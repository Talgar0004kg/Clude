import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lesson.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/step_progress.dart';
import 'practice_done_screen.dart';

/// Письмо (Жазуу): показываем русское слово, нужно написать его по-кыргызски.
class WritingScreen extends StatefulWidget {
  final Lesson lesson;
  const WritingScreen({super.key, required this.lesson});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  final _controller = TextEditingController();
  int _index = 0;
  int _correct = 0;
  bool? _isCorrect;

  List<WordPair> get _words => widget.lesson.words;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll('!', '').replaceAll('?', '');

  void _check() {
    final ok = _normalize(_controller.text) == _normalize(_words[_index].kyrgyz);
    setState(() => _isCorrect = ok);
    if (ok) _correct++;
  }

  void _next() {
    if (_isCorrect == null) {
      _check();
      return;
    }
    if (_index < _words.length - 1) {
      setState(() {
        _index++;
        _isCorrect = null;
        _controller.clear();
      });
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await context.read<AppState>().addLearnedWords(_correct);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PracticeDoneScreen(
        title: 'Жазуу',
        message: 'Правильно написано: $_correct из ${_words.length}',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final w = _words[_index];
    return Scaffold(
      appBar: AppBar(title: const Text('Жазуу')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StepProgress(current: _index + 1, total: _words.length),
              const SizedBox(height: 28),
              const Text('Сөздү кыргызчага жазыңыз',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 24),
              Text(w.russian,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                enabled: _isCorrect == null,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Напишите по-кыргызски...'),
                onSubmitted: (_) => _check(),
              ),
              const SizedBox(height: 20),
              if (_isCorrect != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isCorrect!
                        ? const Color(0xFFE9F7EE)
                        : const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isCorrect!
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: _isCorrect!
                                ? AppColors.success
                                : AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(_isCorrect! ? 'Туура!' : 'Туура эмес',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _isCorrect!
                                      ? AppColors.success
                                      : AppColors.error)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(w.kyrgyz,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _next,
                child: Text(_isCorrect == null ? 'Текшерүү' : 'Кийинки'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
