class ProactiveEngine {
  bool _enabled = true;

  bool get enabled => _enabled;
  void setEnabled(bool value) => _enabled = value;

  String? getDaySummaryTip() {
    if (!_enabled) return null;
    return null;
  }
}
