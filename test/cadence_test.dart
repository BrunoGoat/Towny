import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/model/cadence.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';
import 'package:la_muralla/model/rhythm.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/cadence_sheet.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un hábito nacido hace [age] días con pieza los días (contados hacia atrás
/// desde hoy) que diga [on].
Habit _habit({
  required DateTime now,
  int age = 30,
  Iterable<int> on = const [],
  int? perWeek,
}) {
  final today = dayStart(now);
  final dias = on.toList()..sort((a, b) => b.compareTo(a));
  return Habit(
    id: 'h1',
    name: 'Correr',
    symbol: 'carrera',
    slot: 0,
    createdAt: DateTime(today.year, today.month, today.day - age),
    perWeek: perWeek,
    pieces: [
      for (var i = 0; i < dias.length; i++)
        Piece(
          index: i,
          placedAt: DateTime(today.year, today.month, today.day - dias[i], 19),
        ),
    ],
  );
}

void main() {
  final now = DateTime(2026, 5, 20, 21);

  group('lo que se ve', () {
    test('tres días por semana se ven como tres', () {
      // Lunes, miércoles y viernes durante cuatro semanas.
      final h = _habit(
        now: now,
        on: [
          for (var w = 0; w < 4; w++) ...[w * 7 + 1, w * 7 + 3, w * 7 + 5],
        ],
      );
      expect(observedPerWeek(h, at: now), 3);
    });

    test('con menos de una semana no se sabe nada', () {
      final h = _habit(now: now, age: 3, on: [0, 1, 2]);
      expect(observedPerWeek(h, at: now), isNull);
    });

    test('sin decir y sin ver, se supone lo de siempre: todos los días', () {
      final h = _habit(now: now, age: 2, on: [0]);
      expect(perWeekOf(h, at: now), 7);
    });

    test('lo dicho manda sobre lo visto', () {
      final h = _habit(
        now: now,
        on: [for (var i = 0; i < 28; i++) i],
        perWeek: 2,
      );
      expect(perWeekOf(h, at: now), 2);
    });
  });

  group('la pregunta de la primera semana', () {
    test('no antes de la semana', () {
      final h = _habit(now: now, age: 5, on: [0, 1, 3]);
      expect(cadenceDue(h, at: now), isFalse);
    });

    test('a la semana, con al menos dos días con pieza', () {
      expect(
        cadenceDue(
          _habit(now: now, age: 7, on: [0, 3]),
          at: now,
        ),
        isTrue,
      );
      expect(
        cadenceDue(
          _habit(now: now, age: 7, on: [2]),
          at: now,
        ),
        isFalse,
      );
    });

    test('una vez en la vida del hábito, se conteste o no', () {
      final h = _habit(now: now, age: 9, on: [0, 2, 4]);
      h.cadenceAskedAt = now;
      expect(cadenceDue(h, at: now), isFalse);
      final dicho = _habit(now: now, age: 9, on: [0, 2, 4], perWeek: 3);
      expect(cadenceDue(dicho, at: now), isFalse);
    });

    test('lo que se cuenta es la última semana', () {
      final h = _habit(now: now, on: [0, 0, 1, 3, 5, 9]);
      expect(lastWeekOf(h, at: now), (5, 4));
    });
  });

  group('el candado, contra tu ritmo', () {
    test('todos los días es la regla de siempre: diez de catorce', () {
      final g = UnlockGoal.of(
        _habit(now: now, on: [0, 1, 2, 4, 5, 7, 8, 9, 11, 13], perWeek: 7),
        at: now,
      );
      expect(g.window, 14);
      expect(g.need, 10);
      expect(g.have, 10);
      expect(g.met, isTrue);
      expect(g.slack, 4);
    });

    test('sin decir nada se mide como de todos los días', () {
      // Lo visto sale de las mismas piezas que se cuentan: medir contra eso
      // abriría la puerta a cualquiera.
      final g = UnlockGoal.of(
        _habit(now: now, on: [0, 7, 14]),
        at: now,
      );
      expect(g.perWeek, 7);
      expect(g.declared, isFalse);
      expect(g.met, isFalse);
    });

    test('una vez por semana: tres semanas de cuatro', () {
      final g = UnlockGoal.of(
        _habit(now: now, on: [1, 8, 22], perWeek: 1),
        at: now,
      );
      expect(g.window, 28);
      expect(g.need, 3);
      expect(g.have, 3);
      expect(g.met, isTrue);
      expect(g.slack, 1);
    });

    test('lo que pasa de tu ritmo en una semana no cuenta para otra', () {
      // Tres piezas en la misma semana de alguien que va una vez por semana
      // son una semana, no tres.
      final g = UnlockGoal.of(
        _habit(now: now, on: [0, 1, 2], perWeek: 1),
        at: now,
      );
      expect(g.have, 1);
      expect(g.met, isFalse);
    });

    test('tres por semana: cinco en dos semanas', () {
      final g = UnlockGoal.of(
        _habit(now: now, on: [1, 3, 8, 10, 12], perWeek: 3),
        at: now,
      );
      expect(g.window, 14);
      expect(g.need, 5);
      expect(g.met, isTrue);
    });

    test('dos por semana: seis en cuatro semanas', () {
      final g = UnlockGoal.of(
        _habit(now: now, on: [1, 4, 8, 11, 15, 18], perWeek: 2),
        at: now,
      );
      expect(g.window, 28);
      expect(g.need, 6);
      expect(g.met, isTrue);
    });
  });

  group('los huecos, contra lo que dijiste', () {
    test(
      'dos por semana: tres días en blanco entre una y otra son lo suyo',
      () {
        final h = _habit(now: now, age: 3, on: [0], perWeek: 2);
        expect(expectedGap(h), 3);
        expect(Store.awayAfter(h), 8);
        expect(Store.adriftAfter(h), 9);
      },
    );

    test('sin decir nada, lo de siempre', () {
      final h = _habit(now: now, age: 3, on: [0]);
      expect(expectedGap(h), 0);
      expect(Store.awayAfter(h), 3);
      expect(Store.adriftAfter(h), 4);
    });
  });

  group('la constancia, contra tu ritmo', () {
    test('tres de tres por semana es todo, no menos de la mitad', () {
      final h = _habit(
        now: now,
        age: 27,
        on: [
          for (var w = 0; w < 4; w++) ...[w * 7 + 1, w * 7 + 3, w * 7 + 5],
        ],
      );
      final diario = consistencyOf(h, at: now);
      final suyo = consistencyOf(h, at: now, perWeek: 3);
      expect(diario.rate, lessThan(0.5));
      expect(suyo.rate, greaterThan(0.9));
      // Y se habla igual de pronto: dos semanas de calendario, no catorce
      // días esperados.
      expect(suyo.enough, isTrue);
    });
  });

  group('lo que se guarda', () {
    test('la frecuencia y cuándo se preguntó van y vuelven del disco', () {
      final h = _habit(now: now, on: [0], perWeek: 3)..cadenceAskedAt = now;
      final back = Habit.fromJson(h.toJson());
      expect(back.perWeek, 3);
      expect(back.cadenceAskedAt, now);
    });

    test('un número fuera de la semana se lee como que no se dijo', () {
      final j = _habit(now: now, on: [0]).toJson()..['pw'] = 9;
      expect(Habit.fromJson(j).perWeek, isNull);
    });

    test('una copia vieja no la trae, y no pasa nada', () {
      final j = _habit(now: now, on: [0]).toJson();
      expect(j.containsKey('pw'), isFalse);
      expect(Habit.fromJson(j).perWeek, isNull);
    });
  });

  group('decirlo', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'decir un ritmo más holgado abre la puerta con lo ya puesto',
      () async {
        final s = Store();
        await s.load();
        final hoy = dayStart(DateTime.now());
        for (final d in [1, 8, 22]) {
          s.pieces.add(
            Piece(
              index: s.total,
              placedAt: DateTime(hoy.year, hoy.month, hoy.day - d, 19),
            ),
          );
        }
        s.pieces.sort((a, b) => a.placedAt.compareTo(b.placedAt));
        expect(s.unlocked, isFalse);
        s.setCadence(s.habit, 1);
        expect(s.habit.perWeek, 1);
        expect(s.habit.cadenceAskedAt, isNotNull);
        expect(s.unlocked, isTrue);
      },
    );
  });

  group('la hoja de la primera semana', () {
    testWidgets('cabe en un teléfono estrecho y cuenta lo que vio', (
      tester,
    ) async {
      final hoy = DateTime.now();
      final h = _habit(now: hoy, age: 8, on: [0, 1, 1, 3, 5]);
      int? elegido;
      for (final hora in [13.0, 23.0]) {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: CadenceSheet(
                  habit: h,
                  theme: UiTheme(Palette.forMoment(hora)),
                  onPick: (n) => elegido = n,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'a las $hora');
        expect(
          find.text('Esta semana pusiste 5 piezas en 4 días.'),
          findsOneWidget,
        );
      }
      // Viene marcado lo que se ve, y un toque lo confirma.
      expect(
        find.text('Es ${cadenceSaid(observedPerWeek(h)!)}'),
        findsOneWidget,
      );
      await tester.tap(find.text('3 por semana'));
      await tester.pump();
      await tester.ensureVisible(find.text('Es 3 veces por semana'));
      await tester.pump();
      await tester.tap(find.text('Es 3 veces por semana'));
      await tester.pump();
      expect(elegido, 3);
    });
  });
}
