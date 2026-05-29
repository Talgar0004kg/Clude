import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Достижения (Жетишкендиктер).
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final items = [
      _Achievement(
        icon: Icons.star_rounded,
        color: const Color(0xFFF5B544),
        tint: const Color(0xFFFFF3DA),
        title: 'Алгачкы кадам',
        desc: 'Изучите первые 10 слов',
        unlocked: app.learnedWords >= 10,
      ),
      _Achievement(
        icon: Icons.headphones_rounded,
        color: const Color(0xFF5B8DEF),
        tint: const Color(0xFFE7EEFB),
        title: 'Угуу чебери',
        desc: 'Выполните 20 заданий на аудирование',
        unlocked: app.learnedWords >= 20,
      ),
      _Achievement(
        icon: Icons.shield_rounded,
        color: const Color(0xFFF5934A),
        tint: const Color(0xFFFDEEDD),
        title: 'Туруктуулук',
        desc: 'Учитесь 7 дней подряд',
        unlocked: app.streakDays >= 7,
      ),
      _Achievement(
        icon: Icons.edit_rounded,
        color: const Color(0xFFE06AA0),
        tint: const Color(0xFFFBE7F0),
        title: 'Жазуу чебери',
        desc: 'Выполните 10 заданий на письмо',
        unlocked: app.learnedWords >= 30,
      ),
      _Achievement(
        icon: Icons.school_rounded,
        color: AppColors.primary,
        tint: AppColors.primaryLight,
        title: 'Билим чебери',
        desc: 'Наберите 80% в тестах',
        unlocked: app.progressPercent >= 80,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Жетишкендиктер')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final a = items[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: cardShadow,
            ),
            child: Opacity(
              opacity: a.unlocked ? 1 : 0.5,
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: a.tint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(a.icon, color: a.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(a.desc,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Icon(
                    a.unlocked
                        ? Icons.check_circle_rounded
                        : Icons.lock_outline_rounded,
                    color: a.unlocked
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Achievement {
  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String desc;
  final bool unlocked;
  _Achievement({
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    required this.desc,
    required this.unlocked,
  });
}
