# Telegram Gemini Bot

Telegram-бот с Google Gemini AI. Поддерживает диалог с памятью, выполнение shell-команд и белый список пользователей.

## Быстрый старт

```bash
cd telegram-agent
cp .env.example .env
# Заполните .env (токен бота, ключ Gemini, свой Telegram ID)
./run.sh
```

## Переменные окружения (`.env`)

| Переменная | Обязательно | Описание |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | ✅ | Токен от @BotFather |
| `GEMINI_API_KEY` | ✅ | Ключ Gemini (https://aistudio.google.com/app/apikey) |
| `ALLOWED_USER_IDS` | ⚠️ рекомендуется | Ваш Telegram ID (узнать у @userinfobot). Несколько через запятую. Пусто = доступ для всех |
| `AGENT_MODEL` | нет | Модель Gemini (по умолчанию `gemini-2.5-flash`) |
| `AGENT_COMMAND_TIMEOUT` | нет | Таймаут shell-команд в секундах (по умолчанию `120`) |
| `AGENT_MAX_STEPS` | нет | Глубина памяти диалога (по умолчанию `25`) |

## Запуск через Docker

```bash
cd telegram-agent
cp .env.example .env   # заполните .env
docker compose up --build
```

## Запуск в GitHub Codespaces

1. **Code → Codespaces → New codespace** (Dev Container из `telegram-agent/.devcontainer`).
2. Зависимости установятся автоматически при создании контейнера.
3. Откройте `.env`, вставьте токены.
4. В терминале:
   ```bash
   cd telegram-agent
   python bot.py
   ```

## Команды бота

| Команда | Описание |
|---|---|
| `/start` | Начать / сбросить историю |
| `/clear` | Очистить историю диалога |
| `/run <cmd>` | Выполнить shell-команду |
| *(любой текст)* | Ответ Gemini с памятью контекста |

## Безопасность

- **Никогда не коммитьте `.env`** — добавлен в `.gitignore`.
- Обязательно заполните `ALLOWED_USER_IDS` — иначе бот ответит любому.
- Команда `/run` выполняет произвольный код — доверяйте только себе.
- После публикации токенов в открытом виде — перевыпустите их: `/revoke` у @BotFather и удалите ключ на aistudio.google.com.
