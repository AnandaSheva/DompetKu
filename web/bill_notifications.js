// Foreground reminders only. No push subscription, server, or financial cache.
(() => {
  'use strict';
  const prefix = 'dompetku.bill-reminders.';
  const notificationPrefix = 'dompetku-bill:';
  const accountPattern = /^[a-f0-9]{64}$/;
  const memory = new Map();
  const base = new URL('./', document.baseURI);
  let active = null;
  let registration = null;
  let preparing = null;
  let openHandler = null;
  let pendingOpen = null;

  function permission() {
    if (!globalThis.isSecureContext) return 'insecure';
    const ios = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    const standalone = navigator.standalone === true ||
      globalThis.matchMedia?.('(display-mode: standalone)').matches;
    if (ios && !standalone) return 'install';
    if (!('Notification' in globalThis) || !('serviceWorker' in navigator)) {
      return 'unavailable';
    }
    return Notification.permission;
  }

  function storage(context) {
    if (context.volatile) return null;
    try {
      return context.persistent ? localStorage : sessionStorage;
    } catch (_) {
      return null;
    }
  }
  function read(context, key) {
    try {
      const target = storage(context);
      return target ? target.getItem(key) : memory.get(key) ?? null;
    }
    catch (_) { return memory.get(key) ?? null; }
  }
  function write(context, key, value) {
    memory.set(key, value);
    try {
      const target = storage(context);
      if (!target) { context.volatile = true; return; }
      target.setItem(key, value);
    } catch (_) { context.volatile = true; }
  }
  function enabled(context) {
    return read(context, `${prefix}enabled.${context.account}`) === 'true';
  }
  function live(context, revision) {
    return active === context && context.revision === revision &&
      enabled(context) && permission() === 'granted';
  }

  async function closeAccount(account, tag = null) {
    if (!registration) return;
    const notifications = await registration.getNotifications();
    for (const notification of notifications) {
      if (tag ? notification.tag === tag : notification.tag.startsWith(`${notificationPrefix}${account}:`)) {
        notification.close();
      }
    }
  }

  async function prepare() {
    if (permission() !== 'granted') throw new Error('Notification permission required');
    if (registration?.active) return;
    if (!preparing) {
      preparing = (async () => {
        const result = await navigator.serviceWorker.register(
          new URL('bill_notification_worker.js', base).href,
          // Keep Flutter's app/online worker at its existing root scope.
          { scope: new URL('notification-reminders/', base).href, updateViaCache: 'none' },
        );
        if (!result.active) {
          const worker = result.installing ?? result.waiting;
          if (!worker) throw new Error('Notification worker unavailable');
          await new Promise((resolve, reject) => {
            const timeout = setTimeout(() => finish(new Error('Notification worker timed out')), 15000);
            function finish(error) {
              clearTimeout(timeout);
              worker.removeEventListener('statechange', changed);
              error ? reject(error) : resolve();
            }
            function changed() {
              if (worker.state === 'activated') finish();
              else if (worker.state === 'redundant') finish(new Error('Notification worker failed'));
            }
            worker.addEventListener('statechange', changed);
            changed();
          });
        }
        registration = result;
      })();
    }
    try { await preparing; } finally { preparing = null; }
  }

  function ledger(context, day) {
    try {
      const value = JSON.parse(read(context, `${prefix}sent.${context.account}`));
      if (value?.day === day && Array.isArray(value.keys)) return new Set(value.keys);
    } catch (_) { /* Start a fresh ledger if storage was cleared or invalid. */ }
    return new Set();
  }

  async function showReminder(json) {
    const batch = JSON.parse(json);
    const context = active;
    if (!context || context.account !== batch.account ||
        !/^\d{4}-\d{2}-\d{2}$/.test(batch.day) ||
        !['today', 'tomorrow'].includes(batch.phase) ||
        !Array.isArray(batch.keys) || !batch.keys.every(key => accountPattern.test(key))) return false;
    const display = async () => {
      if (!live(context, batch.revision)) return false;
      await prepare();
      if (!live(context, batch.revision)) return false;
      const sent = ledger(context, batch.day);
      const fresh = [...new Set(batch.keys)].filter(key => !sent.has(key));
      if (fresh.length === 0) return false;
      const when = batch.phase === 'today' ? 'hari ini' : 'besok';
      const tag = `${notificationPrefix}${context.account}:${batch.day}:${batch.phase}`;
      await registration.showNotification(`Tagihan jatuh tempo ${when}`, {
        body: `Ada ${fresh.length} tagihan jatuh tempo ${when}. Buka DompetKu untuk memeriksa jadwal dan mencatat pembayaran.`,
        icon: new URL('icons/Icon-192.png', base).href,
        tag,
        renotify: false,
        data: { kind: 'dompetku-bill', account: context.account },
      });
      if (!live(context, batch.revision)) {
        await closeAccount(context.account, tag);
        return false;
      }
      fresh.forEach(key => sent.add(key));
      write(context, `${prefix}sent.${context.account}`, JSON.stringify({ day: batch.day, keys: [...sent] }));
      return true;
    };
    // Serialize delivery across trusted-device tabs. Stable tags also collapse
    // concurrent notifications in browsers without Web Locks.
    return navigator.locks?.request
      ? navigator.locks.request(`${prefix}delivery.${context.account}`, display)
      : display();
  }

  function rememberOpen(account) {
    if (!accountPattern.test(account ?? '')) return;
    if (openHandler) { openHandler(account); return; }
    pendingOpen = account;
    try { sessionStorage.setItem(`${prefix}open`, account); } catch (_) {}
  }
  const url = new URL(location.href);
  if (url.searchParams.has('dompetkuBills')) {
    rememberOpen(url.searchParams.get('dompetkuBills'));
    url.searchParams.delete('dompetkuBills');
    history.replaceState(history.state, '', url.href);
  }
  navigator.serviceWorker?.addEventListener('message', event => {
    if (event.data?.kind === 'dompetku-open-bills') rememberOpen(event.data.account);
  });

  globalThis.dompetkuBillNotifications = Object.freeze({
    permission,
    activate(account, persistent) {
      if (!accountPattern.test(account)) throw new Error('Invalid account');
      active = { account, persistent, revision: 0 };
      return enabled(active);
    },
    deactivate(account) {
      if (active?.account === account) active = null;
      void closeAccount(account).catch(() => {});
    },
    revise(revision) { if (active) active.revision = revision; },
    setEnabled(value) {
      if (!active) return;
      write(active, `${prefix}enabled.${active.account}`, String(value));
      if (!value) void closeAccount(active.account).catch(() => {});
    },
    takeRecommendation() {
      if (!active) return false;
      const key = `${prefix}recommended.${active.account}`;
      if (read(active, key) === 'true') return false;
      write(active, key, 'true');
      return true;
    },
    requestPermission() {
      // Invoke synchronously from the user's tap, before any awaited setup.
      const current = permission();
      return current === 'default' ? Notification.requestPermission() : Promise.resolve(current);
    },
    prepare,
    showReminder,
    async showTest() {
      const context = active;
      const revision = context?.revision;
      await prepare();
      if (!context || !live(context, revision)) return;
      await registration.showNotification('Notifikasi DompetKu aktif', {
        body: 'Pengingat tagihan H-1 dan hari H akan tampil saat DompetKu dibuka atau aktif.',
        icon: new URL('icons/Icon-192.png', base).href,
        tag: `${notificationPrefix}${context.account}:test`,
        data: { kind: 'dompetku-bill', account: context.account },
      });
      if (!live(context, revision)) await closeAccount(context.account);
    },
    setOpenHandler(handler) { openHandler = handler; },
    takePendingOpen() {
      let value = pendingOpen;
      pendingOpen = null;
      try {
        value ??= sessionStorage.getItem(`${prefix}open`);
        sessionStorage.removeItem(`${prefix}open`);
      } catch (_) {}
      return accountPattern.test(value ?? '') ? value : null;
    },
  });
})();
