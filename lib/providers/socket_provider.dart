import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../services/socket_service.dart';
import 'conversations_provider.dart';
import 'messages_provider.dart';

class SocketNotifier extends StateNotifier<bool> {
  final Ref ref;
  bool _listenersSetUp = false;

  SocketNotifier(this.ref) : super(false);

  void setupListeners() {
    if (_listenersSetUp) return;
    _listenersSetUp = true;

    final socket = SocketService.instance;

    // On reconnect — sync missed data
    socket.onReconnectCallback = () {
      ref.read(conversationsProvider.notifier).syncSince();
    };

    socket.on('new_message', _onNewMessage);
    socket.on('conversation_update', _onConversationUpdate);
    socket.on('contact_updated', _onContactUpdated);
    socket.on('typing_start', _onTypingStart);
    socket.on('typing_stop', _onTypingStop);

    state = true;
  }

  void _onNewMessage(dynamic data) {
    final map = data as Map<String, dynamic>;
    final messageData = map['message'] as Map<String, dynamic>?;
    if (messageData == null) return;

    final message = Message.fromJson(messageData);

    try {
      ref.read(messagesProvider(message.conversationId).notifier).addIncomingMessage(message);
    } catch (_) {}

    final convData = map['conversation'];
    if (convData != null && convData is Map<String, dynamic>) {
      final exists = ref.read(conversationsProvider).conversations.any((c) => c.id == message.conversationId);
      if (exists) {
        ref.read(conversationsProvider.notifier).updateConversationFromSocket({
          'conversationId': message.conversationId,
          'lastMessage': message.body ?? (message.hasMedia ? '📎 Media' : ''),
          'lastMessageAt': message.createdAt.toIso8601String(),
          'unreadCount': convData['unread_count'] ?? convData['unreadCount'],
        });
      } else {
        ref.read(conversationsProvider.notifier).loadConversations();
      }
    }
  }

  void _onConversationUpdate(dynamic data) {
    final map = data as Map<String, dynamic>;
    if (map['lastMessageAt'] == null) {
      map['lastMessageAt'] = DateTime.now().toIso8601String();
    }
    ref.read(conversationsProvider.notifier).updateConversationFromSocket(map);
  }

  void _onContactUpdated(dynamic data) {
    ref.read(conversationsProvider.notifier).loadConversations();
  }

  void _onTypingStart(dynamic data) {
    final map = data as Map<String, dynamic>;
    final convId = map['conversationId']?.toString();
    final staffName = map['staffName'] as String?;
    if (convId != null) ref.read(typingProvider.notifier).setTyping(convId, staffName);
  }

  void _onTypingStop(dynamic data) {
    final map = data as Map<String, dynamic>;
    final convId = map['conversationId']?.toString();
    if (convId != null) ref.read(typingProvider.notifier).setTyping(convId, null);
  }
}

final socketProvider = StateNotifierProvider<SocketNotifier, bool>((ref) {
  return SocketNotifier(ref);
});
