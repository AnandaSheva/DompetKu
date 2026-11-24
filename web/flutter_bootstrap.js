{{flutter_js}}
{{flutter_build_config}}

// Flutter's own service worker is deprecated and has no offline cache, so it is
// not configured here. app_shell_worker.js provides the offline app shell.
_flutter.loader.load();

if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker
      .register(new URL('app_shell_worker.js', document.baseURI).href, {
        scope: new URL('./', document.baseURI).href,
        updateViaCache: 'none',
      })
      .catch(function () { /* The app works online without the worker. */ });
  });
}
