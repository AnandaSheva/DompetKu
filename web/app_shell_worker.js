'use strict';

// Offline app shell for the PWA.
//
// Network first: online users always receive the current build, and offline
// users (or users on a very slow connection) receive the last copy of the app
// files. It only handles same-origin GET requests for static app files.
// Firestore and Google sign-in traffic is cross-origin and never reaches this
// worker, so no financial data or credentials are cached here.
//
// __BUILD_ID__ is stamped by scripts/vercel-build.sh so every deployment
// installs a fresh worker and drops the previous cache.
const BUILD = '__BUILD_ID__';
const CACHE_PREFIX = 'dompetku-shell-';
const CACHE = `${CACHE_PREFIX}${BUILD}`;
const NAVIGATION_TIMEOUT_MS = 4000;
const SCOPE = new URL(self.registration.scope);
const SHELL_KEY = SCOPE.origin + SCOPE.pathname;
const PRECACHE = [
  '',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
].map(path => new URL(path, SCOPE).href);

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // One missing file must not block the install.
    await Promise.allSettled(PRECACHE.map(async url => {
      const response = await fetch(url);
      if (cacheable(response)) await cache.put(keyFor(url), response);
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names
      .filter(name => name.startsWith(CACHE_PREFIX) && name !== CACHE)
      .map(name => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET' || request.headers.has('range')) return;
  const url = new URL(request.url);
  if (url.origin !== SCOPE.origin || url.pathname.includes('/__/')) return;
  event.respondWith(request.mode === 'navigate'
    ? navigation(event, request)
    : networkFirst(event, request));
});

// Ignore query strings so deep links such as `?dompetkuBills=...` share one entry.
function keyFor(href) {
  const url = new URL(href);
  return url.origin + url.pathname;
}

function cacheable(response) {
  return response.ok && response.type === 'basic' && !response.redirected &&
    !/no-store/i.test(response.headers.get('cache-control') ?? '');
}

function remember(event, request, response) {
  if (!cacheable(response)) return;
  const copy = response.clone();
  event.waitUntil(caches.open(CACHE).then(cache => cache.put(keyFor(request.url), copy)));
}

async function navigation(event, request) {
  const cached = await caches.match(keyFor(request.url)) ?? await caches.match(SHELL_KEY);
  const network = fetch(request).then(response => {
    remember(event, request, response);
    return response;
  }, () => null);
  // With a cached copy, a stalled connection falls back to it after a short wait.
  const result = cached
    ? await Promise.race([
        network,
        new Promise(resolve => setTimeout(() => resolve(null), NAVIGATION_TIMEOUT_MS)),
      ])
    : await network;
  if (result && (result.status < 500 || !cached)) return result;
  return cached ?? Response.error();
}

async function networkFirst(event, request) {
  try {
    const response = await fetch(request);
    remember(event, request, response);
    return response;
  } catch (error) {
    const cached = await caches.match(keyFor(request.url));
    if (cached) return cached;
    throw error;
  }
}
