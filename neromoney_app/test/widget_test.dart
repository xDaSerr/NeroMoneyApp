// Smoke test básico. Probar NeroMoneyApp completo requeriría inicializar
// Firebase (o mockearlo con paquetes como firebase_auth_mocks), así que por
// ahora probamos un widget puro que no depende de plugins nativos.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/core/widgets/gradient_button.dart';

void main() {
  testWidgets('GradientButton dispara onPressed al tocarlo', (WidgetTester tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradientButton(label: 'Continuar', onPressed: () => tapped = true),
        ),
      ),
    );

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
