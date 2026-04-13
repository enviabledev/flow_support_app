import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0B0B0B);
  static const surface = Color(0xFF1A1A1A);
  static const chatBackground = Color(0xFF0B0B0B);
  static const incomingBubble = Color(0xFF1F2C34);
  static const outgoingBubble = Color(0xFF005C4B);
  static const textPrimary = Color(0xFFE9EDEF);
  static const textSecondary = Color(0xFF8696A0);
  static const accent = Color(0xFF00A884);
  static const inputBackground = Color(0xFF1F2C34);
  static const headerBackground = Color(0xFF1F2C34);
  static const divider = Color(0xFF222D34);
  static const unreadBadge = Color(0xFF00A884);
  static const linkColor = Color(0xFF53BDEB);
  static const danger = Color(0xFFEA4335);
  static const tickGrey = Color(0xFF8696A0);
  static const tickBlue = Color(0xFF53BDEB);
}

class AppTypography {
  static const chatMessage = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  static const timestamp = TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
  );
  static const contactName = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const lastMessage = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );
  static const headerTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
}

ThemeData appTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.headerBackground,
      elevation: 0,
      titleTextStyle: AppTypography.headerTitle,
      iconTheme: IconThemeData(color: AppColors.textSecondary),
    ),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      surface: AppColors.surface,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textSecondary,
    ),
    dividerColor: AppColors.divider,
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
  );
}
