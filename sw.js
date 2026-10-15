// Service Worker para REGISTROS PRV TRANSITO PWA
// Versión de caché dinámica: se incrementa en cada despliegue para forzar actualización en celulares
const CACHE_VERSION = 'v1.1.20';
const CACHE_NAME = `registros-prv-${CACHE_VERSION}`;

self.addEventListener('install', (event) => {
  console.log(`[SW] Instalando Service Worker versión: ${CACHE_VERSION}`);
  // Forzar activación inmediata sin esperar a que se cierren pestañas
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log(`[SW] Activando Service Worker versión: ${CACHE_VERSION}`);
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cache) => {
          if (cache !== CACHE_NAME) {
            console.log(`[SW] Eliminando caché obsoleta: ${cache}`);
            return caches.delete(cache);
          }
        })
      );
    }).then(() => {
      // Tomar control inmediato de todas las pestañas abiertas
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', (event) => {
  // Estrategia Network First: siempre intenta descargar lo más reciente
  event.respondWith(
    fetch(event.request)
      .then((networkResponse) => {
        return networkResponse;
      })
      .catch(() => {
        // Si no hay conexión o falla la red, recurre a la caché
        return caches.match(event.request);
      })
  );
});
