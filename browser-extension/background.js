chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.type !== 'workbench-request' || !sender.tab?.id) return;
  const workbenchTabId = sender.tab.id;
  chrome.tabs.query({}).then(async (tabs) => {
    const bossTab = tabs.find((tab) => {
      try {
        const host = new URL(tab.url || '').hostname;
        return host === 'www.zhipin.com' || host === 'zhipin.com';
      } catch (_) {
        return false;
      }
    });
    if (!bossTab?.id) {
      return sendToWorkbench(workbenchTabId, message.requestId, {
        ok: false,
        error: 'boss_tab_not_found',
      });
    }
    try {
      const response = await chrome.tabs.sendMessage(bossTab.id, {
        type: 'boss-action',
        action: message.action,
        payload: message.payload || {},
      });
      await sendToWorkbench(workbenchTabId, message.requestId, response);
    } catch (_) {
      await sendToWorkbench(workbenchTabId, message.requestId, {
        ok: false,
        error: 'boss_content_script_unavailable',
      });
    }
  });
  sendResponse({ok: true, queued: true});
  return true;
});

async function sendToWorkbench(tabId, requestId, response) {
  try {
    await chrome.tabs.sendMessage(tabId, {
      type: 'workbench-response',
      requestId,
      response,
    });
  } catch (_) {
    // The workbench tab may have been closed while BOSS was processing.
  }
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.local.set({installedAt: new Date().toISOString()});
});
