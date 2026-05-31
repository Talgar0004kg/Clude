"""Настройки телеграм-агента из переменных окружения / .env."""
import os

from dotenv import load_dotenv

load_dotenv()

# Telegram
TELEGRAM_BOT_TOKEN: str = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()


def _parse_ids(raw: str) -> set[int]:
    ids: set[int] = set()
    for part in raw.split(","):
        part = part.strip()
        if part.lstrip("-").isdigit():
            ids.add(int(part))
    return ids


# Разрешённые пользователи (пустой набор = разрешено всем).
ALLOWED_USER_IDS: set[int] = _parse_ids(os.getenv("ALLOWED_USER_IDS", ""))

# Gemini
GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "").strip()
MODEL: str = os.getenv("AGENT_MODEL", "gemini-2.5-flash").strip()

# Агент
_default_workspace = os.path.join(os.path.dirname(__file__), "workspace")
WORKSPACE_BASE: str = os.path.abspath(os.getenv("AGENT_WORKSPACE", _default_workspace))
COMMAND_TIMEOUT: int = int(os.getenv("AGENT_COMMAND_TIMEOUT", "120"))
MAX_STEPS: int = int(os.getenv("AGENT_MAX_STEPS", "25"))
MAX_TOOL_OUTPUT: int = int(os.getenv("AGENT_MAX_TOOL_OUTPUT", "8000"))

# Максимальный размер скачиваемого файла (Telegram отдаёт документы до ~50 МБ).
MAX_DOWNLOAD_BYTES: int = int(os.getenv("AGENT_MAX_DOWNLOAD_MB", "45")) * 1024 * 1024


def workspace_for(chat_id: int) -> str:
    """Возвращает (и создаёт) изолированную рабочую папку для чата."""
    path = os.path.join(WORKSPACE_BASE, str(chat_id))
    os.makedirs(path, exist_ok=True)
    return path


def is_allowed(user_id: int) -> bool:
    return not ALLOWED_USER_IDS or user_id in ALLOWED_USER_IDS
