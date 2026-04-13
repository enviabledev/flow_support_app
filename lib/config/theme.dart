import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Theme mode enum ──

enum AppThemeMode { light, dark, system }

// ── Dynamic color set (one instance per mode) ──

class AppColors {
  // Brand colors — identical in both modes
  static const Color brand = Color(0xFF0057FF);
  static const Color accent = Color(0xFF00A884);
  static const Color danger = Color(0xFFEA4335);
  static const Color linkColor = Color(0xFF53BDEB);
  static const Color tickGrey = Color(0xFF8696A0);
  static const Color tickBlue = Color(0xFF53BDEB);
  static const Color unreadBadge = Color(0xFF00A884);
  static const Color starGold = Color(0xFFF5C543);

  // Dynamic colors
  final Color background;
  final Color surface;
  final Color headerBackground;
  final Color inputBackground;
  final Color chatBackground;
  final Color incomingBubble;
  final Color outgoingBubble;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color chatWallpaper;
  final Color wallpaperIcon;

  const AppColors._({
    required this.background,
    required this.surface,
    required this.headerBackground,
    required this.inputBackground,
    required this.chatBackground,
    required this.incomingBubble,
    required this.outgoingBubble,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.chatWallpaper,
    required this.wallpaperIcon,
  });

  static const dark = AppColors._(
    background: Color(0xFF0B0B0B),
    surface: Color(0xFF1A1A1A),
    headerBackground: Color(0xFF1F2C34),
    inputBackground: Color(0xFF1F2C34),
    chatBackground: Color(0xFF0B0B0B),
    incomingBubble: Color(0xFF1F2C34),
    outgoingBubble: Color(0xFF005C4B),
    textPrimary: Color(0xFFE9EDEF),
    textSecondary: Color(0xFF8696A0),
    divider: Color(0xFF222D34),
    chatWallpaper: Color(0xFF0B141A),
    wallpaperIcon: Color(0xFF0D1A22),
  );

  static const light = AppColors._(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    headerBackground: Color(0xFF008069),
    inputBackground: Color(0xFFF0F2F5),
    chatBackground: Color(0xFFEFE7DC),
    incomingBubble: Color(0xFFFFFFFF),
    outgoingBubble: Color(0xFFD9FDD3),
    textPrimary: Color(0xFF111B21),
    textSecondary: Color(0xFF667781),
    divider: Color(0xFFE9EDEF),
    chatWallpaper: Color(0xFFEFE7DC),
    wallpaperIcon: Color(0xFFE4DCCF),
  );
}

// ── Typography (adapts via colors) ──

class AppTypography {
  static TextStyle chatMessage(AppColors c) => TextStyle(fontSize: 16, color: c.textPrimary);
  static TextStyle timestamp(AppColors c) => TextStyle(fontSize: 11, color: c.textSecondary);
  static TextStyle contactName(AppColors c) => TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.textPrimary);
  static TextStyle lastMessage(AppColors c) => TextStyle(fontSize: 14, color: c.textSecondary);
  static TextStyle headerTitle(AppColors c) => TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary);
}

// ── Theme provider (singleton with persistence) ──

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider instance = ThemeProvider._();
  ThemeProvider._();

  AppThemeMode _mode = AppThemeMode.dark;

  AppThemeMode get mode => _mode;

  AppColors get colors {
    switch (_mode) {
      case AppThemeMode.light:
        return AppColors.light;
      case AppThemeMode.dark:
        return AppColors.dark;
      case AppThemeMode.system:
        final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    }
  }

  bool get isDark {
    if (_mode == AppThemeMode.dark) return true;
    if (_mode == AppThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved != null) {
      _mode = AppThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeMode.dark,
      );
    }
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }
}

// ── BuildContext extension for easy access ──

extension ThemeContext on BuildContext {
  AppColors get appColors => ThemeProvider.instance.colors;
  bool get isDarkMode => ThemeProvider.instance.isDark;
}

// ── ThemeData builder ──

ThemeData buildAppTheme(bool isDark, AppColors colors) {
  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: colors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.headerBackground,
      foregroundColor: isDark ? colors.textPrimary : Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? colors.textPrimary : Colors.white,
      ),
      iconTheme: IconThemeData(color: isDark ? colors.textSecondary : Colors.white),
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            ),
    ),
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.brand,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colors.surface,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: colors.textSecondary,
    ),
    dividerColor: colors.divider,
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
  );
}
