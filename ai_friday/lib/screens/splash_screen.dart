import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/app_config.dart';
import '../services/key_manager.dart';
import '../services/contact_service.dart';
import '../services/notification_service.dart';
import '../utils/device_utils.dart';
import '../core/command_parser.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Инициализация сервисов не должна ронять запуск: любой сбой (нет прав,
    // отсутствует плагин и т.п.) логируем, но продолжаем до навигации.
    await _safe(KeyManager().init());
    await Future.wait([
      _safe(DeviceUtils.init()),
      _safe(NotificationService.init()),
      _safe(ContactService().load()),
    ]);
    try {
      CommandParser.init();
    } catch (_) {}

    // Авто-подстановка ключа из .env (если он есть и валиден, а в хранилище ключа ещё нет),
    // чтобы не вводить его вручную в онбординге.
    try {
      if (!KeyManager().hasKey) {
        final envKey = (dotenv.maybeGet('GEMINI_API_KEY') ?? '').trim();
        if (envKey.startsWith('AIza') && envKey.length > 20) {
          await KeyManager().addKey(envKey);
        }
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final hasKey = KeyManager().hasKey;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => hasKey ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }

  Future<void> _safe(Future<void> future) async {
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.colorBackground),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(AppConfig.colorAccent),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.assistant, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              AppConfig.appName,
              style: TextStyle(
                color: Color(AppConfig.colorText),
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'F.R.I.D.A.Y.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, letterSpacing: 6),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Color(AppConfig.colorAccent)),
          ],
        ),
      ),
    );
  }
}
