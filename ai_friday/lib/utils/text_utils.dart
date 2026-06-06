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
    return extractJson(text) != null;
  }

  /// Извлекает JSON-объект из ответа ИИ: убирает markdown-обёртку ```json```
  /// и берёт подстроку от первой { до последней }. Возвращает null, если нет.
  static String? extractJson(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '').replaceFirst(RegExp(r'```\s*$'), '').trim();
    }
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return t.substring(start, end + 1);
  }
}
