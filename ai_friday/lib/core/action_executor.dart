import 'dart:convert';
import '../models/command.dart';
import '../services/intent_service.dart';
import '../utils/logger.dart';
import '../utils/text_utils.dart';

class ActionExecutor {
  static Future<bool> execute(String jsonResponse) async {
    if (!TextUtils.isJson(jsonResponse)) return false;

    try {
      final data = jsonDecode(jsonResponse);
      final steps = (data['steps'] as List?)?.map((s) => ActionStep.fromMap(s)).toList() ?? [];

      for (final step in steps) {
        final ok = await _executeStep(step);
        if (!ok) {
          AppLogger.warn('Step failed: ${step.action}');
        }
      }
      return true;
    } catch (e) {
      AppLogger.error('ActionExecutor parse error', e);
      return false;
    }
  }

  static Future<bool> _executeStep(ActionStep step) async {
    AppLogger.debug('Executing step: ${step.action} ${step.params}');
    switch (step.action) {
      case 'open_app':
        final pkg = step.params['package'] as String? ?? step.params['app'] as String? ?? '';
        return IntentService.openApp(pkg);
      case 'call':
        final phone = step.params['phone'] as String? ?? '';
        return IntentService.call(phone);
      case 'sms':
        final phone = step.params['phone'] as String? ?? '';
        final text = step.params['text'] as String? ?? '';
        return IntentService.sendSms(phone, text);
      case 'alarm':
        final hour = step.params['hour'] as int? ?? 0;
        final minute = step.params['minute'] as int? ?? 0;
        return IntentService.setAlarm(hour: hour, minute: minute);
      case 'timer':
        final seconds = step.params['seconds'] as int? ?? 60;
        return IntentService.setTimer(seconds);
      case 'maps':
        final query = step.params['query'] as String? ?? '';
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
}
