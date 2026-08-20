// Kill-switch service worker for LOCALHOST testing only.
// Flutter generates a real service worker that caches main.dart.js and
// ignores HTTP Cache-Control headers, so localhost previews served stale
// bundles. This script unregisters itself on activation so the browser
// stops caching and always fetches fresh assets.
self.addEventListener('install', function (e) { self.skipWaiting(); });
self.addEventListener('activate', function (e) {
  e.waitUntil(
    self.registration.unregister()
      .then(function () {
        return self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      })
      .then(function (clients) {
        clients.forEach(function (client) { client.navigate(client.url); });
      })
  );
});
