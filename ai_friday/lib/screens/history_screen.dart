import 'package:flutter/material.dart';
import '../config/app_config.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.colorBackground),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('История', style: TextStyle(color: Color(AppConfig.colorText))),
      ),
      body: const Center(
        child: Text('История команд пуста', style: TextStyle(color: Color(0xFF6B7280))),
      ),
    );
  }
}
