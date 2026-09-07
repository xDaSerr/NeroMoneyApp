import 'package:firebase_auth/firebase_auth.dart';

/// Nombre a mostrar en saludos ("Hola, X" en Inicio, encabezado de Perfil) +
/// inicial para el avatar circular. Compartido entre HomeScreen y
/// ProfileScreen para que ambos concuerden siempre — antes vivía duplicado
/// (una copia privada dentro de home_screen.dart).
///
/// Prioridad: el apodo que el usuario eligió a mano en Editar perfil (ver
/// EditarPerfilScreen) > el nombre real que trae Google Sign-In > el
/// prefijo del correo (si entró con email/contraseña, que no trae nombre) >
/// "ahí", como último respaldo para que el saludo nunca quede vacío.
({String nombre, String inicial}) datosDeSaludo(User? usuario, String? apodo) {
  final apodoLimpio = apodo?.trim();
  if (apodoLimpio != null && apodoLimpio.isNotEmpty) {
    return (
      nombre: apodoLimpio,
      inicial: apodoLimpio.substring(0, 1).toUpperCase(),
    );
  }

  final displayName = usuario?.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) {
    final primerNombre = displayName.split(' ').first;
    return (
      nombre: primerNombre,
      inicial: primerNombre.substring(0, 1).toUpperCase(),
    );
  }

  final email = usuario?.email ?? '';
  final prefijo = email.contains('@') ? email.split('@').first : email;
  if (prefijo.isEmpty) return (nombre: 'ahí', inicial: '?');
  return (nombre: prefijo, inicial: prefijo.substring(0, 1).toUpperCase());
}
