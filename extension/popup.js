const APP_URL = 'http://localhost:7432';

async function init() {
  try {
    const res = await fetch(`${APP_URL}/status`, { signal: AbortSignal.timeout(3000) });
    const data = await res.json();
    document.getElementById('state-loading').style.display = 'none';
    document.getElementById('dot').classList.add('ok');

    if (data.has_identity) {
      document.getElementById('state-active').style.display = 'block';
      document.getElementById('popup-address').textContent = data.address;
    } else {
      document.getElementById('state-no-identity').style.display = 'block';
    }
  } catch (e) {
    document.getElementById('state-loading').style.display = 'none';
    document.getElementById('state-no-app').style.display = 'block';
    document.getElementById('dot').classList.add('err');
  }
}

init();
