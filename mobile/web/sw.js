// Ayuvo web service worker — shows medicine reminders pushed from the
// server's Web Push scheduler, and lets the user answer them.
//
// This is the Flutter web build's counterpart to `front/public/sw.js` (the
// Next.js PWA): the backend reminder scheduler sends encrypted push messages
// to every registered subscription, and when the app is closed this file is
// what wakes up and renders the notification. It must stay a tiny, dependency-
// free plain-JS file so it can be registered from Dart.
//
// The Flutter build ships its own `flutter_service_worker.js`, which only
// unregisters itself; registering at the same scope here simply takes over as
// the active worker for the app.

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// Server Web Push → medicine reminder notification (fires even when the app is
// fully closed). Payload is produced by the backend reminder scheduler.
self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch {
    data = {};
  }

  const title = data.title || '💊 Medicine Reminder';
  const options = {
    body: data.body || 'Time to take your medicine',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    tag: data.tag || 'medicine-reminder',
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
      { action: 'taken', title: '✓ Taken' },
      { action: 'snooze', title: 'Snooze 10m' },
    ],
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Relay the tapped action (taken / snooze / open) to any open page so it can
// record adherence; bring the app to the front unless the user only snoozed.
self.addEventListener('notificationclick', (event) => {
  const data = (event.notification && event.notification.data) || {};
  const action = event.action || 'open';
  event.notification.close();

  event.waitUntil(
    (async () => {
      const clientList = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });

      const payload = {
        type: 'medicine-alarm-action',
        action,
        medId: data.medId,
        time: data.time,
        name: data.name,
        dosage: data.dosage,
      };

      for (const client of clientList) client.postMessage(payload);

      if (action !== 'snooze') {
        const focused = clientList.find((c) => 'focus' in c);
        if (focused) {
          await focused.focus();
        } else if (self.clients.openWindow) {
          await self.clients.openWindow('/');
        }
      }
    })(),
  );
});
