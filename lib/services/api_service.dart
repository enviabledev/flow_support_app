import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  late final Dio _dio;
  VoidCallback? onAuthError;

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          onAuthError?.call();
        }
        handler.next(error);
      },
    ));
  }

  // Auth
  Future<Response> login(String email, String password) {
    return _dio.post('/api/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> getMe() {
    return _dio.get('/api/auth/me');
  }

  Future<Response> registerFcmToken(String token) {
    return _dio.post('/api/auth/fcm-token', data: {'token': token});
  }

  // Conversations
  Future<Response> getConversations() {
    return _dio.get('/api/conversations');
  }

  Future<Response> syncConversations(String since) {
    return _dio.get('/api/conversations/sync', queryParameters: {'since': since});
  }

  Future<Response> createConversation(String contactId) {
    return _dio.post('/api/conversations', data: {'contactId': contactId});
  }

  Future<Response> getConversation(String id) {
    return _dio.get('/api/conversations/$id');
  }

  Future<Response> updateConversation(String id, Map<String, dynamic> data) {
    return _dio.patch('/api/conversations/$id', data: data);
  }

  Future<Response> markConversationRead(String id) {
    return _dio.patch('/api/conversations/$id/read');
  }

  Future<Response> starConversation(String id) {
    return _dio.post('/api/conversations/$id/star');
  }

  Future<Response> unstarConversation(String id) {
    return _dio.delete('/api/conversations/$id/star');
  }

  // Messages
  Future<Response> getMessages(String conversationId, {String? cursor, int limit = 50}) {
    final queryParams = <String, dynamic>{'limit': limit};
    if (cursor != null) queryParams['cursor'] = cursor;
    return _dio.get(
      '/api/conversations/$conversationId/messages',
      queryParameters: queryParams,
    );
  }

  Future<Response> sendMessage(String conversationId, String body, {String? mediaUrl, String? mediaContentType, String? replyToId}) {
    final data = <String, dynamic>{};
    if (body.isNotEmpty) data['body'] = body;
    if (mediaUrl != null) data['mediaUrl'] = mediaUrl;
    if (mediaContentType != null) data['mediaContentType'] = mediaContentType;
    if (replyToId != null) data['replyToId'] = replyToId;
    return _dio.post('/api/conversations/$conversationId/messages', data: data);
  }

  Future<Response> uploadFile(String filePath, String filename, {void Function(int, int)? onSendProgress}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });
    return _dio.post('/api/upload', data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
      ),
      onSendProgress: onSendProgress,
    );
  }

  // Broadcast
  Future<Response> broadcast(String body, List<String> conversationIds, {String? mediaUrl}) {
    final data = <String, dynamic>{
      'conversationIds': conversationIds,
    };
    if (body.isNotEmpty) data['body'] = body;
    if (mediaUrl != null) data['mediaUrl'] = mediaUrl;
    return _dio.post('/api/broadcast', data: data);
  }

  // Staff
  Future<Response> getStaff() {
    return _dio.get('/api/staff');
  }

  Future<Response> createStaff(Map<String, dynamic> data) {
    return _dio.post('/api/staff', data: data);
  }

  Future<Response> updateStaff(String id, Map<String, dynamic> data) {
    return _dio.patch('/api/staff/$id', data: data);
  }

  Future<Response> resetStaffPassword(String id, String password) {
    return _dio.patch('/api/staff/$id/password', data: {'password': password});
  }

  Future<Response> deleteStaff(String id) {
    return _dio.delete('/api/staff/$id');
  }

  // Contacts
  Future<Response> getContacts() {
    return _dio.get('/api/contacts');
  }

  Future<Response> updateContact(String id, Map<String, dynamic> data) {
    return _dio.patch('/api/contacts/$id', data: data);
  }
}

typedef VoidCallback = void Function();
