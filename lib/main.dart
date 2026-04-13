import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';

/// Whether Firebase was successfully initialized
bool firebaseAvailable = false;

// Top-level background handler — shows notification for data-only messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message received: ${message.data}');

  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await plugin.initialize(initSettings);

  final title = message.data['contactName'] ?? 'New message';
  final body = message.data['messageBody'] ?? 'New message received';
  final conversationId = message.data['conversationId'];

  await plugin.show(
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // On iOS, FirebaseApp.configure() is called in AppDelegate.swift
    // This Dart call connects to the already-initialized native instance
    await Firebase.initializeApp();
    firebaseAvailable = true;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase init failed (push notifications disabled): $e');
  }

  runApp(const ProviderScope(child: App()));
}
