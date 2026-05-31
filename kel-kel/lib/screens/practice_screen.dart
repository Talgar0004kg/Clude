import 'package:flutter/material.dart';
import '../data/lessons_data.dart';
import '../theme.dart';
import 'practice/words_screen.dart';
import 'practice/listening_screen.dart';
import 'practice/writing_screen.dart';
import 'practice/test_screen.dart';

/// Меню практики (Практика).
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Для практики используем первый урок по умолчанию.
    final lesson = kLessons.first;
    final items = [
      _Item(
        icon: Icons.text_fields_rounded,
        tint: const Color(0xFFFDEDED),
        iconColor: const Color(0xFFE5736B),
        title: 'Сөздөр',
        subtitle: 'Изучайте новые слова',
        builder: (_) => WordsScreen(lesson: lesson),
      ),
      _Item(
        icon: Icons.headphones_rounded,
        tint: const Color(0xFFE7EEFB),
        iconColor: const Color(0xFF5B8DEF),
        title: 'Угуу',
        subtitle: 'Слушайте и понимайте',
        builder: (_) => ListeningScreen(lesson: lesson),
      ),
      _Item(
        icon: Icons.edit_rounded,
        tint: const Color(0xFFE2F3EE),
        iconColor: AppColors.primary,
        title: 'Жазуу',
        subtitle: 'Учитесь писать',
        builder: (_) => WritingScreen(lesson: lesson),
      ),
      _Item(
        icon: Icons.checklist_rounded,
        tint: const Color(0xFFFBE7F0),
        iconColor: const Color(0xFFE06AA0),
        title: 'Тест',
        subtitle: 'Проверьте свои знания',
        builder: (_) => TestScreen(lesson: lesson),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Практика',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Выберите режим тренировки',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 18),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: it.builder)),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: it.tint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(it.icon, color: it.iconColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(it.subtitle,
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
  _Item({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}
