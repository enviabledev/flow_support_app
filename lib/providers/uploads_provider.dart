import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../utils/media_compressor.dart';
import 'conversations_provider.dart';
import 'messages_provider.dart';

class UploadingMessage {
  final String tempId;
  final String conversationId;
  final File localFile;
  final String contentType;
  final String? caption;
  double progress;
  bool failed;
  String? errorMessage;

  UploadingMessage({
    required this.tempId,
    required this.conversationId,
    required this.localFile,
    required this.contentType,
    this.caption,
    this.progress = 0,
    this.failed = false,
    this.errorMessage,
  });

  bool get isImage => contentType.startsWith('image/');
  bool get isVideo => contentType.startsWith('video/');
}

class UploadsNotifier extends StateNotifier<Map<String, UploadingMessage>> {
  final Ref _ref;
  UploadsNotifier(this._ref) : super({});

  /// Start an upload that runs independently of any screen.
  Future<void> startUpload({
    required String conversationId,
    required String path,
    required String filename,
    required String contentType,
    required String caption,
  }) async {
    final tempId = 'upload_${DateTime.now().millisecondsSinceEpoch}';
    final file = File(path);

    // Add to state immediately — shows uploading bubble
    final upload = UploadingMessage(
      tempId: tempId,
      conversationId: conversationId,
      localFile: file,
      contentType: contentType,
      caption: caption.isNotEmpty ? caption : null,
    );
    state = {...state, tempId: upload};

    // Update conversation list preview
    String mediaLabel;
    if (contentType.startsWith('image/')) {
      mediaLabel = '📷 Photo';
    } else if (contentType.startsWith('audio/')) {
      mediaLabel = '🎵 Voice message';
    } else if (contentType.startsWith('video/')) {
      mediaLabel = '🎥 Video';
    } else {
      mediaLabel = '📎 Document';
    }
    final previewText = caption.isNotEmpty ? '$mediaLabel: $caption' : mediaLabel;
    _ref.read(conversationsProvider.notifier).updateLastMessage(conversationId, previewText);

    try {
      // Compress if needed
      File fileToUpload = file;
      try {
        final compressResult = await MediaCompressor.prepareForUpload(file, contentType);
        fileToUpload = compressResult.file;
        if (compressResult.wasCompressed) {
          debugPrint('Media compressed: ${MediaCompressor.formatSize(compressResult.originalSize)} -> ${MediaCompressor.formatSize(compressResult.compressedSize)}');
        }
      } on FileTooLargeException catch (e) {
        if (state.containsKey(tempId)) {
          state[tempId]!.failed = true;
          state[tempId]!.errorMessage = e.reason;
          state = Map.from(state);
        }
        return;
      }

      // Upload file with progress tracking
      final uploadResponse = await ApiService().uploadFile(fileToUpload.path, filename,
        onSendProgress: (sent, total) {
          if (total > 0) {
            _updateProgress(tempId, sent / total);
          }
        },
      );
      final url = uploadResponse.data['url'] as String;

      // Send the message with the uploaded URL
      await _ref.read(messagesProvider(conversationId).notifier).sendMessage(
        caption,
        mediaUrl: url,
        mediaContentType: contentType,
      );

      // Remove uploading indicator
      _removeUpload(tempId);
    } catch (_) {
      _markFailed(tempId);
    }
  }

  /// Retry a failed upload.
  Future<void> retryUpload(String tempId) async {
    final upload = state[tempId];
    if (upload == null) return;

    // Remove the failed entry
    _removeUpload(tempId);

    // Restart
    await startUpload(
      conversationId: upload.conversationId,
      path: upload.localFile.path,
      filename: upload.localFile.path.split('/').last,
      contentType: upload.contentType,
      caption: upload.caption ?? '',
    );
  }

  void _updateProgress(String tempId, double progress) {
    if (state.containsKey(tempId)) {
      state[tempId]!.progress = progress;
      state = Map.from(state);
    }
  }

  void _markFailed(String tempId) {
    if (state.containsKey(tempId)) {
      state[tempId]!.failed = true;
      state = Map.from(state);
    }
  }

  void _removeUpload(String tempId) {
    state = Map.from(state)..remove(tempId);
  }

  void removeUpload(String tempId) => _removeUpload(tempId);
}

final uploadsProvider = StateNotifierProvider<UploadsNotifier, Map<String, UploadingMessage>>((ref) {
  return UploadsNotifier(ref);
});
