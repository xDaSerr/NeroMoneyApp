import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'asistente_avatar.dart';

/// La cara del asistente (ver AsistenteAvatar) con un anillo degradado y
/// brillo alrededor — se usa más grande en la pestaña inferior (AppShell,
/// donde resalta del resto de los íconos) y más chico como vista previa en
/// PersonalizarAsistenteScreen, donde el usuario elige de qué colores es
/// (ver paleta_anillos_asistente.dart). Un solo widget para que se vea
/// exactamente igual en los dos lugares.
class AnilloAsistente extends StatelessWidget {
  const AnilloAsistente({super.key, required this.avatarBase64, this.colores, this.size = 42});

  final String? avatarBase64;

  /// Los 2 colores del degradado, elegidos por el usuario. Null (o si no
  /// trae exactamente 2) usa el degradado por defecto.
  final List<Color>? colores;
  final double size;

  static const coloresPorDefecto = [AppColors.secondaryVioletTint, AppColors.primaryCyan];

  @override
  Widget build(BuildContext context) {
    final coloresEfectivos =
        (colores != null && colores!.length == 2) ? colores! : coloresPorDefecto;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: coloresEfectivos,
        ),
        boxShadow: [
          BoxShadow(color: coloresEfectivos[0].withValues(alpha: 0.45), blurRadius: 16),
          BoxShadow(color: coloresEfectivos[1].withValues(alpha: 0.45), blurRadius: 16),
        ],
      ),
      // El pequeño espacio del color de fondo entre el anillo y la foto es
      // lo que hace que el anillo se vea como un contorno propio y no como
      // un simple borde pegado a la imagen.
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surface1),
        child: AsistenteAvatar(avatarBase64: avatarBase64, size: size),
      ),
    );
  }
}
