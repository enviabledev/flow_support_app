import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/storage_service.dart';
import '../screens/login_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/contact_info_screen.dart';
import '../screens/new_chat_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/staff_management_screen.dart';
import '../widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) async {
    final hasToken = await StorageService.hasToken();
    final isLoginRoute = state.matchedLocation == '/login';

    if (!hasToken && !isLoginRoute) return '/login';
    if (hasToken && isLoginRoute) return '/chats';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/chats',
          builder: (_, __) => const ChatListScreen(),
          routes: [
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, state) => ChatScreen(
                conversationId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: ':id/contact',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, state) => ContactInfoScreen(
                conversationId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/new-chat',
      builder: (_, __) => const NewChatScreen(),
    ),
    GoRoute(
      path: '/staff',
      builder: (_, __) => const StaffManagementScreen(),
    ),
  ],
);
