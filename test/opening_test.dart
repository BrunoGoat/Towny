import 'package:flutter_test/flutter_test.dart';

import 'package:la_muralla/core/rng.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';

/// Las cuatro estructuras con las que abre un pueblo de esta semilla.
List<BuildingKind> _abre(TownCharacter c, int seed) {
  final plan = TownPlan.of(c, seed: seed);
  return [for (var b = 0; b < 4; b++) plan.kindFor(b)];
}

/// Dónde quedan los primeros solares, medidos en anchos de parcela desde la
/// plaza — que es donde está el tablón. Así dos regiones con parcelas de
/// distinto tamaño se pueden comparar de verdad.
List<String> _solares(TownCharacter c, int seed, {int hasta = 6}) {
  final t = TownLayout(120, c, seed: seed);
  return [
    for (var b = 0; b < hasta; b++)
      '${(t.buildings[b].cx / c.plotPitch).toStringAsFixed(2)},'
          '${(t.buildings[b].cz / c.plotPitch).toStringAsFixed(2)}',
  ];
}

Habit _habit(String id, int slot) => Habit(
  id: id,
  name: 'Prueba',
  symbol: 'rueda',
  slot: slot,
  createdAt: DateTime(2026, 3, 1),
  character: TownCharacter.all.first.order,
  pieces: const [],
);

void main() {
  group('el arranque de un pueblo', () {
    test('son cuatro humildes, y las cuatro distintas', () {
      // Que sean humildes no se sortea: un valle que abre con una posada es un
      // valle que ya estaba ahí. Y que se repita una es lo que hacía que el
      // arranque se leyera como un error y no como azar.
      const humildes = {
        BuildingKind.shed,
        BuildingKind.cottage,
        BuildingKind.workshop,
        BuildingKind.house,
        BuildingKind.granary,
      };
      for (var k = 0; k < 200; k++) {
        final abre = _abre(TownCharacter.all.first, hashText('h$k'));
        expect(abre.toSet().length, 4, reason: 'se repite una en h$k');
        for (final kind in abre) {
          expect(humildes, contains(kind), reason: '$kind no es humilde');
        }
      }
    });

    test('y ninguna de las cuatro es un hito', () {
      for (var k = 0; k < 50; k++) {
        final plan = TownPlan.of(
          TownCharacter.all.first,
          seed: hashText('h$k'),
        );
        for (final w in plan.walk(const []).take(4)) {
          expect(w.landmark, isNull);
        }
      }
    });

    test('dos pueblos no abren igual', () {
      // Lo que se veía en pantalla: dos hábitos distintos, la misma secuencia
      // de casas hasta el primer hito, o sea varias semanas mirando el mismo
      // pueblo dos veces.
      final visto = <String, int>{};
      for (var k = 0; k < 200; k++) {
        final s = _abre(
          TownCharacter.all.first,
          hashText('h$k'),
        ).map((e) => e.name).join(',');
        visto[s] = (visto[s] ?? 0) + 1;
      }
      // De las ciento veinte barajas posibles tienen que salir muchísimas.
      expect(visto.length, greaterThan(80));
      // Y ninguna puede acaparar: con un sorteo roto salía siempre la misma.
      expect(visto.values.reduce((a, b) => a > b ? a : b), lessThan(20));
    });

    test('y tampoco se plantan en los mismos solares', () {
      final visto = <String>{};
      for (var k = 0; k < 60; k++) {
        visto.add(_solares(TownCharacter.all.first, hashText('h$k')).join(' '));
      }
      expect(visto.length, greaterThan(40));
    });

    test('la posición no la decide la región, la decide el pueblo', () {
      // Ésta es la que falla si la varita vuelve a depender sólo de la rejilla:
      // dos pueblos de regiones distintas tenían los primeros solares en el
      // mismo sitio medido en parcelas, y se notaba comparándolos con el
      // tablón.
      final a = _solares(TownCharacter.all[0], hashText('hA'));
      final b = _solares(TownCharacter.all[3], hashText('hB'));
      expect(a, isNot(b));
    });
  });

  group('la semilla es del hábito y no se mueve', () {
    test('sale del identificador y no de la ranura ni del nombre', () {
      final uno = _habit('h1758000000000001', 0);
      final otro = Habit(
        id: uno.id,
        name: 'Otro nombre entero',
        symbol: 'ancla',
        slot: 4,
        createdAt: DateTime(2020, 1, 1),
        character: uno.character,
        pieces: [Piece(index: 0, placedAt: DateTime(2026, 3, 2))],
      );
      expect(otro.townSeed, uno.townSeed);
      expect(_habit('h1758000000000002', 0).townSeed, isNot(uno.townSeed));
    });

    test('el mismo hábito levanta siempre el mismo pueblo', () {
      final h = _habit('h1758000000000001', 0);
      expect(_solares(h.place, h.townSeed), _solares(h.place, h.townSeed));
      expect(_abre(h.place, h.townSeed), _abre(h.place, h.townSeed));
    });

    test('guardar y volver a leer el hábito no le cambia el pueblo', () {
      final h = _habit('h1758000000000001', 2);
      final leido = Habit.fromJson(h.toJson());
      expect(leido.townSeed, h.townSeed);
    });
  });

  group('un pueblo ya construido también cambia', () {
    test(
      'lo escrito manda de la crónica en adelante, pero no en el arranque',
      () {
        // El usuario es el único que tiene la app y quiere que sus pueblos,
        // levantados con el arranque viejo, sigan la regla nueva. La crónica
        // existe para protegerse de que cambie el catálogo de hitos; las cuatro
        // primeras no salen del catálogo sino de la semilla, que es tan
        // inmutable como la crónica, así que se derivan siempre.
        final c = TownCharacter.all.first;
        final vieja = ['#shed', '#cottage', '#workshop', '#cottage', 'pozo'];
        final plan = TownPlan.of(c, seed: hashText('h1758000000000001'));
        final anda = plan.walk(vieja).take(5).toList();
        expect(
          [for (var i = 0; i < 4; i++) anda[i].id],
          isNot(vieja.take(4).toList()),
          reason: 'el arranque viejo sigue mandando',
        );
        // Pero el hito escrito sí sigue siendo el que se escribió.
        expect(anda[4].id, 'pozo');
      },
    );

    test('y la crónica se corrige sola en cuanto crece', () {
      final c = TownCharacter.all.first;
      final plan = TownPlan.of(c, seed: hashText('h1758000000000001'));
      final vieja = ['#shed', '#cottage', '#workshop', '#cottage'];
      final nueva = plan.chronicleFor(400, vieja);
      expect(nueva.length, greaterThan(vieja.length));
      expect(nueva.take(4).toList(), isNot(vieja));
      for (var i = 0; i < 4; i++) {
        expect(nueva[i].startsWith(TownPlan.kindMark), isTrue);
      }
    });
  });
}
