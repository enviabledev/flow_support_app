import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/conversation.dart';
import '../providers/auth_provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/socket_provider.dart';
import '../providers/uploads_provider.dart';
import '../services/api_service.dart';
import '../services/permission_service.dart';
import '../widgets/chat_list_item.dart';
import '../widgets/search_bar.dart';
import 'broadcast_screen.dart';

enum ConversationFilter { all, unread, starred, read }

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedConversations = {};
  ConversationFilter _activeFilter = ConversationFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationsProvider.notifier).loadConversations();
      ref.read(socketProvider.notifier).setupListeners();
      PermissionService().requestAll(context);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedConversations.contains(id)) {
        _selectedConversations.remove(id);
        if (_selectedConversations.isEmpty) _isSelectionMode = false;
      } else {
        _selectedConversations.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedConversations.clear();
    });
  }

  List<Conversation> _applyFilters(List<Conversation> conversations) {
    // Text search
    var result = conversations;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((conv) {
        final name = conv.contact.nameOrPhone.toLowerCase();
        final lastMsg = (conv.lastMessageText ?? '').toLowerCase();
        return name.contains(query) || lastMsg.contains(query);
      }).toList();
    }
    // Category filter
    switch (_activeFilter) {
      case ConversationFilter.all:
        return result;
      case ConversationFilter.unread:
        return result.where((c) => c.unreadCount > 0).toList();
      case ConversationFilter.starred:
        return result.where((c) => c.isStarred).toList();
      case ConversationFilter.read:
        return result.where((c) => c.unreadCount == 0).toList();
    }
  }

  void _toggleStar(Conversation conversation) {
    final newStarred = !conversation.isStarred;
    // Update locally first for instant UI feedback
    ref.read(conversationsProvider.notifier).updateStarred(conversation.id, newStarred);
    // Then sync to server in background
    if (newStarred) {
      ApiService().starConversation(conversation.id);
    } else {
      ApiService().unstarConversation(conversation.id);
    }
  }

  void _showConversationActions(Conversation conversation) {
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
            ListTile(
              leading: Icon(
                conversation.isStarred ? Icons.star_border : Icons.star,
                color: AppColors.accent,
              ),
              title: Text(
                conversation.isStarred ? 'Unstar' : 'Star',
                style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggleStar(conversation);
              },
            ),
            if (conversation.unreadCount == 0)
              ListTile(
                leading: const Icon(Icons.markunread, color: AppColors.accent),
                title: Text('Mark as unread', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  // Update locally first for instant UI feedback
                  ref.read(conversationsProvider.notifier).updateUnread(conversation.id, 1);
                  // Then sync to server in background
                  ApiService().updateConversation(conversation.id, {'unread_count': 1});
                },
              ),
            ListTile(
              leading: Icon(Icons.checklist, color: ThemeProvider.instance.colors.textSecondary),
              title: Text('Select', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _isSelectionMode = true;
                  _selectedConversations.add(conversation.id);
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsProvider);
    final typing = ref.watch(typingProvider);
    final user = ref.watch(authProvider).user;
    final uploads = ref.watch(uploadsProvider);
    final filtered = _applyFilters(state.conversations);
    final unreadCount = state.conversations.where((c) => c.unreadCount > 0).length;

    return Scaffold(
      appBar: _isSearching
          ? null
          : _isSelectionMode
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _exitSelectionMode,
                  ),
                  title: Text(
                    '${_selectedConversations.length} selected',
                    style: const TextStyle(fontSize: 18),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.campaign, color: AppColors.accent),
                      tooltip: 'Broadcast to selected',
                      onPressed: () {
                        final ids = _selectedConversations.toList();
                        _exitSelectionMode();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BroadcastScreen(preSelectedIds: ids),
                          ),
                        );
                      },
                    ),
                  ],
                )
              : AppBar(
                  title: const Text('Flow Support'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.campaign_outlined),
                      tooltip: 'Broadcast message',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BroadcastScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => setState(() => _isSearching = true),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      color: ThemeProvider.instance.colors.surface,
                      onSelected: (value) {
                        if (value == 'staff') context.push('/staff');
                      },
                      itemBuilder: (_) => [
                        if (user?.isAdmin == true)
                          const PopupMenuItem(
                            value: 'staff',
                            child: Text('Staff Management'),
                          ),
                      ],
                    ),
                  ],
                ),
      body: Column(
        children: [
          if (_isSearching)
            ChatSearchBar(
              controller: _searchController,
              onChanged: (q) => setState(() => _searchQuery = q),
              onClose: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
          // Filter chips
          if (!_isSelectionMode)
            Container(
              height: 52,
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildChip('All', ConversationFilter.all, null),
                  const SizedBox(width: 8),
                  _buildChip('Unread', ConversationFilter.unread, unreadCount),
                  const SizedBox(width: 8),
                  _buildChip('Starred', ConversationFilter.starred, null),
                  const SizedBox(width: 8),
                  _buildChip('Read', ConversationFilter.read, null),
                ],
              ),
            ),
          Expanded(
            child: state.isLoading && state.conversations.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : state.error != null && state.conversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Failed to load conversations',
                              style: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => ref.read(conversationsProvider.notifier).loadConversations(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.accent,
                        onRefresh: () => ref.read(conversationsProvider.notifier).loadConversations(),
                        child: filtered.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 200),
                                  Center(
                                    child: Text(
                                      _activeFilter == ConversationFilter.all
                                          ? 'No conversations'
                                          : 'No ${_activeFilter.name} conversations',
                                      style: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final conv = filtered[index];
                                  return Dismissible(
                                    key: Key('star_${conv.id}'),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (_) async {
                                      _toggleStar(conv);
                                      return false;
                                    },
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 24),
                                      color: conv.isStarred
                                          ? ThemeProvider.instance.colors.textSecondary
                                          : AppColors.accent,
                                      child: Icon(
                                        conv.isStarred ? Icons.star_border : Icons.star,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    child: ChatListItem(
                                      conversation: conv,
                                      typingStaffName: typing[conv.id],
                                      isSelectionMode: _isSelectionMode,
                                      isSelected: _selectedConversations.contains(conv.id),
                                      isUploading: uploads.values.any((u) => u.conversationId == conv.id && !u.failed),
                                      onTap: () {
                                        if (_isSelectionMode) {
                                          _toggleSelection(conv.id);
                                        } else {
                                          context.push('/chats/${conv.id}');
                                        }
                                      },
                                      onLongPress: () {
                                        if (!_isSelectionMode) {
                                          _showConversationActions(conv);
                                        }
                                      },
                                      ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/new-chat'),
        child: const Icon(Icons.message),
      ),
    );
  }

  Widget _buildChip(String label, ConversationFilter filter, int? count) {
    final isActive = _activeFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : ThemeProvider.instance.colors.inputBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (filter == ConversationFilter.starred && isActive)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.star, color: Colors.white, size: 14),
              ),
            Text(
              count != null && count > 0 ? '$label ($count)' : label,
              style: TextStyle(
                color: isActive ? Colors.white : ThemeProvider.instance.colors.textSecondary,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
