// Displays foreground reminders; it does not schedule work or subscribe to push.
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));

self.addEventListener('notificationclick', event => {
  const data = event.notification.data;
  event.notification.close();
  if (data?.kind !== 'dompetku-bill' || !/^[a-f0-9]{64}$/.test(data.account ?? '')) return;
  event.waitUntil((async () => {
    const base = new URL('../', self.registration.scope);
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      const url = new URL(client.url);
      if (url.origin === base.origin && url.pathname === base.pathname) {
        await client.focus();
        client.postMessage({ kind: 'dompetku-open-bills', account: data.account });
        return;
      }
    }
    base.searchParams.set('dompetkuBills', data.account);
    await self.clients.openWindow(base.href);
  })());
});
