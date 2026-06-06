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

  static const String _wsHost =
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage';
  static const String _wsSuffix = 'GenerativeService.BidiGenerateContent';
  // Перебор версий API: новая модель может требовать v1alpha.
  static const List<String> _apiVersions = ['v1beta', 'v1alpha'];

  final AudioRecorder _recorder = AudioRecorder();
  WebSocketChannel? _ch;
  StreamSubscription? _wsSub;
  StreamSubscription<Uint8List>? _micSub;
  bool _active = false;
  bool _playerReady = false;
  Completer<bool>? _connect; // завершается true при setupComplete
  String lastError = ''; // последняя причина сбоя (для показа пользователю)

  bool get isActive => _active;

  final StreamController<LiveState> _stateController = StreamController.broadcast();
  Stream<LiveState> get stateStream => _stateController.stream;
  void _emit(LiveState s) => _stateController.add(s);

  // Транскрипции и лог действий (для чата/истории в приложении).
  final StreamController<String> _userTextCtrl = StreamController.broadcast();
  final StreamController<String> _botTextCtrl = StreamController.broadcast();
  final StreamController<String> _actionCtrl = StreamController.broadcast();
  Stream<String> get userTextStream => _userTextCtrl.stream;
  Stream<String> get botTextStream => _botTextCtrl.stream;
  Stream<String> get actionStream => _actionCtrl.stream;

  final StringBuffer _inBuf = StringBuffer(); // речь пользователя за ход
  final StringBuffer _outBuf = StringBuffer(); // речь Пятницы за ход
  bool _speaking = false; // сейчас Пятница говорит (полудуплекс: микрофон молчит)
  final List<int> _pcmQueue = []; // буфер сэмплов ответа (сглаживает рывки сети)

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
            'responseModalities': ['AUDIO'],
            'speechConfig': {
              'voiceConfig': {
                'prebuiltVoiceConfig': {'voiceName': AiConfig.liveVoice}
              }
            }
          },
          'systemInstruction': {
            'parts': [
              {'text': AiConfig.liveSystemPrompt}
            ]
          },
          'tools': [
            {'functionDeclarations': _functions}
          ],
          // Транскрипции речи (для записи в чат/историю).
          'inputAudioTranscription': {},
          'outputAudioTranscription': {},
        }
      };

  /// Запускает живую сессию. Возвращает false, если не удалось (нужен фолбэк).
  Future<bool> start() async {
    if (_active) return true;
    lastError = '';
    final key = KeyManager().getActiveKey();
    if (key == null) {
      lastError = 'нет API-ключа';
      AppLogger.error('Live: no API key');
      _emit(LiveState.error);
      return false;
    }
    if (!await _recorder.hasPermission()) {
      lastError = 'нет доступа к микрофону';
      AppLogger.error('Live: no mic permission');
      _emit(LiveState.error);
      return false;
    }

    _emit(LiveState.connecting);
    // Пробуем версии endpoint по очереди (v1beta, затем v1alpha).
    for (final ver in _apiVersions) {
      final ok = await _attempt(ver, key);
      if (ok) return true;
      await _resetConnection();
    }
    AppLogger.error('Live: all endpoints failed ($lastError)');
    _active = false;
    _emit(LiveState.idle);
    return false;
  }

  Future<bool> _attempt(String ver, String key) async {
    try {
      _connect = Completer<bool>();
      final url = '$_wsHost.$ver.$_wsSuffix?key=$key';
      _ch = WebSocketChannel.connect(Uri.parse(url));
      await _ch!.ready;
      _wsSub = _ch!.stream.listen(
        _onMessage,
        onError: (e) {
          lastError = '[$ver] ошибка: $e';
          AppLogger.error('Live ws error', e);
          _failConnect();
        },
        onDone: () {
          if (_connect != null && !_connect!.isCompleted) {
            lastError =
                '[$ver] закрыто (code ${_ch?.closeCode ?? '-'}: ${_ch?.closeReason ?? ''})';
          }
          _failConnect();
          if (_active) stop();
        },
      );
      _ch!.sink.add(jsonEncode(_setupMessage()));

      final ok = await _connect!.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => false,
      );
      if (!ok) {
        if (lastError.isEmpty) lastError = '[$ver] таймаут setupComplete';
        return false;
      }
      _active = true;
      return true;
    } catch (e) {
      lastError = '[$ver] исключение: $e';
      AppLogger.error('Live connect failed', e);
      return false;
    }
  }

  /// Закрывает текущее соединение перед повторной попыткой (микрофон не трогаем).
  Future<void> _resetConnection() async {
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ch?.sink.close();
    } catch (_) {}
    _ch = null;
  }

  void _failConnect() {
    if (_connect != null && !_connect!.isCompleted) _connect!.complete(false);
  }

  Future<void> _onSetupComplete() async {
    if (_connect != null && !_connect!.isCompleted) _connect!.complete(true);
    // Проигрывание ответов (24кГц) и захват микрофона (16кГц).
    if (!_playerReady) {
      FlutterPcmSound.setup(sampleRate: 24000, channelCount: 1);
      // Порог ~0.33с: колбэк подкормки вызывается заранее, без провалов.
      FlutterPcmSound.setFeedThreshold(8000);
      FlutterPcmSound.setFeedCallback(_onFeed);
      FlutterPcmSound.start();
      _playerReady = true;
    }
    try {
      final stream = await _recorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        androidConfig: const AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
        ),
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
    if (_speaking) return; // полудуплекс: не слушаем, пока сами говорим (нет петли)
    ch.sink.add(jsonEncode({
      'realtimeInput': {
        'audio': {'mimeType': 'audio/pcm;rate=16000', 'data': base64Encode(data)}
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
    // Прервали (пользователь заговорил) — сбрасываем буфер речи.
    if (sc['interrupted'] == true) {
      _speaking = false;
      _pcmQueue.clear(); // прекращаем доигрывать прерванный ответ
      _emit(LiveState.listening);
    }

    // Транскрипция речи пользователя и Пятницы.
    final inT = (sc['inputTranscription'] is Map) ? sc['inputTranscription']['text'] : null;
    if (inT is String) _inBuf.write(inT);
    final outT = (sc['outputTranscription'] is Map) ? sc['outputTranscription']['text'] : null;
    if (outT is String) {
      _speaking = true; // ответ начался — микрофон молчит (без ложного обрыва)
      _outBuf.write(outT);
    }

    final modelTurn = sc['modelTurn'] as Map<String, dynamic>?;
    if (modelTurn != null) {
      final parts = modelTurn['parts'] as List?;
      if (parts != null) {
        for (final p in parts) {
          final inline = p is Map ? p['inlineData'] : null;
          final data = inline is Map ? inline['data'] : null;
          if (data is String && data.isNotEmpty) {
            _speaking = true; // полудуплекс: микрофон молчит, пока играет ответ
            _emit(LiveState.speaking);
            _playPcm(data);
          }
        }
      }
    }

    if (sc['turnComplete'] == true) {
      // Пишем реплики в чат.
      final u = _inBuf.toString().trim();
      final b = _outBuf.toString().trim();
      _inBuf.clear();
      _outBuf.clear();
      if (u.isNotEmpty) _userTextCtrl.add(u);
      if (b.isNotEmpty) _botTextCtrl.add(b);
      // Через паузу снова слушаем (даём затихнуть динамику — без эхо-петли).
      Future.delayed(const Duration(milliseconds: 600), () {
        _speaking = false;
        if (_active) _emit(LiveState.listening);
      });
    }
  }

  void _playPcm(String b64) {
    try {
      final bytes = base64Decode(b64);
      final samples = Int16List.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes ~/ 2);
      _pcmQueue.addAll(samples); // в очередь — отдаём в колбэке ровным потоком
    } catch (e) {
      AppLogger.error('Live decode failed', e);
    }
  }

  // Вызывается, когда буфер проигрывателя пустеет: отдаём следующую порцию
  // из очереди, а если её нет — короткую тишину, чтобы поток не прерывался.
  void _onFeed(int remaining) {
    const frame = 8000;
    if (_pcmQueue.isNotEmpty) {
      final n = _pcmQueue.length < frame ? _pcmQueue.length : frame;
      final chunk = _pcmQueue.sublist(0, n);
      _pcmQueue.removeRange(0, n);
      FlutterPcmSound.feed(PcmArrayInt16.fromList(chunk));
    } else {
      // Тишина выше порога — чтобы колбэк не вызывался в плотном цикле.
      FlutterPcmSound.feed(PcmArrayInt16.fromList(List<int>.filled(frame, 0)));
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
      final ok = res['success'] == true;
      final argStr = args.values.join(' ');
      _actionCtrl.add('🔧 $name${argStr.isNotEmpty ? " ($argStr)" : ""} — ${ok ? "выполнено" : "не вышло"}');
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
    _speaking = false;
    _inBuf.clear();
    _outBuf.clear();
    _pcmQueue.clear();
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
