import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lesson.dart';
import '../../services/speech.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/step_progress.dart';
import 'practice_done_screen.dart';

/// Карточки слов (Сөздөр): показываем кыргызское слово и перевод,
/// можно прослушать и отметить «Билем».
class WordsScreen extends StatefulWidget {
  final Lesson lesson;
  const WordsScreen({super.key, required this.lesson});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  int _index = 0;
  bool _revealed = false;

  List<WordPair> get _words => widget.lesson.words;

  void _next() {
    if (_index < _words.length - 1) {
      setState(() {
        _index++;
        _revealed = false;
      });
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final app = context.read<AppState>();
    await app.addLearnedWords(_words.length);
    await app.completeLesson(widget.lesson.id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PracticeDoneScreen(
        title: 'Сөздөр',
        message: 'Вы изучили ${_words.length} слов урока «${widget.lesson.title}»!',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final w = _words[_index];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сөздөр'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {
              _index = 0;
              _revealed = false;
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            children: [
              StepProgress(current: _index + 1, total: _words.length),
              const Spacer(),
              Text(
                w.kyrgyz,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                opacity: _revealed ? 1 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  w.russian,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 28),
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Speech.instance.speak(w.kyrgyz),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.volume_up_rounded,
                      color: AppColors.primary, size: 30),
                ),
              ),
              const SizedBox(height: 16),
              if (!_revealed)
                TextButton(
                  onPressed: () => setState(() => _revealed = true),
                  child: const Icon(Icons.play_circle_fill_rounded,
                      color: AppColors.primary, size: 44),
                )
              else
                const SizedBox(height: 44),
              const Spacer(),
              ElevatedButton(
                  onPressed: _next, child: const Text('Кийинки')),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _next,
                child: const Text('Билем',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
