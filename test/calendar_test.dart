import 'package:flutter_test/flutter_test.dart';
import 'package:towny/model/piece.dart';

/// Las cuentas de días son de calendario, no de veinticuatro horas.
///
/// Donde hay horario de verano, el día que cambia la hora dura veintitrés o
/// veinticinco, y contar con `Duration` se corría una hora cada vez que lo
/// cruzaba: un día dejaba de contarse. Estas pruebas dicen lo que tiene que
/// pasar en cualquier zona; para ver el fallo de verdad, la suite entera se
/// corre en una con cambio de hora reciente:
///
///   TZ=Pacific/Auckland flutter test
void main() {
  test('sumar días deja la misma hora del reloj', () {
    // Cruza los cambios de hora de los dos hemisferios.
    for (final desde in [
      DateTime(2026, 3, 20, 9, 30),
      DateTime(2026, 9, 20, 9, 30),
      DateTime(2026, 10, 20, 9, 30),
    ]) {
      for (final n in [1, 14, 30, -30]) {
        final d = shiftDays(desde, n);
        expect(d.hour, 9, reason: '$desde + $n');
        expect(d.minute, 30);
        expect(daysBetween(desde, d), n);
      }
    }
  });

  test('entre dos fechas cuentan los días, no las horas', () {
    expect(daysBetween(DateTime(2026, 4, 1, 23, 59), DateTime(2026, 4, 2)), 1);
    expect(daysBetween(DateTime(2026, 4, 2), DateTime(2026, 4, 1, 23, 59)), -1);
    expect(daysBetween(DateTime(2026, 4, 1), DateTime(2026, 4, 1, 23)), 0);
    expect(daysBetween(DateTime(2026, 2, 27), DateTime(2026, 3, 2)), 3);
    expect(daysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 1)), 1);
  });

  test('medianoche más un día es la medianoche siguiente', () {
    var d = DateTime(2026, 3, 1);
    for (var i = 0; i < 400; i++) {
      d = shiftDays(d, 1);
      expect(d.hour, 0, reason: '$d');
    }
  });
}
