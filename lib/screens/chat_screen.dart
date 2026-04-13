import 'dart:async';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/notification_service.dart';
import '../services/pending_message_service.dart';
import 'package:file_picker/file_picker.dart';
import '../config/theme.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../utils/time_formatter.dart';
import '../providers/conversations_provider.dart';
import '../providers/messages_provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'dart:io';
import '../providers/uploads_provider.dart';
import '../widgets/avatar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/uploading_bubble.dart';
import '../widgets/date_separator.dart';
import '../widgets/input_bar.dart';
import '../widgets/emoji_picker_overlay.dart';
import '../widgets/attachment_picker.dart';
import '../widgets/chat_wallpaper.dart';
import '../widgets/swipeable_message.dart';
import 'media_preview_screen.dart';
import 'broadcast_screen.dart';
import 'camera_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  bool _showEmojiPicker = false;
  bool _showScrollToBottom = false;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isSending = false;
  Message? _replyingTo;

  // Bound method references for proper listener cleanup
  late final void Function(dynamic) _boundNewMessage;
  late final void Function(dynamic) _boundMessageStatus;
  late final VoidCallback _boundPendingListener;

  @override
  void initState() {
    super.initState();

    _boundNewMessage = _handleNewMessage;
    _boundMessageStatus = _handleMessageStatus;
    _boundPendingListener = () {
      if (mounted) setState(() {});
    };

    // Always update the onSend callback to use the current screen's ref
    PendingMessageService.instance.onSend = _handlePendingSend;
    PendingMessageService.instance.addListener(_boundPendingListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagesProvider(widget.conversationId).notifier).loadMessages();
      _markRead();
      NotificationService().activeConversationId = widget.conversationId;

      final socket = SocketService();
      socket.on('new_message', _boundNewMessage);
      socket.on('message_status', _boundMessageStatus);
    });

    _scrollController.addListener(_onScroll);
  }

  void _handlePendingSend(String conversationId, String body, String? replyToId) async {
    try {
      await ref.read(messagesProvider(conversationId).notifier).sendMessage(
        body,
        replyToId: replyToId,
      );
      ref.read(conversationsProvider.notifier).updateLastMessage(conversationId, body);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 &&
          e.response?.data is Map &&
          e.response?.data['windowExpired'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Message not sent. Customer needs to message you first.'),
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 4),
          ));
        }
      }
    }
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 200;
    if (show != _showScrollToBottom) setState(() => _showScrollToBottom = show);
  }

  void _handleNewMessage(dynamic data) {
    final map = data as Map<String, dynamic>;
    final msgData = map['message'] as Map<String, dynamic>?;
    if (msgData == null) return;
    final message = Message.fromJson(msgData);
    if (message.conversationId == widget.conversationId) {
      ref.read(messagesProvider(widget.conversationId).notifier).addIncomingMessage(message);
      _markRead();

      // Update lastInboundAt locally when customer messages — clears 24h banner
      if (message.isIncoming) {
        ref.read(conversationsProvider.notifier).updateLastInbound(widget.conversationId);
      }

      // Auto-scroll to bottom when new message arrives
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _scrollController.offset < 300) {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });
    }
  }

  void _handleMessageStatus(dynamic data) {
    final map = data as Map<String, dynamic>;
    final messageId = map['messageId']?.toString();
    final status = map['status'] as String?;
    if (messageId != null && status != null) {
      ref.read(messagesProvider(widget.conversationId).notifier).updateMessageStatus(messageId, status);
    }
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      SocketService().emit('typing_start', {'conversationId': widget.conversationId});
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _isTyping = false;
      SocketService().emit('typing_stop', {'conversationId': widget.conversationId});
    });
  }

  void _markRead() {
    ApiService().markConversationRead(widget.conversationId);
    SocketService().markRead(widget.conversationId);
    ref.read(conversationsProvider.notifier).markRead(widget.conversationId);
  }

  void _sendMessage() {
    if (_isSending) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Block if a message is pending in THIS conversation
    final pending = PendingMessageService.instance.pending;
    if (pending != null && pending.conversationId == widget.conversationId) return;

    _typingTimer?.cancel();
    if (_isTyping) {
      _isTyping = false;
      SocketService().emit('typing_stop', {'conversationId': widget.conversationId});
    }
    _textController.clear();

    String messageToSend;
    if (_replyingTo != null) {
      String originalText = _getCleanMessageText(_replyingTo!.body ?? '');
      if (originalText.isEmpty && _replyingTo!.hasMedia) {
        final ct = _replyingTo!.mediaContentType ?? '';
        if (ct.startsWith('image/')) originalText = '📷 Photo';
        else if (ct.startsWith('audio/')) originalText = '🎵 Voice message';
        else if (ct.startsWith('video/')) originalText = '🎥 Video';
        else originalText = '📎 Document';
      }
      if (originalText.isEmpty) originalText = '[Message]';
      final originalTime = _formatReplyTimestamp(_replyingTo!.createdAt);
      final truncated = originalText.length > 150
          ? '${originalText.substring(0, 150)}...'
          : originalText;
      messageToSend = '> _"$truncated"_\n> _— ${originalTime}_\n\n$text';
    } else {
      messageToSend = text;
    }

    // Queue for 2-minute hold instead of sending immediately
    PendingMessageService.instance.queueMessage(
      conversationId: widget.conversationId,
      body: messageToSend,
      replyToId: _replyingTo?.id,
    );

    _clearReply();
  }

  /// Extract only the actual message text, stripping any quote blocks.
  String _getCleanMessageText(String body) {
    final doubleNewlineIndex = body.indexOf('\n\n');
    if (doubleNewlineIndex != -1) {
      final before = body.substring(0, doubleNewlineIndex);
      if (before.startsWith('>') || before.contains('> _"') || before.startsWith('_"')) {
        final actualText = body.substring(doubleNewlineIndex + 2).trim();
        if (actualText.isNotEmpty) return actualText;
      }
    }
    return body;
  }

  String _formatReplyTimestamp(DateTime dt) {
    return TimeFormatter.formatReplyTimestamp(dt);
  }

  void _setReplyTo(Message message) => setState(() => _replyingTo = message);
  void _clearReply() => setState(() => _replyingTo = null);

  void _scrollToBottom() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _openCamera() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (result != null && mounted) {
      final files = result['files'] as List<File>;
      final type = result['type'] as String;
      final mediaType = type == 'video' ? 'video' : 'image';

      _showMultiMediaPreview(files, mediaType);
    }
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AttachmentPicker(onGallery: _pickFromGallery, onFile: _pickFile),
    );
  }

  Future<void> _pickFromCamera() async {
    final photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (photo != null) _showMediaPreview(photo.path, photo.name, 'image/jpeg');
  }

  Future<void> _pickFromGallery() async {
    final images = await _imagePicker.pickMultiImage(imageQuality: 80);
    if (images.isNotEmpty) {
      _showMultiMediaPreview(
        images.map((x) => File(x.path)).toList(),
        'image',
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      final files = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
      if (files.isNotEmpty) {
        _showMultiMediaPreview(files, 'document');
      }
    }
  }

  Future<void> _showMultiMediaPreview(List<File> files, String mediaType) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaPreviewScreen(
          files: files,
          mediaType: mediaType,
        ),
      ),
    );
    if (result != null && result is List) {
      for (final item in result) {
        final file = item['file'] as File;
        final caption = item['caption'] as String;
        final contentType = item['contentType'] as String;
        _sendMediaWithProgress(file.path, file.path.split('/').last, contentType, caption);
      }
    }
  }

  Future<void> _showMediaPreview(String path, String filename, String contentType) async {
    final caption = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => MediaPreviewScreen(filePath: path, filename: filename, contentType: contentType)),
    );
    if (caption != null) {
      _sendMediaWithProgress(path, filename, contentType, caption);
    }
  }

  void _sendMediaWithProgress(String path, String filename, String contentType, String caption) {
    ref.read(uploadsProvider.notifier).startUpload(
      conversationId: widget.conversationId,
      path: path,
      filename: filename,
      contentType: contentType,
      caption: caption,
    );
  }

  void _sendVoiceNote(String path) {
    _sendMediaWithProgress(path, 'voice_note.m4a', 'audio/mp4', '');
  }

  void _forwardMessage(Message message) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BroadcastScreen(
          prefillBody: message.body,
          forwardMessageId: message.id,
        ),
      ),
    );
  }

  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'mp3': return 'audio/mpeg';
      case 'm4a': return 'audio/mp4';
      case 'ogg': return 'audio/ogg';
      case 'mp4': return 'video/mp4';
      default: return 'application/octet-stream';
    }
  }

  // --- Pending message UI ---

  void _showEditDialog(PendingMessage pending) {
    final controller = TextEditingController(text: pending.body);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeProvider.instance.colors.surface,
        title: Text('Edit message', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: ThemeProvider.instance.colors.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ThemeProvider.instance.colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              final newBody = controller.text.trim();
              if (newBody.isNotEmpty) {
                PendingMessageService.instance.editMessage(newBody);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingMessageBubble(PendingMessage pending) {
    final minutes = pending.remainingSeconds ~/ 60;
    final seconds = pending.remainingSeconds % 60;
    final timeText = '$minutes:${seconds.toString().padLeft(2, '0')}';

    // Strip quote formatting for display
    String displayBody = pending.body;
    final doubleNewline = displayBody.indexOf('\n\n');
    if (doubleNewline != -1 && displayBody.startsWith('>')) {
      displayBody = displayBody.substring(doubleNewline + 2).trim();
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // The message bubble
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              decoration: BoxDecoration(
                color: ThemeProvider.instance.colors.outgoingBubble,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayBody,
                    style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  // Timer + send now row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer, color: AppColors.accent, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              timeText,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => PendingMessageService.instance.sendNow(),
                        child: const Text(
                          'Send now',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Action buttons below the bubble
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Edit
                  GestureDetector(
                    onTap: () => _showEditDialog(pending),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ThemeProvider.instance.colors.inputBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, color: AppColors.accent, size: 14),
                          SizedBox(width: 4),
                          Text('Edit', style: TextStyle(color: AppColors.accent, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Delete
                  GestureDetector(
                    onTap: () => PendingMessageService.instance.cancelMessage(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.danger, size: 14),
                          SizedBox(width: 4),
                          Text('Delete', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Copy
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: pending.body));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied'), backgroundColor: AppColors.accent, duration: Duration(seconds: 1)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ThemeProvider.instance.colors.inputBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy, color: ThemeProvider.instance.colors.textSecondary, size: 14),
                          SizedBox(width: 4),
                          Text('Copy', style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: ThemeProvider.instance.colors.background,
        child: Row(
          children: [
            Icon(Icons.timer, color: ThemeProvider.instance.colors.textSecondary, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Message queued. Edit, delete, or wait to send.',
                style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_isTyping) SocketService().emit('typing_stop', {'conversationId': widget.conversationId});
    NotificationService().activeConversationId = null;
    SocketService().off('new_message', _boundNewMessage);
    SocketService().off('message_status', _boundMessageStatus);
    PendingMessageService.instance.removeListener(_boundPendingListener);
    ref.read(conversationsProvider.notifier).markRead(widget.conversationId);
    _scrollController.removeListener(_onScroll);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msgState = ref.watch(messagesProvider(widget.conversationId));
    final convState = ref.watch(conversationsProvider);
    final uploads = ref.watch(uploadsProvider);
    final activeUploads = uploads.values.where((u) => u.conversationId == widget.conversationId).toList();
    final conversation = convState.conversations.where((c) => c.id == widget.conversationId).firstOrNull;
    final contactName = conversation?.contact.nameOrPhone ?? 'Chat';

    final pendingService = PendingMessageService.instance;
    final pending = pendingService.pending;
    final hasPendingHere = pending != null && pending.conversationId == widget.conversationId;

    return Scaffold(
      backgroundColor: ThemeProvider.instance.colors.chatBackground,
      appBar: AppBar(
        backgroundColor: ThemeProvider.instance.colors.headerBackground,
        leadingWidth: 32,
        title: GestureDetector(
          onTap: () => context.push('/chats/${widget.conversationId}/contact'),
          child: Row(
            children: [
              Avatar(name: contactName, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contactName,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ThemeProvider.instance.colors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                    Consumer(builder: (_, ref, __) {
                      final typing = ref.watch(typingProvider);
                      final typingName = typing[widget.conversationId];
                      return Text(
                        typingName != null ? '$typingName is typing...' : 'online',
                        style: TextStyle(fontSize: 12, color: typingName != null ? AppColors.accent : ThemeProvider.instance.colors.textSecondary),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              conversation != null && conversation.isStarred ? Icons.star : Icons.star_border,
              color: conversation != null && conversation.isStarred
                  ? const Color(0xFFF5C543)
                  : ThemeProvider.instance.colors.textSecondary,
            ),
            onPressed: () {
              if (conversation == null) return;
              final newStarred = !conversation.isStarred;
              if (newStarred) {
                ApiService().starConversation(conversation.id);
              } else {
                ApiService().unstarConversation(conversation.id);
              }
              ref.read(conversationsProvider.notifier).updateStarred(conversation.id, newStarred);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: ThemeProvider.instance.colors.surface,
            itemBuilder: (_) => [const PopupMenuItem(value: 'contact', child: Text('Contact info'))],
            onSelected: (v) { if (v == 'contact') context.push('/chats/${widget.conversationId}/contact'); },
          ),
        ],
      ),
      body: Column(
        children: [
          // 24-hour window expired banner
          if (_isWindowExpired(conversation))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.danger.withValues(alpha: 0.15),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: AppColors.danger, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '24h window expired. Messages won\'t deliver until the customer messages you first.',
                      style: TextStyle(color: AppColors.danger, fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                const ChatWallpaper(),
                msgState.isLoading && msgState.messages.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n is ScrollEndNotification && _scrollController.position.extentAfter < 50) {
                            ref.read(messagesProvider(widget.conversationId).notifier).loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: (hasPendingHere ? 1 : 0) + activeUploads.length + msgState.messages.length,
                          itemBuilder: (context, index) {
                            // Pending message at the very top (index 0 = bottom of screen = newest)
                            if (hasPendingHere && index == 0) {
                              return _buildPendingMessageBubble(pending);
                            }

                            final adjustedIndex = hasPendingHere ? index - 1 : index;

                            // Active uploads
                            if (adjustedIndex < activeUploads.length) {
                              final upload = activeUploads[activeUploads.length - 1 - adjustedIndex];
                              return UploadingBubble(
                                upload: upload,
                                onRetry: () {
                                  ref.read(uploadsProvider.notifier).retryUpload(upload.tempId);
                                },
                              );
                            }

                            // Real messages
                            final msgIndex = adjustedIndex - activeUploads.length;
                            final message = msgState.messages[msgIndex];
                            final prevIdx = msgIndex + 1;
                            final prev = prevIdx < msgState.messages.length ? msgState.messages[prevIdx] : null;
                            final showTail = prev == null || prev.direction != message.direction;
                            final showDate = prev == null || !_isSameDay(message.createdAt, prev.createdAt);
                            final showSenderName = message.isOutgoing &&
                                (prev == null ||
                                 prev.direction != 'outbound' ||
                                 prev.senderId != message.senderId);

                            return Column(
                              children: [
                                if (showDate) DateSeparator(date: message.createdAt),
                                SwipeableMessage(
                                  onReply: () => _setReplyTo(message),
                                  child: MessageBubble(
                                    message: message,
                                    showTail: showTail,
                                    showSenderName: showSenderName,
                                    onRetry: message.isFailed
                                        ? () => ref.read(messagesProvider(widget.conversationId).notifier).sendMessage(message.body ?? '')
                                        : null,
                                    onReply: _setReplyTo,
                                    onForward: _forwardMessage,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                if (_showScrollToBottom)
                  Positioned(
                    bottom: 8, right: 16,
                    child: FloatingActionButton.small(
                      backgroundColor: ThemeProvider.instance.colors.surface,
                      onPressed: _scrollToBottom,
                      child: Icon(Icons.keyboard_arrow_down, color: ThemeProvider.instance.colors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          if (_replyingTo != null && !pendingService.hasPending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: ThemeProvider.instance.colors.surface,
              child: Row(
                children: [
                  Container(width: 4, height: 40, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_replyingTo!.senderType == 'contact' ? contactName : 'You',
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(_replyingTo!.body ?? '[Media]',
                          style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(icon: Icon(Icons.close, color: ThemeProvider.instance.colors.textSecondary, size: 20), onPressed: _clearReply,
                    padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ),
          // Input bar — only blocked in the conversation with the pending message
          if (hasPendingHere)
            _buildBlockedInputBar()
          else
            InputBar(
              controller: _textController,
              onSend: _sendMessage,
              onAttachment: _showAttachmentPicker,
              onCamera: _openCamera,
              onVoiceNoteSent: _sendVoiceNote,
              onTextChanged: _onTextChanged,
              onEmojiToggle: () {
                setState(() => _showEmojiPicker = !_showEmojiPicker);
                if (_showEmojiPicker) FocusScope.of(context).unfocus();
              },
              showEmojiPicker: _showEmojiPicker,
            ),
          if (_showEmojiPicker && !pendingService.hasPending) EmojiPickerOverlay(controller: _textController),
        ],
      ),
    );
  }

  bool _isWindowExpired(Conversation? conversation) {
    if (conversation == null) return true;
    final lastInbound = conversation.lastInboundAt;
    if (lastInbound == null) return true;
    return DateTime.now().toUtc().difference(lastInbound).inHours >= 23;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}
