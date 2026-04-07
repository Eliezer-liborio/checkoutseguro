"""
Fazendinha E-commerce — Laboratório de Testes CheckoutSeguro
Loja de produtos orgânicos fictícia para testar o fluxo de compra assinada.
"""
import json
import hashlib
import sqlite3
import logging
from pathlib import Path
from datetime import datetime, timezone

from eth_account import Account
from eth_account.messages import encode_defunct
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("fazendinha")

BASE_DIR = Path(__file__).parent
STATIC_DIR = BASE_DIR / "static"
DB_PATH = BASE_DIR / "orders.db"

# ── Banco de dados ─────────────────────────────────────────────────────────────
def get_db():
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    with get_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS orders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id TEXT UNIQUE NOT NULL,
                buyer_address TEXT NOT NULL,
                signature TEXT NOT NULL,
                cart_hash TEXT NOT NULL,
                amount REAL NOT NULL,
                items TEXT NOT NULL,
                status TEXT DEFAULT 'confirmed',
                created_at TEXT NOT NULL
            )
        """)
        conn.commit()

# ── App ────────────────────────────────────────────────────────────────────────
app = FastAPI(title="Fazendinha E-commerce", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

@app.on_event("startup")
def startup():
    init_db()
    logger.info("Fazendinha E-commerce iniciado em http://localhost:8000")

@app.get("/", response_class=HTMLResponse)
def root():
    return FileResponse(str(STATIC_DIR / "index.html"))

@app.get("/api/products")
def get_products():
    return [
        {"id": 1, "name": "Cesta de Orgânicos Premium", "price": 89.90, "emoji": "🧺", "desc": "Frutas e verduras frescas da fazenda"},
        {"id": 2, "name": "Mel Puro de Abelha", "price": 34.50, "emoji": "🍯", "desc": "Mel artesanal, 500g"},
        {"id": 3, "name": "Ovos Caipiras (12 un)", "price": 18.00, "emoji": "🥚", "desc": "Ovos de galinha caipira"},
        {"id": 4, "name": "Queijo Colonial", "price": 45.00, "emoji": "🧀", "desc": "Queijo artesanal curado 30 dias"},
        {"id": 5, "name": "Geleia de Morango", "price": 22.00, "emoji": "🍓", "desc": "Geleia caseira sem conservantes"},
        {"id": 6, "name": "Azeite Extra Virgem", "price": 67.00, "emoji": "🫒", "desc": "Azeite prensado a frio, 500ml"},
    ]

class VerifyOrderRequest(BaseModel):
    orderId: str
    address: str
    signature: str
    orderPayload: str

@app.post("/api/verify-order")
def verify_order(req: VerifyOrderRequest):
    """
    Verifica a assinatura criptográfica do pedido.
    Se válida, registra o pedido no banco de dados da loja.
    """
    init_db()
    try:
        msg = encode_defunct(text=req.orderPayload)
        recovered = Account.recover_message(msg, signature=req.signature)
        valid = recovered.lower() == req.address.lower()
    except Exception as e:
        raise HTTPException(400, f"Erro na verificação da assinatura: {e}")

    if not valid:
        raise HTTPException(401, "Assinatura inválida. Endereço não corresponde.")

    # Extrai dados do payload
    try:
        payload_data = json.loads(req.orderPayload)
    except Exception:
        raise HTTPException(400, "Payload do pedido malformado.")

    # Persiste o pedido com a prova criptográfica
    with get_db() as conn:
        try:
            conn.execute("""
                INSERT INTO orders (order_id, buyer_address, signature, cart_hash, amount, items, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                req.orderId,
                req.address,
                req.signature,
                payload_data.get("cart_hash", ""),
                payload_data.get("amount", 0),
                json.dumps(payload_data.get("items", [])),
                datetime.now(timezone.utc).isoformat()
            ))
            conn.commit()
        except sqlite3.IntegrityError:
            pass  # Pedido já registrado (idempotente)

    logger.info("Pedido %s verificado e registrado. Comprador: %s", req.orderId, req.address)

    return {
        "valid": True,
        "orderId": req.orderId,
        "buyerAddress": req.address,
        "message": "Pedido confirmado com assinatura criptográfica válida.",
        "recoveredAddress": recovered
    }

@app.get("/api/orders")
def list_orders():
    """Lista todos os pedidos confirmados (para o painel da loja)."""
    init_db()
    with get_db() as conn:
        rows = conn.execute(
            "SELECT order_id, buyer_address, amount, status, created_at FROM orders ORDER BY created_at DESC"
        ).fetchall()
    return [dict(r) for r in rows]

@app.get("/api/orders/{order_id}")
def get_order(order_id: str):
    """Retorna detalhes de um pedido específico."""
    with get_db() as conn:
        row = conn.execute("SELECT * FROM orders WHERE order_id=?", (order_id,)).fetchone()
    if not row:
        raise HTTPException(404, "Pedido não encontrado.")
    return dict(row)
