import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../core/context_manager.dart';
import '../models/message.dart';

class ChatScreen extends StatelessWidget {
  final ContextManager contextManager;
  const ChatScreen({super.key, required this.contextManager});

  @override
  Widget build(BuildContext context) {
    final messages = contextManager.history;

    return Scaffold(
      backgroundColor: const Color(AppConfig.colorBackground),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Чат', style: TextStyle(color: Color(AppConfig.colorText))),
        actions: [
          IconButton(
            icon: Icon(
              contextManager.privateMode ? Icons.lock : Icons.lock_open,
              color: contextManager.privateMode ? const Color(AppConfig.colorAccent) : const Color(0xFF6B7280),
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFF6B7280)),
            onPressed: () {},
          ),
        ],
      ),
      body: messages.isEmpty
          ? const Center(child: Text('Нет сообщений', style: TextStyle(color: Color(0xFF6B7280))))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, i) => _MessageBubble(message: messages[i]),
            ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(AppConfig.colorAccent) : const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Color(AppConfig.colorText), fontSize: 15),
        ),
      ),
    );
  }
}
