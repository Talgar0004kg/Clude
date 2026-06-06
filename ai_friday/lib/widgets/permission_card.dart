import 'package:flutter/material.dart';
import '../config/app_config.dart';

class PermissionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool granted;
  final VoidCallback onRequest;

  const PermissionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.granted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: granted ? const Color(AppConfig.colorSuccess) : const Color(AppConfig.colorAccent)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(AppConfig.colorText), fontWeight: FontWeight.w600)),
                Text(description, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
              ],
            ),
          ),
          if (!granted)
            TextButton(
              onPressed: onRequest,
              child: const Text('Дать'),
            )
          else
            const Icon(Icons.check_circle, color: Color(AppConfig.colorSuccess)),
        ],
      ),
    );
  }
}
