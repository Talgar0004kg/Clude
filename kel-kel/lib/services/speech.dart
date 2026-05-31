import 'package:flutter_tts/flutter_tts.dart';

/// Простой сервис озвучивания слов.
/// Кыргызский голос есть не на всех устройствах, поэтому при его отсутствии
/// используется доступный тюркский/русский голос как запасной вариант.
class Speech {
  Speech._();
  static final Speech instance = Speech._();

  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    // Пытаемся выбрать кыргызский, иначе ближайший доступный язык.
    try {
      await _tts.setLanguage('ky-KG');
    } catch (_) {
      try {
        await _tts.setLanguage('ru-RU');
      } catch (_) {}
    }
    _configured = true;
  }

  Future<void> speak(String text) async {
    await _ensureConfigured();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
