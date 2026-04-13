import 'dart:async';
import 'package:flutter/foundation.dart';

class PendingMessage {
  final String tempId;
  final String conversationId;
  String body;
  final DateTime createdAt;
  final String? replyToId;
  int remainingSeconds;
  Timer? _timer;

  PendingMessage({
    required this.tempId,
    required this.conversationId,
    required this.body,
    required this.createdAt,
    this.replyToId,
    this.remainingSeconds = 120,
  });
}

class PendingMessageService extends ChangeNotifier {
  static final PendingMessageService instance = PendingMessageService._();
  PendingMessageService._();

  /// One pending message per conversation — fully independent.
  final Map<String, PendingMessage> _pending = {};

  /// Callback when message should actually be sent.
  Function(String conversationId, String body, String? replyToId)? onSend;

  /// Get the pending message for a specific conversation.
  PendingMessage? pendingFor(String conversationId) => _pending[conversationId];

  /// Check if a specific conversation has a pending message.
  bool hasPendingFor(String conversationId) => _pending.containsKey(conversationId);

  // Legacy getters — avoid using these, prefer conversation-scoped methods.
  PendingMessage? get pending => null; // deprecated
  bool get hasPending => _pending.isNotEmpty;

  /// Queue a message for the 2-minute hold in a specific conversation.
  void queueMessage({
    required String conversationId,
    required String body,
    String? replyToId,
  }) {
    // Cancel any existing pending in THIS conversation only
    _cancelFor(conversationId);

    final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';

    final msg = PendingMessage(
      tempId: tempId,
      conversationId: conversationId,
      body: body,
      createdAt: DateTime.now(),
      replyToId: replyToId,
    );

    msg._timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_pending.containsKey(conversationId)) {
        timer.cancel();
        return;
      }

      msg.remainingSeconds--;
      notifyListeners();

      if (msg.remainingSeconds <= 0) {
        _dispatchFor(conversationId);
      }
    });

    _pending[conversationId] = msg;
    notifyListeners();
  }

  /// Edit the pending message text for a conversation.
  void editMessage(String newBody, {String? conversationId}) {
    final key = conversationId ?? _pending.keys.firstOrNull;
    if (key == null) return;
    final msg = _pending[key];
    if (msg != null) {
      msg.body = newBody;
      notifyListeners();
    }
  }

  /// Cancel (delete) the pending message for a conversation.
  void cancelMessage({String? conversationId}) {
    final key = conversationId ?? _pending.keys.firstOrNull;
    if (key == null) return;
    _cancelFor(key);
    notifyListeners();
  }

  /// Send immediately (skip remaining timer) for a conversation.
  void sendNow({String? conversationId}) {
    final key = conversationId ?? _pending.keys.firstOrNull;
    if (key == null) return;
    _dispatchFor(key);
  }

  void _dispatchFor(String conversationId) {
    final msg = _pending[conversationId];
    if (msg == null) return;

    msg._timer?.cancel();
    _pending.remove(conversationId);
    notifyListeners();

    onSend?.call(msg.conversationId, msg.body, msg.replyToId);
  }

  void _cancelFor(String conversationId) {
    final msg = _pending.remove(conversationId);
    msg?._timer?.cancel();
  }
}
