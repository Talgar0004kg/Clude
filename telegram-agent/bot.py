"""
Telegram-бот с Gemini AI агентом.
Запуск: python bot.py
"""
import asyncio
import logging
import os
import subprocess
import sys
from typing import Optional

from dotenv import load_dotenv
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

import google.generativeai as genai

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ── Конфигурация ──────────────────────────────────────────────
TELEGRAM_BOT_TOKEN: str = os.environ["TELEGRAM_BOT_TOKEN"]
GEMINI_API_KEY: str = os.environ["GEMINI_API_KEY"]
AGENT_MODEL: str = os.getenv("AGENT_MODEL", "gemini-2.5-flash")
COMMAND_TIMEOUT: int = int(os.getenv("AGENT_COMMAND_TIMEOUT", "120"))
MAX_STEPS: int = int(os.getenv("AGENT_MAX_STEPS", "25"))

_raw_ids = os.getenv("ALLOWED_USER_IDS", "").strip()
ALLOWED_USER_IDS: set[int] = (
    {int(uid.strip()) for uid in _raw_ids.split(",") if uid.strip()}
    if _raw_ids else set()
)

# ── Gemini ────────────────────────────────────────────────────
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel(AGENT_MODEL)

# ── Вспомогательные функции ───────────────────────────────────

def is_allowed(user_id: int) -> bool:
    """Проверяет, разрешён ли пользователь."""
    if not ALLOWED_USER_IDS:
        return True  # белый список пуст → разрешить всем (не рекомендуется)
    return user_id in ALLOWED_USER_IDS


def run_shell(cmd: str, timeout: int = COMMAND_TIMEOUT) -> str:
    """Выполняет shell-команду и возвращает stdout+stderr."""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=timeout
        )
        output = (result.stdout + result.stderr).strip()
        return output or "(команда выполнена, вывод пуст)"
    except subprocess.TimeoutExpired:
        return f"⏱ Таймаут: команда выполнялась дольше {timeout} секунд."
    except Exception as exc:
        return f"❌ Ошибка выполнения: {exc}"


async def ask_gemini(prompt: str, history: list[dict]) -> str:
    """Отправляет запрос в Gemini и возвращает текстовый ответ."""
    try:
        chat = model.start_chat(history=history)
        response = await asyncio.to_thread(chat.send_message, prompt)
        return response.text
    except Exception as exc:
        logger.error("Gemini error: %s", exc)
        return f"❌ Ошибка Gemini: {exc}"


# ── Handlers ──────────────────────────────────────────────────

async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("🚫 Нет доступа.")
        return
    context.user_data.clear()
    await update.message.reply_text(
        "👋 Привет! Я Gemini-агент.\n\n"
        "Просто напишите задачу — я отвечу или выполню команду.\n\n"
        "Команды:\n"
        "/start — начать заново\n"
        "/clear — очистить историю\n"
        "/run <команда> — выполнить shell-команду напрямую"
    )


async def cmd_clear(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("🚫 Нет доступа.")
        return
    context.user_data.clear()
    await update.message.reply_text("🗑 История очищена.")


async def cmd_run(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("🚫 Нет доступа.")
        return
    cmd = " ".join(context.args) if context.args else ""
    if not cmd:
        await update.message.reply_text("Использование: /run <команда>")
        return
    await update.message.reply_text(f"⚙️ Выполняю: `{cmd}`", parse_mode="Markdown")
    output = await asyncio.to_thread(run_shell, cmd)
    # Telegram ограничивает сообщение 4096 символами
    for chunk in [output[i:i+4000] for i in range(0, len(output), 4000)]:
        await update.message.reply_text(f"```\n{chunk}\n```", parse_mode="Markdown")


async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("🚫 Нет доступа.")
        return

    user_text = update.message.text or ""
    history: list[dict] = context.user_data.get("history", [])

    await update.message.chat.send_action("typing")

    reply = await ask_gemini(user_text, history)

    # Сохраняем историю (последние MAX_STEPS * 2 сообщений)
    history.append({"role": "user", "parts": [user_text]})
    history.append({"role": "model", "parts": [reply]})
    context.user_data["history"] = history[-(MAX_STEPS * 2):]

    for chunk in [reply[i:i+4000] for i in range(0, len(reply), 4000)]:
        await update.message.reply_text(chunk)


# ── Main ──────────────────────────────────────────────────────

def main() -> None:
    if not ALLOWED_USER_IDS:
        logger.warning(
            "⚠️  ALLOWED_USER_IDS не задан — бот доступен всем. "
            "Рекомендуется указать свой Telegram ID."
        )

    app = Application.builder().token(TELEGRAM_BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("clear", cmd_clear))
    app.add_handler(CommandHandler("run", cmd_run))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))

    logger.info("Бот запущен. Модель: %s", AGENT_MODEL)
    app.run_polling(drop_pending_updates=True)


if __name__ == "__main__":
    main()
