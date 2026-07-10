// MediStore service worker — offline app shell only.
// SECURITY: never cache API responses or medical data. Only static assets
// and a generic offline fallback page are cached.

const CACHE = "medistore-v3";
const OFFLINE_URL = "/offline.html";
const PRECACHE = [
  OFFLINE_URL,
  "/icon-192.png",
  "/icon-512.png",
  "/apple-touch-icon.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

function isApiRequest(url) {
  return url.pathname.startsWith("/api/") || url.port === "3001";
}

// Server Web Push → medicine alarm notification (fires even when the app is
// fully closed). Payload is produced by the backend reminder scheduler.
self.addEventListener("push", (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch {
    data = {};
  }

  const title = data.title || "💊 Medicine Reminder";
  const options = {
    body: data.body || "Time to take your medicine",
    icon: "/icon-192.png",
    badge: "/icon-192.png",
    tag: data.tag || "medicine-reminder",
    renotify: true,
    requireInteraction: true,
    vibrate: [400, 200, 400, 200, 400],
    data: {
      medId: data.medId,
      name: data.name,
      dosage: data.dosage,
      time: data.time,
    },
    actions: [
      { action: "taken", title: "✓ Taken" },
      { action: "snooze", title: "Snooze 10m" },
    ],
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Medicine alarm: relay the tapped action (taken / snooze / open) to an open
// page so it can record adherence, stop the tone, and reschedule snoozes.
self.addEventListener("notificationclick", (event) => {
  const data = (event.notification && event.notification.data) || {};
  const action = event.action || "open";
  event.notification.close();

  event.waitUntil(
    (async () => {
      const clientList = await self.clients.matchAll({
        type: "window",
        includeUncontrolled: true,
      });

      const payload = {
        type: "medicine-alarm-action",
        action,
        medId: data.medId,
        time: data.time,
        name: data.name,
        dosage: data.dosage,
      };

      for (const client of clientList) client.postMessage(payload);

      // Bring the app to the front (open it if nothing is running) unless the
      // user only snoozed — snoozing shouldn't yank them into the app.
      if (action !== "snooze") {
        const focused = clientList.find((c) => "focus" in c);
        if (focused) {
          await focused.focus();
        } else if (self.clients.openWindow) {
          await self.clients.openWindow("/medicines");
        }
      }
    })(),
  );
});

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;

  const url = new URL(request.url);

  // Never intercept/cache API or cross-origin (backend) requests — sensitive data.
  if (url.origin !== self.location.origin || isApiRequest(url)) return;

  // Navigations: network-first, fall back to offline page when offline.
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request).catch(() => caches.match(OFFLINE_URL))
    );
    return;
  }

  // Static assets (_next/static, images, fonts): stale-while-revalidate.
  if (
    url.pathname.startsWith("/_next/static/") ||
    /\.(?:png|svg|jpg|jpeg|webp|gif|ico|woff2?)$/.test(url.pathname)
  ) {
    event.respondWith(
      caches.open(CACHE).then(async (cache) => {
        const cached = await cache.match(request);
        const network = fetch(request)
          .then((res) => {
            if (res.ok) cache.put(request, res.clone());
            return res;
          })
          .catch(() => cached);
        return cached || network;
      })
    );
  }
});
