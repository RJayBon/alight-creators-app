import 'dart:io';

import 'package:flutter/material.dart';

import '../services/file_service.dart';
import '../theme.dart';

/// Thumbnail chooser for the composer / tutorial editor.
///
/// Two defects fixed, both of the "the screen froze or went red" family:
///
///  * The `catch` called `setState` with no `mounted` guard. `image_picker`
///    throws its `PlatformException` in precisely the situation where the app
///    has been backgrounded long enough for Android to reclaim the activity — so
///    the error path was itself a crash (`setState() called after dispose()`).
///    Handing the result to `widget.onPick` had the same problem.
///  * The preview was a `DecorationImage(ResizeImage(FileImage(...)))`, and a
///    decoration image has **no error channel at all**: no `errorBuilder`, no
///    `onError`. The picked file lives in the cache directory, which the OS is
///    free to purge while the gallery is open; the next frame then threw
///    `FileSystemException` out of `FileImage.load` — and every frame after it.
///    It is now an `Image.file` with an `errorBuilder`, keeping the same decode
///    cap through `cacheWidth`.
class ThumbnailPicker extends StatefulWidget {
  const ThumbnailPicker({
    super.key,
    required this.file,
    required this.onPick,
  });

  final File? file;
  final ValueChanged<File?> onPick;

  @override
  State<ThumbnailPicker> createState() => _ThumbnailPickerState();
}

class _ThumbnailPickerState extends State<ThumbnailPicker> {
  bool _busy = false;
  String? _error;

  /// Decoded size of the preview — and of the file handed back to the caller,
  /// which is why `pickImageAsWebp` gets the same number.
  static const int kPreviewDecodeWidth = 400;

  static const Widget _placeholder = Center(
    child: Icon(Icons.image_outlined, color: AppColors.textSecondary),
  );

  Future<void> _pick() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    File? img;
    try {
      img = await FileService.instance
          .pickImageAsWebp(targetWidth: kPreviewDecodeWidth);
    } catch (e) {
      // image_picker throws PlatformException when the gallery intent is
      // killed on low-memory devices; that used to bubble up as a red screen,
      // and then the unguarded setState below turned the recovery into a second
      // crash.
      debugPrint('ThumbnailPicker.pick failed: $e');
      if (mounted) {
        setState(() => _error = 'Could not open the gallery. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // The parent can be gone by now (the user backed out mid-pick), which is the
    // other half of the dispose crash.
    if (img != null && mounted) widget.onPick(img);
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thumbnail',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 110,
              height: 70,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (file == null)
                    _placeholder
                  else
                    Image.file(
                      file,
                      fit: BoxFit.cover,
                      cacheWidth: kPreviewDecodeWidth,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => _placeholder,
                    ),
                  if (_busy)
                    const ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : _pick,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                    ),
                    child: Text(file == null
                        ? 'Choose image'
                        : 'Change image'),
                  ),
                  if (file != null)
                    TextButton(
                      onPressed: _busy ? null : () => widget.onPick(null),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.danger,
                      ),
                      child: const Text('Remove',
                          style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 12, height: 1.4)),
          ),
      ],
    );
  }
}