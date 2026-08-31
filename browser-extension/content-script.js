(function () {
  const REQUEST = 'workbench-extension-request';
  const RESPONSE = 'workbench-extension-response';
  const isWorkbench = location.hostname === '127.0.0.1' || location.hostname === 'localhost';

  if (isWorkbench) {
    window.addEventListener('message', (event) => {
      if (event.source !== window) return;
      const data = typeof event.data === 'string' ? parseJson(event.data) : event.data;
      if (data?.type !== REQUEST) return;
      chrome.runtime.sendMessage({
        type: 'workbench-request',
        requestId: data.requestId,
        action: data.action,
        payload: data.payload || {},
      });
    });
    chrome.runtime.onMessage.addListener((message) => {
      if (message?.type !== 'workbench-response') return;
      window.postMessage({
        type: RESPONSE,
        requestId: message.requestId,
        response: message.response,
      }, location.origin);
    });
    return;
  }

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message?.type !== 'boss-action') return;
    handle(message.action, message.payload || {}).then(sendResponse);
    return true;
  });

  async function handle(action, payload) {
    if (action === 'check_login') return checkLogin();
    if (action === 'read_visible_jobs') return readVisibleJobs(payload);
    if (action === 'assist_apply') return assistApply(payload);
    return {ok: false, error: 'unsupported_action'};
  }

  function checkLogin() {
    const loginMarkers = ['.header-nav-user', '.user-nav', '[class*="user-info"]', '[class*="avatar"]'];
    const loggedIn = loginMarkers.some((selector) => document.querySelector(selector));
    return {ok: true, platform: 'BOSS 直聘', loggedIn, url: location.href};
  }

  function readVisibleJobs(payload) {
    const keywordList = Array.isArray(payload.keywords) ? payload.keywords.map(normalize) : [];
    const cityList = Array.isArray(payload.cities) ? payload.cities.map(normalize) : [];
    const cards = [...document.querySelectorAll('.job-card-wrapper, .job-card, .job-list li, [class*="job-card"]')];
    const unique = new Set();
    const items = [];
    for (const card of cards) {
      const text = normalize(card.innerText || '');
      if (!text || unique.has(text)) continue;
      if (keywordList.length && !keywordList.some((item) => text.includes(item))) continue;
      if (cityList.length && !cityList.some((item) => text.includes(item))) continue;
      unique.add(text);
      items.push({
        externalId: card.getAttribute('data-jobid') || card.getAttribute('data-id') || null,
        title: text.split(/\s+/).slice(0, 8).join(' '),
        text: text.slice(0, 1000),
        url: card.querySelector('a')?.href || location.href,
        source: 'BOSS 直聘',
      });
    }
    return {ok: true, platform: 'BOSS 直聘', items, scanned: cards.length, pageUrl: location.href};
  }

  function assistApply(payload) {
    if (hasChallenge()) return {ok: false, paused: true, reason: 'challenge_detected'};
    if (payload.confirmed !== true) return {ok: false, error: 'user_confirmation_required'};
    const button = [...document.querySelectorAll('button, a, [role="button"]')]
      .find((item) => /立即沟通|立即投递|投递|申请/.test(item.innerText || ''));
    if (!button) return {ok: false, error: 'apply_button_not_found'};
    button.click();
    return {ok: true, submitted: true, pageUrl: location.href};
  }

  function hasChallenge() {
    return /验证码|安全验证|短信验证|异常访问|操作频繁|请完成验证/.test(document.body?.innerText || '');
  }

  function normalize(value) {
    return String(value || '').replace(/\s+/g, ' ').trim().toLowerCase();
  }

  function parseJson(value) {
    try { return JSON.parse(value); } catch (_) { return null; }
  }
})();
