"""Телеграм-бот: кодинг-агент на Gemini.

Пользователь пишет задачу в чат → агент исследует/меняет файлы и выполняет
команды в персональной рабочей папке → шаги приходят обратно в чат.
"""
import asyncio
import logging
import threading

from telegram import Update
from telegram.constants import ChatAction
from telegram.ext import (
    Application,
    ApplicationBuilder,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

import config
from agent import Agent

logging.basicConfig(
    format="%(asctime)s — %(name)s — %(levelname)s — %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger("telegram-agent")

TG_LIMIT = 4000  # запас до лимита Telegram (4096)

TOOL_LABELS = {
    "list_files": "📂 list_files",
    "read_file": "📄 read_file",
    "write_file": "✏️ write_file",
    "run_command": "⚙️ run_command",
}


def _get_agent(context: ContextTypes.DEFAULT_TYPE, chat_id: int) -> Agent:
    agent = context.chat_data.get("agent")
    if agent is None:
        agent = Agent(config.workspace_for(chat_id))
        context.chat_data["agent"] = agent
    return agent


async def _send(update: Update, text: str) -> None:
    """Отправляет текст, разбивая длинные сообщения на части."""
    if not text:
        return
    for i in range(0, len(text), TG_LIMIT):
        await update.effective_chat.send_message(text[i : i + TG_LIMIT])


def _format_event(ev: dict) -> str | None:
    kind = ev.get("type")
    if kind == "assistant":
        return ev["message"]
    if kind == "tool_call":
        label = TOOL_LABELS.get(ev["name"], ev["name"])
        args = ev.get("args", {})
        detail = args.get("command") or args.get("path") or ""
        return f"{label}  {detail}".rstrip()
    if kind == "tool_result":
        return f"```\n{ev['result']}\n```"
    if kind == "done":
        return "✅ Готово"
    if kind == "error":
        return f"⚠️ {ev['message']}"
    return None


# --- Команды ---

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not config.is_allowed(update.effective_user.id):
        await update.message.reply_text(
            f"⛔ Доступ запрещён. Ваш ID: {update.effective_user.id}\n"
            "Попросите администратора добавить его в ALLOWED_USER_IDS."
        )
        return
    await update.message.reply_text(
        "👋 Привет! Я кодинг-агент на Gemini.\n\n"
        "Напишите задачу — я исследую файлы, внесу изменения и проверю их в вашей "
        "персональной рабочей папке.\n\n"
        "Команды:\n"
        "/reset — очистить контекст диалога\n"
        "/help — помощь"
    )


async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text(
        "Примеры задач:\n"
        "• Создай файл hello.py, который печатает «Привет, мир»\n"
        "• Покажи список файлов\n"
        "• Напиши функцию факториала и проверь её тестом\n\n"
        "/reset — начать диалог заново."
    )


async def reset(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not config.is_allowed(update.effective_user.id):
        return
    agent = context.chat_data.get("agent")
    if agent:
        agent.reset()
    await update.message.reply_text("🔄 Контекст очищен.")


# --- Обработка задачи ---

async def handle_task(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    user_id = update.effective_user.id
    if not config.is_allowed(user_id):
        await update.message.reply_text(
            f"⛔ Доступ запрещён. Ваш ID: {user_id}"
        )
        return

    if context.chat_data.get("busy"):
        await update.message.reply_text("⏳ Дождитесь завершения текущей задачи.")
        return

    task = update.message.text.strip()
    if not task:
        return

    agent = _get_agent(context, update.effective_chat.id)
    context.chat_data["busy"] = True

    loop = asyncio.get_event_loop()
    queue: asyncio.Queue = asyncio.Queue()

    def worker() -> None:
        try:
            for event in agent.run(task):
                loop.call_soon_threadsafe(queue.put_nowait, event)
        except Exception as exc:  # noqa: BLE001
            loop.call_soon_threadsafe(
                queue.put_nowait, {"type": "error", "message": str(exc)}
            )
        finally:
            loop.call_soon_threadsafe(queue.put_nowait, None)

    threading.Thread(target=worker, daemon=True).start()

    try:
        while True:
            event = await queue.get()
            if event is None:
                break
            await update.effective_chat.send_action(ChatAction.TYPING)
            text = _format_event(event)
            if text:
                await _send(update, text)
    finally:
        context.chat_data["busy"] = False


def main() -> None:
    if not config.TELEGRAM_BOT_TOKEN:
        raise SystemExit("Не задан TELEGRAM_BOT_TOKEN в .env")
    if not config.GEMINI_API_KEY:
        raise SystemExit("Не задан GEMINI_API_KEY в .env")
    if not config.ALLOWED_USER_IDS:
        logger.warning(
            "ALLOWED_USER_IDS пуст — бот отвечает ВСЕМ. Это небезопасно: "
            "бот выполняет команды. Укажите свой ID в .env."
        )

    app: Application = ApplicationBuilder().token(config.TELEGRAM_BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("help", help_cmd))
    app.add_handler(CommandHandler("reset", reset))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_task))

    logger.info("Бот запущен. Модель: %s", config.MODEL)
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
