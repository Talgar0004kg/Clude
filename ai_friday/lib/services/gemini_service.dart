import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/ai_config.dart';
import '../models/message.dart';
import '../utils/logger.dart';
import 'key_manager.dart';

enum AssistantState { idle, listening, thinking, speaking }

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  GenerativeModel? _model;
  ChatSession? _session;
  final KeyManager _keyManager = KeyManager();

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

  Future<bool> init() async {
    final key = _keyManager.getActiveKey();
    if (key == null) {
      AppLogger.error('No API key available');
      return false;
    }
    try {
      _model = GenerativeModel(
        model: AiConfig.modelName,
        apiKey: key,
        systemInstruction: Content.system(AiConfig.systemPrompt),
      );
      _session = _model!.startChat();
      AppLogger.info('Gemini service initialized');
      return true;
    } catch (e) {
      AppLogger.error('Failed to init Gemini', e);
      return false;
    }
  }

  Future<String?> sendMessage(String text) async {
    if (_session == null) {
      final ok = await init();
      if (!ok) return null;
    }

    _setState(AssistantState.thinking);
    try {
      final response = await _session!.sendMessage(Content.text(text));
      _keyManager.onRequestSuccess();
      final result = response.text ?? '';
      _setState(AssistantState.idle);
      return result;
    } on GenerativeAIException catch (e) {
      AppLogger.error('Gemini error', e);
      if (e.message.contains('429')) {
        _keyManager.onRequestFailed(429);
        await init();
      }
      _setState(AssistantState.idle);
      return null;
    } catch (e) {
      AppLogger.error('Unexpected error', e);
      _setState(AssistantState.idle);
      return null;
    }
  }

  Future<String?> sendMessageStream(String text, {Function(String)? onChunk}) async {
    if (_session == null) {
      final ok = await init();
      if (!ok) return null;
    }

    _setState(AssistantState.thinking);
    final buffer = StringBuffer();

    try {
      final responses = _session!.sendMessageStream(Content.text(text));
      _setState(AssistantState.speaking);

      await for (final chunk in responses) {
        final chunkText = chunk.text ?? '';
        buffer.write(chunkText);
        _responseStream.add(buffer.toString());
        onChunk?.call(chunkText);
      }

      _keyManager.onRequestSuccess();
      _setState(AssistantState.idle);
      return buffer.toString();
    } on GenerativeAIException catch (e) {
      AppLogger.error('Gemini stream error', e);
      if (e.message.contains('429')) {
        _keyManager.onRequestFailed(429);
        await init();
      }
      _setState(AssistantState.idle);
      return null;
    } catch (e) {
      AppLogger.error('Stream unexpected error', e);
      _setState(AssistantState.idle);
      return null;
    }
  }

  List<Message> getRecentContext(List<Message> history, {int count = 10}) {
    if (history.length <= count) return history;
    return history.sublist(history.length - count);
  }

  void resetSession() {
    _session = _model?.startChat();
    AppLogger.info('Session reset');
  }

  void dispose() {
    _responseStream.close();
    _stateStream.close();
  }
}
