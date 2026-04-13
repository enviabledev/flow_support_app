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
            color: ThemeProvider.instance.colors.headerBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            TimeFormatter.formatDateSeparator(date),
            style: TextStyle(
              color: ThemeProvider.instance.colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
