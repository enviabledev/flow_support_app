import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../services/media_download_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String? caption;

  const FullScreenImage({super.key, required this.imageUrl, this.caption});

  Future<void> _download(BuildContext context) async {
    final success = await MediaDownloadService().saveImageToGallery(imageUrl);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Saved to gallery' : 'Failed to save'),
        backgroundColor: success ? AppColors.accent : AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () async {
              final filename = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
              await MediaDownloadService().shareMedia(imageUrl, filename, caption: caption);
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _download(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                  errorWidget: (_, __, ___) => Center(
                    child: Icon(Icons.broken_image, color: ThemeProvider.instance.colors.textSecondary, size: 64),
                  ),
                ),
              ),
            ),
          ),
          if (caption != null && caption!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black87,
              child: Text(caption!, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
        ],
      ),
    );
  }
}
