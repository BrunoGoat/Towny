import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/model/arrival.dart';
import 'package:la_muralla/model/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Store> _store() async {
  SharedPreferences.setMockInitialValues({});
  final s = Store();
  await s.load();
  s.renameHabit(0, name: 'Leer', symbol: 'libro');
  return s;
}

/// Un buzón, tal como llega del otro lado: mapas sueltos y nada de fiar.
List<Object?> _inbox(List<(int, String, DateTime)> e) => [
  for (final (n, id, t) in e) {'n': n, 'h': id, 't': t.millisecondsSinceEpoch},
];

void main() {
  group('lo que llega del buzón', () {
    test('se entiende, y lo que no se entiende se tira', () {
      final t = DateTime(2026, 5, 4, 19);
      final leidas = Arrival.parseAll([
        {'n': 2, 'h': 'h0', 't': t.millisecondsSinceEpoch},
        {'n': 1, 'h': 'h0', 't': t.millisecondsSinceEpoch},
        // Las cinco maneras de venir roto.
        {'n': 3, 'h': 'h0'},
        {'n': 4, 't': t.millisecondsSinceEpoch},
        {'h': 'h0', 't': t.millisecondsSinceEpoch},
        {'n': 5, 'h': '', 't': t.millisecondsSinceEpoch},
        'esto no es un mapa',
      ]);
      expect(leidas.length, 2);
      // Y en orden de número, no en el que venían.
      expect(leidas.first.serial, 1);
      expect(leidas.last.serial, 2);
    });

    test('un buzón que no es una lista no revienta nada', () {
      expect(Arrival.parseAll(null), isEmpty);
      expect(Arrival.parseAll('{}'), isEmpty);
    });
  });

  group('poner lo que llegó', () {
    test(
      'la pieza es del hábito que dice, no del que se está mirando',
      () async {
        final s = await _store();
        s.addHabit('Correr', 'carrera');
        final leer = s.habits[0], correr = s.habits[1];
        s.select(0);
        expect(s.habit.id, leer.id);

        final puestas = s.applyArrivals(
          Arrival.parseAll(_inbox([(1, correr.id, DateTime(2026, 5, 4, 19))])),
        );
        expect(puestas.length, 1);
        expect(leer.total, 0, reason: 'la puso en el pueblo que se miraba');
        expect(correr.total, 1);
        // Y no cambió de pueblo por su cuenta: nadie pidió eso.
        expect(s.active, 0);
      },
    );

    test('con la hora a la que se tocó, no con la de llegada', () async {
      final s = await _store();
      final h = s.habits.first;
      // Al milisegundo, que es la resolución con la que el buzón guarda la
      // hora: pedirle microsegundos sería pedirle algo que no cruza el canal.
      final anoche = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now()
            .subtract(const Duration(hours: 14))
            .millisecondsSinceEpoch,
      );
      s.applyArrivals(Arrival.parseAll(_inbox([(1, h.id, anoche)])));
      expect(h.pieces.single.placedAt, anoche);
    });

    test(
      'la que llega tarde entra en su sitio y los números quedan bien',
      () async {
        final s = await _store();
        final h = s.habits.first;
        final base = DateTime.now().subtract(const Duration(hours: 6));
        // Dos puestas en la app, y una del widget que pasó entre las dos.
        s.lay(h, base);
        s.lay(h, base.add(const Duration(hours: 4)));
        s.applyArrivals(
          Arrival.parseAll(
            _inbox([(1, h.id, base.add(const Duration(hours: 2)))]),
          ),
        );

        expect(h.total, 3);
        for (var i = 0; i < h.pieces.length; i++) {
          expect(h.pieces[i].index, i, reason: 'la pieza $i lleva otro número');
          if (i > 0) {
            expect(
              h.pieces[i].placedAt.isBefore(h.pieces[i - 1].placedAt),
              isFalse,
              reason: 'la fila del pueblo va hacia atrás en el tiempo',
            );
          }
        }
        expect(h.lastPlacedAt, base.add(const Duration(hours: 4)));
      },
    );

    test('la misma llegada dos veces es una sola pieza', () async {
      final s = await _store();
      final h = s.habits.first;
      final buzon = _inbox([(1, h.id, DateTime.now())]);
      expect(s.applyArrivals(Arrival.parseAll(buzon)).length, 1);
      // El buzón la reenvía porque la app murió antes de confirmarlo.
      expect(s.applyArrivals(Arrival.parseAll(buzon)), isEmpty);
      expect(h.total, 1);
    });

    test('y sobrevive a cerrar la app, que es de lo que se trata', () async {
      SharedPreferences.setMockInitialValues({});
      final uno = Store();
      await uno.load();
      final id = uno.habit.id;
      final buzon = _inbox([(7, id, DateTime.now())]);
      uno.applyArrivals(Arrival.parseAll(buzon));
      expect(uno.habit.total, 1);
      // Se guarda en un microtask; hay que dejarlo correr.
      await Future<void>.delayed(Duration.zero);

      final dos = Store();
      await dos.load();
      expect(dos.applyArrivals(Arrival.parseAll(buzon)), isEmpty);
      expect(dos.habit.total, 1, reason: 'la contó dos veces entre arranques');
    });

    test('la de un pueblo que ya no existe se tira, y no vuelve', () async {
      final s = await _store();
      final buzon = _inbox([(3, 'un-pueblo-borrado', DateTime.now())]);
      expect(s.applyArrivals(Arrival.parseAll(buzon)), isEmpty);
      // Pero queda entregada: si no, el buzón la reenvía para siempre.
      s.addHabit('Correr', 'carrera');
      expect(s.applyArrivals(Arrival.parseAll(buzon)), isEmpty);
    });

    test('una del futuro se recorta a ahora', () async {
      final s = await _store();
      final h = s.habits.first;
      final antes = DateTime.now();
      s.applyArrivals(
        Arrival.parseAll(
          _inbox([(1, h.id, DateTime.now().add(const Duration(days: 3)))]),
        ),
      );
      expect(h.pieces.single.placedAt.isAfter(DateTime.now()), isFalse);
      expect(
        h.pieces.single.placedAt.isBefore(
          antes.subtract(const Duration(seconds: 5)),
        ),
        isFalse,
      );
    });

    test('despierta un pueblo dormido, igual que el botón', () async {
      final s = await _store();
      final h = s.habits.first;
      final hasta = DateTime.now().add(const Duration(days: 4));
      s.rest(h, hasta);
      expect(h.resting, isTrue);
      s.applyArrivals(Arrival.parseAll(_inbox([(1, h.id, DateTime.now())])));
      expect(h.resting, isFalse, reason: 'el pueblo siguió dormido');
    });

    test('tres del mismo hábito en un día son tres piezas', () async {
      // Nada limita cuántas veces se puede tocar la misma fila, y es a
      // propósito: dentro de la app tampoco hay un tope de una por día, y una
      // app que te dejara apuntar dos cosas hechas y te contara una sola
      // estaría mintiendo sobre lo único que promete contar bien.
      final s = await _store();
      final h = s.habits.first;
      final t0 = DateTime.now().subtract(const Duration(hours: 8));
      final uno = t0.add(const Duration(hours: 3));
      final dos = t0.add(const Duration(hours: 5));
      final puestas = s.applyArrivals(
        Arrival.parseAll(
          _inbox([(1, h.id, t0), (2, h.id, uno), (3, h.id, dos)]),
        ),
      );
      expect(puestas.length, 3);
      expect(h.total, 3);
      // Y cada una con su hora, que es lo que hace que el tablón sepa a qué
      // hora aparecés de verdad.
      expect(h.pieces.map((p) => p.placedAt.hour).toList(), [
        t0.hour,
        uno.hour,
        dos.hour,
      ]);
    });

    test(
      'varias, en el orden en que pasaron y no en el que llegaron',
      () async {
        final s = await _store();
        s.addHabit('Correr', 'carrera');
        final leer = s.habits[0], correr = s.habits[1];
        final t0 = DateTime.now().subtract(const Duration(hours: 9));
        final puestas = s.applyArrivals(
          Arrival.parseAll(
            _inbox([
              (3, leer.id, t0.add(const Duration(hours: 4))),
              (1, correr.id, t0.add(const Duration(hours: 1))),
              (2, leer.id, t0),
            ]),
          ),
        );
        expect(puestas.map((a) => a.serial).toList(), [2, 1, 3]);
        expect(leer.total, 2);
        expect(correr.total, 1);
      },
    );
  });
}
