import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
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

class FileService {
  FileService._();
  static final FileService instance = FileService._();

  final _picker = ImagePicker();

  // ---------- PICKERS ----------

  /// Picks an image from the gallery and normalizes it to a plain 8-bit
  /// JPEG. This step is what prevents the "Invalid base format" crash
  /// inside UCropActivity on phones that hand back HDR or HEIC files.
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
  /// HDR / HEIC / 10-bit metadata that UCropActivity can't render.
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
  Future<File?> pickImageAsWebp() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (x == null) return null;
    return convertToWebp(File(x.path));
  }

  /// Converts any image file to WebP at quality 80. Returns the original
  /// file unchanged if conversion fails for any reason.
  Future<File> convertToWebp(File src, {int quality = 80}) async {
    try {
      final ext = p.extension(src.path).toLowerCase();
      if (ext == '.webp') return src;

      final tmpDir = await getTemporaryDirectory();
      final stem = p.basenameWithoutExtension(src.path);
      final dest = p.join(
        tmpDir.path,
        '${stem}_${DateTime.now().microsecondsSinceEpoch}.webp',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        src.absolute.path,
        dest,
        format: CompressFormat.webp,
        quality: quality,
        minWidth: 1600,
        minHeight: 1600,
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

  /// Crops an image and returns a WebP file. The input is expected to
  /// have already gone through `pickImage()` (which normalizes to JPEG),
  /// so this only has to deal with plain 8-bit data.
  Future<File?> cropImage(
    File src, {
    required double aspectRatio,
    required int width,
    required int height,
    bool circle = false,
  }) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: src.path,
      aspectRatio: CropAspectRatio(ratioX: aspectRatio, ratioY: 1),
      compressQuality: 80,
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop',
          toolbarColor: const Color(0xFF151D29),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: 'Crop',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) return null;
    return convertToWebp(File(cropped.path));
  }

  // ---------- SAVE / DELETE ----------

  Future<String> saveUpload({
    required File src,
    required String subfolder,
    required String prefix,
    int? maxBytes,
  }) async {
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
    if (!folder.existsSync()) folder.createSync(recursive: true);

    var ext = p.extension(src.path).toLowerCase();
    if (ext.isEmpty || ext == '.tmp') ext = '.webp';

    final rand = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final name = '${prefix}_$rand$ext';
    final dest = p.join(folder.path, name);

    await src.copy(dest);
    return p.join(subfolder, name);
  }

  Future<void> deleteFile(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    final docs = await getApplicationDocumentsDirectory();
    final abs = p.join(docs.path, relativePath);
    final f = File(abs);
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }

  // ---------- SEED ASSETS ----------

  Future<void> copySeedAsset({
    required String assetPath,
    required String relativeDest,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final absDest = p.join(docs.path, relativeDest);
    final destFile = File(absDest);
    if (destFile.existsSync()) return;

    final folder = destFile.parent;
    if (!folder.existsSync()) folder.createSync(recursive: true);

    final data = await rootBundle.load(assetPath);
    await destFile.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }

  // ---------- RESOLVE ----------

  Future<File?> resolveFile(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final docs = await getApplicationDocumentsDirectory();
    final abs = p.join(docs.path, relativePath);
    final f = File(abs);
    return f.existsSync() ? f : null;
  }
}