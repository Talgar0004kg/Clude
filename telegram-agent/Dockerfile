FROM python:3.12-slim

WORKDIR /app

# Устанавливаем зависимости отдельным слоем (кэш при изменении кода)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Код агента
COPY bot.py agent.py llm.py tool_specs.py tools.py config.py ./
COPY skills ./skills

# .env монтируется снаружи, не копируем
CMD ["python", "bot.py"]
