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
          emojiViewConfig: const EmojiViewConfig(
            backgroundColor: AppColors.background,
            columns: 8,
            emojiSizeMax: 28,
          ),
          categoryViewConfig: const CategoryViewConfig(
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.accent,
            iconColorSelected: AppColors.accent,
            iconColor: AppColors.textSecondary,
          ),
          searchViewConfig: const SearchViewConfig(
            backgroundColor: AppColors.background,
            hintText: 'Search emoji...',
          ),
          bottomActionBarConfig: const BottomActionBarConfig(
            backgroundColor: AppColors.surface,
            buttonColor: AppColors.accent,
            buttonIconColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
