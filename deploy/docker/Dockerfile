# =============================================================================
#  CheckoutSeguro — Dockerfile
#  Uso: docker build -t checkoutseguro:latest -f deploy/docker/Dockerfile .
#  NOTA: O modo Docker é recomendado apenas para o servidor de verificação
#        das lojas parceiras (fazendinha-ecommerce), NÃO para o app local
#        do usuário (que deve rodar no hardware para garantir self-custody).
# =============================================================================

FROM python:3.12-slim AS base

# Metadados
LABEL maintainer="CheckoutSeguro <https://github.com/Eliezer-liborio/checkoutseguro>"
LABEL description="CheckoutSeguro — App de Assinatura Criptográfica para E-commerce"
LABEL version="1.0.0"

# Variáveis de ambiente
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    CHECKOUTSEGURO_ENV=production \
    CHECKOUTSEGURO_PORT=7432 \
    CHECKOUTSEGURO_LOG_LEVEL=info

# Usuário não-root para segurança
RUN groupadd -r checkoutseguro && \
    useradd -r -g checkoutseguro -d /app -s /sbin/nologin checkoutseguro

# Dependências do sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instala dependências Python (camada separada para cache)
COPY app/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
        "fastapi>=0.110.0" \
        "uvicorn[standard]>=0.29.0" \
        "eth-account>=0.11.0" \
        "bcrypt>=4.1.0" \
        "cryptography>=42.0.0" \
        "python-multipart>=0.0.9"

# Copia o código da aplicação
COPY app/ .

# Cria diretórios de dados com permissões corretas
RUN mkdir -p /data/wallet /data/certs /data/logs && \
    chown -R checkoutseguro:checkoutseguro /app /data

# Gera certificado autoassinado para HTTPS local
RUN openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout /data/certs/key.pem \
    -out /data/certs/cert.pem \
    -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" && \
    chmod 600 /data/certs/key.pem && \
    chown checkoutseguro:checkoutseguro /data/certs/*

USER checkoutseguro

EXPOSE 7432

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -fsk https://localhost:7432/status || exit 1

# Entrypoint
ENTRYPOINT ["uvicorn", "main:app", \
    "--host", "0.0.0.0", \
    "--port", "7432", \
    "--ssl-certfile", "/data/certs/cert.pem", \
    "--ssl-keyfile", "/data/certs/key.pem", \
    "--log-level", "info", \
    "--no-access-log"]
