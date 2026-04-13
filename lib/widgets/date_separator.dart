import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/time_formatter.dart';

class DateSeparator extends StatelessWidget {
  final DateTime date;

  const DateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.isDarkMode
                ? ThemeProvider.instance.colors.headerBackground
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: context.isDarkMode
                ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2)],
          ),
          child: Text(
            TimeFormatter.formatDateSeparator(date),
            style: TextStyle(
              color: context.isDarkMode
                  ? ThemeProvider.instance.colors.textSecondary
                  : const Color(0xFF667781),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
