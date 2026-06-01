#!/usr/bin/env bash
# Полная настройка телеграм-агента после (пере)создания Codespace.
# Использование:  bash setup.sh
set -e
cd "$(dirname "$0")"

echo "── 1/5  Ollama ───────────────────────────────"
if ! command -v ollama >/dev/null 2>&1; then
  echo "Устанавливаю Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
else
  echo "Ollama уже установлена."
fi

echo "── 2/5  Python-зависимости ───────────────────"
pip install -q -r requirements.txt
echo "Зависимости установлены."

echo "── 3/5  Файл .env ────────────────────────────"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "⚠️  Создан .env из шаблона — впишите TELEGRAM_BOT_TOKEN и ALLOWED_USER_IDS,"
  echo "   при желании поменяйте OLLAMA_MODEL, затем запустите setup.sh снова."
else
  echo ".env уже есть."
fi

echo "── 4/5  Сервер Ollama ────────────────────────"
if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
  echo "Запускаю 'ollama serve' в фоне..."
  nohup ollama serve > /tmp/ollama.log 2>&1 &
  sleep 3
else
  echo "Сервер Ollama уже работает."
fi

echo "── 5/5  Модель ───────────────────────────────"
MODEL=$(grep -E '^OLLAMA_MODEL=' .env 2>/dev/null | cut -d= -f2)
MODEL=${MODEL:-qwen2.5:3b}
echo "Память (для справки):"
free -h | awk 'NR==1 || /Mem/'
echo "Скачиваю модель: $MODEL ..."
ollama pull "$MODEL"

echo ""
echo "✅ Готово. Запустите бота:  python bot_local.py"
