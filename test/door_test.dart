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

/// Si esta pieza es una puerta y no el poyo bajo y ancho que un par de recetas
/// escriben con la misma palabra.
bool _esPuerta(TownPiece p) =>
    p.kind == PieceKind.porch &&
    p.y1 - p.y0 >= 0.36 &&
    math.min(p.w, p.d) <= 0.26;

void main() {
  group('una puerta es una puerta', () {
    test('y lo que no es una puerta no va encalado como la fachada', () {
      // La otra mitad del cubo blanco. Cinco recetas usan esta misma palabra
      // para un cuerpo que no es una puerta —la tarima de un soportal, un
      // embarcadero, la visera sobre un portal— y todos iban encalados: un
      // bloque saliendo de una pared, exactamente del color de la pared.
      final blancos = <String>[];
      for (final c in TownCharacter.all) {
        for (final (name, mark, kind, cost) in _catalogue()) {
          for (final p in _show(mark, kind, cost, c).pieces) {
            if (p.kind != PieceKind.porch || _esPuerta(p)) continue;
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

    test('con su hueco oscuro, que es lo que la hace una puerta', () {
      var vistas = 0;
      for (final c in TownCharacter.all) {
        for (final (name, mark, kind, cost) in _catalogue()) {
          for (final p in _show(mark, kind, cost, c).pieces) {
            if (!_esPuerta(p)) continue;
            vistas++;
            var hueco = false;
            for (final s in solidsOf(p)) {
              for (final f in s.faces) {
                for (final d in f.decals ?? const <Facet>[]) {
                  if (d.surface == Surface.hollow) hueco = true;
                }
              }
            }
            expect(hueco, isTrue, reason: '${c.region} $name: puerta ciega');
          }
        }
      }
      // Y que la prueba esté mirando algo: si un día nadie pone puertas, esto
      // pasaría en vacío y no diría nada.
      expect(vistas, greaterThan(100));
    });

    test('y el vano nunca es más ancho que alto', () {
      // Varias recetas piden hasta metro y pico de ancho para setenta de alto.
      // Con un cajón de cal daba igual; con un hueco de verdad, eso no es una
      // puerta sino un portón de garaje.
      for (final c in TownCharacter.all) {
        for (final (name, mark, kind, cost) in _catalogue()) {
          for (final p in _show(mark, kind, cost, c).pieces) {
            if (!_esPuerta(p)) continue;
            final alto = p.y1 - p.y0;
            for (final s in solidsOf(p)) {
              for (final f in s.faces) {
                for (final d in f.decals ?? const <Facet>[]) {
                  if (d.surface != Surface.hollow) continue;
                  var ancho = 0.0;
                  for (final a in d.v) {
                    for (final b in d.v) {
                      final w = math.max((a.x - b.x).abs(), (a.z - b.z).abs());
                      if (w > ancho) ancho = w;
                    }
                  }
                  expect(
                    ancho,
                    lessThanOrEqualTo(alto + 1e-6),
                    reason: '${c.region} $name: el vano es un portón',
                  );
                }
              }
            }
          }
        }
      }
    });

    test('y se abre sobre el zócalo, no enterrada en él', () {
      // Mientras la puerta era un cajón que salía por delante del zócalo daba
      // igual a qué altura empezaba: se veía el cajón. Siendo un hueco, una
      // puerta de setenta que arranca en la tierra bajo un zócalo de cuarenta
      // es una tronera de treinta.
      final hundidas = <String>[];
      for (final c in TownCharacter.all) {
        for (final (name, mark, kind, cost) in _catalogue()) {
          final town = _show(mark, kind, cost, c);
          final zocalos = [
            for (final p in town.pieces)
              if (p.kind == PieceKind.plinth) p,
          ];
          for (final p in town.pieces) {
            if (!_esPuerta(p)) continue;
            for (final z in zocalos) {
              final dentro =
                  (p.cx - z.cx).abs() <= z.w / 2 &&
                  (p.cz - z.cz).abs() <= z.d / 2;
              if (dentro && p.y0 < z.y1 - 1e-6) {
                hundidas.add(
                  '${c.region} $name: puerta en ${p.y0.toStringAsFixed(2)} '
                  'bajo un zócalo de ${z.y1.toStringAsFixed(2)}',
                );
              }
            }
          }
        }
      }
      expect(hundidas, isEmpty, reason: 'puertas enterradas: $hundidas');
    });
  });

  group('lo que no se toca al arreglarla', () {
    test('cada estructura sigue costando lo que costaba', () {
      // La tentación era borrar la puerta de las recetas. No se puede: lo que
      // `finish` pone en su lugar es repetir la pieza anterior en el mismo
      // sitio, o sea un logro que no coloca nada — y una pieza es un logro.
      for (final c in TownCharacter.all) {
        for (final (name, mark, kind, cost) in _catalogue()) {
          expect(
            _show(mark, kind, cost, c).pieces.length,
            cost,
            reason: '${c.region} $name cambió de precio',
          );
        }
      }
    });

    test('y ninguna receta rellena repitiendo la pieza anterior', () {
      // La prueba directa de lo de arriba: dos piezas iguales en el mismo
      // sitio son un día en que el pueblo no cambió.
      final mudas = <String>[];
      for (final (name, mark, kind, cost) in _catalogue()) {
        final ps = _show(mark, kind, cost, TownCharacter.all.first).pieces;
        for (var i = 1; i < ps.length; i++) {
          final a = ps[i - 1], b = ps[i];
          if (a.kind == b.kind &&
              (a.cx - b.cx).abs() < 1e-9 &&
              (a.cz - b.cz).abs() < 1e-9 &&
              (a.y0 - b.y0).abs() < 1e-9 &&
              (a.y1 - b.y1).abs() < 1e-9) {
            mudas.add('$name en la pieza $i');
          }
        }
      }
      expect(mudas, isEmpty, reason: 'logros que no colocan nada: $mudas');
    });
  });
}
