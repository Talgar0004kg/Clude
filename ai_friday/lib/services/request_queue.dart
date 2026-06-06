import 'dart:async';
import '../utils/logger.dart';

class RequestQueue {
  final _queue = <Future<void> Function()>[];
  bool _processing = false;

  void add(Future<void> Function() task) {
    _queue.add(task);
    if (!_processing) _process();
  }

  Future<void> _process() async {
    _processing = true;
    while (_queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      try {
        await task();
      } catch (e) {
        AppLogger.error('Queue task error', e);
      }
    }
    _processing = false;
  }
}
