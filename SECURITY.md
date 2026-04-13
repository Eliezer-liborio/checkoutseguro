# Política de Segurança — CheckoutSeguro

## Versões Suportadas

| Versão | Suporte de Segurança |
| :--- | :--- |
| 1.x (main) | ✅ Suportada |

## Reportando uma Vulnerabilidade

O CheckoutSeguro lida com chaves criptográficas e dados financeiros. Levamos a segurança muito a sério.

**NÃO abra uma issue pública para vulnerabilidades de segurança.**

### Como Reportar

Envie um e-mail para o mantenedor do projeto descrevendo:

1. **Tipo da vulnerabilidade** (ex: XSS, injeção SQL, exposição de chave privada).
2. **Componente afetado** (ex: `app/main.py`, endpoint `/wallet/sign`).
3. **Passos para reproduzir** a vulnerabilidade.
4. **Impacto potencial** — o que um atacante poderia fazer.
5. **Sugestão de correção** (opcional, mas muito bem-vinda).

### Processo de Resposta

Após o recebimento do relatório:

- **Confirmação em 48h**: Confirmaremos o recebimento do relatório.
- **Avaliação em 7 dias**: Avaliaremos a severidade e o impacto.
- **Correção em 30 dias**: Para vulnerabilidades críticas, trabalharemos para publicar uma correção.
- **Crédito público**: Com sua permissão, você será mencionado no `CHANGELOG.md` como colaborador de segurança.

### Escopo

As seguintes áreas são de alta prioridade para relatórios de segurança:

- Exposição ou vazamento de chaves privadas Ethereum.
- Bypass da autenticação por Frase de Segurança.
- Ataques de replay em assinaturas de pedidos.
- Injeção de código no app local ou na extensão de navegador.
- Comunicação não criptografada entre a extensão e o app local.

### Fora do Escopo

- Ataques que requerem acesso físico ao dispositivo do usuário.
- Engenharia social ou phishing.
- Vulnerabilidades em dependências de terceiros já conhecidas e sem correção disponível.

## Boas Práticas para Usuários

- **Nunca compartilhe sua Frase de Segurança** com ninguém, nem com o suporte.
- Faça backup da sua Frase de Segurança em local físico seguro (papel, cofre).
- Mantenha o app sempre atualizado (`make update` ou `bash deploy/update.sh`).
- Verifique sempre se está acessando `https://localhost:7432` (HTTPS obrigatório).
