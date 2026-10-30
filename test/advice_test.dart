import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/advice.dart';
import 'package:towny/model/advice_book.dart';
import 'package:towny/model/habit.dart';
import 'package:towny/model/piece.dart';
import 'package:towny/model/stumble.dart';

Habit _pueblo(String id, DateTime fundado, {List<DateTime> dias = const []}) =>
    Habit(
      id: id,
      name: id,
      symbol: 'book',
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
      // Todo lo que pasa tiene el suyo, menos el día sin pieza: ése no tiene
      // uno propio, lo dicen el del charco o el de la mancha, que se
      // adelantan en el camino al día siguiente.
      expect({
        for (final a in eventAdvice) a.event,
      }, AdviceEvent.values.toSet()..remove(AdviceEvent.missedDay));
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

    test('los de la presentación quedan dados, y no son el del día', () {
      // Antes de fundar nada, el viejo da sus dos consejos.
      final dia = DateTime(2026, 3, 1, 9);
      for (final id in prologueAdvice) {
        libro.give(adviceById[id]!, now: dia);
        libro.markRead(adviceById[id]!);
      }
      expect(
        libro.read(approved: todos).map((g) => g.$1.id),
        containsAll(prologueAdvice),
      );
      // Fundado el primer pueblo ese mismo día, tiene uno nuevo, y no
      // repite ninguno de los de la presentación.
      final h = _pueblo('Leer', DateTime(2026, 3, 1));
      libro.setGoal(h.id, AdviceGoal.start);
      final hoy = libro.visit(
        [h],
        now: DateTime(2026, 3, 1, 10),
        approved: todos,
      );
      expect(hoy, hasLength(1));
      expect(prologueAdvice, isNot(contains(hoy.single.id)));
      // Y ninguno de los días siguientes los vuelve a dar.
      for (var d = 2; d < 40; d++) {
        for (final a in libro.visit(
          [h],
          now: DateTime(2026, 3, d),
          approved: todos,
        )) {
          expect(prologueAdvice, isNot(contains(a.id)), reason: 'día $d');
        }
      }
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
      // Hasta que no se confirma, el viejo no da por hecho que faltaste.
      expect(momentOf(h, hoy), AdviceMoment.steady);
      h.stumbles.add(
        StumbleEntry(DateTime(2026, 3, 9), Stumble.tired).encode(),
      );
      expect(momentOf(h, hoy), AdviceMoment.missedYesterday);
      expect(libro.pathOf([h], now: hoy).first, 'nodosveces');
    });

    test('«ese día no tocaba» no es faltar', () {
      final hoy = DateTime(2026, 3, 10, 21);
      final h = _pueblo(
        'Leer',
        DateTime(2026, 3, 1),
        dias: [for (var d = 0; d < 8; d++) DateTime(2026, 3, 1 + d, 20)],
      );
      h.stumbles.add(
        StumbleEntry(DateTime(2026, 3, 9), Stumble.notDue).encode(),
      );
      expect(momentOf(h, hoy), AdviceMoment.steady);
      expect({
        for (final (e, _) in eventsOf([h])) e,
      }, isNot(contains(AdviceEvent.missedDay)));
    });

    test('dormido no le pasa nada, y no manda', () {
      final hoy = DateTime(2026, 3, 20, 21);
      final h = _pueblo(
        'Saltar',
        DateTime(2026, 3, 1),
        dias: [DateTime(2026, 3, 2)],
      )..rests.add(Rest(DateTime(2026, 3, 5), DateTime(2026, 3, 30)).encode());
      final b = _pueblo(
        'Leer',
        DateTime(2026, 3, 1),
        dias: [for (var d = 0; d < 19; d++) DateTime(2026, 3, 1 + d, 20)],
      );
      libro
        ..setGoal(h.id, AdviceGoal.start)
        ..setGoal(b.id, AdviceGoal.start);
      expect(momentOf(h, hoy), AdviceMoment.steady);
      expect(libro.focusOf([h, b], now: hoy)?.id, 'Leer');
    });

    test('cinco por semana: los días libres no son tropiezos', () {
      // Lunes a viernes, dos semanas, y hoy es el lunes siguiente.
      final dias = [
        for (final d in [2, 3, 4, 5, 6, 9, 10, 11, 12, 13])
          DateTime(2026, 3, d, 20),
      ];
      final h = _pueblo('Ordenar', DateTime(2026, 3, 1), dias: dias)
        ..perWeek = 5;
      final lunes = DateTime(2026, 3, 16, 9);
      expect(stumbleDue(h, at: lunes), isNull);
      expect(momentOf(h, lunes), AdviceMoment.steady);
      expect(struggleOf(h, lunes), lessThan(0.3));
      // Una semana de cuatro tampoco.
      final cuatro = _pueblo(
        'Ordenar',
        DateTime(2026, 3, 1),
        dias: [
          for (final d in [2, 3, 4, 5, 9, 10, 11, 12]) DateTime(2026, 3, d, 20),
        ],
      )..perWeek = 5;
      expect(stumbleDue(cuatro, at: DateTime(2026, 3, 16, 9)), isNull);
      // Pero tres días seguidos sin nada en una semana de dos, sí.
      final flojo = _pueblo(
        'Ordenar',
        DateTime(2026, 3, 1),
        dias: [
          for (final d in [2, 3, 4, 5, 6, 9, 10]) DateTime(2026, 3, d, 20),
        ],
      )..perWeek = 5;
      expect(stumbleDue(flojo, at: DateTime(2026, 3, 16, 9)), isNotNull);
    });

    test('y lo ganado antes por faltas sin confirmar, también', () async {
      // Lo que quedó guardado de antes: un «que no sean dos» por un día que
      // nadie confirmó.
      final h = _pueblo(
        'Ordenar',
        DateTime(2026, 3, 1),
        dias: [for (var d = 0; d < 8; d++) DateTime(2026, 3, 1 + d, 20)],
      );
      SharedPreferences.setMockInitialValues({
        'consejero_v3': [
          'nodosveces|${DateTime(2026, 3, 10).millisecondsSinceEpoch}|'
              '${AdviceReason(moment: AdviceMoment.missedYesterday, town: 'Ordenar', when: DateTime(2026, 3, 9)).encode()}',
        ],
      });
      await libro.load();
      libro.setGoal(h.id, AdviceGoal.start);
      bool hay(String id) =>
          libro.unlocked(approved: todos).any((g) => g.$1.id == id);
      expect(hay('nodosveces'), isTrue);
      libro.visit([h], now: DateTime(2026, 3, 11, 21), approved: todos);
      expect(hay('nodosveces'), isFalse);
    });

    test('lo que se dijo por una falta que no era, se borra', () {
      final h = _pueblo(
        'Leer',
        DateTime(2026, 3, 1),
        dias: [for (var d = 0; d < 8; d++) DateTime(2026, 3, 1 + d, 20)],
      );
      libro.setGoal(h.id, AdviceGoal.start);
      h.stumbles.add(
        StumbleEntry(DateTime(2026, 3, 9), Stumble.tired).encode(),
      );
      libro.visit([h], now: DateTime(2026, 3, 10, 21), approved: todos);
      bool hay(String id) =>
          libro.unlocked(approved: todos).any((g) => g.$1.id == id);
      expect(hay('nodosveces'), isTrue);
      libro.retractMisses('Leer', DateTime(2026, 3, 9));
      expect(hay('nodosveces'), isFalse);
      // Lo que no era por la falta se queda.
      expect(hay('ev_primera'), isTrue);
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
      // A quien deja algo, lo de atar lo nuevo a lo de siempre no le toca.
      expect(nuevos, isNot(contains('despues')));
    });

    test('lo que pasó se lee de lo guardado', () {
      final dias = [
        for (var d = 0; d < 7; d++) DateTime(2026, 3, 1 + d, 20),
        DateTime(2026, 3, 9, 20),
        DateTime(2026, 3, 20, 20),
      ];
      final h = _pueblo('Leer', DateTime(2026, 3, 1), dias: dias);
      // Faltar el 8, confirmado en la charla.
      h.stumbles.add(
        StumbleEntry(DateTime(2026, 3, 8), Stumble.forgot).encode(),
      );
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

    test('lo que se gana por algo dice por qué, con el día y el pueblo', () {
      final dias = [
        for (var d = 0; d < 7; d++) DateTime(2026, 3, 1 + d, 20),
        DateTime(2026, 3, 9, 20),
        DateTime(2026, 3, 20, 20),
      ];
      final h = _pueblo('Leer', DateTime(2026, 3, 1), dias: dias);
      h.stumbles.add(
        StumbleEntry(DateTime(2026, 3, 8), Stumble.forgot).encode(),
      );
      libro.setGoal(h.id, AdviceGoal.start);
      libro.visit([h], now: DateTime(2026, 3, 21), approved: todos);
      String? porque(String id) => libro.reasonOf(adviceById[id]!)?.text;
      expect(porque('ev_primera'), contains('1/3'));
      expect(porque('ev_primera'), contains('Leer'));
      // Volvió el 20, después de diez días sin nada.
      expect(porque('ev_vuelta'), contains('20/3'));
      expect(porque('ev_vuelta'), contains('10'));
      // El del camino de todos los días no es por algo que pasó: si dice por
      // qué, es por cómo viene el pueblo (acá, que le está costando).
      final delDia = libro
          .unlocked(approved: todos)
          .map((g) => g.$1)
          .firstWhere((a) => a.event == null);
      expect(libro.reasonOf(delDia)?.event, isNull);
      expect(libro.reasonOf(delDia)?.text ?? '', isNot(contains('null')));
    });

    test('lo ganado no está en la lista hasta que se lee', () async {
      final h = _pueblo('Leer', DateTime(2026, 3, 1));
      libro.setGoal(h.id, AdviceGoal.start);
      libro.visit([h], now: DateTime(2026, 3, 1), approved: todos);
      expect(libro.pending(approved: todos), hasLength(1));
      expect(libro.read(approved: todos), isEmpty);
      expect(libro.unseen(approved: todos), 1);
      libro.markRead(libro.pending(approved: todos).first);
      expect(libro.pending(approved: todos), isEmpty);
      expect(libro.read(approved: todos), hasLength(1));
      // Y el motivo y lo leído sobreviven a cerrar la app.
      await libro.flush();
      libro.forget();
      await libro.load();
      expect(libro.read(approved: todos), hasLength(1));
    });

    test('el motivo se guarda y se lee igual', () {
      final r = AdviceReason(
        event: AdviceEvent.comeback,
        town: 'Correr | a la mañana',
        when: DateTime(2026, 5, 4),
        n: 6,
      );
      final otra = AdviceReason.decode(r.encode())!;
      expect(otra.text, r.text);
      expect(otra.town, 'Correr | a la mañana');
    });

    test('se presenta una sola vez', () async {
      expect(libro.met, isFalse);
      libro.meet();
      await libro.flush();
      libro.forget();
      expect(libro.met, isFalse);
      await libro.load();
      expect(libro.met, isTrue);
      // Y quien ya le había contestado algo lo conoce de antes.
      libro.forget();
      libro.setGoal('Leer', AdviceGoal.start);
      expect(libro.met, isTrue);
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
