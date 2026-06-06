import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceUtils {
  static AndroidDeviceInfo? _info;

  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final plugin = DeviceInfoPlugin();
      _info = await plugin.androidInfo;
    } catch (_) {}
  }

  static String get manufacturer => _info?.manufacturer ?? 'unknown';
  static String get model => _info?.model ?? 'unknown';
  static int get sdkVersion => _info?.version.sdkInt ?? 0;

  static String getBatteryExclusionHint() {
    final mfr = manufacturer.toLowerCase();
    if (mfr.contains('xiaomi') || mfr.contains('redmi')) {
      return 'MIUI → Приложения → Пятница → Автозапуск → Включить';
    } else if (mfr.contains('samsung')) {
      return 'Настройки → Батарея → Оптимизация → Пятница → Не оптимизировать';
    } else if (mfr.contains('huawei') || mfr.contains('honor')) {
      return 'Диспетчер телефона → Запуск приложений → Пятница → Включить';
    } else {
      return 'Настройки → Батарея → Исключения → Добавить Пятница';
    }
  }
}
