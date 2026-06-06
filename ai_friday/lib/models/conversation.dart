import 'message.dart';

class Conversation {
  final String id;
  final List<Message> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  Conversation copyWith({List<Message>? messages, DateTime? updatedAt}) {
    return Conversation(
      id: id,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
