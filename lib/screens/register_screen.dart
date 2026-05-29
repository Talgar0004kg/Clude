import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'main_shell.dart';

/// Экран регистрации (Катталуу).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppState>().register(_name.text, _email.text);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Катталуу')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Жаңы аккаунт түзүңүз',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Создайте новый аккаунт, чтобы начать',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                _field('Атыңыз · Имя', _name, hint: 'Азатбек',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Введите имя' : null),
                _field('Электрондук почта · Эл. почта', _email,
                    hint: 'mail@example.com',
                    keyboard: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Введите эл. почту'
                        : null),
                _field('Сырсөз · Пароль', _password,
                    obscure: true,
                    hint: '••••••••',
                    validator: (v) => (v == null || v.length < 4)
                        ? 'Минимум 4 символа'
                        : null),
                _field('Сырсөздү кайталаңыз · Повтор пароля', _confirm,
                    obscure: true,
                    hint: '••••••••',
                    validator: (v) =>
                        v != _password.text ? 'Пароли не совпадают' : null),
                const SizedBox(height: 12),
                ElevatedButton(
                    onPressed: _submit, child: const Text('Катталуу')),
                const SizedBox(height: 24),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Аккаунтуңуз барбы? ',
                          style: TextStyle(color: AppColors.textMuted)),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Text('Кирүү',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          TextFormField(
            controller: c,
            obscureText: obscure,
            keyboardType: keyboard,
            decoration: InputDecoration(hintText: hint),
            validator: validator,
          ),
        ],
      ),
    );
  }
}
