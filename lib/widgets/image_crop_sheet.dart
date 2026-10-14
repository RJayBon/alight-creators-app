import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/file_service.dart';
import '../theme.dart';

/// Drag-to-frame crop screen, drawn entirely in Dart.
///
/// Why this exists instead of `image_cropper`: that plugin launches a *second
/// Android activity* (`com.yalantis.ucrop.UCropActivity`) and waits for
/// `onActivityResult` on the Flutter one. On the device class this app ships to,
/// that callback never arrives — the crop activity opens, draws one frame, and
/// finishes while the awaited `ImageCropper.cropImage()` Future sits pending
/// forever. Nothing done in Dart can close that Future, so the crop must not
/// depend on a second activity at all. Here the frame is composited by Flutter
/// and the pixels are cut through `FileService.renderCrop` — the engine's own
/// rasterizer, the same path every other image in this app is resized by. No
/// platform channel, no activity result, nothing for a vendor ROM to swallow.
///
/// Geometry contract, shared by the preview and [_apply]: the source is fitted to
/// the viewport with a *cover* ratio ([_baseScale]), then multiplied by `_zoom`
/// and translated by `_offset`, about the viewport center. Whatever the viewport
/// shows **is** the crop — which is why the mapping in [_apply] is one division
/// rather than the two-step arithmetic a free-resize cropper needs.
///
/// Returns the cropped file through [show], or `null` when the user cancels.
class ImageCropSheet extends StatefulWidget {
  const ImageCropSheet({
    super.key,
    required this.source,
    required this.aspectRatio,
    required this.outputWidth,
    required this.outputHeight,
    this.circle = false,
    this.title = 'Crop',
    this.maxDimension,
  });

  final File source;

  /// Width / height of the frame, e.g. 1 for an avatar, 4 for a banner.
  final double aspectRatio;

  /// Requested output size in pixels. The caller is expected to have already
  /// sized this sensibly; [FileService.convertToWebp] does the final downscale.
  final int outputWidth;
  final int outputHeight;

  /// Masks the frame with an oval. Preview only — the saved file stays a
  /// rectangle, because a transparent WebP costs bytes and breaks the
  /// `BoxFit.cover` the profile already relies on.
  final bool circle;

  final String title;

  /// Long edge the *result* is downscaled to before it comes back, mirroring what
  /// the native cropper's `maxWidth`/`maxHeight` used to do. Null keeps the crop
  /// at its rendered size.
  final int? maxDimension;

  /// Long edge the source is decoded at. 1600 px is roomier than any output we
  /// produce, and it keeps a 108-megapixel phone photo from ever existing in
  /// memory at full size (that decode alone would need ~1.3 GB).
  static const int decodeMaxDimension = 1600;

  Future<File?> show(BuildContext context) => Navigator.of(context)
      .push<File?>(MaterialPageRoute<File?>(builder: (_) => this));

  @override
  State<ImageCropSheet> createState() => _ImageCropSheetState();
}

class _ImageCropSheetState extends State<ImageCropSheet> {
  ui.Image? _img;
  String? _error;
  bool _busy = false;

  /// Raw pan/zoom translation. Deliberately *unclamped*: the clamped value used
  /// for painting is derived in [_fit] on every layout, which is what makes a
  /// focal-anchored zoom lose no pixels. Clamping `on` each update instead would
  /// silently rewrite history mid-gesture, so the finger would drift away from
  /// the point it is holding.
  Offset _rawOffset = Offset.zero;

  /// [_rawOffset] after the "stay inside the frame" constraint. Set by [_fit]
  /// before anything reads it, and read by the painter, the gesture anchor and
  /// the crop mapping alike.
  Offset _offset = Offset.zero;

  double _zoom = 1;

  /// Zoom baseline captured in `onScaleStart`, so `d.scale` is applied as a
  /// delta against it rather than compounded against whatever `_zoom` happens to
  /// be after the previous frame's clamp.
  double _startZoom = 1;

  /// Second pointer's position relative to the viewport center, captured in
  /// `onScaleStart` and held for the whole gesture: the point the pinch is about.
  Offset _anchor = Offset.zero;

  double _vw = 0;
  double _vh = 0;
  double _baseScale = 1;

  static const double _maxZoom = 6;
  static const ui.Color _backdrop = ui.Color(0xFF05080D);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Deferred: a frame that is still compositing the old image must not touch a
    // disposed one.
    final img = _img;
    _img = null;
    if (img != null) {
      // Future.microtask (not scheduleMicrotask): the latter needs an
      // explicit dart:async / foundation import and is a needless dependency.
      Future.microtask(img.dispose);
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.source.readAsBytes();
      if (!mounted) return;
      // Resampling happens during decode, so this costs one pass, not a
      // full-size bitmap followed by a scale.
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: ImageCropSheet.decodeMaxDimension,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _img = frame.image);
    } catch (e) {
      debugPrint('[ImageCropSheet] decode failed: $e');
      if (mounted) {
        setState(() => _error =
            'This image could not be opened. Cancel and pick another one.');
      }
    }
  }

  /// Fits the frame box into the available space and derives every constant the
  /// gestures and the crop mapping depend on. Runs inside `LayoutBuilder`, and
  /// deliberately mutates fields rather than calling `setState` — the build that
  /// computed it is the one that will use it.
  void _layout(BoxConstraints c) {
    final availW = c.maxWidth - 32;
    var w = availW < 120 ? 120.0 : availW;
    var h = w / widget.aspectRatio;
    final maxH = c.maxHeight - 200;
    if (maxH > 80 && h > maxH) {
      h = maxH;
      w = h * widget.aspectRatio;
      if (w > availW) {
        w = availW;
        h = w / widget.aspectRatio;
      }
    }
    _vw = w;
    _vh = h;
    if (_img != null) {
      final s = _coverScale(_img!.width.toDouble(), _img!.height.toDouble(), w, h);
      // Re-fitting (first layout, or a rotation) must not keep a stale pan.
      if (s != _baseScale) {
        _baseScale = s;
        _rawOffset = Offset.zero;
      }
    }
  }

  static double _coverScale(double iw, double ih, double vw, double vh) {
    if (iw <= 0 || ih <= 0) return 1;
    final sx = vw / iw;
    final sy = vh / ih;
    return sx > sy ? sx : sy;
  }

  double _drawW(ui.Image img) => img.width * _baseScale * _zoom;

  double _drawH(ui.Image img) => img.height * _baseScale * _zoom;

  /// Derives the painted offset from [_rawOffset]. Runs at the top of every
  /// build, so a stale clamp can never leak into a frame.
  void _fit() {
    final img = _img;
    if (img == null) {
      _offset = Offset.zero;
      return;
    }
    _offset = Offset(
      _clamp(_rawOffset.dx, _vw - _drawW(img), 0),
      _clamp(_rawOffset.dy, _vh - _drawH(img), 0),
    );
  }

  /// When the drawn image is smaller than the frame (only possible if a decode
  /// came back oddly proportioned) `min > max`, and the only sane position is
  /// centered — which is exactly what the mid branch returns.
  static double _clamp(double v, double min, double max) {
    if (min > max) return (min + max) / 2;
    return v < min ? min : (v > max ? max : v);
  }

  /// Ends the current gesture baseline. Without this, lifting one finger out of
  /// a pinch makes the recognizer resume the sequence with the *remaining*
  /// finger's `focalPointDelta`, which is a large jump in the accumulated pan —
  /// the frame would snap the moment a finger leaves.
  void _onScaleEnd(ScaleEndDetails d) {
    _startZoom = _zoom;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startZoom = _zoom;
    final img = _img;
    if (img != null) {
      final dx = d.localFocalPoint.dx - _vw / 2;
      final dy = d.localFocalPoint.dy - _vh / 2;
      _anchor = Offset(
        _clamp(dx, -_drawW(img) / 2, _drawW(img) / 2),
        _clamp(dy, -_drawH(img) / 2, _drawH(img) / 2),
      );
    } else {
      _anchor = Offset.zero;
    }
  }

  /// Pan *and* pinch, from one recognizer.
  ///
  /// `GestureDetector` asserts that a pan and a scale recognizer are not both
  /// attached — scale is the superset, and `ScaleGestureRecognizer` does keep
  /// reporting `focalPointDelta` for a single finger, so this handles both cases
  /// without double-applying anything.
  ///
  /// `ScaleUpdateDetails.focal` / `.localFocal` are deliberately NOT used: this
  /// project's Flutter exposes neither (analyzer-verified). The pinch anchor is
  /// therefore carried in [_anchor], captured once in [_onScaleStart], and only
  /// `d.scale` / `d.focalPointDelta` are read here — both long-standing members.
  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_img == null) return;
    final target = (_startZoom * d.scale).clamp(1.0, _maxZoom);
    // Zoom about the anchor: with p = c + o + a fixed, o must move by (k-1)*(c+a).
    final k = target / _zoom;
    setState(() {
      _zoom = target;
      _rawOffset = Offset(
        _rawOffset.dx + (k - 1) * (_vw / 2 + _anchor.dx) + d.focalPointDelta.dx,
        _rawOffset.dy + (k - 1) * (_vh / 2 + _anchor.dy) + d.focalPointDelta.dy,
      );
    });
  }

  void _reset() {
    setState(() {
      _zoom = 1;
      _startZoom = 1;
      _rawOffset = Offset.zero;
      _anchor = Offset.zero;
    });
  }

  Future<void> _apply() async {
    final img = _img;
    if (img == null) return;
    setState(() => _busy = true);
    try {
      final s = _baseScale * _zoom;
      final crop = Rect.fromLTWH(
        -_offset.dx / s,
        -_offset.dy / s,
        _vw / s,
        _vh / s,
      );
      final outW = widget.outputWidth < 1 ? 1 : widget.outputWidth;
      final outH = widget.outputHeight < 1 ? 1 : widget.outputHeight;
      var file = await _cropToFile(img, crop, outW, outH);
      // Hand back exactly what the old pipeline handed back: a WebP temp file,
      // so `saveUpload` + the byte caps behave identically.
      if (widget.maxDimension != null) {
        file = await FileService.instance.convertToWebp(
          file,
          maxDimension: widget.maxDimension,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop<File?>(file);
    } catch (e) {
      debugPrint('[ImageCropSheet] crop failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not crop this image. Cancel and pick it again.';
      });
    }
  }

  /// Cuts the framed region out of the decoded source and writes it to a temp
  /// file, via `FileService.renderCrop` — the same `drawImageRect` path the rest of
  /// the app's image work uses, so there is one crop implementation, not two.
  ///
  /// The rect is mapped from viewport logical pixels back to *decoded source*
  /// pixels by dividing by the total scale, which is the whole point of the
  /// geometry contract in the class doc: the preview and the crop are derived from
  /// the same three numbers.
  Future<File> _cropToFile(
    ui.Image img,
    Rect crop,
    int outW,
    int outH,
  ) async {
    final bytes = await FileService.instance.renderCrop(
      img,
      crop,
      outWidth: outW,
      outHeight: outH,
    );
    if (bytes == null) {
      throw StateError('empty crop rect');
    }
    // Written out as a real file so the rest of the pipeline (`convertToWebp`,
    // `saveUpload`) sees exactly what it saw from the native cropper: a temp file
    // in the cache directory.
    final dir = await getTemporaryDirectory();
    final dest = p.join(
      dir.path,
      'crop_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    final f = File(dest);
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop<File?>(null),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: img == null ? null : _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _layout(constraints);
            _fit();
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: _vw,
                        height: _vh,
                        child: _frame(img),
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: Column(
                    children: [
                      const Text(
                        'Drag to reposition · pinch to zoom',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CropActions(
                        busy: _busy,
                        canCrop: img != null,
                        onReset: _reset,
                        onApply: _apply,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _frame(ui.Image? img) {
    if (img == null) {
      return const ColoredBox(
        color: _backdrop,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final content = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: _backdrop,
          child: Transform.translate(
            offset: _offset,
            child: Transform.scale(
              scale: _zoom,
              alignment: Alignment.center,
              child: RawImage(
                image: img,
                width: _drawW(img),
                height: _drawH(img),
              ),
            ),
          ),
        ),
        // One recognizer over the whole box — not on the image — so a drag that
        // starts over a dimmed corner still works. A pan recognizer must not be
        // added alongside: `GestureDetector` asserts, and scale already covers it.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
          ),
        ),
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.circle) ClipOval(child: content) else content,
        // Everything outside the frame dims, using the same shape.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _DimOutside(circle: widget.circle),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius:
                    widget.circle
                    ? null
                    : const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reset / Use-photo pair. A private row instead of `PillButton`: both buttons
/// here need a *nullable* callback (disabled while decoding or saving), and
/// `PillButton.onPressed` is a non-nullable `VoidCallback`.
class _CropActions extends StatelessWidget {
  const _CropActions({
    required this.busy,
    required this.canCrop,
    required this.onReset,
    required this.onApply,
  });

  final bool busy;
  final bool canCrop;
  final VoidCallback onReset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: busy ? null : onReset,
            child: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: (busy || !canCrop) ? null : onApply,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Use photo'),
          ),
        ),
      ],
    );
  }
}

class _DimOutside extends CustomPainter {
  const _DimOutside({required this.circle});

  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    // A real hole, not a second sub-path: `Path.addOval` alone still fills inside
    // the oval (non-zero winding), which would dim the *crop* and leave the
    // outside bright. `PathOperation.difference` is the only correct spelling.
    final outer = Path()..addRect(Offset.zero & size);
    final inner = circle
        ? (Path()..addOval(Offset.zero & size))
        : (Path()
          ..addRRect(RRect.fromRectAndRadius(
            Offset.zero & size,
            const Radius.circular(14),
          )));
    canvas.drawPath(
      Path.combine(ui.PathOperation.difference, outer, inner),
      Paint()..color = const Color(0x7A000000),
    );
  }

  @override
  bool shouldRepaint(_DimOutside oldDelegate) =>
      oldDelegate.circle != circle;
}