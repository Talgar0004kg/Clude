class FuzzySearch {
  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final dp = List.generate(a.length + 1, (i) => List.generate(b.length + 1, (j) => 0));
    for (int i = 0; i <= a.length; i++) { dp[i][0] = i; }
    for (int j = 0; j <= b.length; j++) { dp[0][j] = j; }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[a.length][b.length];
  }

  static T? findBest<T>(String query, List<T> items, String Function(T) name, {int maxDist = 2}) {
    T? best;
    int bestDist = maxDist + 1;

    for (final item in items) {
      final n = name(item).toLowerCase();
      final q = query.toLowerCase();

      if (n == q) return item;
      if (n.contains(q)) return item;

      final dist = levenshtein(q, n);
      if (dist < bestDist) {
        bestDist = dist;
        best = item;
      }
    }
    return best;
  }
}
