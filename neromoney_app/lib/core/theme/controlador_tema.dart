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

  TemaApp _tema = TemaApp.negro;
  TemaApp get tema => _tema;

  /// Se llama una vez en main(), antes de runApp.
  Future<void> cargarGuardado() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      _tema = TemaAppNombre.desdeTexto(preferencias.getString(_clave));
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
