FROM python:3.12-slim

WORKDIR /app

# Устанавливаем зависимости отдельным слоем (кэш при изменении кода)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Код агента (бот + ядро агента + инструменты + конфиг)
COPY bot.py agent.py tools.py config.py ./

# .env монтируется снаружи, не копируем
CMD ["python", "bot.py"]
