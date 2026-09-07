import 'dart:convert';

import 'package:flutter/material.dart';

/// La "cara" del asistente en toda la app: la foto que el usuario haya
/// elegido (ver PersonalizarAsistenteScreen) o, si no ha elegido ninguna,
/// el ícono de NeroMoney — nunca un ícono genérico de robot/IA que no
/// tenga relación real con la app. Es un solo widget a propósito: así,
/// cuando el usuario cambia la foto, se actualiza sola en todos los
/// lugares donde aparece (pestaña inferior, encabezado del chat, burbujas
/// de Lucy) sin tener que tocar cada pantalla por separado.
class AsistenteAvatar extends StatefulWidget {
  const AsistenteAvatar({
    super.key,
    required this.avatarBase64,
    this.size = 36,
  });

  /// Foto elegida por el usuario, codificada en Base64. Null = usar el
  /// ícono de la app como cara por defecto.
  final String? avatarBase64;
  final double size;

  @override
  State<AsistenteAvatar> createState() => _AsistenteAvatarState();
}

class _AsistenteAvatarState extends State<AsistenteAvatar> {
  late ImageProvider _imagen;

  @override
  void initState() {
    super.initState();
    _actualizarImagen();
  }

  @override
  void didUpdateWidget(AsistenteAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarBase64 != widget.avatarBase64) _actualizarImagen();
  }

  void _actualizarImagen() {
    final foto = widget.avatarBase64;
    // MemoryImage identifica su caché por los bytes. Decodificar Base64
    // en cada frame creaba una imagen distinta y dejaba huecos mientras
    // cargaba, tanto al animar la barra como al recibir niveles de voz.
    _imagen = foto != null && foto.isNotEmpty
        ? MemoryImage(base64Decode(foto))
        : const AssetImage('assets/icon/icon_full.png');
  }

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Image(image: _imagen, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }
}
