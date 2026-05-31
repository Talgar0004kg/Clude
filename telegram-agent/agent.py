"""Ядро агента: цикл «Gemini → инструменты → результат» для одного чата."""
from typing import Iterator

from google import genai
from google.genai import types

import config
import tools

SYSTEM_PROMPT = """\
Ты — кодинг-агент в Телеграме, по духу похожий на Devin AI.
Помогаешь пользователю с задачами по программированию. У тебя есть инструменты
для работы с файлами и выполнения команд в персональной рабочей папке.

Действуй пошагово:
1. Исследуй (list_files, read_file).
2. Вноси изменения (write_file) небольшими шагами.
3. Проверяй результат командами/тестами (run_command).
4. При ошибках — анализируй вывод и исправляй.

Правила:
- Отвечай на языке пользователя (обычно по-русски), коротко и по делу — это чат.
- Не выдумывай содержимое файлов, сначала читай их.
- Используй относительные пути.
- Когда задача выполнена — напиши итог БЕЗ вызова инструментов (это значит «готово»).
"""


def _build_tools() -> list:
    s = types.Type.STRING
    obj = types.Type.OBJECT

    def sch(props, required):
        return types.Schema(type=obj, properties=props, required=required)

    return [
        types.Tool(
            function_declarations=[
                types.FunctionDeclaration(
                    name="list_files",
                    description="Список файлов и папок по пути (относительно рабочей папки).",
                    parameters=sch(
                        {"path": types.Schema(type=s, description="Путь, по умолчанию '.'")},
                        [],
                    ),
                ),
                types.FunctionDeclaration(
                    name="read_file",
                    description="Прочитать текстовый файл.",
                    parameters=sch(
                        {"path": types.Schema(type=s, description="Путь к файлу")},
                        ["path"],
                    ),
                ),
                types.FunctionDeclaration(
                    name="write_file",
                    description="Создать или перезаписать файл.",
                    parameters=sch(
                        {
                            "path": types.Schema(type=s, description="Путь к файлу"),
                            "content": types.Schema(type=s, description="Содержимое файла"),
                        },
                        ["path", "content"],
                    ),
                ),
                types.FunctionDeclaration(
                    name="run_command",
                    description="Выполнить shell-команду в рабочей папке.",
                    parameters=sch(
                        {"command": types.Schema(type=s, description="Команда")},
                        ["command"],
                    ),
                ),
            ]
        )
    ]


class Agent:
    """История диалога + цикл рассуждения для одного чата."""

    def __init__(self, workspace: str) -> None:
        if not config.GEMINI_API_KEY:
            raise RuntimeError("Не задан GEMINI_API_KEY в .env")
        self._client = genai.Client(api_key=config.GEMINI_API_KEY)
        self._tools = _build_tools()
        self._workspace = workspace
        self._contents: list = []

    def reset(self) -> None:
        self._contents = []

    def _config(self) -> types.GenerateContentConfig:
        return types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            tools=self._tools,
            temperature=0.2,
            automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
        )

    def run(self, task: str) -> Iterator[dict]:
        """Поток событий: assistant, tool_call, tool_result, done, error."""
        self._contents.append(types.Content(role="user", parts=[types.Part(text=task)]))

        for _ in range(config.MAX_STEPS):
            try:
                response = self._client.models.generate_content(
                    model=config.MODEL,
                    contents=self._contents,
                    config=self._config(),
                )
            except Exception as exc:  # noqa: BLE001
                yield {"type": "error", "message": f"Ошибка Gemini: {exc}"}
                return

            candidate = response.candidates[0] if response.candidates else None
            if candidate is None or candidate.content is None:
                yield {"type": "error", "message": "Пустой ответ модели."}
                return

            self._contents.append(candidate.content)
            parts = candidate.content.parts or []
            calls = [p.function_call for p in parts if p.function_call]
            texts = [p.text for p in parts if p.text]

            if texts:
                yield {"type": "assistant", "message": "\n".join(texts)}

            if not calls:
                yield {"type": "done"}
                return

            response_parts = []
            for call in calls:
                args = dict(call.args or {})
                yield {"type": "tool_call", "name": call.name, "args": args}
                result = tools.execute(call.name, args, self._workspace)
                yield {"type": "tool_result", "name": call.name, "result": result}
                response_parts.append(
                    types.Part.from_function_response(
                        name=call.name, response={"result": result}
                    )
                )
            self._contents.append(types.Content(role="user", parts=response_parts))

        yield {
            "type": "error",
            "message": f"Достигнут лимит шагов ({config.MAX_STEPS}).",
        }
