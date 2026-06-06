import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import '../config/intent_map.dart';
import '../utils/logger.dart';

class IntentService {
  static Future<bool> openApp(String appName) async {
    final package = IntentMap.getPackage(appName);
    if (package == null) {
      AppLogger.warn('Unknown app: $appName');
      return false;
    }
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: package,
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return true;
    } catch (e) {
      AppLogger.error('Failed to open $appName', e);
      return false;
    }
  }

  static Future<bool> call(String phoneNumber) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.CALL',
        data: 'tel:$phoneNumber',
      );
      await intent.launch();
      return true;
    } catch (e) {
      AppLogger.error('Failed to call $phoneNumber', e);
      return false;
    }
  }

  static Future<bool> setAlarm({required int hour, required int minute, String? message}) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: {
          'android.intent.extra.alarm.HOUR': hour,
          'android.intent.extra.alarm.MINUTES': minute,
          if (message != null) 'android.intent.extra.alarm.MESSAGE': message,
          'android.intent.extra.alarm.SKIP_UI': true,
        },
      );
      await intent.launch();
      return true;
    } catch (e) {
      AppLogger.error('Failed to set alarm', e);
      return false;
    }
  }

  static Future<bool> setTimer(int seconds) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_TIMER',
        arguments: {
          'android.intent.extra.alarm.LENGTH': seconds,
          'android.intent.extra.alarm.SKIP_UI': true,
        },
      );
      await intent.launch();
      return true;
    } catch (e) {
      AppLogger.error('Failed to set timer', e);
      return false;
    }
  }

  static Future<bool> openMaps(String query) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'geo:0,0?q=${Uri.encodeComponent(query)}',
        package: 'com.google.android.apps.maps',
      );
      await intent.launch();
      return true;
    } catch (e) {
      AppLogger.error('Failed to open maps', e);
      return false;
    }
  }

  static Future<bool> sendSms(String phone, String message) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SENDTO',
        data: 'smsto:$phone',
        arguments: {'sms_body': message},
      );
      await intent.launch();
      return true;
    } catch (e) {
      AppLogger.error('Failed to send SMS', e);
      return false;
    }
  }

  /// Открывает чат WhatsApp с уже введённым текстом (остаётся нажать «отправить»).
  /// Номер приводится к международному виду (только цифры).
  static Future<bool> sendWhatsApp(String phone, String message) async {
    try {
      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return false;
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return true;
    } catch (e) {
      AppLogger.error('Failed to open WhatsApp', e);
      return false;
    }
  }

  static Future<bool> openSettings() async {
    try {
      const intent = AndroidIntent(action: 'android.settings.SETTINGS');
      await intent.launch();
      return true;
    } catch (e) {
      AppLogger.error('Failed to open settings', e);
      return false;
    }
  }

  static Future<bool> openAccessibilitySettings() async {
    try {
      const intent = AndroidIntent(action: 'android.settings.ACCESSIBILITY_SETTINGS');
      await intent.launch();
      return true;
    } catch (e) {
      AppLogger.error('Failed to open accessibility settings', e);
      return false;
    }
  }
}
