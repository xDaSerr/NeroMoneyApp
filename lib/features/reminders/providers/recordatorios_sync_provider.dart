import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/providers/perfil_providers.dart';
import '../../profile/data/saludo_usuario.dart';
import '../data/recordatorios_service.dart';

/// Mantiene los recordatorios programados al día con el perfil, sin que
/// cada pantalla que edita nombre/apodo/horas tenga que acordarse de
/// reprogramarlos ella misma. `AppShell` lo observa una sola vez (mismo
/// patrón que `controladorAsistenteProvider`) mientras haya sesión activa.
///
/// `fireImmediately: true` cubre el arranque de la app: si ya estaban
/// activados, se reprograman con el nombre/apodo más reciente (por si se
/// cambiaron desde la última vez que se abrió la app, cuando el texto ya
/// programado se habría quedado con los datos viejos). Volver a programar
/// con los mismos datos no tiene costo — `zonedSchedule` con el mismo id
/// simplemente reemplaza el aviso pendiente.
final recordatoriosSyncProvider = Provider<void>((ref) {
  ref.listen(perfilProvider, (anterior, actual) {
    final perfil = actual.value;
    if (perfil == null) return;
    if (!perfil.recordatoriosActivados) {
      RecordatoriosService.cancelarTodos();
      return;
    }
    RecordatoriosService.programar(
      horaMediodiaMinutos: perfil.horaRecordatorio1,
      horaNocheMinutos: perfil.horaRecordatorio2,
      nombreAsistente: perfil.nombreAsistente,
      nombreSaludo: datosDeSaludo(
        FirebaseAuth.instance.currentUser,
        perfil.apodo,
      ).nombre,
    );
  }, fireImmediately: true);
});
