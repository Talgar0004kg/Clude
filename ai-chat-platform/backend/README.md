# ⚙️ ChatBiz — Бэкенд

Сервер платформы AI-чат-ботов: DeepSeek, база данных SQLite, авторизация,
статистика и WhatsApp-уведомления (whatsapp-web.js).

## 🚀 Запуск

```bash
cd backend
cp .env.example .env      # впишите DEEPSEEK_API_KEY и JWT_SECRET
npm install               # установит зависимости (включая whatsapp-web.js)
npm start                 # сервер на http://localhost:4000
```

> Без WhatsApp (для разработки) можно установить быстрее:
> `npm install --omit=optional` — тогда заявки просто сохраняются в кабинете.

## 🔑 Демо-вход
- Бизнес: `business@demo.kg` / `demo`
- Админ: `admin@demo.kg` / `demo`

## 🔌 Подключение фронтенда
Во фронтенде задайте переменную окружения перед сборкой:

```bash
VITE_API_URL=https://ваш-бэкенд-адрес npm run build
```

Если переменная не задана — фронтенд работает в ДЕМО-режиме (без бэкенда).

## 📲 WhatsApp (whatsapp-web.js)
1. В `.env` поставьте `WHATSAPP_ENABLED=true`.
2. Запустите сервер — в консоли появится QR-код.
3. Отсканируйте его в WhatsApp: **Настройки → Связанные устройства**.
4. В кабинете бизнеса укажите номер для уведомлений.

> ⚠️ Это неофициальный способ. Используйте **отдельный номер** под рассылку —
> при большом объёме WhatsApp может заблокировать номер.

## 🗄️ База данных
SQLite-файл создаётся автоматически в `data/app.db` и при первом запуске
наполняется демо-данными. Для перехода на PostgreSQL замените слой `db.js`.

## 📚 API (кратко)
| Метод | Путь | Назначение |
|-------|------|------------|
| POST | `/api/auth/login` | вход |
| POST | `/api/auth/register` | регистрация бизнеса |
| GET | `/api/public/business/:slug` | данные бизнеса для чата |
| POST | `/api/public/chat/:slug` | сообщение боту (DeepSeek) |
| POST | `/api/public/lead/:slug` | заявка от клиента |
| GET | `/api/dashboard/business` | мой бизнес |
| PUT | `/api/dashboard/bot` | сохранить настройки бота |
| POST | `/api/dashboard/submit-review` | отправить на модерацию |
| GET | `/api/dashboard/leads` | заявки |
| PATCH | `/api/dashboard/leads/:id` | статус заявки |
| GET | `/api/dashboard/chats` | переписки |
| GET | `/api/dashboard/stats` | статистика |
| GET | `/api/admin/businesses` | список бизнесов |
| PATCH | `/api/admin/businesses/:id/status` | модерация |
