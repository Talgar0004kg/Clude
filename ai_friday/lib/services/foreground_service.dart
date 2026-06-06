import '../utils/logger.dart';
import 'key_manager.dart';
import 'notification_service.dart';

class ForegroundService {
  static bool _running = false;
  static bool get isRunning => _running;

  static Future<void> start() async {
    if (_running) return;
    _running = true;
    AppLogger.info('Foreground service started');
    await _updateNotification();
  }

  static Future<void> stop() async {
    _running = false;
    await NotificationService.cancelAll();
    AppLogger.info('Foreground service stopped');
  }

  static Future<void> _updateNotification() async {
    final km = KeyManager();
    final remaining = km.getRemainingRequests();
    final keys = km.getAllKeys();
    final activeIdx = keys.indexWhere((k) => k.isActive);
    final keyInfo = keys.isNotEmpty ? 'Ключ ${activeIdx + 1}' : 'Нет ключа';
    await NotificationService.showForeground(keyInfo: keyInfo, remaining: remaining);
  }
}
