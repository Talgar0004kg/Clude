"""Телеграм-бот: кодинг-агент на локальной модели (Ollama).

Пользователь пишет задачу в чат → агент исследует/меняет файлы и выполняет
команды в персональной рабочей папке → шаги приходят обратно в чат.
"""
import asyncio
import logging
import os
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
import tools
from agent import Agent
from llm import LLMError

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
    "fetch_url": "🌐 fetch_url",
    "download_site": "⬇️ download_site",
    "web_search": "🔎 web_search",
    "download_file": "📥 download_file",
    "send_file": "📤 send_file",
    "send_files": "📦 send_files",
    "git_commit": "💾 git_commit",
}


async def _send_zip(update: Update, chat_id: int) -> None:
    """Упаковывает рабочую папку чата в zip и отправляет документом."""
    archive = await asyncio.to_thread(tools.make_zip, config.workspace_for(chat_id))
    if archive is None:
        await update.effective_chat.send_message(
            "📭 Пока нечего отправлять — рабочая папка пуста."
        )
        return
    with open(archive, "rb") as f:
        await update.effective_chat.send_document(f, filename="site.zip")


async def _send_file(update: Update, chat_id: int, rel_path: str) -> None:
    """Отправляет конкретный файл из рабочей папки чата (с реальным типом/именем)."""
    workspace = config.workspace_for(chat_id)
    target = os.path.abspath(os.path.join(workspace, rel_path))
    if not (target == workspace or target.startswith(workspace + os.sep)) \
            or not os.path.isfile(target):
        await update.effective_chat.send_message(f"⚠️ Файл не найден: {rel_path}")
        return
    with open(target, "rb") as f:
        await update.effective_chat.send_document(f, filename=os.path.basename(target))


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
        detail = (args.get("command") or args.get("query") or args.get("url")
                  or args.get("path") or "")
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
        "👋 Привет! Я локальный кодинг-агент (Ollama).\n\n"
        "Напишите задачу — я исследую файлы, внесу изменения и проверю их в вашей "
        "персональной рабочей папке.\n\n"
        "📷 Пришлите картинку дизайна/скриншот сайта — свёрстаю его один в один.\n\n"
        "Команды:\n"
        "/zip — прислать файлы архивом\n"
        "/commit — сохранить код в репозиторий\n"
        "/model — сменить модель/провайдера\n"
        "/reset — очистить контекст диалога\n"
        "/help — помощь"
    )


async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text(
        "Примеры задач:\n"
        "• Создай файл hello.py, который печатает «Привет, мир»\n"
        "• Покажи список файлов\n"
        "• Напиши функцию факториала и проверь её тестом\n"
        "• Пришли мне zip с сайтом · Сохрани код в репозиторий\n\n"
        "Команды: /zip — архив файлов, /commit — сохранить в git, "
        "/reset — начать заново."
    )


async def reset(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not config.is_allowed(update.effective_user.id):
        return
    agent = context.chat_data.get("agent")
    if agent:
        agent.reset()
    await update.message.reply_text("🔄 Контекст очищен.")


async def zip_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Прислать zip с файлами рабочей папки."""
    if not config.is_allowed(update.effective_user.id):
        return
    await update.effective_chat.send_action(ChatAction.UPLOAD_DOCUMENT)
    await _send_zip(update, update.effective_chat.id)


async def model_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Показать или сменить провайдера/модель без перезапуска бота."""
    if not config.is_allowed(update.effective_user.id):
        return
    args = [a.strip() for a in context.args if a.strip()]
    if not args:
        await update.message.reply_text(
            f"🧠 Текущая локальная модель: *{config.current_model()}*\n\n"
            "Сменить:\n"
            "`/model llama3.2:3b`\n"
            "`/model qwen2.5:7b`\n"
            "`/model llama3.1:8b`\n\n"
            "Модель должна быть скачана: `ollama pull <модель>`",
            parse_mode="Markdown",
        )
        return

    prev = config.OLLAMA_MODEL
    config.set_model(args[0])
    try:
        agent = _get_agent(context, update.effective_chat.id)
        agent.rebuild_client()
    except LLMError as exc:
        config.set_model(prev)
        await update.message.reply_text(f"⚠️ Не удалось переключить: {exc}")
        return
    await update.message.reply_text(f"✅ Модель: {config.current_model()}")


async def commit_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Закоммитить рабочую папку в репозиторий (и запушить)."""
    if not config.is_allowed(update.effective_user.id):
        return
    message = " ".join(context.args) if context.args else "update from telegram agent"
    await update.effective_chat.send_action(ChatAction.TYPING)
    workspace = config.workspace_for(update.effective_chat.id)
    result = await asyncio.to_thread(tools.git_commit, workspace, message)
    await _send(update, result)


# --- Обработка задачи ---

async def handle_task(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not config.is_allowed(update.effective_user.id):
        await update.message.reply_text(
            f"⛔ Доступ запрещён. Ваш ID: {update.effective_user.id}"
        )
        return
    task = (update.message.text or "").strip()
    if not task:
        return
    await _run_agent(update, context, task)


async def handle_photo(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Пользователь прислал картинку (дизайн/скриншот) — верстаем сайт по ней."""
    if not config.is_allowed(update.effective_user.id):
        await update.message.reply_text(
            f"⛔ Доступ запрещён. Ваш ID: {update.effective_user.id}"
        )
        return

    # Берём самое крупное фото или картинку-документ.
    images: list[bytes] = []
    if update.message.photo:
        tg_file = await update.message.photo[-1].get_file()
        images.append(bytes(await tg_file.download_as_bytearray()))
    elif update.message.document and (update.message.document.mime_type or "").startswith("image/"):
        tg_file = await update.message.document.get_file()
        images.append(bytes(await tg_file.download_as_bytearray()))
    else:
        return

    caption = (update.message.caption or "").strip()
    task = caption or (
        "Свёрстай сайт один в один по этому изображению: создай index.html, "
        "style.css и при необходимости script.js. Точно повтори структуру, "
        "расположение, цвета, шрифты и тексты."
    )
    await _run_agent(update, context, task, images=images)


async def _run_agent(
    update: Update,
    context: ContextTypes.DEFAULT_TYPE,
    task: str,
    images: list[bytes] | None = None,
) -> None:
    """Запускает агента и стримит шаги в чат."""
    if context.chat_data.get("busy"):
        await update.message.reply_text("⏳ Дождитесь завершения текущей задачи.")
        return

    agent = _get_agent(context, update.effective_chat.id)
    context.chat_data["busy"] = True

    loop = asyncio.get_event_loop()
    queue: asyncio.Queue = asyncio.Queue()

    def worker() -> None:
        try:
            for event in agent.run(task, images=images):
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
            if event.get("type") == "send_zip":
                await _send_zip(update, update.effective_chat.id)
                continue
            if event.get("type") == "send_file":
                await _send_file(update, update.effective_chat.id, event.get("path", ""))
                continue
            text = _format_event(event)
            if text:
                await _send(update, text)
    finally:
        context.chat_data["busy"] = False


def main() -> None:
    if not config.TELEGRAM_BOT_TOKEN:
        raise SystemExit("Не задан TELEGRAM_BOT_TOKEN в .env")
    logger.info(
        "LLM: локальная Ollama (%s, модель %s). Нужен запущенный 'ollama serve'.",
        config.OLLAMA_HOST,
        config.OLLAMA_MODEL,
    )
    if not config.ALLOWED_USER_IDS:
        logger.warning(
            "ALLOWED_USER_IDS пуст — бот отвечает ВСЕМ. Это небезопасно: "
            "бот выполняет команды. Укажите свой ID в .env."
        )

    app: Application = ApplicationBuilder().token(config.TELEGRAM_BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("help", help_cmd))
    app.add_handler(CommandHandler("reset", reset))
    app.add_handler(CommandHandler("zip", zip_cmd))
    app.add_handler(CommandHandler("commit", commit_cmd))
    app.add_handler(CommandHandler("model", model_cmd))
    app.add_handler(MessageHandler(filters.PHOTO | filters.Document.IMAGE, handle_photo))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_task))

    logger.info("Бот запущен. Локальная модель: %s", config.OLLAMA_MODEL)
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
