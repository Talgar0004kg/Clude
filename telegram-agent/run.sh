#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "✏️  Создан .env из шаблона. Заполните TELEGRAM_BOT_TOKEN и ALLOWED_USER_IDS, затем запустите снова."
  exit 1
fi

source .env
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ "$TELEGRAM_BOT_TOKEN" = "your_telegram_bot_token_here" ]; then
  echo "❌ TELEGRAM_BOT_TOKEN не задан. Откройте .env и вставьте токен от @BotFather."
  exit 1
fi

OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434/api/generate}"
OLLAMA_BASE="${OLLAMA_URL%/api/generate}"
if ! curl -fsS "$OLLAMA_BASE/api/tags" >/dev/null 2>&1; then
  echo "⚠️  Локальный сервер Ollama недоступен по адресу $OLLAMA_BASE."
  echo "    Запустите его в соседней вкладке: 'ollama serve'"
  echo "    и загрузите модель: 'ollama pull ${AGENT_MODEL:-llama3.2:3b}'"
fi

echo "📦 Устанавливаю зависимости..."
pip install -q -r requirements.txt

echo "🤖 Запускаю бота..."
python bot.py
