import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class MessagesState {
  final List<Message> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  MessagesState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class MessagesNotifier extends StateNotifier<MessagesState> {
  final ApiService _api;
  final CacheService _cache;
  final String conversationId;

  MessagesNotifier(this._api, this._cache, this.conversationId) : super(const MessagesState());

  Future<void> loadMessages() async {
    // Show cached data immediately
    if (state.messages.isEmpty) {
      try {
        final cached = await _cache.getCachedMessages(conversationId);
        if (cached.isNotEmpty) {
          state = state.copyWith(messages: cached);
        }
      } catch (_) {}
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.getMessages(conversationId);
      final data = response.data;
      final List<dynamic> list = data is List ? data : (data['messages'] ?? data['data'] ?? []);
      final messages = list
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList();
      messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(
        messages: messages,
        isLoading: false,
        hasMore: messages.length >= 50,
      );

      // Cache in background
      _cache.cacheMessages(conversationId, messages);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.messages.isEmpty) return;
    state = state.copyWith(isLoading: true);

    try {
      final oldest = state.messages.last;
      final response = await _api.getMessages(
        conversationId,
        cursor: oldest.createdAt.toIso8601String(),
      );
      final data = response.data;
      final List<dynamic> list = data is List ? data : (data['messages'] ?? data['data'] ?? []);
      final older = list
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList();
      older.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(
        messages: [...state.messages, ...older],
        isLoading: false,
        hasMore: older.length >= 50,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void addOptimisticMessage(Message message) {
    state = state.copyWith(messages: [message, ...state.messages]);
  }

  void replaceOptimisticMessage(String tempId, Message real) {
    // Check if the real message already exists (socket beat the API response)
    final alreadyExists = state.messages.any((m) =>
      m.id != tempId && (
        m.id == real.id ||
        (m.twilioSid != null && m.twilioSid!.isNotEmpty && m.twilioSid == real.twilioSid)
      )
    );

    if (alreadyExists) {
      // Socket already added the real message, just remove the temp
      state = state.copyWith(messages: state.messages.where((m) => m.id != tempId).toList());
    } else {
      // Normal case: replace temp with real
      final updated = state.messages.map((m) => m.id == tempId ? real : m).toList();
      state = state.copyWith(messages: updated);
    }
  }

  void markMessageFailed(String tempId) {
    final updated = state.messages.map((m) {
      if (m.id == tempId) return m.copyWith(status: 'failed');
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  void addIncomingMessage(Message message) {
    if (message.conversationId != conversationId) return;

    // Deduplicate by ID
    if (state.messages.any((m) => m.id == message.id)) return;

    // Deduplicate by Twilio SID
    if (message.twilioSid != null && message.twilioSid!.isNotEmpty) {
      if (state.messages.any((m) => m.twilioSid == message.twilioSid)) return;
    }

    // Deduplicate by body + direction + timestamp (belt and suspenders)
    if (message.body != null && message.body!.isNotEmpty) {
      final isDuplicate = state.messages.any((m) =>
        !m.isOptimistic &&
        m.body == message.body &&
        m.direction == message.direction &&
        m.conversationId == message.conversationId &&
        m.createdAt.difference(message.createdAt).inSeconds.abs() < 3
      );
      if (isDuplicate) return;
    }

    // If this is an outbound message from the server, it may be the real version
    // of an optimistic message we already have. Replace instead of duplicating.
    if (message.isOutgoing) {
      final optimisticIndex = state.messages.indexWhere((m) {
        if (!m.isOptimistic) return false;
        if (m.body != null && m.body!.isNotEmpty && m.body == message.body) return true;
        if (m.mediaUrl != null && m.mediaUrl == message.mediaUrl) return true;
        if (m.mediaContentType != null &&
            m.mediaContentType == message.mediaContentType &&
            message.createdAt.difference(m.createdAt).inSeconds.abs() < 30) return true;
        return false;
      });
      if (optimisticIndex >= 0) {
        final updated = [...state.messages];
        updated[optimisticIndex] = message;
        state = state.copyWith(messages: updated);
        return;
      }
    }

    state = state.copyWith(messages: [message, ...state.messages]);
  }

  void updateMessageStatus(String messageId, String status) {
    final updated = state.messages.map((m) {
      if (m.id == messageId) return m.copyWith(status: status);
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  Future<void> sendMessage(String body, {String? mediaUrl, String? mediaContentType, String? replyToId}) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = Message(
      id: tempId,
      conversationId: conversationId,
      direction: 'outbound',
      senderType: 'staff',
      body: body,
      mediaUrl: mediaUrl,
      mediaContentType: mediaContentType,
      replyToId: replyToId,
      status: 'queued',
      createdAt: DateTime.now().toUtc(),
      isOptimistic: true,
    );

    addOptimisticMessage(optimistic);

    try {
      final response = await _api.sendMessage(conversationId, body, mediaUrl: mediaUrl, mediaContentType: mediaContentType, replyToId: replyToId);
      final data = response.data;
      final realMessage = Message.fromJson(
        (data is Map<String, dynamic>) ? (data['message'] ?? data) : data,
      );
      replaceOptimisticMessage(tempId, realMessage);
    } catch (e) {
      // Remove the optimistic message entirely for window expiry (not a real send attempt)
      if (e is DioException &&
          e.response?.statusCode == 400 &&
          e.response?.data is Map &&
          e.response?.data['windowExpired'] == true) {
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != tempId).toList(),
        );
        rethrow;
      }
      markMessageFailed(tempId);
    }
  }

  Future<void> sendMediaMessage(String filePath, String filename, String contentType, {String caption = ''}) async {
    try {
      final uploadResponse = await _api.uploadFile(filePath, filename);
      final url = uploadResponse.data['url'] as String;
      await sendMessage(caption, mediaUrl: url, mediaContentType: contentType);
    } catch (_) {
      // Upload failed
    }
  }
}

final messagesProvider = StateNotifierProvider.family<MessagesNotifier, MessagesState, String>(
  (ref, conversationId) {
    return MessagesNotifier(ApiService(), CacheService(), conversationId);
  },
);
