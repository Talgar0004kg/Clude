import 'intent_service.dart';

class GmailService {
  static Future<bool> open() => IntentService.openApp('gmail');
}
