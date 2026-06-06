import 'dart:async';

class SilenceDetector {
  final Duration threshold;
  final VoidCallback onSilence;

  Timer? _timer;

  SilenceDetector({
    required this.threshold,
    required this.onSilence,
  });

  void onAudioReceived() {
    _timer?.cancel();
    _timer = Timer(threshold, onSilence);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

typedef VoidCallback = void Function();
