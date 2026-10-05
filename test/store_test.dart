import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/character.dart';
import 'package:towny/data/landmarks.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/model/habit.dart';
import 'package:towny/model/piece.dart';
import 'package:towny/model/rhythm.dart';
import 'package:towny/model/store.dart';

Future<Store> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final s = Store();
  await s.load();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('one brick is one achievement', () {
    test('placing adds exactly one brick, never a batch', () async {
      final s = await freshStore();
      expect(s.total, 0);
      s.placePiece();
      expect(s.total, 1);
      s.placePiece();
      s.placePiece();
      expect(s.total, 3);
    });

    test('bricks are numbered in the order they were earned', () async {
      final s = await freshStore();
      s.placePiece();
      s.placePiece();
      s.placePiece();
      expect(s.pieces.map((x) => x.index), [0, 1, 2]);
    });
  });

  group('las leyendas ya no existen', () {
    // Quien venga de una versión con leyendas trae en cada pieza una clave
    // `l`. Se lee el valle entero, y en el teléfono queda escrito sin ellas.
    test('un guardado con leyendas se abre y se reescribe sin ellas', () async {
      final s = await freshStore();
      s.placePiece();
      s.placePiece();
      final viejo = s.exportSave().replaceFirst('"i":1,', '"i":1,"l":"Leí",');
      expect(viejo, contains('"l":"Leí"'));

      SharedPreferences.setMockInitialValues({'pueblo_state_v1': viejo});
      final again = Store();
      await again.load();
      expect(again.total, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pueblo_state_v1'), isNot(contains('"l":')));
    });
  });

  group('volver', () {
    test('la primera pieza no vuelve de ningún sitio', () async {
      final s = await freshStore();
      expect(s.isAway, isFalse);
      final r = s.placePiece();
      expect(r.returned, isFalse);
      expect(s.isAway, isFalse);
    });

    test('nueve días fuera de un hábito diario es una vuelta', () async {
      final s = await freshStore();
      s.debugFill(20, endedDaysAgo: 9);
      expect(s.isAway, isTrue);

      final r = s.placePiece();
      expect(r.returned, isTrue);
      expect(r.awayDays, greaterThan(8));
      expect(s.isAway, isFalse);
    });

    test(
      'a quien viene los domingos no se le da la bienvenida cada domingo',
      () async {
        final s = await freshStore();
        final hoy = DateTime.now();
        for (var w = 6; w >= 1; w--) {
          s.pieces.add(
            Piece(
              index: s.pieces.length,
              placedAt: hoy.subtract(Duration(days: w * 7)),
            ),
          );
        }
        // Una semana justa desde la última: es su ritmo, no un hueco.
        expect(Store.awayAfter(s.habit), 14);
        expect(s.isAway, isFalse);
        expect(s.placePiece().returned, isFalse);
      },
    );
  });

  group('what kind of place a habit builds', () {
    // Chosen the day it is founded and never again: the character decides how
    // wide the plots are and in what order the hundred and twelve arrive, so
    // changing it would move pieces laid years ago.
    test('the region chosen when founding is the one it keeps', () async {
      final store = await freshStore();
      final want = TownCharacter.all[3];
      store.addHabit('Correr', 'carrera', character: want.order);
      expect(store.habit.place.region, want.region);

      final again = Store();
      await again.load();
      final found = again.habits.firstWhere((h) => h.name == 'Correr');
      expect(found.place.region, want.region);
    });

    test('a habit saved before there was a choice keeps its plot\'s own', () {
      final old = Habit.fromJson({
        'id': 'h1',
        'n': 'Leer',
        's': 'libro',
        'slot': 2,
        'c': DateTime(2025).millisecondsSinceEpoch,
        'p': const [],
      });
      expect(old.place.region, TownCharacter.forSlot(2).region);
    });
  });

  group('eliminar un hábito', () {
    test('se lleva su pueblo y deja los demás donde estaban', () async {
      final s = await freshStore();
      s.renameHabit(0, name: 'Leer');
      s.addHabit('Correr', 'carrera');
      s.addHabit('Nadar', 'ola');
      s.select(1);
      s.placePiece();
      s.removeHabit(1);
      expect(s.habits.length, 2);
      expect(s.habits.map((h) => h.name), ['Leer', 'Nadar']);
      expect(s.habits.every((h) => h.total == 0), isTrue);
    });

    test(
      'el último también se puede eliminar: el valle vuelve a cero',
      () async {
        // Lo que pasaba: con un solo hábito el botón no hacía nada, así que no
        // había forma de borrar un pueblo empezado por error. Un valle sin
        // nada que dibujar no es un estado que la app tenga, así que eliminar
        // el único deja el mismo hábito en blanco de un teléfono recién
        // instalado — sin nombre puesto, sin piezas y sin la marca de antes.
        final s = await freshStore();
        s.renameHabit(0, name: 'Fumar menos', symbol: 'pipa');
        s.placePiece();
        s.placePiece();
        final was = s.habit.id;
        s.removeHabit(0);
        expect(s.habits.length, 1);
        expect(s.habit.id, isNot(was));
        expect(s.habit.total, 0);
        expect(s.habit.name, isNot('Fumar menos'));
        expect(s.habit.symbol, isNot('pipa'));
        expect(s.active, 0);
      },
    );

    test('un índice que no existe no toca nada', () async {
      final s = await freshStore();
      s.addHabit('Correr', 'carrera');
      s.removeHabit(7);
      s.removeHabit(-1);
      expect(s.habits.length, 2);
    });
  });

  group('lo de hoy', () {
    test('cuenta las de hoy y no las de ayer', () async {
      final s = await freshStore();
      expect(s.today, 0);
      s.placePiece();
      s.placePiece();
      expect(s.today, 2);
      // Una de ellas corrida a anteayer deja de contar hoy.
      s.setPlacedAt(0, DateTime.now().subtract(const Duration(days: 2)));
      expect(s.today, 1);
    });

    test('y es de este pueblo, no del valle', () async {
      final s = await freshStore();
      s.placePiece();
      s.addHabit('Leer', 'lectura');
      // El hábito nuevo queda seleccionado y su pueblo está vacío.
      expect(s.today, 0);
    });
  });

  group('la hora de una pieza se corrige', () {
    test('y se queda corregida', () async {
      final s = await freshStore();
      s.placePiece();
      // Un rato antes y no una hora fija: el test corre a cualquier hora del
      // día y una hora fija sería el futuro la mitad de las veces — y el
      // futuro se recorta, que es justo la prueba siguiente.
      final antes = s.pieceAt(0)!.placedAt;
      final temprano = antes.subtract(const Duration(hours: 9, minutes: 7));
      s.setPlacedAt(0, temprano);
      expect(s.pieceAt(0)!.placedAt, temprano);
    });

    test('nunca hacia el futuro', () async {
      // Una pieza puesta dentro de tres horas rompe todo lo que mide el tiempo
      // desde la última —el deterioro, la racha, lo que el tablón va notando—
      // y no quiere decir nada. Se recorta a ahora.
      final s = await freshStore();
      s.placePiece();
      final antes = DateTime.now();
      s.setPlacedAt(0, antes.add(const Duration(days: 2)));
      final ahora = s.pieceAt(0)!.placedAt;
      expect(ahora.isAfter(antes.add(const Duration(seconds: 5))), isFalse);
    });

    test('y sobrevive a cerrar la app', () async {
      final s = await freshStore();
      s.placePiece();
      // Redondeado al milisegundo, que es lo que cabe en el disco: lo que se
      // guarda son milisegundos desde la época, y los microsegundos del reloj
      // no vuelven.
      final temprano = DateTime.fromMillisecondsSinceEpoch(
        s.pieceAt(0)!.placedAt.millisecondsSinceEpoch - 5 * 3600 * 1000,
      );
      s.setPlacedAt(0, temprano);
      final again = Store();
      await again.load();
      expect(again.pieceAt(0)!.placedAt, temprano);
    });

    test('un índice que no existe no toca nada', () async {
      final s = await freshStore();
      s.placePiece();
      final w = s.pieceAt(0)!.placedAt;
      s.setPlacedAt(9, DateTime(2000));
      s.setPlacedAt(-1, DateTime(2000));
      expect(s.pieceAt(0)!.placedAt, w);
    });
  });

  group('el cielo del valle', () {
    // El cielo ya no se desbloquea ni se anota: algunas noches hay una figura
    // ahí arriba y otras no, y tocarla suena y no la apunta nadie. Lo que
    // queda de aquello son estas dos, que siguen valiendo por otra razón — el
    // observatorio es un hito del catálogo y tiene que salir en los seis.
    test('a todo pueblo le acaba tocando el catálogo entero', () async {
      // Un hito que en un carácter no sale nunca es un hito que ese hábito no
      // ve jamás, y eso no se notaría hasta que alguien llegase. Antes esto
      // preguntaba por el observatorio, que era la obra que le tocaba a todo
      // el mundo; el observatorio se retiró y la pregunta de verdad era ésta,
      // que además vale para las sesenta.
      //
      // Se cuenta desde el catálogo y no desde una lista escrita a mano: una
      // obra nueva entra sola en la cuenta, y una retirada sale sola.
      for (final c in TownCharacter.all) {
        final plan = TownPlan.of(c);
        final faltan = [
          for (final l in landmarks)
            if (!plan.built(l.id, 12000)) l.id,
        ];
        expect(
          faltan,
          isEmpty,
          reason: '${c.region} no levanta $faltan ni con doce mil piezas',
        );
      }
    });

    test('y ninguna se levanta de golpe', () async {
      // Lo que costó piezas tiene que verse costar: antes de la última pieza
      // no está terminada, y después sí.
      final s = await freshStore();
      final plan = TownPlan.of(s.character);
      for (final l in landmarks.take(8)) {
        var at = -1;
        for (var n = 0; n <= 12000; n++) {
          if (plan.built(l.id, n)) {
            at = n;
            break;
          }
        }
        expect(at, greaterThan(0), reason: '${l.name}: no se construye nunca');
        expect(plan.built(l.id, at - 1), isFalse, reason: l.name);
        expect(plan.built(l.id, at + 500), isTrue, reason: l.name);
      }
    });

    test('y un guardado viejo con su cuaderno se lee igual', () async {
      // Quien tenga anotadas constelaciones en el disco trae una lista `sky`
      // que ya no significa nada. Se lee, se tira, y lo que importa —el valle—
      // entra entero.
      final s = await freshStore();
      s.addHabit('Leer', 'lectura');
      s.placePiece();
      final saved = s.exportSave();
      final viejo = saved.replaceFirst('{', '{"sky":["orion","cruz"],');
      final other = await freshStore();
      expect(other.importSave(viejo), isNull, reason: 'no lo pudo leer');
      expect(other.habits.length, 2);
      expect(other.exportSave().contains('sky'), isFalse);
    });
  });

  group('quitar la última pieza', () {
    test('la quita, y sólo la última', () async {
      final s = await freshStore();
      s.placePiece();
      s.placePiece();
      s.placePiece();
      final gone = s.removeLastPiece();
      expect(gone, isNotNull);
      expect(gone!.index, 2);
      expect(s.total, 2);
      expect(s.pieceAt(0), isNotNull);
      expect(s.pieceAt(1), isNotNull);
      expect(s.pieceAt(2), isNull);
    });

    test('con el pueblo vacío no hace nada', () async {
      final s = await freshStore();
      expect(s.removeLastPiece(), isNull);
      expect(s.total, 0);
    });

    test('y queda quitada al volver a abrir', () async {
      final s = await freshStore();
      s.placePiece();
      s.placePiece();
      s.removeLastPiece();
      final again = Store();
      await again.load();
      expect(again.total, 1);
    });

    test('la crónica de obra no se deshace con ella', () async {
      // Lo que se decidió, se decidió. Deshacer un dedo no es motivo para
      // volver a sortear qué edificio se está levantando: el que estaba
      // escrito sigue siendo el que se va a construir.
      final s = await freshStore();
      for (var i = 0; i < 40; i++) {
        s.placePiece();
      }
      final was = [...s.habit.chronicle];
      s.removeLastPiece();
      expect(s.habit.chronicle, was);
    });
  });

  group('persistence', () {
    test('the wall survives a restart exactly as it was', () async {
      SharedPreferences.setMockInitialValues({});
      final a = Store();
      await a.load();
      for (var i = 0; i < 14; i++) {
        a.placePiece();
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final b = Store();
      await b.load();
      expect(b.total, a.total);
      // Al milisegundo, que es la resolución con la que se guarda.
      expect(
        b.pieceAt(3)!.placedAt.millisecondsSinceEpoch,
        a.pieceAt(3)!.placedAt.millisecondsSinceEpoch,
      );
    });

    test('a corrupt save starts clean instead of failing', () async {
      // Sobre la clave de ahora, que es donde está lo que se guarda. Apuntaba
      // a la del nombre viejo, y al irse el lector de aquello esta prueba
      // habría pasado por no haber ningún guardado que leer — que es pasar
      // sin probar nada.
      SharedPreferences.setMockInitialValues({
        'flutter.pueblo_state_v1': 'not json at all',
      });
      final s = Store();
      await s.load();
      expect(s.loaded, isTrue);
      expect(s.total, 0);
    });
  });

  // La racha murió y no quedó escondida en ningún rincón: lo que la sustituyó
  // mide lo mismo de una manera que admite un mal día, que es la única que
  // sirve para medir algo sostenible.
  group('consistencia en lugar de rachas', () {
    /// Un hábito con piezas en esos días atrás, y nacido lo bastante antes
    /// como para que la ventana entera cuente.
    Future<Store> withDays(List<int> offsets, {int born = 40}) async {
      final s = await freshStore();
      final today = dayStart(DateTime.now());
      s.habits[0] = Habit(
        id: s.habit.id,
        name: s.habit.name,
        symbol: s.habit.symbol,
        slot: s.habit.slot,
        createdAt: today.subtract(Duration(days: born)),
      );
      for (final offset in offsets) {
        s.pieces.add(
          Piece(
            index: s.total,
            placedAt: today.subtract(Duration(days: offset, hours: -12)),
          ),
        );
      }
      return s;
    }

    test('un fallo baja la consistencia, no la tira a cero', () async {
      // Veintinueve de los últimos treinta días, menos hoy que aún no terminó.
      final s = await withDays([for (var i = 1; i <= 29; i++) i]);
      final firme = s.consistency;
      expect(firme.enough, isTrue);
      // Ayer no hubo pieza sólo si lo sacamos; acá están todos, así que lo que
      // se comprueba es que el numerador y el denominador son los de verdad.
      expect(firme.done, 29);
      expect(firme.of, 29);

      // Y ahora uno con un hueco en medio: baja, y no se va a cero.
      final roto = await withDays([
        for (var i = 1; i <= 29; i++)
          if (i != 3) i,
      ]);
      expect(roto.consistency.done, 28);
      expect(roto.consistency.of, 29);
      expect(roto.consistency.rate, greaterThan(0.9));
    });

    test('hoy en blanco no cuenta en contra: el día no terminó', () async {
      // Los veintinueve días anteriores con pieza, y hoy todavía sin nada.
      final s = await withDays([for (var i = 1; i <= 29; i++) i]);
      // La ventana son treinta días, y el denominador sale veintinueve: hoy no
      // está. Descontar por un día que aún no terminó, a las nueve de la
      // mañana, es exactamente el castigo que esto vino a quitar.
      expect(s.consistency.of, 29);

      // Y en cuanto cae la de hoy, cuenta como cualquier otro día.
      s.placePiece();
      expect(s.consistency.of, 30);
      expect(s.consistency.done, 30);
    });

    test('se calla hasta que hay dos semanas de las que hablar', () async {
      final s = await withDays([1, 2, 3], born: 3);
      expect(s.consistency.enough, isFalse);
    });

    test('los días dormidos no cuentan ni a favor ni en contra', () async {
      final s = await withDays([for (var i = 15; i <= 29; i++) i]);
      final today = dayStart(DateTime.now());
      // Catorce días sin nada, pero dormidos a propósito.
      s.habit.rests.add(
        Rest(
          today.subtract(const Duration(days: 14)),
          today.add(const Duration(days: 1)),
        ).encode(),
      );
      final firme = s.consistency;
      expect(firme.done, firme.of, reason: 'una pausa no es un fallo');
    });
  });

  group('la vuelta', () {
    test(
      'mide cuánto tardás en volver, y mejora cuando volvés antes',
      () async {
        final s = await freshStore();
        final today = dayStart(DateTime.now());
        // Huecos de 4, 4, 1, 1 días entre piezas.
        for (final offset in [30, 25, 20, 18, 16]) {
          s.pieces.add(
            Piece(
              index: s.total,
              placedAt: today.subtract(Duration(days: offset, hours: -12)),
            ),
          );
        }
        expect(s.comingBack, isNotNull);
        // Cuatro huecos: 4, 4, 1, 1. La mediana de los ordenados es el tercero.
        expect(s.comingBack, 4);
      },
    );

    test('una pausa entera en medio no es un hueco', () async {
      final s = await freshStore();
      final today = dayStart(DateTime.now());
      for (final offset in [20, 5]) {
        s.pieces.add(
          Piece(
            index: s.total,
            placedAt: today.subtract(Duration(days: offset, hours: -12)),
          ),
        );
      }
      expect(gapsOf(s.habit), [14]);
      s.habit.rests.add(
        Rest(
          today.subtract(const Duration(days: 20)),
          today.subtract(const Duration(days: 5)),
        ).encode(),
      );
      expect(gapsOf(s.habit), isEmpty);
    });
  });

  group('dormir el pueblo', () {
    test('no se apaga mientras duerme, y despierta sin deuda', () async {
      final s = await freshStore();
      s.pieces.add(
        Piece(
          index: 0,
          placedAt: DateTime.now().subtract(const Duration(days: 20)),
        ),
      );
      // Veinte días sin venir: eso es estar fuera.
      expect(s.isAway, isTrue);

      s.rest(s.habit, DateTime.now().add(const Duration(days: 7)));
      expect(s.habit.resting, isTrue);
      expect(Store.daysIdleOf(s.habit), 0);
      expect(s.isAway, isFalse);
    });

    test('poner una pieza despierta el pueblo', () async {
      final s = await freshStore();
      s.placePiece();
      s.rest(s.habit, DateTime.now().add(const Duration(days: 7)));
      expect(s.habit.resting, isTrue);
      final r = s.placePiece();
      expect(r.woke, isTrue);
      expect(s.habit.resting, isFalse);
    });

    test('la pausa queda escrita con lo que duró de verdad', () async {
      final s = await freshStore();
      s.placePiece();
      s.rest(s.habit, DateTime.now().add(const Duration(days: 30)));
      s.wake(s.habit);
      expect(s.habit.resting, isFalse);
      // Se recorta, no se borra: cuánto duró es un dato.
      expect(s.habit.rests.length, lessThanOrEqualTo(1));
    });
  });

  group('el candado del segundo pueblo', () {
    test('cerrado hasta que el primero se sostiene', () async {
      final s = await freshStore();
      expect(s.unlocked, isFalse);
      expect(s.canAddHabit, isFalse);
    });

    test('se abre con días con pieza, sin exigir que sean seguidos', () async {
      final s = await freshStore();
      final today = dayStart(DateTime.now());
      // Diez días con pieza dentro de los últimos catorce, con cuatro fallos
      // por el medio: una racha diría que no, y acá se abre igual.
      for (final offset in [0, 1, 2, 4, 5, 7, 8, 9, 11, 13]) {
        s.pieces.add(
          Piece(
            index: s.total,
            placedAt: today.subtract(Duration(days: offset, hours: -12)),
          ),
        );
      }
      expect(s.unlockGoal.have, 10);
      expect(s.unlockGoal.need, 10);
      s.placePiece();
      expect(s.unlocked, isTrue);
      expect(s.canAddHabit, isTrue);
    });

    test('una vez abierto no se vuelve a cerrar', () async {
      final s = await freshStore();
      final today = dayStart(DateTime.now());
      for (final offset in [0, 1, 2, 4, 5, 7, 8, 9, 11, 13]) {
        s.pieces.add(
          Piece(
            index: s.total,
            placedAt: today.subtract(Duration(days: offset, hours: -12)),
          ),
        );
      }
      s.placePiece();
      expect(s.unlocked, isTrue);
      // Y ahora un mes entero sin aparecer: la puerta sigue abierta. Cerrarla
      // castigaría justo a quien vuelve, que es para quien está hecha la app.
      s.habits[0].pieces.clear();
      s.pieces.add(
        Piece(index: 0, placedAt: today.subtract(const Duration(days: 40))),
      );
      expect(s.unlockGoal.have, 0);
      expect(s.unlocked, isTrue);
      expect(s.canAddHabit, isTrue);
    });

    test('un valle que ya tenía varios pueblos entra abierto', () async {
      // Lo que pediste: esto no es retrocompatible hacia atrás. Una copia
      // guardada antes del candado, con más de un pueblo, los conserva todos y
      // no se le pregunta nada.
      SharedPreferences.setMockInitialValues({
        'pueblo_state_v1': jsonEncode({
          'v': 1,
          'a': 0,
          'h': [
            {'id': 'h1', 'n': 'Leer', 's': 'libro', 'slot': 0, 'p': []},
            {'id': 'h2', 'n': 'Correr', 's': 'carrera', 'slot': 1, 'p': []},
          ],
        }),
      });
      final s = Store();
      await s.load();
      expect(s.habits.length, 2);
      expect(s.unlocked, isTrue);
      expect(s.canAddHabit, isTrue);
    });
  });

  group('el desenganche', () {
    test('no se pregunta por un hueco corto ni sin historia', () async {
      final s = await freshStore();
      s.placePiece();
      expect(s.adrift, isNull);
    });

    test('se pregunta una sola vez por hueco', () async {
      final s = await freshStore();
      final today = dayStart(DateTime.now());
      for (final offset in [30, 29, 28, 27, 26, 25]) {
        s.pieces.add(
          Piece(
            index: s.total,
            placedAt: today.subtract(Duration(days: offset, hours: -12)),
          ),
        );
      }
      expect(s.adrift, isNotNull);
      s.asked(s.habit);
      expect(s.adrift, isNull, reason: 'insistir es lo que hace que se borre');
    });

    test('un pueblo dormido nunca está desenganchado', () async {
      final s = await freshStore();
      final today = dayStart(DateTime.now());
      for (final offset in [30, 29, 28, 27, 26, 25]) {
        s.pieces.add(
          Piece(
            index: s.total,
            placedAt: today.subtract(Duration(days: offset, hours: -12)),
          ),
        );
      }
      expect(s.adrift, isNotNull);
      s.rest(s.habit, DateTime.now().add(const Duration(days: 7)));
      expect(s.adrift, isNull);
    });
  });
}
