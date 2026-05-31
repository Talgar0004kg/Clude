"""Слой LLM: единый интерфейс для разных бэкендов (Ollama, Gemini).

Каждый клиент принимает нормализованную историю сообщений и возвращает
кортеж (текст_ответа, список_вызовов_инструментов).

Нормализованное сообщение — это dict одного из видов:
  {"role": "user", "content": str, "images": [bytes]}
  {"role": "assistant", "content": str, "tool_calls": [{"name", "args"}]}
  {"role": "tool", "name": str, "content": str}

Вызов инструмента: {"name": str, "args": dict}.
"""
import base64
import json
import urllib.error
import urllib.request

import config


class LLMError(Exception):
    """Ошибка обращения к LLM (показывается пользователю)."""


# --- Ollama (локальный сервер) ---


def _to_ollama(messages: list, system: str) -> list:
    out = [{"role": "system", "content": system}]
    for m in messages:
        role = m["role"]
        if role == "user":
            d = {"role": "user", "content": m.get("content", "")}
            if m.get("images"):
                d["images"] = [base64.b64encode(i).decode() for i in m["images"]]
            out.append(d)
        elif role == "assistant":
            d = {"role": "assistant", "content": m.get("content", "") or ""}
            if m.get("tool_calls"):
                d["tool_calls"] = [
                    {"function": {"name": tc["name"], "arguments": tc.get("args", {})}}
                    for tc in m["tool_calls"]
                ]
            out.append(d)
        elif role == "tool":
            out.append({"role": "tool", "content": m.get("content", "")})
    return out


class OllamaClient:
    """Локальная модель через Ollama (http://localhost:11434, /api/chat)."""

    def __init__(self, host: str, model: str, system: str, tool_specs: list) -> None:
        self._url = host.rstrip("/") + "/api/chat"
        self._model = model
        self._system = system
        self._tools = [
            {
                "type": "function",
                "function": {
                    "name": s["name"],
                    "description": s["description"],
                    "parameters": s["parameters"],
                },
            }
            for s in tool_specs
        ]

    def generate(self, messages: list) -> tuple[str, list]:
        payload = {
            "model": self._model,
            "messages": _to_ollama(messages, self._system),
            "tools": self._tools,
            "stream": False,
            "options": {"temperature": 0.2},
        }
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            self._url, data=data, headers={"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(req, timeout=600) as resp:  # noqa: S310
                body = json.loads(resp.read().decode("utf-8"))
        except urllib.error.URLError as exc:
            raise LLMError(
                "Не удалось подключиться к Ollama (" + self._url + "). "
                "Запустите 'ollama serve' в соседней вкладке Codespaces и "
                f"скачайте модель: 'ollama pull {self._model}'. ({exc})"
            )
        except Exception as exc:  # noqa: BLE001
            raise LLMError(f"Ошибка Ollama: {exc}")

        msg = body.get("message", {}) or {}
        text = msg.get("content", "") or ""
        calls = []
        for tc in msg.get("tool_calls", []) or []:
            fn = tc.get("function", {}) or {}
            args = fn.get("arguments", {})
            if isinstance(args, str):
                try:
                    args = json.loads(args)
                except json.JSONDecodeError:
                    args = {}
            calls.append({"name": fn.get("name", ""), "args": args or {}})
        return text, calls


# --- Gemini (облачное API, опционально) ---


def _gem_schema(d: dict):
    from google.genai import types

    t = d.get("type", "string")
    if t == "object":
        props = {k: _gem_schema(v) for k, v in d.get("properties", {}).items()}
        return types.Schema(
            type=types.Type.OBJECT,
            properties=props or None,
            required=d.get("required") or None,
        )
    return types.Schema(type=types.Type.STRING, description=d.get("description"))


def _to_gemini(messages: list) -> list:
    from google.genai import types

    out = []
    for m in messages:
        role = m["role"]
        if role == "user":
            parts = []
            if m.get("content"):
                parts.append(types.Part(text=m["content"]))
            for img in m.get("images") or []:
                parts.append(types.Part.from_bytes(data=img, mime_type="image/jpeg"))
            out.append(types.Content(role="user", parts=parts or [types.Part(text="")]))
        elif role == "assistant":
            parts = []
            if m.get("content"):
                parts.append(types.Part(text=m["content"]))
            for tc in m.get("tool_calls") or []:
                parts.append(
                    types.Part(
                        function_call=types.FunctionCall(name=tc["name"], args=tc.get("args", {}))
                    )
                )
            out.append(types.Content(role="model", parts=parts or [types.Part(text="")]))
        elif role == "tool":
            out.append(
                types.Content(
                    role="user",
                    parts=[
                        types.Part.from_function_response(
                            name=m["name"], response={"result": m.get("content", "")}
                        )
                    ],
                )
            )
    return out


class GeminiClient:
    """Облачная модель Google Gemini (через google-genai)."""

    def __init__(self, api_key: str, model: str, system: str, tool_specs: list) -> None:
        from google import genai
        from google.genai import types

        self._client = genai.Client(api_key=api_key)
        self._model = model
        self._system = system
        decls = [
            types.FunctionDeclaration(
                name=s["name"],
                description=s["description"],
                parameters=_gem_schema(s["parameters"]),
            )
            for s in tool_specs
        ]
        self._tools = [types.Tool(function_declarations=decls)]

    def generate(self, messages: list) -> tuple[str, list]:
        from google.genai import types

        try:
            resp = self._client.models.generate_content(
                model=self._model,
                contents=_to_gemini(messages),
                config=types.GenerateContentConfig(
                    system_instruction=self._system,
                    tools=self._tools,
                    temperature=0.2,
                    automatic_function_calling=types.AutomaticFunctionCallingConfig(
                        disable=True
                    ),
                ),
            )
        except Exception as exc:  # noqa: BLE001
            raise LLMError(f"Ошибка Gemini: {exc}")

        cand = resp.candidates[0] if resp.candidates else None
        if cand is None or cand.content is None:
            return "", []
        parts = cand.content.parts or []
        text = "\n".join(p.text for p in parts if p.text)
        calls = [
            {"name": p.function_call.name, "args": dict(p.function_call.args or {})}
            for p in parts
            if p.function_call
        ]
        return text, calls


def make_client(system: str, tool_specs: list):
    """Создаёт клиента LLM согласно config.PROVIDER."""
    provider = config.PROVIDER
    if provider == "ollama":
        return OllamaClient(config.OLLAMA_HOST, config.OLLAMA_MODEL, system, tool_specs)
    if provider == "gemini":
        if not config.GEMINI_API_KEY:
            raise LLMError("AGENT_PROVIDER=gemini, но не задан GEMINI_API_KEY в .env")
        return GeminiClient(config.GEMINI_API_KEY, config.MODEL, system, tool_specs)
    raise LLMError(f"Неизвестный AGENT_PROVIDER: '{provider}' (ожидается ollama|gemini)")
