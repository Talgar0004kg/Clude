import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/ai_config.dart';
import '../core/action_executor.dart';
import '../utils/logger.dart';
import 'key_manager.dart';

enum LiveState { idle, connecting, listening, speaking, error }

/// Gemini Live API в реальном времени: микрофон → Gemini → голос,
/// с function calling («руки» для управления телефоном).
class LiveService {
  static final LiveService _instance = LiveService._internal();
  factory LiveService() => _instance;
  LiveService._internal();

  static const String _wsBase =
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';

  final AudioRecorder _recorder = AudioRecorder();
  WebSocketChannel? _ch;
  StreamSubscription? _wsSub;
  StreamSubscription<Uint8List>? _micSub;
  bool _active = false;
  bool _playerReady = false;

  bool get isActive => _active;

  final StreamController<LiveState> _stateController = StreamController.broadcast();
  Stream<LiveState> get stateStream => _stateController.stream;
  void _emit(LiveState s) => _stateController.add(s);

  // Описание функций для модели (её «руки»).
  static final List<Map<String, dynamic>> _functions = [
    {
      'name': 'open_app',
      'description': 'Открыть приложение по имени (whatsapp, telegram, youtube, instagram и т.п.)',
      'parameters': {
        'type': 'object',
        'properties': {'app': {'type': 'string'}},
        'required': ['app']
      }
    },
    {
      'name': 'send_message',
      'description': 'Написать и отправить сообщение контакту',
      'parameters': {
        'type': 'object',
        'properties': {
          'app': {'type': 'string', 'description': 'whatsapp или sms'},
          'contact': {'type': 'string'},
          'text': {'type': 'string'}
        },
        'required': ['contact', 'text']
      }
    },
    {
      'name': 'call',
      'description': 'Позвонить контакту по имени',
      'parameters': {
        'type': 'object',
        'properties': {'contact': {'type': 'string'}},
        'required': ['contact']
      }
    },
    {
      'name': 'type_text',
      'description': 'Напечатать текст в активное текстовое поле на экране',
      'parameters': {
        'type': 'object',
        'properties': {'text': {'type': 'string'}},
        'required': ['text']
      }
    },
    {
      'name': 'tap',
      'description': 'Нажать кнопку или элемент по его тексту/описанию',
      'parameters': {
        'type': 'object',
        'properties': {'label': {'type': 'string'}},
        'required': ['label']
      }
    },
    {
      'name': 'press_send',
      'description': 'Нажать кнопку отправки в текущем приложении',
      'parameters': {'type': 'object', 'properties': {}}
    },
    {
      'name': 'open_maps',
      'description': 'Открыть карту или маршрут/поиск места',
      'parameters': {
        'type': 'object',
        'properties': {'query': {'type': 'string'}},
        'required': ['query']
      }
    },
    {
      'name': 'set_alarm',
      'description': 'Поставить будильник',
      'parameters': {
        'type': 'object',
        'properties': {'hour': {'type': 'integer'}, 'minute': {'type': 'integer'}},
        'required': ['hour', 'minute']
      }
    },
    {
      'name': 'set_timer',
      'description': 'Поставить таймер в секундах',
      'parameters': {
        'type': 'object',
        'properties': {'seconds': {'type': 'integer'}},
        'required': ['seconds']
      }
    },
    {
      'name': 'go_back',
      'description': 'Кнопка назад',
      'parameters': {'type': 'object', 'properties': {}}
    },
    {
      'name': 'go_home',
      'description': 'На главный экран',
      'parameters': {'type': 'object', 'properties': {}}
    },
  ];

  Map<String, dynamic> _setupMessage() => {
        'setup': {
          'model': 'models/${AiConfig.liveModel}',
          'generationConfig': {
            'responseModalities': ['AUDIO']
          },
          'systemInstruction': {
            'parts': [
              {'text': AiConfig.liveSystemPrompt}
            ]
          },
          'tools': [
            {'functionDeclarations': _functions}
          ],
        }
      };

  /// Запускает живую сессию. Возвращает false, если не удалось (нужен фолбэк).
  Future<bool> start() async {
    if (_active) return true;
    final key = KeyManager().getActiveKey();
    if (key == null) {
      AppLogger.error('Live: no API key');
      _emit(LiveState.error);
      return false;
    }
    if (!await _recorder.hasPermission()) {
      AppLogger.error('Live: no mic permission');
      _emit(LiveState.error);
      return false;
    }

    try {
      _emit(LiveState.connecting);
      _ch = WebSocketChannel.connect(Uri.parse('$_wsBase?key=$key'));
      await _ch!.ready;
      _wsSub = _ch!.stream.listen(
        _onMessage,
        onError: (e) {
          AppLogger.error('Live ws error', e);
          _emit(LiveState.error);
        },
        onDone: () => stop(),
      );
      _ch!.sink.add(jsonEncode(_setupMessage()));
      _active = true;
      return true;
    } catch (e) {
      AppLogger.error('Live connect failed', e);
      await stop();
      return false;
    }
  }

  Future<void> _onSetupComplete() async {
    // Проигрывание ответов (24кГц) и захват микрофона (16кГц).
    if (!_playerReady) {
      FlutterPcmSound.setup(sampleRate: 24000, channelCount: 1);
      FlutterPcmSound.setFeedThreshold(2400);
      FlutterPcmSound.setFeedCallback((_) {});
      FlutterPcmSound.start();
      _playerReady = true;
    }
    try {
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      _micSub = stream.listen(_sendAudio);
      _emit(LiveState.listening);
    } catch (e) {
      AppLogger.error('Live mic start failed', e);
      _emit(LiveState.error);
    }
  }

  void _sendAudio(Uint8List data) {
    final ch = _ch;
    if (ch == null || !_active) return;
    ch.sink.add(jsonEncode({
      'realtimeInput': {
        'mediaChunks': [
          {'mimeType': 'audio/pcm;rate=16000', 'data': base64Encode(data)}
        ]
      }
    }));
  }

  void _onMessage(dynamic raw) {
    try {
      final text = raw is String ? raw : utf8.decode(raw as List<int>);
      final msg = jsonDecode(text) as Map<String, dynamic>;
      if (msg.containsKey('setupComplete')) {
        _onSetupComplete();
      } else if (msg.containsKey('serverContent')) {
        _onServerContent(msg['serverContent'] as Map<String, dynamic>);
      } else if (msg.containsKey('toolCall')) {
        _onToolCall(msg['toolCall'] as Map<String, dynamic>);
      }
    } catch (e) {
      AppLogger.error('Live parse failed', e);
    }
  }

  void _onServerContent(Map<String, dynamic> sc) {
    final modelTurn = sc['modelTurn'] as Map<String, dynamic>?;
    if (modelTurn != null) {
      final parts = modelTurn['parts'] as List?;
      if (parts != null) {
        for (final p in parts) {
          final inline = p is Map ? p['inlineData'] : null;
          final data = inline is Map ? inline['data'] : null;
          if (data is String && data.isNotEmpty) {
            _emit(LiveState.speaking);
            _playPcm(data);
          }
        }
      }
    }
    if (sc['turnComplete'] == true) {
      _emit(LiveState.listening);
    }
  }

  void _playPcm(String b64) {
    try {
      final bytes = base64Decode(b64);
      final samples = Int16List.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes ~/ 2);
      FlutterPcmSound.feed(PcmArrayInt16.fromList(samples.toList()));
    } catch (e) {
      AppLogger.error('Live play failed', e);
    }
  }

  Future<void> _onToolCall(Map<String, dynamic> tc) async {
    final calls = tc['functionCalls'] as List?;
    if (calls == null || calls.isEmpty) return;
    final responses = <Map<String, dynamic>>[];
    for (final c in calls) {
      if (c is! Map) continue;
      final name = (c['name'] ?? '').toString();
      final args = (c['args'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final res = await ActionExecutor.runFunction(name, args);
      responses.add({'id': c['id'], 'name': name, 'response': res});
    }
    _ch?.sink.add(jsonEncode({
      'toolResponse': {'functionResponses': responses}
    }));
  }

  Future<void> stop() async {
    if (!_active && _ch == null) {
      _emit(LiveState.idle);
      return;
    }
    _active = false;
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ch?.sink.close();
    } catch (_) {}
    _ch = null;
    try {
      FlutterPcmSound.release();
    } catch (_) {}
    _playerReady = false;
    _emit(LiveState.idle);
  }
}
