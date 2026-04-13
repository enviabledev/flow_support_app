import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../models/conversation.dart';
import '../providers/conversations_provider.dart';
import '../services/api_service.dart';
import '../widgets/avatar.dart';

class BroadcastScreen extends ConsumerStatefulWidget {
  final String? prefillBody;
  final String? forwardMessageId;
  final List<String>? preSelectedIds;

  const BroadcastScreen({
    super.key,
    this.prefillBody,
    this.forwardMessageId,
    this.preSelectedIds,
  });

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  Set<String> _selectedConversationIds = {};
  String _searchQuery = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillBody != null) {
      _messageController.text = widget.prefillBody!;
    }
    if (widget.preSelectedIds != null) {
      _selectedConversationIds = widget.preSelectedIds!.toSet();
    }
  }

  List<Conversation> _filteredConversations(List<Conversation> conversations) {
    if (_searchQuery.isEmpty) return conversations;
    final q = _searchQuery.toLowerCase();
    return conversations.where((c) {
      return c.contact.nameOrPhone.toLowerCase().contains(q);
    }).toList();
  }

  void _toggleSelection(String conversationId) {
    setState(() {
      if (_selectedConversationIds.contains(conversationId)) {
        _selectedConversationIds.remove(conversationId);
      } else {
        _selectedConversationIds.add(conversationId);
      }
    });
  }

  void _selectAll(List<Conversation> filtered) {
    setState(() {
      // Only select non-expired contacts by default
      final nonExpiredIds = filtered.where((c) => !_isExpired(c)).map((c) => c.id).toSet();
      if (_selectedConversationIds.containsAll(nonExpiredIds)) {
        _selectedConversationIds.removeAll(filtered.map((c) => c.id));
      } else {
        _selectedConversationIds.addAll(nonExpiredIds);
      }
    });
  }

  bool _isExpired(Conversation convo) {
    final lastInbound = convo.lastInboundAt;
    if (lastInbound == null) return true;
    return DateTime.now().toUtc().difference(lastInbound).inHours >= 23;
  }

  int _countExpiredWindows(List<Conversation> conversations) {
    return _selectedConversationIds.where((id) {
      final convo = conversations.where((c) => c.id == id).firstOrNull;
      if (convo == null) return false;
      return _isExpired(convo);
    }).length;
  }

  Future<void> _sendBroadcast() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _selectedConversationIds.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final response = await ApiService().broadcast(
        body,
        _selectedConversationIds.toList(),
      );

      final data = response.data;
      final sent = data['sent'] as int;
      final total = data['total'] as int;
      final skipped = data['skipped'] as int? ?? 0;
      final failed = data['failed'] as int;

      if (mounted) {
        String message;
        Color bgColor;

        if (sent == 0 && skipped > 0) {
          message = 'No messages sent. All selected contacts have expired messaging windows.';
          bgColor = AppColors.danger;
        } else {
          message = 'Sent to $sent contact${sent == 1 ? '' : 's'}.';
          if (skipped > 0) message += ' $skipped skipped (24h window expired).';
          if (failed > 0) message += ' $failed failed.';
          bgColor = (skipped > 0 || failed > 0) ? const Color(0xFFE67E22) : AppColors.accent;
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          duration: const Duration(seconds: 4),
        ));

        ref.read(conversationsProvider.notifier).loadConversations();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Broadcast failed: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final convState = ref.watch(conversationsProvider);
    final allConversations = convState.conversations;
    final filtered = _filteredConversations(allConversations);
    final expiredCount = _selectedConversationIds.isNotEmpty
        ? _countExpiredWindows(allConversations)
        : 0;

    return Scaffold(
      backgroundColor: ThemeProvider.instance.colors.background,
      appBar: AppBar(
        backgroundColor: ThemeProvider.instance.colors.headerBackground,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Broadcast message',
              style: TextStyle(
                color: ThemeProvider.instance.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_selectedConversationIds.length} selected',
              style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _selectAll(filtered),
            child: Text(
              _selectedConversationIds.containsAll(filtered.map((c) => c.id))
                  ? 'Deselect all'
                  : 'Select all',
              style: const TextStyle(color: AppColors.accent, fontSize: 14),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Message compose area
          Container(
            padding: const EdgeInsets.all(12),
            color: ThemeProvider.instance.colors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message',
                  style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  minLines: 2,
                  style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Type your broadcast message...',
                    hintStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                    filled: true,
                    fillColor: ThemeProvider.instance.colors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),

          Divider(color: ThemeProvider.instance.colors.divider, height: 1),

          // 24-hour window warning
          if (expiredCount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$expiredCount contact${expiredCount == 1 ? '' : 's'} will be skipped (24-hour window expired). They need to message you first.',
                      style: const TextStyle(color: AppColors.danger, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Search contacts
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              onChanged: (q) => setState(() => _searchQuery = q),
              style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                prefixIcon: Icon(Icons.search, color: ThemeProvider.instance.colors.textSecondary),
                filled: true,
                fillColor: ThemeProvider.instance.colors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),

          // Contact list with selection
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final convo = filtered[index];
                final isSelected = _selectedConversationIds.contains(convo.id);
                final contactName = convo.contact.nameOrPhone;
                final expired = _isExpired(convo);

                return ListTile(
                  leading: Stack(
                    children: [
                      Avatar(name: contactName, imageUrl: convo.contact.profileImageUrl),
                      if (isSelected)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: ThemeProvider.instance.colors.background, width: 2),
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          contactName,
                          style: TextStyle(
                            color: ThemeProvider.instance.colors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (expired) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.schedule, color: Color(0xFFE67E22), size: 16),
                      ],
                    ],
                  ),
                  subtitle: expired
                      ? const Text(
                          'Window expired',
                          style: TextStyle(color: Color(0xFFE67E22), fontSize: 12),
                        )
                      : Text(
                          convo.contact.phoneNumber,
                          style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 12),
                        ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.accent, size: 24)
                      : Icon(Icons.circle_outlined, color: ThemeProvider.instance.colors.textSecondary, size: 24),
                  onTap: () => _toggleSelection(convo.id),
                );
              },
            ),
          ),

          // Selected contacts chips
          if (_selectedConversationIds.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: ThemeProvider.instance.colors.surface,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _selectedConversationIds.map((id) {
                  final convo = allConversations.where((c) => c.id == id).firstOrNull;
                  if (convo == null) return const SizedBox.shrink();
                  final name = convo.contact.nameOrPhone;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Chip(
                      label: Text(name, style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 12)),
                      backgroundColor: ThemeProvider.instance.colors.inputBackground,
                      deleteIcon: Icon(Icons.close, size: 16, color: ThemeProvider.instance.colors.textSecondary),
                      onDeleted: () => _toggleSelection(id),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Send button
          Container(
            padding: const EdgeInsets.all(12),
            color: ThemeProvider.instance.colors.surface,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_isSending ||
                        _selectedConversationIds.isEmpty ||
                        _messageController.text.trim().isEmpty)
                    ? null
                    : _sendBroadcast,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: _isSending
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Sending...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Send to ${_selectedConversationIds.length} contact${_selectedConversationIds.length == 1 ? "" : "s"}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
