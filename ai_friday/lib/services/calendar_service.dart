import 'package:android_intent_plus/android_intent.dart';
import '../utils/logger.dart';

class CalendarService {
  static Future<bool> createEvent({
    required String title,
    required DateTime start,
    DateTime? end,
    String? description,
  }) async {
    try {
      final endTime = end ?? start.add(const Duration(hours: 1));
      final intent = AndroidIntent(
        action: 'android.intent.action.INSERT',
        data: 'content://com.android.calendar/events',
        arguments: {
          'title': title,
          'beginTime': start.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
          if (description != null) 'description': description,
        },
      );
      await intent.launch();
      return true;
    } catch (e) {
      AppLogger.error('Failed to create calendar event', e);
      return false;
    }
  }

  static Future<bool> createReminder({
    required String text,
    required DateTime time,
  }) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.INSERT',
        data: 'content://com.android.calendar/reminders',
        arguments: {
          'title': text,
          'beginTime': time.millisecondsSinceEpoch,
        },
      );
      await intent.launch();
      return true;
    } catch (e) {
      AppLogger.error('Failed to create reminder', e);
      return false;
    }
  }
}
