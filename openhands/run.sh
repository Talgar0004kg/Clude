#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f .env ]; then
  echo "⚠️  Файл .env не найден. Копирую из .env.example..."
  cp .env.example .env
  echo "✏️  Впишите LLM_API_KEY в файл .env, затем запустите скрипт снова."
  exit 1
fi

# Проверяем, что ключ задан
source .env
if [ -z "${LLM_API_KEY:-}" ] || [ "$LLM_API_KEY" = "your_gemini_api_key_here" ]; then
  echo "❌ LLM_API_KEY не задан. Откройте .env и впишите ключ Gemini."
  exit 1
fi

echo "🚀 Запускаю OpenHands..."
docker compose up --pull always
