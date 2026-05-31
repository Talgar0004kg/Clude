# Telegram Agent — кодинг-агент на Gemini

Телеграм-бот, который работает как автономный **кодинг-агент** на **Google
Gemini**. Пишете задачу в чат — бот сам исследует файлы, вносит изменения и
выполняет команды в персональной рабочей папке, присылая каждый шаг обратно.

```
Telegram ──► бот (python-telegram-bot) ──► Gemini API
                  │
                  ▼
        инструменты в рабочей папке (песочница)
   list_files · read_file · write_file · run_command
```

> Для каждого чата создаётся **отдельная** папка `workspace/<chat_id>` — модель
> сама решает, какие инструменты вызвать, и не выходит за её пределы.

## Структура

```
telegram-agent/
├── bot.py        # телеграм-бот, стрим шагов агента в чат
├── agent.py      # цикл агента на Gemini (вызов инструментов)
├── tools.py      # инструменты: файлы + команды, песочница на чат
├── config.py     # настройки из .env
├── requirements.txt
├── Dockerfile · docker-compose.yml · run.sh
└── .devcontainer/  # для GitHub Codespaces
```

## Быстрый старт

```bash
cd telegram-agent
cp .env.example .env     # впишите токены и свой Telegram ID
./run.sh
```
Затем откройте бота в Телеграме и напишите `/start`.

## Запуск через Docker

```bash
cd telegram-agent
cp .env.example .env      # заполните .env
docker compose up --build
```

## Запуск в GitHub Codespaces

1. **Code → Codespaces → New codespace** (Dev Container из `telegram-agent/.devcontainer`).
2. Зависимости установятся автоматически.
3. Впишите токены в `.env` и запустите `python bot.py`.

## Команды бота

| Команда | Действие |
|---------|----------|
| `/start` | приветствие |
| `/help` | примеры задач |
| `/reset` | очистить контекст диалога |
| любой текст | задача для агента |

## Переменные окружения (`.env`)

| Переменная | Обязательно | Описание |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | ✅ | Токен от @BotFather |
| `GEMINI_API_KEY` | ✅ | Ключ Gemini (https://aistudio.google.com/app/apikey) |
| `ALLOWED_USER_IDS` | ⚠️ рекомендуется | Ваш Telegram ID (у @userinfobot). Несколько — через запятую. Пусто = все |
| `AGENT_MODEL` | нет | Модель Gemini (по умолчанию `gemini-2.5-flash`) |
| `AGENT_WORKSPACE` | нет | Базовая рабочая папка (по умолчанию `./workspace`) |
| `AGENT_COMMAND_TIMEOUT` | нет | Таймаут команды, сек (по умолчанию `120`) |
| `AGENT_MAX_STEPS` | нет | Лимит шагов агента на задачу (по умолчанию `25`) |

## ⚠️ Безопасность

- Бот **выполняет команды** (в песочнице рабочей папки). Обязательно заполните
  `ALLOWED_USER_IDS`, иначе бот ответит любому.
- Запускайте в изолированной среде (контейнер/Codespaces), не на машине с важными
  данными.
- **Никогда не коммитьте `.env`** — он в `.gitignore`.
- Если токены засветились — перевыпустите: `/revoke` у @BotFather и новый ключ на
  aistudio.google.com.
