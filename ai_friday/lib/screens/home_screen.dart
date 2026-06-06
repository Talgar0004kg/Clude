import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/gemini_service.dart';
import '../services/key_manager.dart';
import '../services/voice_service.dart';
import '../services/live_service.dart';
import '../services/accessibility_service.dart';
import '../core/context_manager.dart';
import '../core/security_guard.dart';
import '../core/action_executor.dart';
import '../core/command_parser.dart';
import '../models/message.dart';
import '../utils/text_utils.dart';
import '../widgets/waveform_widget.dart';
import '../widgets/status_bar.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _gemini = GeminiService();
  final _context = ContextManager();
  final _keyManager = KeyManager();
  final _voice = VoiceService();
  final _live = LiveService();
  bool _liveMode = false; // активна ли живая сессия Gemini Live
  StreamSubscription<LiveState>? _liveSub;
  StreamSubscription<String>? _userTextSub;
  StreamSubscription<String>? _botTextSub;
  StreamSubscription<String>? _actionSub;

  AssistantState _state = AssistantState.idle;
  String _transcript = '';
  String _response = '';
  bool _serviceRunning = false; // активный режим (как Gemini Live)
  bool _stopRequested = false;
  String? _pendingBarge; // текст, которым пользователь перебил озвучку
  int _navIndex = 0;
  double _level = 0.0;

  late AnimationController _orbController;
  StreamSubscription<double>? _levelSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _orbController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _levelSub = _voice.levelStream.listen((lvl) {
      if (mounted) setState(() => _level = lvl);
    });
    _liveSub = _live.stateStream.listen(_onLiveState);
    // Логируем реплики и действия Live в чат.
    _userTextSub = _live.userTextStream.listen((t) {
      _logMessage(t, MessageRole.user);
      if (mounted) setState(() => _transcript = t);
    });
    _botTextSub = _live.botTextStream.listen((t) {
      _logMessage(t, MessageRole.assistant);
      if (mounted) setState(() => _response = t);
    });
    _actionSub = _live.actionStream.listen((a) {
      _logMessage(a, MessageRole.assistant);
    });
    _voice.init();
    // Загружаем историю прошлых бесед из БД (для чата и контекста).
    _context.loadFromDb().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _logMessage(String text, MessageRole role) {
    if (text.trim().isEmpty) return;
    _context.add(Message(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      role: role,
      timestamp: DateTime.now(),
    ));
  }

  void _onLiveState(LiveState s) {
    if (!mounted) return;
    setState(() {
      switch (s) {
        case LiveState.connecting:
          _state = AssistantState.thinking;
          break;
        case LiveState.listening:
          _state = AssistantState.listening;
          break;
        case LiveState.speaking:
          _state = AssistantState.speaking;
          break;
        case LiveState.idle:
          _state = AssistantState.idle;
          break;
        case LiveState.error:
          break;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _levelSub?.cancel();
    _liveSub?.cancel();
    _userTextSub?.cancel();
    _botTextSub?.cancel();
    _actionSub?.cancel();
    _live.stopByUser();
    AccessibilityServiceManager.stopForeground();
    _voice.stopListening();
    _voice.stopSpeaking();
    _orbController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_liveMode) return; // живой режим управляет аудио сам
    if (state == AppLifecycleState.resumed &&
        _serviceRunning &&
        !_stopRequested &&
        !_voice.isListening &&
        _state != AssistantState.speaking &&
        _state != AssistantState.thinking) {
      _beginListening();
    } else if (state == AppLifecycleState.paused) {
      _voice.stopListening();
    }
  }

  void _setState(AssistantState s) {
    if (mounted) setState(() => _state = s);
  }

  /// Главная кнопка — включить/выключить ассистента.
  Future<void> _toggleService() async {
    if (_serviceRunning) {
      await _stopConversation();
      return;
    }
    _stopRequested = false;
    setState(() {
      _serviceRunning = true;
      _state = AssistantState.thinking;
      _transcript = '';
      _response = 'Подключаюсь к Пятнице...';
    });

    // Контекст прошлых бесед → в Live (чтобы помнила историю).
    final history = _context
        .getRecent(count: 20)
        .map((m) => {'role': m.role.name, 'text': m.text})
        .toList();

    // Только живой режим (Gemini Live), без запасного.
    final live = await _live.start(history: history);
    if (live) {
      _liveMode = true;
      AccessibilityServiceManager.startForeground(); // держим процесс живым
      if (mounted) setState(() => _response = '');
      return; // дальше всё ведёт LiveService (звук, перебивание, действия)
    }

    // Без фолбэка — честно сообщаем о неудаче подключения.
    _liveMode = false;
    if (mounted) {
      setState(() {
        _serviceRunning = false;
        _state = AssistantState.idle;
        _response =
            'Не удалось подключиться к Пятнице (Gemini Live): ${_live.lastError}. Проверьте интернет/ключ и нажмите «Включить» снова.';
      });
    }
  }

  /// Полная остановка (ручная).
  Future<void> _stopConversation() async {
    _stopRequested = true;
    if (_liveMode) {
      await _live.stopByUser(); // без авто-переподключения
      _liveMode = false;
    }
    AccessibilityServiceManager.stopForeground();
    await _voice.stopListening();
    await _voice.stopSpeaking();
    if (mounted) {
      setState(() {
        _serviceRunning = false;
        _state = AssistantState.idle;
        _level = 0.0;
      });
    }
    await _voice.speak('Пятница отключена');
  }

  /// Слушает речь (с паузой 3 сек на «договорить»).
  Future<void> _beginListening() async {
    await _voice.stopSpeaking();
    if (!mounted) return;
    setState(() {
      _state = AssistantState.listening;
      _transcript = '';
    });

    final ok = await _voice.startListening(
      pauseSeconds: 3,
      onPartial: (partial) {
        if (mounted) setState(() => _transcript = partial);
      },
      onResult: (text) {
        if (mounted) setState(() {
          _transcript = text;
          _level = 0.0;
        });
        processCommand(text);
      },
      onListenEnd: () {
        // Тишина без фразы — в активном режиме слушаем снова.
        if (_serviceRunning && !_stopRequested && mounted) {
          _scheduleResume();
        } else {
          _setState(AssistantState.idle);
        }
      },
    );

    if (!ok) {
      setState(() {
        _serviceRunning = false;
        _state = AssistantState.idle;
        _response =
            'Распознавание речи недоступно. Установите/включите Google-распознавание и разрешите доступ к микрофону.';
      });
    }
  }

  void _maybeResume() {
    if (_serviceRunning && !_stopRequested && mounted) {
      _scheduleResume();
    }
  }

  void _scheduleResume() {
    Future.delayed(const Duration(milliseconds: 400), () {
      final resumed = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (_serviceRunning && !_stopRequested && mounted && resumed && !_voice.isListening) {
        _beginListening();
      }
    });
  }

  /// Один запрос на команду: думает → говорит (можно перебить) → действует.
  Future<void> processCommand(String text) async {
    final spoken = text.trim();
    if (spoken.isEmpty) {
      _maybeResume();
      return;
    }

    _context.add(Message(
      id: DateTime.now().toIso8601String(),
      text: spoken,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    ));
    if (mounted) setState(() => _response = '');

    String speech;
    Map<String, dynamic>? action;

    if (!SecurityGuard.isAllowed(spoken)) {
      speech = SecurityGuard.blockMessage();
    } else {
      _setState(AssistantState.thinking);

      // Локальные команды (без обращения к ИИ).
      final localResult = await CommandParser.tryParse(spoken);
      if (localResult != null && localResult.matched) {
        speech = localResult.success ? 'Выполнено.' : 'Не удалось выполнить.';
      } else {
        // Один запрос к Gemini (с поиском Google внутри него).
        final reply = await _gemini.sendMessageStream(spoken);
        if (reply == null) {
          speech = 'Не удалось получить ответ. Проверьте интернет и ключ.';
        } else {
          _context.add(Message(
            id: '${DateTime.now().toIso8601String()}_r',
            text: reply,
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
          ));
          final data = _parseAction(reply);
          if (data != null) {
            action = data;
            final s = (data['speech'] as String?)?.trim();
            speech = (s != null && s.isNotEmpty) ? s : 'Выполняю.';
          } else {
            speech = reply;
          }
        }
      }
    }

    // Говорит и одновременно слушает — пользователь может перебить.
    _pendingBarge = null;
    if (mounted) setState(() {
      _state = AssistantState.speaking;
      _response = speech;
    });
    await _voice.speakAndListen(
      text: speech,
      onUserSpeech: (t) => _pendingBarge = t,
    );

    // Перебили — обрабатываем новую фразу, действие текущей отменяем.
    if (_pendingBarge != null) {
      final next = _pendingBarge!;
      _pendingBarge = null;
      if (mounted) setState(() => _transcript = next);
      await processCommand(next);
      return;
    }

    // Не перебили — выполняем действие (если было).
    if (action != null) {
      final ok = await ActionExecutor.executeMap(action);
      if (!ok) {
        await _voice.speak('Не получилось. Проверьте, что контакт есть в телефоне и приложение установлено.');
      }
    }

    _setState(AssistantState.idle);
    _maybeResume();
  }

  /// Если ответ ИИ — JSON-команда телефону, возвращает её как map, иначе null.
  Map<String, dynamic>? _parseAction(String reply) {
    final jsonStr = TextUtils.extractJson(reply);
    if (jsonStr == null) return null;
    try {
      final d = jsonDecode(jsonStr);
      if (d is Map && (d['action'] is String || d['steps'] is List)) {
        return Map<String, dynamic>.from(d);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.colorBackground),
      body: IndexedStack(
        index: _navIndex,
        children: [
          _homeTab(),
          ChatScreen(contextManager: _context),
          const HistoryScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF111827),
        indicatorColor: const Color(AppConfig.colorAccent).withValues(alpha: 0.2),
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.chat_outlined), selectedIcon: Icon(Icons.chat), label: 'Чат'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'История'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }

  Widget _homeTab() {
    return SafeArea(
      child: Column(
        children: [
          StatusBar(serviceRunning: _serviceRunning, keyManager: _keyManager, onToggle: _toggleService),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WaveformWidget(state: _state, controller: _orbController, level: _level),
                const SizedBox(height: 24),
                _stateText(),
                if (_transcript.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Text(
                      _transcript,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    ),
                  ),
                if (_response.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Text(
                      _response,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(AppConfig.colorText), fontSize: 16),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          _bottomControls(),
        ],
      ),
    );
  }

  Widget _stateText() {
    String label;
    if (!_serviceRunning) {
      label = 'Выключено — нажмите «Включить»';
    } else {
      label = {
            AssistantState.idle: 'Готова, говорите',
            AssistantState.listening: 'Слушаю...',
            AssistantState.thinking: 'Обрабатываю...',
            AssistantState.speaking: 'Отвечаю... (можно перебить)',
          }[_state] ??
          '';
    }
    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: !_serviceRunning ? const Color(0xFF6B7280) : const Color(AppConfig.colorAccent),
        fontSize: 16,
      ),
    );
  }

  Widget _bottomControls() {
    final active = _serviceRunning;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggleService,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: active ? const Color(AppConfig.colorError) : const Color(AppConfig.colorAccent),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (active ? const Color(AppConfig.colorError) : const Color(AppConfig.colorAccent))
                        .withValues(alpha: 0.45),
                    blurRadius: 28,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                active ? Icons.stop_rounded : Icons.power_settings_new,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            active ? 'Выключить' : 'Включить',
            style: TextStyle(
              color: active ? const Color(AppConfig.colorError) : const Color(AppConfig.colorText),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
