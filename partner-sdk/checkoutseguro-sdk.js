/**
 * CheckoutSeguro Partner SDK v1.0.0
 * Adicione em qualquer loja para habilitar compras assinadas criptograficamente.
 *
 * Uso:
 *   <script src="checkoutseguro-sdk.js" data-store-id="minha-loja"></script>
 *   CheckoutSeguro.init({ storeId: 'minha-loja', verifyUrl: '/api/verify-order' });
 */

(function (global) {
  'use strict';

  const APP_URL = 'http://localhost:7432';

  const SDK = {
    storeId: null,
    verifyUrl: null,
    onSuccess: null,
    onError: null,

    /**
     * Inicializa o SDK.
     * @param {object} opts - { storeId, verifyUrl, onSuccess, onError }
     */
    init(opts = {}) {
      this.storeId = opts.storeId || document.currentScript?.dataset?.storeId || 'unknown-store';
      this.verifyUrl = opts.verifyUrl || '/api/verify-order';
      this.onSuccess = opts.onSuccess || null;
      this.onError = opts.onError || null;

      // Escuta respostas da extensão
      window.addEventListener('message', (event) => {
        if (event.data?.type === 'CHECKOUTSEGURO_SIGNED') {
          this._handleSigned(event.data.payload);
        }
      });

      console.log(`[CheckoutSeguro] SDK inicializado para loja: ${this.storeId}`);
    },

    /**
     * Dispara o fluxo de checkout assinado.
     * @param {object} order - { orderId, amount, items }
     */
    async checkout(order) {
      const { orderId, amount, items } = order;

      // Gera hash do carrinho
      const cartData = JSON.stringify({ orderId, amount, items, storeId: this.storeId });
      const cartHash = await this._sha256(cartData);

      // Envia evento para a extensão via postMessage
      window.postMessage({
        type: 'CHECKOUTSEGURO_CHECKOUT',
        payload: {
          orderId,
          storeId: this.storeId,
          cartHash,
          amount,
          items,
          callbackUrl: window.location.origin + this.verifyUrl
        }
      }, '*');
    },

    /**
     * Verifica a assinatura de um pedido no backend da loja.
     * Chamado automaticamente após receber CHECKOUTSEGURO_SIGNED.
     */
    async _handleSigned(payload) {
      const { orderId, address, signature, orderPayload } = payload;

      try {
        const res = await fetch(this.verifyUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ orderId, address, signature, orderPayload })
        });
        const data = await res.json();

        if (data.valid) {
          console.log(`[CheckoutSeguro] Pedido ${orderId} verificado com sucesso.`);
          if (this.onSuccess) this.onSuccess({ orderId, address, signature });
        } else {
          throw new Error('Assinatura inválida retornada pelo servidor.');
        }
      } catch (e) {
        console.error('[CheckoutSeguro] Erro na verificação:', e.message);
        if (this.onError) this.onError(e);
      }
    },

    async _sha256(message) {
      const msgBuffer = new TextEncoder().encode(message);
      const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    }
  };

  global.CheckoutSeguro = SDK;
})(window);
