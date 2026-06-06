import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/command.dart';

class PreviewCard extends StatelessWidget {
  final Command command;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PreviewCard({
    super.key,
    required this.command,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(AppConfig.colorAccent).withValues(alpha:0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(command.speech, style: const TextStyle(color: Color(AppConfig.colorText), fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(AppConfig.colorAccent)),
                  child: const Text('Выполнить', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
