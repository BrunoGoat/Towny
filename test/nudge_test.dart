import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/nudge.dart';
import 'package:la_muralla/model/piece.dart';

final _inicio = DateTime(2026, 3, 1);

/// Un hábito que pone una pieza [cada] días durante [dias], a las siete y
/// media de la tarde, y la última hace [hueco] días.
Habit _habit({
  double cada = 1,
  int dias = 60,
  String id = 'h',
  int slot = 0,
  String? why,
  String? floor,
  int hora = 19,
}) {
  final pieces = <Piece>[];
  var i = 0;
  for (var d = 0.0; d < dias; d += cada) {
    pieces.add(
      Piece(
        index: i++,
        placedAt: _inicio.add(
          Duration(minutes: (d * 1440).round() + hora * 60),
        ),
      ),
    );
  }
  // Correr todo para que la última caiga hace [hueco] días de hoy.
  return Habit(
    id: id,
    name: 'Leer',
    symbol: 'libro',
    slot: slot,
    createdAt: _inicio,
    character: TownCharacter.all.first.order,
    why: why,
    floor: floor,
    pieces: pieces,
  );
}

/// El «hoy» que deja la última pieza a [hueco] días.
DateTime _hoy(Habit h, int hueco) => DateTime(
  h.lastPlacedAt!.year,
  h.lastPlacedAt!.month,
  h.lastPlacedAt!.day,
).add(Duration(days: hueco, hours: 23));

void main() {
  group('cuándo habla', () {
    test('nunca el primer día sin pieza', () {
      final h = _habit();
      expect(planNudge([h], _hoy(h, 1)), isNull);
    });

    test('a quien aparece a diario, al segundo', () {
      final h = _habit();
      expect(lateAfter(h, at: _hoy(h, 2)), 2);
      expect(planNudge([h], _hoy(h, 2)), isNotNull);
    });

    test('ni a quien usó la app cinco días y desapareció un mes', () {
      // Cinco días dan una ventana de un mes y una cadencia inventada. No es
      // historia: es una corazonada con aspecto de número.
      final h = _habit(dias: 5);
      expect(planNudge([h], _hoy(h, 30)), isNull);
    });

    test('a quien aparece tres veces por semana, no el jueves', () {
      // Es el error que comete cualquier app que trate todos los días en
      // blanco como incumplimientos.
      final h = _habit(cada: 2.33, dias: 70);
      expect(lateAfter(h, at: _hoy(h, 3)), greaterThanOrEqualTo(4));
      expect(planNudge([h], _hoy(h, 2)), isNull);
      expect(planNudge([h], _hoy(h, 3)), isNull);
      expect(planNudge([h], _hoy(h, 5)), isNotNull);
    });

    test('nunca sin historia de la que sacar un ritmo', () {
      // Los primeros días, cualquier número que saliera de acá sería inventado.
      for (final d in [3, 7, 12, 13]) {
        final h = _habit(dias: d);
        expect(
          planNudge([h], _hoy(h, 6)),
          isNull,
          reason: 'avisó con sólo $d días de hábito',
        );
      }
    });

    test('nunca a un pueblo dormido', () {
      final h = _habit();
      final hoy = _hoy(h, 9);
      expect(planNudge([h], hoy), isNotNull);
      final desde = hoy.subtract(const Duration(days: 5));
      final hasta = hoy.add(const Duration(days: 5));
      h.rests.add(
        '${desde.millisecondsSinceEpoch}|${hasta.millisecondsSinceEpoch}',
      );
      expect(planNudge([h], hoy), isNull);
    });

    test('siempre dentro de una hora decente, y a la tuya', () {
      for (final hora in [6, 9, 14, 23]) {
        final h = _habit(hora: hora);
        final n = planNudge([h], _hoy(h, 4));
        expect(n, isNotNull, reason: 'a las $hora');
        expect(n!.at.hour, greaterThanOrEqualTo(NudgeRules.earliest));
        expect(n.at.hour, lessThanOrEqualTo(NudgeRules.latest));
      }
      // Y a la tuya cuando la tuya es decente.
      final h = _habit(hora: 9);
      expect(planNudge([h], _hoy(h, 4))!.at.hour, 9);
    });
  });

  group('cuánto habla', () {
    test('una sola vez por hueco, por largo que se haga', () {
      final h = _habit();
      var hoy = _hoy(h, 2);
      final primero = planNudge([h], hoy)!;
      nudgeSent(h, primero.at);
      // Los veinte días siguientes, nada.
      for (var d = 3; d < NudgeRules.backAt; d++) {
        expect(
          planNudge([h], _hoy(h, d)),
          isNull,
          reason: 'volvió a avisar al día $d del mismo hueco',
        );
      }
    });

    test('y una segunda, semanas después, que es la de volver', () {
      final h = _habit();
      final primero = planNudge([h], _hoy(h, 2))!;
      nudgeSent(h, primero.at);
      final segundo = planNudge([h], _hoy(h, NudgeRules.backAt + 1));
      expect(segundo, isNotNull);
      expect(segundo!.kind, NudgeKind.back);
      nudgeSent(h, segundo.at);
      // Y ya no hay tercero.
      for (final d in [30, 45, 90, 200]) {
        expect(planNudge([h], _hoy(h, d)), isNull, reason: 'tercero al día $d');
      }
    });

    test('nunca dos seguidos aunque haya seis pueblos', () {
      final habits = [for (var k = 0; k < 6; k++) _habit(id: 'h$k', slot: k)];
      final hoy = _hoy(habits.first, 4);
      DateTime? ultimo;
      final salidos = <DateTime>[];
      for (var vuelta = 0; vuelta < 6; vuelta++) {
        final n = planNudge(habits, hoy, lastAny: ultimo);
        if (n == null) break;
        salidos.add(n.at);
        nudgeSent(habits.firstWhere((h) => h.id == n.habitId), n.at);
        ultimo = n.at;
      }
      for (var i = 1; i < salidos.length; i++) {
        expect(
          salidos[i].difference(salidos[i - 1]).inDays,
          greaterThanOrEqualTo(NudgeRules.apart),
          reason: 'dos avisos a menos de ${NudgeRules.apart} días',
        );
      }
    });

    test('se calla sola cuando no sirve de nada', () {
      // Lo que ninguna app de hábitos hace y lo que más falta hace: si tres
      // avisos no trajeron ni una pieza, el cuarto tampoco va a traerla.
      final h = _habit();
      var enviados = 0;
      for (var d = 2; d < 400; d++) {
        final n = planNudge([h], _hoy(h, d));
        if (n == null) continue;
        nudgeSent(h, n.at);
        enviados++;
      }
      expect(
        enviados,
        lessThanOrEqualTo(NudgeRules.giveUpAfter + 1),
        reason: 'mandó $enviados avisos a alguien que no contestó ninguno',
      );
    });
  });

  group('qué dice', () {
    test('el día malo habla con tus palabras, no con las de la app', () {
      final h = _habit(why: 'para dormir mejor', floor: 'una página');
      final n = planNudge([h], _hoy(h, 5))!;
      expect(n.kind, NudgeKind.words);
      expect(n.body, contains('para dormir mejor'));
      expect(n.body, contains('una página'));
      expect(n.title, 'Leer');
    });

    test('y si no escribiste nada, habla el pueblo', () {
      final h = _habit();
      final n = planNudge([h], _hoy(h, 5))!;
      expect(n.kind, NudgeKind.late);
      expect(n.body, isNotEmpty);
    });

    test('la de volver no pide perdón ni cuenta días', () {
      final h = _habit(why: 'para dormir mejor');
      nudgeSent(h, planNudge([h], _hoy(h, 4))!.at);
      final n = planNudge([h], _hoy(h, 40))!;
      expect(n.kind, NudgeKind.back);
      expect(n.body, contains('entero'));
    });

    test('ningún aviso cuenta los días que faltaste ni dice «racha»', () {
      // Las dos cosas que esta app no hace en ninguna pantalla, y menos todavía
      // en un aviso que llega sin que nadie lo haya pedido.
      final casos = <Habit>[
        _habit(),
        _habit(why: 'para dormir mejor', floor: 'una página'),
        _habit(why: 'para dormir mejor'),
        _habit(floor: 'una página'),
        _habit(cada: 3, dias: 90),
      ];
      final dichos = <String>[];
      for (final h in casos) {
        for (final d in [2, 4, 6, 9, 14, 30, 60]) {
          final n = planNudge([h], _hoy(h, d));
          if (n != null) dichos.add('${n.title}\n${n.body}');
          if (n != null) nudgeSent(h, n.at);
        }
      }
      expect(dichos, isNotEmpty);
      for (final t in dichos) {
        final bajo = t.toLowerCase();
        expect(bajo, isNot(contains('racha')), reason: t);
        expect(bajo, isNot(contains('!')), reason: t);
        expect(
          RegExp(r'\d+\s*(días?|semanas?)').hasMatch(bajo),
          isFalse,
          reason: 'cuenta el tiempo que faltaste: $t',
        );
      }
    });
  });

  group('cuántas en un año', () {
    // Un año día a día, como funciona de verdad: la app programa el próximo
    // aviso cada vez que se abre o cae una pieza, y ese aviso suena cuando el
    // reloj lo alcanza. Contarlo mirando lo que `planNudge` devuelve hoy daría
    // cero siempre — lo que devuelve es siempre una hora que todavía no llegó.
    int simular(Habit h, bool Function(int dia) pone, {int dias = 365}) {
      var dia = _inicio;
      var avisos = 0;
      DateTime? ultimo;
      Nudge? programado;
      for (var k = 0; k < dias; k++) {
        final ahora = dia.add(const Duration(hours: 23));
        if (programado != null && !programado.at.isAfter(ahora)) {
          nudgeSent(h, programado.at);
          ultimo = programado.at;
          avisos++;
        }
        if (pone(k)) {
          final cuando = dia.add(const Duration(hours: 19));
          h.pieces.add(Piece(index: h.pieces.length, placedAt: cuando));
          nudgeAnswered(h, cuando);
        }
        programado = planNudge([h], ahora, lastAny: ultimo);
        dia = dia.add(const Duration(days: 1));
      }
      return avisos;
    }

    test('a quien nunca llega a estar tarde, ninguno', () {
      // Falla dos días de cada diez, pero nunca dos seguidos. No hay nada que
      // decirle, y no se le dice nada.
      final h = _habit(dias: 1)..pieces.clear();
      final avisos = simular(h, (k) => k % 10 != 3 && k % 10 != 7);
      // ignore: avoid_print
      print('  un año fallando dos de cada diez, nunca seguidos: $avisos');
      expect(avisos, 0);
    });

    test('a quien se cae de verdad cada tanto, un puñado', () {
      // Cuatro caídas largas en el año —una semana, diez días, tres días y dos
      // semanas— además de los fallos sueltos.
      final caidas = <int, int>{70: 7, 150: 10, 232: 3, 300: 14};
      var saltar = 0;
      final h = _habit(dias: 1)..pieces.clear();
      final avisos = simular(h, (k) {
        if (saltar > 0) {
          saltar--;
          return false;
        }
        if (caidas.containsKey(k)) {
          saltar = caidas[k]!;
          return false;
        }
        return k % 9 != 4;
      });
      // ignore: avoid_print
      print('  un año con cuatro caídas largas: $avisos avisos');
      expect(avisos, greaterThan(0), reason: 'no dijo nada en todo el año');
      expect(avisos, lessThanOrEqualTo(8), reason: 'mandó $avisos en un año');
    });
  });
}
