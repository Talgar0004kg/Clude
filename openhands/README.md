# OpenHands + Gemini

Готовый запуск **[OpenHands](https://github.com/OpenHands/OpenHands)** —
open-source автономного AI-инженера (аналог Devin) — с подключением к
**Google Gemini** через API. Здесь не пишется свой агент: мы используем готовый
проект OpenHands и только конфигурируем его запуск и LLM.

> OpenHands умеет сам писать код, запускать команды, работать с git, браузером и
> т.д. Мы подключаем к нему Gemini в качестве «мозга».

## Что нужно

- **Docker** (Docker Desktop или Docker Engine) — OpenHands запускается в контейнере.
- **Ключ Gemini API** — https://aistudio.google.com/app/apikey

## Быстрый старт (локально)

```bash
cd openhands
cp .env.example .env
# откройте .env и впишите LLM_API_KEY = ваш ключ Gemini
./run.sh
```
Или вручную:
```bash
docker compose up
```
Затем откройте **http://localhost:3000**.

При первом запуске Docker скачает образы (несколько сотен МБ) — это нормально.

## Настройка Gemini

Модель и ключ задаются в `.env`:

| Переменная | Значение |
|------------|----------|
| `LLM_API_KEY` | ваш ключ Gemini |
| `LLM_MODEL` | `gemini/gemini-2.5-flash` (или `gemini/gemini-2.5-pro`) |

Префикс `gemini/` обязателен — так OpenHands (через LiteLLM) понимает, что это
Google Gemini.

> Те же параметры можно изменить и в самом интерфейсе: **Settings → LLM** —
> выбрать провайдера Gemini, модель и вставить ключ.

## Запуск в GitHub Codespaces

В этом проекте есть `.devcontainer` с поддержкой Docker-in-Docker.

1. Создайте Codespace для репозитория.
2. В терминале:
   ```bash
   cd openhands
   cp .env.example .env     # впишите LLM_API_KEY
   docker compose up
   ```
3. Порт **3000** пробросится автоматически — откройте его в превью.

## Версии образов

OpenHands активно обновляется. Версии задаются в `.env`:

```env
OPENHANDS_VERSION=latest
AGENT_SERVER_IMAGE_TAG=1.19.1-python
```

Актуальные версии смотрите в
[релизах OpenHands](https://github.com/OpenHands/OpenHands/releases). Чтобы
зафиксировать стабильную версию, замените `latest` на нужный номер (например
`1.7`) и при необходимости обновите `AGENT_SERVER_IMAGE_TAG`.

## Полезные команды

```bash
docker compose up           # запуск
docker compose up -d        # запуск в фоне
docker compose logs -f      # логи
docker compose down         # остановка
docker compose pull         # обновить образы
```

## ⚠️ Безопасность

OpenHands выполняет произвольный код в своей песочнице и требует доступ к
Docker-сокету. Запускайте его в изолированной среде (Codespaces / отдельный
контейнер/VM), не открывайте порт 3000 в публичный интернет без авторизации и
не коммитьте файл `.env` с ключом.

## Ссылки

- Репозиторий: https://github.com/OpenHands/OpenHands
- Документация: https://docs.openhands.dev
- Получить ключ Gemini: https://aistudio.google.com/app/apikey
