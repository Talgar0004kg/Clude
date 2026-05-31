# OpenHands + Gemini

Запуск готового [OpenHands](https://github.com/All-Hands-AI/OpenHands) (open-source аналог Devin),
подключённого к Google Gemini через API.

## Быстрый старт

```bash
cd openhands
cp .env.example .env          # скопируйте шаблон
# отредактируйте .env: впишите LLM_API_KEY (ключ Gemini)
./run.sh                      # или: docker compose up
```

Откройте браузер: http://localhost:3000

## Переменные окружения (`.env`)

| Переменная | По умолчанию | Описание |
|---|---|---|
| `LLM_API_KEY` | — | Ключ Gemini (https://aistudio.google.com/app/apikey) |
| `LLM_MODEL` | `gemini/gemini-2.5-flash` | Модель (префикс `gemini/` обязателен) |
| `LLM_BASE_URL` | *(пусто)* | Кастомный endpoint (обычно не нужен) |
| `OPENHANDS_VERSION` | `latest` | Тег образа OpenHands |
| `AGENT_SERVER_IMAGE_TAG` | `0.39.0-nikolaik` | Тег образа runtime-sandbox |

> Актуальные теги: https://github.com/All-Hands-AI/OpenHands/releases

## Запуск в GitHub Codespaces

1. Откройте репозиторий → **Code → Codespaces → New codespace** (выберите Dev Container из папки `openhands/.devcontainer`).
2. Дождитесь сборки контейнера (Docker-in-Docker устанавливается автоматически).
3. В терминале:
   ```bash
   cd openhands
   # впишите LLM_API_KEY в .env (он уже создан из .env.example)
   ./run.sh
   ```
4. Codespaces автоматически пробросит порт 3000 и откроет браузер.

## Безопасность

- **Никогда не коммитьте `.env`** — он добавлен в `.gitignore`.
- OpenHands выполняет произвольный код внутри sandbox-контейнера.
  Запускайте только в изолированной среде.
