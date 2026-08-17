// Firebase Cloud Messaging Service Worker for Web Push Notifications
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyBo2JwEWAvVlPDvDxT8VO4rTpXjKkxgdqc",
  authDomain: "parentpeak-prod-2026.firebaseapp.com",
  projectId: "parentpeak-prod-2026",
  storageBucket: "parentpeak-prod-2026.firebasestorage.app",
  messagingSenderId: "89417219632",
  appId: "1:89417219632:web:51b6fa43ffa2b52f1bf7f5"
});

const messaging = firebase.messaging();

// Background message handler
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'Parentpeak';
  const body = payload.notification?.body || 'Neue Nachricht';
  const options = {
    body: body,
    icon: '/assets/app-icon.png',
    badge: '/assets/app-icon.png',
    tag: 'parentpeak-notification',
  };
  return self.registration.showNotification(title, options);
});
