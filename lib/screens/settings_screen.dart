import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../main.dart' show firebaseAvailable;
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../widgets/avatar.dart';

void _showThemePicker(BuildContext context) {
  final colors = ThemeProvider.instance.colors;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface,
      title: Text('Appearance', style: TextStyle(color: colors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _themeOption(ctx, 'Light', AppThemeMode.light, Icons.light_mode),
          _themeOption(ctx, 'Dark', AppThemeMode.dark, Icons.dark_mode),
          _themeOption(ctx, 'System default', AppThemeMode.system, Icons.settings_brightness),
        ],
      ),
    ),
  );
}

Widget _themeOption(BuildContext context, String label, AppThemeMode mode, IconData icon) {
  final isSelected = ThemeProvider.instance.mode == mode;
  final colors = ThemeProvider.instance.colors;
  return ListTile(
    leading: Icon(icon, color: isSelected ? AppColors.accent : colors.textSecondary),
    title: Text(label, style: TextStyle(
      color: colors.textPrimary,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
    )),
    trailing: isSelected ? const Icon(Icons.check, color: AppColors.accent) : null,
    onTap: () {
      ThemeProvider.instance.setMode(mode);
      Navigator.pop(context);
    },
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: ThemeProvider.instance.colors.background,
      appBar: AppBar(
        backgroundColor: ThemeProvider.instance.colors.headerBackground,
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
                          style: AppTypography.contactName(ThemeProvider.instance.colors).copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(user.email, style: AppTypography.lastMessage(ThemeProvider.instance.colors)),
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
          Divider(color: ThemeProvider.instance.colors.divider, height: 32),
          SwitchListTile(
            title: Text('Notifications', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
            subtitle: Text('Message notifications', style: TextStyle(color: ThemeProvider.instance.colors.textSecondary)),
            value: true,
            activeTrackColor: AppColors.accent,
            onChanged: (_) {},
            secondary: Icon(Icons.notifications_outlined, color: ThemeProvider.instance.colors.textSecondary),
          ),
          Divider(color: ThemeProvider.instance.colors.divider, height: 1),
          if (user?.isAdmin == true) ...[
            ListTile(
              leading: Icon(Icons.people_outline, color: ThemeProvider.instance.colors.textSecondary),
              title: Text('Staff Management', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
              trailing: Icon(Icons.chevron_right, color: ThemeProvider.instance.colors.textSecondary),
              onTap: () => context.push('/staff'),
            ),
            Divider(color: ThemeProvider.instance.colors.divider, height: 1),
          ],
          Divider(color: ThemeProvider.instance.colors.divider, height: 1),
          ListTile(
            leading: Icon(
              ThemeProvider.instance.isDark ? Icons.dark_mode : Icons.light_mode,
              color: ThemeProvider.instance.colors.textSecondary,
            ),
            title: Text('Appearance', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
            subtitle: Text(
              ThemeProvider.instance.mode == AppThemeMode.system
                  ? 'System default'
                  : ThemeProvider.instance.mode == AppThemeMode.dark
                      ? 'Dark'
                      : 'Light',
              style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: ThemeProvider.instance.colors.textSecondary),
            onTap: () => _showThemePicker(context),
          ),
          Divider(color: ThemeProvider.instance.colors.divider, height: 32),
          ListTile(
            leading: Icon(Icons.info_outline, color: ThemeProvider.instance.colors.textSecondary),
            title: Text('About', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
            subtitle: Text('Flow Support v1.0.0', style: TextStyle(color: ThemeProvider.instance.colors.textSecondary)),
          ),
          ListTile(
            leading: Icon(Icons.notifications_active, color: ThemeProvider.instance.colors.textSecondary),
            title: Text('Push Status', style: TextStyle(color: ThemeProvider.instance.colors.textPrimary)),
            subtitle: Text(
              'Firebase: ${firebaseAvailable ? "OK" : "FAILED"}\nNotif: ${NotificationService().debugStatus}',
              style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 12),
            ),
          ),
          Divider(color: ThemeProvider.instance.colors.divider, height: 32),
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
