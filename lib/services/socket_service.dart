import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

class SocketService {
  static SocketService? _instance;
  io.Socket? _socket;
  bool _initialized = false;
  VoidCallback? onReconnectCallback;

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  // Keep factory for backward compat
  factory SocketService() => instance;
  SocketService._();

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    if (_initialized && _socket != null && _socket!.connected) return;

    // If socket exists but disconnected, just reconnect
    if (_initialized && _socket != null && !_socket!.connected) {
      _socket!.connect();
      return;
    }

    // First time or after logout — create new socket
    _socket?.dispose();

    _socket = io.io(AppConfig.wsUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'forceNew': false,
      'reconnection': true,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 5000,
      'reconnectionAttempts': 999999,
      'timeout': 30000,
      'auth': {'token': token},
    });

    _socket!.onConnect((_) {
      debugPrint('Socket: connected');
    });

    _socket!.onDisconnect((reason) {
      debugPrint('Socket: disconnected — $reason');
    });

    _socket!.onConnectError((error) {
      debugPrint('Socket: connection error');
    });

    _socket!.onReconnect((_) {
      debugPrint('Socket: reconnected — syncing data');
      onReconnectCallback?.call();
    });

    _socket!.onReconnectAttempt((attempt) {
      if (attempt % 5 == 0) debugPrint('Socket: reconnect attempt $attempt');
    });

    _socket!.connect();
    _initialized = true;
  }

  void on(String event, void Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  void off(String event, void Function(dynamic) callback) {
    _socket?.off(event, callback);
  }

  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  void markRead(String conversationId) {
    _socket?.emit('mark_read', {'conversationId': conversationId});
  }

  /// Only call on explicit logout
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _initialized = false;
    onReconnectCallback = null;
    _instance = null;
  }
}
