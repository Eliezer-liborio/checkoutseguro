# CheckoutSeguro

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110.0+-009688.svg?logo=fastapi)](https://fastapi.tiangolo.com)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

**Plataforma de autenticação Web3 custodial para e-commerce:** cadastro único, assinatura de compras via Ethereum, sem depender de MetaMask ou taxas de rede (gas).

[Arquitetura](./docs/ARQUITETURA.md) •
[Como Contribuir](./CONTRIBUTING.md) •
[Reportar Bug](https://github.com/Eliezer-liborio/checkoutseguro/issues/new?template=bug_report.md) •
[Sugerir Funcionalidade](https://github.com/Eliezer-liborio/checkoutseguro/issues/new?template=feature_request.md)

</div>

---

O **CheckoutSeguro** é uma solução B2B2C que une a conveniência da Web2 com a segurança irrefutável da Web3. O sistema atua como um provedor de identidade (Identity Provider) e cofre criptográfico (KMS) local, permitindo que usuários façam compras online assinadas na blockchain Ethereum sem precisar instalar carteiras de terceiros.

##  O Problema que Resolvemos

No e-commerce tradicional, o *chargeback* (quando o cliente alega "não fui eu que comprei") é um dos maiores ralos de dinheiro para os lojistas.

##  Nossa Solução (Self-Custody)

O **CheckoutSeguro** abstrai toda a complexidade da blockchain, mantendo o controle total nas mãos do usuário:

1. **App Local:** O usuário roda um servidor leve em sua própria máquina. A chave privada é gerada e guardada no hardware dele, nunca trafegando pela rede.
2. **Cadastro Único (SSO):** O usuário cria uma identidade uma única vez e pode usá-la em qualquer loja parceira.
3. **Assinatura sem Fricção:** No momento do checkout, o usuário digita sua Frase de Segurança na nossa extensão de navegador. O app local assina o pedido criptograficamente e entrega um "recibo" irrefutável para a loja.

## Instalação Rápida (Produção)

O CheckoutSeguro roda como um serviço em background no seu computador.

**Linux / macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/Eliezer-liborio/checkoutseguro/main/deploy/install.sh | bash
```

**Windows (PowerShell como Administrador):**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Eliezer-liborio/checkoutseguro/main/deploy/windows/install.ps1").Content
```

Após a instalação, acesse `https://localhost:7432` (o instalador gera o certificado HTTPS automaticamente) para criar sua identidade.

##  Para Desenvolvedores

### Requisitos

- Python 3.9+
- GNU Make (opcional, mas recomendado)

### Rodando Localmente

```bash
# 1. Clone o repositório
git clone https://github.com/Eliezer-liborio/checkoutseguro.git
cd checkoutseguro

# 2. Crie o ambiente virtual e instale as dependências
make install

# 3. Inicie o app local (porta 7432)
make start

# 4. (Opcional) Inicie a loja de testes (Fazendinha E-commerce)
make start-loja
```

### Testes End-to-End

O projeto inclui uma suite completa de testes E2E que valida todo o fluxo de assinatura e verificação criptográfica:

```bash
make test-e2e
```

##  Arquitetura

O ecossistema é composto pelo App Local (KMS), Extensão de Navegador, SDK para lojas parceiras e uma loja de laboratório.

![Arquitetura Geral](./docs/diagramas/arquitetura_geral.png)

Para um aprofundamento técnico, consulte a [Documentação de Arquitetura](./docs/ARQUITETURA.md).

##  Cenários de Uso

A plataforma foi desenhada para ser fluida tanto para novos usuários quanto para os recorrentes:

- **[Cenário 1: Primeiro Acesso (Cadastro Único)](./docs/cenarios/CENARIO_1_NOVO_USUARIO.md)**
- **[Cenário 2: Usuário Existente (Login e Checkout)](./docs/cenarios/CENARIO_2_USUARIO_EXISTENTE.md)**

##  Como Contribuir

Contribuições são muito bem-vindas! Se você deseja melhorar o CheckoutSeguro, por favor, leia nosso [Guia de Contribuição](./CONTRIBUTING.md) para entender como configurar seu ambiente e enviar Pull Requests.

##  Segurança

Se você encontrou uma vulnerabilidade de segurança, **por favor não abra uma issue pública**. Leia nossa [Política de Segurança](./SECURITY.md) para instruções sobre como reportar de forma responsável.

##  Roadmap

Consulte o arquivo [ROADMAP.md](./docs/ROADMAP.md) para acompanhar as próximas fases de desenvolvimento, incluindo o lançamento oficial da extensão nas stores, do app mobile e da integração on-chain (EIP-1271).

## Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo [LICENSE](./LICENSE) para detalhes.
