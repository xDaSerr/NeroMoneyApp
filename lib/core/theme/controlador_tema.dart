import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tema_app.dart';

/// Tema elegido por el usuario. La fuente de verdad es su perfil en
/// Firestore (`usuarios/{uid}.tema`, sincronizado desde AppShell); aquí
/// además se guarda en el dispositivo para que, al abrir la app, el primer
/// cuadro ya salga con el color correcto en vez de parpadear desde el Negro
/// mientras llega el perfil.
///
/// NeroMoneyApp (main.dart) lo escucha y reconstruye toda la app al cambiar.
class ControladorTema extends ChangeNotifier {
  ControladorTema._();
  static final instancia = ControladorTema._();

  static const _clave = 'tema_app';
  static const _claveFondo = 'fondo_app';

  TemaApp _tema = TemaApp.negro;
  TemaApp get tema => _tema;

  /// Fondo con imagen (Plus y Pro). null = el color del tema.
  FondoApp? _fondo;
  FondoApp? get fondo => _fondo;

  /// La paleta que se ve: la del fondo si hay uno, si no la del color.
  PaletaTema get paleta =>
      _fondo != null ? PaletaTema.deFondo(_fondo!) : PaletaTema.de(_tema);

  /// Se llama una vez en main(), antes de runApp.
  Future<void> cargarGuardado() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      _tema = TemaAppNombre.desdeTexto(preferencias.getString(_clave));
      _fondo = FondoApp.desdeTexto(preferencias.getString(_claveFondo));
    } catch (_) {
      // Sin almacenamiento local (ej. navegador en modo privado): se arranca
      // en Negro y el perfil corrige el color en cuanto llega.
    }
  }

  void cambiar(TemaApp tema) {
    if (tema == _tema) return;
    _tema = tema;
    SharedPreferences.getInstance()
        .then((p) => p.setString(_clave, tema.name))
        .catchError((Object _) => false);
    _notificar();
  }

  /// null quita el fondo (vuelve al color).
  void cambiarFondo(FondoApp? fondo) {
    if (fondo == _fondo) return;
    _fondo = fondo;
    SharedPreferences.getInstance()
        .then(
          (p) => fondo == null
              ? p.remove(_claveFondo)
              : p.setString(_claveFondo, fondo.name),
        )
        .catchError((Object _) => false);
    _notificar();
  }

  void _notificar() {
    // Puede llegar desde un ref.listen que corre mientras se construye un
    // widget; notificar justo ahí haría que NeroMoneyApp llamara setState
    // en pleno build. En ese caso se espera al final del cuadro.
    final fase = SchedulerBinding.instance.schedulerPhase;
    if (fase == SchedulerPhase.persistentCallbacks ||
        fase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}
