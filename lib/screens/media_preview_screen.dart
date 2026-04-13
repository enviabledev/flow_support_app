import 'dart:io';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/media_compressor.dart';

class MediaPreviewScreen extends StatefulWidget {
  /// Single-file constructor (backwards compatible).
  /// Sets [files] to a single-element list.
  final String? filePath;
  final String? filename;
  final String? contentType;

  /// Multi-file constructor fields.
  final List<File>? files;
  final String? mediaType; // 'image', 'video', 'document'

  const MediaPreviewScreen({
    super.key,
    this.filePath,
    this.filename,
    this.contentType,
    this.files,
    this.mediaType,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  late PageController _pageController;
  late List<File> _files;
  late List<TextEditingController> _captionControllers;
  late String _mediaType;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    // Support both single-file (legacy) and multi-file modes
    if (widget.files != null && widget.files!.isNotEmpty) {
      _files = List.from(widget.files!);
      _mediaType = widget.mediaType ?? _inferMediaType(widget.files!.first.path);
    } else {
      _files = [File(widget.filePath!)];
      _mediaType = _inferMediaType(widget.filePath!, contentType: widget.contentType);
    }

    _pageController = PageController();
    _captionControllers = _files.map((_) => TextEditingController()).toList();
  }

  String _inferMediaType(String path, {String? contentType}) {
    if (contentType != null) {
      if (contentType.startsWith('image/')) return 'image';
      if (contentType.startsWith('video/')) return 'video';
      if (contentType.startsWith('audio/')) return 'audio';
      return 'document';
    }
    final ext = path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)) return 'image';
    if (['mp4', '3gp', 'mov'].contains(ext)) return 'video';
    return 'document';
  }

  String _contentTypeForFile(File file) {
    if (widget.contentType != null && _files.length == 1) return widget.contentType!;
    final ext = file.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      case 'mp4': return 'video/mp4';
      case '3gp': return 'video/3gpp';
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default: return 'application/octet-stream';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _captionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _removeFile(int index) {
    if (_files.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _files.removeAt(index);
      _captionControllers[index].dispose();
      _captionControllers.removeAt(index);
      if (_currentIndex >= _files.length) {
        _currentIndex = _files.length - 1;
      }
    });
  }

  void _send() {
    // Return a list of {file, caption, contentType} maps for multi-file,
    // or just the caption string for single-file legacy mode.
    if (widget.files != null) {
      final results = <Map<String, dynamic>>[];
      for (int i = 0; i < _files.length; i++) {
        results.add({
          'file': _files[i],
          'caption': _captionControllers[i].text.trim(),
          'contentType': _contentTypeForFile(_files[i]),
        });
      }
      Navigator.pop(context, results);
    } else {
      // Legacy single-file: return caption string
      Navigator.pop(context, _captionControllers[0].text.trim());
    }
  }

  IconData _fileIcon(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc': case 'docx': return Icons.description;
      case 'xls': case 'xlsx': return Icons.table_chart;
      default: return Icons.insert_drive_file;
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
        title: _files.length > 1
            ? Text(
                '${_currentIndex + 1} of ${_files.length}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : Text(
                _files.first.path.split('/').last,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () => _removeFile(_currentIndex),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview area
          Expanded(
            child: _files.length == 1
                ? _buildPreview(_files[0])
                : PageView.builder(
                    controller: _pageController,
                    itemCount: _files.length,
                    onPageChanged: (index) => setState(() => _currentIndex = index),
                    itemBuilder: (context, index) => _buildPreview(_files[index]),
                  ),
          ),

          // Thumbnail strip (multi-select only)
          if (_files.length > 1)
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.black,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final isActive = index == _currentIndex;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(index,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive ? AppColors.accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _mediaType == 'image'
                          ? Image.file(_files[index], fit: BoxFit.cover)
                          : Container(
                              color: Colors.white10,
                              child: Icon(
                                _mediaType == 'video' ? Icons.videocam : Icons.insert_drive_file,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),

          // File size indicator
          FutureBuilder<int>(
            future: _files[_currentIndex].length(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final sizeBytes = snapshot.data!;
              final sizeMB = sizeBytes / (1024 * 1024);
              final sizeText = MediaCompressor.formatSize(sizeBytes);
              final isDocument = _mediaType == 'document';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(sizeText, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                    if (sizeMB > 14 && !isDocument) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 14),
                      const SizedBox(width: 4),
                      const Text('Large file, will be compressed', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ],
                    if (sizeMB > 16 && isDocument) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 14),
                      const SizedBox(width: 4),
                      const Text('Exceeds 16MB limit', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                    ],
                  ],
                ),
              );
            },
          ),

          // Caption input + send button
          SafeArea(
            child: Container(
              color: ThemeProvider.instance.colors.background,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _captionControllers[_currentIndex],
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Add a caption...',
                        hintStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                        filled: true,
                        fillColor: ThemeProvider.instance.colors.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(File file) {
    switch (_mediaType) {
      case 'image':
        return Center(
          child: InteractiveViewer(
            child: Image.file(file, fit: BoxFit.contain),
          ),
        );
      case 'video':
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: ThemeProvider.instance.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.videocam, size: 56, color: AppColors.accent),
              ),
              const SizedBox(height: 16),
              Text(
                file.path.split('/').last,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              FutureBuilder<int>(
                future: file.length(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final mb = snap.data! / (1024 * 1024);
                  return Text(
                    '${mb.toStringAsFixed(1)} MB',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  );
                },
              ),
            ],
          ),
        );
      default:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: ThemeProvider.instance.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(_fileIcon(file.path), size: 56, color: AppColors.accent),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  file.path.split('/').last,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              FutureBuilder<int>(
                future: file.length(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final mb = snap.data! / (1024 * 1024);
                  return Text(
                    '${mb.toStringAsFixed(1)} MB',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  );
                },
              ),
            ],
          ),
        );
    }
  }
}
