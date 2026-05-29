import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'achievements_screen.dart';
import 'stats_screen.dart';
import 'welcome_screen.dart';

/// Профиль пользователя (Профиль).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Профиль',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 50, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(app.userName ?? 'Окуучу',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(app.userEmail ?? '',
                    style: const TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: cardShadow,
            ),
            child: Row(
              children: [
                _Stat(value: '${app.learnedWords}', label: 'Үйрөнгөн сөздөр'),
                _divider(),
                _Stat(value: '${app.streakDays}', label: 'Күн ирааттуулук'),
                _divider(),
                _Stat(value: '${app.progressPercent}%', label: 'Прогресс'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _MenuTile(
            icon: Icons.emoji_events_outlined,
            title: 'Жетишкендиктер',
            subtitle: 'Достижения',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AchievementsScreen())),
          ),
          _MenuTile(
            icon: Icons.bar_chart_rounded,
            title: 'Статистика',
            subtitle: 'Статистика обучения',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'Орнотуулар',
            subtitle: 'Настройки',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Настройки скоро появятся')),
            ),
          ),
          _MenuTile(
            icon: Icons.logout_rounded,
            title: 'Чыгуу',
            subtitle: 'Выйти из аккаунта',
            danger: true,
            onTap: () async {
              await context.read<AppState>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 36, color: const Color(0xFFE2E8E6));
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: danger ? AppColors.error : AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
