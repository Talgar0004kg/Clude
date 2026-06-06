import 'dart:math';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/gemini_service.dart';

class WaveformWidget extends StatelessWidget {
  final AssistantState state;
  final AnimationController controller;

  const WaveformWidget({super.key, required this.state, required this.controller});

  Color get _orbColor {
    switch (state) {
      case AssistantState.idle:
        return const Color(AppConfig.colorAccent);
      case AssistantState.listening:
        return const Color(0xFF06B6D4);
      case AssistantState.thinking:
        return const Color(0xFF7C3AED);
      case AssistantState.speaking:
        return const Color(AppConfig.colorSuccess);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _OrbPainter(
            progress: controller.value,
            color: _orbColor,
            state: state,
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double progress;
  final Color color;
  final AssistantState state;

  _OrbPainter({required this.progress, required this.color, required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.28;

    // Glow rings
    for (int i = 3; i >= 1; i--) {
      final ringProgress = (progress + i * 0.2) % 1.0;
      final ringRadius = baseRadius + (i * 20 * ringProgress);
      final alpha = ((1 - ringProgress) * 60).toInt().clamp(0, 255);
      final paint = Paint()
        ..color = color.withAlpha(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, ringRadius, paint);
    }

    // Core orb
    final gradient = RadialGradient(colors: [color, color.withValues(alpha:0.6)]);
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: baseRadius));
    canvas.drawCircle(center, baseRadius, paint);

    // Waveform for listening/speaking
    if (state == AssistantState.listening || state == AssistantState.speaking) {
      _drawWave(canvas, size, center);
    }
  }

  void _drawWave(Canvas canvas, Size size, Offset center) {
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha:0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final w = size.width;
    final amp = state == AssistantState.speaking ? 12.0 : 6.0;
    for (double x = 0; x <= w; x++) {
      final y = center.dy + sin((x / w * 2 * pi) + (progress * 2 * pi)) * amp;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.progress != progress || old.state != state;
}
