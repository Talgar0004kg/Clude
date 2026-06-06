import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/contact_service.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final contacts = ContactService().all;

    return Scaffold(
      backgroundColor: const Color(AppConfig.colorBackground),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Контакты', style: TextStyle(color: Color(AppConfig.colorText))),
      ),
      body: contacts.isEmpty
          ? const Center(child: Text('Нет контактов', style: TextStyle(color: Color(0xFF6B7280))))
          : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (_, i) {
                final c = contacts[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(AppConfig.colorAccent),
                    child: Text(
                      c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(c.displayName, style: const TextStyle(color: Color(AppConfig.colorText))),
                  subtitle: Text(c.primaryPhone, style: const TextStyle(color: Color(0xFF6B7280))),
                );
              },
            ),
    );
  }
}
