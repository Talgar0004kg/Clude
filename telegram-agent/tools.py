"""Инструменты агента: файлы и команды, ограниченные рабочей папкой чата."""
import os
import shutil
import subprocess
import tempfile
import urllib.parse
import urllib.request
from html.parser import HTMLParser

import config

_USER_AGENT = "Mozilla/5.0 (compatible; TelegramAgent/1.0)"


class ToolError(Exception):
    """Ошибка инструмента — возвращается модели как текст."""


def _resolve(workspace: str, path: str) -> str:
    """Абсолютный путь внутри workspace; защита от выхода за пределы."""
    candidate = os.path.abspath(os.path.join(workspace, path))
    if candidate != workspace and not candidate.startswith(workspace + os.sep):
        raise ToolError(f"Путь '{path}' выходит за пределы рабочей папки.")
    return candidate


def list_files(workspace: str, path: str = ".") -> str:
    target = _resolve(workspace, path)
    if not os.path.exists(target):
        raise ToolError(f"Путь не найден: {path}")
    if os.path.isfile(target):
        return f"{path} — файл ({os.path.getsize(target)} байт)."
    entries = sorted(os.listdir(target))
    if not entries:
        return f"Папка '{path}' пуста."
    return "\n".join(
        name + ("/" if os.path.isdir(os.path.join(target, name)) else "")
        for name in entries
    )


def read_file(workspace: str, path: str) -> str:
    target = _resolve(workspace, path)
    if not os.path.isfile(target):
        raise ToolError(f"Файл не найден: {path}")
    try:
        with open(target, "r", encoding="utf-8") as f:
            content = f.read()
    except UnicodeDecodeError:
        raise ToolError(f"Файл '{path}' не текстовый (UTF-8).")
    if len(content) > config.MAX_TOOL_OUTPUT:
        content = content[: config.MAX_TOOL_OUTPUT] + "\n... [обрезано]"
    return content


def write_file(workspace: str, path: str, content: str) -> str:
    target = _resolve(workspace, path)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8") as f:
        f.write(content)
    return f"Файл '{path}' сохранён ({len(content)} символов)."


def run_command(workspace: str, command: str) -> str:
    try:
        result = subprocess.run(
            command,
            shell=True,
            cwd=workspace,
            capture_output=True,
            text=True,
            timeout=config.COMMAND_TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        raise ToolError(f"Команда превысила лимит ({config.COMMAND_TIMEOUT} сек).")
    output = ((result.stdout or "") + (result.stderr or "")).strip() or "(нет вывода)"
    if len(output) > config.MAX_TOOL_OUTPUT:
        output = output[: config.MAX_TOOL_OUTPUT] + "\n... [обрезано]"
    return f"Код возврата: {result.returncode}\n{output}"


# --- Работа с сайтами ---


def _http_get(url: str, binary: bool = False, timeout: int = 30):
    req = urllib.request.Request(url, headers={"User-Agent": _USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
        data = resp.read()
    return data if binary else data.decode("utf-8", errors="replace")


def fetch_url(workspace: str, url: str) -> str:
    """Загружает страницу по URL и возвращает её HTML/текст для анализа."""
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    try:
        html = _http_get(url)
    except Exception as exc:  # noqa: BLE001
        raise ToolError(f"Не удалось загрузить {url}: {exc}")
    if len(html) > config.MAX_TOOL_OUTPUT:
        html = html[: config.MAX_TOOL_OUTPUT] + "\n... [вывод обрезан]"
    return html


class _AssetParser(HTMLParser):
    """Находит ссылки на ресурсы страницы (css, js, img)."""

    def __init__(self) -> None:
        super().__init__()
        self.assets: list[str] = []

    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if tag == "link" and d.get("href"):
            self.assets.append(d["href"])
        elif tag == "script" and d.get("src"):
            self.assets.append(d["src"])
        elif tag == "img" and d.get("src"):
            self.assets.append(d["src"])


def download_site(workspace: str, url: str, dest: str = "site") -> str:
    """Скачивает страницу и её ресурсы (css/js/img) в папку dest."""
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    folder = _resolve(workspace, dest)
    os.makedirs(folder, exist_ok=True)
    try:
        html = _http_get(url)
    except Exception as exc:  # noqa: BLE001
        raise ToolError(f"Не удалось загрузить {url}: {exc}")

    parser = _AssetParser()
    parser.feed(html)

    saved, failed = 0, 0
    for raw in list(dict.fromkeys(parser.assets)):  # уникальные, по порядку
        if raw.startswith(("data:", "#", "javascript:", "mailto:")):
            continue
        asset_url = urllib.parse.urljoin(url, raw)
        if not asset_url.startswith(("http://", "https://")):
            continue
        path = urllib.parse.urlparse(asset_url).path.lstrip("/")
        if not path or path.endswith("/"):
            continue
        rel = os.path.join("assets", path)
        try:
            abs_path = _resolve(workspace, os.path.join(dest, rel))
        except ToolError:
            continue
        if saved >= 40:  # ограничение, чтобы не качать бесконечно
            break
        try:
            data = _http_get(asset_url, binary=True)
            os.makedirs(os.path.dirname(abs_path), exist_ok=True)
            with open(abs_path, "wb") as f:
                f.write(data)
            html = html.replace(raw, rel.replace(os.sep, "/"))
            saved += 1
        except Exception:  # noqa: BLE001
            failed += 1

    with open(os.path.join(folder, "index.html"), "w", encoding="utf-8") as f:
        f.write(html)

    msg = f"Сайт сохранён в '{dest}/': index.html + {saved} ресурсов."
    if failed:
        msg += f" Не удалось скачать: {failed}."
    return msg


TOOL_FUNCTIONS = {
    "list_files": list_files,
    "read_file": read_file,
    "write_file": write_file,
    "run_command": run_command,
    "fetch_url": fetch_url,
    "download_site": download_site,
}


def execute(name: str, args: dict, workspace: str) -> str:
    func = TOOL_FUNCTIONS.get(name)
    if func is None:
        return f"Неизвестный инструмент: {name}"
    try:
        return func(workspace, **args)
    except ToolError as exc:
        return f"Ошибка: {exc}"
    except TypeError as exc:
        return f"Ошибка аргументов '{name}': {exc}"
    except Exception as exc:  # noqa: BLE001
        return f"Непредвиденная ошибка '{name}': {exc}"


# --- Доставка результата и сохранение в git ---


def make_zip(workspace: str) -> str | None:
    """Упаковывает содержимое рабочей папки в zip. Возвращает путь к архиву
    или None, если папка пуста/не существует."""
    if not os.path.isdir(workspace) or not os.listdir(workspace):
        return None
    tmp_dir = tempfile.mkdtemp()
    base = os.path.join(tmp_dir, "site")
    archive = shutil.make_archive(base, "zip", root_dir=workspace)
    return archive


def _find_repo_root(start: str) -> str | None:
    """Идёт вверх от start в поисках папки с .git."""
    path = os.path.abspath(start)
    while True:
        if os.path.isdir(os.path.join(path, ".git")):
            return path
        parent = os.path.dirname(path)
        if parent == path:
            return None
        path = parent


def git_commit(workspace: str, message: str = "update from telegram agent") -> str:
    """Коммитит рабочую папку в git-репозиторий и пытается запушить.

    Папка агента может быть в .gitignore, поэтому используем add -f.
    """
    root = _find_repo_root(workspace)
    if root is None:
        return ("Ошибка: git-репозиторий не найден. Файлы сохранены только в "
                "рабочей папке.")
    if not os.path.isdir(workspace) or not os.listdir(workspace):
        return "Рабочая папка пуста — коммитить нечего."

    rel = os.path.relpath(workspace, root)

    def git(*args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["git", "-C", root, *args],
            capture_output=True,
            text=True,
            timeout=120,
        )

    git("add", "-f", rel)
    commit = git(
        "-c", "user.name=Telegram Agent",
        "-c", "user.email=agent@example.com",
        "-c", "commit.gpgsign=false",
        "commit", "-m", message,
    )
    out = (commit.stdout + commit.stderr).strip()
    if commit.returncode != 0 and "nothing to commit" in out:
        return "Нет изменений для коммита."
    if commit.returncode != 0:
        return f"Не удалось закоммитить:\n{out}"

    push = git("push")
    push_out = (push.stdout + push.stderr).strip()
    if push.returncode == 0:
        return f"✅ Закоммичено и отправлено в репозиторий.\n{out}"
    return (f"✅ Закоммичено локально (push не удался — возможно, нет доступа):\n"
            f"{out}\n\npush: {push_out}")
