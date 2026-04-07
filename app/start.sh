#!/bin/bash
# CheckoutSeguro — Inicializador do App Local
# Roda o servidor na porta 7432 (localhost apenas)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       CheckoutSeguro — App Local         ║"
echo "║   Sua identidade Web3 no seu hardware    ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verifica Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 não encontrado. Instale em https://python.org"
    exit 1
fi

# Instala dependências se necessário
if ! python3 -c "import fastapi" 2>/dev/null; then
    echo "📦 Instalando dependências..."
    pip3 install -r requirements.txt
fi

echo "🚀 Iniciando CheckoutSeguro em http://localhost:7432"
echo "📱 Abra http://localhost:7432 no navegador para gerenciar sua identidade"
echo "🔌 Extensão e lojas parceiras se conectam automaticamente"
echo ""
echo "Pressione Ctrl+C para encerrar."
echo ""

python3 -m uvicorn main:app --host 127.0.0.1 --port 7432 --reload
