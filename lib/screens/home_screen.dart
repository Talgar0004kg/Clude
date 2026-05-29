import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/lessons_data.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'lesson_detail_screen.dart';
import 'lessons_screen.dart';

/// Главный экран (Башкы бет).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final goalProgress =
        app.dailyGoal == 0 ? 0.0 : app.dailyDone / app.dailyGoal;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text('Башкы бет',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              Icon(Icons.notifications_none_rounded,
                  color: AppColors.textDark),
            ],
          ),
          const SizedBox(height: 6),
          Text('Салам, ${app.userName ?? 'окуучу'}! 👋',
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 18),

          // Карточка дневной цели
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1AA98F), Color(0xFF0E7567)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Күнүмдүк максат · Цель на день',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Text('${app.dailyDone} / ${app.dailyGoal} сөз',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: goalProgress.clamp(0, 1).toDouble(),
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Заголовок раздела уроков
          Row(
            children: [
              const Expanded(
                child: Text('Сабактар',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LessonsScreen())),
                child: const Text('Бардык сабактар ›',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...kLessons.take(4).map((lesson) {
            final unlocked = app.isLessonUnlocked(lesson.id);
            final done = app.isLessonCompleted(lesson.id);
            final idx = lesson.id - 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LessonRow(
                lesson: lesson,
                tint: AppColors.lessonTints[idx % AppColors.lessonTints.length],
                unlocked: unlocked,
                done: done,
                onTap: unlocked
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LessonDetailScreen(lesson: lesson)))
                    : null,
              ),
            );
          }),

          const SizedBox(height: 12),

          // Дневная задача
          const Text('Күнүмдүк тапшырма · Задание дня',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.task_alt_rounded,
                      color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Изучите 20 новых слов',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${app.dailyDone}/${app.dailyGoal}',
                          style:
                              const TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final dynamic lesson;
  final Color tint;
  final bool unlocked;
  final bool done;
  final VoidCallback? onTap;

  const _LessonRow({
    required this.lesson,
    required this.tint,
    required this.unlocked,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(lesson.icon, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${lesson.id}. ${lesson.title}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${lesson.wordCount} сөз · ${lesson.subtitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (done)
              const Icon(Icons.check_circle_rounded, color: AppColors.success)
            else if (!unlocked)
              const Icon(Icons.lock_rounded, color: AppColors.textMuted)
            else
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
