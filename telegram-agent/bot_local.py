"""Самодостаточный телеграм-бот: локальный кодинг-агент на Ollama.

Зависит ТОЛЬКО от python-telegram-bot и python-dotenv (без других файлов проекта).
Инструменты ("руки"): файлы, команды, поиск в интернете, скачивание и отправка файлов.

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
import glob
import json
import logging
import os
import re
import shutil
import subprocess
import tempfile
import threading
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser

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
MAX_DOWNLOAD = int(os.getenv("AGENT_MAX_DOWNLOAD_MB", "45")) * 1024 * 1024
WS_BASE = os.path.abspath(
    os.getenv("AGENT_WORKSPACE", os.path.join(os.path.dirname(__file__), "workspace"))
)
UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/124.0.0.0 Safari/537.36")
_HEADERS = {"User-Agent": UA, "Accept": "*/*", "Accept-Language": "ru,en;q=0.9"}

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("bot")


def allowed(uid: int) -> bool:
    return not ALLOWED or uid in ALLOWED


def ws_for(chat_id: int) -> str:
    path = os.path.join(WS_BASE, str(chat_id))
    os.makedirs(path, exist_ok=True)
    return path


# ─── Файловые инструменты (внутри рабочей папки чата) ─────────────────────

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


# ─── Интернет-инструменты ─────────────────────────────────────────────────

def _encode_url(url):
    """Кодирует не-ASCII символы в URL (кириллица в пути/запросе/домене)."""
    try:
        url.encode("ascii")
        return url
    except UnicodeEncodeError:
        p = urllib.parse.urlsplit(url)
        netloc = p.netloc
        try:
            netloc = netloc.encode("idna").decode("ascii")
        except Exception:  # noqa: BLE001
            pass
        return urllib.parse.urlunsplit((
            p.scheme, netloc, urllib.parse.quote(p.path),
            urllib.parse.quote(p.query, safe="=&"), p.fragment,
        ))


def _http_get(url, binary=False, timeout=30):
    req = urllib.request.Request(_encode_url(url), headers=_HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as r:  # noqa: S310
        data = r.read()
    return data if binary else data.decode("utf-8", errors="replace")


def t_fetch(ws, url):
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    try:
        return _http_get(url)[:8000]
    except Exception as e:  # noqa: BLE001
        return f"ошибка загрузки: {e}"


class _Search(HTMLParser):
    def __init__(self):
        super().__init__()
        self.res = []
        self._in = False
        self._href = ""
        self._txt = []

    def handle_starttag(self, tag, attrs):
        if tag == "a" and "result__a" in (dict(attrs).get("class") or ""):
            self._in = True
            self._href = dict(attrs).get("href") or ""
            self._txt = []

    def handle_data(self, data):
        if self._in:
            self._txt.append(data)

    def handle_endtag(self, tag):
        if tag == "a" and self._in:
            self._in = False
            real = self._href
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self._href).query)
            if "uddg" in q:
                real = q["uddg"][0]
            title = "".join(self._txt).strip()
            if title and real:
                self.res.append((title, real))


def _ddg_search(query, limit=8):
    """Поиск через DuckDuckGo (POST), с запасным lite-эндпоинтом и regex-фолбэком."""
    data = urllib.parse.urlencode({"q": query, "kl": "ru-ru"}).encode()
    headers = {"User-Agent": UA, "Content-Type": "application/x-www-form-urlencoded"}
    for url in ("https://html.duckduckgo.com/html/", "https://lite.duckduckgo.com/lite/"):
        try:
            req = urllib.request.Request(url, data=data, headers=headers)
            with urllib.request.urlopen(req, timeout=30) as r:  # noqa: S310
                html = r.read().decode("utf-8", "replace")
        except Exception:  # noqa: BLE001
            continue
        p = _Search()
        p.feed(html)
        res = p.res
        if not res:
            # фолбэк: вытащить ссылки из редиректов /l/?uddg=...
            res = [("", urllib.parse.unquote(m)) for m in re.findall(r'uddg=([^&"\']+)', html)]
        if res:
            # убрать дубли, оставить http(s)
            seen, out = set(), []
            for t, u in res:
                if u.startswith(("http://", "https://")) and u not in seen:
                    seen.add(u)
                    out.append((t, u))
            if out:
                return out[:limit]
    return []


def t_search(ws, query):
    res = _ddg_search(query)
    if not res:
        return "ничего не найдено (поисковик не вернул результатов)"
    return "\n".join(f"{i+1}. {t or '(без названия)'}\n   {u}" for i, (t, u) in enumerate(res))


def _safe_name(name):
    name = os.path.basename(name.split("?")[0]) or "download"
    return re.sub(r"[^A-Za-z0-9._-]", "_", name)[:120] or "download"


def _download(ws, url, filename=""):
    """Скачивает файл в рабочую папку, возвращает имя файла. Бросает при ошибке."""
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    req = urllib.request.Request(_encode_url(url), headers=_HEADERS)
    with urllib.request.urlopen(req, timeout=60) as r:  # noqa: S310
        if not filename:
            cd = r.headers.get("Content-Disposition", "")
            m = re.search(r'filename="?([^"\;]+)"?', cd)
            filename = m.group(1) if m else os.path.basename(urllib.parse.urlparse(url).path)
        data = r.read(MAX_DOWNLOAD + 1)
    if len(data) > MAX_DOWNLOAD:
        raise ValueError(f"файл больше {MAX_DOWNLOAD // 1024 // 1024} МБ")
    filename = _safe_name(filename or "download")
    if "." not in filename:  # картинки часто без расширения в URL
        filename += ".jpg"
    with open(_resolve(ws, filename), "wb") as f:
        f.write(data)
    return filename


def t_download(ws, url, filename=""):
    try:
        name = _download(ws, url, filename)
    except Exception as e:  # noqa: BLE001
        return f"ошибка скачивания: {e}"
    return f"скачано: {name}. Теперь вызови send_file с path='{name}'."


def _ddg_images(query, limit=6):
    """Возвращает прямые ссылки на изображения через DuckDuckGo."""
    headers = {"User-Agent": UA, "Referer": "https://duckduckgo.com/"}
    try:
        token = _http_get("https://duckduckgo.com/?q=" + urllib.parse.quote(query)
                          + "&iax=images&ia=images")
    except Exception:  # noqa: BLE001
        token = ""
    m = re.search(r'vqd=["\']?([\d-]+)', token)
    if not m:
        return []
    url = ("https://duckduckgo.com/i.js?l=ru-ru&o=json&q=" + urllib.parse.quote(query)
           + "&vqd=" + m.group(1) + "&f=,,,&p=1")
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=30) as r:  # noqa: S310
            data = json.loads(r.read().decode("utf-8", "replace"))
    except Exception:  # noqa: BLE001
        return []
    return [it.get("image") for it in data.get("results", []) if it.get("image")][:limit]


def t_image_search(ws, query):
    imgs = _ddg_images(query)
    if not imgs:
        return "картинок не найдено"
    return "Прямые ссылки на изображения:\n" + "\n".join(imgs)


def _download_video(ws, url):
    """Качает видео по ссылке (YouTube/Instagram/TikTok/…) через yt-dlp, ≤49 МБ."""
    for f in glob.glob(os.path.join(ws, "video.*")):
        try:
            os.remove(f)
        except OSError:
            pass
    out = os.path.join(ws, "video.%(ext)s")
    try:
        r = subprocess.run(
            ["yt-dlp", "--no-playlist", "--max-filesize", "49M",
             "-f", "mp4[height<=720]/best[height<=720]/best",
             "-o", out, url],
            capture_output=True, text=True, timeout=300,
        )
    except FileNotFoundError:
        return None, "yt-dlp не установлен (pip install yt-dlp)"
    except subprocess.TimeoutExpired:
        return None, "таймаут скачивания видео"
    files = [f for f in glob.glob(os.path.join(ws, "video.*"))
             if not f.endswith(".part")]
    if files:
        return os.path.basename(files[0]), ""
    return None, ((r.stdout + r.stderr)[-400:] or "видео не скачалось")


def _find_file_links(query, exts):
    """Ищет прямые ссылки на файлы нужных форматов (fb2/epub/txt/pdf...).

    Сначала прямые ссылки из выдачи, потом — со страниц верхних результатов.
    """
    pat = "(?:" + "|".join(exts) + ")"
    res = _ddg_search(query + " скачать " + " ".join(exts))
    urls = [u for _, u in res]
    direct = [u for u in urls
              if re.search(r"\." + pat + r"($|\?)", u.lower())]
    if direct:
        return direct
    found = []
    for u in urls[:5]:
        try:
            html = _http_get(u)
        except Exception:  # noqa: BLE001
            continue
        for m in re.findall(r'href=["\']([^"\']+\.' + pat + r')["\']', html, re.I):
            found.append(urllib.parse.urljoin(u, m))
        if found:
            break
    return found


TOOLS_FN = {
    "list_files": t_list, "read_file": t_read, "write_file": t_write,
    "run_command": t_run, "fetch_url": t_fetch, "web_search": t_search,
    "download_file": t_download, "image_search": t_image_search,
}

# Описания инструментов для модели (Ollama tool-calling).
TOOLS = [{"type": "function", "function": {"name": n, "description": d, "parameters": p}} for n, d, p in [
    ("list_files", "Список файлов в рабочей папке",
     {"type": "object", "properties": {"path": {"type": "string"}}, "required": []}),
    ("read_file", "Прочитать файл",
     {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}),
    ("write_file", "Создать/перезаписать файл",
     {"type": "object", "properties": {"path": {"type": "string"}, "content": {"type": "string"}},
      "required": ["path", "content"]}),
    ("run_command", "Выполнить shell-команду",
     {"type": "object", "properties": {"command": {"type": "string"}}, "required": ["command"]}),
    ("fetch_url", "Зайти на сайт и прочитать его HTML/текст",
     {"type": "object", "properties": {"url": {"type": "string"}}, "required": ["url"]}),
    ("web_search", "Найти что-либо в интернете (фото, книгу, файл, инфо). Возвращает ссылки",
     {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]}),
    ("download_file", "Скачать файл по прямой ссылке (jpg/pdf/mp3/zip…) в рабочую папку",
     {"type": "object", "properties": {"url": {"type": "string"}, "filename": {"type": "string"}},
      "required": ["url"]}),
    ("send_file", "Отправить пользователю в чат конкретный файл (любого типа)",
     {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}),
    ("send_files", "Упаковать рабочую папку в zip и отправить пользователю",
     {"type": "object", "properties": {}, "required": []}),
    ("image_search", "Найти прямые ссылки на изображения по запросу",
     {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]}),
    ("send_image", "Найти фото/картинку по запросу, скачать и сразу отправить пользователю (одним вызовом)",
     {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]}),
    ("send_book", "Найти книгу/документ (fb2/epub/txt/pdf) по запросу, скачать и отправить пользователю",
     {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]}),
    ("send_github", "Скачать репозиторий с GitHub архивом zip и отправить. Формат repo: 'owner/name'",
     {"type": "object", "properties": {"repo": {"type": "string"}}, "required": ["repo"]}),
    ("send_video", "Скачать видео по ссылке (YouTube/Instagram/TikTok и др.) и отправить пользователю",
     {"type": "object", "properties": {"url": {"type": "string"}}, "required": ["url"]}),
]]

SYSTEM = (
    "Ты — кодинг-агент в Телеграме с РУКАМИ (инструментами). У тебя ЕСТЬ доступ к "
    "файлам, терминалу и интернету. НИКОГДА не говори, что ты чего-то не умеешь или "
    "не можешь отправить/скачать/найти — вместо этого ВЫЗЫВАЙ нужный инструмент.\n"
    "Как действовать (выбирай ОДИН подходящий инструмент и доводи до конца):\n"
    "- ФОТО/картинка/обложка → send_image(query).\n"
    "- Книга/документ (fb2/epub/txt/pdf) → send_book(query).\n"
    "- Репозиторий с GitHub → send_github(repo), repo вида 'owner/name'.\n"
    "- Видео по ссылке (YouTube/Instagram/TikTok) → send_video(url).\n"
    "- Файл по прямой ссылке → download_file(url), затем send_file(path).\n"
    "- Найти текст/ссылки → web_search; открыть страницу → fetch_url.\n"
    "- Отправить готовый файл → send_file(path). Рабочую папку архивом → send_files.\n"
    "- Сделать сайт/код → write_file; проверить → run_command.\n"
    "Доводи задачу до конца: не выводи просто список ссылок, а выполняй до файла "
    "в чате. Если сайт заблокировал (403/анти-бот) — попробуй другой источник.\n"
    "Делай качественные адаптивные сайты (semantic HTML5, meta viewport, "
    "современный CSS). Отвечай по-русски, коротко. Когда всё сделано — напиши "
    "итог БЕЗ вызова инструментов."
)


def ollama_chat(messages):
    payload = {"model": OLLAMA_MODEL, "messages": messages, "tools": TOOLS,
               "stream": False, "keep_alive": "30m", "options": {"temperature": 0.2}}
    req = urllib.request.Request(
        OLLAMA_HOST + "/api/chat", data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:  # noqa: S310
        return json.loads(r.read())


def run_agent(chat_id, task):
    """Генератор: ('text'|'tool'|'result'|'send_file'|'send_zip'|'done'|'error', значение)."""
    ws = ws_for(chat_id)
    msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": task}]
    for _ in range(MAX_STEPS):
        try:
            body = ollama_chat(msgs)
        except urllib.error.URLError as e:
            yield ("error", f"Нет связи с Ollama ({OLLAMA_HOST}). Запустите 'ollama serve'. ({e})")
            return
        except Exception as e:  # noqa: BLE001
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
            yield ("tool", f"{name} {args.get('path') or args.get('command') or args.get('query') or args.get('url') or ''}".strip())

            if name == "send_file":
                p = args.get("path", "")
                target = os.path.abspath(os.path.join(ws, p))
                if (target == ws or target.startswith(ws + os.sep)) and os.path.isfile(target):
                    yield ("send_file", p)
                    res = f"файл {p} отправлен пользователю"
                else:
                    res = (f"файл '{p}' НЕ найден в рабочей папке. Сначала скачай его "
                           "через download_file, потом отправляй send_file с относительным путём.")
            elif name == "send_files":
                yield ("send_zip", None)
                res = "архив отправлен пользователю"
            elif name == "send_image":
                qy = args.get("query", "")
                imgs = _ddg_images(qy)
                saved = None
                for u in imgs:  # перебираем, пока какая-то картинка не скачается (403 и т.п.)
                    try:
                        saved = _download(ws, u)
                        break
                    except Exception:  # noqa: BLE001
                        continue
                if saved:
                    yield ("send_file", saved)
                    res = f"картинка по запросу '{qy}' отправлена пользователю"
                else:
                    res = f"не удалось найти/скачать картинку по запросу '{qy}'"
            elif name == "send_book":
                qy = args.get("query", "")
                links = _find_file_links(qy, ["fb2", "epub", "txt", "pdf"])
                saved = None
                for u in links[:10]:
                    try:
                        saved = _download(ws, u)
                        break
                    except Exception:  # noqa: BLE001
                        continue
                if saved:
                    yield ("send_file", saved)
                    res = f"книга/документ по запросу '{qy}' отправлен(а)"
                else:
                    res = (f"не нашёл скачиваемый файл по запросу '{qy}'. Многие сайты "
                           "блокируют ботов; попробуй уточнить формат (fb2/pdf/txt).")
            elif name == "send_github":
                repo = (args.get("repo", "") or "").strip().rstrip("/")
                repo = re.sub(r"^https?://github\.com/", "", repo)
                saved = None
                for br in ("main", "master"):
                    try:
                        saved = _download(
                            ws, f"https://codeload.github.com/{repo}/zip/refs/heads/{br}",
                            filename=repo.split("/")[-1] + ".zip")
                        break
                    except Exception:  # noqa: BLE001
                        continue
                if saved:
                    yield ("send_file", saved)
                    res = f"репозиторий {repo} отправлен архивом"
                else:
                    res = f"не удалось скачать репозиторий '{repo}' (проверь owner/name)."
            elif name == "send_video":
                vurl = args.get("url", "")
                fn, err = _download_video(ws, vurl)
                if fn:
                    yield ("send_file", fn)
                    res = "видео отправлено пользователю"
                else:
                    res = (f"не удалось скачать видео: {err}. Возможно, оно больше 49 МБ "
                           "(лимит Telegram) или требует входа на сайт.")
            else:
                func = TOOLS_FN.get(name)
                try:
                    res = func(ws, **args) if func else f"неизвестный инструмент {name}"
                except Exception as e:  # noqa: BLE001
                    res = f"ошибка: {e}"
            yield ("result", res)
            msgs.append({"role": "tool", "content": res})
    yield ("error", "достигнут лимит шагов")


def make_zip(ws):
    if not os.path.isdir(ws) or not os.listdir(ws):
        return None
    return shutil.make_archive(os.path.join(tempfile.mkdtemp(), "site"), "zip", ws)


# ─── Отправка файлов в чат ────────────────────────────────────────────────

async def send_zip(update, chat_id):
    z = make_zip(ws_for(chat_id))
    if not z:
        await update.effective_chat.send_message("📭 Пока пусто.")
        return
    with open(z, "rb") as f:
        await update.effective_chat.send_document(f, filename="site.zip")


async def send_one_file(update, chat_id, rel):
    ws = ws_for(chat_id)
    target = os.path.abspath(os.path.join(ws, rel))
    if not (target == ws or target.startswith(ws + os.sep)) or not os.path.isfile(target):
        await update.effective_chat.send_message(f"⚠️ Файл не найден: {rel}")
        return
    with open(target, "rb") as f:
        await update.effective_chat.send_document(f, filename=os.path.basename(target))


# ─── Хендлеры ─────────────────────────────────────────────────────────────

async def start(u: Update, c: ContextTypes.DEFAULT_TYPE):
    if not allowed(u.effective_user.id):
        await u.message.reply_text(f"⛔ Доступ запрещён. Ваш ID: {u.effective_user.id}")
        return
    await u.message.reply_text(
        "👋 Локальный ИИ-агент (Ollama). Умею: делать сайты/код, выполнять команды, "
        "искать в интернете, скачивать и присылать файлы.\n\n"
        "Примеры: «сделай лендинг», «найди фото кота и пришли», «скачай …».\n"
        "/zip — прислать рабочую папку архивом."
    )


async def zip_cmd(u: Update, c: ContextTypes.DEFAULT_TYPE):
    if not allowed(u.effective_user.id):
        return
    await u.effective_chat.send_action(ChatAction.UPLOAD_DOCUMENT)
    await send_zip(u, u.effective_chat.id)


_whisper = None


def transcribe(path: str) -> str:
    """Распознаёт речь из аудиофайла в текст (faster-whisper, локально)."""
    global _whisper
    if _whisper is None:
        from faster_whisper import WhisperModel
        model = os.getenv("WHISPER_MODEL", "base")
        _whisper = WhisperModel(model, device="cpu", compute_type="int8")
    segments, _ = _whisper.transcribe(path, language="ru")
    return " ".join(s.text.strip() for s in segments).strip()


async def on_voice(u: Update, c: ContextTypes.DEFAULT_TYPE):
    if not allowed(u.effective_user.id):
        await u.message.reply_text(f"⛔ Доступ запрещён. Ваш ID: {u.effective_user.id}")
        return
    voice = u.message.voice or u.message.audio
    if voice is None:
        return
    await u.effective_chat.send_action(ChatAction.TYPING)
    tg_file = await voice.get_file()
    data = bytes(await tg_file.download_as_bytearray())
    tmp = os.path.join(tempfile.mkdtemp(), "voice.oga")
    with open(tmp, "wb") as f:
        f.write(data)
    try:
        text = await asyncio.to_thread(transcribe, tmp)
    except Exception as e:  # noqa: BLE001
        await u.effective_chat.send_message(f"⚠️ Не смог распознать голос: {e}")
        return
    if not text:
        await u.effective_chat.send_message("🤷 Не расслышал. Попробуйте ещё раз.")
        return
    await u.effective_chat.send_message(f"📝 Распознал: {text}")
    await _process(u, c, text)


async def on_text(u: Update, c: ContextTypes.DEFAULT_TYPE):
    if not allowed(u.effective_user.id):
        await u.message.reply_text(f"⛔ Доступ запрещён. Ваш ID: {u.effective_user.id}")
        return
    task = (u.message.text or "").strip()
    if task:
        await _process(u, c, task)


async def _process(u: Update, c: ContextTypes.DEFAULT_TYPE, task: str):
    if c.chat_data.get("busy"):
        await u.message.reply_text("⏳ Дождитесь завершения текущей задачи.")
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
            elif kind == "send_file":
                await send_one_file(u, u.effective_chat.id, val)
            elif kind == "send_zip":
                await send_zip(u, u.effective_chat.id)
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
    app.add_handler(MessageHandler(filters.VOICE | filters.AUDIO, on_voice))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_text))
    log.info("Бот запущен. Модель: %s", OLLAMA_MODEL)
    app.run_polling()


if __name__ == "__main__":
    main()
