import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../theme.dart';
import '../widgets/speaker_button.dart';
import 'practice/words_screen.dart';

/// Детальный экран урока: список пар «кыргызский – русский».
class LessonDetailScreen extends StatelessWidget {
  final Lesson lesson;
  const LessonDetailScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${lesson.id}. ${lesson.title}')),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              itemCount: lesson.words.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final w = lesson.words[i];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: cardShadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                color: AppColors.textDark, fontSize: 15),
                            children: [
                              TextSpan(
                                text: w.kyrgyz,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              const TextSpan(
                                text: '  –  ',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                              TextSpan(
                                text: w.russian,
                                style: const TextStyle(
                                    color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SpeakerButton(text: w.kyrgyz, size: 36),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => WordsScreen(lesson: lesson)),
                ),
                child: const Text('Практика'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
