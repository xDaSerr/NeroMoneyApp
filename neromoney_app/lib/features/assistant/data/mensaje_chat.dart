import 'package:cloud_firestore/cloud_firestore.dart';

enum AutorMensaje { usuario, asistente }

/// Un mensaje del chat con Lucy. Vive en Firestore bajo
/// `usuarios/{uid}/mensajesAsistente/{id}` para que la conversación
/// sincronice entre dispositivos, igual que el resto de los datos de la app.
class MensajeChat {
  const MensajeChat({
    required this.id,
    required this.autor,
    required this.contenido,
    required this.fecha,
    this.chipsCuentas = const [],
    this.registrado = false,
  });

  final String id;
  final AutorMensaje autor;
  final String contenido;
  final DateTime fecha;

  /// Si Lucy necesita que el usuario elija una cuenta (ver
  /// BorradorPendiente), este mensaje trae los ids de las cuentas a mostrar
  /// como chips de selección rápida justo debajo de la burbuja. Vacío en
  /// mensajes normales.
  final List<String> chipsCuentas;

  /// true solo en los mensajes de confirmación que vinieron justo después
  /// de una llamada real a `TransaccionesRepository.registrarTransaccion` —
  /// nunca en una respuesta de texto libre del modelo. Sirve para mostrar
  /// una marca visual ("✅ Registrado") que distinga una confirmación real
  /// de un texto que solo *suena* a confirmación (un riesgo real de los
  /// modelos de lenguaje: a veces "confirman" en texto sin de verdad llamar
  /// a la función que guarda el dato — ver CLAUDE.md → Backend de IA).
  final bool registrado;

  factory MensajeChat.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MensajeChat(
      id: doc.id,
      autor: AutorMensaje.values.byName(data['autor'] as String),
      contenido: data['contenido'] as String,
      fecha: (data['fecha'] as Timestamp).toDate(),
      chipsCuentas: (data['chipsCuentas'] as List<dynamic>?)?.cast<String>() ?? const [],
      registrado: data['registrado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'autor': autor.name,
      'contenido': contenido,
      'fecha': Timestamp.fromDate(fecha),
      if (chipsCuentas.isNotEmpty) 'chipsCuentas': chipsCuentas,
      if (registrado) 'registrado': registrado,
    };
  }
}
