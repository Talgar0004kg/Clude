"""Слой LLM: локальная модель через Ollama (http://localhost:11434).

Клиент принимает нормализованную историю сообщений и возвращает кортеж
(текст_ответа, список_вызовов_инструментов).

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
    """Локальная модель через Ollama (/api/chat, с поддержкой инструментов)."""

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


def make_client(system: str, tool_specs: list) -> OllamaClient:
    """Создаёт локального клиента Ollama по настройкам из config."""
    return OllamaClient(config.OLLAMA_HOST, config.OLLAMA_MODEL, system, tool_specs)
