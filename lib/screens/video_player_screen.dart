import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../config/theme.dart';
import '../services/media_download_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String? caption;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.caption,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
                const SizedBox(height: 12),
                Text('Failed to play video', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 16)),
                const SizedBox(height: 4),
                Text(errorMessage, style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
          );
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.accent,
          handleColor: AppColors.accent,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
      );

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _downloadVideo() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading video...'), backgroundColor: AppColors.accent),
    );
    try {
      final success = await MediaDownloadService().saveVideoToGallery(widget.videoUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Video saved to gallery' : 'Failed to save video'),
          backgroundColor: success ? AppColors.accent : AppColors.danger,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: widget.caption != null && widget.caption!.isNotEmpty
            ? Text(widget.caption!, style: const TextStyle(color: Colors.white, fontSize: 16), overflow: TextOverflow.ellipsis)
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () async {
              final filename = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
              await MediaDownloadService().shareMedia(widget.videoUrl, filename, caption: widget.caption);
            },
          ),
          IconButton(icon: const Icon(Icons.download, color: Colors.white), onPressed: _downloadVideo),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.accent),
                  SizedBox(height: 16),
                  Text('Loading video...', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              )
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
                      const SizedBox(height: 12),
                      const Text('Failed to load video', style: TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() { _isLoading = true; _error = null; });
                          _initializePlayer();
                        },
                        child: const Text('Retry', style: TextStyle(color: AppColors.accent)),
                      ),
                    ],
                  )
                : _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : const SizedBox.shrink(),
      ),
    );
  }
}
