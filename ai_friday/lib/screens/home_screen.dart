import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/gemini_service.dart';
import '../services/key_manager.dart';
import '../services/voice_service.dart';
import '../core/context_manager.dart';
import '../core/security_guard.dart';
import '../core/action_executor.dart';
import '../core/command_parser.dart';
import '../services/intent_service.dart';
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

  AssistantState _state = AssistantState.idle;
  String _transcript = '';
  String _response = '';
  bool _serviceRunning = false; // непрерывный режим разговора
  bool _stopRequested = false;
  // Слово-активатор: в hands-free режиме запрос к ИИ уходит только при обращении.
  bool _wakeWordEnabled = true;
  static const List<String> _wakeWords = [
    'пятница', 'пятницу', 'пятницы', 'пятниц', 'friday', 'фрайдей', 'фрайди', 'фрайдэй'
  ];
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
    _voice.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _levelSub?.cancel();
    _voice.stopListening();
    _voice.stopSpeaking();
    _orbController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Вернулись в приложение в активном режиме — снова слушаем.
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

  /// Кнопка Вкл/Выкл — включает/выключает непрерывный режим разговора.
  Future<void> _toggleService() async {
    if (_serviceRunning) {
      await _stopConversation();
      await _voice.speak('Пятница отключена');
    } else {
      _stopRequested = false;
      setState(() => _serviceRunning = true);
      await _voice.speak('Пятница активирована. Слушаю вас.');
      await _beginListening();
    }
  }

  /// Полная остановка разговора (ручная).
  Future<void> _stopConversation() async {
    _stopRequested = true;
    await _voice.stopListening();
    await _voice.stopSpeaking();
    if (mounted) {
      setState(() {
        _serviceRunning = false;
        _state = AssistantState.idle;
        _level = 0.0;
      });
    }
  }

  /// Запускает прослушивание (с паузой 3 сек на «договорить»).
  Future<void> _beginListening() async {
    await _voice.stopSpeaking();
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
        // Тишина без фразы: в непрерывном режиме слушаем снова.
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

  /// В непрерывном режиме возобновляет прослушивание после паузы.
  void _maybeResume() {
    if (_serviceRunning && !_stopRequested && mounted) {
      _scheduleResume();
    }
  }

  void _scheduleResume() {
    Future.delayed(const Duration(milliseconds: 500), () {
      // Не слушаем в фоне (например, после открытия WhatsApp) — только когда
      // приложение на экране.
      final resumed = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (_serviceRunning && !_stopRequested && mounted && resumed && !_voice.isListening) {
        _beginListening();
      }
    });
  }

  Future<void> processCommand(String text) async {
    final spoken = text.trim();
    if (spoken.isEmpty) {
      _maybeResume();
      return;
    }

    // Слово-активатор: реагируем только на обращение «Пятница …».
    String effective = spoken;
    if (_wakeWordEnabled) {
      final cmd = _extractAfterWake(spoken);
      if (cmd == null) {
        // К Пятнице не обращались — не тратим запрос к ИИ, слушаем дальше.
        _maybeResume();
        return;
      }
      if (cmd.isEmpty) {
        // Сказали только имя — коротко отзываемся без запроса к API.
        await _say('Да, слушаю.');
        _setState(AssistantState.idle);
        _maybeResume();
        return;
      }
      effective = cmd;
    }

    _context.add(Message(
      id: DateTime.now().toIso8601String(),
      text: effective,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    ));
    if (mounted) setState(() => _response = '');

    try {
      if (!SecurityGuard.isAllowed(effective)) {
        await _say(SecurityGuard.blockMessage());
        return;
      }

      _setState(AssistantState.thinking);

      // Локальные команды (без обращения к ИИ).
      final localResult = await CommandParser.tryParse(effective);
      if (localResult != null && localResult.matched) {
        await _say(localResult.success ? 'Выполнено.' : 'Не удалось выполнить.');
        return;
      }

      // Запрос к Gemini — один на команду.
      final reply = await _gemini.sendMessageStream(effective);
      if (reply == null) {
        await _say('Не удалось получить ответ. Проверьте интернет и ключ.');
        return;
      }

      final data = _parseAction(reply);
      if (data != null) {
        // Это команда телефону: озвучиваем speech и выполняем все шаги локально.
        final speech = (data['speech'] as String?)?.trim();
        await _say((speech != null && speech.isNotEmpty) ? speech : 'Выполняю.');
        final ok = await ActionExecutor.executeMap(data);
        if (!ok) {
          await _voice.speak('Не получилось. Проверьте, что контакт есть в телефоне и приложение установлено.');
        }
      } else {
        // Обычный ответ — проговариваем.
        if (mounted) setState(() {
          _state = AssistantState.speaking;
          _response = reply;
        });
        await _voice.speak(reply);
      }

      _context.add(Message(
        id: '${DateTime.now().toIso8601String()}_r',
        text: reply,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      ));
    } finally {
      _setState(AssistantState.idle);
      _maybeResume();
    }
  }

  /// Возвращает команду после слова-активатора «Пятница».
  /// null — обращения не было; '' — сказали только имя.
  String? _extractAfterWake(String phrase) {
    final lower = phrase.toLowerCase();
    for (final w in _wakeWords) {
      final idx = lower.indexOf(w);
      if (idx == -1) continue;
      final lead = RegExp(r'^[\s,.:;!?\-—]+');
      final trail = RegExp(r'[\s,.:;!?\-—]+$');
      // Часть после имени («Пятница, открой …»).
      final after = phrase.substring(idx + w.length).replaceFirst(lead, '').trim();
      if (after.isNotEmpty) return after;
      // Имя в конце («открой телеграм, пятница») — берём часть до имени.
      final before = phrase.substring(0, idx).replaceFirst(trail, '').trim();
      return before; // '' если фраза состояла только из имени
    }
    return null;
  }

  /// Показывает и проговаривает короткую фразу.
  Future<void> _say(String msg) async {
    if (mounted) setState(() {
      _state = AssistantState.speaking;
      _response = msg;
    });
    await _voice.speak(msg);
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
                      maxLines: 6,
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
            AssistantState.speaking: 'Отвечаю...',
          }[_state] ??
          '';
    }
    return Text(
      label,
      style: TextStyle(
        color: !_serviceRunning ? const Color(0xFF6B7280) : const Color(AppConfig.colorAccent),
        fontSize: 16,
      ),
    );
  }

  Widget _bottomControls() {
    final active = _serviceRunning;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          // Главная кнопка: включить / выключить ассистента (hands-free).
          GestureDetector(
            onTap: _toggleService,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: active ? const Color(AppConfig.colorError) : const Color(AppConfig.colorAccent),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (active ? const Color(AppConfig.colorError) : const Color(AppConfig.colorAccent))
                        .withValues(alpha: 0.45),
                    blurRadius: 26,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                active ? Icons.stop_rounded : Icons.power_settings_new,
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            active ? 'Выключить' : 'Включить',
            style: TextStyle(
              color: active ? const Color(AppConfig.colorError) : const Color(AppConfig.colorText),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _quickBtn(Icons.phone, 'Телефон', () => IntentService.openApp('phone')),
              _quickBtn(Icons.message, 'Сообщения', () => IntentService.openApp('messages')),
              _quickBtn(Icons.calendar_today, 'Календарь', () => IntentService.openApp('calendar')),
              _quickBtn(
                _context.privateMode ? Icons.lock : Icons.lock_open,
                'Приватно',
                () => setState(() => _context.setPrivateMode(!_context.privateMode)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(AppConfig.colorAccent), size: 22),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
      ]),
    );
  }
}
