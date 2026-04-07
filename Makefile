# =============================================================================
#  CheckoutSeguro — Makefile
#  Centraliza todos os comandos de desenvolvimento, deploy e manutenção.
#  Uso: make <comando>
# =============================================================================

.PHONY: help install update uninstall start stop restart status logs \
        test test-e2e lint format docker-build docker-up docker-down \
        docker-logs clean backup

# Configurações
PORT        ?= 7432
LOJA_PORT   ?= 8001
PYTHON      ?= python3
VENV        := $(HOME)/.checkoutseguro/venv
APP_DIR     := $(HOME)/.checkoutseguro/app
LOG_FILE    := $(HOME)/.checkoutseguro/logs/checkoutseguro.log

# Detecta o SO
UNAME := $(shell uname -s)

# ── Ajuda ─────────────────────────────────────────────────────────────────────
help: ## Exibe esta mensagem de ajuda
	@echo ""
	@echo "  CheckoutSeguro — Comandos Disponíveis"
	@echo "  ══════════════════════════════════════"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ── Instalação e Manutenção ───────────────────────────────────────────────────
install: ## Instala o CheckoutSeguro no sistema (Linux/macOS)
	@chmod +x deploy/install.sh
	@bash deploy/install.sh

update: ## Atualiza para a versão mais recente preservando os dados
	@chmod +x deploy/update.sh
	@bash deploy/update.sh

uninstall: ## Remove o CheckoutSeguro do sistema
	@chmod +x deploy/uninstall.sh
	@bash deploy/uninstall.sh

# ── Controle do Serviço ───────────────────────────────────────────────────────
start: ## Inicia o app CheckoutSeguro localmente (desenvolvimento)
	@echo "Iniciando CheckoutSeguro na porta $(PORT)..."
	@cd app && $(PYTHON) -m uvicorn main:app \
		--host 127.0.0.1 \
		--port $(PORT) \
		--reload \
		--log-level info

start-bg: ## Inicia o app em background
	@cd app && $(PYTHON) -m uvicorn main:app \
		--host 127.0.0.1 \
		--port $(PORT) \
		--log-level info > /tmp/checkoutseguro.log 2>&1 &
	@echo "CheckoutSeguro iniciado em background (porta $(PORT))"
	@echo "Logs: /tmp/checkoutseguro.log"

start-loja: ## Inicia a Fazendinha E-commerce (laboratório)
	@cd fazendinha-ecommerce && $(PYTHON) -m uvicorn app:app \
		--host 127.0.0.1 \
		--port $(LOJA_PORT) \
		--reload \
		--log-level info

stop: ## Para o app CheckoutSeguro
	@PID=$$(lsof -ti tcp:$(PORT) 2>/dev/null); \
	if [ -n "$$PID" ]; then \
		kill -SIGTERM $$PID && echo "CheckoutSeguro parado (PID $$PID)"; \
	else \
		echo "CheckoutSeguro não está rodando na porta $(PORT)"; \
	fi

restart: stop start-bg ## Reinicia o app

status: ## Verifica o status do app
	@curl -s http://127.0.0.1:$(PORT)/status 2>/dev/null | \
		$(PYTHON) -m json.tool || echo "CheckoutSeguro não está rodando"

logs: ## Exibe os logs em tempo real
	@if [ -f "$(LOG_FILE)" ]; then \
		tail -f "$(LOG_FILE)"; \
	elif [ -f "/tmp/checkoutseguro.log" ]; then \
		tail -f /tmp/checkoutseguro.log; \
	else \
		echo "Arquivo de log não encontrado"; \
	fi

# ── Testes ────────────────────────────────────────────────────────────────────
test: ## Executa todos os testes (requer os dois servidores rodando)
	@$(PYTHON) tests/test_e2e.py

test-e2e: start-bg ## Inicia os servidores e executa os testes E2E
	@sleep 3
	@cd fazendinha-ecommerce && $(PYTHON) -m uvicorn app:app \
		--host 127.0.0.1 --port $(LOJA_PORT) > /tmp/fazendinha.log 2>&1 &
	@sleep 3
	@$(PYTHON) tests/test_e2e.py; STATUS=$$?; \
	PID=$$(lsof -ti tcp:$(PORT) 2>/dev/null); [ -n "$$PID" ] && kill $$PID; \
	PID=$$(lsof -ti tcp:$(LOJA_PORT) 2>/dev/null); [ -n "$$PID" ] && kill $$PID; \
	exit $$STATUS

lint: ## Verifica o código com flake8
	@$(PYTHON) -m flake8 app/ fazendinha-ecommerce/ tests/ \
		--max-line-length=100 \
		--exclude=__pycache__,.venv,venv

format: ## Formata o código com black
	@$(PYTHON) -m black app/ fazendinha-ecommerce/ tests/ --line-length=100

# ── Docker ────────────────────────────────────────────────────────────────────
docker-build: ## Constrói as imagens Docker
	@docker compose -f deploy/docker/docker-compose.yml build

docker-up: ## Sobe o ambiente completo com Docker Compose
	@docker compose -f deploy/docker/docker-compose.yml up -d
	@echo "Ambiente Docker iniciado:"
	@echo "  CheckoutSeguro: https://localhost:7432"
	@echo "  Fazendinha:     http://localhost:8000"

docker-down: ## Para e remove os containers Docker
	@docker compose -f deploy/docker/docker-compose.yml down

docker-logs: ## Exibe os logs dos containers Docker
	@docker compose -f deploy/docker/docker-compose.yml logs -f

docker-status: ## Verifica o status dos containers
	@docker compose -f deploy/docker/docker-compose.yml ps

# ── Utilitários ───────────────────────────────────────────────────────────────
clean: ## Remove arquivos temporários e caches
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.pyc" -delete 2>/dev/null || true
	@find . -name "*.db" -not -path "*/wallet/*" -delete 2>/dev/null || true
	@rm -f /tmp/checkoutseguro.log /tmp/fazendinha*.log
	@echo "Limpeza concluída"

backup: ## Faz backup dos dados da carteira
	@BACKUP_DIR="backup_carteira_$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$BACKUP_DIR"; \
	cp -r "$(HOME)/.checkoutseguro/wallet" "$$BACKUP_DIR/" 2>/dev/null || \
		cp -r app/wallet "$$BACKUP_DIR/" 2>/dev/null || \
		echo "Nenhum dado de carteira encontrado"; \
	echo "Backup criado em: $$BACKUP_DIR"

cert-info: ## Exibe informações do certificado TLS local
	@CERT="$(HOME)/.checkoutseguro/certs/cert.pem"; \
	[ -f "$$CERT" ] && openssl x509 -in "$$CERT" -noout -text | \
		grep -E "(Subject|Not Before|Not After|DNS|IP)" || \
		echo "Certificado não encontrado"

version: ## Exibe a versão instalada
	@echo "CheckoutSeguro v1.0.0"
	@echo "Python: $$($(PYTHON) --version)"
	@echo "Repositório: https://github.com/Eliezer-liborio/checkoutseguro"
