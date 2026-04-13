import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';

class MediaCompressor {
  static const int maxFileSizeBytes = 16 * 1024 * 1024;
  static const int compressionThresholdBytes = 14 * 1024 * 1024;

  static Future<CompressResult> prepareForUpload(File file, String contentType) async {
    final originalSize = await file.length();

    if (originalSize <= compressionThresholdBytes) {
      return CompressResult(file: file, originalSize: originalSize, compressedSize: originalSize, wasCompressed: false);
    }

    if (contentType.startsWith('image/')) {
      return _compressImage(file, originalSize);
    } else if (contentType.startsWith('video/')) {
      return _compressVideo(file, originalSize);
    } else {
      // Documents can't be compressed
      if (originalSize > maxFileSizeBytes) {
        throw FileTooLargeException(
          originalSize: originalSize,
          reason: 'Documents cannot be compressed. Maximum file size is 16MB.',
        );
      }
      return CompressResult(file: file, originalSize: originalSize, compressedSize: originalSize, wasCompressed: false);
    }
  }

  static Future<CompressResult> _compressImage(File file, int originalSize) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    for (int quality in [85, 70, 50, 30, 15]) {
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: quality,
        minWidth: quality > 50 ? 1920 : 1280,
        minHeight: quality > 50 ? 1920 : 1280,
      );

      if (result != null) {
        final compressedSize = await result.length();
        if (compressedSize <= compressionThresholdBytes) {
          return CompressResult(
            file: File(result.path),
            originalSize: originalSize,
            compressedSize: compressedSize,
            wasCompressed: true,
          );
        }
      }
    }

    throw FileTooLargeException(
      originalSize: originalSize,
      reason: 'Image is too large even after maximum compression. Try cropping or using a lower resolution.',
    );
  }

  static Future<CompressResult> _compressVideo(File file, int originalSize) async {
    for (final quality in [VideoQuality.MediumQuality, VideoQuality.LowQuality]) {
      final result = await VideoCompress.compressVideo(
        file.path,
        quality: quality,
        deleteOrigin: false,
      );

      if (result?.file != null) {
        final compressedSize = await result!.file!.length();
        if (compressedSize <= compressionThresholdBytes) {
          return CompressResult(
            file: result.file!,
            originalSize: originalSize,
            compressedSize: compressedSize,
            wasCompressed: true,
          );
        }
      }
    }

    throw FileTooLargeException(
      originalSize: originalSize,
      reason: 'Video is too large even after compression (${formatSize(originalSize)} original). Try recording a shorter video.',
    );
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class CompressResult {
  final File file;
  final int originalSize;
  final int compressedSize;
  final bool wasCompressed;

  CompressResult({required this.file, required this.originalSize, required this.compressedSize, required this.wasCompressed});
}

class FileTooLargeException implements Exception {
  final int originalSize;
  final String reason;

  FileTooLargeException({required this.originalSize, required this.reason});
}
