# Roadmap: CheckoutSeguro

Este documento descreve as fases de desenvolvimento e evolução da plataforma CheckoutSeguro, desde a Prova de Conceito (PoC) até a integração completa com a rede Ethereum (Mainnet/L2).

## Fase 1: Fundação e PoC (Atual)
- [x] Definição da arquitetura e dos fluxos de usuário (Cenários 1 e 2).
- [x] Repositório base estruturado.
- [ ] **Identity Service:** API de onboarding (cadastro de e-mail, telefone e geração da Frase de Segurança).
- [ ] **Wallet Service:** Integração do `carteira-ethereum` como KMS (Key Management System) custodial usando Fernet e bcrypt.
- [ ] **Auth Service:** Adaptação do `sdk-metamask` para gerar nonces e validar assinaturas EIP-4361 geradas pelo Wallet Service.
- [ ] **Order Service:** API básica para receber o hash do carrinho e a assinatura, persistindo o recibo criptográfico.

## Fase 2: Clientes e Integração
- [ ] **Extensão de Navegador (MVP):**
  - Popup de onboarding (Cenário 1).
  - Interceptação de eventos de checkout.
  - Tela de assinatura com Frase de Segurança (Cenário 2).
- [ ] **Partner SDK:** Script JS simples (`<script src="..."></script>`) para lojas parceiras adicionarem o botão "Pagar com CheckoutSeguro".
- [ ] **Ambiente de Homologação:** Deploy da infraestrutura base (Docker/Terraform) e banco de dados centralizado.

## Fase 3: Expansão Mobile e UX
- [ ] **App Mobile (React Native / PWA):**
  - Sincronização da conta via QR Code (Extensão -> Mobile).
  - Aprovação de compras no desktop via notificação push no celular (Autenticação 2FA).
  - Biometria (FaceID/TouchID) para preencher a Frase de Segurança automaticamente.
- [ ] **Painel do Usuário:** Dashboard web para o usuário visualizar seu histórico de compras e recibos criptográficos.
- [ ] **Painel do Lojista:** Dashboard para lojas parceiras visualizarem pedidos, assinaturas e exportarem provas de compra (prevenção de chargeback).

## Fase 4: Descentralização e Web3 Real
- [ ] **EIP-1271 (Smart Contract Wallets):** Implementação opcional para que usuários avançados possam usar contratos inteligentes como sua identidade (Account Abstraction).
- [ ] **Rollups / L2:** Registro em lote (batching) dos hashes de pedidos em uma rede Layer 2 (ex: Arbitrum, Optimism, Base) para criar uma prova pública e imutável de todas as transações da plataforma, sem custo para o usuário final.
- [ ] **Exportação de Chaves:** Ferramenta segura para que o usuário possa revelar sua chave privada e migrar para uma carteira não-custodial (MetaMask, Rabby) se desejar assumir a custódia total de seus fundos e identidade.
