import 'dart:convert';
import '../models/command.dart';
import '../services/intent_service.dart';
import '../services/contact_service.dart';
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

  /// Выполняет либо одиночное действие {"action": ...}, либо набор {"steps": [...]}.
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
    }
    return all;
  }

  static Future<bool> _executeStep(ActionStep step) async {
    AppLogger.debug('Executing step: ${step.action} ${step.params}');
    switch (step.action) {
      case 'whatsapp':
      case 'whatsapp_message':
        return _message(step, whatsapp: true);
      case 'sms':
      case 'sms_message':
        return _message(step, whatsapp: false);
      case 'call':
        final phone = _resolvePhone(step);
        if (phone == null) return false;
        return IntentService.call(phone);
      case 'open_app':
        final pkg = step.params['package'] as String? ?? step.params['app'] as String? ?? '';
        return IntentService.openApp(pkg);
      case 'alarm':
        final hour = (step.params['hour'] as num?)?.toInt() ?? 0;
        final minute = (step.params['minute'] as num?)?.toInt() ?? 0;
        return IntentService.setAlarm(hour: hour, minute: minute);
      case 'timer':
        final seconds = (step.params['seconds'] as num?)?.toInt() ?? 60;
        return IntentService.setTimer(seconds);
      case 'maps':
        final query = step.params['query'] as String? ?? step.params['text'] as String? ?? '';
        return IntentService.openMaps(query);
      case 'settings':
        return IntentService.openSettings();
      case 'accessibility_settings':
        return IntentService.openAccessibilitySettings();
      default:
        AppLogger.warn('Unknown action: ${step.action}');
        return false;
    }
  }

  /// Отправка сообщения (WhatsApp или SMS) с разрешением контакта по имени.
  static Future<bool> _message(ActionStep step, {required bool whatsapp}) async {
    final text =
        (step.params['text'] as String?) ?? (step.params['message'] as String?) ?? '';
    final phone = _resolvePhone(step);
    if (phone == null || text.trim().isEmpty) return false;
    return whatsapp
        ? IntentService.sendWhatsApp(phone, text)
        : IntentService.sendSms(phone, text);
  }

  /// Находит номер: сначала явный phone, иначе по имени контакта.
  static String? _resolvePhone(ActionStep step) {
    final phone = step.params['phone'] as String?;
    if (phone != null && phone.trim().isNotEmpty) return phone.trim();
    final name =
        (step.params['contact'] as String?) ?? (step.params['name'] as String?);
    if (name != null && name.trim().isNotEmpty) {
      final c = ContactService().findByName(name.trim());
      if (c != null && c.primaryPhone.isNotEmpty) return c.primaryPhone;
    }
    return null;
  }
}
