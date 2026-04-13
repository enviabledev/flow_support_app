import 'package:flutter/material.dart';
import '../config/theme.dart';

class ChatSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const ChatSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      color: ThemeProvider.instance.colors.headerBackground,
      padding: EdgeInsets.only(
        top: topPadding + 8,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: ThemeProvider.instance.colors.textSecondary),
            onPressed: onClose,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              style: TextStyle(color: ThemeProvider.instance.colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                filled: true,
                fillColor: ThemeProvider.instance.colors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
