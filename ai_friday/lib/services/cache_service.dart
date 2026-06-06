import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _cacheKey = 'cmd_cache';
  static Map<String, String>? _cache;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    _cache = raw != null ? Map<String, String>.from(jsonDecode(raw)) : {};
  }

  static String? get(String key) => _cache?[key.toLowerCase()];

  static Future<void> set(String key, String value) async {
    _cache ??= {};
    _cache![key.toLowerCase()] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(_cache));
  }

  static Future<void> clear() async {
    _cache = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
