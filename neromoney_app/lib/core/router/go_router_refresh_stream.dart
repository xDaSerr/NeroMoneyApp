import 'dart:async';
import 'package:flutter/foundation.dart';

/// Adapta cualquier Stream (aquí, authStateChanges de Firebase) a un
/// ChangeNotifier, que es lo que go_router espera en `refreshListenable`
/// para re-evaluar sus redirecciones cada vez que cambia la sesión.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
