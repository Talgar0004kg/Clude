import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Обёртка над собственным нативным Accessibility-сервисом (Kotlin)
/// через MethodChannel. Позволяет печатать текст и кликать в любом приложении.
class AccessibilityServiceManager {
  static const MethodChannel _channel = MethodChannel('friday/accessibility');

  static Future<bool> isEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } catch (e) {
      AppLogger.error('Accessibility isEnabled failed', e);
      return false;
    }
  }

  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openSettings');
    } catch (e) {
      AppLogger.error('Accessibility openSettings failed', e);
    }
  }

  /// Печатает текст в сфокусированное/первое редактируемое поле на экране.
  static Future<bool> setText(String text) async {
    try {
      return await _channel.invokeMethod<bool>('setText', {'text': text}) ?? false;
    } catch (e) {
      AppLogger.error('Accessibility setText failed', e);
      return false;
    }
  }

  /// Кликает по элементу с текстом/описанием из списка меток.
  static Future<bool> tap(List<String> labels) async {
    try {
      return await _channel.invokeMethod<bool>('tap', {'labels': labels}) ?? false;
    } catch (e) {
      AppLogger.error('Accessibility tap failed', e);
      return false;
    }
  }

  /// Запускает приложение точно по пакету (минуя дефолт-ассоциации Android).
  static Future<bool> launchApp(String package) async {
    try {
      return await _channel.invokeMethod<bool>('launchApp', {'package': package}) ?? false;
    } catch (e) {
      AppLogger.error('Accessibility launchApp failed', e);
      return false;
    }
  }

  /// Жмёт кнопку отправки (Send/Отправить и т.п.).
  static Future<bool> pressSend() async {
    try {
      return await _channel.invokeMethod<bool>('pressSend') ?? false;
    } catch (e) {
      AppLogger.error('Accessibility pressSend failed', e);
      return false;
    }
  }

  /// Читает текущий экран как компактный текст (глаза агента).
  static Future<String> readScreen() async {
    try {
      return await _channel.invokeMethod<String>('readScreen') ?? '';
    } catch (e) {
      AppLogger.error('Accessibility readScreen failed', e);
      return '';
    }
  }

  /// Тап по координатам экрана.
  static Future<bool> tapXY(int x, int y) async {
    try {
      return await _channel.invokeMethod<bool>('tapXY', {'x': x, 'y': y}) ?? false;
    } catch (e) {
      AppLogger.error('Accessibility tapXY failed', e);
      return false;
    }
  }

  /// Скролл экрана: up/down/left/right.
  static Future<bool> scroll(String direction) async {
    try {
      return await _channel.invokeMethod<bool>('scroll', {'direction': direction}) ?? false;
    } catch (e) {
      AppLogger.error('Accessibility scroll failed', e);
      return false;
    }
  }

  static Future<bool> back() async {
    try {
      return await _channel.invokeMethod<bool>('back') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> home() async {
    try {
      return await _channel.invokeMethod<bool>('home') ?? false;
    } catch (_) {
      return false;
    }
  }
}
