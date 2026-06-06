import 'package:flutter/material.dart';
import '../config/app_config.dart';

class ListeningIndicator extends StatefulWidget {
  const ListeningIndicator({super.key});

  @override
  State<ListeningIndicator> createState() => _ListeningIndicatorState();
}

class _ListeningIndicatorState extends State<ListeningIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i * 0.2;
          final value = ((_ctrl.value + delay) % 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: 4 + (value * 16),
            decoration: BoxDecoration(
              color: const Color(AppConfig.colorAccent),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
