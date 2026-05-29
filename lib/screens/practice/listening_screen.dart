import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lesson.dart';
import '../../services/speech.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/step_progress.dart';
import 'practice_done_screen.dart';

/// Аудирование (Угуу): прослушайте слово и выберите правильный перевод.
class ListeningScreen extends StatefulWidget {
  final Lesson lesson;
  const ListeningScreen({super.key, required this.lesson});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> {
  final _rng = Random();
  int _index = 0;
  int _correct = 0;
  int? _selected;
  late List<List<String>> _options;

  List<WordPair> get _words => widget.lesson.words;

  @override
  void initState() {
    super.initState();
    _buildOptions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrent());
  }

  void _buildOptions() {
    _options = List.generate(_words.length, (i) {
      final correct = _words[i].russian;
      final pool = _words.map((e) => e.russian).where((e) => e != correct).toList()
        ..shuffle(_rng);
      final opts = [correct, ...pool.take(3)]..shuffle(_rng);
      return opts;
    });
  }

  void _playCurrent() => Speech.instance.speak(_words[_index].kyrgyz);

  void _next() {
    if (_selected == null) return;
    if (_options[_index][_selected!] == _words[_index].russian) _correct++;
    if (_index < _words.length - 1) {
      setState(() {
        _index++;
        _selected = null;
      });
      _playCurrent();
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await context.read<AppState>().addLearnedWords(_correct);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PracticeDoneScreen(
        title: 'Угуу',
        message: 'Правильных ответов: $_correct из ${_words.length}',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final opts = _options[_index];
    final correct = _words[_index].russian;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Угуу'),
        actions: [
          IconButton(
              onPressed: _playCurrent,
              icon: const Icon(Icons.volume_up_rounded)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            children: [
              StepProgress(current: _index + 1, total: _words.length),
              const SizedBox(height: 28),
              const Text('Угуу, туура котормонузду тандаңыз',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 28),
              InkWell(
                customBorder: const CircleBorder(),
                onTap: _playCurrent,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.volume_up_rounded,
                      color: Colors.white, size: 34),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: opts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final selected = _selected == i;
                    final showResult = _selected != null;
                    Color border = const Color(0xFFE2E8E6);
                    Color bg = Colors.white;
                    if (showResult && opts[i] == correct) {
                      border = AppColors.success;
                      bg = const Color(0xFFE9F7EE);
                    } else if (selected && opts[i] != correct) {
                      border = AppColors.error;
                      bg = const Color(0xFFFDECEC);
                    } else if (selected) {
                      border = AppColors.primary;
                      bg = AppColors.primaryLight;
                    }
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _selected == null
                          ? () => setState(() => _selected = i)
                          : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border, width: 1.4),
                        ),
                        child: Text(opts[i],
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _selected == null ? null : _next,
                child: const Text('Кийинки'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
