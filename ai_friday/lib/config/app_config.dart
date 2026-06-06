class AppConfig {
  static const String appName = 'Пятница';
  static const String appVersion = '1.0.0';

  // Colors
  static const int colorBackground = 0xFF0A0A0F;
  static const int colorAccent = 0xFF1D4ED8;
  static const int colorText = 0xFFE5E7EB;
  static const int colorSuccess = 0xFF10B981;
  static const int colorError = 0xFFEF4444;
  static const int colorSurface = 0xFF111827;

  // Session
  static const int sessionMaxMinutes = 10;
  static const int reconnectMaxAttempts = 3;
  static const int reconnectDelaySeconds = 5;

  // VAD
  static const int silenceDurationMs = 3000;

  // Keys
  static const int dailyRequestLimit = 1500;
  static const int keyRotateThreshold = 100;

  // Audio
  static const int maxVoiceMessageSeconds = 120;
  static const int silenceBeforeStopSeconds = 3;
}
