// BookMySpace Service Worker for Web Push Notifications
const CACHE_NAME = 'bookmyspace-push-v1';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// Listen for incoming Web Push events
self.addEventListener('push', (event) => {
  let payload = {};
  if (event.data) {
    try {
      payload = event.data.json();
    } catch (e) {
      payload = {
        title: 'BookMySpace Notification',
        body: event.data.text()
      };
    }
  }

  const title = payload.title || '⏰ BookMySpace Pre-Slot Reminder';
  const data = payload.data || payload;
  const isReminder = data.type === '1_hour_reminder' || payload.type === '1_hour_reminder';

  const defaultActions = isReminder ? [
    { action: 'view_pass', title: '🎟️ View Pass' },
    { action: 'directions', title: '🗺️ Directions' }
  ] : [
    { action: 'open', title: 'Open BookMySpace' }
  ];

  const options = {
    body: payload.body || 'Your upcoming venue slot begins in 1 hour. Tap to view your check-in pass.',
    icon: payload.icon || '/icons/Icon-192.png',
    badge: payload.badge || '/favicon.png',
    data: data,
    tag: payload.tag || 'bms-slot-reminder',
    renotify: true,
    requireInteraction: isReminder,
    actions: payload.actions || defaultActions
  };

  event.waitUntil(
    self.registration.showNotification(title, options).then(() => {
      // Broadcast to any open web clients
      return self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
        for (const client of clientList) {
          client.postMessage({
            eventType: 'message',
            title: title,
            body: options.body,
            data: data
          });
        }
      });
    })
  );
});

// Handle notification click and deep link dispatching
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data = event.notification.data || {};
  const action = event.action;

  let targetUrl = '/';
  if (action === 'directions') {
    targetUrl = data.venue_id ? '/map?venue=' + data.venue_id : '/map';
  } else if (action === 'view_pass' || data.type === '1_hour_reminder' || data.booking_id) {
    targetUrl = '/bookings';
  } else if (data.venue_id) {
    targetUrl = '/venues/' + data.venue_id;
  } else if (data.course_id || data.class_id) {
    targetUrl = '/courses/' + (data.course_id || data.class_id);
  } else {
    targetUrl = '/notifications';
  }

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.focus();
          client.postMessage({
            eventType: 'click',
            action: action,
            data: data,
            targetUrl: targetUrl
          });
          return;
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
    })
  );
});
