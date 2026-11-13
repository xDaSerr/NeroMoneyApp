#!/usr/bin/env bash
# Compila la versión web y la publica en Firebase Hosting.
#
# Por qué no basta con `flutter build web && firebase deploy`: el navegador
# puede tener guardada una copia vieja de main.dart.js (pasó en la prueba
# PWA: la página seguía mostrando la versión anterior). Aquí se le agrega a
# main.dart.js una huella de su contenido (?v=...) dentro de
# flutter_bootstrap.js, que se sirve sin caché — así cada versión nueva tiene
# una URL distinta y ninguna copia vieja puede hacerse pasar por ella.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter build web --release --no-wasm-dry-run

huella=$(sha256sum build/web/main.dart.js | cut -c1-12)
sed -i "s|\"mainJsPath\":\"main.dart.js\"|\"mainJsPath\":\"main.dart.js?v=${huella}\"|" \
  build/web/flutter_bootstrap.js
grep -q "main.dart.js?v=${huella}" build/web/flutter_bootstrap.js \
  || { echo "No se pudo marcar main.dart.js con la huella" >&2; exit 1; }

firebase deploy --only hosting --project neromoneyapp
echo "Publicado con main.dart.js?v=${huella}"
