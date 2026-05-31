import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/lessons_data.dart';

/// Глобальное состояние приложения: пользователь, прогресс, статистика.
/// Данные сохраняются локально через shared_preferences.
class AppState extends ChangeNotifier {
  static const _kUserName = 'user_name';
  static const _kUserEmail = 'user_email';
  static const _kLearnedWords = 'learned_words'; // суммарно изучено слов
  static const _kStreak = 'streak_days';
  static const _kCompletedLessons = 'completed_lessons'; // список id
  static const _kDailyDone = 'daily_done'; // слов за сегодня
  static const _kDailyDate = 'daily_date';

  SharedPreferences? _prefs;

  String? userName;
  String? userEmail;
  int learnedWords = 0;
  int streakDays = 0;
  Set<int> completedLessons = {};

  /// Дневная цель — количество слов.
  final int dailyGoal = 20;
  int dailyDone = 0;
  String _dailyDate = '';

  bool get isLoggedIn => userName != null;

  /// Прогресс в процентах по всему курсу.
  int get progressPercent {
    final total = kLessons.fold<int>(0, (s, l) => s + l.wordCount);
    if (total == 0) return 0;
    return ((learnedWords.clamp(0, total) / total) * 100).round();
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    userName = _prefs!.getString(_kUserName);
    userEmail = _prefs!.getString(_kUserEmail);
    learnedWords = _prefs!.getInt(_kLearnedWords) ?? 0;
    streakDays = _prefs!.getInt(_kStreak) ?? 0;
    final raw = _prefs!.getString(_kCompletedLessons);
    if (raw != null) {
      completedLessons =
          (jsonDecode(raw) as List).map((e) => e as int).toSet();
    }
    _dailyDate = _prefs!.getString(_kDailyDate) ?? '';
    dailyDone = _prefs!.getInt(_kDailyDone) ?? 0;
    _resetDailyIfNeeded();
    notifyListeners();
  }

  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  void _resetDailyIfNeeded() {
    if (_dailyDate != _today) {
      // Новый день: если вчера была активность — увеличиваем серию.
      if (_dailyDate.isNotEmpty && dailyDone > 0) {
        streakDays += 1;
      }
      _dailyDate = _today;
      dailyDone = 0;
      _prefs?.setString(_kDailyDate, _dailyDate);
      _prefs?.setInt(_kDailyDone, 0);
      _prefs?.setInt(_kStreak, streakDays);
    }
  }

  // --- Аутентификация (демо: локально) ---

  Future<void> register(String name, String email) async {
    userName = name.trim().isEmpty ? 'Окуучу' : name.trim();
    userEmail = email.trim();
    if (streakDays == 0) streakDays = 1;
    await _prefs?.setString(_kUserName, userName!);
    await _prefs?.setString(_kUserEmail, userEmail ?? '');
    await _prefs?.setInt(_kStreak, streakDays);
    notifyListeners();
  }

  Future<void> login(String email) async {
    userName ??= 'Азатбек';
    userEmail = email.trim().isEmpty ? 'azatbek@mail.com' : email.trim();
    if (streakDays == 0) streakDays = 1;
    await _prefs?.setString(_kUserName, userName!);
    await _prefs?.setString(_kUserEmail, userEmail!);
    await _prefs?.setInt(_kStreak, streakDays);
    notifyListeners();
  }

  Future<void> logout() async {
    await _prefs?.clear();
    userName = null;
    userEmail = null;
    learnedWords = 0;
    streakDays = 0;
    completedLessons = {};
    dailyDone = 0;
    _dailyDate = '';
    notifyListeners();
  }

  // --- Прогресс ---

  /// Засчитать изученные слова (например, после завершения практики урока).
  Future<void> addLearnedWords(int count) async {
    _resetDailyIfNeeded();
    learnedWords += count;
    dailyDone = (dailyDone + count).clamp(0, dailyGoal);
    await _prefs?.setInt(_kLearnedWords, learnedWords);
    await _prefs?.setInt(_kDailyDone, dailyDone);
    await _prefs?.setString(_kDailyDate, _today);
    notifyListeners();
  }

  Future<void> completeLesson(int lessonId) async {
    completedLessons.add(lessonId);
    await _prefs?.setString(
        _kCompletedLessons, jsonEncode(completedLessons.toList()));
    notifyListeners();
  }

  bool isLessonCompleted(int id) => completedLessons.contains(id);

  /// Урок открыт, если это первый урок или предыдущий завершён.
  bool isLessonUnlocked(int id) {
    if (id <= 1) return true;
    return completedLessons.contains(id - 1);
  }
}
