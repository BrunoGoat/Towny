import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';
import 'package:la_muralla/model/reel.dart';

final _inicio = DateTime(2026, 3, 1, 9);

/// Un hábito con las piezas puestas en los días que se le digan. Fracciones
/// admitidas: 0.5 es doce horas después, que es como se ponen dos en un día.
Habit _habit(List<double> dias, {int slot = 0, String id = 'h'}) => Habit(
  id: id,
  name: 'Prueba',
  symbol: 'rueda',
  slot: slot,
  createdAt: _inicio,
  character: TownCharacter.all.first.order,
  pieces: [
    for (var i = 0; i < dias.length; i++)
      Piece(
        index: i,
        placedAt: _inicio.add(Duration(minutes: (dias[i] * 1440).round())),
      ),
  ],
);

/// Una al día durante [n] días.
Habit _seguidas(int n, {int slot = 0, String id = 'h', double desde = 0}) =>
    _habit([for (var i = 0; i < n; i++) desde + i], slot: slot, id: id);

void main() {
  group('el reloj de la reproducción', () {
    test('empieza en la primera pieza y acaba en la última', () {
      final r = Reel.of([_seguidas(30)])!;
      expect(r.pieces, 30);
      expect(r.from, _inicio);
      expect(r.to, _inicio.add(const Duration(days: 29)));
      expect(r.days, 29);
    });

    test(
      'la última pieza cae al empezar la cola, no en el último fotograma',
      () {
        for (final n in [2, 5, 30, 200, 1500]) {
          final r = Reel.of([_seguidas(n)])!;
          expect(
            r.markOf(n - 1),
            closeTo(r.seconds - Reel.tail, 1e-9),
            reason: 'con $n piezas',
          );
        }
      },
    );

    test('hay un valle vacío al principio y un pueblo entero al final', () {
      final r = Reel.of([_seguidas(60)])!;
      // La entrada: el prado, sin nada.
      expect(r.at(Reel.lead * 0.5, 1).done, 0);
      expect(r.at(Reel.lead * 0.5, 1).when, r.from);
      // Y la cola: todo puesto, con tiempo de mirarlo.
      final entra = r.seconds - Reel.tail;
      expect(r.at(entra + 0.01, 1).done, 60);
      expect(r.at(r.seconds - 0.01, 1).done, 60);
    });

    test('dura lo mismo con doce piezas que con mil quinientas', () {
      // El punto entero de que la duración sea fija: mirar esto no puede
      // costar más cuanto más hayas hecho.
      final corto = Reel.of([_seguidas(12)])!;
      final largo = Reel.of([_seguidas(1500)])!;
      expect(corto.seconds, largo.seconds);
    });

    test('nunca va hacia atrás en el tiempo', () {
      final r = Reel.of([_seguidas(120)])!;
      var antes = DateTime(2000);
      var cuenta = 0;
      for (var paso = 0; paso <= 2000; paso++) {
        final t = r.seconds * paso / 2000;
        final m = r.at(t, 1);
        expect(
          m.when.isBefore(antes),
          isFalse,
          reason: 'la fecha retrocedió en el segundo $t',
        );
        expect(m.done, greaterThanOrEqualTo(cuenta));
        antes = m.when;
        cuenta = m.done;
      }
    });

    test('las piezas corridas de hora no desordenan la cola', () {
      // `withWhen` deja mover una pieza a la hora en que se hizo la cosa, así
      // que la lista guardada puede no estar en orden de reloj. Si la cola
      // saliera de ahí tal cual, la reproducción retrocedería a mitad.
      final h = _habit([0, 5, 2, 9, 1]);
      final r = Reel.of([h])!;
      for (var i = 1; i < r.steps.length; i++) {
        expect(
          r.steps[i].when.isBefore(r.steps[i - 1].when),
          isFalse,
          reason: 'la pieza $i cae antes que la anterior',
        );
      }
    });

    test('un hueco largo se ve, pero no se come la reproducción', () {
      // Treinta días parados en medio de dos meses de una al día.
      final r = Reel.of([
        _habit([
          for (var i = 0; i < 30; i++) i.toDouble(),
          for (var i = 0; i < 30; i++) 60.0 + i,
        ]),
      ])!;
      // Lo que ocupa el hueco es lo que va entre la pieza 29 y la 30.
      final hueco = r.markOf(30) - r.markOf(29);
      final normal = r.markOf(20) - r.markOf(19);
      expect(hueco, greaterThan(normal * 3), reason: 'el hueco no se nota');
      expect(
        hueco,
        lessThan(r.seconds * 0.12),
        reason: 'el hueco se come la reproducción',
      );
    });

    test('el tope del hueco no deja que unas vacaciones lo ocupen todo', () {
      final r = Reel.of([
        _habit([0, 1, 2, 400, 401, 402]),
      ])!;
      final vacaciones = r.markOf(3) - r.markOf(2);
      expect(vacaciones, lessThan(r.seconds * 0.6));
    });

    test('dos piezas el mismo minuto no dividen por cero', () {
      final r = Reel.of([
        _habit([0, 0, 0, 1]),
      ])!;
      for (var t = 0.0; t <= r.seconds; t += 0.25) {
        expect(r.at(t, 1).when.isAfter(DateTime(2000)), isTrue);
      }
    });
  });

  group('el valle entero', () {
    test('las piezas de los dos pueblos se intercalan por fecha', () {
      // Uno empieza el día cero y el otro el veinte: el segundo pueblo tiene
      // que aparecer cuando apareció, no desde el principio.
      final r = Reel.of([
        _seguidas(40, id: 'a'),
        _seguidas(20, id: 'b', slot: 1, desde: 20),
      ])!;
      expect(r.pieces, 60);

      final pronto = r.at(r.seconds * 0.15, 2);
      expect(pronto.counts[0], greaterThan(0));
      expect(
        pronto.counts[1],
        0,
        reason: 'el segundo pueblo llegó antes de ser',
      );

      final alFinal = r.at(r.seconds, 2);
      expect(alFinal.counts[0], 40);
      expect(alFinal.counts[1], 20);
    });

    test('la cuenta de cada pueblo sólo sube', () {
      final r = Reel.of([
        _seguidas(40, id: 'a'),
        _seguidas(30, id: 'b', slot: 1, desde: 12),
      ])!;
      var antes = [0, 0];
      for (var paso = 0; paso <= 2000; paso++) {
        final t = r.seconds * paso / 2000;
        final c = r.at(t, 2).counts;
        expect(c[0], greaterThanOrEqualTo(antes[0]));
        expect(c[1], greaterThanOrEqualTo(antes[1]));
        antes = c;
      }
      expect(antes, [40, 30]);
    });

    test('al final está el pueblo entero, no uno menos', () {
      // Pasarse por uno aquí quiere decir que la cinemática acaba enseñando un
      // pueblo que no es el que tenés, que es la única cosa que esta pantalla
      // no se puede permitir.
      final r = Reel.of([_seguidas(77)])!;
      expect(r.at(r.seconds, 1).counts[0], 77);
      expect(r.at(r.seconds * 2, 1).counts[0], 77, reason: 'pasado el final');
    });
  });

  group('cuándo se ofrece', () {
    test('no con cuatro piezas', () {
      expect(Reel.worthIt([_seguidas(4)]), isFalse);
    });

    test('no con doce puestas la misma tarde', () {
      expect(
        Reel.worthIt([
          _habit([for (var i = 0; i < 12; i++) i * 0.02]),
        ]),
        isFalse,
      );
    });

    test('sí con doce en dos semanas', () {
      expect(
        Reel.worthIt([
          _habit([for (var i = 0; i < 12; i++) i * 1.2]),
        ]),
        isTrue,
      );
    });

    test('un pueblo vacío no rompe nada', () {
      expect(Reel.worthIt([_habit([])]), isFalse);
      expect(Reel.of([_habit([])]), isNull);
      expect(
        Reel.of([
          _habit([0]),
        ]),
        isNull,
      );
    });
  });

  group('el plano entero cortado', () {
    test('es, pieza por pieza, el plano corto', () {
      // De esto depende que la cinemática exista tal como está escrita.
      //
      // `ReelScreen` levanta **un** plano por hábito, el entero, y lo único que
      // mueve durante el minuto es la cuenta que le pasa a `builtTown`. Lo
      // obvio sería levantar el plano de cada cuenta —el de 5 piezas, el de 6,
      // el de 7—, y no se puede: uno de mil quinientas tarda diez milisegundos
      // y hay sesenta fotogramas por segundo que servir.
      //
      // El atajo vale **si y sólo si** el plano largo, cortado por la pieza k,
      // es el plano de k. Si algún día un cambio en el reparto de solares
      // hiciera que el número total de edificios moviera de sitio a los
      // primeros, lo que se vería aquí son casas saltando por el prado
      // mientras crece el pueblo — y no habría ninguna otra pista de por qué.
      for (final ch in TownCharacter.all) {
        final entero = TownLayout(900, ch, seed: 7);
        for (final k in [1, 5, 40, 137, 400, 899]) {
          final corto = TownLayout(k, ch, seed: 7);
          expect(entero.pieces.length, greaterThanOrEqualTo(k));
          for (var i = 0; i < k; i++) {
            final a = entero.pieces[i], b = corto.pieces[i];
            expect(
              [a.cx, a.cz, a.y0, a.y1, a.w, a.d, a.kind.index, a.building],
              [b.cx, b.cz, b.y0, b.y1, b.w, b.d, b.kind.index, b.building],
              reason:
                  '${ch.region}: la pieza $i se mueve entre el plano de $k '
                  'y el de 900',
            );
          }
        }
      }
    });
  });
}
