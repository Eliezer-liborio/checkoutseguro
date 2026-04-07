#!/usr/bin/env bash
# =============================================================================
#  CheckoutSeguro — Script de Instalação Unificado
#  Suporta: Linux (Ubuntu/Debian/Fedora/Arch) e macOS (12+)
#  Uso:
#    curl -fsSL https://raw.githubusercontent.com/Eliezer-liborio/checkoutseguro/main/deploy/install.sh | bash
#  Ou localmente:
#    chmod +x deploy/install.sh && ./deploy/install.sh
# =============================================================================

set -euo pipefail

# ── Cores e helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERRO]${RESET}  $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${BLUE}▶ $*${RESET}"; }

# ── Banner ───────────────────────────────────────────────────────────────────
echo -e "${BOLD}${GREEN}"
cat << 'EOF'
  ██████╗██╗  ██╗███████╗ ██████╗██╗  ██╗ ██████╗ ██╗   ██╗████████╗
 ██╔════╝██║  ██║██╔════╝██╔════╝██║ ██╔╝██╔═══██╗██║   ██║╚══██╔══╝
 ██║     ███████║█████╗  ██║     █████╔╝ ██║   ██║██║   ██║   ██║
 ██║     ██╔══██║██╔══╝  ██║     ██╔═██╗ ██║   ██║██║   ██║   ██║
 ╚██████╗██║  ██║███████╗╚██████╗██║  ██╗╚██████╔╝╚██████╔╝   ██║
  ╚═════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝    ╚═╝
                    S E G U R O   —   I n s t a l a d o r
EOF
echo -e "${RESET}"

# ── Detecção de SO ───────────────────────────────────────────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"
info "Sistema detectado: ${OS} / ${ARCH}"

if [[ "$OS" == "Darwin" ]]; then
    PLATFORM="macos"
elif [[ "$OS" == "Linux" ]]; then
    PLATFORM="linux"
else
    error "Sistema operacional não suportado: $OS. Use o instalador Windows (.ps1)."
fi

# ── Variáveis de instalação ──────────────────────────────────────────────────
INSTALL_DIR="${HOME}/.checkoutseguro"
VENV_DIR="${INSTALL_DIR}/venv"
APP_DIR="${INSTALL_DIR}/app"
CERTS_DIR="${INSTALL_DIR}/certs"
WALLET_DIR="${INSTALL_DIR}/wallet"
LOG_DIR="${INSTALL_DIR}/logs"
PORT="${CHECKOUTSEGURO_PORT:-7432}"
REPO_URL="https://github.com/Eliezer-liborio/checkoutseguro"
VERSION="1.0.0"

# ── Verificação de dependências ──────────────────────────────────────────────
step "Verificando dependências"

check_cmd() {
    if command -v "$1" &>/dev/null; then
        success "$1 encontrado: $(command -v "$1")"
        return 0
    else
        return 1
    fi
}

# Python 3.9+
if check_cmd python3; then
    PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
    if [[ "$PY_MAJOR" -lt 3 ]] || [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 9 ]]; then
        error "Python 3.9+ é necessário. Versão atual: ${PY_VERSION}"
    fi
    success "Python ${PY_VERSION} compatível"
    PYTHON_CMD="python3"
else
    error "Python 3 não encontrado. Instale em https://python.org/downloads"
fi

# pip
if ! check_cmd pip3 && ! python3 -m pip --version &>/dev/null; then
    error "pip não encontrado. Execute: python3 -m ensurepip --upgrade"
fi

# git (opcional, para atualizações)
if check_cmd git; then
    HAS_GIT=true
else
    warn "git não encontrado. Atualizações automáticas desabilitadas."
    HAS_GIT=false
fi

# openssl (para certificado HTTPS local)
if check_cmd openssl; then
    HAS_OPENSSL=true
else
    warn "openssl não encontrado. HTTPS local será desabilitado."
    HAS_OPENSSL=false
fi

# ── Criação de diretórios ────────────────────────────────────────────────────
step "Criando estrutura de diretórios em ${INSTALL_DIR}"
mkdir -p "${APP_DIR}" "${CERTS_DIR}" "${WALLET_DIR}" "${LOG_DIR}"
success "Diretórios criados"

# ── Download / cópia dos arquivos da aplicação ───────────────────────────────
step "Instalando arquivos da aplicação"

# Detecta se está rodando a partir do repositório clonado
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "${REPO_ROOT}/app/main.py" ]]; then
    info "Repositório local detectado. Copiando arquivos..."
    cp -r "${REPO_ROOT}/app/"* "${APP_DIR}/"
    success "Arquivos copiados de ${REPO_ROOT}/app/"
elif [[ "$HAS_GIT" == true ]]; then
    info "Clonando repositório de ${REPO_URL}..."
    TEMP_DIR=$(mktemp -d)
    git clone --depth=1 "${REPO_URL}" "${TEMP_DIR}/checkoutseguro"
    cp -r "${TEMP_DIR}/checkoutseguro/app/"* "${APP_DIR}/"
    rm -rf "${TEMP_DIR}"
    success "Repositório clonado com sucesso"
else
    error "Não foi possível obter os arquivos. Clone o repositório e execute o script novamente."
fi

# ── Ambiente virtual Python ──────────────────────────────────────────────────
step "Criando ambiente virtual Python isolado"
"${PYTHON_CMD}" -m venv "${VENV_DIR}"
source "${VENV_DIR}/bin/activate"
pip install --upgrade pip --quiet
success "Ambiente virtual criado em ${VENV_DIR}"

step "Instalando dependências Python"
pip install --quiet \
    "fastapi>=0.110.0" \
    "uvicorn[standard]>=0.29.0" \
    "eth-account>=0.11.0" \
    "bcrypt>=4.1.0" \
    "cryptography>=42.0.0" \
    "python-multipart>=0.0.9"
success "Dependências instaladas"

# ── Geração de certificado HTTPS local ──────────────────────────────────────
if [[ "$HAS_OPENSSL" == true ]]; then
    step "Gerando certificado TLS autoassinado para HTTPS local"
    CERT_FILE="${CERTS_DIR}/cert.pem"
    KEY_FILE="${CERTS_DIR}/key.pem"
    if [[ ! -f "$CERT_FILE" ]]; then
        openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
            -keyout "${KEY_FILE}" \
            -out "${CERT_FILE}" \
            -subj "/CN=localhost" \
            -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
            2>/dev/null
        chmod 600 "${KEY_FILE}"
        success "Certificado gerado: ${CERT_FILE}"
    else
        info "Certificado já existe, pulando geração"
    fi
    USE_HTTPS=true
else
    USE_HTTPS=false
    warn "HTTPS local desabilitado (openssl não encontrado)"
fi

# ── Arquivo de configuração .env ─────────────────────────────────────────────
step "Configurando variáveis de ambiente"
ENV_FILE="${INSTALL_DIR}/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    cat > "${ENV_FILE}" << EOF
# CheckoutSeguro — Configuração de Produção
# Gerado automaticamente em $(date '+%Y-%m-%d %H:%M:%S')

# Porta do servidor local
CHECKOUTSEGURO_PORT=${PORT}

# Diretório do banco de dados
CHECKOUTSEGURO_DB_PATH=${WALLET_DIR}/identity.db

# HTTPS local (true/false)
CHECKOUTSEGURO_USE_HTTPS=${USE_HTTPS}
CHECKOUTSEGURO_CERT_FILE=${CERTS_DIR}/cert.pem
CHECKOUTSEGURO_KEY_FILE=${CERTS_DIR}/key.pem

# Modo de execução (production/development)
CHECKOUTSEGURO_ENV=production

# Log level (info/warning/error)
CHECKOUTSEGURO_LOG_LEVEL=info
EOF
    success "Arquivo .env criado em ${ENV_FILE}"
else
    info "Arquivo .env já existe, mantendo configurações"
fi

# ── Script de inicialização ──────────────────────────────────────────────────
step "Criando script de inicialização"
START_SCRIPT="${INSTALL_DIR}/start.sh"
cat > "${START_SCRIPT}" << STARTEOF
#!/usr/bin/env bash
# CheckoutSeguro — Script de Inicialização
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR}"
VENV_DIR="${VENV_DIR}"
APP_DIR="${APP_DIR}"
LOG_DIR="${LOG_DIR}"
PORT="${PORT}"

source "\${VENV_DIR}/bin/activate"
source "\${INSTALL_DIR}/.env"
export \$(grep -v '^#' "\${INSTALL_DIR}/.env" | xargs)

# Redireciona logs para arquivo rotativo
exec >> "\${LOG_DIR}/checkoutseguro.log" 2>&1

cd "\${APP_DIR}"

if [[ "\${CHECKOUTSEGURO_USE_HTTPS}" == "true" ]]; then
    exec uvicorn main:app \\
        --host 127.0.0.1 \\
        --port "\${PORT}" \\
        --ssl-certfile "\${CHECKOUTSEGURO_CERT_FILE}" \\
        --ssl-keyfile "\${CHECKOUTSEGURO_KEY_FILE}" \\
        --log-level "\${CHECKOUTSEGURO_LOG_LEVEL}" \\
        --no-access-log
else
    exec uvicorn main:app \\
        --host 127.0.0.1 \\
        --port "\${PORT}" \\
        --log-level "\${CHECKOUTSEGURO_LOG_LEVEL}" \\
        --no-access-log
fi
STARTEOF
chmod +x "${START_SCRIPT}"
success "Script de inicialização criado: ${START_SCRIPT}"

# ── Script de parada ─────────────────────────────────────────────────────────
STOP_SCRIPT="${INSTALL_DIR}/stop.sh"
cat > "${STOP_SCRIPT}" << STOPEOF
#!/usr/bin/env bash
# CheckoutSeguro — Script de Parada
PID=\$(lsof -ti tcp:${PORT} 2>/dev/null || true)
if [[ -n "\$PID" ]]; then
    kill -SIGTERM "\$PID" && echo "CheckoutSeguro parado (PID \$PID)"
else
    echo "CheckoutSeguro não está rodando na porta ${PORT}"
fi
STOPEOF
chmod +x "${STOP_SCRIPT}"

# ── Instalação como serviço do sistema ──────────────────────────────────────
if [[ "$PLATFORM" == "linux" ]]; then
    step "Instalando serviço systemd (usuário)"
    SERVICE_DIR="${HOME}/.config/systemd/user"
    mkdir -p "${SERVICE_DIR}"
    cat > "${SERVICE_DIR}/checkoutseguro.service" << SVCEOF
[Unit]
Description=CheckoutSeguro — App Local de Assinatura Criptográfica
Documentation=${REPO_URL}
After=network.target

[Service]
Type=simple
ExecStart=${START_SCRIPT}
ExecStop=${STOP_SCRIPT}
Restart=on-failure
RestartSec=5s
StandardOutput=append:${LOG_DIR}/checkoutseguro.log
StandardError=append:${LOG_DIR}/checkoutseguro-error.log
Environment="PATH=${VENV_DIR}/bin:/usr/local/bin:/usr/bin:/bin"
WorkingDirectory=${APP_DIR}

[Install]
WantedBy=default.target
SVCEOF

    if systemctl --user daemon-reload 2>/dev/null; then
        systemctl --user enable checkoutseguro.service 2>/dev/null || true
        success "Serviço systemd instalado e habilitado"
        info "Para iniciar: systemctl --user start checkoutseguro"
        info "Para ver logs: journalctl --user -u checkoutseguro -f"
    else
        warn "systemd não disponível. Use ${START_SCRIPT} para iniciar manualmente."
    fi

elif [[ "$PLATFORM" == "macos" ]]; then
    step "Instalando LaunchAgent (macOS)"
    PLIST_DIR="${HOME}/Library/LaunchAgents"
    mkdir -p "${PLIST_DIR}"
    cat > "${PLIST_DIR}/com.checkoutseguro.app.plist" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.checkoutseguro.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>${START_SCRIPT}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/checkoutseguro.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/checkoutseguro-error.log</string>
    <key>WorkingDirectory</key>
    <string>${APP_DIR}</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${VENV_DIR}/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
PLISTEOF

    launchctl load "${PLIST_DIR}/com.checkoutseguro.app.plist" 2>/dev/null || true
    success "LaunchAgent instalado e carregado"
    info "Para parar: launchctl unload ~/Library/LaunchAgents/com.checkoutseguro.app.plist"
    info "Para ver logs: tail -f ${LOG_DIR}/checkoutseguro.log"
fi

# ── Verificação pós-instalação ───────────────────────────────────────────────
step "Verificando instalação"
sleep 2

PROTO="http"
[[ "$USE_HTTPS" == "true" ]] && PROTO="https"

if curl -sk "${PROTO}://127.0.0.1:${PORT}/status" | grep -q '"running":true'; then
    success "CheckoutSeguro está rodando em ${PROTO}://localhost:${PORT}"
else
    # Tenta iniciar manualmente para verificação
    "${START_SCRIPT}" &
    sleep 3
    if curl -sk "${PROTO}://127.0.0.1:${PORT}/status" | grep -q '"running":true'; then
        success "CheckoutSeguro iniciado com sucesso"
    else
        warn "Não foi possível verificar automaticamente. Inicie manualmente: ${START_SCRIPT}"
    fi
fi

# ── Resumo final ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  ✅  CheckoutSeguro instalado com sucesso! (v${VERSION})${RESET}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${CYAN}Interface:${RESET}    ${PROTO}://localhost:${PORT}"
echo -e "  ${CYAN}Dados:${RESET}        ${WALLET_DIR}/"
echo -e "  ${CYAN}Logs:${RESET}         ${LOG_DIR}/checkoutseguro.log"
echo -e "  ${CYAN}Configuração:${RESET} ${ENV_FILE}"
echo ""
echo -e "  ${YELLOW}Próximos passos:${RESET}"
echo -e "  1. Acesse ${PROTO}://localhost:${PORT} para criar sua identidade"
echo -e "  2. Instale a extensão do navegador (pasta extension/)"
echo -e "  3. Faça backup da sua Frase de Segurança em local seguro"
echo ""
