enum CommandStatus { pending, executing, success, failed, blocked }

class ActionStep {
  final String action;
  final Map<String, dynamic> params;

  const ActionStep({required this.action, required this.params});

  factory ActionStep.fromMap(Map<String, dynamic> map) {
    final params = Map<String, dynamic>.from(map)..remove('action');
    return ActionStep(action: map['action'], params: params);
  }
}

class Command {
  final String id;
  final String rawText;
  final String speech;
  final List<ActionStep> steps;
  final bool preview;
  final DateTime timestamp;
  CommandStatus status;

  Command({
    required this.id,
    required this.rawText,
    required this.speech,
    required this.steps,
    this.preview = false,
    required this.timestamp,
    this.status = CommandStatus.pending,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'rawText': rawText,
        'speech': speech,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status.name,
      };
}
