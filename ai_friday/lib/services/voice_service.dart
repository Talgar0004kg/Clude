import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../config/ai_config.dart';
import '../utils/logger.dart';

/// Пресет голоса (характер озвучки на базе системного TTS).
class VoicePreset {
  final String name;
  final double pitch;
  final double rate;
  const VoicePreset(this.name, this.pitch, this.rate);
}

/// Единый сервис голоса: распознавание речи (STT) + синтез речи (TTS).
///
/// Способ B: речь распознаётся на устройстве и уходит текстом в Gemini,
/// ответ озвучивается системным TTS выбранным «голосом».
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _ttsReady = false;
  bool _listening = false;
  bool get isListening => _listening;
  bool get sttAvailable => _sttReady;

  static const String _voicePrefsKey = 'friday_voice';
  String _currentVoice = AiConfig.defaultVoice;
  String get currentVoice => _currentVoice;

  // Пресеты «голосов» Пятницы (pitch/rate системного TTS).
  static const Map<String, VoicePreset> presets = {
    'Fenrir': VoicePreset('Fenrir', 0.85, 0.48),
    'Charon': VoicePreset('Charon', 0.72, 0.46),
    'Aoede': VoicePreset('Aoede', 1.28, 0.52),
    'Kore': VoicePreset('Kore', 1.12, 0.50),
    'Puck': VoicePreset('Puck', 1.00, 0.56),
  };

  // Уровень громкости микрофона (0..1) для анимации волны.
  final StreamController<double> _levelController = StreamController.broadcast();
  Stream<double> get levelStream => _levelController.stream;

  // Промежуточный (частичный) распознанный текст.
  final StreamController<String> _partialController = StreamController.broadcast();
  Stream<String> get partialStream => _partialController.stream;

  Completer<void>? _speakCompleter;

  Future<void> init() async {
    await _loadVoice();
    await _initStt();
    await _initTts();
  }

  Future<void> _loadVoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_voicePrefsKey);
      if (saved != null && presets.containsKey(saved)) {
        _currentVoice = saved;
      }
    } catch (_) {}
  }

  Future<void> _initStt() async {
    try {
      _sttReady = await _stt.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _listening = false;
          }
        },
        onError: (err) {
          AppLogger.error('STT error: ${err.errorMsg}');
          _listening = false;
        },
      );
    } catch (e) {
      AppLogger.error('STT init failed', e);
      _sttReady = false;
    }
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('ru-RU');
      await _tts.awaitSpeakCompletion(true);
      await _applyPreset(_currentVoice);
      _tts.setCompletionHandler(() {
        _speakCompleter?.complete();
        _speakCompleter = null;
      });
      _tts.setCancelHandler(() {
        _speakCompleter?.complete();
        _speakCompleter = null;
      });
      _tts.setErrorHandler((msg) {
        AppLogger.error('TTS error: $msg');
        _speakCompleter?.complete();
        _speakCompleter = null;
      });
      _ttsReady = true;
    } catch (e) {
      AppLogger.error('TTS init failed', e);
      _ttsReady = false;
    }
  }

  Future<void> _applyPreset(String name) async {
    final p = presets[name] ?? presets[AiConfig.defaultVoice]!;
    try {
      await _tts.setPitch(p.pitch);
      await _tts.setSpeechRate(p.rate);
      await _tts.setVolume(1.0);
    } catch (_) {}
  }

  /// Нормализуем уровень громкости от платформы в диапазон 0..1.
  double _normalizeLevel(double level) {
    // Android отдаёт примерно -2..10 (RMS dB), iOS — отрицательные значения.
    final v = (level + 2.0) / 12.0;
    return v.clamp(0.0, 1.0);
  }

  Future<bool> startListening({
    required void Function(String finalText) onResult,
    void Function(String partial)? onPartial,
  }) async {
    if (!_sttReady) {
      await _initStt();
      if (!_sttReady) return false;
    }
    if (_listening) return true;

    await stopSpeaking();
    _listening = true;

    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          final words = r.recognizedWords;
          if (!r.finalResult) {
            _partialController.add(words);
            onPartial?.call(words);
          } else {
            _listening = false;
            if (words.trim().isNotEmpty) onResult(words.trim());
          }
        },
        localeId: 'ru_RU',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        onSoundLevelChange: (level) {
          _levelController.add(_normalizeLevel(level));
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
      return true;
    } catch (e) {
      AppLogger.error('startListening failed', e);
      _listening = false;
      return false;
    }
  }

  Future<void> stopListening() async {
    if (!_listening) return;
    _listening = false;
    try {
      await _stt.stop();
    } catch (_) {}
    _levelController.add(0.0);
  }

  Future<void> cancelListening() async {
    _listening = false;
    try {
      await _stt.cancel();
    } catch (_) {}
    _levelController.add(0.0);
  }

  /// Озвучить текст выбранным голосом. Ждёт окончания проговаривания.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_ttsReady) {
      await _initTts();
      if (!_ttsReady) return;
    }
    await stopSpeaking();
    _speakCompleter = Completer<void>();
    try {
      await _tts.speak(text);
    } catch (e) {
      AppLogger.error('speak failed', e);
      _speakCompleter?.complete();
      _speakCompleter = null;
    }
    // awaitSpeakCompletion(true) делает speak() ждущим, но подстрахуемся.
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      await _speakCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {},
      );
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
    _speakCompleter = null;
  }

  /// Выбрать голос и сохранить выбор.
  Future<void> setVoice(String name) async {
    if (!presets.containsKey(name)) return;
    _currentVoice = name;
    await _applyPreset(name);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_voicePrefsKey, name);
    } catch (_) {}
  }

  /// Проиграть короткий пример выбранным голосом.
  Future<void> previewVoice(String name) async {
    await _applyPreset(name);
    await speak('Привет, я Пятница. Это голос $name.');
    // Вернуть пресет активного голоса, если предпросмотр был другого.
    if (name != _currentVoice) await _applyPreset(_currentVoice);
  }

  void dispose() {
    _levelController.close();
    _partialController.close();
  }
}
