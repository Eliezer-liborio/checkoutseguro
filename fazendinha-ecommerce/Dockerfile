FROM python:3.12-slim

LABEL description="Fazendinha E-commerce — Laboratório CheckoutSeguro"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN groupadd -r fazendinha && \
    useradd -r -g fazendinha -d /app -s /sbin/nologin fazendinha

RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
        "fastapi>=0.110.0" \
        "uvicorn[standard]>=0.29.0" \
        "eth-account>=0.11.0"

COPY . .

RUN mkdir -p /data && chown -R fazendinha:fazendinha /app /data

USER fazendinha

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -fs http://localhost:8000/api/products || exit 1

ENTRYPOINT ["uvicorn", "app:app", \
    "--host", "0.0.0.0", \
    "--port", "8000", \
    "--log-level", "info", \
    "--no-access-log"]
