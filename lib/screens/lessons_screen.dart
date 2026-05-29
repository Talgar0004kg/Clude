import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/lessons_data.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'lesson_detail_screen.dart';

/// Список всех уроков (Сабактар).
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        title: const Text('Сабактар'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: kLessons.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final lesson = kLessons[i];
          final unlocked = app.isLessonUnlocked(lesson.id);
          final done = app.isLessonCompleted(lesson.id);
          final tint =
              AppColors.lessonTints[i % AppColors.lessonTints.length];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: unlocked
                ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LessonDetailScreen(lesson: lesson)))
                : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Завершите предыдущий урок, чтобы открыть этот'),
                      ),
                    ),
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
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(lesson.icon, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${lesson.id}. ${lesson.title}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 3),
                        Text('${lesson.wordCount} сөз · ${lesson.subtitle}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  if (done)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success)
                  else if (!unlocked)
                    const Icon(Icons.lock_rounded, color: AppColors.textMuted)
                  else
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
