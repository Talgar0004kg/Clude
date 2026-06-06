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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _gemini = GeminiService();
  final _context = ContextManager();
  final _keyManager = KeyManager();
  final _voice = VoiceService();

  AssistantState _state = AssistantState.idle;
  String _transcript = '';
  String _response = '';
  bool _serviceRunning = false;
  int _navIndex = 0;
  double _level = 0.0;

  late AnimationController _orbController;
  StreamSubscription<double>? _levelSub;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _levelSub = _voice.levelStream.listen((lvl) {
      if (mounted) setState(() => _level = lvl);
    });
    _voice.init();
  }

  @override
  void dispose() {
    _levelSub?.cancel();
    _voice.stopListening();
    _voice.stopSpeaking();
    _orbController.dispose();
    super.dispose();
  }

  void _setState(AssistantState s) {
    if (mounted) setState(() => _state = s);
  }

  Future<void> _toggleService() async {
    if (_serviceRunning) {
      await _voice.stopListening();
      await _voice.stopSpeaking();
      setState(() {
        _serviceRunning = false;
        _state = AssistantState.idle;
        _level = 0.0;
      });
      await _voice.speak('Пятница отключена');
    } else {
      setState(() => _serviceRunning = true);
      await _voice.speak('Пятница активирована. Слушаю вас.');
    }
  }

  Future<void> _startListening() async {
    // Повторное нажатие во время прослушивания — остановить.
    if (_voice.isListening) {
      await _voice.stopListening();
      _setState(AssistantState.idle);
      return;
    }
    // Если говорит — прервать озвучку.
    await _voice.stopSpeaking();

    setState(() {
      _state = AssistantState.listening;
      _transcript = '';
      _response = '';
    });

    final ok = await _voice.startListening(
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
    );

    if (!ok) {
      setState(() {
        _state = AssistantState.idle;
        _response =
            'Распознавание речи недоступно. Установите/включите Google-распознавание и разрешите микрофон.';
      });
    }
  }

  Future<void> processCommand(String text) async {
    if (text.trim().isEmpty) return;

    _context.add(Message(
      id: DateTime.now().toIso8601String(),
      text: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    ));

    if (!SecurityGuard.isAllowed(text)) {
      final msg = SecurityGuard.blockMessage();
      setState(() {
        _state = AssistantState.speaking;
        _response = msg;
      });
      await _voice.speak(msg);
      _setState(AssistantState.idle);
      return;
    }

    _setState(AssistantState.thinking);

    // Локальные команды (без обращения к ИИ).
    final localResult = await CommandParser.tryParse(text);
    if (localResult != null && localResult.matched) {
      final reply = localResult.success ? 'Выполнено.' : 'Не удалось выполнить.';
      setState(() {
        _state = AssistantState.speaking;
        _response = reply;
      });
      await _voice.speak(reply);
      _setState(AssistantState.idle);
      return;
    }

    // Запрос к Gemini.
    final reply = await _gemini.sendMessageStream(text, onChunk: (chunk) {
      if (mounted) setState(() => _response += chunk);
    });

    if (reply == null) {
      const err = 'Не удалось получить ответ. Проверьте интернет и ключ.';
      setState(() {
        _state = AssistantState.speaking;
        _response = err;
      });
      await _voice.speak(err);
      _setState(AssistantState.idle);
      return;
    }

    // Если ответ — JSON с действиями, выполняем и озвучиваем поле speech.
    String speakText = reply;
    if (TextUtils.isJson(reply)) {
      speakText = _extractSpeech(reply) ?? 'Выполняю.';
      setState(() {
        _state = AssistantState.speaking;
        _response = speakText;
      });
      await _voice.speak(speakText);
      await ActionExecutor.execute(reply);
    } else {
      _setState(AssistantState.speaking);
      await _voice.speak(speakText);
    }

    _context.add(Message(
      id: '${DateTime.now().toIso8601String()}_r',
      text: reply,
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
    ));

    _setState(AssistantState.idle);
  }

  String? _extractSpeech(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr);
      if (map is Map && map['speech'] is String) return map['speech'] as String;
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
    final labels = {
      AssistantState.idle: 'Нажмите и говорите',
      AssistantState.listening: 'Слушаю...',
      AssistantState.thinking: 'Обрабатываю...',
      AssistantState.speaking: 'Отвечаю...',
    };
    return Text(
      labels[_state] ?? '',
      style: TextStyle(
        color: _state == AssistantState.idle ? const Color(0xFF6B7280) : const Color(AppConfig.colorAccent),
        fontSize: 16,
      ),
    );
  }

  Widget _bottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: _startListening,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _state == AssistantState.listening
                    ? const Color(AppConfig.colorError)
                    : const Color(AppConfig.colorAccent),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(AppConfig.colorAccent).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                _state == AssistantState.listening ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _quickBtn(Icons.phone, 'Звонок', () {}),
              _quickBtn(Icons.message, 'Сообщение', () {}),
              _quickBtn(Icons.calendar_today, 'Календарь', () {}),
              _quickBtn(Icons.lock_outline, 'Приватно', () {
                _context.setPrivateMode(!_context.privateMode);
              }),
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
