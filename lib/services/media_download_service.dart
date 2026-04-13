import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaDownloadService {
  static final MediaDownloadService _instance = MediaDownloadService._internal();
  factory MediaDownloadService() => _instance;
  MediaDownloadService._internal();

  final _dio = Dio();

  /// Progress notifier for UI
  final ValueNotifier<double?> downloadProgress = ValueNotifier<double?>(null);

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final photos = await Permission.photos.request();
      if (photos.isGranted) return true;
      final storage = await Permission.storage.request();
      return storage.isGranted;
    }
    return true;
  }

  /// Save an image to the device gallery
  Future<bool> saveImageToGallery(String mediaUrl) async {
    if (!await _requestStoragePermission()) return false;

    try {
      downloadProgress.value = 0;
      final response = await _dio.get<List<int>>(
        mediaUrl,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total > 0) downloadProgress.value = received / total;
        },
      );
      downloadProgress.value = null;

      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(response.data!),
        quality: 100,
        name: 'flow_support_${DateTime.now().millisecondsSinceEpoch}',
      );

      return result['isSuccess'] == true;
    } catch (_) {
      downloadProgress.value = null;
      return false;
    }
  }

  /// Save a video to the device gallery
  Future<bool> saveVideoToGallery(String mediaUrl) async {
    if (!await _requestStoragePermission()) return false;

    try {
      downloadProgress.value = 0;
      final dir = await getTemporaryDirectory();
      final filename = 'flow_support_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final tempPath = '${dir.path}/$filename';

      await _dio.download(mediaUrl, tempPath, onReceiveProgress: (received, total) {
        if (total > 0) downloadProgress.value = received / total;
      });
      downloadProgress.value = null;

      final result = await ImageGallerySaverPlus.saveFile(tempPath, name: filename);
      File(tempPath).deleteSync();

      return result['isSuccess'] == true;
    } catch (_) {
      downloadProgress.value = null;
      return false;
    }
  }

  /// Download a file and open it with the system's default app
  Future<bool> openInExternalApp(String mediaUrl, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$filename';
      await _dio.download(mediaUrl, filePath);

      final result = await OpenFilex.open(filePath);
      if (result.type == ResultType.noAppToOpen) {
        final uri = Uri.parse(mediaUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
        return false;
      }
      return result.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }

  /// Share a media file via the system share sheet
  Future<void> shareMedia(String mediaUrl, String filename, {String? caption}) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/share_$filename';
    await _dio.download(mediaUrl, filePath);
    await Share.shareXFiles([XFile(filePath)], text: caption);
  }

  /// Share text via the system share sheet
  Future<void> shareText(String text) async {
    await Share.share(text);
  }

  /// Save a document to the Downloads folder
  Future<String?> saveToDownloads(String mediaUrl, String filename) async {
    if (!await _requestStoragePermission()) return null;

    try {
      downloadProgress.value = 0;
      final downloadsDir = Directory('/storage/emulated/0/Download');
      final targetDir = downloadsDir.existsSync()
          ? downloadsDir
          : await getExternalStorageDirectory();

      if (targetDir == null) return null;

      final path = '${targetDir.path}/$filename';

      await _dio.download(mediaUrl, path, onReceiveProgress: (received, total) {
        if (total > 0) downloadProgress.value = received / total;
      });
      downloadProgress.value = null;

      return File(path).existsSync() ? path : null;
    } catch (_) {
      downloadProgress.value = null;
      return null;
    }
  }
}
