// Inicializa firebase-admin una sola vez para todos los módulos.
const {initializeApp, getApps} = require("firebase-admin/app");

if (getApps().length === 0) initializeApp();
