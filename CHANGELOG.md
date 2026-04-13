# Changelog — CheckoutSeguro

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato segue o padrão [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

---

## [1.0.0] — 2026-04-13

### Adicionado

- **App Local (Self-Custody):** Servidor FastAPI leve rodando em `localhost:7432`, com a chave privada Ethereum armazenada exclusivamente no hardware do usuário.
- **Interface Web (SPA):** Tela de onboarding com geração de carteira Ethereum, exibição da Frase de Segurança e histórico de compras assinadas.
- **Extensão de Navegador (Manifest V3):** Injeta o botão "Pagar com CheckoutSeguro" em lojas parceiras e exibe popup de assinatura sem redirecionar o usuário.
- **Partner SDK (`checkoutseguro-sdk.js`):** Script JavaScript para integração em lojas parceiras em poucos minutos.
- **Fazendinha E-commerce:** Loja de exemplo completa (FastAPI + SPA) para testes de integração end-to-end.
- **Testes E2E Automatizados:** Suite de 23 testes cobrindo os dois cenários principais (novo usuário e usuário existente).
- **Scripts de Deploy Multiplataforma:**
  - `deploy/install.sh` — Linux (systemd) e macOS (LaunchAgent).
  - `deploy/windows/install.ps1` — Windows (Task Scheduler).
  - `deploy/update.sh` — Atualização segura com backup automático.
  - `deploy/uninstall.sh` — Desinstalação preservando dados da carteira.
- **Docker:** `Dockerfile` e `docker-compose.yml` para ambiente de laboratório completo.
- **Certificado HTTPS Local:** Gerado automaticamente via OpenSSL, válido por 10 anos para `localhost`.
- **Makefile:** Central de comandos para desenvolvimento, testes e deploy.
- **Documentação Completa:** Arquitetura, cenários de uso, roadmap e diagramas.

### Segurança

- Chave privada Ethereum nunca trafega pela rede; toda assinatura é feita localmente.
- Comunicação entre extensão e app local obrigatoriamente via HTTPS.
- Banco de dados SQLite bloqueado no `.gitignore` para evitar exposição acidental.

---

## [Não Lançado]

### Planejado para v1.1.0

- Identity Service com sincronização segura entre dispositivos.
- App Mobile (React Native/Expo) com suporte a biometria (FaceID/TouchID).
- Suporte a múltiplas carteiras por usuário.
- Integração on-chain via EIP-1271 para verificação pública de assinaturas.
- Dashboard de analytics para lojas parceiras.

[1.0.0]: https://github.com/Eliezer-liborio/checkoutseguro/releases/tag/v1.0.0
