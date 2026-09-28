import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';
import 'package:la_muralla/model/review.dart';
import 'package:la_muralla/ui/review_page.dart';

/// **La cuenta del mes y la del año.**
///
/// Lo único que esta app no sabía decir: cómo fue el mes. Se ve cómo va hoy
/// —cuántas piezas, qué está en obra— y eso no sirve para corregir nada, porque
/// para corregir hay que poder comparar un tramo cerrado con el anterior.
///
/// No se guarda nada: sale de las fechas de las piezas, de la crónica y de las
/// pausas, igual que el calendario de las obras. Por eso lo que hay que probar
/// es la aritmética, y sobre todo las tres reglas que no son obvias: que un día
/// dormido no es un hueco, que los días en blanco del final de un mes que sigue
/// abierto tampoco lo son, y que hoy en blanco no cuenta en contra.
Habit _town(
  List<DateTime> when, {
  DateTime? born,
  List<String> rests = const [],
  int? vowHour,
  String? identity,
}) {
  final h = Habit(
    id: 'h1758000000000009',
    name: 'Leer',
    symbol: 'rueda',
    slot: 0,
    createdAt: born ?? DateTime(2026, 1, 5),
    character: TownCharacter.all.first.order,
    vowHour: vowHour,
    identity: identity,
    rests: [...rests],
  );
  final orden = [...when]..sort();
  for (var i = 0; i < orden.length; i++) {
    h.pieces.add(Piece(index: i, placedAt: orden[i]));
  }
  final plan = TownPlan.of(h.place, seed: h.townSeed);
  h.chronicle.addAll(plan.chronicleFor(h.pieces.length, const []));
  return h;
}

List<DateTime> _days(
  int year,
  int month,
  Iterable<int> days, {
  int hour = 21,
}) => [for (final d in days) DateTime(year, month, d, hour)];

final DateTime _hoy = DateTime(2026, 6, 15, 10);

void main() {
  group('la cuenta de un mes', () {
    /// Marzo flojo, abril con un hueco de nueve días en el medio, junio en
    /// marcha. Es el pueblo con el que se cuentan todas las de abajo.
    Habit pueblo() => _town([
      ..._days(2026, 3, [2, 5, 9, 14, 21, 28]),
      ..._days(2026, 4, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20]),
      ..._days(2026, 6, [1, 2, 3, 4, 5]),
    ]);

    test('los días con pieza contra los días que contaban', () {
      final r = Review.forMonth(pueblo(), 2026, 4, now: _hoy);
      expect(r.open, isFalse);
      expect(r.heading, 'ASÍ FUE ABRIL');
      expect(r.pieces, 11);
      expect(r.days, 11);
      expect(r.of, 30);
      expect(r.enough, isTrue);
    });

    test('un hueco es faltar y volver, y se mide en los días del medio', () {
      final r = Review.forMonth(pueblo(), 2026, 4, now: _hoy);
      expect(r.gaps, 1);
      expect(r.longest, 9, reason: 'del 11 al 19');
    });

    test('los días en blanco del final de un mes abierto no son un hueco', () {
      // Es la regla que evita la cuenta más injusta de todas: el día 3 del mes,
      // con una pieza el día 1, decir que llevás un hueco de dos días. Todavía
      // no hay hueco: hay un mes que no ha acabado.
      final r = Review.forMonth(pueblo(), 2026, 6, now: _hoy);
      expect(r.open, isTrue);
      expect(r.heading, 'ASÍ VA ESTE MES');
      expect(r.days, 5);
      expect(r.gaps, 0);
      // Del 1 al 15, menos hoy, que sigue en blanco y no cuenta en contra.
      expect(r.of, 14);
    });

    test('lo de después del mes no se cuela', () {
      // Abril cuenta abril: si la ventana se pasara un día, entrarían las
      // piezas de mayo y la cuenta del mes sería la de otro mes.
      final r = Review.forMonth(
        _town(_days(2026, 5, [1, 2, 3])),
        2026,
        4,
        now: _hoy,
      );
      expect(r.pieces, 0);
      expect(r.days, 0);
      expect(r.enough, isFalse, reason: 'un mes sin nada no es una cuenta');
    });

    test('un día dormido no es un día en blanco ni parte un hueco', () {
      // El mismo abril, con el pueblo dormido del 12 al 18: los siete días de
      // pausa salen de la cuenta y el hueco de nueve pasa a ser de dos.
      final r = Review.forMonth(
        _town(
          [
            ..._days(2026, 4, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20]),
          ],
          rests: [
            Rest(DateTime(2026, 4, 12), DateTime(2026, 4, 19)).encode(),
          ],
        ),
        2026,
        4,
        now: _hoy,
      );
      expect(r.of, 23, reason: '30 días menos los 7 dormidos');
      expect(r.gaps, 1);
      expect(r.longest, 2, reason: 'el 11 y el 19, nada más');
    });

    test('antes de fundar el pueblo no hay días que contar', () {
      final r = Review.forMonth(
        _town(_days(2026, 4, [20, 21, 22]), born: DateTime(2026, 4, 18)),
        2026,
        4,
        now: _hoy,
      );
      expect(r.of, 13, reason: 'del 18 al 30');
    });
  });

  group('contra el tramo anterior', () {
    test('la diferencia se dice en puntos', () {
      final h = _town([
        ..._days(2026, 3, [2, 5, 9, 14, 21, 28]),
        ..._days(2026, 4, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20]),
      ]);
      final abril = Review.forMonth(h, 2026, 4, now: _hoy);
      expect(abril.before, isNotNull);
      expect(abril.before!.days, 6);
      expect(abril.before!.of, 31);
      // 11 de 30 contra 6 de 31: diecisiete puntos más.
      expect(abril.shift, 17);
    });

    test('un mes sin nada detrás no se compara con nada', () {
      // Comparar contra un mes en el que el pueblo no existía sería inventarse
      // una caída desde cero.
      final h = _town(
        _days(2026, 4, [1, 2, 3, 4, 5, 6, 7, 8]),
        born: DateTime(2026, 4, 1),
      );
      final abril = Review.forMonth(h, 2026, 4, now: _hoy);
      expect(abril.before, isNull);
      expect(abril.shift, isNull);
    });

    test('el año se compara con el año', () {
      final h = _town([
        ..._days(2025, 11, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
        ..._days(2026, 1, [1, 2, 3, 4, 5]),
        ..._days(2026, 2, [1, 2, 3, 4, 5]),
      ], born: DateTime(2025, 10, 1));
      final r = Review.forYear(h, 2026, now: _hoy);
      expect(r.monthly, isFalse);
      expect(r.days, 10);
      expect(r.before, isNotNull);
      expect(r.before!.days, 10, reason: 'los diez de noviembre del 25');
    });
  });

  group('las obras y las palabras', () {
    test('sólo las obras rematadas dentro del tramo', () {
      // Un pueblo largo, para que haya obras de verdad que remataron.
      final when = <DateTime>[];
      for (var i = 0; i < 300; i++) {
        when.add(DateTime(2025, 8, 1, 21).add(Duration(days: i)));
      }
      final h = _town(when, born: DateTime(2025, 8, 1));
      for (var m = 1; m <= 5; m++) {
        final r = Review.forMonth(h, 2026, m, now: _hoy);
        for (final w in r.works) {
          expect(w.ended, isNotNull, reason: w.name);
          expect(w.ended!.isBefore(r.from), isFalse, reason: w.name);
          expect(w.ended!.isBefore(r.to), isTrue, reason: w.name);
        }
        final obra = r.underway;
        if (obra != null) {
          expect(obra.began.isBefore(r.to), isTrue, reason: obra.name);
          final fin = obra.ended;
          if (fin != null) expect(fin.isBefore(r.to), isFalse);
        }
      }
    });

    test('el plan se mide sobre las piezas del tramo', () {
      final r = Review.forMonth(
        _town(_days(2026, 4, [1, 2, 3, 4, 5, 6], hour: 22), vowHour: 22),
        2026,
        4,
        now: _hoy,
      );
      expect(r.plan, 'Voy a leer a las 22 de la noche.');
      expect(r.planKept, 1.0);
    });

    test('y sin plan escrito no se inventa ninguno', () {
      final r = Review.forMonth(
        _town(_days(2026, 4, [1, 2, 3, 4, 5, 6])),
        2026,
        4,
        now: _hoy,
      );
      expect(r.plan, isNull);
      expect(r.planKept, isNull);
    });
  });

  group('qué cuentas se enseñan', () {
    test('las cuatro de siempre y ninguna vacía', () {
      final when = <DateTime>[];
      for (var i = 0; i < 400; i++) {
        when.add(DateTime(2025, 5, 1, 21).add(Duration(days: i)));
      }
      final cuentas = Review.latest(_town(when, born: DateTime(2025, 5, 1)),
          now: _hoy);
      expect(cuentas.length, inInclusiveRange(1, 4));
      for (final r in cuentas) {
        expect(r.enough, isTrue);
      }
      // Y no dos veces la misma: la del año no puede ser la del mes repetida.
      final titulos = {for (final r in cuentas) '${r.heading}|${r.from}'};
      expect(titulos.length, cuentas.length);
    });

    test('un pueblo recién fundado todavía no tiene ninguna', () {
      final h = _town(
        _days(2026, 6, [14]),
        born: DateTime(2026, 6, 14),
      );
      expect(Review.latest(h, now: _hoy), isEmpty);
    });

    test('el año en curso no se repite cuando todo cabe en este mes', () {
      final h = _town(
        _days(2026, 6, [1, 2, 3, 4, 5, 6, 7, 8]),
        born: DateTime(2026, 6, 1),
      );
      final cuentas = Review.latest(h, now: _hoy);
      expect(cuentas.length, 1);
      expect(cuentas.first.monthly, isTrue);
    });
  });

  group('la página, escrita', () {
    test('dice lo que la cuenta dice, y en cifras que se leen', () {
      final r = Review.forMonth(
        _town([
          ..._days(2026, 3, [2, 5, 9, 14, 21, 28]),
          ..._days(2026, 4, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20]),
        ]),
        2026,
        4,
        now: _hoy,
      );
      final lines = reviewLines(r);
      final por = {for (final l in lines) l.label: l.said};
      expect(por['LO QUE PUSISTE'], contains('11 piezas'));
      expect(por['LO QUE PUSISTE'], contains('11 de los 30'));
      expect(por['CONTRA EL MES ANTERIOR'], contains('17 puntos más'));
      expect(por['LOS HUECOS'], contains('9 días'));
      // Y abril acabó en blanco: del 21 al 30 no hubo nada, y eso no es un
      // hueco del que se volvió — es cómo acabó el mes.
      expect(por['LOS HUECOS'], contains('el mes acabó con 10 días sin nada'));
      expect(por['LOS HUECOS'], isNot(contains('Volviste de todos')));
      expect(por.containsKey('LO QUE SE LEVANTÓ'), isTrue);
    });

    test('un pueblo que se apagó no dice que no faltó ni un día', () {
      // El fallo que esto cierra, y que se veía en la página: un hueco se cuenta
      // al volver, así que el de siete meses de un pueblo abandonado no se
      // cerraba nunca y la cuenta del año salía con cero huecos. La página
      // anunciaba muy seria que no habías faltado un solo día.
      final h = _town(_days(2026, 1, [1, 2, 3, 4, 5]));
      final r = Review.forYear(h, 2026, now: _hoy);
      expect(r.gaps, 0);
      expect(r.trailing, greaterThan(100));
      final huecos = reviewLines(r).firstWhere((l) => l.label == 'LOS HUECOS');
      expect(huecos.said, isNot(contains('no faltaste')));
      expect(huecos.said, contains('sin poner nada'));
    });

    test('y en un mes en curso, lo que llevás sin aparecer', () {
      final r = Review.forMonth(
        _town(_days(2026, 6, [1, 2, 3, 4, 5])),
        2026,
        6,
        now: _hoy,
      );
      expect(r.open, isTrue);
      final huecos = reviewLines(r).firstWhere((l) => l.label == 'LOS HUECOS');
      // Del 6 al 14: nueve días. Hoy no cuenta, que el día no ha acabado.
      expect(huecos.said, contains('llevás 9 días sin poner nada'));
    });

    test('un mes sin faltar un día lo dice de otra manera', () {
      final r = Review.forMonth(
        _town(_days(2026, 4, [for (var d = 1; d <= 30; d++) d])),
        2026,
        4,
        now: _hoy,
      );
      final huecos = reviewLines(r).firstWhere((l) => l.label == 'LOS HUECOS');
      expect(huecos.said, contains('Ninguno'));
    });

    test('las dos líneas que escribiste vos salen si las escribiste', () {
      final r = Review.forMonth(
        _town(
          _days(2026, 4, [1, 2, 3, 4, 5, 6], hour: 22),
          vowHour: 22,
          identity: 'alguien que lee todos los días',
        ),
        2026,
        4,
        now: _hoy,
      );
      final por = {for (final l in reviewLines(r)) l.label: l.said};
      expect(por['EL PLAN'], contains('Voy a leer a las 22'));
      expect(por['EL PLAN'], contains('100%'));
      expect(por['QUIÉN SOS'], contains('Este pueblo es de alguien que lee'));
      expect(por['QUIÉN SOS'], contains('6 días'));
    });

    test('sin ellas, la página no las inventa', () {
      final r = Review.forMonth(
        _town(_days(2026, 4, [1, 2, 3, 4, 5, 6])),
        2026,
        4,
        now: _hoy,
      );
      final labels = [for (final l in reviewLines(r)) l.label];
      expect(labels, isNot(contains('EL PLAN')));
      expect(labels, isNot(contains('QUIÉN SOS')));
    });
  });
}
