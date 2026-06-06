import 'package:flutter/material.dart';
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
    await Future.wait([
      KeyManager().init(),
      DeviceUtils.init(),
      NotificationService.init(),
      ContactService().load(),
    ]);
    CommandParser.init();

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
