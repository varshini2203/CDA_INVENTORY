importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAKeTY_HBxGmZx_84K-1y5TXQAdbP_CNuM",
  authDomain: "cda-inventory-be82b.firebaseapp.com",
  projectId: "cda-inventory-be82b",
  storageBucket: "cda-inventory-be82b.firebasestorage.app",
  messagingSenderId: "140087898334",
  appId: "1:140087898334:web:487c5aa6d996442f4fd24f",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Background message received:', payload);
  const { title, body } = payload.notification || {};
  self.registration.showNotification(title || 'CDA Inventory', {
    body: body || '',
    icon: '/icons/Icon-192.png',
  });
});