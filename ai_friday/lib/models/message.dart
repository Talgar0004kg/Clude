enum MessageRole { user, assistant }

class Message {
  final String id;
  final String text;
  final MessageRole role;
  final DateTime timestamp;
  final bool isStreaming;

  const Message({
    required this.id,
    required this.text,
    required this.role,
    required this.timestamp,
    this.isStreaming = false,
  });

  Message copyWith({String? text, bool? isStreaming}) {
    return Message(
      id: id,
      text: text ?? this.text,
      role: role,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'role': role.name,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'],
        text: map['text'],
        role: MessageRole.values.byName(map['role']),
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      );
}
