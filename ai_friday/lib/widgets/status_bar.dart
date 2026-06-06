import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/key_manager.dart';

class StatusBar extends StatelessWidget {
  final bool serviceRunning;
  final KeyManager keyManager;
  final VoidCallback onToggle;

  const StatusBar({
    super.key,
    required this.serviceRunning,
    required this.keyManager,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final keys = keyManager.getAllKeys();
    final activeIdx = keys.indexWhere((k) => k.isActive);
    final remaining = keyManager.getRemainingRequests();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: serviceRunning ? const Color(AppConfig.colorSuccess) : const Color(0xFF6B7280),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            serviceRunning ? 'Пятница активна' : 'Пятница отключена',
            style: TextStyle(
              color: serviceRunning ? const Color(AppConfig.colorSuccess) : const Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          if (keys.isNotEmpty)
            Text(
              'Ключ ${activeIdx + 1} | $remaining запросов',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: serviceRunning
                    ? const Color(AppConfig.colorError).withValues(alpha:0.2)
                    : const Color(AppConfig.colorAccent).withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                serviceRunning ? 'Выкл' : 'Вкл',
                style: TextStyle(
                  color: serviceRunning ? const Color(AppConfig.colorError) : const Color(AppConfig.colorAccent),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
