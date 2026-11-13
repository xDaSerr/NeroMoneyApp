import 'package:flutter/material.dart';

import '../../core/router/app_shell.dart';
import 'widgets/perfil_escritorio.dart';
import 'widgets/perfil_movil.dart';

/// Perfil: datos del usuario, preferencias (moneda, color, recordatorios,
/// reportes), el asistente y cerrar sesión. En ventana ancha usa
/// PerfilEscritorio; en teléfono, el diseño móvil del usuario (PerfilMovil).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return esEscritorio(context)
        ? const PerfilEscritorio()
        : const PerfilMovil();
  }
}
