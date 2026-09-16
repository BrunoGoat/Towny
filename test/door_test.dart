import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/engine/solid.dart';
import 'package:la_muralla/engine/solids.dart';
import 'package:la_muralla/engine/town.dart';

/// Todo lo que el pueblo sabe construir: las siete casas corrientes y los
/// ciento y pico hitos, que es la misma lista que enseña el expositor.
List<(String, Landmark?, BuildingKind?, int)> _catalogue() => [
  for (final k in BuildingKind.values)
    (buildingName[k]!, null, k, buildingCost[k]!),
  for (final m in landmarks) (m.name, m, null, m.cost),
];

TownLayout _show(
  Landmark? mark,
  BuildingKind? kind,
  int cost,
  TownCharacter c,
) => TownLayout.showcase(
  c,
  landmark: mark,
  kind: kind,
  placed: cost,
  seed: c.order,
);

void main() {
  group('la puerta se fue', () {
    test('ninguna estructura levanta ya un bulto contra su fachada', () {
      // Era una caja de cal de medio metro de fondo pegada al muro, encalada
      // del mismo color que la fachada: desde fuera, un cubo blanco. Estaba en
      // setenta recetas y ahora no está en ninguna.
      final bultos = <String>[];
      for (final c in TownCharacter.all) {
        for (final (name, mark, kind, cost) in _catalogue()) {
          for (final p in _show(mark, kind, cost, c).pieces) {
            if (p.kind != PieceKind.porch) continue;
            // Lo que queda con esa palabra son cuerpos bajos y anchos: una
            // tarima, un embarcadero, una visera. Nada alto y delgado, que era
            // la forma de la puerta.
            if (p.y1 - p.y0 >= 0.36 && math.min(p.w, p.d) <= 0.30) {
              bultos.add('${c.region} $name');
            }
          }
        }
      }
      expect(bultos, isEmpty, reason: 'sigue habiendo puertas: $bultos');
    });

    test('y lo que queda con ese nombre no va encalado como la fachada', () {
      // La otra mitad de por qué se leía como un cubo blanco: un cuerpo que
      // sale de una pared y tiene exactamente el color de la pared.
      final blancos = <String>[];
      for (final c in TownCharacter.all) {
        for (final (name, mark, kind, cost) in _catalogue()) {
          for (final p in _show(mark, kind, cost, c).pieces) {
            if (p.kind != PieceKind.porch) continue;
            for (final s in solidsOf(p)) {
              for (final f in s.faces) {
                if (f.surface == Surface.wall) blancos.add('${c.region} $name');
              }
            }
          }
        }
      }
      expect(blancos, isEmpty, reason: 'siguen siendo cubos de cal: $blancos');
    });
  });

  group('y con ella se fue su logro', () {
    // Ésta es la prueba de fuego de haber quitado una pieza de setenta
    // recetas: si a una se le quitó la puerta y se le olvidó bajarle el
    // precio, `finish` rellena repitiendo la pieza anterior en el mismo sitio
    // — y eso es un día en que se puso una pieza y el pueblo no cambió.
    test('cada estructura pone exactamente las piezas que cuesta', () {
      for (final c in TownCharacter.all) {
        for (final (name, mark, kind, cost) in _catalogue()) {
          expect(
            _show(mark, kind, cost, c).pieces.length,
            cost,
            reason: '${c.region} $name',
          );
        }
      }
    });

    test('y ninguna receta rellena repitiendo la pieza anterior', () {
      final mudas = <String>[];
      for (final c in TownCharacter.all) {
        for (final (name, mark, kind, cost) in _catalogue()) {
          final ps = _show(mark, kind, cost, c).pieces;
          for (var i = 1; i < ps.length; i++) {
            final a = ps[i - 1], b = ps[i];
            if (a.kind == b.kind &&
                (a.cx - b.cx).abs() < 1e-9 &&
                (a.cz - b.cz).abs() < 1e-9 &&
                (a.w - b.w).abs() < 1e-9 &&
                (a.d - b.d).abs() < 1e-9 &&
                (a.y0 - b.y0).abs() < 1e-9 &&
                (a.y1 - b.y1).abs() < 1e-9) {
              mudas.add('${c.region} $name en la pieza $i');
            }
          }
        }
      }
      expect(mudas, isEmpty, reason: 'logros que no colocan nada: $mudas');
    });

    test('ni deja ninguna receta a medio escribir', () {
      // Al revés que lo anterior: una receta que escribe más piezas de las que
      // cuesta se queda con el final sin construir para siempre. Se mira
      // pidiéndole una pieza de más y comprobando que no sabe darla.
      for (final c in TownCharacter.all) {
        for (final (name, mark, kind, cost) in _catalogue()) {
          expect(
            TownLayout.showcase(
              c,
              landmark: mark,
              kind: kind,
              placed: cost + 4,
              seed: c.order,
            ).pieces.length,
            cost,
            reason: '${c.region} $name sabe poner más de lo que cobra',
          );
        }
      }
    });
  });

  group('un pueblo que ya estaba levantado', () {
    test('llega más lejos con las mismas piezas', () {
      // Lo que se pidió: las estructuras que tenían puerta cuestan un logro
      // menos, así que se terminan antes y lo que sobra arranca lo siguiente.
      // Con la crónica escrita, que es como está un pueblo de verdad.
      final c = TownCharacter.all.first;
      final plan = TownPlan.of(c);
      final cronica = plan.chronicleFor(200, const []);
      var edificios = 0, total = 0;
      for (final w in plan.walk(cronica)) {
        if (w.from >= 200) break;
        edificios++;
        total += w.cost;
      }
      // Medido contra la versión anterior: doscientas piezas daban treinta
      // edificios empezados y ahora dan treinta y dos. El número exacto puede
      // cambiar si mañana se añade un hito al catálogo; que sean más que
      // treinta, no — para eso haría falta volver a cobrar la puerta.
      expect(edificios, greaterThan(30));
      expect(total, greaterThanOrEqualTo(200));
    });

    test('y lo escrito en la crónica sigue siendo lo que se levanta', () {
      // Cambia lo que cuesta cada cosa, no cuál es cada cosa: el quinto
      // edificio de un pueblo sigue siendo el que decía la crónica.
      final c = TownCharacter.all.first;
      final plan = TownPlan.of(c);
      final cronica = plan.chronicleFor(400, const []);
      final anda = plan.walk(cronica).take(cronica.length).toList();
      for (var i = 0; i < cronica.length; i++) {
        expect(anda[i].id, cronica[i]);
      }
    });
  });
}
