import '../models/message.dart';
import '../services/db_service.dart';

class ContextManager {
  final List<Message> _history = [];
  static const int _maxHistory = 100;
  bool _privateMode = false;

  bool get privateMode => _privateMode;
  List<Message> get history => List.unmodifiable(_history);

  /// Загружает историю из локальной БД при старте приложения.
  Future<void> loadFromDb() async {
    final saved = await DbService().getRecent();
    _history
      ..clear()
      ..addAll(saved);
    if (_history.length > _maxHistory) {
      _history.removeRange(0, _history.length - _maxHistory);
    }
  }

  void add(Message message) {
    if (_privateMode) return;
    _history.add(message);
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
    DbService().insert(message); // сохраняем в БД (fire-and-forget)
  }

  List<Message> getRecent({int count = 10}) {
    if (_history.length <= count) return List.unmodifiable(_history);
    return List.unmodifiable(_history.sublist(_history.length - count));
  }

  void setPrivateMode(bool enabled) => _privateMode = enabled;

  void clearAll() {
    _history.clear();
    DbService().clear();
  }

  void clearLast({int minutes = 10}) {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    _history.removeWhere((m) => m.timestamp.isAfter(cutoff));
  }
}
