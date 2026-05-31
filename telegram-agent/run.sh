#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "✏️  Создан .env из шаблона. Заполните TELEGRAM_BOT_TOKEN, GEMINI_API_KEY и ALLOWED_USER_IDS, затем запустите снова."
  exit 1
fi

source .env
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ "$TELEGRAM_BOT_TOKEN" = "your_telegram_bot_token_here" ]; then
  echo "❌ TELEGRAM_BOT_TOKEN не задан. Откройте .env и вставьте токен от @BotFather."
  exit 1
fi
if [ -z "${GEMINI_API_KEY:-}" ] || [ "$GEMINI_API_KEY" = "your_gemini_api_key_here" ]; then
  echo "❌ GEMINI_API_KEY не задан. Откройте .env и вставьте ключ Gemini."
  exit 1
fi

echo "📦 Устанавливаю зависимости..."
pip install -q -r requirements.txt

echo "🤖 Запускаю бота..."
python bot.py
