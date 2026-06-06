import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/ai_config.dart';
import '../services/key_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyManager = KeyManager();
  final _keyController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = _keyManager.getAllKeys();

    return Scaffold(
      backgroundColor: const Color(AppConfig.colorBackground),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Настройки', style: TextStyle(color: Color(AppConfig.colorText))),
      ),
      body: ListView(
        children: [
          _section('API Ключи', [
            ...List.generate(keys.length, (i) {
              final k = keys[i];
              return ListTile(
                leading: Icon(
                  Icons.circle,
                  size: 12,
                  color: k.isActive ? const Color(AppConfig.colorSuccess) : const Color(0xFF6B7280),
                ),
                title: Text(k.maskedKey, style: const TextStyle(color: Color(AppConfig.colorText))),
                subtitle: Text('${k.remaining} запросов осталось', style: const TextStyle(color: Color(0xFF9CA3AF))),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFF6B7280)),
                  onPressed: () async {
                    await _keyManager.removeKey(i);
                    setState(() {});
                  },
                ),
              );
            }),
            ListTile(
              leading: const Icon(Icons.add, color: Color(AppConfig.colorAccent)),
              title: const Text('Добавить ключ', style: TextStyle(color: Color(AppConfig.colorAccent))),
              onTap: _showAddKeyDialog,
            ),
          ]),
          _section('Голос Пятницы', [
            ...AiConfig.availableVoices.map((v) => ListTile(
              leading: Icon(
                v == AiConfig.defaultVoice ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: const Color(AppConfig.colorAccent),
                size: 20,
              ),
              title: Text(v, style: const TextStyle(color: Color(AppConfig.colorText))),
              onTap: () {},
            )),
          ]),
          _section('О приложении', [
            const ListTile(
              title: Text('Версия', style: TextStyle(color: Color(AppConfig.colorText))),
              trailing: Text(AppConfig.appVersion, style: TextStyle(color: Color(0xFF6B7280))),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, letterSpacing: 1.5),
          ),
        ),
        Container(
          color: const Color(0xFF111827),
          child: Column(children: children),
        ),
      ],
    );
  }

  void _showAddKeyDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Добавить API ключ', style: TextStyle(color: Color(AppConfig.colorText))),
        content: TextField(
          controller: _keyController,
          style: const TextStyle(color: Color(AppConfig.colorText)),
          decoration: const InputDecoration(
            hintText: 'AIzaSy...',
            hintStyle: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              await _keyManager.addKey(_keyController.text.trim());
              _keyController.clear();
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Добавить', style: TextStyle(color: Color(AppConfig.colorAccent))),
          ),
        ],
      ),
    );
  }
}
