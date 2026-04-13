import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/message.dart';
import '../utils/link_detector.dart';
import '../utils/time_formatter.dart';
import '../services/media_download_service.dart';
import 'delivery_ticks.dart';
import 'link_preview_bubble.dart';
import 'rich_message_text.dart';
import 'voice_note_bubble.dart';
import 'full_screen_image.dart';
import '../screens/video_player_screen.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool showTail;
  final bool showSenderName;
  final VoidCallback? onRetry;
  final void Function(Message)? onReply;
  final void Function(Message)? onForward;
  final void Function(String messageId)? onTapReply;

  const MessageBubble({
    super.key,
    required this.message,
    this.showTail = false,
    this.showSenderName = false,
    this.onRetry,
    this.onReply,
    this.onForward,
    this.onTapReply,
  });

  static const _agentColors = [
    Color(0xFF00A884), // Green
    Color(0xFF53BDEB), // Blue
    Color(0xFFF5C543), // Yellow/gold
    Color(0xFFFF6B6B), // Coral
    Color(0xFFAB7BFF), // Purple
    Color(0xFFFF9F43), // Orange
    Color(0xFF1DD1A1), // Teal
    Color(0xFFFF6B81), // Pink
  ];

  Color _getAgentColor(String name) {
    final index = name.hashCode.abs() % _agentColors.length;
    return _agentColors[index];
  }

  bool get _isImage {
    final ct = message.mediaContentType ?? '';
    final url = (message.mediaUrl ?? '').toLowerCase();
    return ct.startsWith('image/') ||
        url.endsWith('.jpg') || url.endsWith('.jpeg') ||
        url.endsWith('.png') || url.endsWith('.gif') || url.endsWith('.webp');
  }

  bool get _isAudio {
    final ct = message.mediaContentType ?? '';
    final url = (message.mediaUrl ?? '').toLowerCase();
    return ct.startsWith('audio/') || ct == 'application/ogg' ||
        url.endsWith('.ogg') || url.endsWith('.opus') ||
        url.endsWith('.m4a') || url.endsWith('.mp3') ||
        url.endsWith('.aac') || url.endsWith('.wav');
  }

  bool get _isVideo {
    final ct = message.mediaContentType ?? '';
    final url = (message.mediaUrl ?? '').toLowerCase();
    return ct.startsWith('video/') || url.endsWith('.mp4') || url.endsWith('.3gp');
  }

  bool get _isDocument => message.hasMedia && !_isImage && !_isAudio && !_isVideo;

  void _showUndeliveredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeProvider.instance.colors.surface,
        title: Row(
          children: [
            const Icon(Icons.error, color: AppColors.danger, size: 24),
            const SizedBox(width: 8),
            Text('Not delivered', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 18)),
          ],
        ),
        content: Text(
          'Message not delivered. The customer\'s 24-hour messaging window may have expired. Ask them to send you a message first, then resend.',
          style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.isOutgoing;
    final screenWidth = MediaQuery.of(context).size.width;

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isOutgoing || !showTail ? 12 : 2),
      topRight: Radius.circular(!isOutgoing || !showTail ? 12 : 2),
      bottomLeft: const Radius.circular(12),
      bottomRight: const Radius.circular(12),
    );

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
              margin: EdgeInsets.only(
                left: isOutgoing ? 60 : 16,
                right: isOutgoing ? 16 : 60,
                top: showTail ? 8 : 2,
                bottom: message.isUndelivered ? 0 : 2,
              ),
              padding: _isImage && (message.body == null || message.body!.isEmpty) && !message.hasReply
                  ? const EdgeInsets.all(3)
                  : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isOutgoing ? ThemeProvider.instance.colors.outgoingBubble : ThemeProvider.instance.colors.incomingBubble,
                borderRadius: borderRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Agent name (outbound only, first in consecutive group)
                  if (message.isOutgoing && showSenderName && message.senderName != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 4, left: _isImage ? 7 : 0),
                      child: Text(
                        message.senderName!,
                        style: TextStyle(
                          color: _getAgentColor(message.senderName!),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  // Media
                  if (message.hasMedia) _buildMedia(context),
                  // Message content with reply rendering
                  if (message.body != null && message.body!.isNotEmpty)
                    Padding(
                      padding: _isImage ? const EdgeInsets.only(left: 7, right: 7, top: 4) : EdgeInsets.zero,
                      child: _buildMessageContent(),
                    ),
                  const SizedBox(height: 2),
                  // Timestamp + ticks
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: _isImage && (message.body == null || message.body!.isEmpty)
                          ? const EdgeInsets.only(right: 6, bottom: 2)
                          : EdgeInsets.zero,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(TimeFormatter.formatMessageTime(message.createdAt), style: AppTypography.timestamp(ThemeProvider.instance.colors)),
                          if (isOutgoing) ...[
                            const SizedBox(width: 4),
                            DeliveryTicks(
                              status: message.status,
                              onRetry: onRetry,
                              onUndeliveredTap: () => _showUndeliveredDialog(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // "Not delivered" label below bubble for undelivered messages
            if (message.isUndelivered)
              GestureDetector(
                onTap: () => _showUndeliveredDialog(context),
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, top: 2, bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, size: 14, color: AppColors.danger),
                      const SizedBox(width: 4),
                      Text(
                        'Not delivered',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    final body = message.body ?? '';

    // Priority 1: Database-linked reply (has replyBody from server JOIN)
    if (message.hasReply) {
      final replyText = _stripAllQuotePrefixes(body);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReplyQuote(),
          _buildRichText(replyText),
        ],
      );
    }

    // Priority 2: Detect any WhatsApp-formatted quote in the body
    final quoteData = _parseQuotedMessage(body);
    if (quoteData != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildParsedQuoteBubble(quoteData['quote']!, quoteData['timestamp']!),
          _buildRichText(quoteData['reply']!),
        ],
      );
    }

    // Priority 3: Normal message with link detection and preview
    final urls = LinkDetector.extractUrls(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichMessageText(text: body, style: AppTypography.chatMessage(ThemeProvider.instance.colors)),
        if (urls.isNotEmpty)
          LinkPreviewBubble(url: urls.first, isOutgoing: message.isOutgoing),
      ],
    );
  }

  Widget _buildRichText(String text) {
    return RichMessageText(text: text, style: AppTypography.chatMessage(ThemeProvider.instance.colors));
  }

  /// Strip all quote formatting when we already have a database-linked reply bubble.
  String _stripAllQuotePrefixes(String body) {
    final doubleNewlineIndex = body.indexOf('\n\n');
    if (doubleNewlineIndex == -1) return body;
    final before = body.substring(0, doubleNewlineIndex);
    if (before.startsWith('>') || before.startsWith('_"') || before.startsWith('"') || before.contains('> _"')) {
      return body.substring(doubleNewlineIndex + 2).trim();
    }
    return body;
  }

  /// Robust parser that handles all quote format variations including nested quotes.
  Map<String, String>? _parseQuotedMessage(String body) {
    final doubleNewlineIndex = body.indexOf('\n\n');
    if (doubleNewlineIndex == -1) return null;

    final quoteBlock = body.substring(0, doubleNewlineIndex);
    final reply = body.substring(doubleNewlineIndex + 2).trim();
    if (reply.isEmpty) return null;
    if (!quoteBlock.startsWith('>')) return null;

    final lines = quoteBlock.split('\n');
    String quotedText = '';
    String timestamp = '';

    for (final line in lines) {
      String cleaned = line.trim();
      while (cleaned.startsWith('>')) {
        cleaned = cleaned.substring(1).trim();
      }

      // Timestamp line: starts with _— or —
      if (cleaned.startsWith('_—') || cleaned.startsWith('—')) {
        timestamp = cleaned
            .replaceFirst(RegExp(r'^_?—\s*'), '')
            .replaceAll(RegExp(r'_$'), '')
            .trim();
      } else {
        // Quoted text line — strip wrapping _" and "_
        cleaned = cleaned
            .replaceFirst(RegExp(r'^_?"'), '')
            .replaceFirst(RegExp(r'"_?$'), '')
            .replaceFirst(RegExp(r'^\s*_\s*"'), '')
            .replaceFirst(RegExp(r'"\s*_\s*$'), '')
            .trim();
        if (cleaned.isNotEmpty) {
          if (quotedText.isNotEmpty) quotedText += ' ';
          quotedText += cleaned;
        }
      }
    }

    if (quotedText.isEmpty) return null;
    return {'quote': quotedText, 'timestamp': timestamp, 'reply': reply};
  }

  Widget _buildParsedQuoteBubble(String quotedText, String timestamp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: message.isOutgoing
            ? Colors.black.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: const Border(left: BorderSide(color: AppColors.accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"$quotedText"',
            style: TextStyle(
              color: ThemeProvider.instance.colors.textSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (timestamp.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '— $timestamp',
                style: TextStyle(
                  color: ThemeProvider.instance.colors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyQuote() {
    return GestureDetector(
      onTap: () {
        if (message.replyToId != null) onTapReply?.call(message.replyToId!);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: message.isOutgoing
              ? Colors.black.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: AppColors.accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.replySenderType == 'contact'
                  ? (message.replySenderName ?? 'Customer')
                  : (message.replySenderName ?? 'Staff'),
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              message.replyBody!,
              style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeProvider.instance.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (message.body != null && message.body!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.copy, color: ThemeProvider.instance.colors.textSecondary),
                title: Text('Copy', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.body!));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied'), backgroundColor: AppColors.accent, duration: Duration(seconds: 1)),
                  );
                },
              ),
            ListTile(
              leading: Icon(Icons.reply, color: ThemeProvider.instance.colors.textSecondary),
              title: Text('Reply', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                onReply?.call(message);
              },
            ),
            ListTile(
              leading: Icon(Icons.forward, color: ThemeProvider.instance.colors.textSecondary),
              title: Text('Forward', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                onForward?.call(message);
              },
            ),
            // Share — works for all message types
            ListTile(
              leading: const Icon(Icons.share, color: AppColors.accent),
              title: Text('Share', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
              onTap: () async {
                Navigator.pop(ctx);
                if (message.hasMedia) {
                  final filename = Uri.tryParse(message.mediaUrl ?? '')?.pathSegments.lastOrNull ?? 'file';
                  try {
                    await MediaDownloadService().shareMedia(message.mediaUrl!, filename, caption: message.body);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: $e'), backgroundColor: AppColors.danger));
                    }
                  }
                } else if (message.body != null && message.body!.isNotEmpty) {
                  await MediaDownloadService().shareText(message.body!);
                }
              },
            ),
            if (message.hasMedia) ...[
              if (_isImage)
                ListTile(
                  leading: Icon(Icons.save_alt, color: ThemeProvider.instance.colors.textSecondary),
                  title: Text('Save to Gallery', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success = await MediaDownloadService().saveImageToGallery(message.mediaUrl!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(success ? 'Saved to gallery' : 'Failed to save'),
                        backgroundColor: success ? AppColors.accent : AppColors.danger,
                      ));
                    }
                  },
                ),
              if (_isVideo)
                ListTile(
                  leading: Icon(Icons.save_alt, color: ThemeProvider.instance.colors.textSecondary),
                  title: Text('Save Video', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success = await MediaDownloadService().saveVideoToGallery(message.mediaUrl!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(success ? 'Video saved' : 'Failed to save'),
                        backgroundColor: success ? AppColors.accent : AppColors.danger,
                      ));
                    }
                  },
                ),
              if (_isAudio || _isDocument)
                ListTile(
                  leading: Icon(Icons.file_download, color: ThemeProvider.instance.colors.textSecondary),
                  title: Text('Save to Downloads', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final filename = Uri.tryParse(message.mediaUrl ?? '')?.pathSegments.lastOrNull ?? 'file';
                    final path = await MediaDownloadService().saveToDownloads(message.mediaUrl!, filename);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(path != null ? 'Saved to Downloads' : 'Failed to save'),
                        backgroundColor: path != null ? AppColors.accent : AppColors.danger,
                      ));
                    }
                  },
                ),
              if (_isDocument)
                ListTile(
                  leading: Icon(Icons.open_in_new, color: ThemeProvider.instance.colors.textSecondary),
                  title: Text('Open with...', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final filename = Uri.tryParse(message.mediaUrl ?? '')?.pathSegments.lastOrNull ?? 'file';
                    await MediaDownloadService().openInExternalApp(message.mediaUrl!, filename);
                  },
                ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    if (_isImage) return _buildImageMedia(context);
    if (_isVideo) return _buildVideoMedia(context);
    if (_isAudio) return _buildAudioMedia();
    if (_isDocument) return _buildDocumentMedia(context);
    return _buildImageMedia(context);
  }

  Widget _buildImageMedia(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FullScreenImage(imageUrl: message.mediaUrl!, caption: message.body),
        ));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: message.mediaUrl!,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, __) => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
          ),
          errorWidget: (_, __, ___) => SizedBox(
            height: 200,
            child: Center(child: Icon(Icons.broken_image, color: ThemeProvider.instance.colors.textSecondary, size: 48)),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMedia(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(videoUrl: message.mediaUrl!, caption: message.body),
        ));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          height: 200,
          color: Colors.black.withValues(alpha: 0.7),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.videocam, color: Colors.white.withValues(alpha: 0.4), size: 40),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('Video', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioMedia() {
    return SizedBox(
      width: 220,
      child: VoiceNoteBubble(audioUrl: message.mediaUrl!, isOutgoing: message.isOutgoing),
    );
  }

  Widget _buildDocumentMedia(BuildContext context) {
    final filename = Uri.tryParse(message.mediaUrl ?? '')?.pathSegments.lastOrNull ?? 'Document';
    final ext = filename.split('.').last.toLowerCase();
    final docColor = _docTypeColor(ext);

    return GestureDetector(
      onTap: () async {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Opening $filename...'),
          ]),
          backgroundColor: ThemeProvider.instance.colors.headerBackground,
          duration: const Duration(seconds: 5),
        ));
        final success = await MediaDownloadService().openInExternalApp(message.mediaUrl!, filename);
        if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No app available to open this file'),
            backgroundColor: AppColors.danger,
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ThemeProvider.instance.colors.background.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: docColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_docTypeIcon(ext), color: docColor, size: 24),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(filename, style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(_docTypeLabel(ext), style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new, color: ThemeProvider.instance.colors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  IconData _docTypeIcon(String ext) {
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc': case 'docx': return Icons.description;
      case 'xls': case 'xlsx': case 'csv': return Icons.table_chart;
      case 'ppt': case 'pptx': return Icons.slideshow;
      case 'zip': case 'rar': case '7z': return Icons.folder_zip;
      case 'txt': return Icons.text_snippet;
      default: return Icons.insert_drive_file;
    }
  }

  Color _docTypeColor(String ext) {
    switch (ext) {
      case 'pdf': return const Color(0xFFE24B4A);
      case 'doc': case 'docx': return const Color(0xFF378ADD);
      case 'xls': case 'xlsx': case 'csv': return const Color(0xFF1D9E75);
      case 'ppt': case 'pptx': return const Color(0xFFD85A30);
      default: return ThemeProvider.instance.colors.textSecondary;
    }
  }

  String _docTypeLabel(String ext) {
    switch (ext) {
      case 'pdf': return 'PDF Document';
      case 'doc': case 'docx': return 'Word Document';
      case 'xls': case 'xlsx': return 'Excel Spreadsheet';
      case 'csv': return 'CSV File';
      case 'ppt': case 'pptx': return 'PowerPoint';
      case 'zip': case 'rar': case '7z': return 'Archive';
      case 'txt': return 'Text File';
      default: return ext.toUpperCase();
    }
  }
}
