"""Ядро агента: цикл «LLM → инструменты → результат» для одного чата.

LLM — локальная модель через Ollama. Агент хранит нормализованную историю
сообщений и не зависит от конкретного бэкенда.
"""
import glob
import os
from typing import Iterator

import config
import tools
from llm import LLMError, make_client
from tool_specs import TOOL_SPECS


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


class Agent:
    """История диалога + цикл рассуждения для одного чата."""

    def __init__(self, workspace: str) -> None:
        self._workspace = workspace
        self._messages: list = []
        self._system = SYSTEM_PROMPT + _load_skills()
        # Может бросить LLMError, если провайдер настроен неверно.
        self._client = make_client(self._system, TOOL_SPECS)

    def reset(self) -> None:
        self._messages = []

    def rebuild_client(self) -> None:
        """Пересоздаёт LLM-клиента по текущим настройкам (после смены модели)."""
        self._client = make_client(self._system, TOOL_SPECS)

    def run(self, task: str, images: list[bytes] | None = None) -> Iterator[dict]:
        """Поток событий: assistant, tool_call, tool_result, send_zip, send_file,
        done, error.

        images — список изображений (например, дизайн сайта) в байтах.
        """
        self._messages.append(
            {"role": "user", "content": task, "images": images or []}
        )

        for _ in range(config.MAX_STEPS):
            try:
                text, calls = self._client.generate(self._messages)
            except LLMError as exc:
                yield {"type": "error", "message": str(exc)}
                return
            except Exception as exc:  # noqa: BLE001
                yield {"type": "error", "message": f"Ошибка LLM: {exc}"}
                return

            self._messages.append(
                {"role": "assistant", "content": text, "tool_calls": calls}
            )

            if text:
                yield {"type": "assistant", "message": text}

            if not calls:
                yield {"type": "done"}
                return

            for call in calls:
                name = call.get("name", "")
                args = call.get("args") or {}
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
                        self._workspace,
                        args.get("message") or "update from telegram agent",
                    )
                    yield {"type": "tool_result", "name": name, "result": result}
                else:
                    result = tools.execute(name, args, self._workspace)
                    yield {"type": "tool_result", "name": name, "result": result}

                self._messages.append(
                    {"role": "tool", "name": name, "content": result}
                )

        yield {
            "type": "error",
            "message": f"Достигнут лимит шагов ({config.MAX_STEPS}).",
        }
