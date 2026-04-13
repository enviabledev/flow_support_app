import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../providers/uploads_provider.dart';

class UploadingBubble extends StatelessWidget {
  final UploadingMessage upload;
  final VoidCallback? onRetry;

  const UploadingBubble({super.key, required this.upload, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
        margin: const EdgeInsets.only(left: 60, right: 16, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: ThemeProvider.instance.colors.outgoingBubble,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Preview with overlay
            Stack(
              alignment: Alignment.center,
              children: [
                // Blurred local image preview or file icon
                if (upload.isImage)
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: upload.failed ? 0 : 6, sigmaY: upload.failed ? 0 : 6),
                    child: Image.file(
                      upload.localFile,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: double.infinity,
                        height: 200,
                        color: ThemeProvider.instance.colors.surface,
                        child: Icon(Icons.broken_image, color: ThemeProvider.instance.colors.textSecondary, size: 48),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 80,
                    color: ThemeProvider.instance.colors.surface.withValues(alpha: 0.5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          upload.isVideo ? Icons.videocam : Icons.insert_drive_file,
                          color: ThemeProvider.instance.colors.textPrimary, size: 28,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            upload.localFile.path.split('/').last,
                            style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Dark overlay
                Container(
                  width: double.infinity,
                  height: upload.isImage ? 200 : 80,
                  color: Colors.black.withValues(alpha: upload.failed ? 0.6 : 0.4),
                ),

                // Progress indicator or failed state
                if (!upload.failed)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: upload.progress > 0 ? upload.progress : null,
                              color: AppColors.accent,
                              strokeWidth: 3,
                              backgroundColor: Colors.white.withValues(alpha: 0.3),
                            ),
                            Text(
                              '${(upload.progress * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Uploading...',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),

                if (upload.failed)
                  GestureDetector(
                    onTap: upload.errorMessage != null ? null : onRetry,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
                        const SizedBox(height: 4),
                        Text(
                          upload.errorMessage != null ? 'File too large' : 'Tap to retry',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        if (upload.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              upload.errorMessage!,
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),

            // Caption
            if (upload.caption != null && upload.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(upload.caption!, style: AppTypography.chatMessage(ThemeProvider.instance.colors)),
              ),

            // Timestamp
            Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 6, left: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    style: AppTypography.timestamp(ThemeProvider.instance.colors),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.access_time, size: 14, color: AppColors.tickGrey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
