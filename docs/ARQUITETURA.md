# Arquitetura Técnica: CheckoutSeguro

## Visão Geral

O **CheckoutSeguro** é construído sobre uma arquitetura de microsserviços, onde cada componente tem uma responsabilidade bem definida. A plataforma combina dois projetos proprietários — `carteira-ethereum` (KMS custodial) e `sdk-metamask` (motor SIWE EIP-4361) — para entregar autenticação Web3 sem a necessidade de carteiras externas como o MetaMask.

![Arquitetura Geral](./diagramas/arquitetura_geral.png)

## Componentes Principais

A tabela abaixo resume as responsabilidades e tecnologias de cada serviço da plataforma:

| Serviço | Repositório de Origem | Responsabilidade Principal | Tecnologia |
| :--- | :--- | :--- | :--- |
| **Identity Service** | Novo (CheckoutSeguro) | Onboarding, cadastro único, gestão de usuários | Python / FastAPI |
| **Wallet Service** | `carteira-ethereum` | KMS: geração de chaves, criptografia, assinatura server-side | Python / Flask, Fernet, bcrypt |
| **Auth Service** | `sdk-metamask` | Nonce EIP-4361, verificação SIWE, emissão de JWT | Python / FastAPI, siwe |
| **Order Service** | Novo (CheckoutSeguro) | Validação de pedidos, persistência de recibos criptográficos | Python / FastAPI |
| **Partner SDK** | Novo (CheckoutSeguro) | Integração nas lojas parceiras (JS snippet + REST) | JavaScript |
| **Extensão** | Novo (CheckoutSeguro) | Interface do usuário no navegador (Chrome/Edge/Firefox) | HTML/CSS/JS (Manifest V3) |
| **App Mobile** | Novo (CheckoutSeguro) | Interface nativa e aprovação via biometria | React Native / Expo |

## Decisões de Arquitetura

### Por que Custodial (e não Self-Custody)?

A decisão de manter as chaves privadas no backend do CheckoutSeguro é intencional e estratégica. O público-alvo é o consumidor comum do e-commerce brasileiro, que não está familiarizado com Web3. Exigir que ele gerencie sua própria chave privada resultaria em abandono de carrinho e suporte massivo por perda de acesso. O modelo custodial resolve isso, enquanto a Frase de Segurança garante que nem o próprio CheckoutSeguro pode assinar em nome do usuário sem o consentimento dele (a frase é necessária para descriptografar a chave).

### Por que a Frase de Segurança é a "senha"?

A chave privada do usuário é criptografada com `Fernet`, usando como entropia adicional o hash `bcrypt` da Frase de Segurança. Isso significa que, mesmo que o banco de dados seja comprometido, as chaves privadas permanecem inacessíveis sem as frases individuais de cada usuário. A Frase de Segurança nunca é armazenada em texto claro — apenas seu hash bcrypt.

### Fluxo de Assinatura (O Núcleo da Plataforma)

O fluxo de assinatura é o coração do sistema e acontece inteiramente no backend, sem nenhuma extensão de carteira no navegador do usuário:

1. A Extensão/App envia a mensagem SIWE e a Frase de Segurança para o `Wallet Service` via HTTPS.
2. O `Wallet Service` valida o hash da frase contra o banco de dados.
3. Se válido, a chave privada é descriptografada **apenas em memória** (nunca em disco).
4. A mensagem é assinada com `personal_sign` (compatível com EIP-4361).
5. A chave privada é imediatamente descartada da memória.
6. A assinatura é devolvida para a Extensão/App.

### Extensão de Navegador vs. App Mobile

Os dois clientes têm papéis complementares:

**Extensão de Navegador (Desktop):** É o cliente primário para compras em e-commerce. Ela injeta o botão "Pagar com CheckoutSeguro" nas páginas de checkout das lojas parceiras (via Partner SDK) e exibe o popup de confirmação sem redirecionar o usuário para outro site.

**App Mobile:** Serve tanto como cliente primário para compras em apps mobile quanto como segundo fator de autenticação (2FA) para compras no desktop. Quando o usuário está comprando no computador, ele pode aprovar a compra com biometria (FaceID/TouchID) no celular, que preenche a Frase de Segurança automaticamente via notificação push segura.

## Segurança e Conformidade

A plataforma foi projetada com os seguintes princípios de segurança:

| Ameaça | Mitigação |
| :--- | :--- |
| Replay Attack | Nonce de uso único com TTL de 5 minutos (Auth Service) |
| Vazamento de banco de dados | Chaves privadas criptografadas com Fernet + entropia da Frase de Segurança (bcrypt) |
| Chargeback fraudulento | Recibo criptográfico (assinatura Ethereum) vinculado ao pedido e ao endereço do comprador |
| Roubo de sessão | JWT emitido como cookie HttpOnly, inacessível via JavaScript |
| Man-in-the-Middle | Toda comunicação via HTTPS/TLS; domínio validado na mensagem SIWE (EIP-4361) |
| Acesso indevido ao Wallet Service | Endpoint `/wallet/sign` é interno e nunca exposto diretamente ao público |
