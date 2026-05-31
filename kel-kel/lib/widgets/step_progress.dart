import 'package:flutter/material.dart';
import '../theme.dart';

/// Полоса прогресса с подписью «N/Total» как на макетах практики.
class StepProgress extends StatelessWidget {
  final int current; // 1-based
  final int total;
  const StepProgress({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : current / total;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8E6),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('$current/$total',
            style: const TextStyle(
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
