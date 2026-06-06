class BlockedCommands {
  static const List<String> keywords = [
    'банковский перевод',
    'переведи деньги',
    'банковский пароль',
    'пин код карты',
    'cvv',
    'данные карты',
    'банковские реквизиты',
    'платёжные данные',
    'transfer money',
    'bank transfer',
    'credit card',
    'debit card',
  ];

  static bool isBlocked(String command) {
    final lower = command.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }
}
