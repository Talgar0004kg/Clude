import 'package:flutter/material.dart';
import '../config/app_config.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.colorBackground),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Статистика', style: TextStyle(color: Color(AppConfig.colorText))),
      ),
      body: const Center(
        child: Text('Статистика будет здесь', style: TextStyle(color: Color(0xFF6B7280))),
      ),
    );
  }
}
