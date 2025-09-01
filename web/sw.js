// Service Worker for Flutter Web Asset Management
const CACHE_NAME = 'flutter-assets-v2';
const CRITICAL_ASSETS = [
  'assets/AssetManifest.bin.json',
  'assets/AssetManifest.json',
  'assets/FontManifest.json',
  'assets/images/app_icon.png',
  'main.dart.js',
  'flutter.js',
  'flutter_bootstrap.js'
];

// Install event - cache critical assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('Caching critical assets');
        return cache.addAll(CRITICAL_ASSETS.map(asset => {
          return new Request(asset, { cache: 'reload' });
        }));
      })
      .catch((error) => {
        console.error('Failed to cache assets:', error);
      })
  );
  self.skipWaiting();
});

// Fetch event - serve from cache with network fallback
self.addEventListener('fetch', (event) => {
  // Only handle GET requests
  if (event.request.method !== 'GET') return;
  
  // Handle asset manifest requests specially
  if (event.request.url.includes('AssetManifest') || 
      event.request.url.includes('FontManifest')) {
    event.respondWith(
      caches.open(CACHE_NAME)
        .then((cache) => {
          return cache.match(event.request)
            .then((cachedResponse) => {
              if (cachedResponse) {
                console.log('Serving cached asset:', event.request.url);
                return cachedResponse;
              }
              
              // If not in cache, fetch and cache
              return fetch(event.request)
                .then((response) => {
                  if (response.ok) {
                    cache.put(event.request, response.clone());
                  }
                  return response;
                })
                .catch((error) => {
                  console.error('Failed to fetch asset:', event.request.url, error);
                  // Return a fallback response for critical assets
                  if (event.request.url.includes('AssetManifest.bin.json')) {
                    return new Response('{}', {
                      headers: { 'Content-Type': 'application/json' }
                    });
                  }
                  throw error;
                });
            });
        })
    );
  }
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});