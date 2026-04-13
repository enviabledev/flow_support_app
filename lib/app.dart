import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
// ThemeProvider, buildAppTheme imported via config/theme.dart
import 'providers/conversations_provider.dart';
import 'router/app_router.dart';
import 'services/notification_service.dart';
import 'services/socket_service.dart';
import 'services/storage_service.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notif = NotificationService();
      notif.onNotificationTap = (conversationId) {
        router.go('/chats/$conversationId');
      };
      notif.onRefreshConversations = () {
        try {
          ref.read(conversationsProvider.notifier).syncSince();
        } catch (_) {}
      };
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.authenticated) {
        // Sync missed messages
        ref.read(conversationsProvider.notifier).syncSince();

        // Reconnect socket if it died
        final socket = SocketService.instance;
        if (!socket.isConnected) {
          StorageService.getToken().then((token) {
            if (token != null) socket.connect(token);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, _) {
        final tp = ThemeProvider.instance;
        return MaterialApp.router(
          title: 'Flow Support',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(tp.isDark, tp.colors),
          routerConfig: router,
        );
      },
    );
  }
}
