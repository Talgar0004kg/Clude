import 'package:flutter/material.dart';
import '../config/app_config.dart';

class BlockedBanner extends StatelessWidget {
  final String message;
  const BlockedBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(AppConfig.colorError).withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(AppConfig.colorError).withValues(alpha:0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, color: Color(AppConfig.colorError), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Color(AppConfig.colorError), fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
