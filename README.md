# Проекты

Репозиторий для разных проектов. Каждый проект находится в своей папке.

## Список проектов

| Проект | Папка | Описание |
|--------|-------|----------|
| Мобильное приложение кыргызского языка | `kel-kel/` | React Native приложение для изучения кыргызского языка |
| OpenHands AI-агент | `openhands/` | Готовый OpenHands (аналог Devin), подключённый к Google Gemini |
| Telegram кодинг-агент | `telegram-agent/` | Телеграм-бот на Google Gemini, работающий как кодинг-агент |

## OpenHands — быстрый старт

```bash
cd openhands
cp .env.example .env   # вписать LLM_API_KEY (ключ Gemini)
./run.sh               # открыть http://localhost:3000
```

Подробнее: [openhands/README.md](openhands/README.md)
