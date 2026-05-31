import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'main_shell.dart';
import 'register_screen.dart';

/// Экран входа (Кирүү).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppState>().login(_email.text);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Кирүү')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Кош келиңиз!',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Войдите в аккаунт, чтобы продолжить обучение',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 28),
                const _Label('Электрондук почта · Эл. почта'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'mail@example.com'),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Введите эл. почту' : null,
                ),
                const SizedBox(height: 16),
                const _Label('Сырсөз · Пароль'),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: '••••••••'),
                  validator: (v) =>
                      (v == null || v.length < 4) ? 'Минимум 4 символа' : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Сырсөздү унуттуңузбу?'),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _submit, child: const Text('Кирүү')),
                const SizedBox(height: 24),
                const _OrDivider(),
                const SizedBox(height: 20),
                const _SocialRow(),
                const SizedBox(height: 28),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Аккаунтуңуз жокпу? ',
                          style: TextStyle(color: AppColors.textMuted)),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        ),
                        child: const Text('Катталуу',
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
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
      );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(child: Divider(color: Color(0xFFE2E8E6))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('же · или', style: TextStyle(color: AppColors.textMuted)),
          ),
          Expanded(child: Divider(color: Color(0xFFE2E8E6))),
        ],
      );
}

class _SocialRow extends StatelessWidget {
  const _SocialRow();

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, Color color) => Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8E6)),
          ),
          child: Icon(icon, color: color),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        btn(Icons.g_mobiledata_rounded, const Color(0xFFEA4335)),
        const SizedBox(width: 16),
        btn(Icons.facebook_rounded, const Color(0xFF1877F2)),
        const SizedBox(width: 16),
        btn(Icons.apple_rounded, Colors.black),
      ],
    );
  }
}
