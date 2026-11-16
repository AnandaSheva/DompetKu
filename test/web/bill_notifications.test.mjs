import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { setImmediate } from 'node:timers/promises';
import vm from 'node:vm';

const source = await readFile(new URL('../../web/bill_notifications.js', import.meta.url), 'utf8');
const workerSource = await readFile(new URL('../../web/bill_notification_worker.js', import.meta.url), 'utf8');
const alice = 'a'.repeat(64);
const bob = 'b'.repeat(64);
const bill = '1'.repeat(64);
const bill2 = '2'.repeat(64);

class Storage {
  values = new Map();
  failWrite = false;
  getItem(key) { return this.values.get(key) ?? null; }
  setItem(key, value) {
    if (this.failWrite) throw new Error('Storage unavailable');
    this.values.set(key, value);
  }
  removeItem(key) { this.values.delete(key); }
}

function locks() {
  let queue = Promise.resolve();
  return { request(_, callback) { const next = queue.then(callback); queue = next.catch(() => {}); return next; } };
}

function harness(options = {}) {
  const events = [];
  const notifications = options.notifications ?? [];
  const local = options.local ?? new Storage();
  const session = new Storage();
  const listeners = new Map();
  const registration = options.registration ?? {
    active: {},
    async getNotifications() { return notifications.filter(item => !item.closed); },
    async showNotification(title, details) {
      if (options.failShow?.()) throw new Error('Notification failed');
      notifications.push({ title, ...details, closed: false, close() { this.closed = true; } });
    },
  };
  const notification = {
    permission: options.permission ?? 'default',
    requestPermission() {
      events.push('permission');
      this.permission = options.answer ?? 'granted';
      return Promise.resolve(this.permission);
    },
  };
  const context = vm.createContext({
    URL, Map, Set, Promise, setTimeout, clearTimeout,
    isSecureContext: options.secure ?? true,
    Notification: notification,
    navigator: {
      userAgent: options.ios ? 'iPhone' : 'Chrome',
      standalone: options.standalone ?? false,
      serviceWorker: {
        addEventListener(type, callback) { listeners.set(type, callback); },
        async register(url, settings) {
          events.push({ url, ...settings });
          if (options.holdRegistration) await options.holdRegistration;
          return registration;
        },
      },
      locks: options.locks ?? locks(),
    },
    document: { baseURI: 'https://dompetku.test/finance/' },
    location: { href: options.url ?? 'https://dompetku.test/finance/' },
    history: { state: null, replaceState(_, __, url) { events.push({ replacedUrl: url }); } },
    localStorage: local,
    sessionStorage: session,
  });
  if (options.unsupported) delete context.Notification;
  vm.runInContext(source, context);
  const api = context.dompetkuBillNotifications;
  function enable(account = alice, persistent = true) {
    api.activate(account, persistent);
    notification.permission = 'granted';
    api.setEnabled(true);
    api.revise(1);
  }
  function send({ account = alice, day = '2026-11-16', phase = 'today', keys = [bill], revision = 1 } = {}) {
    return api.showReminder(JSON.stringify({ account, day, phase, keys, revision }));
  }
  return { api, enable, send, events, notifications, notification, registration, local, session, listeners };
}

test('startup never requests permission or registers a worker', () => {
  const h = harness();
  assert.equal(h.api.permission(), 'default');
  assert.equal(h.api.activate(alice, false), false);
  assert.deepEqual(h.events, []);
});

test('requestPermission reaches the browser before any worker setup', async () => {
  const h = harness();
  const permission = h.api.requestPermission();
  assert.deepEqual(h.events, ['permission']);
  assert.equal(await permission, 'granted');
});

for (const [name, options, permission] of [
  ['denied', { permission: 'denied' }, 'denied'],
  ['insecure', { secure: false }, 'insecure'],
  ['unsupported', { unsupported: true }, 'unavailable'],
  ['iOS browser tab', { ios: true }, 'install'],
]) {
  test(`${name} does not request permission or show a notification`, async () => {
    const h = harness(options);
    h.api.activate(alice, false);
    assert.equal(await h.api.requestPermission(), permission);
    assert.equal(await h.send(), false);
    assert.deepEqual(h.events, []);
  });
}

test('installed iOS uses service worker notifications without replacing Flutter scope', async () => {
  const h = harness({ ios: true, standalone: true });
  h.enable();
  assert.equal(await h.send(), true);
  assert.equal(h.events[0].url, 'https://dompetku.test/finance/bill_notification_worker.js');
  assert.equal(h.events[0].scope, 'https://dompetku.test/finance/notification-reminders/');
  assert.equal(h.notifications[0].tag, `dompetku-bill:${alice}:2026-11-16:today`);
  assert.equal(h.notifications[0].renotify, false);
});

test('each occurrence is delivered once per day even after dismissal and reload', async () => {
  const h = harness();
  h.enable();
  assert.equal(await h.send(), true);
  h.notifications[0].close();
  assert.equal(await h.send(), false);
  const reloaded = harness({ local: h.local });
  reloaded.api.activate(alice, true);
  reloaded.notification.permission = 'granted';
  reloaded.api.revise(1);
  assert.equal(await reloaded.send(), false);
  assert.equal(h.notifications.length + reloaded.notifications.length, 1);
});

test('H-1 and H are separate and batches only count newly due occurrences', async () => {
  const h = harness();
  h.enable();
  await h.send({ phase: 'tomorrow' });
  await h.send({ keys: [bill, bill2], phase: 'tomorrow' });
  assert.match(h.notifications[1].body, /Ada 1 tagihan/);
  assert.equal(await h.send({ day: '2026-11-17', phase: 'today', keys: [bill2] }), true);
  assert.equal(h.notifications.length, 3);
  assert.equal(h.notifications[2].title, 'Tagihan jatuh tempo hari ini');
  assert.equal(h.notifications[0].title, 'Tagihan jatuh tempo besok');
});

test('failed display is retryable and does not mark a bill as sent', async () => {
  let fail = true;
  const h = harness({ failShow: () => fail });
  h.enable();
  await assert.rejects(h.send());
  fail = false;
  assert.equal(await h.send(), true);
  assert.equal(h.notifications.length, 1);
});

test('revoked permission or disabled preference stops delivery', async () => {
  const h = harness();
  h.enable();
  h.notification.permission = 'denied';
  assert.equal(await h.send(), false);
  h.notification.permission = 'granted';
  h.api.setEnabled(false);
  assert.equal(await h.send(), false);
  assert.equal(h.notifications.length, 0);
});

for (const action of ['disable', 'logout', 'revision']) {
  test(`${action} during worker activation cancels stale notifications`, async () => {
    let release;
    const hold = new Promise(resolve => { release = resolve; });
    const h = harness({ holdRegistration: hold });
    h.enable();
    const pending = h.send();
    await setImmediate();
    if (action === 'disable') h.api.setEnabled(false);
    else if (action === 'logout') h.api.deactivate(alice);
    else h.api.revise(2);
    release();
    assert.equal(await pending, false);
    assert.equal(h.notifications.length, 0);
  });
}

test('account preference, ledger and notification closure remain isolated', async () => {
  const h = harness();
  h.enable();
  await h.send();
  h.api.deactivate(alice);
  assert.equal(h.api.activate(bob, true), false);
  h.enable(bob);
  assert.equal(await h.send({ account: bob }), true);
  await setImmediate();
  assert.equal(h.notifications[0].closed, true);
  assert.equal(h.notifications[1].closed, false);
});

test('shared devices use session storage and functional markers contain no bill details', async () => {
  const h = harness();
  h.enable(alice, false);
  await h.send();
  assert.equal(h.local.values.size, 0);
  assert.equal(h.session.values.size, 2);
  const stored = JSON.stringify([...h.session.values]);
  assert.ok(!stored.includes('Internet rumah'));
  assert.ok(!stored.includes('250000'));
  assert.ok(!h.notifications[0].body.includes(bill));
});

test('storage failure retains an effective in-memory off switch', async () => {
  const h = harness();
  h.enable();
  h.local.failWrite = true;
  h.api.setEnabled(false);
  assert.equal(await h.send(), false);
  assert.equal(h.notifications.length, 0);
});

test('trusted-device tabs serialize delivery and observe another tabs off switch', async () => {
  const local = new Storage();
  const sharedLocks = locks();
  const h = harness({ local, locks: sharedLocks });
  const other = harness({ local, locks: sharedLocks, registration: h.registration });
  h.enable();
  other.enable();
  const results = await Promise.all([h.send(), other.send()]);
  assert.deepEqual(results, [true, false]);
  other.api.setEnabled(false);
  assert.equal(await h.send({ keys: [bill2] }), false);
});

test('pending navigation survives login without retaining a financial payload', () => {
  const h = harness({ url: `https://dompetku.test/finance/?dompetkuBills=${alice}&keep=yes` });
  assert.equal(h.api.takePendingOpen(), alice);
  assert.equal(h.api.takePendingOpen(), null);
  assert.equal(new URL(h.events[0].replacedUrl).searchParams.get('keep'), 'yes');
  let opened;
  h.api.setOpenHandler(account => { opened = account; });
  h.listeners.get('message')({ data: { kind: 'dompetku-open-bills', account: bob } });
  assert.equal(opened, bob);
});

function workerHarness(windows = []) {
  const listeners = new Map();
  const opened = [];
  vm.runInNewContext(workerSource, { URL, self: {
    registration: { scope: 'https://dompetku.test/finance/notification-reminders/' },
    skipWaiting: async () => {},
    addEventListener(type, callback) { listeners.set(type, callback); },
    clients: { matchAll: async () => windows, openWindow: async url => { opened.push(url); } },
  } });
  async function click(data) {
    let pending;
    listeners.get('notificationclick')({ notification: { data, close() {} }, waitUntil(value) { pending = value; } });
    await pending;
  }
  return { opened, click };
}

test('notification click focuses the app and passes the intended account', async () => {
  let focused = false;
  let message;
  const h = workerHarness([{ url: 'https://dompetku.test/finance/', async focus() { focused = true; }, postMessage(value) { message = value; } }]);
  await h.click({ kind: 'dompetku-bill', account: alice, url: 'https://untrusted.test/' });
  assert.equal(focused, true);
  assert.equal(message.account, alice);
  assert.equal(message.kind, 'dompetku-open-bills');
  assert.equal(h.opened.length, 0);
});

test('notification click only opens the apps own URL and rejects malformed accounts', async () => {
  const h = workerHarness();
  await h.click({ kind: 'dompetku-bill', account: 'invalid' });
  assert.equal(h.opened.length, 0);
  await h.click({ kind: 'dompetku-bill', account: alice, url: 'https://untrusted.test/' });
  const target = new URL(h.opened[0]);
  assert.equal(target.origin, 'https://dompetku.test');
  assert.equal(target.pathname, '/finance/');
  assert.equal(target.searchParams.get('dompetkuBills'), alice);
});
