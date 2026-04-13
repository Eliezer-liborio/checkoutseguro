# Guia de Contribuição — CheckoutSeguro

Obrigado por se interessar em contribuir com o CheckoutSeguro! Este guia explica como participar do projeto de forma organizada e eficiente.

## Código de Conduta

Ao participar deste projeto, você concorda em seguir o nosso [Código de Conduta](./CODE_OF_CONDUCT.md). Trate todos com respeito e profissionalismo.

## Como Contribuir

### 1. Reportando Bugs

Antes de abrir uma issue, verifique se o problema já foi reportado na [lista de issues](https://github.com/Eliezer-liborio/checkoutseguro/issues).

Ao reportar um bug, inclua:
- Versão do sistema operacional e Python.
- Passos detalhados para reproduzir o problema.
- Comportamento esperado vs. comportamento atual.
- Logs relevantes (sem dados sensíveis).

### 2. Sugerindo Melhorias

Abra uma issue com o prefixo `[FEATURE]` no título e descreva:
- O problema que a melhoria resolve.
- A solução proposta.
- Alternativas consideradas.

### 3. Enviando Pull Requests

#### Configurando o Ambiente de Desenvolvimento

```bash
# 1. Faça um fork do repositório e clone localmente
git clone https://github.com/SEU_USUARIO/checkoutseguro.git
cd checkoutseguro

# 2. Crie um ambiente virtual Python
python3 -m venv .venv
source .venv/bin/activate  # Linux/macOS
# .venv\Scripts\activate   # Windows

# 3. Instale as dependências de desenvolvimento
pip install -r app/requirements.txt
pip install flake8 black pytest

# 4. Copie o arquivo de configuração de exemplo
cp .env.example .env
# Edite o .env com suas configurações locais

# 5. Inicie os servidores de desenvolvimento
make start-bg        # App CheckoutSeguro (porta 7432)
make start-loja      # Fazendinha E-commerce (porta 8001)
```

#### Fluxo de Trabalho

```bash
# 1. Crie uma branch descritiva a partir de main
git checkout -b feat/nome-da-funcionalidade
# ou
git checkout -b fix/descricao-do-bug

# 2. Faça suas alterações e escreva testes
# ...

# 3. Verifique a formatação e qualidade do código
make lint    # flake8
make format  # black

# 4. Execute os testes
make test-e2e

# 5. Commit com mensagem descritiva (Conventional Commits)
git commit -m "feat(wallet): adiciona suporte a múltiplas carteiras por usuário"

# 6. Envie a branch e abra o Pull Request
git push origin feat/nome-da-funcionalidade
```

#### Padrão de Commits (Conventional Commits)

Use o padrão [Conventional Commits](https://www.conventionalcommits.org/):

| Prefixo | Quando usar |
| :--- | :--- |
| `feat:` | Nova funcionalidade |
| `fix:` | Correção de bug |
| `docs:` | Alterações na documentação |
| `refactor:` | Refatoração sem mudança de comportamento |
| `test:` | Adição ou correção de testes |
| `chore:` | Tarefas de manutenção (deps, CI, etc.) |
| `security:` | Correção de vulnerabilidade de segurança |

#### Critérios para Aprovação de PR

- O código passa em todos os testes automatizados (`make test-e2e`).
- O código segue o estilo do projeto (`make lint`).
- Novas funcionalidades incluem testes.
- A documentação foi atualizada se necessário.
- Nenhum dado sensível (chaves, senhas, `.db`) foi incluído.

## Estrutura do Projeto

```text
checkoutseguro/
├── app/                    # App local (FastAPI) — roda no hardware do usuário
│   ├── main.py             # Servidor principal com todos os endpoints
│   ├── ui/index.html       # Interface web (SPA)
│   └── requirements.txt    # Dependências Python
├── extension/              # Extensão de navegador (Manifest V3)
├── fazendinha-ecommerce/   # Loja de exemplo para testes de integração
├── partner-sdk/            # SDK JavaScript para lojas parceiras
├── deploy/                 # Scripts de instalação multiplataforma
├── tests/                  # Testes end-to-end automatizados
└── docs/                   # Documentação técnica e diagramas
```

## Dúvidas?

Abra uma [Discussion](https://github.com/Eliezer-liborio/checkoutseguro/discussions) no GitHub para perguntas gerais sobre o projeto.
