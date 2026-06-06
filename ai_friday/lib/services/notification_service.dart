import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/logger.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const int _foregroundId = 1;

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
    AppLogger.info('Notification service initialized');
  }

  static Future<void> showForeground({
    required String keyInfo,
    required int remaining,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'friday_foreground',
      'Пятница активна',
      channelDescription: 'Постоянное уведомление о работе ассистента',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      playSound: false,
      enableVibration: false,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      _foregroundId,
      'Пятница активна',
      '$keyInfo | $remaining запросов осталось',
      details,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);
  static Future<void> cancelAll() => _plugin.cancelAll();
}
