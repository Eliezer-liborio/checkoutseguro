/**
 * CheckoutSeguro — Content Script
 * Detecta eventos de checkout nas lojas parceiras e injeta o modal de assinatura.
 */

const APP_URL = 'http://localhost:7432';

// Escuta mensagens do Partner SDK (lojas parceiras)
window.addEventListener('message', async (event) => {
  if (event.data?.type !== 'CHECKOUTSEGURO_CHECKOUT') return;

  const { orderId, storeId, cartHash, amount, items, callbackUrl } = event.data.payload;

  // Verifica se o app local está rodando
  let status;
  try {
    const res = await fetch(`${APP_URL}/status`, { signal: AbortSignal.timeout(3000) });
    status = await res.json();
  } catch {
    showModal({
      type: 'error',
      title: 'App não encontrado',
      message: 'Inicie o CheckoutSeguro no seu computador para assinar compras.',
      orderId, storeId, amount, items, cartHash, callbackUrl
    });
    return;
  }

  if (!status.has_identity) {
    showModal({
      type: 'no-identity',
      title: 'Identidade não encontrada',
      message: 'Crie sua identidade CheckoutSeguro para continuar.',
      orderId, storeId, amount, items, cartHash, callbackUrl
    });
    return;
  }

  // Exibe modal de confirmação de compra
  showModal({
    type: 'confirm',
    title: 'Confirmar Compra',
    address: status.address,
    orderId, storeId, amount, items, cartHash, callbackUrl
  });
});

function showModal(opts) {
  // Remove modal anterior se existir
  const existing = document.getElementById('cs-modal-overlay');
  if (existing) existing.remove();

  const overlay = document.createElement('div');
  overlay.id = 'cs-modal-overlay';
  overlay.style.cssText = `
    position:fixed; top:0; left:0; width:100%; height:100%;
    background:rgba(0,0,0,0.75); z-index:999999;
    display:flex; align-items:center; justify-content:center;
    font-family:'Segoe UI',system-ui,sans-serif;
  `;

  const modal = document.createElement('div');
  modal.style.cssText = `
    background:#111827; border:1px solid #1e293b; border-radius:16px;
    padding:28px; width:380px; max-width:95vw; color:#f1f5f9;
    box-shadow:0 25px 50px rgba(0,0,0,0.5);
  `;

  if (opts.type === 'confirm') {
    modal.innerHTML = `
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:20px">
        <div style="width:36px;height:36px;background:linear-gradient(135deg,#38bdf8,#a78bfa);border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:18px">🔐</div>
        <div>
          <div style="font-weight:700;font-size:1rem">CheckoutSeguro</div>
          <div style="font-size:0.72rem;color:#64748b">Assinatura de compra</div>
        </div>
        <button id="cs-close" style="margin-left:auto;background:none;border:none;color:#64748b;font-size:1.2rem;cursor:pointer">✕</button>
      </div>
      <div style="background:#0a0f1e;border-radius:10px;padding:14px;margin-bottom:16px">
        <div style="font-size:0.7rem;color:#64748b;text-transform:uppercase;margin-bottom:4px">Loja</div>
        <div style="font-weight:600;color:#38bdf8">${opts.storeId}</div>
        <div style="font-size:0.7rem;color:#64748b;text-transform:uppercase;margin-top:10px;margin-bottom:4px">Valor Total</div>
        <div style="font-size:1.4rem;font-weight:700;color:#34d399">R$ ${Number(opts.amount).toFixed(2)}</div>
        <div style="font-size:0.7rem;color:#64748b;text-transform:uppercase;margin-top:10px;margin-bottom:4px">Sua Identidade</div>
        <div style="font-family:monospace;font-size:0.72rem;color:#a78bfa;word-break:break-all">${opts.address}</div>
      </div>
      <div style="margin-bottom:16px">
        <label style="display:block;font-size:0.72rem;color:#64748b;text-transform:uppercase;margin-bottom:6px">Frase de Segurança</label>
        <input id="cs-phrase" type="password" placeholder="Digite sua frase de segurança"
          style="width:100%;background:#0a0f1e;border:1px solid #1e293b;border-radius:8px;padding:10px 14px;color:#f1f5f9;font-size:0.9rem;outline:none">
      </div>
      <button id="cs-confirm" style="width:100%;padding:12px;background:linear-gradient(135deg,#38bdf8,#a78bfa);border:none;border-radius:10px;font-size:0.95rem;font-weight:700;color:#0a0f1e;cursor:pointer">
        🔐 Assinar e Confirmar Compra
      </button>
      <div id="cs-alert" style="margin-top:10px;font-size:0.82rem;display:none"></div>
    `;
  } else if (opts.type === 'error' || opts.type === 'no-identity') {
    const color = opts.type === 'error' ? '#f87171' : '#f59e0b';
    const bg = opts.type === 'error' ? '#2d0f0f' : '#1c1208';
    modal.innerHTML = `
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:16px">
        <div style="width:36px;height:36px;background:linear-gradient(135deg,#38bdf8,#a78bfa);border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:18px">🔐</div>
        <div style="font-weight:700">CheckoutSeguro</div>
        <button id="cs-close" style="margin-left:auto;background:none;border:none;color:#64748b;font-size:1.2rem;cursor:pointer">✕</button>
      </div>
      <div style="background:${bg};border:1px solid ${color};border-radius:8px;padding:12px;color:${color};font-size:0.85rem;margin-bottom:16px">
        <strong>${opts.title}</strong><br>${opts.message}
      </div>
      <button onclick="window.open('http://localhost:7432')" style="width:100%;padding:10px;background:transparent;border:1px solid #1e293b;border-radius:8px;color:#f1f5f9;cursor:pointer;font-size:0.88rem">
        Abrir CheckoutSeguro
      </button>
    `;
  }

  overlay.appendChild(modal);
  document.body.appendChild(overlay);

  // Fechar ao clicar fora ou no X
  overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
  const closeBtn = document.getElementById('cs-close');
  if (closeBtn) closeBtn.addEventListener('click', () => overlay.remove());

  // Lógica de confirmação
  const confirmBtn = document.getElementById('cs-confirm');
  if (confirmBtn) {
    confirmBtn.addEventListener('click', async () => {
      const phrase = document.getElementById('cs-phrase').value;
      const alertEl = document.getElementById('cs-alert');
      if (!phrase) {
        showAlert(alertEl, 'error', 'Digite sua frase de segurança.');
        return;
      }
      confirmBtn.disabled = true;
      confirmBtn.textContent = 'Assinando...';
      hideAlert(alertEl);

      try {
        const res = await fetch(`${APP_URL}/wallet/sign-order`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            phrase,
            order_id: opts.orderId,
            store_id: opts.storeId,
            cart_hash: opts.cartHash,
            amount: opts.amount,
            items: opts.items,
            store_callback_url: opts.callbackUrl
          })
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.detail || 'Erro ao assinar.');

        // Envia o resultado de volta para a loja
        window.postMessage({
          type: 'CHECKOUTSEGURO_SIGNED',
          payload: {
            orderId: data.order_id,
            address: data.address,
            signature: data.signature,
            orderPayload: data.order_payload
          }
        }, '*');

        // Exibe sucesso
        modal.innerHTML = `
          <div style="text-align:center;padding:20px">
            <div style="font-size:2.5rem;margin-bottom:12px">✅</div>
            <div style="font-size:1.1rem;font-weight:700;color:#34d399;margin-bottom:8px">Compra Confirmada!</div>
            <div style="font-size:0.82rem;color:#64748b;margin-bottom:16px">Pedido assinado criptograficamente.</div>
            <div style="font-family:monospace;font-size:0.7rem;color:#a78bfa;word-break:break-all;background:#0a0f1e;padding:8px;border-radius:6px">
              ${data.signature.slice(0, 40)}...
            </div>
            <button onclick="document.getElementById('cs-modal-overlay').remove()"
              style="margin-top:16px;width:100%;padding:10px;background:transparent;border:1px solid #1e293b;border-radius:8px;color:#f1f5f9;cursor:pointer">
              Fechar
            </button>
          </div>
        `;
      } catch (e) {
        showAlert(alertEl, 'error', e.message);
        confirmBtn.disabled = false;
        confirmBtn.textContent = '🔐 Assinar e Confirmar Compra';
      }
    });
  }
}

function showAlert(el, type, msg) {
  const colors = { error: '#f87171', warn: '#f59e0b', success: '#34d399' };
  const bgs = { error: '#2d0f0f', warn: '#1c1208', success: '#052e16' };
  el.style.display = 'block';
  el.style.background = bgs[type];
  el.style.border = `1px solid ${colors[type]}`;
  el.style.color = colors[type];
  el.style.padding = '8px 12px';
  el.style.borderRadius = '6px';
  el.textContent = msg;
}
function hideAlert(el) { el.style.display = 'none'; }
