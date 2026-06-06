import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message) {
    if (kDebugMode) debugPrint('[INFO] $message');
  }

  static void error(String message, [Object? error]) {
    if (kDebugMode) debugPrint('[ERROR] $message${error != null ? ': $error' : ''}');
  }

  static void warn(String message) {
    if (kDebugMode) debugPrint('[WARN] $message');
  }

  static void debug(String message) {
    if (kDebugMode) debugPrint('[DEBUG] $message');
  }
}
