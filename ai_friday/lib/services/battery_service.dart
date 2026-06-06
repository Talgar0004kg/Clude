import '../utils/logger.dart';

class BatteryService {
  static Future<int> getLevel() async {
    // Battery level via platform channel — placeholder
    AppLogger.info('Battery level requested');
    return -1;
  }
}
