import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/logger.dart';
import '../config/app_config.dart';

class ApiKeyModel {
  final String key;
  int usedToday;
  final DateTime resetDate;
  bool isActive;

  ApiKeyModel({
    required this.key,
    this.usedToday = 0,
    required this.resetDate,
    this.isActive = false,
  });

  int get remaining => AppConfig.dailyRequestLimit - usedToday;
  String get maskedKey => '${key.substring(0, 8)}...${key.substring(key.length - 4)}';

  Map<String, dynamic> toMap() => {
        'key': key,
        'usedToday': usedToday,
        'resetDate': resetDate.toIso8601String(),
        'isActive': isActive,
      };

  factory ApiKeyModel.fromMap(Map<String, dynamic> map) => ApiKeyModel(
        key: map['key'],
        usedToday: map['usedToday'] ?? 0,
        resetDate: DateTime.parse(map['resetDate']),
        isActive: map['isActive'] ?? false,
      );
}

class KeyManager {
  static final KeyManager _instance = KeyManager._internal();
  factory KeyManager() => _instance;
  KeyManager._internal();

  List<ApiKeyModel> _keys = [];
  int _activeIndex = 0;
  static const String _prefsKey = 'api_keys';

  Future<void> init() async {
    await _load();
    _resetIfNewDay();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _keys = list.map((e) => ApiKeyModel.fromMap(e)).toList();
      _activeIndex = _keys.indexWhere((k) => k.isActive);
      if (_activeIndex < 0) _activeIndex = 0;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_keys.map((k) => k.toMap()).toList()));
  }

  void _resetIfNewDay() {
    final now = DateTime.now();
    for (final key in _keys) {
      if (now.day != key.resetDate.day || now.month != key.resetDate.month) {
        key.usedToday = 0;
      }
    }
    _save();
  }

  String? getActiveKey() {
    if (_keys.isEmpty) return null;
    return _keys[_activeIndex].key;
  }

  Future<void> addKey(String key) async {
    final exists = _keys.any((k) => k.key == key);
    if (exists) return;
    _keys.add(ApiKeyModel(key: key, resetDate: DateTime.now(), isActive: _keys.isEmpty));
    if (_keys.length == 1) {
      _keys.first.isActive = true;
      _activeIndex = 0;
    }
    await _save();
    AppLogger.info('Added API key: ${key.substring(0, 8)}...');
  }

  Future<void> removeKey(int index) async {
    if (index < 0 || index >= _keys.length) return;
    _keys.removeAt(index);
    if (_activeIndex >= _keys.length) _activeIndex = _keys.length - 1;
    if (_keys.isNotEmpty) _keys[_activeIndex].isActive = true;
    await _save();
  }

  void onRequestSuccess() {
    if (_keys.isEmpty) return;
    _keys[_activeIndex].usedToday++;
    if (_keys[_activeIndex].remaining <= AppConfig.keyRotateThreshold) {
      _switchToNext();
    }
    _save();
  }

  void onRequestFailed(int statusCode) {
    if (statusCode == 429) {
      AppLogger.warn('Rate limit hit, switching key');
      _switchToNext();
    }
  }

  void _switchToNext() {
    if (_keys.length <= 1) return;
    _keys[_activeIndex].isActive = false;
    _activeIndex = (_activeIndex + 1) % _keys.length;
    _keys[_activeIndex].isActive = true;
    AppLogger.info('Switched to key index $_activeIndex');
    _save();
  }

  int getRemainingRequests() {
    if (_keys.isEmpty) return 0;
    return _keys[_activeIndex].remaining;
  }

  List<ApiKeyModel> getAllKeys() => List.unmodifiable(_keys);

  bool get hasKey => _keys.isNotEmpty;
}
