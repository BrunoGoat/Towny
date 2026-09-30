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
      Piece(index: n, placedAt: start.add(Duration(days: d, hours: hour))),
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
      expect(vowLine('Leer', 12, 'la cocina'), 'Voy a leer al mediodía, en la cocina.');
      expect(vowLine('Leer', 0, null), 'Voy a leer a medianoche.');
    });

    test('media promesa sigue siendo una promesa', () {
      expect(vowLine('Correr', null, 'el parque'), 'Voy a correr, en el parque.');
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
          Piece(index: i, placedAt: start.add(Duration(days: i, hours: i))),
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

  });

  /// **El título se gana.** Ésta es la parte que importa de la identidad: que
  /// escribir «alguien sabio» el día que se funda el pueblo no te convierte en
  /// nada, y que el pueblo no lo diga hasta que lo sea de verdad — cada cuánto
  /// lo hacés lo averigua él, y el listón es ese ritmo tuyo sostenido trece
  /// semanas.
  group('el título, que no se escribe sino que se gana', () {
    final hoy = DateTime(2026, 9, 28);

    /// Un pueblo con una semana por cada número de [semanas], de la más vieja a
    /// la más nueva, poniendo esas piezas en los primeros días de cada una. La
    /// última acaba hoy.
    Habit porSemanas(
      List<int> semanas, {
      String? identity = 'alguien sabio',
      List<String> rests = const [],
    }) {
      final desde = hoy.subtract(Duration(days: 7 * semanas.length - 1));
      final h = Habit(
        id: 'h1758000000000003',
        name: 'Leer',
        symbol: 'rueda',
        slot: 0,
        createdAt: desde,
        character: TownCharacter.all.first.order,
        identity: identity,
        rests: [...rests],
      );
      var i = 0;
      for (var w = 0; w < semanas.length; w++) {
        for (var d = 0; d < semanas[w]; d++) {
          h.pieces.add(
            Piece(
              index: i++,
              placedAt: desde.add(Duration(days: 7 * w + d, hours: 21)),
            ),
          );
        }
      }
      return h;
    }

    test('el día que se funda el pueblo no hay título', () {
      // El fallo que esto cierra: escribías «alguien sabio» al fundar y esa
      // misma tarde el tablón anunciaba que este pueblo era de alguien sabio.
      // Todavía no hiciste nada.
      final voy = identityStanding(porSemanas([1]), at: hoy)!;
      expect(voy.earned, isFalse);
      expect(voy.done, 1);
      expect(voy.missing, identityWeeks - 1);
    });

    test('trece semanas cumpliendo todos los días: el título es tuyo', () {
      final voy = identityStanding(porSemanas(List.filled(13, 7)), at: hoy)!;
      expect(voy.rhythm, 7);
      expect(voy.kept, 1.0);
      expect(voy.missing, 0);
      expect(voy.earned, isTrue);
    });

    test('el ritmo es el tuyo y no siete', () {
      // Tres días por semana durante trece semanas es una manera de vivir tan
      // sostenida como la de todos los días, y el pueblo la mide contra lo que
      // vos hacés — no contra un calendario lleno.
      final voy = identityStanding(porSemanas(List.filled(13, 3)), at: hoy)!;
      expect(voy.rhythm, 3);
      expect(voy.kept, 1.0);
      expect(voy.earned, isTrue);
    });

    test('pero cumplirlo a medias no alcanza, aunque hayan pasado los meses', () {
      // Siete semanas enteras y seis de dos días: el ritmo sigue siendo diario
      // —la mediana no la mueven seis semanas malas— y el cumplimiento se
      // queda en dos tercios.
      final voy = identityStanding(
        porSemanas([2, 2, 2, 2, 2, 2, 7, 7, 7, 7, 7, 7, 7]),
        at: hoy,
      )!;
      expect(voy.rhythm, 7);
      expect(voy.missing, 0);
      expect(voy.kept, lessThan(identityBar));
      expect(voy.earned, isFalse);
    });

    test('una semana heroica no tapa una semana en blanco', () {
      // Doce semanas de cinco y una de cero, con catorce piezas en la última:
      // si las piezas se sumaran a secas daría de sobra. Cada semana aporta
      // como mucho lo suyo, así que la semana en blanco se nota.
      final voy = identityStanding(
        porSemanas([5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 0, 7]),
        at: hoy,
      )!;
      expect(voy.rhythm, 5);
      expect(voy.kept, lessThan(1.0));
      expect(voy.weeks[11], 0);
    });

    test('una pausa retrasa el título pero no lo pierde', () {
      // Las semanas dormidas no cuentan ni a favor ni en contra: no bajan el
      // cumplimiento —lo que llevás hecho sigue entero— y el título espera.
      final dormida = hoy.subtract(const Duration(days: 34));
      final h = porSemanas([
        for (var w = 0; w < 13; w++)
          if (w == 8 || w == 9) 0 else 7,
      ], rests: [Rest(dormida, dormida.add(const Duration(days: 14))).encode()]);
      final voy = identityStanding(h, at: hoy)!;
      expect(voy.kept, 1.0, reason: 'dormir no es fallar');
      expect(voy.done, 11);
      expect(voy.missing, 2);
      expect(voy.earned, isFalse);
    });

    test('sin frase escrita no hay título que ganar', () {
      expect(identityStanding(porSemanas([7], identity: null), at: hoy), isNull);
    });

    test('y se dice el ritmo como se dice en voz alta', () {
      expect(rhythmSaid(7), 'todos los días');
      expect(rhythmSaid(1), 'un día por semana');
      expect(rhythmSaid(4), '4 días de cada siete');
    });
  });

  group('la regla', () {
    /// Dos pueblos: correr, y estirar detrás de correr. Los dos los días pares.
    (Habit, Habit) dos({int? estiraCada}) {
      final correr = _habit(id: 'hA', name: 'Correr', days: 20, every: 2);
      final estirar = _habit(
        id: 'hB',
        name: 'Estirar',
        days: 20,
        every: estiraCada ?? 2,
        after: 'hA',
      );
      return (correr, estirar);
    }

    test('se dice con los dos nombres y en orden', () {
      final (correr, estirar) = dos();
      expect(
        ruleSaid(estirar, [correr, estirar]),
        'Después de correr, estirar.',
      );
      // Y al revés no existe: la regla la lleva quien la cumple.
      expect(ruleSaid(correr, [correr, estirar]), isNull);
    });

    test('una regla contra un hábito borrado deja de existir sola', () {
      final (_, estirar) = dos();
      expect(afterOf(estirar, [estirar]), isNull);
      expect(ruleSaid(estirar, [estirar]), isNull);
    });

    test('nadie va detrás de sí mismo', () {
      final h = _habit(after: 'h1758000000000001');
      expect(afterOf(h, [h]), isNull);
    });

    test('lo que se mide es la diferencia, no el porcentaje solo', () {
      final (correr, estirar) = dos();
      final hoy = DateTime(2026, 3, 1).add(const Duration(days: 39));
      final score = ruleKept(estirar, [correr, estirar], at: hoy)!;
      // Los dos caen los días pares: los días de correr se cumple siempre, y
      // los demás días nunca. Es la regla haciendo todo el trabajo.
      expect(score.kept, 1.0);
      expect(score.without, 0.0);
      expect(score.of, 20);
      expect(score.ofWithout, greaterThan(0));
    });

    test('con pocos días todavía no se dice nada', () {
      final correr = _habit(id: 'hA', name: 'Correr', days: 3);
      final estirar = _habit(id: 'hB', name: 'Estirar', days: 3, after: 'hA');
      expect(
        ruleKept(estirar, [correr, estirar], at: DateTime(2026, 3, 4)),
        isNull,
      );
    });
  });

  group('lo que el tablón clava con las tres', () {
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

    test('sin plan escrito, el papel pide escribirlo', () {
      final h = _habit(hour: 22);
      final nota = noticesFor(h, at: DateTime(2026, 4, 10)).firstWhere(
        (n) => n.kind == NoticeKind.plan,
      );
      expect(nota.said, contains('22'));
      expect(nota.said, contains('sin plan escrito'));
      // Y lleva el reloj entero detrás, que es de donde salió.
      expect(nota.bars.length, 24);
      expect(nota.mark, 22);
    });

    test('un plan que ya no es el tuyo se dice, sin regañar', () {
      final h = _habit(hour: 22, vowHour: 7, place: 'la cama');
      final nota = noticesFor(h, at: DateTime(2026, 4, 10)).firstWhere(
        (n) => n.kind == NoticeKind.plan,
      );
      expect(nota.said, contains('7'));
      expect(nota.said, contains('22'));
      expect(nota.more, contains('no es rendirse'));
    });

    test('la identidad todavía sin ganar se dice como lo que es', () {
      // Cuarenta días no son trece semanas: el papel existe, pero dice que el
      // pueblo todavía no te llama así y cuánto falta.
      final h = _habit(identity: 'alguien que lee todos los días');
      final nota = noticesFor(h, at: DateTime(2026, 4, 10)).firstWhere(
        (n) => n.kind == NoticeKind.who,
      );
      expect(nota.said, startsWith('El pueblo todavía no te llama'));
      expect(nota.said, contains('alguien que lee todos los días'));
      expect(nota.because, contains('semanas'));
    });

    test('y ganada, el pueblo lo dice entero', () {
      final hoy = DateTime(2026, 9, 28);
      final h = _habit(
        from: hoy.subtract(const Duration(days: 90)),
        days: 91,
        identity: 'alguien que lee todos los días',
      );
      final nota = noticesFor(h, at: hoy).firstWhere(
        (n) => n.kind == NoticeKind.who,
      );
      expect(nota.said, 'Este pueblo es de alguien que lee todos los días.');
      expect(nota.because, contains('Trece semanas'));
    });

    test('y el papel del título cambia de sitio según esté ganado', () {
      // Dado, es la noticia más grande del pueblo y va arriba. Sin ganar, es
      // algo a lo que vas: tres meses de «todavía no» en el primer papel sería
      // una app dando la lata.
      final hoy = DateTime(2026, 9, 28);
      final joven = noticesFor(
        _habit(identity: 'alguien sabio'),
        at: DateTime(2026, 4, 10),
      );
      expect(joven.last.kind, NoticeKind.who);
      final viejo = noticesFor(
        _habit(
          from: hoy.subtract(const Duration(days: 90)),
          days: 91,
          identity: 'alguien sabio',
        ),
        at: hoy,
      );
      expect(viejo.first.kind, NoticeKind.who);
    });

    test('la regla firmada tapa la observación de la que salió', () {
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
      expect(clavado, contains(NoticeKind.rule));
      expect(
        clavado,
        isNot(contains(NoticeKind.pair)),
        reason: 'la observación y la regla dirían lo mismo',
      );
    });

    test('la observación dice de quién habla, para poder firmarla', () {
      // Sin esto no se puede convertir en regla desde el tablón: el papel no
      // sabría de cuál de los seis pueblos estaba hablando.
      final correr = _habit(id: 'hA', name: 'Correr', days: 30, every: 2);
      final estirar = _habit(id: 'hB', name: 'Estirar', days: 30, every: 2);
      final valle = [correr, estirar];
      final nota = noticesFor(
        estirar,
        others: valle,
        at: DateTime(2026, 5, 10),
      ).firstWhere((n) => n.kind == NoticeKind.pair);
      expect(nota.about, 'hA', reason: 'el que va primero');
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
