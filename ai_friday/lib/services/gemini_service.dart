import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import '../models/message.dart';
import '../utils/logger.dart';
import 'key_manager.dart';

enum AssistantState { idle, listening, thinking, speaking }

/// Сервис Gemini через REST с включённым поиском Google (grounding).
///
/// Поиск в интернете выполняется внутри ОДНОГО запроса generateContent —
/// модель сама обращается к Google Search, отдельного запроса нет (один вызов
/// API на команду).
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  final KeyManager _keyManager = KeyManager();

  // История диалога (для контекста). Храним последние сообщения.
  final List<Map<String, String>> _history = [];
  static const int _maxHistory = 20;

  final StreamController<String> _responseStream = StreamController.broadcast();
  final StreamController<AssistantState> _stateStream = StreamController.broadcast();

  Stream<String> get responseStream => _responseStream.stream;
  Stream<AssistantState> get stateStream => _stateStream.stream;

  AssistantState _state = AssistantState.idle;
  AssistantState get currentState => _state;

  void _setState(AssistantState state) {
    _state = state;
    _stateStream.add(state);
  }

  Future<bool> init() async => _keyManager.getActiveKey() != null;

  void _trimHistory() {
    while (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
  }

  Future<String?> sendMessage(String text) => sendMessageStream(text);

  Future<String?> sendMessageStream(String text, {Function(String)? onChunk}) async {
    _setState(AssistantState.thinking);
    _history.add({'role': 'user', 'text': text});
    _trimHistory();

    // До двух попыток — на случай ротации ключа при лимите (429).
    for (int attempt = 0; attempt < 2; attempt++) {
      final key = _keyManager.getActiveKey();
      if (key == null) {
        AppLogger.error('No API key available');
        _setState(AssistantState.idle);
        return null;
      }

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${AiConfig.modelName}:generateContent?key=$key',
      );
      final body = jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': AiConfig.systemPrompt}
          ]
        },
        'contents': _history
            .map((m) => {
                  'role': m['role'],
                  'parts': [
                    {'text': m['text']}
                  ]
                })
            .toList(),
        // Доступ к интернету: поиск Google внутри этого же запроса.
        'tools': [
          {'google_search': {}}
        ],
        'generationConfig': {'temperature': 0.7},
      });

      try {
        final resp = await http
            .post(url, headers: {'Content-Type': 'application/json'}, body: body)
            .timeout(const Duration(seconds: 30));

        if (resp.statusCode == 200) {
          final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
          final out = _extractText(data);
          _keyManager.onRequestSuccess();
          _setState(AssistantState.idle);
          if (out.isNotEmpty) {
            _history.add({'role': 'model', 'text': out});
            onChunk?.call(out);
            _responseStream.add(out);
            return out;
          }
          return null;
        } else if (resp.statusCode == 429) {
          AppLogger.warn('Gemini rate limit (429), switching key');
          _keyManager.onRequestFailed(429);
          continue; // попробовать следующий ключ
        } else {
          AppLogger.error('Gemini HTTP ${resp.statusCode}: ${resp.body}');
          _setState(AssistantState.idle);
          return null;
        }
      } catch (e) {
        AppLogger.error('Gemini request failed', e);
        _setState(AssistantState.idle);
        return null;
      }
    }

    _setState(AssistantState.idle);
    return null;
  }

  String _extractText(Map<String, dynamic> data) {
    try {
      final cands = data['candidates'] as List?;
      if (cands == null || cands.isEmpty) return '';
      final parts = cands.first['content']?['parts'] as List?;
      if (parts == null) return '';
      return parts.map((p) => (p['text'] ?? '').toString()).join('').trim();
    } catch (e) {
      AppLogger.error('Failed to parse Gemini response', e);
      return '';
    }
  }

  List<Message> getRecentContext(List<Message> history, {int count = 10}) {
    if (history.length <= count) return history;
    return history.sublist(history.length - count);
  }

  void resetSession() {
    _history.clear();
    AppLogger.info('Session reset');
  }

  void dispose() {
    _responseStream.close();
    _stateStream.close();
  }
}
