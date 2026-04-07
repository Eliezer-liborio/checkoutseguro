#!/usr/bin/env bash
# =============================================================================
#  CheckoutSeguro — Script de Atualização
#  Atualiza a aplicação preservando todos os dados do usuário.
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }

INSTALL_DIR="${HOME}/.checkoutseguro"
VENV_DIR="${INSTALL_DIR}/venv"
APP_DIR="${INSTALL_DIR}/app"
PORT="${CHECKOUTSEGURO_PORT:-7432}"
REPO_URL="https://github.com/Eliezer-liborio/checkoutseguro"
OS="$(uname -s)"

echo -e "\n${BOLD}${CYAN}CheckoutSeguro — Atualização${RESET}\n"

if [[ ! -d "$INSTALL_DIR" ]]; then
    warn "CheckoutSeguro não está instalado. Execute deploy/install.sh primeiro."
    exit 1
fi

# Para o serviço temporariamente
info "Parando o serviço para atualização..."
PID=$(lsof -ti tcp:${PORT} 2>/dev/null || true)
[[ -n "$PID" ]] && kill -SIGTERM "$PID" && sleep 2

if [[ "$OS" == "Linux" ]]; then
    systemctl --user stop checkoutseguro.service 2>/dev/null || true
elif [[ "$OS" == "Darwin" ]]; then
    launchctl unload "${HOME}/Library/LaunchAgents/com.checkoutseguro.app.plist" 2>/dev/null || true
fi

# Faz backup dos arquivos atuais
BACKUP_DIR="${INSTALL_DIR}/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "${BACKUP_DIR}"
cp -r "${APP_DIR}" "${BACKUP_DIR}/app" 2>/dev/null || true
success "Backup criado em ${BACKUP_DIR}"

# Atualiza os arquivos da aplicação
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "${REPO_ROOT}/app/main.py" ]]; then
    info "Atualizando a partir do repositório local..."
    cp -r "${REPO_ROOT}/app/"* "${APP_DIR}/"
elif command -v git &>/dev/null; then
    info "Baixando atualização de ${REPO_URL}..."
    TEMP_DIR=$(mktemp -d)
    git clone --depth=1 "${REPO_URL}" "${TEMP_DIR}/checkoutseguro"
    cp -r "${TEMP_DIR}/checkoutseguro/app/"* "${APP_DIR}/"
    rm -rf "${TEMP_DIR}"
fi
success "Arquivos atualizados"

# Atualiza dependências Python
info "Atualizando dependências Python..."
source "${VENV_DIR}/bin/activate"
pip install --upgrade --quiet \
    "fastapi>=0.110.0" \
    "uvicorn[standard]>=0.29.0" \
    "eth-account>=0.11.0" \
    "bcrypt>=4.1.0" \
    "cryptography>=42.0.0" \
    "python-multipart>=0.0.9"
success "Dependências atualizadas"

# Reinicia o serviço
info "Reiniciando o serviço..."
if [[ "$OS" == "Linux" ]]; then
    systemctl --user start checkoutseguro.service 2>/dev/null || \
        "${INSTALL_DIR}/start.sh" &
elif [[ "$OS" == "Darwin" ]]; then
    launchctl load "${HOME}/Library/LaunchAgents/com.checkoutseguro.app.plist" 2>/dev/null || \
        "${INSTALL_DIR}/start.sh" &
fi

sleep 2
PROTO="http"
[[ -f "${INSTALL_DIR}/certs/cert.pem" ]] && PROTO="https"

if curl -sk "${PROTO}://127.0.0.1:${PORT}/status" | grep -q '"running":true'; then
    success "CheckoutSeguro atualizado e rodando em ${PROTO}://localhost:${PORT}"
else
    warn "Serviço não respondeu. Inicie manualmente: ${INSTALL_DIR}/start.sh"
fi

echo ""
success "Atualização concluída!"
