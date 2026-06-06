import '../config/blocked_commands.dart';

class SecurityGuard {
  static bool isAllowed(String command) => !BlockedCommands.isBlocked(command);

  static String blockMessage() => 'Это действие заблокировано в целях безопасности.';
}
