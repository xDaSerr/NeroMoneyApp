import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/voz_asistente.dart';

final vozAsistenteProvider = Provider<VozAsistente>((ref) {
  final voz = VozAsistente();
  ref.onDispose(() => unawaited(voz.detener()));
  return voz;
});
