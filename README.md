# Проекты

Репозиторий для разных проектов. Каждый проект находится в своей папке.

## Список проектов

| Проект | Папка | Описание |
|--------|-------|----------|
| Мобильное приложение кыргызского языка | `kel-kel/` | React Native приложение для изучения кыргызского языка |
| Grok Voice Keyboard | `grok-keyboard/` | Нативная Android IME-клавиатура с голосовой транскрипцией xAI |
| OpenHands AI-агент | `openhands/` | Готовый OpenHands (аналог Devin), подключённый к Google Gemini |
| Telegram Gemini Bot | `telegram-agent/` | Telegram-бот с Gemini AI: диалог, память, shell-команды |

## Быстрый старт

**OpenHands:**
```bash
cd openhands && cp .env.example .env && ./run.sh
```

**Telegram-бот:**
```bash
cd telegram-agent && cp .env.example .env && ./run.sh
```

Подробнее: [openhands/README.md](openhands/README.md) · [telegram-agent/README.md](telegram-agent/README.md)
