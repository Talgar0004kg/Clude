import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/app_config.dart';
import '../services/key_manager.dart';
import '../utils/permission_utils.dart';
import '../services/intent_service.dart';
import '../services/accessibility_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  final _keyController = TextEditingController();
  String? _keyError;
  bool _keyValid = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // Предзаполняем поле ключом из .env, если он там задан.
    final envKey = (dotenv.maybeGet('GEMINI_API_KEY') ?? '').trim();
    if (envKey.startsWith('AIza') && envKey.length > 20) {
      _keyController.text = envKey;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _keyController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 4) {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _page++);
    }
  }

  Future<void> _checkKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _keyError = 'Введите ключ');
      return;
    }
    setState(() { _checking = true; _keyError = null; });
    await KeyManager().addKey(key);
    setState(() { _checking = false; _keyValid = true; });
    _next();
  }

  Future<void> _requestPermissions() async {
    await PermissionUtils.requestAll();
    _next();
  }

  Future<void> _openAccessibility() async {
    await IntentService.openAccessibilitySettings();
    // Poll until enabled
    _waitForAccessibility();
  }

  void _waitForAccessibility() async {
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (await AccessibilityServiceManager.isEnabled()) {
        if (mounted) _next();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.colorBackground),
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        children: [_welcome(), _apiKey(), _permissions(), _accessibility(), _done()],
      ),
    );
  }

  Widget _welcome() => _page_(
    icon: Icons.assistant,
    title: 'Добро пожаловать!',
    subtitle: 'Я Пятница — ваш персональный\nассистент. Давайте настроим всё\nза 2 минуты.',
    button: 'Начать',
    onTap: _next,
  );

  Widget _apiKey() => _page_(
    icon: Icons.key,
    title: 'API Ключ Gemini',
    subtitle: 'Получите бесплатный ключ на\naistudio.google.com',
    button: _keyValid ? 'Ключ принят ✓' : 'Проверить ключ',
    onTap: _keyValid ? _next : _checkKey,
    extra: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        TextField(
          controller: _keyController,
          style: const TextStyle(color: Color(AppConfig.colorText)),
          decoration: InputDecoration(
            hintText: 'AIzaSy...',
            hintStyle: const TextStyle(color: Color(0xFF6B7280)),
            errorText: _keyError,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF374151)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(AppConfig.colorAccent)),
            ),
          ),
        ),
        if (_checking) const Padding(
          padding: EdgeInsets.only(top: 12),
          child: CircularProgressIndicator(color: Color(AppConfig.colorAccent)),
        ),
      ]),
    ),
  );

  Widget _permissions() => _page_(
    icon: Icons.security,
    title: 'Разрешения',
    subtitle: 'Нужно несколько разрешений\nдля работы ассистента',
    button: 'Дать разрешения',
    onTap: _requestPermissions,
    extra: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        _PermRow(icon: Icons.mic, text: 'Микрофон — для голоса'),
        _PermRow(icon: Icons.contacts, text: 'Контакты — для звонков'),
        _PermRow(icon: Icons.phone, text: 'Телефон — для вызовов'),
        _PermRow(icon: Icons.notifications, text: 'Уведомления — для фона'),
      ]),
    ),
  );

  Widget _accessibility() => _page_(
    icon: Icons.accessibility_new,
    title: 'Специальные\nвозможности',
    subtitle: 'Последний шаг! Включите доступность\nдля управления телефоном.',
    button: 'Открыть настройки',
    onTap: _openAccessibility,
  );

  Widget _done() => _page_(
    icon: Icons.check_circle_outline,
    title: 'Пятница готова!',
    subtitle: 'Нажмите кнопку и скажите\nчто-нибудь.',
    button: 'Попробовать',
    onTap: () => Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    ),
  );

  Widget _page_({
    required IconData icon,
    required String title,
    required String subtitle,
    required String button,
    required VoidCallback onTap,
    Widget? extra,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(AppConfig.colorAccent).withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: const Color(AppConfig.colorAccent), size: 40),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(AppConfig.colorText),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 16, height: 1.5),
            ),
            if (extra != null) ...[const SizedBox(height: 24), extra],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConfig.colorAccent),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(button, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PermRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: const Color(AppConfig.colorAccent), size: 20),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Color(AppConfig.colorText), fontSize: 15)),
      ]),
    );
  }
}
