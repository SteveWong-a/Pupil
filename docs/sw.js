// Pupil Companion Service Worker — W3C Web Push & Lock-Screen Notification Handler

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', (event) => {
  let payload = {
    title: 'Pupil Security Alert',
    body: 'Tamper or alarm activity detected on your MacBook.',
    severity: 'high',
    tag: 'pupil-security-alert',
    timestamp: Date.now()
  };

  if (event.data) {
    try {
      const parsed = event.data.json();
      payload = {
        title: parsed.title || payload.title,
        body: parsed.body || payload.body,
        severity: parsed.severity || payload.severity,
        tag: parsed.tag || payload.tag,
        timestamp: parsed.timestamp || Date.now()
      };
    } catch {
      const rawText = event.data.text();
      if (rawText) {
        payload.body = rawText;
      }
    }
  }

  const options = {
    body: payload.body,
    icon: './icon-192.png',
    badge: './icon-192.png',
    tag: payload.tag,
    renotify: true,
    requireInteraction: payload.severity === 'critical',
    vibrate: payload.severity === 'critical' ? [300, 120, 300, 120, 450] : [200, 100, 200],
    data: payload
  };

  event.waitUntil(
    Promise.all([
      self.registration.showNotification(payload.title, options),
      self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
        for (const client of windowClients) {
          client.postMessage({ type: 'PUPIL_PUSH_RECEIVED', payload });
        }
      })
    ])
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) {
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow('./');
      }
    })
  );
});
