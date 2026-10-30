import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/model/cadence.dart';
import 'package:towny/model/habit.dart';
import 'package:towny/model/piece.dart';
import 'package:towny/model/rhythm.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/cadence_sheet.dart';
import 'package:towny/ui/style.dart';

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
    symbol: 'run',
    slot: 0,
    createdAt: DateTime(today.year, today.month, today.day - age),
    perWeek: perWeek?.toDouble(),
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

    test('contestada, no se vuelve a preguntar', () {
      final h = _habit(now: now, age: 9, on: [0, 2, 4]);
      h.cadenceAskedAt = now;
      expect(cadenceDue(h, at: now), isFalse);
      final dicho = _habit(now: now, age: 9, on: [0, 2, 4], perWeek: 3);
      expect(cadenceDue(dicho, at: now), isFalse);
    });

    test('«ahora no» la deja para el día siguiente', () {
      final h = _habit(now: now, age: 9, on: [0, 2, 4]);
      h.cadenceLaterAt = now;
      expect(cadenceDue(h, at: now), isFalse);
      expect(cadenceDue(h, at: now.add(const Duration(hours: 1))), isFalse);
      final manana = DateTime(now.year, now.month, now.day + 1, 9);
      expect(cadenceDue(h, at: manana), isTrue);
    });

    test('lo que se cuenta son los días desde que empezó, no los de pieza', () {
      // Cuatro piezas en una semana no son «cuatro piezas en cuatro días»:
      // eso parece ir a diario. Son cuatro en siete.
      final h = _habit(now: now, age: 7, on: [0, 1, 3, 5]);
      expect(sinceStartOf(h, at: now), (4, 7));
    });

    test('cada dos días y cada dos semanas se distinguen de lo demás', () {
      expect(nearestCadence(3.5), everyOtherDay);
      expect(nearestCadence(3.1), 3);
      expect(nearestCadence(0.4), everyOtherWeek);
      expect(nearestCadence(6.8), 7);
      expect(cadenceSaid(everyOtherDay), 'cada dos días');
      expect(cadenceSaid(everyOtherWeek), 'cada dos semanas');
      expect(cadenceSaid(5), '5 veces por semana');
    });
  });

  group('el candado, contra tu ritmo', () {
    test('desde el cuarto pueblo, la puerta pide cada vez más', () {
      expect(
        [for (var n = 2; n <= 9; n++) UnlockGoal.shareFor(n)],
        [0.70, 0.70, 0.75, 0.80, 0.85, 0.90, 0.90, 0.90],
      );
      // A diario y catorce días: diez para el segundo, once para el cuarto,
      // trece para el séptimo.
      final hoy = DateTime(2026, 5, 20, 12);
      final h = _habit(now: hoy, on: [for (var d = 0; d < 11; d++) d]);
      int pide(int pueblo) =>
          UnlockGoal.of(h, at: hoy, meta: UnlockGoal.shareFor(pueblo)).need;
      expect(pide(2), 10);
      expect(pide(4), 11);
      expect(pide(7), 13);
      // Once días alcanzan para el cuarto y no para el quinto.
      expect(UnlockGoal.of(h, at: hoy, meta: UnlockGoal.shareFor(4)).met, true);
      expect(
        UnlockGoal.of(h, at: hoy, meta: UnlockGoal.shareFor(5)).met,
        false,
      );
      expect(
        UnlockGoal.of(h, at: hoy, meta: UnlockGoal.shareFor(5)).metaPercent,
        80,
      );
    });

    test('sin poner piezas, pasar el día no abre la puerta', () {
      // Lo que se vio en el teléfono: un día no abría, y al siguiente sí, con
      // las mismas piezas. Se contaba por semanas desde hoy, y al correrse el
      // corte las mismas piezas quedaban mejor repartidas. Ahora, con los días
      // que pasan, lo que se lleva sólo puede bajar.
      final hoy = DateTime(2026, 5, 20, 12);
      var semilla = 7;
      int azar(int n) {
        semilla = (semilla * 1103515245 + 12345) & 0x7fffffff;
        return semilla % n;
      }

      for (var caso = 0; caso < 400; caso++) {
        final ritmo = [2, 3, 4, 5, 6, 7][azar(6)];
        final dias = <int>{for (var k = 0; k < 4 + azar(14); k++) 1 + azar(27)};
        final h = _habit(now: hoy, age: 40, on: dias, perWeek: ritmo);
        var antes = UnlockGoal.of(h, at: hoy).have;
        for (var d = 1; d <= 10; d++) {
          final luego = DateTime(hoy.year, hoy.month, hoy.day + d, 12);
          final ahora = UnlockGoal.of(h, at: luego).have;
          expect(
            ahora,
            lessThanOrEqualTo(antes),
            reason: 'ritmo $ritmo, días $dias: subió solo al pasar $d días',
          );
          antes = ahora;
        }
      }
    });

    test('cinco por semana: una semana de seis cuenta entera', () {
      // Seis días seguidos —uno más que tu ritmo— y uno antes. Una semana
      // cargada se compensa con otra más floja: son siete días de trabajo
      // en la ventana, y alcanzan.
      final hoy = DateTime(2026, 5, 20, 12);
      final h = _habit(now: hoy, on: [0, 1, 2, 3, 4, 5, 8], perWeek: 5);
      final g = UnlockGoal.of(h, at: hoy);
      expect(g.need, 7);
      expect(g.have, 7);
      // Y al día siguiente, sin poner nada, no sube.
      final manana = DateTime(2026, 5, 21, 12);
      expect(UnlockGoal.of(h, at: manana).have, lessThanOrEqualTo(7));
    });

    test('horarios rotativos: seis una semana y cuatro la otra', () {
      // El caso de quien trabaja por turnos: del sábado 17 al domingo 25,
      // sin pieza el martes 20, ni el lunes 26 ni hoy. Del sábado al viernes
      // son seis, y contado clavado de siete en siete sobraba una.
      final hoy = DateTime(2026, 10, 27, 17);
      final h = _habit(now: hoy, on: [2, 3, 4, 5, 6, 8, 9, 10], perWeek: 5);
      final g = UnlockGoal.of(h, at: hoy);
      expect(g.calendar.where((c) => c.$2 == DayMark.extra), isEmpty);
      expect(g.have, 8);
    });

    test('cinco por semana: siete seguidos siguen siendo seis', () {
      final hoy = DateTime(2026, 5, 20, 12);
      final g = UnlockGoal.of(
        _habit(now: hoy, on: [0, 1, 2, 3, 4, 5, 6], perWeek: 5),
        at: hoy,
      );
      expect(g.have, 6);
    });

    test('los días en pausa no cuentan: lo de antes de pausar se guarda', () {
      // Nueve días con pieza en la ventana de siempre y dos más justo antes,
      // y los últimos cuatro en pausa. Sin saltarlos, esos cuatro eran días
      // fallados y no llegaba; saltándolos, la ventana se corre y llega.
      final hoy = DateTime(2026, 5, 20, 18);
      final h = _habit(
        now: hoy,
        on: [4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15],
        perWeek: 7,
      );
      h.rests.add(
        Rest(DateTime(2026, 5, 16, 8), DateTime(2026, 5, 20, 13)).encode(),
      );
      final g = UnlockGoal.of(h, at: hoy);
      expect(g.restDays, 4);
      expect(g.resting, isFalse);
      expect(g.have, greaterThanOrEqualTo(g.need));
      expect(g.met, isTrue);
    });

    test('dormido ahora no abre la puerta, aunque haya llegado', () {
      final hoy = DateTime(2026, 5, 20, 18);
      final h = _habit(
        now: hoy,
        on: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        perWeek: 7,
      );
      h.rests.add(
        Rest(DateTime(2026, 5, 19, 8), DateTime(2026, 5, 25, 8)).encode(),
      );
      final g = UnlockGoal.of(h, at: hoy);
      expect(g.resting, isTrue);
      expect(g.have, greaterThanOrEqualTo(g.need), reason: 'lo suyo se guarda');
      expect(g.met, isFalse);
    });

    test('el porcentaje nunca contradice a la puerta', () {
      // Llegado, nunca menos que la meta; sin llegar, nunca la meta.
      final hoy = DateTime(2026, 5, 20, 12);
      for (final ritmo in [1, 2, 3, 4, 5, 6, 7]) {
        for (var n = 0; n <= 28; n++) {
          final h = _habit(
            now: hoy,
            age: 60,
            on: [for (var d = 0; d < n; d++) d],
            perWeek: ritmo,
          );
          final g = UnlockGoal.of(h, at: hoy);
          if (g.met) {
            expect(g.percent, greaterThanOrEqualTo(UnlockGoal.goalPercent));
          } else if (!g.young) {
            expect(g.percent, lessThan(UnlockGoal.goalPercent));
          }
          expect(g.percent, inInclusiveRange(0, 100));
        }
      }
    });

    test('decir el ritmo la primera semana vale para todo el pueblo', () {
      // Cinco seguidos, falla el sexto, y en la charla dice «cinco por
      // semana»: lo hecho cuenta entero contra el ritmo que dijo.
      final s = Store();
      final hoy = DateTime.now();
      final h = _habit(now: hoy, age: 6, on: [1, 2, 3, 4, 5]);
      s.setCadence(h, 5);
      expect(h.paces, isEmpty, reason: 'decirlo no es cambiarlo');
      expect(h.paceOn(DateTime(hoy.year, hoy.month, hoy.day - 5)), 5);
      final g = UnlockGoal.of(h, at: hoy);
      expect(g.young, isTrue);
      expect(g.onTrack, isTrue, reason: 'va bien aunque le falten días');
      expect(g.met, isFalse, reason: 'la ventana entera todavía no está');
    });

    test('bajar el ritmo después no abre la puerta con los días de antes', () {
      // Un pueblo de dos meses, todos los días, que viene flojo: seis de
      // catorce. Bajarlo a una por semana hoy no lo hace llegar.
      final s = Store();
      final hoy = DateTime.now();
      final h = _habit(now: hoy, age: 60, on: [1, 3, 5, 8, 10, 12], perWeek: 7);
      expect(UnlockGoal.of(h, at: hoy).met, isFalse);
      s.setCadence(h, 1);
      expect(h.paces.length, 2, reason: 'el de antes y el de ahora');
      final g = UnlockGoal.of(h, at: hoy);
      expect(g.met, isFalse);
      // Y de hoy en adelante, sí vale el nuevo.
      expect(h.paceOn(dayStart(hoy)), 1);
      expect(h.paceOn(DateTime(hoy.year, hoy.month, hoy.day - 3)), 7);
    });

    test(
      'un pueblo nuevo no arranca castigado por los días que no existía',
      () {
        final hoy = DateTime(2026, 5, 20, 12);
        final g = UnlockGoal.of(
          _habit(now: hoy, age: 4, on: [0, 1, 2, 3, 4], perWeek: 7),
          at: hoy,
        );
        expect(g.percent, 100);
        expect(g.met, isFalse);
        expect(
          g.calendar.where((c) => c.$2 == DayMark.unborn).length,
          14 - 5,
          reason: 'los días de antes de fundarlo, en blanco',
        );
      },
    );

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
      final h = _habit(now: now, on: [0], perWeek: 3)
        ..cadenceAskedAt = now
        ..cadenceLaterAt = now;
      final back = Habit.fromJson(h.toJson());
      expect(back.perWeek, 3);
      expect(back.cadenceAskedAt, now);
      expect(back.cadenceLaterAt, now);
      final alterno = Habit.fromJson((h..perWeek = everyOtherDay).toJson());
      expect(alterno.perWeek, everyOtherDay);
    });

    test('un número fuera de la semana se lee como que no se dijo', () {
      final j = _habit(now: now, on: [0]).toJson()..['pw'] = 9;
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
      double? elegido;
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
        // Los días desde que empezó, no los días con pieza.
        expect(find.text('En 8 días pusiste 5 piezas.'), findsOneWidget);
      }
      // Viene marcado lo que se ve, y un toque lo confirma.
      expect(
        find.text('Es ${cadenceSaid(nearestCadence(observedRate(h)!))}'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cada dos días'));
      await tester.pump();
      expect(find.text('Es cada dos días'), findsOneWidget);
      // Los días sueltos se eligen dentro de su renglón, desplegando.
      await tester.tap(find.byIcon(Icons.expand_more_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 por semana').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Es 5 veces por semana'));
      await tester.pump();
      await tester.tap(find.text('Es 5 veces por semana'));
      await tester.pump();
      expect(elegido, 5);
    });

    testWidgets('antes, un aviso que se puede dejar para mañana', (
      tester,
    ) async {
      final h = _habit(now: DateTime.now(), age: 8, on: [0, 1, 3]);
      bool? dijo;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    dijo = await showDialog<bool>(
                      context: context,
                      builder: (_) => CadenceIntro(
                        habit: h,
                        theme: UiTheme(Palette.forMoment(13)),
                      ),
                    );
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Contanos más de tu hábito'), findsOneWidget);
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(dijo, isFalse);
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(dijo, isTrue);
    });
  });
}
