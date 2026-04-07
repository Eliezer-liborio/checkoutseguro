"""
CheckoutSeguro — Testes End-to-End
Valida os dois cenários:
  Cenário 1: Novo usuário (cadastro + ativação)
  Cenário 2: Usuário existente (login + assinatura de pedido + verificação na loja)
"""
import json
import hashlib
import requests
import sys
from datetime import datetime, timezone

import os
import sqlite3
APP_URL = "http://127.0.0.1:7433"
LOJA_URL = "http://127.0.0.1:8001"

import subprocess, time
# Limpa os bancos antes dos testes para garantir estado inicial limpo
DB_APP = os.path.expanduser("~/checkoutseguro/app/wallet/identity.db")
# Recria o banco antes de deletar para garantir que o servidor reinicializa
# (o servidor com --reload detecta mudanças de arquivo automaticamente)
DB_LOJA = os.path.expanduser("~/checkoutseguro/fazendinha-ecommerce/orders.db")
for db in [DB_APP, DB_LOJA]:
    if os.path.exists(db):
        os.remove(db)
        print(f"  🗑️  Banco limpo: {db}")

# Aguarda os servidores reinicializarem os bancos
time.sleep(2)

PASS = "\033[92m✅ PASS\033[0m"
FAIL = "\033[91m❌ FAIL\033[0m"
INFO = "\033[94mℹ️\033[0m"

results = []

def check(name, condition, detail=""):
    status = PASS if condition else FAIL
    print(f"  {status}  {name}")
    if detail:
        print(f"       {INFO} {detail}")
    results.append((name, condition))
    return condition

def section(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

# ─────────────────────────────────────────────────────────────
# PRÉ-REQUISITOS
# ─────────────────────────────────────────────────────────────
section("PRÉ-REQUISITOS: Serviços em execução")

try:
    r = requests.get(f"{APP_URL}/status", timeout=3)
    check("App CheckoutSeguro respondendo (porta 7432)", r.status_code == 200,
          f"Status: {r.json()}")
except Exception as e:
    check("App CheckoutSeguro respondendo (porta 7432)", False, str(e))
    print("\n⛔ App não está rodando. Inicie com: cd app && python3 -m uvicorn main:app --port 7432")
    sys.exit(1)

try:
    r = requests.get(f"{LOJA_URL}/api/products", timeout=3)
    check("Fazendinha E-commerce respondendo (porta 8000)", r.status_code == 200,
          f"{len(r.json())} produtos encontrados")
except Exception as e:
    check("Fazendinha E-commerce respondendo (porta 8000)", False, str(e))
    print("\n⛔ Fazendinha não está rodando. Inicie com: cd fazendinha-ecommerce && python3 -m uvicorn app:app --port 8000")
    sys.exit(1)

# ─────────────────────────────────────────────────────────────
# CENÁRIO 1: NOVO USUÁRIO
# ─────────────────────────────────────────────────────────────
section("CENÁRIO 1: Novo Usuário — Cadastro e Ativação")

FRASE = "tigre-azul-montanha-42"
address = None
mnemonic = None

# 1.1 Status inicial sem identidade
r = requests.get(f"{APP_URL}/status")
check("Status inicial: sem identidade", not r.json()["has_identity"])

# 1.2 Cadastro com frase de segurança
payload = {"email": "teste@fazendinha.com", "phone": "+55 11 99999-0001", "phrase": FRASE}
r = requests.post(f"{APP_URL}/identity/register", json=payload)
check("POST /identity/register retorna 200", r.status_code == 200, r.text[:120])

if r.status_code == 200:
    data = r.json()
    address = data.get("address")
    mnemonic = data.get("mnemonic")
    check("Endereço Ethereum gerado (0x...)", bool(address) and address.startswith("0x"),
          f"Endereço: {address}")
    check("Mnemônico gerado (12 palavras)", bool(mnemonic) and len(mnemonic.split()) == 12,
          f"Mnemônico: {mnemonic[:40]}...")
    check("Frase de segurança retornada", data.get("phrase") == FRASE)

# 1.3 Tentativa de uso antes da ativação (deve falhar)
r = requests.post(f"{APP_URL}/wallet/sign", json={"phrase": FRASE, "message": "teste"})
check("Assinar antes de ativar retorna 403", r.status_code == 403,
      f"Resposta: {r.json().get('detail','')}")

# 1.4 Confirmação/ativação da identidade
if address:
    r = requests.post(f"{APP_URL}/identity/confirm", json={"address": address})
    check("POST /identity/confirm retorna 200", r.status_code == 200, r.text)

# 1.5 Status após ativação
r = requests.get(f"{APP_URL}/status")
data = r.json()
check("Status após ativação: has_identity=True", data.get("has_identity") is True)
check("Endereço correto no status", data.get("address") == address,
      f"Endereço: {data.get('address')}")

# ─────────────────────────────────────────────────────────────
# CENÁRIO 2: USUÁRIO EXISTENTE — COMPRA ASSINADA
# ─────────────────────────────────────────────────────────────
section("CENÁRIO 2: Usuário Existente — Assinatura de Pedido e Verificação")

# 2.1 Frase incorreta deve ser rejeitada
r = requests.post(f"{APP_URL}/wallet/sign", json={"phrase": "frase-errada-123", "message": "teste"})
check("Frase incorreta retorna 401", r.status_code == 401,
      f"Detalhe: {r.json().get('detail','')}")

# 2.2 Assinar mensagem simples com frase correta
r = requests.post(f"{APP_URL}/wallet/sign", json={"phrase": FRASE, "message": "Olá, CheckoutSeguro!"})
check("POST /wallet/sign com frase correta retorna 200", r.status_code == 200)
if r.status_code == 200:
    sig_data = r.json()
    sig = sig_data.get("signature","")
    check("Assinatura gerada (hex 65 bytes)", len(sig) == 130,
          f"Sig: {sig[:40]}... (len={len(sig)})")

# 2.3 Simular checkout completo
import uuid
order_id = f"ORD-TEST-{uuid.uuid4().hex[:8].upper()}"
cart_items = [
    {"id": 1, "name": "Cesta de Orgânicos Premium", "price": 89.90, "qty": 1},
    {"id": 3, "name": "Ovos Caipiras (12 un)", "price": 18.00, "qty": 2},
]
amount = sum(i["price"] * i["qty"] for i in cart_items)
cart_data = json.dumps({"orderId": order_id, "amount": amount, "items": cart_items, "storeId": "fazendinha-organica"})
cart_hash = hashlib.sha256(cart_data.encode()).hexdigest()

sign_payload = {
    "phrase": FRASE,
    "order_id": order_id,
    "store_id": "fazendinha-organica",
    "cart_hash": cart_hash,
    "amount": amount,
    "items": cart_items,
    "store_callback_url": f"{LOJA_URL}/api/verify-order"
}
r = requests.post(f"{APP_URL}/wallet/sign-order", json=sign_payload)
check("POST /wallet/sign-order retorna 200", r.status_code == 200, r.text[:120])

signature = None
order_payload = None
if r.status_code == 200:
    order_data = r.json()
    signature = order_data.get("signature")
    order_payload = order_data.get("order_payload")
    check("Assinatura do pedido gerada (hex 65 bytes)", bool(signature) and len(signature) == 130,
          f"Sig: {signature[:40]}... (len={len(signature)})")
    check("Payload do pedido retornado", bool(order_payload))

# 2.4 Verificar pedido na loja (Fazendinha)
if signature and order_payload:
    verify_payload = {
        "orderId": order_id,
        "address": address or "",
        "signature": signature,
        "orderPayload": order_payload
    }
    r = requests.post(f"{LOJA_URL}/api/verify-order", json=verify_payload)
    check("POST /api/verify-order na loja retorna 200", r.status_code == 200, r.text[:120])
    if r.status_code == 200:
        vdata = r.json()
        check("Loja confirma assinatura como VÁLIDA", vdata.get("valid") is True)
        check("Endereço recuperado pela loja corresponde ao comprador",
              vdata.get("recoveredAddress","").lower() == address.lower(),
              f"Recuperado: {vdata.get('recoveredAddress')}")

# 2.5 Pedido registrado no banco da loja
r = requests.get(f"{LOJA_URL}/api/orders")
orders = r.json()
order_found = any(o["order_id"] == order_id for o in orders)
check("Pedido registrado no banco da loja", order_found,
      f"Total de pedidos: {len(orders)}")

# 2.6 Pedido registrado no histórico do app local
r = requests.get(f"{APP_URL}/purchases")
purchases = r.json()
purchase_found = any(p["order_id"] == order_id for p in purchases)
check("Compra registrada no histórico local do usuário", purchase_found,
      f"Total de compras: {len(purchases)}")

# 2.7 Teste de não-repúdio: assinatura com endereço errado deve falhar
if signature and order_payload:
    fake_address = "0x" + "a" * 40
    r = requests.post(f"{LOJA_URL}/api/verify-order", json={
        "orderId": order_id,
        "address": fake_address,
        "signature": signature,
        "orderPayload": order_payload
    })
    if r.status_code == 200:
        check("Endereço falso rejeitado (non-repudiation)", not r.json().get("valid"),
              f"valid={r.json().get('valid')}")
    else:
        check("Endereço falso rejeitado (non-repudiation)", r.status_code in [401, 400])

# ─────────────────────────────────────────────────────────────
# RESUMO
# ─────────────────────────────────────────────────────────────
section("RESUMO DOS TESTES")
passed = sum(1 for _, ok in results if ok)
total = len(results)
failed = total - passed
print(f"\n  Total: {total} | ✅ Passou: {passed} | ❌ Falhou: {failed}")
if failed == 0:
    print("\n  🎉 Todos os testes passaram! Sistema funcionando corretamente.")
else:
    print(f"\n  ⚠️  {failed} teste(s) falharam. Verifique os logs acima.")
print()
sys.exit(0 if failed == 0 else 1)
