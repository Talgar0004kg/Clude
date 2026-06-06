import '../services/contact_service.dart';
import '../services/intent_service.dart';
import '../services/maps_service.dart';
import '../services/translate_service.dart';
import '../utils/logger.dart';

class CommandParser {
  static final ContactService _contacts = ContactService();

  static final Map<RegExp, Future<bool> Function(RegExpMatch)> _rules = {};

  static void init() {
    _rules.clear();

    // ── Calls ──
    _rules[RegExp(r'(позвони|вызови|набери|чал)\s+(.+)', caseSensitive: false)] = (m) async {
      final name = m.group(2)!.trim();
      final contact = _contacts.findByName(name);
      if (contact == null) return false;
      return IntentService.call(contact.primaryPhone);
    };

    _rules[RegExp(r'апама\s*чал', caseSensitive: false)] = (_) async {
      final contact = _contacts.findByName('мама');
      if (contact == null) return false;
      return IntentService.call(contact.primaryPhone);
    };

    // ── Apps ──
    _rules[RegExp(r'(открой|ач|запусти)\s+(.+)', caseSensitive: false)] = (m) async {
      final app = m.group(2)!.trim();
      return IntentService.openApp(app);
    };

    // ── Maps / Navigation ──
    _rules[RegExp(r'(найди|навигация|маршрут|построй маршрут)\s+(.+)', caseSensitive: false)] = (m) async {
      return MapsService.navigate(m.group(2)!.trim());
    };

    _rules[RegExp(r'ближайш\w+\s+(.+)', caseSensitive: false)] = (m) async {
      return MapsService.findNearby(m.group(1)!.trim());
    };

    // ── Alarms / Timers ──
    _rules[RegExp(r'(поставь будильник|поставь алярм)\s+на\s+(\d{1,2}):(\d{2})', caseSensitive: false)] = (m) async {
      final h = int.parse(m.group(2)!);
      final min = int.parse(m.group(3)!);
      return IntentService.setAlarm(hour: h, minute: min);
    };

    _rules[RegExp(r'таймер на (\d+)\s*(минут|мин|секунд|сек)', caseSensitive: false)] = (m) async {
      final value = int.parse(m.group(1)!);
      final unit = m.group(2)!.toLowerCase();
      final secs = unit.startsWith('м') ? value * 60 : value;
      return IntentService.setTimer(secs);
    };

    // ── Translate ──
    _rules[RegExp(r'переведи\s+(.+)\s+на\s+(\w+)', caseSensitive: false)] = (m) async {
      return TranslateService.translate(m.group(1)!.trim());
    };

    // ── SMS ──
    _rules[RegExp(r'(отправь смс|напиши смс)\s+(.+?)\s+(текст|:)\s+(.+)', caseSensitive: false)] = (m) async {
      final name = m.group(2)!.trim();
      final text = m.group(4)!.trim();
      final contact = _contacts.findByName(name);
      if (contact == null) return false;
      return IntentService.sendSms(contact.primaryPhone, text);
    };

    // ── Settings ──
    _rules[RegExp(r'открой настройки', caseSensitive: false)] = (_) async =>
        IntentService.openSettings();
  }

  static Future<CommandResult?> tryParse(String input) async {
    final lower = input.toLowerCase().trim();

    for (final entry in _rules.entries) {
      final match = entry.key.firstMatch(lower);
      if (match != null) {
        AppLogger.info('Local command matched: ${entry.key.pattern}');
        try {
          final success = await entry.value(match);
          return CommandResult(matched: true, success: success);
        } catch (e) {
          AppLogger.error('Command execution error', e);
          return const CommandResult(matched: true, success: false);
        }
      }
    }
    return null;
  }
}

class CommandResult {
  final bool matched;
  final bool success;
  const CommandResult({required this.matched, required this.success});
}
