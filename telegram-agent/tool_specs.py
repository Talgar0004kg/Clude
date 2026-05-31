"""Нейтральные описания инструментов агента.

Один формат (JSON-schema-подобный) для инструментов Ollama. Так инструменты
описываются один раз.
"""


def _s(description: str) -> dict:
    return {"type": "string", "description": description}


def _obj(properties: dict, required: list) -> dict:
    return {"type": "object", "properties": properties, "required": required}


TOOL_SPECS = [
    {
        "name": "list_files",
        "description": "Список файлов и папок по пути (относительно рабочей папки).",
        "parameters": _obj({"path": _s("Путь, по умолчанию '.'")}, []),
    },
    {
        "name": "read_file",
        "description": "Прочитать текстовый файл.",
        "parameters": _obj({"path": _s("Путь к файлу")}, ["path"]),
    },
    {
        "name": "write_file",
        "description": "Создать или перезаписать файл.",
        "parameters": _obj(
            {"path": _s("Путь к файлу"), "content": _s("Содержимое файла")},
            ["path", "content"],
        ),
    },
    {
        "name": "run_command",
        "description": "Выполнить shell-команду в рабочей папке.",
        "parameters": _obj({"command": _s("Команда")}, ["command"]),
    },
    {
        "name": "fetch_url",
        "description": "Зайти на сайт по URL и получить его HTML/текст для анализа.",
        "parameters": _obj({"url": _s("Адрес сайта")}, ["url"]),
    },
    {
        "name": "download_site",
        "description": "Скачать страницу сайта и её ресурсы (css/js/картинки) в "
        "рабочую папку — потом можно отправить архивом.",
        "parameters": _obj(
            {"url": _s("Адрес сайта"), "dest": _s("Папка назначения, по умолчанию 'site'")},
            ["url"],
        ),
    },
    {
        "name": "web_search",
        "description": "Найти что-либо в интернете (фото, книгу, приложение, файл, "
        "информацию). Возвращает список ссылок.",
        "parameters": _obj({"query": _s("Поисковый запрос")}, ["query"]),
    },
    {
        "name": "download_file",
        "description": "Скачать файл по прямой ссылке (любого типа: jpg, png, pdf, "
        "mp3, apk, zip и т.д.) в рабочую папку.",
        "parameters": _obj(
            {"url": _s("Прямая ссылка на файл"), "filename": _s("Имя файла (необязательно)")},
            ["url"],
        ),
    },
    {
        "name": "send_file",
        "description": "Отправить пользователю в чат конкретный файл из рабочей папки "
        "(любого типа, не только zip), сохраняя расширение.",
        "parameters": _obj({"path": _s("Путь к файлу")}, ["path"]),
    },
    {
        "name": "send_files",
        "description": "Упаковать рабочую папку в zip и отправить её пользователю в "
        "чат. Вызывай, когда просят прислать/скачать файлы, готовый сайт или архив.",
        "parameters": _obj({}, []),
    },
    {
        "name": "git_commit",
        "description": "Закоммитить рабочую папку с кодом в git-репозиторий (и "
        "отправить на GitHub). Вызывай, когда просят сохранить или закоммитить.",
        "parameters": _obj({"message": _s("Сообщение коммита")}, []),
    },
]
