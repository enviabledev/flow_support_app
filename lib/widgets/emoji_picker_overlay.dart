import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../config/theme.dart';

class EmojiPickerOverlay extends StatelessWidget {
  final TextEditingController controller;

  const EmojiPickerOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: EmojiPicker(
        textEditingController: controller,
        config: Config(
          height: 260,
          emojiViewConfig: EmojiViewConfig(
            backgroundColor: ThemeProvider.instance.colors.background,
            columns: 8,
            emojiSizeMax: 28,
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: ThemeProvider.instance.colors.surface,
            indicatorColor: AppColors.accent,
            iconColorSelected: AppColors.accent,
            iconColor: ThemeProvider.instance.colors.textSecondary,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: ThemeProvider.instance.colors.background,
            hintText: 'Search emoji...',
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: ThemeProvider.instance.colors.surface,
            buttonColor: AppColors.accent,
            buttonIconColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
