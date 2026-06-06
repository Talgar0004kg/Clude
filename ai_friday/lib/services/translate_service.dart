import 'package:android_intent_plus/android_intent.dart';
import '../utils/logger.dart';

class TranslateService {
  static Future<bool> translate(String text, {String targetLang = 'en'}) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SEND',
        type: 'text/plain',
        package: 'com.google.android.apps.translate',
        arguments: {'android.intent.extra.TEXT': text},
      );
      await intent.launch();
      return true;
    } catch (e) {
      AppLogger.error('Failed to open translator', e);
      return false;
    }
  }
}
