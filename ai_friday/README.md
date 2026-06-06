# Пятница (F.R.I.D.A.Y.) — AI Voice Assistant

## Статус разработки
- [x] Задача 1 — Структура проекта и базовая настройка
- [x] Задача 2 — KeyManager (lib/services/key_manager.dart)
- [x] Задача 3 — Системный промт (lib/config/ai_config.dart)
- [ ] Задача 4 — Gemini Live Native Audio (требует доработки)
- [ ] Задача 5 — Парсер команд (базовая реализация в core/command_parser.dart)
- [ ] Задача 6 — Accessibility Service (конфиг готов)
- [ ] Задача 7 — Foreground Service (базовая реализация)
- [ ] Задача 8 — Голосовые сообщения
- [x] Задача 9 — Главный экран и UI
- [ ] Задача 10 — Настройки (базовая реализация)
- [ ] Задача 11 — История и чат
- [x] Задача 12 — Онбординг
- [x] Задача 13 — GitHub Actions
- [ ] Задача 14 — Тестирование

## Последняя выполненная задача
**Задача 1 завершена** — вся структура проекта создана, flutter pub get прошёл успешно (96 пакетов).

## Следующий шаг
**Задача 4** — полноценная интеграция Gemini Live Native Audio с голосовым вводом/выводом.

## Как запустить
```bash
git clone [repo]
echo "GEMINI_API_KEY=твой_ключ" > .env
flutter pub get
flutter run
```

## Получить API ключ
https://aistudio.google.com

## Известные проблемы
- Название модели `gemini-2.5-flash-preview-native-audio-dialog` — проверить актуальность
- Голосовая запись в home_screen.dart требует доработки
- Accessibility Service требует ручного включения при первом запуске

## Технологии
- Flutter 3.24+ / Dart
- Gemini API (google_generative_ai)
- Accessibility Service
- Android Intents
- SQLite + SharedPreferences
- WorkManager
