FROM python:3.11-slim
ENV PYTHONUNBUFFERED=1 HOST=0.0.0.0 PORT=5101
WORKDIR /worker
RUN apt-get update && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 libgomp1 && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY fetch_models.py ./
RUN python fetch_models.py
COPY checks.py engine.py app.py ./
RUN python -c "from engine import Engine; Engine()"
RUN useradd --uid 10001 --create-home identity
USER identity
EXPOSE 5101
CMD ["python", "app.py"]
