import 'package:flutter/material.dart';
import '../../theme.dart';

/// Экран завершения практики.
class PracticeDoneScreen extends StatelessWidget {
  final String title;
  final String message;
  const PracticeDoneScreen({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.primary, size: 56),
              ),
              const SizedBox(height: 24),
              const Text('Азаматсыз! 🎉',
                  style:
                      TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 15)),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst),
                child: const Text('Башкы бетке кайтуу'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
