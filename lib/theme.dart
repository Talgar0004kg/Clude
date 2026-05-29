import 'package:flutter/material.dart';

/// Цветовая палитра и оформление приложения «Кыргыз тили».
class AppColors {
  static const Color primary = Color(0xFF13937F);
  static const Color primaryDark = Color(0xFF0E7567);
  static const Color primaryLight = Color(0xFFE3F3EF);
  static const Color accent = Color(0xFF3BB89B);
  static const Color background = Color(0xFFF4F6F8);
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF1C2B2A);
  static const Color textMuted = Color(0xFF8A9794);
  static const Color success = Color(0xFF34A853);
  static const Color error = Color(0xFFE5484D);

  // Мягкие фоновые цвета для иконок уроков.
  static const List<Color> lessonTints = [
    Color(0xFFE7E2FB),
    Color(0xFFFBE2EC),
    Color(0xFFFFF0D6),
    Color(0xFFE0F3EF),
    Color(0xFFFFF6D6),
    Color(0xFFE3EEFB),
    Color(0xFFFDE8DC),
  ];
}

ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.textDark,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.textDark,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
  );
}

/// Тень для карточек.
const List<BoxShadow> cardShadow = [
  BoxShadow(
    color: Color(0x0F1C2B2A),
    blurRadius: 18,
    offset: Offset(0, 8),
  ),
];
