import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/core/widgets/barra_flotante.dart';

void main() {
  testWidgets('toque navega; mantener anima solo el centro y soltar termina', (
    tester,
  ) async {
    var pulsado = false;
    var inicios = 0;
    var finales = 0;
    int? destino;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Align(
              alignment: Alignment.bottomCenter,
              child: BarraFlotante(
                indiceActual: 0,
                onSeleccionar: (i) => destino = i,
                avatarBase64: null,
                coloresAnillo: null,
                nombreAsistente: 'Lucy',
                pulsado: pulsado,
                ocupado: pulsado,
                enviando: false,
                nivel: .5,
                onMantener: () {
                  inicios++;
                  setState(() => pulsado = true);
                },
                onSoltar: () {
                  finales++;
                  setState(() => pulsado = false);
                },
                onCancelar: () => setState(() => pulsado = false),
              ),
            ),
          ),
        ),
      ),
    );
    final boton = find.byKey(const ValueKey('boton-asistente-global'));
    final inicio = tester.getRect(find.byKey(const ValueKey('destino-0')));
    final perfil = tester.getRect(find.byKey(const ValueKey('destino-4')));
    await tester.tap(boton);
    await tester.pump();
    expect(destino, 2);
    expect(inicios, 0);
    destino = null;
    final gesto = await tester.startGesture(tester.getCenter(boton));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(inicios, 1);
    expect(destino, isNull);
    expect(pulsado, isTrue);
    expect(tester.getRect(find.byKey(const ValueKey('destino-0'))), inicio);
    expect(tester.getRect(find.byKey(const ValueKey('destino-4'))), perfil);
    await gesto.up();
    await tester.pumpAndSettle();
    expect(finales, 1);
    expect(pulsado, isFalse);
    expect(destino, isNull);
    expect(tester.takeException(), isNull);
  });
}
