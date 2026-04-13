import 'dart:async';
import 'package:flutter/foundation.dart';

class PendingMessage {
  final String tempId;
  final String conversationId;
  String body;
  final DateTime createdAt;
  final String? replyToId;
  int remainingSeconds;

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

  PendingMessage? _pending;
  Timer? _countdownTimer;

  PendingMessage? get pending => _pending;
  bool get hasPending => _pending != null;

  /// Callback when message should actually be sent.
  Function(String conversationId, String body, String? replyToId)? onSend;

  /// Queue a message for the 2-minute hold.
  void queueMessage({
    required String conversationId,
    required String body,
    String? replyToId,
  }) {
    _cancelTimer();

    final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';

    _pending = PendingMessage(
      tempId: tempId,
      conversationId: conversationId,
      body: body,
      createdAt: DateTime.now(),
      replyToId: replyToId,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_pending == null) {
        timer.cancel();
        return;
      }

      _pending!.remainingSeconds--;
      notifyListeners();

      if (_pending!.remainingSeconds <= 0) {
        _dispatchMessage();
      }
    });

    notifyListeners();
  }

  /// Edit the pending message text.
  void editMessage(String newBody) {
    if (_pending != null) {
      _pending!.body = newBody;
      notifyListeners();
    }
  }

  /// Cancel (delete) the pending message.
  void cancelMessage() {
    _cancelTimer();
    _pending = null;
    notifyListeners();
  }

  /// Send immediately (skip remaining timer).
  void sendNow() {
    _dispatchMessage();
  }

  void _dispatchMessage() {
    if (_pending == null) return;

    final msg = _pending!;
    _cancelTimer();
    _pending = null;
    notifyListeners();

    onSend?.call(msg.conversationId, msg.body, msg.replyToId);
  }

  void _cancelTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }
}
