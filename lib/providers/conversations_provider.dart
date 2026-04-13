import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class ConversationsState {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? error;

  const ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  ConversationsState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final ApiService _api;
  final CacheService _cache;
  DateTime _lastSyncedAt = DateTime.now();

  ConversationsNotifier(this._api, this._cache) : super(const ConversationsState());

  Future<void> loadConversations() async {
    if (state.conversations.isEmpty) {
      try {
        final cached = await _cache.getCachedConversations();
        if (cached.isNotEmpty) {
          state = state.copyWith(conversations: cached);
        }
      } catch (_) {}
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.getConversations();
      final data = response.data;
      final List<dynamic> list = data is List ? data : (data['conversations'] ?? data['data'] ?? []);
      final conversations = list
          .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
          .toList();
      _sortConversations(conversations);
      state = state.copyWith(conversations: conversations, isLoading: false);
      _lastSyncedAt = DateTime.now();
      _cache.cacheConversations(conversations);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Lightweight sync — fetches only conversations updated since last sync
  Future<void> syncSince() async {
    try {
      final since = _lastSyncedAt.toUtc().toIso8601String();
      final response = await _api.syncConversations(since);
      final data = response.data;
      final List<dynamic> list = data is List ? data : (data['conversations'] ?? data['data'] ?? []);
      if (list.isEmpty) return;

      final updated = list.map((json) => Conversation.fromJson(json as Map<String, dynamic>)).toList();
      final currentMap = {for (var c in state.conversations) c.id: c};
      for (var conv in updated) {
        currentMap[conv.id] = conv;
      }
      final merged = currentMap.values.toList();
      _sortConversations(merged);
      state = state.copyWith(conversations: merged);
      _lastSyncedAt = DateTime.now();
    } catch (_) {
      // Sync failed — do a full fetch
      await loadConversations();
    }
  }

  void updateConversationFromSocket(Map<String, dynamic> data) {
    final conversationId = data['conversationId']?.toString();
    if (conversationId == null) return;

    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0) {
      loadConversations();
      return;
    }

    final updated = List<Conversation>.from(state.conversations);
    updated[index] = updated[index].copyWith(
      lastMessageText: data['lastMessage'] as String?,
      lastMessageAt: data['lastMessageAt'] != null
          ? DateTime.tryParse(data['lastMessageAt'] as String)
          : DateTime.now(),
      unreadCount: data['unreadCount'] as int?,
    );
    _sortConversations(updated);
    state = state.copyWith(conversations: updated);
  }

  void updateLastMessage(String conversationId, String text) {
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0) return;
    final updated = List<Conversation>.from(state.conversations);
    updated[index] = updated[index].copyWith(
      lastMessageText: text,
      lastMessageAt: DateTime.now(),
      lastMessageDirection: 'outbound',
    );
    _sortConversations(updated);
    state = state.copyWith(conversations: updated);
  }

  void markRead(String conversationId) {
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0) return;
    final updated = List<Conversation>.from(state.conversations);
    updated[index] = updated[index].copyWith(unreadCount: 0);
    state = state.copyWith(conversations: updated);
  }

  void updateStarred(String conversationId, bool isStarred) {
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0) return;
    final updated = List<Conversation>.from(state.conversations);
    updated[index] = updated[index].copyWith(isStarred: isStarred);
    state = state.copyWith(conversations: updated);
  }

  void updateUnread(String conversationId, int count) {
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0) return;
    final updated = List<Conversation>.from(state.conversations);
    updated[index] = updated[index].copyWith(unreadCount: count);
    state = state.copyWith(conversations: updated);
  }

  void updateLastInbound(String conversationId) {
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0) return;
    final updated = List<Conversation>.from(state.conversations);
    updated[index] = updated[index].copyWith(lastInboundAt: DateTime.now().toUtc());
    state = state.copyWith(conversations: updated);
  }

  Future<void> archiveConversation(String id) async {
    try {
      await _api.updateConversation(id, {'isArchived': true});
      final updated = state.conversations.where((c) => c.id != id).toList();
      state = state.copyWith(conversations: updated);
    } catch (_) {}
  }

  void _sortConversations(List<Conversation> list) {
    list.sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime(2000);
      final bTime = b.lastMessageAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
  }
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  return ConversationsNotifier(ApiService(), CacheService());
});

// Separate typing state — doesn't trigger conversation list rebuilds
class TypingNotifier extends StateNotifier<Map<String, String>> {
  TypingNotifier() : super({});

  void setTyping(String conversationId, String? staffName) {
    if (staffName != null) {
      state = {...state, conversationId: staffName};
    } else {
      final updated = Map<String, String>.from(state);
      updated.remove(conversationId);
      state = updated;
    }
  }
}

final typingProvider = StateNotifierProvider<TypingNotifier, Map<String, String>>((ref) {
  return TypingNotifier();
});
