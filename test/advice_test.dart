import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/advice.dart';
import 'package:towny/model/advice_book.dart';
import 'package:towny/model/habit.dart';
import 'package:towny/model/piece.dart';

Habit _pueblo(String id, DateTime fundado, {List<DateTime> dias = const []}) =>
    Habit(
      id: id,
      name: id,
      symbol: 'libro',
      slot: 0,
      createdAt: fundado,
      pieces: [
        for (var i = 0; i < dias.length; i++)
          Piece(index: i, placedAt: dias[i]),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final todos = {
    for (final a in [...dailyAdvice, ...eventAdvice]) a.id,
  };
  final libro = AdviceBook.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    libro.forget();
  });

  group('lo que sabe el consejero', () {
    test('cada consejo tiene su nombre y lo dice en los dos idiomas', () {
      final ids = <String>{};
      for (final a in [...dailyAdvice, ...eventAdvice]) {
        expect(ids.add(a.id), isTrue, reason: '«${a.id}» está dos veces');
        for (final t in [a.sayEs, a.meanEs, a.sayEn, a.meanEn]) {
          expect(t.trim(), isNotEmpty, reason: a.id);
        }
      }
      expect({
        for (final a in eventAdvice) a.event,
      }, AdviceEvent.values.toSet());
      for (final id in approvedAdvice) {
        expect(adviceById, contains(id), reason: 'aprobado y no existe: $id');
      }
    });

    test('cada camino tiene lo suyo, sin repetir y sin lo del otro', () {
      for (final g in AdviceGoal.values) {
        final camino = pathFor(g);
        expect(camino.toSet().length, camino.length, reason: '$g repite');
        for (final id in camino) {
          final a = adviceById[id];
          expect(a, isNotNull, reason: '$g pide «$id», que no existe');
          expect(a!.event, isNull, reason: '«$id» es de los que llegan solos');
          expect(a.goal == null || a.goal == g, isTrue, reason: '$g: «$id»');
        }
      }
      // Ninguno de todos los días se queda sin camino.
      final usados = {
        ...pathFor(AdviceGoal.start),
        ...pathFor(AdviceGoal.quit),
      };
      for (final a in dailyAdvice) {
        expect(usados, contains(a.id), reason: '«${a.id}» no sale nunca');
      }
    });
  });

  group('la libreta', () {
    test('sin contestar la pregunta, no da nada', () {
      final h = _pueblo('Leer', DateTime(2026, 3, 1));
      expect(
        libro.visit([h], now: DateTime(2026, 3, 1), approved: todos),
        isEmpty,
      );
    });

    test('sin aprobar, tampoco', () {
      final h = _pueblo('Leer', DateTime(2026, 3, 1));
      libro.setGoal(h.id, AdviceGoal.start);
      expect(
        libro.visit([h], now: DateTime(2026, 3, 1), approved: {}),
        isEmpty,
      );
    });

    test('uno por día que entrás, sin acumular los que no', () {
      final h = _pueblo('Leer', DateTime(2026, 3, 1));
      libro.setGoal(h.id, AdviceGoal.start);
      final camino = pathFor(AdviceGoal.start);
      final d1 = libro.visit(
        [h],
        now: DateTime(2026, 3, 1, 9),
        approved: todos,
      );
      expect(d1.single.id, camino[0]);
      expect(
        libro.visit([h], now: DateTime(2026, 3, 1, 22), approved: todos),
        isEmpty,
      );
      final d2 = libro.visit([h], now: DateTime(2026, 3, 2), approved: todos);
      expect(d2.single.id, camino[1]);
      // Dos semanas sin entrar: uno, no catorce.
      final d3 = libro.visit([h], now: DateTime(2026, 3, 16), approved: todos);
      expect(d3.where((a) => a.event == null), hasLength(1));
      final hay = libro.unlocked(approved: todos);
      expect(hay, hasLength(3));
      expect(hay.last.$1.id, camino[0]);
    });

    test('una sola libreta para todos los pueblos', () {
      final a = _pueblo('Leer', DateTime(2026, 3, 1));
      final b = _pueblo('Correr', DateTime(2026, 3, 2));
      libro
        ..setGoal(a.id, AdviceGoal.start)
        ..setGoal(b.id, AdviceGoal.start);
      // Dos pueblos, un solo consejo del día.
      final d1 = libro.visit(
        [a, b],
        now: DateTime(2026, 3, 3),
        approved: todos,
      );
      expect(d1.where((x) => x.event == null), hasLength(1));
    });

    test('quien arranca algo empieza por otro lado', () {
      final h = _pueblo('Fumar', DateTime(2026, 3, 1));
      libro.setGoal(h.id, AdviceGoal.quit);
      final d1 = libro.visit([h], now: DateTime(2026, 3, 1), approved: todos);
      expect(d1.single.id, pathFor(AdviceGoal.quit).first);
    });

    test('manda el hábito que más cuesta: el nuevo, si el viejo anda', () {
      final hoy = DateTime(2026, 4, 1, 21);
      // Leer, desde hace un mes, casi todos los días.
      final a = _pueblo(
        'Leer',
        DateTime(2026, 3, 1),
        dias: [for (var d = 0; d < 31; d++) DateTime(2026, 3, 1 + d, 20)],
      );
      // Fumar, desde ayer.
      final b = _pueblo('Fumar', DateTime(2026, 3, 31));
      libro
        ..setGoal(a.id, AdviceGoal.start)
        ..setGoal(b.id, AdviceGoal.quit);
      expect(libro.focusOf([a, b], now: hoy)?.id, 'Fumar');
      expect(
        libro.pathOf([a, b], now: hoy).first,
        pathFor(AdviceGoal.quit).first,
      );
    });

    test('si ayer faltaste, primero que no sean dos', () {
      final hoy = DateTime(2026, 3, 10, 21);
      final h = _pueblo(
        'Leer',
        DateTime(2026, 3, 1),
        dias: [for (var d = 0; d < 8; d++) DateTime(2026, 3, 1 + d, 20)],
      );
      libro.setGoal(h.id, AdviceGoal.start);
      expect(momentOf(h, hoy), AdviceMoment.missedYesterday);
      expect(libro.pathOf([h], now: hoy).first, 'nodosveces');
    });

    test('si viene costando, más chico', () {
      final hoy = DateTime(2026, 3, 15, 21);
      final h = _pueblo(
        'Leer',
        DateTime(2026, 3, 1),
        dias: [
          DateTime(2026, 3, 2),
          DateTime(2026, 3, 9),
          DateTime(2026, 3, 15),
        ],
      );
      libro.setGoal(h.id, AdviceGoal.start);
      expect(momentOf(h, hoy), AdviceMoment.struggling);
      expect(libro.pathOf([h], now: hoy).first, 'chico');
    });

    test('el segundo pueblo oye lo que le toca según lo que busca', () {
      final a = _pueblo('Leer', DateTime(2026, 3, 1));
      final b = _pueblo('Fumar', DateTime(2026, 3, 9));
      libro
        ..setGoal(a.id, AdviceGoal.start)
        ..setGoal(b.id, AdviceGoal.quit);
      final nuevos = libro
          .visit([a, b], now: DateTime(2026, 3, 9), approved: todos)
          .map((x) => x.id);
      expect(nuevos, contains('ev_segundo_q'));
      expect(nuevos, isNot(contains('ev_segundo')));
    });

    test('lo que pasó se lee de lo guardado', () {
      final dias = [
        for (var d = 0; d < 7; d++) DateTime(2026, 3, 1 + d, 20),
        DateTime(2026, 3, 9, 20),
        DateTime(2026, 3, 20, 20),
      ];
      final h = _pueblo('Leer', DateTime(2026, 3, 1), dias: dias);
      final hay = {
        for (final (e, _) in eventsOf([h])) e,
      };
      expect(
        hay,
        containsAll([
          AdviceEvent.firstPiece,
          AdviceEvent.week,
          AdviceEvent.missedDay,
          AdviceEvent.comeback,
        ]),
      );
      expect(hay, isNot(contains(AdviceEvent.secondTown)));
      expect(hay, isNot(contains(AdviceEvent.month)));
    });

    test('lo que contestaste y lo ganado sobreviven a cerrar la app', () async {
      final h = _pueblo('Leer', DateTime(2026, 3, 1));
      libro.setGoal(h.id, AdviceGoal.quit);
      libro.visit([h], now: DateTime(2026, 3, 1), approved: todos);
      await libro.flush();
      libro.forget();
      await libro.load();
      expect(libro.goalOf(h.id), AdviceGoal.quit);
      expect(libro.unlocked(approved: todos), hasLength(1));
      expect(libro.unlocked(approved: {}), isEmpty);
    });
  });
}
