"""Ядро агента: цикл «локальная LLM (Ollama) → инструменты → результат».

Модель развёрнута локально через Ollama и отвечает на HTTP-запросы по адресу
config.OLLAMA_URL (по умолчанию http://localhost:11434/api/generate). Так как
endpoint /api/generate не поддерживает нативный function-calling, агент использует
текстовый протокол вызова инструментов: модель присылает JSON вида
{"tool": "имя", "args": {...}}, либо обычный текст — это значит «готово».
"""
import glob
import json
import os
import re
import urllib.error
import urllib.request
from typing import Iterator

import config
import tools


def _load_skills() -> str:
    """Подмешивает в системный промпт все скиллы из папки skills/*.md
    (кроме служебного README). Так качество работы повышается без правки кода."""
    base = os.path.join(os.path.dirname(__file__), "skills")
    if not os.path.isdir(base):
        return ""
    parts: list[str] = []
    for path in sorted(glob.glob(os.path.join(base, "*.md"))):
        if os.path.basename(path).lower() == "readme.md":
            continue
        try:
            with open(path, "r", encoding="utf-8") as f:
                parts.append(f.read().strip())
        except OSError:
            continue
    if not parts:
        return ""
    return "\n\n# ПОДКЛЮЧЁННЫЕ СКИЛЛЫ\n\n" + "\n\n---\n\n".join(parts)


SYSTEM_PROMPT = """\
Ты — кодинг-агент в Телеграме, по духу похожий на Devin AI.
Помогаешь пользователю с задачами по программированию. У тебя есть инструменты
для работы с файлами и выполнения команд в персональной рабочей папке.

Действуй пошагово:
1. Исследуй (list_files, read_file).
2. Вноси изменения (write_file) небольшими шагами.
3. Проверяй результат командами/тестами (run_command).
4. При ошибках — анализируй вывод и исправляй.

Дополнительные действия:
- Если пользователь просит прислать/скачать файлы, готовый сайт, архив или zip —
  вызови инструмент send_files (он отправит zip с рабочей папкой прямо в чат).
- Если пользователь просит сохранить/закоммитить код в репозиторий — вызови
  git_commit с осмысленным сообщением коммита.
- Если пользователь прислал изображение (дизайн/скриншот сайта) — свёрстай сайт
  «один в один»: максимально точно повтори структуру, расположение блоков, цвета,
  шрифты и тексты с картинки, используя HTML/CSS (и JS при необходимости).
- Чтобы зайти на сайт и проанализировать его — используй fetch_url. Чтобы скачать
  сайт (страницу с ресурсами) для последующей отправки — используй download_site,
  затем при просьбе вызови send_files.
- Если пользователь просит НАЙТИ что-то (фото, книгу, приложение, файл, песню) —
  сначала web_search, при необходимости открой страницу через fetch_url, чтобы
  найти прямую ссылку на файл, затем download_file, и в конце send_file, чтобы
  отправить пользователю настоящий файл (с правильным расширением).

Правила:
- Отвечай на языке пользователя (обычно по-русски), коротко и по делу — это чат.
- Не выдумывай содержимое файлов, сначала читай их.
- Используй относительные пути.
- Когда задача выполнена — напиши итог БЕЗ вызова инструментов (это значит «готово»).
"""

# Описание инструментов для текстового протокола (имя → описание + параметры).
TOOLS_SPEC: list[dict] = [
    {
        "name": "list_files",
        "description": "Список файлов и папок по пути (относительно рабочей папки).",
        "args": {"path": "Путь, по умолчанию '.' (необязательно)"},
    },
    {
        "name": "read_file",
        "description": "Прочитать текстовый файл.",
        "args": {"path": "Путь к файлу (обязательно)"},
    },
    {
        "name": "write_file",
        "description": "Создать или перезаписать файл.",
        "args": {
            "path": "Путь к файлу (обязательно)",
            "content": "Содержимое файла (обязательно)",
        },
    },
    {
        "name": "run_command",
        "description": "Выполнить shell-команду в рабочей папке.",
        "args": {"command": "Команда (обязательно)"},
    },
    {
        "name": "fetch_url",
        "description": "Зайти на сайт по URL и получить его HTML/текст для анализа.",
        "args": {"url": "Адрес сайта (обязательно)"},
    },
    {
        "name": "download_site",
        "description": "Скачать страницу сайта и её ресурсы (css/js/картинки) в "
        "рабочую папку — потом можно отправить архивом.",
        "args": {
            "url": "Адрес сайта (обязательно)",
            "dest": "Папка назначения, по умолчанию 'site' (необязательно)",
        },
    },
    {
        "name": "web_search",
        "description": "Найти что-либо в интернете (фото, книгу, приложение, файл, "
        "информацию). Возвращает список ссылок.",
        "args": {"query": "Поисковый запрос (обязательно)"},
    },
    {
        "name": "download_file",
        "description": "Скачать файл по прямой ссылке (любого типа: jpg, png, pdf, "
        "mp3, apk, zip и т.д.) в рабочую папку.",
        "args": {
            "url": "Прямая ссылка на файл (обязательно)",
            "filename": "Имя файла (необязательно)",
        },
    },
    {
        "name": "send_file",
        "description": "Отправить пользователю в чат конкретный файл из рабочей "
        "папки (любого типа, не только zip), сохраняя расширение.",
        "args": {"path": "Путь к файлу (обязательно)"},
    },
    {
        "name": "send_files",
        "description": "Упаковать рабочую папку в zip и отправить её пользователю в "
        "чат. Вызывай, когда просят прислать/скачать файлы, готовый сайт или архив.",
        "args": {},
    },
    {
        "name": "git_commit",
        "description": "Закоммитить рабочую папку с кодом в git-репозиторий (и "
        "отправить на GitHub). Вызывай, когда просят сохранить или закоммитить "
        "результат.",
        "args": {"message": "Сообщение коммита (необязательно)"},
    },
]


def _tools_doc() -> str:
    lines: list[str] = []
    for spec in TOOLS_SPEC:
        if spec["args"]:
            args = ", ".join(f"{k} — {v}" for k, v in spec["args"].items())
        else:
            args = "без аргументов"
        lines.append(f"- {spec['name']}: {spec['description']} Аргументы: {args}.")
    return "\n".join(lines)


TOOL_PROTOCOL = """\

# ДОСТУПНЫЕ ИНСТРУМЕНТЫ
{tools}

# КАК ВЫЗЫВАТЬ ИНСТРУМЕНТЫ
Когда нужно выполнить действие, ответь ТОЛЬКО одним JSON-объектом (без markdown,
без пояснений до или после) строго в формате:
{{"tool": "имя_инструмента", "args": {{"параметр": "значение"}}}}

Можно вызывать только один инструмент за раз. После каждого вызова ты получишь
результат и сможешь вызвать следующий инструмент.

Когда задача полностью выполнена — ответь обычным текстом (итог для пользователя)
БЕЗ JSON. Это означает «готово».
"""


class Agent:
    """История диалога + цикл рассуждения для одного чата."""

    def __init__(self, workspace: str) -> None:
        self._workspace = workspace
        self._history: list[dict] = []
        self._system = (
            SYSTEM_PROMPT
            + _load_skills()
            + TOOL_PROTOCOL.format(tools=_tools_doc())
        )

    def reset(self) -> None:
        self._history = []

    def _build_prompt(self) -> str:
        """Собирает единый текстовый промпт: система + история диалога."""
        parts = [self._system, "\n# ДИАЛОГ"]
        for item in self._history:
            role = item["role"]
            content = item["content"]
            if role == "user":
                parts.append(f"Пользователь: {content}")
            elif role == "assistant":
                parts.append(f"Ассистент: {content}")
            elif role == "tool":
                parts.append(f"Результат инструмента {item['name']}:\n{content}")
        parts.append("Ассистент:")
        return "\n\n".join(parts)

    def _generate(self) -> str:
        """Отправляет запрос локальной LLM (Ollama) и возвращает текст ответа.

        Бросает ConnectionError, если до сервера Ollama не достучаться.
        """
        payload = json.dumps(
            {
                "model": config.MODEL,
                "prompt": self._build_prompt(),
                "stream": False,
            }
        ).encode("utf-8")
        req = urllib.request.Request(
            config.OLLAMA_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=config.OLLAMA_TIMEOUT) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except urllib.error.URLError as exc:
            # ConnectionRefused и подобное приходит внутри URLError.reason
            raise ConnectionError(str(getattr(exc, "reason", exc))) from exc
        return (data.get("response") or "").strip()

    @staticmethod
    def _parse_tool_call(text: str) -> dict | None:
        """Ищет в ответе JSON-вызов инструмента {"tool": ..., "args": {...}}.

        Возвращает {"name": ..., "args": {...}} или None, если это обычный текст.
        """
        candidate = text.strip()
        # Снимаем возможные markdown-ограждения ```json ... ```
        fence = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", candidate, re.DOTALL)
        if fence:
            candidate = fence.group(1)
        else:
            start = candidate.find("{")
            end = candidate.rfind("}")
            if start == -1 or end <= start:
                return None
            candidate = candidate[start : end + 1]
        try:
            obj = json.loads(candidate)
        except (ValueError, TypeError):
            return None
        if not isinstance(obj, dict) or "tool" not in obj:
            return None
        name = obj.get("tool")
        args = obj.get("args") or {}
        if not isinstance(name, str) or not isinstance(args, dict):
            return None
        return {"name": name, "args": args}

    def run(self, task: str, images: list[bytes] | None = None) -> Iterator[dict]:
        """Поток событий: assistant, tool_call, tool_result, done, error.

        images — список изображений в байтах. Локальная модель llama3.2:3b
        текстовая и не умеет «видеть» картинки, поэтому при их наличии добавляем
        пометку в задачу, а сами байты не передаём.
        """
        if images:
            task = (
                f"{task}\n\n(Пользователь приложил {len(images)} изображение(й), но "
                "локальная текстовая модель не может их анализировать. Действуй по "
                "текстовому описанию задачи.)"
            )
        self._history.append({"role": "user", "content": task})

        for _ in range(config.MAX_STEPS):
            try:
                reply = self._generate()
            except ConnectionError as exc:
                yield {
                    "type": "error",
                    "message": (
                        f"Не удалось подключиться к локальной LLM ({config.OLLAMA_URL}): "
                        f"{exc}.\nЗапустите 'ollama serve' в соседней вкладке Codespaces "
                        f"и убедитесь, что модель загружена: 'ollama pull {config.MODEL}'."
                    ),
                }
                return
            except Exception as exc:  # noqa: BLE001
                yield {"type": "error", "message": f"Ошибка локальной LLM: {exc}"}
                return

            if not reply:
                yield {"type": "error", "message": "Пустой ответ модели."}
                return

            call = self._parse_tool_call(reply)
            if call is None:
                self._history.append({"role": "assistant", "content": reply})
                yield {"type": "assistant", "message": reply}
                yield {"type": "done"}
                return

            # Сохраняем исходный JSON-вызов в историю, чтобы модель видела контекст.
            self._history.append({"role": "assistant", "content": reply})

            name = call["name"]
            args = call["args"]
            yield {"type": "tool_call", "name": name, "args": args}

            if name == "send_files":
                yield {"type": "send_zip"}
                result = "Архив с файлами отправлен пользователю в чат."
            elif name == "send_file":
                path = args.get("path", "")
                yield {"type": "send_file", "path": path}
                result = f"Файл '{path}' отправлен пользователю в чат."
            elif name == "git_commit":
                result = tools.git_commit(
                    self._workspace, args.get("message") or "update from telegram agent"
                )
                yield {"type": "tool_result", "name": name, "result": result}
            else:
                result = tools.execute(name, args, self._workspace)
                yield {"type": "tool_result", "name": name, "result": result}

            self._history.append({"role": "tool", "name": name, "content": result})

        yield {
            "type": "error",
            "message": f"Достигнут лимит шагов ({config.MAX_STEPS}).",
        }
