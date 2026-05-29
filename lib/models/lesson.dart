import 'package:flutter/material.dart';

/// Одна словарная пара: кыргызское слово и его перевод на русский.
class WordPair {
  final String kyrgyz;
  final String russian;

  const WordPair(this.kyrgyz, this.russian);
}

/// Урок с набором слов.
class Lesson {
  final int id;
  final String title; // название на кыргызском
  final String subtitle; // короткое описание / тема на русском
  final IconData icon;
  final List<WordPair> words;

  const Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.words,
  });

  int get wordCount => words.length;
}
