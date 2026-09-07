import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../../transactions/data/transacciones_repository.dart';
import '../data/asistente_repository.dart';
import '../data/borrador_pendiente.dart';
import '../data/mensaje_chat.dart';

final asistenteRepositoryProvider = Provider<AsistenteRepository>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('asistenteRepositoryProvider usado sin sesión activa');
  }
  return AsistenteRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instance,
    uid,
    TransaccionesRepository(FirebaseFirestore.instance, uid),
  );
});

final mensajesChatProvider = StreamProvider<List<MensajeChat>>((ref) {
  return ref.watch(asistenteRepositoryProvider).observarMensajes();
});

final borradorPendienteProvider = StreamProvider<BorradorPendiente?>((ref) {
  return ref.watch(asistenteRepositoryProvider).observarBorrador();
});
