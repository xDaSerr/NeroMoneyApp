import 'package:flutter_test/flutter_test.dart';
import 'package:neromoney_app/features/assistant/data/asistente_repository.dart';

void main() {
  // Lunes 23 de noviembre de 2026, 18:40.
  final ahora = DateTime(2026, 11, 23, 18, 40);
  final resolver = AsistenteRepository.resolverFecha;

  test('sin fecha ni hora: ahora mismo', () {
    final r = resolver('', '', ahora);
    expect(r.esAhora, isTrue);
    expect(r.error, isNull);
  });

  test('gasto olvidado sin hora: ese día, al mediodía y sin hora', () {
    final r = resolver('2026-11-20', '', ahora);
    expect(r.fecha, DateTime(2026, 11, 20, 12));
    expect(r.sinHora, isTrue);
    expect(r.esAhora, isFalse);
  });

  test('gasto olvidado con hora: ese día a esa hora', () {
    final r = resolver('2026-11-20', '15:30', ahora);
    expect(r.fecha, DateTime(2026, 11, 20, 15, 30));
    expect(r.sinHora, isFalse);
  });

  test('hoy con una hora que ya pasó', () {
    final r = resolver('2026-11-23', '09:05', ahora);
    expect(r.fecha, DateTime(2026, 11, 23, 9, 5));
    expect(r.esAhora, isFalse);
  });

  test('hoy con una hora que no ha llegado: lo dice en vez de guardarlo', () {
    expect(resolver('', '21:00', ahora).error, isNotNull);
  });

  test('nunca en el futuro ni hace más de un año', () {
    expect(resolver('2026-11-24', '', ahora).error, isNotNull);
    expect(resolver('2024-11-20', '', ahora).error, isNotNull);
  });

  test('fechas y horas inválidas se ignoran: cuenta como ahora', () {
    expect(resolver('2026-02-31', '', ahora).esAhora, isTrue);
    expect(resolver('ayer', '25:00', ahora).esAhora, isTrue);
  });
}
