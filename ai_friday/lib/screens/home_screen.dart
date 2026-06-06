import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/gemini_service.dart';
import '../services/key_manager.dart';
import '../services/foreground_service.dart';
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

  AssistantState _state = AssistantState.idle;
  String _transcript = '';
  String _response = '';
  bool _serviceRunning = false;
  int _navIndex = 0;

  late AnimationController _orbController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _gemini.stateStream.listen((s) => setState(() => _state = s));
    _gemini.responseStream.listen((r) => setState(() => _response = r));
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _toggleService() async {
    if (_serviceRunning) {
      await ForegroundService.stop();
    } else {
      await ForegroundService.start();
    }
    setState(() => _serviceRunning = !_serviceRunning);
  }

  Future<void> _startListening() async {
    setState(() {
      _state = AssistantState.listening;
      _transcript = '';
      _response = '';
    });
    // Real audio recording will call processCommand(transcript) when done
  }

  Future<void> processCommand(String text) async {
    if (!SecurityGuard.isAllowed(text)) {
      setState(() => _response = SecurityGuard.blockMessage());
      return;
    }

    final localResult = await CommandParser.tryParse(text);
    if (localResult != null && localResult.matched) {
      setState(() => _response = localResult.success ? 'Выполнено.' : 'Не удалось выполнить.');
      return;
    }

    final reply = await _gemini.sendMessageStream(text, onChunk: (chunk) {
      setState(() => _response += chunk);
    });

    if (reply != null && TextUtils.isJson(reply)) {
      await ActionExecutor.execute(reply);
    }

    if (reply != null) {
      _context.add(Message(
        id: DateTime.now().toIso8601String(),
        text: text,
        role: MessageRole.user,
        timestamp: DateTime.now(),
      ));
      _context.add(Message(
        id: '${DateTime.now().toIso8601String()}_r',
        text: reply,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      ));
    }
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
        indicatorColor: const Color(AppConfig.colorAccent).withValues(alpha:0.2),
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
                WaveformWidget(state: _state, controller: _orbController),
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
                      maxLines: 5,
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
      AssistantState.idle: 'Нажмите для разговора',
      AssistantState.listening: 'Слушаю...',
      AssistantState.thinking: 'Думаю...',
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
                    color: const Color(AppConfig.colorAccent).withValues(alpha:0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 32),
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
