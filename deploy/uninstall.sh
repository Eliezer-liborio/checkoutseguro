#!/usr/bin/env bash
# =============================================================================
#  CheckoutSeguro — Script de Desinstalação
#  Remove o serviço e os arquivos da aplicação.
#  ⚠️  Os dados da carteira (wallet/) NÃO são removidos por padrão.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERRO]${RESET}  $*" >&2; exit 1; }

INSTALL_DIR="${HOME}/.checkoutseguro"
PORT="${CHECKOUTSEGURO_PORT:-7432}"
OS="$(uname -s)"

echo -e "\n${BOLD}${RED}CheckoutSeguro — Desinstalação${RESET}\n"

# Confirmação
read -rp "$(echo -e "${YELLOW}Tem certeza que deseja desinstalar? [s/N]:${RESET} ")" CONFIRM
[[ "${CONFIRM,,}" != "s" ]] && { info "Desinstalação cancelada."; exit 0; }

# Opção de remover dados da carteira
read -rp "$(echo -e "${RED}⚠️  Remover também os dados da carteira (IRREVERSÍVEL)? [s/N]:${RESET} ")" REMOVE_WALLET
REMOVE_WALLET_DATA=false
[[ "${REMOVE_WALLET,,}" == "s" ]] && REMOVE_WALLET_DATA=true

# Para o serviço
info "Parando o serviço..."
PID=$(lsof -ti tcp:${PORT} 2>/dev/null || true)
[[ -n "$PID" ]] && kill -SIGTERM "$PID" && info "Processo encerrado (PID $PID)"

if [[ "$OS" == "Linux" ]]; then
    systemctl --user stop checkoutseguro.service 2>/dev/null || true
    systemctl --user disable checkoutseguro.service 2>/dev/null || true
    rm -f "${HOME}/.config/systemd/user/checkoutseguro.service"
    systemctl --user daemon-reload 2>/dev/null || true
    success "Serviço systemd removido"
elif [[ "$OS" == "Darwin" ]]; then
    PLIST="${HOME}/Library/LaunchAgents/com.checkoutseguro.app.plist"
    [[ -f "$PLIST" ]] && launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    success "LaunchAgent removido"
fi

# Remove arquivos (preserva wallet por padrão)
if [[ "$REMOVE_WALLET_DATA" == true ]]; then
    rm -rf "${INSTALL_DIR}"
    success "Todos os dados removidos (incluindo carteira)"
else
    # Preserva a pasta wallet/
    WALLET_BACKUP="${HOME}/checkoutseguro_wallet_backup_$(date +%Y%m%d_%H%M%S)"
    [[ -d "${INSTALL_DIR}/wallet" ]] && cp -r "${INSTALL_DIR}/wallet" "${WALLET_BACKUP}"
    rm -rf "${INSTALL_DIR}"
    [[ -d "$WALLET_BACKUP" ]] && {
        success "Dados da carteira preservados em: ${WALLET_BACKUP}"
    }
    success "Arquivos da aplicação removidos"
fi

echo -e "\n${GREEN}CheckoutSeguro desinstalado com sucesso.${RESET}\n"
