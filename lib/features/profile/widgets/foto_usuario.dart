import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// La foto de perfil del usuario, o su inicial si todavía no sube una.
/// Se usa en Perfil (teléfono y escritorio), en Editar perfil y en Inicio,
/// para que la cara del usuario sea la misma en toda la app.
class FotoUsuario extends StatelessWidget {
  const FotoUsuario({
    super.key,
    required this.base64,
    required this.inicial,
    required this.radio,
    this.estiloInicial,
  });

  final String? base64;
  final String inicial;
  final double radio;
  final TextStyle? estiloInicial;

  static final _cache = <String, Uint8List>{};

  /// Decodificar en cada reconstrucción haría parpadear la foto: se
  /// guarda la última versión decodificada de cada texto.
  static Uint8List? _bytes(String? texto) {
    if (texto == null || texto.isEmpty) return null;
    final guardado = _cache[texto];
    if (guardado != null) return guardado;
    try {
      final bytes = base64Decode(texto);
      _cache
        ..clear()
        ..[texto] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes(base64);
    return CircleAvatar(
      radius: radio,
      backgroundColor: AppColors.secundario.withValues(alpha: 0.45),
      foregroundImage: bytes == null ? null : MemoryImage(bytes),
      child: bytes != null
          ? null
          : Text(
              inicial,
              style:
                  estiloInicial ??
                  TextStyle(
                    color: Colors.white,
                    fontSize: radio * 0.8,
                    fontWeight: FontWeight.w600,
                  ),
            ),
    );
  }
}
