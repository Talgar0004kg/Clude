class ActionLog {
  final String id;
  final String commandText;
  final String actionType;
  final bool success;
  final bool blocked;
  final DateTime timestamp;

  const ActionLog({
    required this.id,
    required this.commandText,
    required this.actionType,
    required this.success,
    required this.blocked,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'commandText': commandText,
        'actionType': actionType,
        'success': success ? 1 : 0,
        'blocked': blocked ? 1 : 0,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory ActionLog.fromMap(Map<String, dynamic> map) => ActionLog(
        id: map['id'],
        commandText: map['commandText'],
        actionType: map['actionType'],
        success: map['success'] == 1,
        blocked: map['blocked'] == 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      );
}
