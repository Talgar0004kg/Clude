import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/app_config.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env может отсутствовать или не попасть в release-бандл — это не должно
  // ронять приложение. Инициализируем dotenv пустым, чтобы dotenv.maybeGet
  // дальше не бросал NotInitializedError; ключ тогда вводится вручную.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    dotenv.testLoad(fileInput: '');
  }
  runApp(const FridayApp());
}

class FridayApp extends StatelessWidget {
  const FridayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(AppConfig.colorBackground),
        colorScheme: const ColorScheme.dark(
          primary: Color(AppConfig.colorAccent),
          surface: Color(0xFF111827),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF111827),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: Color(AppConfig.colorText), fontSize: 12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(AppConfig.colorText),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Color(AppConfig.colorText)),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
