"""
CheckoutSeguro — App Local
Servidor FastAPI que roda na máquina do usuário (localhost:7432).
A chave privada NUNCA sai do hardware do usuário.
"""
import os
import json
import logging
import sqlite3
import secrets
import hashlib
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Optional

import bcrypt
from eth_account import Account
from eth_account.messages import encode_defunct
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel

# ── Configuração ──────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("checkoutseguro")

BASE_DIR = Path(__file__).parent
UI_DIR = BASE_DIR / "ui"
DB_PATH = BASE_DIR / "wallet" / "identity.db"
DB_PATH.parent.mkdir(parents=True, exist_ok=True)

# Nonce store em memória: {nonce: {address, expires_at, order_data}}
nonce_store: dict = {}
NONCE_TTL = 300  # 5 minutos

# ── Banco de dados local ───────────────────────────────────────────────────────
def get_db():
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    with get_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS identity (
                id INTEGER PRIMARY KEY,
                address TEXT UNIQUE NOT NULL,
                encrypted_key TEXT NOT NULL,
                phrase_hash TEXT NOT NULL,
                mnemonic_enc TEXT NOT NULL,
                email TEXT,
                phone TEXT,
                created_at TEXT NOT NULL,
                activated INTEGER DEFAULT 0
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS purchases (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id TEXT UNIQUE NOT NULL,
                address TEXT NOT NULL,
                store_id TEXT NOT NULL,
                cart_hash TEXT NOT NULL,
                signature TEXT NOT NULL,
                amount REAL NOT NULL,
                items TEXT NOT NULL,
                timestamp TEXT NOT NULL
            )
        """)
        conn.commit()
    logger.info("Banco de dados local inicializado em %s", DB_PATH)

# ── Criptografia local ─────────────────────────────────────────────────────────
def _derive_key(phrase: str, salt: bytes) -> bytes:
    """Deriva uma chave AES-256 da frase de segurança usando PBKDF2."""
    import hashlib
    return hashlib.pbkdf2_hmac("sha256", phrase.encode(), salt, 200_000)

def encrypt_private_key(private_key_hex: str, phrase: str) -> str:
    """Criptografa a chave privada com a frase de segurança (AES-256-GCM via Fernet)."""
    from cryptography.fernet import Fernet
    import base64
    salt = secrets.token_bytes(16)
    key = base64.urlsafe_b64encode(_derive_key(phrase, salt))
    f = Fernet(key)
    encrypted = f.encrypt(private_key_hex.encode())
    # Armazena: salt_hex:encrypted_b64
    return salt.hex() + ":" + encrypted.decode()

def decrypt_private_key(encrypted_data: str, phrase: str) -> str:
    """Descriptografa a chave privada usando a frase de segurança."""
    from cryptography.fernet import Fernet, InvalidToken
    import base64
    try:
        salt_hex, encrypted_b64 = encrypted_data.split(":", 1)
        salt = bytes.fromhex(salt_hex)
        key = base64.urlsafe_b64encode(_derive_key(phrase, salt))
        f = Fernet(key)
        return f.decrypt(encrypted_b64.encode()).decode()
    except (InvalidToken, Exception):
        raise ValueError("Frase de segurança incorreta ou dados corrompidos.")

def generate_security_phrase() -> str:
    """Gera uma frase de segurança memorizável de 4 palavras + número."""
    words = [
        "tigre","leão","cobra","águia","lobo","urso","raposa","puma",
        "azul","verde","roxo","dourado","negro","branco","prata","coral",
        "monte","vale","rio","pedra","nuvem","vento","fogo","gelo",
        "forte","veloz","sábio","bravo","calmo","livre","firme","claro"
    ]
    chosen = secrets.SystemRandom().sample(words, 3)
    num = secrets.randbelow(90) + 10
    return f"{chosen[0]}-{chosen[1]}-{chosen[2]}-{num}"

# ── App FastAPI ────────────────────────────────────────────────────────────────
app = FastAPI(
    title="CheckoutSeguro — App Local",
    description="Servidor local de identidade Web3 para e-commerce. Roda no seu hardware.",
    version="1.0.0",
    docs_url="/docs"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Extensão e lojas parceiras
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Servir UI estática
if UI_DIR.exists():
    app.mount("/ui", StaticFiles(directory=str(UI_DIR), html=True), name="ui")

@app.on_event("startup")
def startup():
    init_db()
    logger.info("CheckoutSeguro iniciado em http://localhost:7432")

# ── Modelos ────────────────────────────────────────────────────────────────────
class RegisterRequest(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None
    phrase: str  # Frase de segurança escolhida pelo usuário

class ConfirmRequest(BaseModel):
    address: str

class SignRequest(BaseModel):
    phrase: str
    message: str  # Mensagem SIWE ou hash do pedido

class SignOrderRequest(BaseModel):
    phrase: str
    order_id: str
    store_id: str
    cart_hash: str
    amount: float
    items: list
    store_callback_url: str

class VerifyOrderRequest(BaseModel):
    order_id: str
    address: str
    cart_hash: str
    signature: str
    amount: float
    items: list
    store_id: str

# ── Endpoints ─────────────────────────────────────────────────────────────────
@app.get("/", response_class=HTMLResponse)
def root():
    return FileResponse(str(UI_DIR / "index.html"))

@app.get("/status")
def status():
    """Verifica se o app está rodando (usado pela extensão e lojas)."""
    init_db()  # garante que as tabelas existem
    with get_db() as conn:
        row = conn.execute("SELECT address, email, activated FROM identity LIMIT 1").fetchone()
    if row and row["activated"]:
        return {
            "running": True,
            "has_identity": True,
            "address": row["address"],
            "email": row["email"]
        }
    return {"running": True, "has_identity": False}

@app.post("/identity/register")
def register(req: RegisterRequest):
    """Cria uma nova identidade Web3 localmente."""
    with get_db() as conn:
        existing = conn.execute("SELECT id FROM identity LIMIT 1").fetchone()
        if existing:
            raise HTTPException(400, "Identidade já existe neste dispositivo. Use /identity/status.")

    # Gera carteira Ethereum
    Account.enable_unaudited_hdwallet_features()
    acct, mnemonic = Account.create_with_mnemonic()
    address = acct.address
    private_key_hex = acct.key.hex()

    # Criptografa a chave privada com a frase de segurança
    encrypted_key = encrypt_private_key(private_key_hex, req.phrase)
    encrypted_mnemonic = encrypt_private_key(mnemonic, req.phrase)

    # Hash da frase para validação futura
    phrase_hash = bcrypt.hashpw(req.phrase.encode(), bcrypt.gensalt()).decode()

    with get_db() as conn:
        conn.execute("""
            INSERT INTO identity (address, encrypted_key, phrase_hash, mnemonic_enc, email, phone, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (address, encrypted_key, phrase_hash, encrypted_mnemonic,
              req.email, req.phone, datetime.now(timezone.utc).isoformat()))
        conn.commit()

    logger.info("Nova identidade criada: %s", address)
    return {
        "address": address,
        "mnemonic": mnemonic,
        "phrase": req.phrase,
        "message": "Guarde o mnemônico e a frase de segurança em local seguro. Não os compartilhe."
    }

@app.post("/identity/confirm")
def confirm_identity(req: ConfirmRequest):
    """Marca a identidade como ativada após o usuário confirmar que salvou as credenciais."""
    with get_db() as conn:
        result = conn.execute(
            "UPDATE identity SET activated=1 WHERE address=?", (req.address,)
        )
        conn.commit()
        if result.rowcount == 0:
            raise HTTPException(404, "Identidade não encontrada.")
    return {"confirmed": True, "address": req.address}

@app.get("/identity/info")
def identity_info():
    """Retorna informações públicas da identidade local."""
    with get_db() as conn:
        row = conn.execute("SELECT address, email, phone, created_at, activated FROM identity LIMIT 1").fetchone()
    if not row:
        raise HTTPException(404, "Nenhuma identidade encontrada. Faça o cadastro primeiro.")
    return dict(row)

@app.post("/wallet/sign")
def sign_message(req: SignRequest):
    """Assina uma mensagem com a chave privada local (requer frase de segurança)."""
    with get_db() as conn:
        row = conn.execute("SELECT encrypted_key, phrase_hash, address, activated FROM identity LIMIT 1").fetchone()
    if not row:
        raise HTTPException(404, "Nenhuma identidade encontrada.")
    if not row["activated"]:
        raise HTTPException(403, "Identidade não ativada. Confirme o cadastro primeiro.")

    # Valida a frase de segurança
    if not bcrypt.checkpw(req.phrase.encode(), row["phrase_hash"].encode()):
        raise HTTPException(401, "Frase de segurança incorreta.")

    # Descriptografa e assina (chave fica apenas em memória)
    try:
        private_key = decrypt_private_key(row["encrypted_key"], req.phrase)
    except ValueError as e:
        raise HTTPException(401, str(e))

    msg = encode_defunct(text=req.message)
    signed = Account.sign_message(msg, private_key=private_key)
    private_key = None  # Limpa da memória imediatamente

    logger.info("Mensagem assinada para %s", row["address"])
    return {
        "address": row["address"],
        "signature": signed.signature.hex(),
        "message": req.message
    }

@app.post("/wallet/sign-order")
def sign_order(req: SignOrderRequest):
    """Assina um pedido de compra e registra localmente."""
    with get_db() as conn:
        row = conn.execute("SELECT encrypted_key, phrase_hash, address, activated FROM identity LIMIT 1").fetchone()
    if not row:
        raise HTTPException(404, "Nenhuma identidade encontrada.")
    if not row["activated"]:
        raise HTTPException(403, "Identidade não ativada.")

    # Valida frase
    if not bcrypt.checkpw(req.phrase.encode(), row["phrase_hash"].encode()):
        raise HTTPException(401, "Frase de segurança incorreta.")

    # Monta o payload do pedido para assinar
    order_payload = json.dumps({
        "order_id": req.order_id,
        "store_id": req.store_id,
        "cart_hash": req.cart_hash,
        "amount": req.amount,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }, sort_keys=True)

    # Assina
    try:
        private_key = decrypt_private_key(row["encrypted_key"], req.phrase)
    except ValueError as e:
        raise HTTPException(401, str(e))

    msg = encode_defunct(text=order_payload)
    signed = Account.sign_message(msg, private_key=private_key)
    private_key = None  # Limpa da memória
    signature = signed.signature.hex()

    # Persiste o recibo localmente
    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO purchases
            (order_id, address, store_id, cart_hash, signature, amount, items, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (req.order_id, row["address"], req.store_id, req.cart_hash,
              signature, req.amount, json.dumps(req.items),
              datetime.now(timezone.utc).isoformat()))
        conn.commit()

    logger.info("Pedido %s assinado para loja %s", req.order_id, req.store_id)

    return {
        "order_id": req.order_id,
        "address": row["address"],
        "signature": signature,
        "order_payload": order_payload,
        "store_callback_url": req.store_callback_url
    }

@app.get("/purchases")
def list_purchases():
    """Lista o histórico de compras assinadas neste dispositivo."""
    with get_db() as conn:
        rows = conn.execute(
            "SELECT order_id, store_id, amount, timestamp FROM purchases ORDER BY timestamp DESC"
        ).fetchall()
    return [dict(r) for r in rows]

@app.post("/verify-order")
def verify_order(req: VerifyOrderRequest):
    """
    Endpoint público: verifica se uma assinatura de pedido é válida.
    Usado pelas lojas parceiras para validar a autenticidade da compra.
    """
    order_payload = json.dumps({
        "order_id": req.order_id,
        "store_id": req.store_id,
        "cart_hash": req.cart_hash,
        "amount": req.amount,
        "timestamp": req.items[0].get("timestamp") if req.items else ""
    }, sort_keys=True)

    try:
        msg = encode_defunct(text=order_payload)
        recovered = Account.recover_message(msg, signature=req.signature)
        valid = recovered.lower() == req.address.lower()
    except Exception as e:
        raise HTTPException(400, f"Erro na verificação: {e}")

    return {
        "valid": valid,
        "recovered_address": recovered,
        "claimed_address": req.address,
        "order_id": req.order_id
    }
