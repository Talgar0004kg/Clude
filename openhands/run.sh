#!/usr/bin/env bash
# Запуск OpenHands через docker compose.
set -e
cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker не установлен. Установите Docker Desktop / Docker Engine."
  exit 1
fi

if [ ! -f .env ]; then
  echo "⚠️  Файл .env не найден. Копирую .env.example -> .env"
  cp .env.example .env
  echo "👉 Откройте .env, впишите LLM_API_KEY (ключ Gemini) и запустите снова."
  exit 1
fi

echo "🚀 Запускаю OpenHands... Веб-интерфейс будет на http://localhost:${OPENHANDS_PORT:-3000}"
exec docker compose up
