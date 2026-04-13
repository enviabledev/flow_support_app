import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/conversation.dart';
import '../utils/time_formatter.dart';
import 'avatar.dart';
import 'unread_badge.dart';

class ChatListItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMultiSelectStart;
  final String? typingStaffName;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isUploading;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
    this.onMultiSelectStart,
    this.typingStaffName,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isUploading = false,
  });

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return TimeFormatter.formatConversationTime(dateTime);
  }

  String _cleanPreview(String text) {
    // Strip WhatsApp markdown quote prefix to show only the reply text
    if (text.startsWith('> _"')) {
      final parts = text.split('\n\n');
      if (parts.length >= 2) return parts.sublist(1).join('\n\n');
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final contact = conversation.contact;
    final hasUnread = conversation.unreadCount > 0;
    final isTyping = typingStaffName != null;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : null,
        child: Row(
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: isSelected
                    ? Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                      )
                    : Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ThemeProvider.instance.colors.textSecondary, width: 2),
                        ),
                      ),
              ),
            Avatar(
              name: contact.nameOrPhone,
              imageUrl: contact.profileImageUrl,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.nameOrPhone,
                          style: AppTypography.contactName(ThemeProvider.instance.colors),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.isStarred)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.star, color: Color(0xFFF5C543), size: 14),
                        ),
                      Text(
                        _formatTime(conversation.lastMessageAt),
                        style: AppTypography.timestamp(ThemeProvider.instance.colors).copyWith(
                          color: hasUnread ? AppColors.accent : ThemeProvider.instance.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (!isTyping && conversation.isLastMessageOutgoing)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.done_all, size: 16, color: AppColors.tickGrey),
                        ),
                      Expanded(
                        child: isTyping
                            ? Text(
                                'typing...',
                                style: AppTypography.lastMessage(ThemeProvider.instance.colors).copyWith(
                                  color: AppColors.accent,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                              )
                            : isUploading
                            ? Row(
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Uploading media...',
                                    style: AppTypography.lastMessage(ThemeProvider.instance.colors).copyWith(color: AppColors.accent),
                                  ),
                                ],
                              )
                            : Text(
                                conversation.isLastMessageOutgoing
                                    ? '${conversation.lastMessageSenderName ?? "You"}: ${_cleanPreview(conversation.lastMessageText ?? '')}'
                                    : _cleanPreview(conversation.lastMessageText ?? ''),
                                style: AppTypography.lastMessage(ThemeProvider.instance.colors),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        UnreadBadge(count: conversation.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
