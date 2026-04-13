import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../utils/link_detector.dart';

class RichMessageText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const RichMessageText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final linkStyle = style.copyWith(
      color: AppColors.linkColor,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.linkColor,
    );

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in LinkDetector.urlRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: style));
      }
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: TapGestureRecognizer()..onTap = () => _openUrl(url),
      ));
      lastEnd = match.end;
    }

    if (spans.isEmpty) {
      return Text(text, style: style);
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(LinkDetector.ensureProtocol(url));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
