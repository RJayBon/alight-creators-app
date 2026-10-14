import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Thrown by [FileService.saveUpload] when a file exceeds its size cap.
class FileTooLargeException implements Exception {
  FileTooLargeException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when a picked file cannot be copied into the app's storage.
class FileSaveException implements Exception {
  FileSaveException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Local file storage: pick → normalize → compress → persist → resolve.
///
/// FIXES vs. the previous version:
///  1. Cropping no longer *starts an activity*. The old `cropImage()` accepted
///     `width`/`height`/`circle` and ignored all three (so avatars were stored at
///     full camera resolution, 2–6 MB each, despite the caller asking for 400px),
///     and it drove that crop through `image_cropper` — a second Android activity
///     whose result never arrives on some vendor ROMs, leaving the awaited Future
///     pending forever. It is gone: the frame is now drawn in-app by
///     `lib/widgets/image_crop_sheet.dart`, and this service only turns a rect +
///     a decoded image into bytes (`renderCrop`) or a file into a smaller WebP
///     (`convertToWebp`).
///  2. `saveUpload` forced any extension-less or `.tmp` file to `.webp` —
///     correct for images, fatal for videos, which then failed to open in
///     `VideoPlayerController.file` with no clue as to why.
///  3. `resolveFile` hit the filesystem on every call, and `TutorialCard`
///     called it from inside `build()`, so every hover/scroll/parent rebuild
///     did a fresh `exists()` stat on the thumbnail. Results are cached now.
class FileService {
  FileService._();
  static final FileService instance = FileService._();

  final _picker = ImagePicker();

  /// relativePath → resolved file (null = known-missing). Cleared whenever a
  /// file is written or deleted so it can never serve a stale hit.
  final Map<String, File?> _resolved = {};

  // ---------- PICKERS ----------

  /// Picks an image from the gallery and normalizes it to a plain 8-bit JPEG.
  ///
  /// The normalize step started life as the fix for uCrop's "Invalid base format"
  /// crash on phones that hand back HDR/HEIC files. It stays because it is also
  /// what keeps the in-app crop cheap: `ImageCropSheet` decodes this file, and a
  /// 1200 px 8-bit JPEG is a bounded decode whereas a 108-megapixel HEIC is not.
  Future<File?> pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (x == null) return null;
    return _normalizeForCropper(File(x.path));
  }

  /// Re-encodes an image as a plain JPEG at reduced size, stripping any
  /// HDR / HEIC / 10-bit metadata the Flutter decoder can't render, and capping
  /// the long edge so the crop sheet's decode is bounded. Named for the cropper
  /// it originally served; the name is kept because it is still exactly what the
  /// step is for — making an arbitrary gallery file safe and cheap to crop.
  Future<File> _normalizeForCropper(File src) async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final dest = p.join(
        tmpDir.path,
        'pre_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        src.absolute.path,
        dest,
        format: CompressFormat.jpeg,
        quality: 85,
        minWidth: 1200,
        minHeight: 1200,
      );
      return result == null ? src : File(result.path);
    } catch (e) {
      debugPrint('[FileService] pre-crop normalize failed: $e');
      return src;
    }
  }

  /// Picks an image and immediately re-encodes it as WebP.
  /// Use this for thumbnails (no cropper involved).
  Future<File?> pickImageAsWebp({int? targetWidth}) async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (x == null) return null;
    return convertToWebp(File(x.path), maxDimension: targetWidth);
  }

  /// Converts any image file to WebP. Returns the original file unchanged if
  /// conversion fails for any reason.
  ///
  /// [maxDimension] caps the long edge; `flutter_image_compress` keeps the
  /// aspect ratio and picks the smaller of "fits width" / "fits height".
  Future<File> convertToWebp(File src,
      {int quality = 80, int? maxDimension}) async {
    try {
      final ext = p.extension(src.path).toLowerCase();
      final alreadyWebp = ext == '.webp';
      final needsResize = maxDimension != null;
      // Only short-circuit when there is nothing else to do — before, a
      // `.webp` source skipped the whole pipeline and the requested downscale
      // silently never happened.
      if (alreadyWebp && !needsResize) return src;

      final tmpDir = await getTemporaryDirectory();
      final stem = p.basenameWithoutExtension(src.path);
      final dest = p.join(
        tmpDir.path,
        '${stem}_${DateTime.now().microsecondsSinceEpoch}.webp',
      );

      final dim = maxDimension ?? 1600;
      final result = await FlutterImageCompress.compressAndGetFile(
        src.absolute.path,
        dest,
        format: CompressFormat.webp,
        quality: quality,
        minWidth: dim,
        minHeight: dim,
      );
      if (result == null) return src;
      return File(result.path);
    } catch (e) {
      debugPrint('[FileService] WebP conversion failed: $e');
      return src;
    }
  }

  Future<File?> pickVideo() async {
    final x = await _picker.pickVideo(source: ImageSource.gallery);
    return x == null ? null : File(x.path);
  }

  // ---------- CROP ----------

  /// Crops [image] to [crop] (in *source* pixels) and renders it at
  /// [outWidth] x [outHeight], returning PNG bytes. Nothing but the engine's own
  /// rasterizer is involved: `ui.PictureRecorder` + `drawImageRect`.
  ///
  /// This is what replaced the platform cropper. `image_cropper`'s `cropImage()`
  /// started a second Android activity and waited for `onActivityResult`; on some
  /// vendor ROMs that callback never arrives, and the awaiting `Future` then hangs
  /// forever with no exception to catch — so a crop that the user could not finish
  /// was also a crop Dart could not recover from. An in-process crop cannot be
  /// lost that way: no activity to lose, no method channel, and no edge-to-edge
  /// workaround to chase through plugin versions.
  ///
  /// Callers that only have a file (not a decoded image) can use
  /// [convertToWebp], which decodes with a size cap; the interactive
  /// `ImageCropSheet` passes its own decoded image so the geometry it drew on
  /// screen and the pixels it cuts are the same numbers.
  Future<Uint8List?> renderCrop(
    ui.Image image,
    ui.Rect crop, {
    required int outWidth,
    required int outHeight,
  }) {
    return _renderCrop(
      image,
      crop,
      outWidth < 1 ? 1 : outWidth,
      outHeight < 1 ? 1 : outHeight,
    );
  }

  /// Returns the encoded PNG bytes of [crop], or null when the rect is empty or
  /// has drifted entirely outside the source.
  Future<Uint8List?> _renderCrop(
    ui.Image image,
    ui.Rect crop,
    int ow,
    int oh,
  ) async {
    final src = crop.intersect(
      ui.Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      ),
    );
    if (src.width < 1 || src.height < 1) return null;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    // Opaque backdrop first: the output may be re-encoded to WebP and shown under
    // `BoxFit.cover`, and a rect that does not divide evenly would otherwise
    // leave uninitialized pixels at the edge.
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, ow.toDouble(), oh.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF05080D),
    );
    // Contain, centered — never a stretch, so a crop rect whose aspect ratio
    // differs slightly from the output (integer rounding in the caller) cannot
    // squash a face.
    final sx = ow / src.width;
    final sy = oh / src.height;
    final k = sx < sy ? sx : sy;
    final dw = src.width * k;
    final dh = src.height * k;
    canvas.drawImageRect(
      image,
      src,
      ui.Rect.fromLTWH((ow - dw) / 2, (oh - dh) / 2, dw, dh),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(ow, oh);
    picture.dispose();
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    if (data == null) return null;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  // ---------- SAVE / DELETE ----------

  /// Copies [src] into the app documents directory under [subfolder] and
  /// returns the *relative* path that gets stored in the DB.
  Future<String> saveUpload({
    required File src,
    required String subfolder,
    required String prefix,
    int? maxBytes,
    String? fallbackExtension,
  }) async {
    if (!src.existsSync()) {
      throw FileSaveException('The selected file is no longer available.');
    }

    if (maxBytes != null) {
      final size = await src.length();
      if (size > maxBytes) {
        final actualMb = (size / (1024 * 1024)).toStringAsFixed(1);
        final limitMb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
        throw FileTooLargeException(
          'File is too large ($actualMb MB). Max is $limitMb MB.',
        );
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(docs.path, subfolder));
    if (!folder.existsSync()) {
      try {
        await folder.create(recursive: true);
      } catch (e) {
        throw FileSaveException('Could not create the uploads folder: $e');
      }
    }

    var ext = p.extension(src.path).toLowerCase();
    if (ext.isEmpty || ext == '.tmp' || ext == '.file') {
      // `.webp` used to be the unconditional fallback, which turned every
      // extension-less video into a "webp" that no player could open.
      ext = fallbackExtension ?? '.webp';
    }

    final rand = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final name = '${prefix}_$rand$ext';
    final dest = p.join(folder.path, name);

    try {
      await src.copy(dest);
    } catch (e) {
      throw FileSaveException('Could not save the file: $e');
    }

    final rel = p.join(subfolder, name);
    _resolved.remove(rel);
    return rel;
  }

  Future<void> deleteFile(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    _resolved.remove(relativePath);
    final docs = await getApplicationDocumentsDirectory();
    final abs = p.join(docs.path, relativePath);
    final f = File(abs);
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {
        // Best effort — a file we can't delete is not worth failing a
        // profile save or an account delete over.
      }
    }
  }

  /// Delete a batch, ignoring nulls/duplicates. Used when a multi-file save
  /// fails partway and we must not leave orphans behind.
  Future<void> deleteFiles(Iterable<String?> relativePaths) async {
    for (final r in relativePaths.whereType<String>()) {
      if (r.isEmpty) continue;
      await deleteFile(r);
    }
  }

  // ---------- SEED ASSETS ----------

  /// Returns false when the asset is simply not bundled (e.g. a repo checkout
  /// without the large seed videos) instead of letting the FlutterError
  /// escape into whoever forgot a try/catch.
  Future<bool> copySeedAsset({
    required String assetPath,
    required String relativeDest,
  }) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final absDest = p.join(docs.path, relativeDest);
      final destFile = File(absDest);
      if (destFile.existsSync()) return true;

      final folder = destFile.parent;
      if (!folder.existsSync()) {
        await folder.create(recursive: true);
      }

      final data = await rootBundle.load(assetPath);
      await destFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      _resolved.remove(relativeDest);
      return true;
    } catch (e) {
      debugPrint('[FileService] seed asset "$assetPath" unavailable: $e');
      return false;
    }
  }

  // ---------- RESOLVE ----------

  /// Maps a DB-relative path back to a File, or null if it is not on disk.
  /// Cached because it is called from widget `build()` methods.
  Future<File?> resolveFile(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    if (_resolved.containsKey(relativePath)) {
      final cached = _resolved[relativePath];
      // Re-stat a previously-missing file at most cheaply: if it appeared
      // (e.g. a seed copy finished late) we want to pick it up.
      if (cached != null && cached.existsSync()) return cached;
      if (cached != null) _resolved.remove(relativePath);
    }

    final docs = await getApplicationDocumentsDirectory();
    final abs = p.join(docs.path, relativePath);
    final f = File(abs);
    final exists = f.existsSync();
    _resolved[relativePath] = exists ? f : null;
    return exists ? f : null;
  }

  /// Synchronous variant for cases where a Future is awkward (grid sizing,
  /// decoration images). Same cache.
  File? resolveFileSync(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    final cached = _resolved[relativePath];
    if (cached != null && cached.existsSync()) return cached;
    return null;
  }

  /// Call after bulk writes (import, reset) to drop cached lookups.
  void invalidateCache() => _resolved.clear();
}