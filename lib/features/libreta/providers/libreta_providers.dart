import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../transactions/data/transacciones_repository.dart';
import '../data/apunte_libreta.dart';
import '../data/libreta_repository.dart';

final libretaRepositoryProvider = Provider<LibretaRepository>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('libretaRepositoryProvider usado sin sesión activa');
  }
  return LibretaRepository(
    FirebaseFirestore.instance,
    uid,
    TransaccionesRepository(FirebaseFirestore.instance, uid),
  );
});

final apuntesLibretaProvider = StreamProvider<List<ApunteLibreta>>((ref) {
  return ref.watch(libretaRepositoryProvider).observar();
});
