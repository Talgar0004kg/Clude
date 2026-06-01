"""Самодостаточный телеграм-бот: локальный кодинг-агент на Ollama.

Зависит ТОЛЬКО от python-telegram-bot и python-dotenv (без других файлов проекта).

Запуск:
    pip install python-telegram-bot==21.6 python-dotenv
    # в отдельной вкладке: ollama serve   и   ollama pull llama3.2:3b
    python bot_local.py

.env (в той же папке):
    TELEGRAM_BOT_TOKEN=...
    ALLOWED_USER_IDS=123456789
    OLLAMA_MODEL=llama3.2:3b
"""
import asyncio
import json
import logging
import os
import shutil
import subprocess
import tempfile
import threading
import urllib.error
import urllib.request

from dotenv import load_dotenv
from telegram import Update
from telegram.constants import ChatAction
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

load_dotenv()

TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434").rstrip("/")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:3b").strip()
ALLOWED = {
    int(x) for x in os.getenv("ALLOWED_USER_IDS", "").replace(" ", "").split(",")
    if x.lstrip("-").isdigit()
}
TIMEOUT = int(os.getenv("AGENT_COMMAND_TIMEOUT", "120"))
MAX_STEPS = int(os.getenv("AGENT_MAX_STEPS", "25"))
WS_BASE = os.path.abspath(
    os.getenv("AGENT_WORKSPACE", os.path.join(os.path.dirname(__file__), "workspace"))
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("bot")


def allowed(uid: int) -> bool:
    return not ALLOWED or uid in ALLOWED


def ws_for(chat_id: int) -> str:
    path = os.path.join(WS_BASE, str(chat_id))
    os.makedirs(path, exist_ok=True)
    return path


# ─── Инструменты (всё внутри рабочей папки чата) ──────────────────────────

def _resolve(ws: str, path: str) -> str:
    c = os.path.abspath(os.path.join(ws, path))
    if c != ws and not c.startswith(ws + os.sep):
        raise ValueError("путь вне рабочей папки")
    return c


def t_list(ws, path="."):
    t = _resolve(ws, path)
    if not os.path.exists(t):
        return "нет такого пути"
    if os.path.isfile(t):
        return f"{path} — файл"
    return "\n".join(sorted(os.listdir(t))) or "(пусто)"


def t_read(ws, path):
    t = _resolve(ws, path)
    return open(t, encoding="utf-8").read()[:8000] if os.path.isfile(t) else "файл не найден"


def t_write(ws, path, content):
    t = _resolve(ws, path)
    os.makedirs(os.path.dirname(t), exist_ok=True)
    with open(t, "w", encoding="utf-8") as f:
        f.write(content)
    return f"сохранено: {path} ({len(content)} символов)"


def t_run(ws, command):
    try:
        r = subprocess.run(command, shell=True, cwd=ws, capture_output=True,
                           text=True, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        return "таймаут"
    return f"код {r.returncode}\n{(r.stdout + r.stderr)[:8000] or '(нет вывода)'}"


TOOLS_FN = {"list_files": t_list, "read_file": t_read, "write_file": t_write, "run_command": t_run}

TOOLS = [{"type": "function", "function": {"name": n, "description": d, "parameters": p}} for n, d, p in [
    ("list_files", "список файлов и папок",
     {"type": "object", "properties": {"path": {"type": "string"}}, "required": []}),
    ("read_file", "прочитать файл",
     {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}),
    ("write_file", "создать или перезаписать файл",
     {"type": "object", "properties": {"path": {"type": "string"}, "content": {"type": "string"}},
      "required": ["path", "content"]}),
    ("run_command", "выполнить shell-команду",
     {"type": "object", "properties": {"command": {"type": "string"}}, "required": ["command"]}),
]]

SYSTEM = (
    "Ты — кодинг-агент в Телеграме. Используй инструменты для работы с файлами и "
    "командами в рабочей папке. Делай качественные адаптивные сайты: семантический "
    "HTML5, meta viewport, современный CSS (flex/grid, переменные, плавность). "
    "Отвечай по-русски, коротко. Когда задача выполнена — напиши итог БЕЗ вызова "
    "инструментов."
)


def ollama_chat(messages):
    payload = {"model": OLLAMA_MODEL, "messages": messages, "tools": TOOLS,
               "stream": False, "options": {"temperature": 0.2}}
    req = urllib.request.Request(
        OLLAMA_HOST + "/api/chat", data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read())


def run_agent(chat_id, task):
    """Генератор событий: ('text'|'tool'|'result'|'done'|'error', значение)."""
    ws = ws_for(chat_id)
    msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": task}]
    for _ in range(MAX_STEPS):
        try:
            body = ollama_chat(msgs)
        except urllib.error.URLError as e:
            yield ("error", f"Нет связи с Ollama ({OLLAMA_HOST}). Запустите 'ollama serve'. ({e})")
            return
        except Exception as e:
            yield ("error", f"Ошибка Ollama: {e}")
            return
        m = body.get("message", {}) or {}
        text = m.get("content", "") or ""
        calls = m.get("tool_calls") or []
        msgs.append({"role": "assistant", "content": text, "tool_calls": calls})
        if text:
            yield ("text", text)
        if not calls:
            yield ("done", None)
            return
        for tc in calls:
            fn = tc.get("function", {}) or {}
            name = fn.get("name", "")
            args = fn.get("arguments", {})
            if isinstance(args, str):
                try:
                    args = json.loads(args)
                except json.JSONDecodeError:
                    args = {}
            yield ("tool", f"{name} {args.get('path') or args.get('command') or ''}".strip())
            func = TOOLS_FN.get(name)
            try:
                res = func(ws, **args) if func else f"неизвестный инструмент {name}"
            except Exception as e:
                res = f"ошибка: {e}"
            yield ("result", res)
            msgs.append({"role": "tool", "content": res})
    yield ("error", "достигнут лимит шагов")


def make_zip(ws):
    if not os.path.isdir(ws) or not os.listdir(ws):
        return None
    return shutil.make_archive(os.path.join(tempfile.mkdtemp(), "site"), "zip", ws)


# ─── Хендлеры ─────────────────────────────────────────────────────────────

async def start(u: Update, c: ContextTypes.DEFAULT_TYPE):
    if not allowed(u.effective_user.id):
        await u.message.reply_text(f"⛔ Доступ запрещён. Ваш ID: {u.effective_user.id}")
        return
    await u.message.reply_text(
        "👋 Локальный кодинг-агент (Ollama). Опишите задачу — например «сделай "
        "лендинг». Команда /zip пришлёт файлы архивом."
    )


async def zip_cmd(u: Update, c: ContextTypes.DEFAULT_TYPE):
    if not allowed(u.effective_user.id):
        return
    await u.effective_chat.send_action(ChatAction.UPLOAD_DOCUMENT)
    z = make_zip(ws_for(u.effective_chat.id))
    if not z:
        await u.effective_chat.send_message("📭 Пока пусто.")
        return
    with open(z, "rb") as f:
        await u.effective_chat.send_document(f, filename="site.zip")


async def on_text(u: Update, c: ContextTypes.DEFAULT_TYPE):
    if not allowed(u.effective_user.id):
        await u.message.reply_text(f"⛔ Доступ запрещён. Ваш ID: {u.effective_user.id}")
        return
    if c.chat_data.get("busy"):
        await u.message.reply_text("⏳ Дождитесь завершения текущей задачи.")
        return
    task = (u.message.text or "").strip()
    if not task:
        return
    c.chat_data["busy"] = True
    loop = asyncio.get_event_loop()
    q: asyncio.Queue = asyncio.Queue()

    def worker():
        try:
            for ev in run_agent(u.effective_chat.id, task):
                loop.call_soon_threadsafe(q.put_nowait, ev)
        except Exception as e:  # noqa: BLE001
            loop.call_soon_threadsafe(q.put_nowait, ("error", str(e)))
        finally:
            loop.call_soon_threadsafe(q.put_nowait, None)

    threading.Thread(target=worker, daemon=True).start()
    try:
        while True:
            ev = await q.get()
            if ev is None:
                break
            await u.effective_chat.send_action(ChatAction.TYPING)
            kind, val = ev
            if kind == "text" and val:
                await u.effective_chat.send_message(val[:4000])
            elif kind == "tool":
                await u.effective_chat.send_message("🔧 " + val)
            elif kind == "result":
                await u.effective_chat.send_message("```\n" + val[:3500] + "\n```",
                                                    parse_mode="Markdown")
            elif kind == "done":
                await u.effective_chat.send_message("✅ Готово")
            elif kind == "error":
                await u.effective_chat.send_message("⚠️ " + val)
    finally:
        c.chat_data["busy"] = False


def main():
    if not TOKEN:
        raise SystemExit("Нет TELEGRAM_BOT_TOKEN в .env")
    if not ALLOWED:
        log.warning("ALLOWED_USER_IDS пуст — бот отвечает всем (небезопасно).")
    log.info("Ollama: %s, модель %s", OLLAMA_HOST, OLLAMA_MODEL)
    app = ApplicationBuilder().token(TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("zip", zip_cmd))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_text))
    log.info("Бот запущен. Модель: %s", OLLAMA_MODEL)
    app.run_polling()


if __name__ == "__main__":
    main()
