import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/socket_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final SocketService _socket;

  AuthNotifier(this._api, this._socket) : super(const AuthState()) {
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    final hasToken = await StorageService.hasToken();
    if (!hasToken) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final response = await _api.getMe();
      final user = User.fromJson(response.data['user'] ?? response.data);
      final token = await StorageService.getToken();
      if (token != null) _socket.connect(token);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      NotificationService().initialize();
    } catch (_) {
      await StorageService.clearToken();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      final response = await _api.login(email, password);
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);

      await StorageService.setToken(token);
      _socket.connect(token);

      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      NotificationService().initialize();
    } on DioException catch (e) {
      String message;
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        message = 'Connection timed out. Check your internet connection.';
      } else if (e.type == DioExceptionType.connectionError) {
        message = 'Cannot reach the server. Please try again later.';
      } else if (e.response?.statusCode == 401) {
        message = 'Invalid email or password.';
      } else if (e.response?.statusCode == 403) {
        message = 'Account is inactive. Contact your administrator.';
      } else {
        message = 'Login failed. Please check your connection and try again.';
      }
      state = state.copyWith(status: AuthStatus.error, error: message);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, error: 'Login failed. Please try again.');
    }
  }

  Future<void> logout() async {
    _socket.disconnect();
    await StorageService.clearToken();
    await CacheService().clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ApiService(), SocketService());
});
