class TimeFormatter {
  /// Parse a timestamp from the API, always returning UTC DateTime.
  static DateTime parseUtc(dynamic value) {
    if (value == null) return DateTime.now().toUtc();
    if (value is String) {
      DateTime parsed = DateTime.parse(value);
      // If no timezone info, assume UTC
      if (!value.endsWith('Z') && !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value)) {
        parsed = DateTime.utc(
          parsed.year, parsed.month, parsed.day,
          parsed.hour, parsed.minute, parsed.second, parsed.millisecond,
        );
      }
      return parsed.toUtc();
    }
    return DateTime.now().toUtc();
  }

  /// Format time for message bubbles: "14:30"
  static String formatMessageTime(DateTime utcTime) {
    final local = utcTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Format time for conversation list: "14:30", "Yesterday", "Mon", "03/04/26"
  static String formatConversationTime(DateTime utcTime) {
    final local = utcTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(local.year, local.month, local.day);

    if (messageDate == today) {
      return formatMessageTime(utcTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${(local.year % 100).toString().padLeft(2, '0')}';
    }
  }

  /// Format for date separators in chat: "Today", "Yesterday", "3 April 2026"
  static String formatDateSeparator(DateTime utcTime) {
    final local = utcTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(local.year, local.month, local.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      return '${local.day} ${months[local.month - 1]} ${local.year}';
    }
  }

  /// Format for reply quote timestamps: "Today, 14:30" or "3 Apr, 14:30"
  static String formatReplyTimestamp(DateTime utcTime) {
    final local = utcTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(local.year, local.month, local.day);

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';

    if (messageDate == today) {
      return 'Today, $time';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${local.day} ${months[local.month - 1]}, $time';
    }
  }
}
