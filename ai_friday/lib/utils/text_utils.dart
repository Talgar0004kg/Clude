class TextUtils {
  static String normalize(String text) => text.trim().toLowerCase();

  static bool containsAny(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static bool isJson(String text) {
    final t = text.trim();
    return t.startsWith('{') && t.endsWith('}');
  }
}
