import 'package:flutter/material.dart';
import '../services/speech.dart';
import '../theme.dart';

/// Круглая кнопка с иконкой динамика для озвучивания слова.
class SpeakerButton extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;

  const SpeakerButton({
    super.key,
    required this.text,
    this.size = 44,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(size),
      onTap: () => Speech.instance.speak(text),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.volume_up_rounded, color: c, size: size * 0.5),
      ),
    );
  }
}
