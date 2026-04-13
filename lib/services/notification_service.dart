import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart' show firebaseAvailable;
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Currently active conversation ID — suppress notification for this one
  String? activeConversationId;

  /// Callback to navigate to a conversation on notification tap
  void Function(String conversationId)? onNotificationTap;

  /// Callback to refresh conversations data
  VoidCallback? onRefreshConversations;

  bool _initialized = false;

  /// Debug status — temporarily exposed so we can see what's happening on real devices
  String debugStatus = 'not started';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!firebaseAvailable) {
      debugStatus = 'Firebase not available';
      debugPrint('NotificationService: Firebase not available, skipping');
      return;
    }

    try {
      final fcm = FirebaseMessaging.instance;

      debugStatus = 'requesting permission...';
      // Request FCM permission
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugStatus = 'permission: ${settings.authorizationStatus}';
      debugPrint('NotificationService: FCM permission: ${settings.authorizationStatus}');

      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidSettings, iOS: darwinSettings);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('NotificationService: Notification tapped, payload: ${response.payload}');
          final conversationId = response.payload;
          if (conversationId != null && conversationId.isNotEmpty) {
            onNotificationTap?.call(conversationId);
          }
        },
      );

      // Create notification channel (Android 8+)
      const androidChannel = AndroidNotificationChannel(
        'whatsapp_messages',
        'WhatsApp Messages',
        description: 'Incoming WhatsApp customer messages',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
      debugPrint('NotificationService: Notification channel created');

      // On iOS, show notifications even when app is in foreground
      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      debugStatus = 'getting token...';
      // Get FCM token and register — don't await, let it run in background
      _registerFCMToken(fcm);

      // Listen for token refresh — this also fires when token first becomes available on iOS
      fcm.onTokenRefresh.listen((newToken) async {
        debugPrint('NotificationService: Token refreshed: ${newToken.substring(0, 20)}...');
        try {
          await ApiService().registerFcmToken(newToken);
          debugPrint('NotificationService: Refreshed token registered with backend');
        } catch (e) {
          debugPrint('NotificationService: Token refresh registration failed: $e');
        }
      });

      // Foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Background notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('NotificationService: Background notification tapped');
        final conversationId = message.data['conversationId'];
        if (conversationId != null) {
          onRefreshConversations?.call();
          onNotificationTap?.call(conversationId);
        }
      });

      // Check if app was opened from a killed-state notification
      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('NotificationService: App opened from killed-state notification');
        final conversationId = initialMessage.data['conversationId'];
        if (conversationId != null) {
          Future.delayed(const Duration(seconds: 1), () {
            onRefreshConversations?.call();
            onNotificationTap?.call(conversationId);
          });
        }
      }
    } catch (e) {
      debugPrint('NotificationService: initialization failed (notifications disabled): $e');
    }
  }

  Future<void> _registerFCMToken(FirebaseMessaging fcm) async {
    try {
      // On iOS, the APNs token must be available before we can get an FCM token.
      if (Platform.isIOS) {
        // Try immediately first
        String? apnsToken = await fcm.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('NotificationService: APNs token not ready, waiting...');
          // Wait up to 30 seconds
          for (int i = 0; i < 15; i++) {
            await Future.delayed(const Duration(seconds: 2));
            apnsToken = await fcm.getAPNSToken();
            if (apnsToken != null) break;
          }
        }
        if (apnsToken == null) {
          debugPrint('NotificationService: APNs token unavailable after 30s — will rely on onTokenRefresh');
          return;
        }
        debugPrint('NotificationService: APNs token received');
      }

      final token = await fcm.getToken();
      if (token != null) {
        debugStatus = 'registering token...';
        debugPrint('NotificationService: FCM Token: ${token.substring(0, 20)}...');
        await ApiService().registerFcmToken(token);
        debugStatus = 'token registered!';
        debugPrint('NotificationService: FCM token registered with backend');
      } else {
        debugStatus = 'FCM token is null';
        debugPrint('NotificationService: FCM getToken returned null');
      }
    } catch (e) {
      debugStatus = 'token error: $e';
      debugPrint('NotificationService: FCM token registration failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('NotificationService: Foreground message received');
    _showLocalNotification(message);
    onRefreshConversations?.call();
  }

  void _showLocalNotification(RemoteMessage message) {
    final conversationId = message.data['conversationId'];

    // Don't show notification if user is viewing this conversation
    if (conversationId == activeConversationId) {
      debugPrint('NotificationService: Suppressed — user is viewing this conversation');
      return;
    }

    final title = message.notification?.title ?? message.data['contactName'] ?? 'New message';
    final body = message.notification?.body ?? message.data['messageBody'] ?? message.data['body'] ?? 'New message received';

    debugPrint('NotificationService: Showing notification — $title: $body');

    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'whatsapp_messages',
          'WhatsApp Messages',
          channelDescription: 'Incoming WhatsApp messages',
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: conversationId,
    );
  }
}
