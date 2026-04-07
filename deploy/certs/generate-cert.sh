#!/usr/bin/env bash
# =============================================================================
#  CheckoutSeguro — Gerador de Certificado TLS Autoassinado
#  Gera um certificado válido por 10 anos para uso em HTTPS local.
#  Uso: bash deploy/certs/generate-cert.sh [--dir /caminho/para/certs]
# =============================================================================

set -euo pipefail

CERTS_DIR="${1:-${HOME}/.checkoutseguro/certs}"
CERT_FILE="${CERTS_DIR}/cert.pem"
KEY_FILE="${CERTS_DIR}/key.pem"
CONFIG_FILE="${CERTS_DIR}/openssl.cnf"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RESET='\033[0m'

echo -e "${CYAN}Gerando certificado TLS autoassinado para CheckoutSeguro...${RESET}"

if ! command -v openssl &>/dev/null; then
    echo "ERRO: openssl não encontrado. Instale com: sudo apt install openssl"
    exit 1
fi

mkdir -p "${CERTS_DIR}"

# Arquivo de configuração OpenSSL com Subject Alternative Names
cat > "${CONFIG_FILE}" << EOF
[req]
default_bits       = 4096
prompt             = no
default_md         = sha256
distinguished_name = dn
x509_extensions    = v3_req

[dn]
C  = BR
ST = Brasil
L  = Local
O  = CheckoutSeguro
OU = Self-Custody App
CN = localhost

[v3_req]
subjectAltName = @alt_names
keyUsage       = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
IP.1  = 127.0.0.1
IP.2  = ::1
EOF

# Gera o par de chaves e certificado
openssl req -x509 \
    -newkey rsa:4096 \
    -sha256 \
    -days 3650 \
    -nodes \
    -keyout "${KEY_FILE}" \
    -out "${CERT_FILE}" \
    -config "${CONFIG_FILE}" \
    2>/dev/null

chmod 600 "${KEY_FILE}"
chmod 644 "${CERT_FILE}"

echo -e "${GREEN}Certificado gerado com sucesso!${RESET}"
echo ""
echo "  Certificado: ${CERT_FILE}"
echo "  Chave:       ${KEY_FILE}"
echo ""
echo "Validade: $(openssl x509 -in "${CERT_FILE}" -noout -dates | grep 'notAfter' | cut -d= -f2)"
echo ""
echo "Para confiar no certificado no Chrome/Edge:"
echo "  Linux:  sudo cp ${CERT_FILE} /usr/local/share/ca-certificates/checkoutseguro.crt && sudo update-ca-certificates"
echo "  macOS:  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${CERT_FILE}"
echo "  Windows: certutil -addstore -f 'ROOT' ${CERT_FILE}"
