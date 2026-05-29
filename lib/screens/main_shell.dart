import 'package:flutter/material.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'lessons_screen.dart';
import 'practice_screen.dart';
import 'profile_screen.dart';

/// Основной каркас с нижней навигацией.
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;

  final _screens = const [
    HomeScreen(),
    LessonsScreen(),
    PracticeScreen(),
    ProfileScreen(),
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: _BottomBar(index: _index, onTap: _go),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.index, required this.onTap});

  static const _items = [
    (Icons.home_rounded, 'Башкы бет'),
    (Icons.menu_book_rounded, 'Сабактар'),
    (Icons.check_circle_outline_rounded, 'Практика'),
    (Icons.person_rounded, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _items[i].$1,
                          size: 24,
                          color: i == index
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _items[i].$2,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                i == index ? FontWeight.w700 : FontWeight.w500,
                            color: i == index
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
