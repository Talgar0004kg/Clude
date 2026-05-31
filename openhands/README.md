# OpenHands + локальная LLM (Ollama)

Запуск готового [OpenHands](https://github.com/All-Hands-AI/OpenHands) (open-source аналог Devin),
подключённого к локальной модели через [Ollama](https://ollama.com) (без облака).

## Быстрый старт

```bash
# 1. Поднимите локальную модель
curl -fsSL https://ollama.com/install.sh | sh
ollama serve            # в отдельной вкладке
ollama pull llama3.2:3b

# 2. Запустите OpenHands
cd openhands
cp .env.example .env          # шаблон уже настроен на Ollama
./run.sh                      # или: docker compose up
```

Откройте браузер: http://localhost:3000

> OpenHands запускается в Docker, поэтому обращается к Ollama на хосте по
> `host.docker.internal:11434` (а не `localhost`).

## Переменные окружения (`.env`)

| Переменная | По умолчанию | Описание |
|---|---|---|
| `LLM_MODEL` | `ollama/llama3.2:3b` | Модель (префикс `ollama/` обязателен для LiteLLM) |
| `LLM_BASE_URL` | `http://host.docker.internal:11434` | Адрес локального Ollama |
| `LLM_API_KEY` | `ollama` | Заглушка (Ollama ключ не требует) |
| `OPENHANDS_VERSION` | `latest` | Тег образа OpenHands |
| `AGENT_SERVER_IMAGE_TAG` | `0.39.0-nikolaik` | Тег образа runtime-sandbox |

> Актуальные теги: https://github.com/All-Hands-AI/OpenHands/releases

## Запуск в GitHub Codespaces

1. Откройте репозиторий → **Code → Codespaces → New codespace** (выберите Dev Container из папки `openhands/.devcontainer`).
2. Дождитесь сборки контейнера (Docker-in-Docker устанавливается автоматически).
3. В терминале:
   ```bash
   # поднимите модель: ollama serve и ollama pull llama3.2:3b
   cd openhands
   ./run.sh
   ```
4. Codespaces автоматически пробросит порт 3000 и откроет браузер.

## Безопасность

- **Никогда не коммитьте `.env`** — он добавлен в `.gitignore`.
- OpenHands выполняет произвольный код внутри sandbox-контейнера.
  Запускайте только в изолированной среде.
