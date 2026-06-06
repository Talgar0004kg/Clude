import 'dart:convert';
import '../models/command.dart';
import '../services/intent_service.dart';
import '../services/contact_service.dart';
import '../services/accessibility_service.dart';
import '../utils/logger.dart';
import '../utils/text_utils.dart';

class ActionExecutor {
  static Future<bool> execute(String jsonResponse) async {
    final jsonStr = TextUtils.extractJson(jsonResponse);
    if (jsonStr == null) return false;
    try {
      final data = jsonDecode(jsonStr);
      if (data is! Map) return false;
      return executeMap(Map<String, dynamic>.from(data));
    } catch (e) {
      AppLogger.error('ActionExecutor parse error', e);
      return false;
    }
  }

  /// Выполняет одиночное действие {"action": ...} или набор {"steps": [...]}.
  static Future<bool> executeMap(Map<String, dynamic> data) async {
    if (data['action'] is String) {
      return _executeStep(ActionStep.fromMap(data));
    }
    final steps = (data['steps'] as List?)
            ?.whereType<Map>()
            .map((s) => ActionStep.fromMap(Map<String, dynamic>.from(s)))
            .toList() ??
        [];
    if (steps.isEmpty) return false;
    bool all = true;
    for (final step in steps) {
      final ok = await _executeStep(step);
      if (!ok) {
        all = false;
        AppLogger.warn('Step failed: ${step.action}');
      }
      // Пауза, чтобы экран нужного приложения успел открыться/обновиться.
      await Future.delayed(_postDelay(step.action));
    }
    return all;
  }

  static Duration _postDelay(String action) {
    switch (action) {
      case 'open_app':
      case 'open':
      case 'whatsapp':
      case 'sms':
      case 'message':
      case 'maps':
      case 'settings':
        return const Duration(milliseconds: 1800);
      case 'type':
        return const Duration(milliseconds: 500);
      default:
        return const Duration(milliseconds: 250);
    }
  }

  static Future<bool> _executeStep(ActionStep step) async {
    AppLogger.debug('Executing step: ${step.action} ${step.params}');
    switch (step.action) {
      // ── Сообщения ──
      case 'message':
      case 'whatsapp':
      case 'whatsapp_message':
        return _sendMessage(step, defaultApp: 'whatsapp');
      case 'sms':
      case 'sms_message':
        return _sendMessage(step, defaultApp: 'sms');

      // ── Звонок ──
      case 'call':
        final phone = _resolvePhone(step);
        if (phone == null) return false;
        return IntentService.call(phone);

      // ── Универсальное управление экраном ──
      case 'open_app':
      case 'open':
        final app = step.params['package'] as String? ?? step.params['app'] as String? ?? '';
        return IntentService.openApp(app);
      case 'type':
        final text = step.params['text'] as String? ?? '';
        if (text.isEmpty) return false;
        return AccessibilityServiceManager.setText(text);
      case 'tap':
        final labels = _labels(step);
        if (labels.isEmpty) return false;
        return AccessibilityServiceManager.tap(labels);
      case 'send':
        final text = step.params['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          await AccessibilityServiceManager.setText(text);
          await Future.delayed(const Duration(milliseconds: 400));
        }
        return AccessibilityServiceManager.pressSend();
      case 'wait':
        final ms = (step.params['ms'] as num?)?.toInt() ?? 1000;
        await Future.delayed(Duration(milliseconds: ms));
        return true;
      case 'back':
        return AccessibilityServiceManager.back();
      case 'home':
        return AccessibilityServiceManager.home();

      // ── Система ──
      case 'maps':
        final query = step.params['query'] as String? ?? step.params['text'] as String? ?? '';
        return IntentService.openMaps(query);
      case 'alarm':
        final hour = (step.params['hour'] as num?)?.toInt() ?? 0;
        final minute = (step.params['minute'] as num?)?.toInt() ?? 0;
        return IntentService.setAlarm(hour: hour, minute: minute);
      case 'timer':
        final seconds = (step.params['seconds'] as num?)?.toInt() ?? 60;
        return IntentService.setTimer(seconds);
      case 'settings':
        return IntentService.openSettings();
      case 'accessibility_settings':
        return IntentService.openAccessibilitySettings();
      default:
        AppLogger.warn('Unknown action: ${step.action}');
        return false;
    }
  }

  /// Высокоуровневая отправка сообщения с автонажатием «Отправить».
  static Future<bool> _sendMessage(ActionStep step, {required String defaultApp}) async {
    final app = (step.params['app'] as String?)?.toLowerCase() ?? defaultApp;
    final text =
        (step.params['text'] as String?) ?? (step.params['message'] as String?) ?? '';
    if (text.trim().isEmpty) return false;
    final phone = _resolvePhone(step);

    if (app.contains('whatsapp') || app.contains('ватсап')) {
      if (phone == null) return false;
      final opened = await IntentService.sendWhatsApp(phone, text);
      if (!opened) return false;
      await Future.delayed(const Duration(milliseconds: 2500));
      return AccessibilityServiceManager.pressSend();
    }

    if (app.contains('sms') || app.contains('смс')) {
      if (phone == null) return false;
      final opened = await IntentService.sendSms(phone, text);
      if (!opened) return false;
      await Future.delayed(const Duration(milliseconds: 2200));
      return AccessibilityServiceManager.pressSend();
    }

    // Прочие приложения: открыть, напечатать в активное поле, отправить.
    final opened = await IntentService.openApp(app);
    if (!opened) return false;
    await Future.delayed(const Duration(milliseconds: 2500));
    await AccessibilityServiceManager.setText(text);
    await Future.delayed(const Duration(milliseconds: 400));
    return AccessibilityServiceManager.pressSend();
  }

  static List<String> _labels(ActionStep step) {
    final single = step.params['label'] as String?;
    if (single != null && single.trim().isNotEmpty) return [single.trim()];
    final list = step.params['labels'];
    if (list is List) {
      return list.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  /// Номер: сначала явный phone, иначе по имени контакта.
  static String? _resolvePhone(ActionStep step) {
    final phone = step.params['phone'] as String?;
    if (phone != null && phone.trim().isNotEmpty) return phone.trim();
    final name = (step.params['contact'] as String?) ?? (step.params['name'] as String?);
    if (name != null && name.trim().isNotEmpty) {
      final c = ContactService().findByName(name.trim());
      if (c != null && c.primaryPhone.isNotEmpty) return c.primaryPhone;
    }
    return null;
  }
}
