import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../main.dart' show firebaseAvailable;
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../widgets/avatar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBackground,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Avatar(name: user.name, imageUrl: user.avatarUrl, radius: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: AppTypography.contactName.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(user.email, style: AppTypography.lastMessage),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user.role.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: AppColors.divider, height: 32),
          SwitchListTile(
            title: const Text('Notifications', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Message notifications', style: TextStyle(color: AppColors.textSecondary)),
            value: true,
            activeTrackColor: AppColors.accent,
            onChanged: (_) {},
            secondary: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
          ),
          const Divider(color: AppColors.divider, height: 1),
          if (user?.isAdmin == true) ...[
            ListTile(
              leading: const Icon(Icons.people_outline, color: AppColors.textSecondary),
              title: const Text('Staff Management', style: TextStyle(color: AppColors.textPrimary)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () => context.push('/staff'),
            ),
            const Divider(color: AppColors.divider, height: 1),
          ],
          const Divider(color: AppColors.divider, height: 32),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.textSecondary),
            title: const Text('About', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Flow Support v1.0.0', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active, color: AppColors.textSecondary),
            title: const Text('Push Status', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(
              'Firebase: ${firebaseAvailable ? "OK" : "FAILED"}\nNotif: ${NotificationService().debugStatus}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const Divider(color: AppColors.divider, height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
