import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/model/findings.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/notice.dart';
import 'package:la_muralla/model/piece.dart';
import 'package:la_muralla/model/pledge.dart';

/// **Las tres cosas que no se deducen.**
///
/// El plan («voy a leer a las 22, en la cama»), la identidad («este pueblo es
/// de alguien que lee todos los días») y la regla («después de correr,
/// estirar»). Todo lo demás que el tablón dice sale de las piezas; estas tres
/// las escribe quien usa la app, y lo único que el pueblo puede hacer con ellas
/// es enseñarlas y decir si se están cumpliendo.
///
/// Lo que se prueba acá es eso último, que es lo que las hace valer algo: que
/// la frase se arma como se habla, que la cuenta de cuánto se cumple sale de
/// las piezas de verdad, y que cuando una nota nueva dice lo mismo que una
/// vieja, la vieja se calla.
Habit _habit({
  String id = 'h1758000000000001',
  String name = 'Leer',
  DateTime? from,
  int hour = 22,
  int days = 40,
  int? every,
  int? vowHour,
  String? place,
  String? identity,
  String? after,
}) {
  final start = from ?? DateTime(2026, 3, 1);
  final h = Habit(
    id: id,
    name: name,
    symbol: 'rueda',
    slot: 0,
    createdAt: start,
    character: TownCharacter.all.first.order,
    vowHour: vowHour,
    vowPlace: place,
    identity: identity,
    afterId: after,
  );
  var n = 0;
  for (var d = 0; n < days; d++) {
    if (every != null && d % every != 0) continue;
    h.pieces.add(
      Piece(
        index: n,
        placedAt: start.add(Duration(days: d, hours: hour)),
      ),
    );
    n++;
  }
  return h;
}

void main() {
  group('el plan, dicho como se habla', () {
    test('la hora y el sitio, en una frase', () {
      expect(
        vowLine('Leer', 22, 'la cama'),
        'Voy a leer a las 22 de la noche, en la cama.',
      );
      expect(vowLine('Leer', 7, null), 'Voy a leer a las 7 de la mañana.');
      expect(
        vowLine('Leer', 12, 'la cocina'),
        'Voy a leer al mediodía, en la cocina.',
      );
      expect(vowLine('Leer', 0, null), 'Voy a leer a medianoche.');
    });

    test('media promesa sigue siendo una promesa', () {
      expect(
        vowLine('Correr', null, 'el parque'),
        'Voy a correr, en el parque.',
      );
      expect(vowLine('Correr', null, null), isNull);
    });

    test('la preposición no se repite si ya la trae', () {
      expect(
        vowLine('Leer', null, 'de camino al trabajo'),
        'Voy a leer, de camino al trabajo.',
      );
      expect(vowLine('Leer', null, 'en la cama'), 'Voy a leer, en la cama.');
    });

    test('un hábito que se llama en mayúsculas no se estropea', () {
      // «gYM» fue un fallo de verdad de bajar sólo la primera letra.
      expect(vowLine('GYM', 7, null), 'Voy a GYM a las 7 de la mañana.');
      expect(lowerName('No fumar'), 'no fumar');
    });

    test('el reloj da la vuelta', () {
      expect(hoursApart(23, 1), 2);
      expect(hoursApart(1, 23), 2);
      expect(hoursApart(22, 22), 0);
      expect(hoursApart(0, 12), 12);
    });
  });

  group('la costumbre, medida', () {
    test('la hora que se propone es la hora a la que aparecés', () {
      // El fallo que esto cierra: la ventana de tres horas que primero llega al
      // máximo es la que *empieza* dos horas antes del pico, así que un hábito
      // clavado a las 22 se anunciaba a las 21 y el plan propuesto salía una
      // hora antes que el hábito.
      for (final hora in [0, 7, 13, 22, 23]) {
        final uso = habitualHour(_habit(hour: hora));
        expect(uso, isNotNull, reason: 'a las $hora');
        expect(uso!.$1, hora, reason: 'a las $hora');
        expect(uso.$2, 1.0, reason: 'a las $hora');
      }
    });

    test('con poco puesto no se propone nada', () {
      expect(habitualHour(_habit(days: 6)), isNull);
    });

    test('un hábito que cae donde puede no tiene hora', () {
      final h = _habit(days: 0);
      final start = DateTime(2026, 3, 1);
      // Doce piezas repartidas por todo el día: ninguna ventana de tres horas
      // se lleva la mitad, así que no hay costumbre de la que hablar.
      for (var i = 0; i < 24; i++) {
        h.pieces.add(
          Piece(
            index: i,
            placedAt: start.add(Duration(days: i, hours: i)),
          ),
        );
      }
      expect(habitualHour(h), isNull);
    });

    test('cuánto se cumple el plan sale de las piezas', () {
      expect(planKept(_habit(hour: 22, vowHour: 22)), 1.0);
      // Una hora de margen para cada lado: nadie hace nada a la hora clavada.
      expect(planKept(_habit(hour: 22, vowHour: 21)), 1.0);
      expect(planKept(_habit(hour: 22, vowHour: 19)), 0.0);
      expect(planKept(_habit(hour: 22)), isNull, reason: 'sin hora escrita');
    });

    test('el desvío es la distancia entre lo escrito y lo que pasa', () {
      expect(planDrift(_habit(hour: 22, vowHour: 22)), 0);
      expect(planDrift(_habit(hour: 22, vowHour: 7)), 9);
      expect(planDrift(_habit(hour: 1, vowHour: 23)), 2);
    });
  });

  group('la identidad', () {
    test('el sujeto lo pone el pueblo', () {
      expect(
        identitySaid(_habit(identity: 'alguien que lee todos los días')),
        'Este pueblo es de alguien que lee todos los días.',
      );
    });

    test('y no acaba con dos puntos', () {
      expect(
        identitySaid(_habit(identity: 'Alguien que lee todos los días.')),
        'Este pueblo es de alguien que lee todos los días.',
      );
    });

    test('sin frase escrita no dice nada', () {
      expect(identitySaid(_habit()), isNull);
      expect(identitySaid(_habit(identity: '   ')), isNull);
    });

    test('los votos son los días con pieza', () {
      expect(identityVotes(_habit(days: 40)), 40);
      expect(identityVotes(_habit(days: 40, every: 2)), 40);
      expect(identityVotes(_habit(days: 0)), 0);
    });
  });

  group('lo que el tablón clava con lo que dijiste', () {
    List<NoticeKind> kinds(Habit h, {List<Habit> valley = const []}) => [
      for (final n in noticesFor(h, others: valley, at: DateTime(2026, 4, 10)))
        n.kind,
    ];

    test('el plan escrito sale, y el horario se calla', () {
      // Las dos notas dirían lo mismo, y la del horario sin la mitad que
      // importa: que lo decidiste vos.
      final h = _habit(hour: 22, vowHour: 22, place: 'la cama');
      final clavado = kinds(h);
      expect(clavado, contains(NoticeKind.plan));
      expect(clavado, isNot(contains(NoticeKind.hour)));
    });

    test('sin plan escrito, el papel cuenta la hora que ya es la tuya', () {
      final h = _habit(hour: 22);
      final nota = noticesFor(
        h,
        at: DateTime(2026, 4, 10),
      ).firstWhere((n) => n.kind == NoticeKind.plan);
      expect(nota.said, contains('22'));
      // Sin tono de tarea pendiente: lo que dice es lo que ya hacés.
      expect(nota.said, isNot(contains('sin plan')));
      expect(nota.because, contains('Si querés'));
      // Y lleva el reloj entero detrás, que es de donde salió.
      expect(nota.bars.length, 24);
      expect(nota.mark, 22);
    });

    test('un plan que ya no es el tuyo se dice, sin regañar', () {
      final h = _habit(hour: 22, vowHour: 7, place: 'la cama');
      final nota = noticesFor(
        h,
        at: DateTime(2026, 4, 10),
      ).firstWhere((n) => n.kind == NoticeKind.plan);
      expect(nota.said, contains('7'));
      expect(nota.said, contains('22'));
      expect(nota.more, contains('no es rendirse'));
    });

    test('la identidad se devuelve con los días detrás', () {
      final h = _habit(identity: 'alguien que lee todos los días');
      final nota = noticesFor(
        h,
        at: DateTime(2026, 4, 10),
      ).firstWhere((n) => n.kind == NoticeKind.who);
      expect(nota.said, 'Este pueblo es de alguien que lee todos los días.');
      expect(nota.because, contains('40 días'));
    });

    test('dos hábitos que van juntos son una observación y nada más', () {
      // Aunque una copia vieja traiga la regla firmada: ya no se enseña ni
      // tapa nada, así que lo que queda es lo que el pueblo ve.
      final correr = _habit(id: 'hA', name: 'Correr', days: 30, every: 2);
      final estirar = _habit(
        id: 'hB',
        name: 'Estirar',
        days: 30,
        every: 2,
        after: 'hA',
      );
      final valle = [correr, estirar];
      final clavado = kinds(estirar, valley: valle);
      expect(clavado, contains(NoticeKind.pair));
    });
  });

  group('lo que se guarda', () {
    test('las cuatro líneas van y vuelven del disco', () {
      final h = _habit(
        vowHour: 22,
        place: 'la cama',
        identity: 'alguien que lee todos los días',
        after: 'hA',
      );
      final otra = Habit.fromJson(h.toJson());
      expect(otra.vowHour, 22);
      expect(otra.vowPlace, 'la cama');
      expect(otra.identity, 'alguien que lee todos los días');
      expect(otra.afterId, 'hA');
    });

    test('una copia vieja no las trae y sigue siendo el mismo pueblo', () {
      final viejo = Habit.fromJson({'id': 'h1', 'n': 'Leer'});
      expect(viejo.vowHour, isNull);
      expect(viejo.vowPlace, isNull);
      expect(viejo.identity, isNull);
      expect(viejo.afterId, isNull);
      expect(vowOf(viejo), isNull);
    });

    test('una hora que no es del reloj se lee como que no hay plan', () {
      final raro = Habit.fromJson({'id': 'h1', 'n': 'Leer', 'vh': 99});
      expect(raro.vowHour, isNull);
    });
  });
}
