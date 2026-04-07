// CheckoutSeguro — Service Worker
// Verifica periodicamente se o app local está rodando e atualiza o ícone da extensão.

const APP_URL = 'http://localhost:7432';

async function checkAppStatus() {
  try {
    const res = await fetch(`${APP_URL}/status`, { signal: AbortSignal.timeout(2000) });
    const data = await res.json();
    // Ícone verde se ativo, cinza se sem identidade
    chrome.action.setBadgeText({ text: data.has_identity ? '✓' : '!' });
    chrome.action.setBadgeBackgroundColor({ color: data.has_identity ? '#34d399' : '#f59e0b' });
  } catch {
    chrome.action.setBadgeText({ text: '✕' });
    chrome.action.setBadgeBackgroundColor({ color: '#f87171' });
  }
}

// Verifica a cada 30 segundos
checkAppStatus();
setInterval(checkAppStatus, 30000);

// Escuta mensagens da extensão
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === 'CHECK_STATUS') {
    checkAppStatus().then(() => sendResponse({ ok: true }));
    return true;
  }
});
