// Recibe los recordatorios de NeroMoney aunque la app esté cerrada (web
// instalable). Los manda la Cloud Function `recordatoriosWeb` a la hora que
// el usuario eligió en Perfil → Recordatorios.
// La versión debe coincidir con la que usa FlutterFire
// (firebase_core_web → supportedFirebaseJsSdkVersion).
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-messaging-compat.js');

// Configuración pública del proyecto (la misma de lib/firebase_options.dart):
// identifica el proyecto, no da acceso a datos.
firebase.initializeApp({
  apiKey: 'AIzaSyCRz9wQZR3hL2jmldXVeLOtDnWm6tggVjw',
  authDomain: 'neromoneyapp.firebaseapp.com',
  projectId: 'neromoneyapp',
  storageBucket: 'neromoneyapp.firebasestorage.app',
  messagingSenderId: '909698455391',
  appId: '1:909698455391:web:3bdd52cd330a0be11d08ea',
});

// Los mensajes traen `notification`, así que el navegador los muestra solo;
// solo hace falta abrir la app al tocarlos.
firebase.messaging();

self.addEventListener('notificationclick', (evento) => {
  evento.notification.close();
  const destino = new URL('/', self.location.origin).href;
  evento.waitUntil(
    clients.matchAll({type: 'window', includeUncontrolled: true}).then((ventanas) => {
      for (const v of ventanas) {
        if (v.url.startsWith(self.location.origin) && 'focus' in v) return v.focus();
      }
      return clients.openWindow(destino);
    }),
  );
});
