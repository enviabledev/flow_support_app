class LinkDetector {
  static final RegExp urlRegex = RegExp(
    r'(?:https?://|www\.)'
    r'[a-zA-Z0-9]+'
    r'(?:\.[a-zA-Z]{2,})'
    r'(?:[/\w\-._~:/?#\[\]@!$&()*+,;=%]*)?',
    caseSensitive: false,
  );

  static List<String> extractUrls(String text) {
    return urlRegex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  static bool containsUrl(String text) {
    return urlRegex.hasMatch(text);
  }

  static String ensureProtocol(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'https://$url';
    }
    return url;
  }
}
