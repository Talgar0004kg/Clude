#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f .env ]; then
  echo "⚠️  Файл .env не найден. Копирую из .env.example..."
  cp .env.example .env
  echo "✏️  Шаблон уже настроен на локальную Ollama. При необходимости поправьте .env."
fi

source .env

# Проверяем, что локальный сервер Ollama доступен.
OLLAMA_CHECK="${LLM_BASE_URL:-http://host.docker.internal:11434}"
OLLAMA_CHECK="${OLLAMA_CHECK/host.docker.internal/localhost}"
if ! curl -fsS "$OLLAMA_CHECK/api/tags" >/dev/null 2>&1; then
  echo "⚠️  Локальный сервер Ollama недоступен ($OLLAMA_CHECK)."
  echo "    Запустите его в соседней вкладке: 'ollama serve'"
  echo "    и загрузите модель: 'ollama pull ${LLM_MODEL#ollama/}'"
fi

echo "🚀 Запускаю OpenHands..."
docker compose up --pull always
