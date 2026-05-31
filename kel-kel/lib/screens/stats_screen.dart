import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/lessons_data.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Статистика обучения (Статистика).
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              _Card(
                icon: Icons.menu_book_rounded,
                value: '${app.completedLessons.length}/${kLessons.length}',
                label: 'Завершено уроков',
              ),
              const SizedBox(width: 12),
              _Card(
                icon: Icons.translate_rounded,
                value: '${app.learnedWords}',
                label: 'Изучено слов',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Card(
                icon: Icons.local_fire_department_rounded,
                value: '${app.streakDays}',
                label: 'Дней подряд',
              ),
              const SizedBox(width: 12),
              _Card(
                icon: Icons.show_chart_rounded,
                value: '${app.progressPercent}%',
                label: 'Общий прогресс',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Прогресс по урокам',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...kLessons.map((l) {
            final done = app.isLessonCompleted(l.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: cardShadow,
                ),
                child: Row(
                  children: [
                    Icon(l.icon,
                        color: done
                            ? AppColors.primary
                            : AppColors.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('${l.id}. ${l.title}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text(done ? 'Завершён' : 'Не начат',
                        style: TextStyle(
                            color: done
                                ? AppColors.success
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Card(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
