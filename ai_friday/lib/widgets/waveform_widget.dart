import 'dart:math';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/gemini_service.dart';

class WaveformWidget extends StatelessWidget {
  final AssistantState state;
  final AnimationController controller;

  /// Уровень громкости микрофона (0..1) во время прослушивания.
  final double level;

  const WaveformWidget({
    super.key,
    required this.state,
    required this.controller,
    this.level = 0.0,
  });

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
          size: const Size(220, 220),
          painter: _OrbPainter(
            progress: controller.value,
            color: _orbColor,
            state: state,
            level: level,
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
  final double level;

  _OrbPainter({
    required this.progress,
    required this.color,
    required this.state,
    required this.level,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.26;

    // Орб «дышит» по уровню голоса при прослушивании, иначе мягкая пульсация.
    final breath = state == AssistantState.listening
        ? level * 0.35
        : (state == AssistantState.speaking ? (sin(progress * 2 * pi) * 0.12 + 0.12) : 0.0);
    final orbRadius = baseRadius * (1 + breath);

    // Внешние кольца-волны.
    final active = state == AssistantState.listening || state == AssistantState.speaking;
    final ringBoost = state == AssistantState.listening ? (0.5 + level) : 1.0;
    for (int i = 3; i >= 1; i--) {
      final ringProgress = (progress + i * 0.2) % 1.0;
      final ringRadius = orbRadius + (i * 22 * ringProgress * (active ? ringBoost : 1.0));
      final alpha = ((1 - ringProgress) * (active ? 90 : 55)).toInt().clamp(0, 255);
      final paint = Paint()
        ..color = color.withAlpha(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, ringRadius, paint);
    }

    // Свечение.
    final glow = Paint()
      ..color = color.withAlpha((60 + level * 120).toInt().clamp(0, 255))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(center, orbRadius * 1.1, glow);

    // Ядро.
    final gradient = RadialGradient(colors: [color, color.withValues(alpha: 0.6)]);
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: orbRadius));
    canvas.drawCircle(center, orbRadius, paint);

    // Колеблющаяся волна по голосу.
    if (active) {
      _drawWave(canvas, size, center);
    }
  }

  void _drawWave(Canvas canvas, Size size, Offset center) {
    final w = size.width;
    // Амплитуда зависит от голоса при прослушивании, от анимации при ответе.
    final baseAmp = state == AssistantState.speaking ? 14.0 : 6.0;
    final amp = baseAmp + (state == AssistantState.listening ? level * 36.0 : 0.0);

    // Две перекрывающиеся синусоиды для «живой» волны.
    for (int layer = 0; layer < 2; layer++) {
      final path = Path();
      final phase = progress * 2 * pi + layer * pi / 2;
      final freq = 2.0 + layer;
      final layerAmp = amp * (layer == 0 ? 1.0 : 0.6);
      for (double x = 0; x <= w; x += 2) {
        final y = center.dy + sin((x / w * freq * pi) + phase) * layerAmp;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final wavePaint = Paint()
        ..color = Colors.white.withValues(alpha: layer == 0 ? 0.7 : 0.35)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.progress != progress || old.state != state || old.level != level;
}
