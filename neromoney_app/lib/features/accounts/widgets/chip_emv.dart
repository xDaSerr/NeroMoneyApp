import 'package:flutter/material.dart';

/// El chip dorado de una tarjeta física — puramente decorativo (ninguna
/// tarjeta real tiene chip electrónico de verdad, obvio), pero es el
/// detalle que hace que una tarjeta de crédito se sienta como tarjeta de
/// verdad en vez de solo una caja con degradado.
///
/// Vive en su propio archivo (no privado de `CuentaTile`) para que
/// `AccountDetailScreen` use exactamente el mismo widget en su tarjeta
/// grande — mismo criterio que `AsistenteAvatar`/`AnilloAsistente`: un
/// solo lugar para que el detalle se vea idéntico en toda la app.
class ChipEmv extends StatelessWidget {
  const ChipEmv({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 19,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFB45309)],
        ),
      ),
      child: Center(
        child: Container(
          width: 13,
          height: 9,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
