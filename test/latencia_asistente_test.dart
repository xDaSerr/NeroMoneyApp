import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/features/accounts/data/cuenta.dart';
import 'package:neromoney_app/features/assistant/data/asistente_repository.dart';
import 'package:neromoney_app/features/assistant/data/mensaje_chat.dart';
import 'package:neromoney_app/features/transactions/data/transacciones_repository.dart';

typedef Responder = Future<Map<String, dynamic>> Function(dynamic datos);

class FuncionesFalsas implements FirebaseFunctions {
  FuncionesFalsas(this.responder);
  final Responder responder;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, 'interpretarMensajeIA');
    return LlamadaFalsa(responder);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LlamadaFalsa implements HttpsCallable {
  LlamadaFalsa(this.responder);
  final Responder responder;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async =>
      ResultadoFalso<T>((await responder(parameters)) as T);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ResultadoFalso<T> implements HttpsCallableResult<T> {
  ResultadoFalso(this.data);
  @override
  final T data;
}

void main() {
  late FakeFirebaseFirestore db;
  const cuenta = Cuenta(
    id: 'efectivo',
    nombre: 'Efectivo',
    tipo: TipoCuenta.efectivo,
    saldoActual: 500,
  );
  final extraido = <String, dynamic>{
    'tipo': 'transaccion_extraida',
    'datos': {
      'tipo': 'gasto',
      'monto': 100,
      'categoria': 'Alimentación',
      'descripcion': 'café',
      'cuentaMencionada': 'efectivo',
    },
  };
  AsistenteRepository crear(Responder responder) => AsistenteRepository(
    db,
    FuncionesFalsas(responder),
    'prueba',
    TransaccionesRepository(db, 'prueba'),
  );
  Future<num> saldo() async =>
      (await db.doc('usuarios/prueba/cuentas/efectivo').get())
              .data()!['saldoActual']
          as num;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.doc('usuarios/prueba/cuentas/efectivo').set(cuenta.toFirestore());
    await db
        .collection('usuarios/prueba/mensajesAsistente')
        .add(
          MensajeChat(
            id: '',
            autor: AutorMensaje.asistente,
            contenido: 'Mensaje anterior',
            fecha: DateTime(2026, 1, 1),
          ).toFirestore(),
        );
  });

  test(
    'conserva historial previo y confirma solamente después de registrar',
    () async {
      final inicioApi = Completer<dynamic>();
      final respuestaApi = Completer<Map<String, dynamic>>();
      final repo = crear((datos) {
        inicioApi.complete(datos);
        return respuestaApi.future;
      });
      final envio = repo.enviarMensaje('Gasté 100 en café en efectivo', [
        cuenta,
      ]);
      final datos = await inicioApi.future as Map;
      expect(datos['historial'], [
        {'role': 'assistant', 'content': 'Mensaje anterior'},
      ]);
      expect(datos['nombresCuentas'], ['Efectivo']);
      expect(
        (await db.collection('usuarios/prueba/mensajesAsistente').get()).size,
        2,
      );
      expect(await saldo(), 500);
      expect(repo.ultimaRespuesta, isNull);
      respuestaApi.complete(extraido);
      await envio;
      expect(await saldo(), 400);
      expect(
        (await db.collection('usuarios/prueba/transacciones').get()).size,
        1,
      );
      expect(repo.ultimaRespuesta!.registrado, isTrue);
      expect(
        repo.ultimaMedicion!.keys,
        containsAll([
          'preparacion_ms',
          'historial_ms',
          'movimientos_ms',
          'borrador_ms',
          'guardar_mensaje_ms',
          'funcion_ia_ms',
          'resolver_y_guardar_ms',
          'total_ms',
          'fallo',
        ]),
      );
      expect(repo.ultimaMedicion!['fallo'], false);
      expect(
        repo.ultimaMedicion!.values.every((v) => v is int || v is bool),
        isTrue,
      );
    },
  );

  test(
    'error de IA no cambia saldo ni confirma un gasto y queda medido',
    () async {
      final repo = crear(
        (_) async => throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Prueba',
        ),
      );
      await repo.enviarMensaje('Gasté 100 en café en efectivo', [cuenta]);
      expect(await saldo(), 500);
      expect(
        (await db.collection('usuarios/prueba/transacciones').get()).size,
        0,
      );
      expect(repo.ultimaRespuesta!.registrado, false);
      expect(repo.ultimaMedicion!['fallo'], true);
    },
  );

  test(
    'un gasto sin saldo suficiente conserva la validación del repositorio',
    () async {
      final repo = crear(
        (_) async => {
          ...extraido,
          'datos': {...extraido['datos'] as Map, 'monto': 600},
        },
      );
      await repo.enviarMensaje('Gasté 600 en café en efectivo', [cuenta]);
      expect(await saldo(), 500);
      expect(
        (await db.collection('usuarios/prueba/transacciones').get()).size,
        0,
      );
      expect(repo.ultimaRespuesta!.registrado, false);
    },
  );
}
