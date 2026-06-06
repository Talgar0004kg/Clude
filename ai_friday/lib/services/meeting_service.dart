import 'intent_service.dart';

class MeetingService {
  static Future<bool> openMeet() => IntentService.openApp('com.google.android.apps.meetings');
  static Future<bool> openZoom() => IntentService.openApp('us.zoom.videomeetings');
}
