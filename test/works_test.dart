import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';
import 'package:la_muralla/model/works_log.dart';
import 'package:la_muralla/ui/overlays.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:la_muralla/ui/works_calendar.dart';

/// Un pueblo de [n] piezas, una por día desde el 1 de marzo, con la crónica
/// que le tocaría.
Habit _habit(int n, {DateTime? desde, List<int>? saltos}) {
  final start = desde ?? DateTime(2026, 3, 1, 19, 30);
  final h = Habit(
    id: 'h1758000000000001',
    name: 'Leer',
    symbol: 'rueda',
    slot: 0,
    createdAt: start,
    character: TownCharacter.all.first.order,
  );
  var day = 0;
  for (var i = 0; i < n; i++) {
    // Los saltos son días sin pieza: un pueblo real no crece uno por día.
    if (saltos != null && saltos.contains(i)) day += 9;
    h.pieces.add(
      Piece(
        index: i,
        placedAt: start.add(Duration(days: day)),
      ),
    );
    day++;
  }
  final plan = TownPlan.of(h.place, seed: h.townSeed);
  h.chronicle.addAll(plan.chronicleFor(n, const []));
  return h;
}

void main() {
  group('cuándo se levantó cada obra', () {
    test('cada una empieza y acaba en las piezas que dice el plan', () {
      // La prueba de fondo: las fechas no se guardan en ningún sitio, se
      // derivan. Si el tramo de piezas que se le atribuye a una obra no es el
      // que el plan le dio, todas las fechas del libro son mentira.
      final h = _habit(300);
      final plan = TownPlan.of(h.place, seed: h.townSeed);
      final obras = worksOf(h);
      expect(obras, isNotEmpty);
      for (final o in obras) {
        expect(o.began, h.pieces[o.from].placedAt, reason: o.name);
        final last = o.from + o.cost - 1;
        if (o.done) {
          expect(o.ended, h.pieces[last].placedAt, reason: o.name);
        } else {
          expect(last, greaterThanOrEqualTo(h.total), reason: o.name);
        }
        expect(TownPlan.landmarkOf(o.id)!.cost, o.cost, reason: o.name);
        expect(plan.hasFinished(o.id, h.total, h.chronicle), o.done);
      }
    });

    test('no se cuelan las casas ni lo que todavía no empezó', () {
      // Sólo hitos: doscientas entradas de «casa» entre dos catedrales no son
      // un calendario. Y nada del futuro: lo que el plan dice más allá de la
      // última pieza es una previsión, y una previsión no tiene fecha.
      final h = _habit(200);
      for (final o in worksOf(h)) {
        expect(TownPlan.landmarkOf(o.id), isNotNull, reason: o.id);
        expect(o.from, lessThan(h.total), reason: o.name);
      }
    });

    test('van en orden y no se pisan', () {
      final obras = worksOf(_habit(400));
      for (var i = 1; i < obras.length; i++) {
        expect(
          obras[i].from,
          greaterThanOrEqualTo(obras[i - 1].from + obras[i - 1].cost),
          reason: '${obras[i - 1].name} y ${obras[i].name}',
        );
        expect(
          obras[i].began.isBefore(obras[i - 1].began),
          isFalse,
          reason: '${obras[i].name} empezó antes que la anterior',
        );
      }
    });

    test('los días son de calendario, no de piezas', () {
      // Lo que cuenta de una obra no es lo que costó sino lo que duró: veinte
      // piezas pueden ser veinte días o tres meses, y ésa es toda la idea.
      final h = _habit(300, saltos: [40, 80, 120, 160]);
      final obras = worksOf(h).where((o) => o.done).toList();
      expect(obras, isNotEmpty);
      for (final o in obras) {
        expect(o.days, greaterThanOrEqualTo(o.cost), reason: o.name);
        expect(
          o.days,
          dayStart(o.ended!).difference(dayStart(o.began)).inDays + 1,
          reason: o.name,
        );
      }
      // Y alguna tiene que haber cogido uno de los huecos: si ninguna dura más
      // de lo que costó, esto no está midiendo nada.
      expect(obras.any((o) => o.days! > o.cost), isTrue);
    });

    test('empezar y rematar el mismo día es un día, no cero', () {
      final start = DateTime(2026, 5, 4, 8);
      final h = Habit(
        id: 'h1758000000000002',
        name: 'Correr',
        symbol: 'rueda',
        slot: 0,
        createdAt: start,
        character: TownCharacter.all.first.order,
      );
      for (var i = 0; i < 60; i++) {
        h.pieces.add(
          Piece(
            index: i,
            placedAt: start.add(Duration(minutes: 7 * i)),
          ),
        );
      }
      final plan = TownPlan.of(h.place, seed: h.townSeed);
      h.chronicle.addAll(plan.chronicleFor(60, const []));
      for (final o in worksOf(h).where((o) => o.done)) {
        expect(o.days, 1, reason: o.name);
      }
    });

    test('la última puede estar en obra, y entonces no tiene fecha de fin', () {
      // Se recorre pieza a pieza hasta encontrar un pueblo parado en mitad de
      // un hito, que es el estado normal de cualquier pueblo la mayor parte
      // del tiempo.
      var visto = false;
      for (var n = 40; n < 220 && !visto; n++) {
        final obras = worksOf(_habit(n));
        if (obras.isEmpty || obras.last.done) continue;
        visto = true;
        final ultima = obras.last;
        expect(ultima.ended, isNull);
        expect(ultima.days, isNull);
        expect(ultima.from + ultima.cost, greaterThan(n));
        // Y sólo la última: una obra a medias en el medio sería un agujero.
        for (final o in obras.sublist(0, obras.length - 1)) {
          expect(o.done, isTrue, reason: o.name);
        }
      }
      expect(
        visto,
        isTrue,
        reason: 'ningún pueblo quedó con una obra a medias',
      );
    });

    test('un pueblo recién fundado no tiene ninguna', () {
      expect(worksOf(_habit(0)), isEmpty);
    });
  });

  group('la tarjeta del día que se remata', () {
    testWidgets('dice entre qué dos días se levantó y cuántos llevó', (
      tester,
    ) async {
      // Es el momento en que la fecha vale algo: la obra acaba de terminarse y
      // lo que hay debajo son dos meses de tu vida.
      final h = _habit(300);
      final obra = worksOf(h).firstWhere((o) => o.done);
      await tester.pumpWidget(
        MaterialApp(
          home: TownLandmarkOverlay(
            mark: TownPlan.landmarkOf(obra.id)!,
            ordinal: 1,
            theme: UiTheme(Palette.forMoment(13, 1.0)),
            onDismiss: () {},
            span: obra,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('${obra.days} días'),
        findsOneWidget,
        reason: '${obra.name}: ${obra.began} → ${obra.ended}',
      );
      expect(find.textContaining('del ${obra.began.day} de '), findsOneWidget);
    });

    testWidgets('y no dice nada si no lo sabe', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TownLandmarkOverlay(
            mark: TownPlan.landmarkOf('pozo')!,
            ordinal: 1,
            theme: UiTheme(Palette.forMoment(13, 1.0)),
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(' días'), findsNothing);
    });
  });

  group('cómo se reparte el calendario en páginas', () {
    final hoy = DateTime(2029, 1, 1);

    test('un año por página mientras quepan', () {
      final h = _habit(700);
      final obras = worksOf(h);
      final lustro = obras.map((o) => o.began.year).toSet();
      final hojas = calendarPages(obras, fits: 40, today: hoy);
      expect(hojas.length, lustro.length, reason: '${lustro.length} años');
      for (final hoja in hojas) {
        expect(hoja.spans, isNotEmpty);
        expect(
          hoja.spans.map((o) => o.began.year).toSet().length,
          1,
          reason: 'una página con obras de dos años',
        );
      }
    });

    test('y cuando no caben, en tandas de meses seguidos', () {
      final obras = worksOf(_habit(700));
      final hojas = calendarPages(obras, fits: 2, today: hoy);
      expect(hojas.length, greaterThan(3));
      for (final hoja in hojas) {
        expect(hoja.spans.length, lessThanOrEqualTo(2));
        // La ventana empieza el día uno del mes de la primera y acaba después
        // de la última: una página de calendario enseña meses enteros.
        expect(hoja.from.day, 1);
        expect(hoja.to.isAfter(hoja.from), isTrue);
        for (final s in hoja.spans) {
          expect(s.began.isBefore(hoja.from), isFalse, reason: s.name);
          expect(
            (s.ended ?? s.began).isAfter(hoja.to),
            isFalse,
            reason: s.name,
          );
        }
      }
      // Y no se pierde ninguna por el camino.
      expect(
        hojas.expand((h) => h.spans).map((o) => o.from).toList(),
        obras.map((o) => o.from).toList(),
      );
    });

    test('la que está en obra se cuenta hasta hoy, no hasta nunca', () {
      final obras = worksOf(_habit(200));
      final hojas = calendarPages(obras, fits: 40, today: hoy);
      final ultima = hojas.last.spans.last;
      if (ultima.done) return;
      expect(hojas.last.to.isAfter(hoy), isTrue);
    });

    test('sin obras no hay páginas', () {
      expect(calendarPages(const [], fits: 10, today: hoy), isEmpty);
    });
  });
}
