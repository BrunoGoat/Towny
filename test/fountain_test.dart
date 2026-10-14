import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:towny/core/math3.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/fountain.dart';
import 'package:towny/engine/fountain_birds.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/solids.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/engine/world.dart';

void main() {
  final l = TownLayout(120, TownCharacter.forSlot(0));
  final ojo = V3(l.cx + 3, 1.5, l.cz + 3);

  test('la fuente corre, y de noche más tranquila', () {
    final dia = fountainWater(l, ojo, 0, Palette.forMoment(11));
    final noche = fountainWater(l, ojo, 0, Palette.forMoment(23));
    expect(dia, isNotEmpty);
    expect(noche.length, lessThan(dia.length));
    double techo(List<dynamic> fs) => [
      for (final f in fs)
        for (final v in f.v) (v as V3).y,
    ].reduce((a, b) => a > b ? a : b);
    expect(techo(noche), lessThan(techo(dia)));
    // Y se mueve de verdad: no es la misma forma con otro color, son las
    // gotas las que están en otro sitio un momento después.
    final luego = fountainWater(l, ojo, 1 / 30, Palette.forMoment(11));
    double suma(List<dynamic> fs) {
      var t = 0.0;
      for (final f in fs) {
        for (final v in f.v) {
          t += (v as V3).y;
        }
      }
      return t;
    }

    expect((suma(luego) - suma(dia)).abs(), greaterThan(0.01));
  });

  test('el agua cae dentro de la fuente', () {
    final pozo = Plaza.poolOf(TownLayout.plazaReach);
    for (final hora in [8.0, 11.0, 17.0, 23.0]) {
      for (var t = 0.0; t < 3; t += 0.37) {
        for (final f in fountainWater(l, ojo, t, Palette.forMoment(hora))) {
          // Los pájaros vienen de fuera: esto es sólo para el agua.
          if (f.piece != waterPiece) continue;
          for (final v in f.v) {
            final dx = v.x - l.cx, dz = v.z - l.cz;
            expect(math.sqrt(dx * dx + dz * dz), lessThan(pozo + 0.02));
            // La cabeza de una gota que está entrando puede asomar por debajo
            // del agua: ahí la tapa el agua misma.
            expect(v.y, greaterThan(Plaza.poolLevel - 0.03));
          }
        }
      }
    }
  });

  test('la fuente y el tablón echan sombra sobre la plaza', () {
    final sombras = plazaShadows(
      l,
      0,
      Palette.forMoment(8),
      builtTown(l, 0).casters,
    );
    expect(sombras, isNotEmpty);
    final r = TownLayout.plazaReach;
    for (final f in sombras) {
      for (final v in f.v) {
        final dx = v.x - l.cx, dz = v.z - l.cz;
        // Dentro de la plaza y pegadas a su suelo.
        expect(dx * dx + dz * dz, lessThanOrEqualTo(r * r * 1.01));
        expect(v.y, greaterThan(Plaza.lawnTop));
        expect(v.y, lessThan(Plaza.kerbTop + 0.03));
      }
    }
  });

  group('los pájaros de la fuente', () {
    test('vienen cada tanto, se posan en el brocal y se van', () {
      final taza = Plaza.basinOf(TownLayout.plazaReach) / 1.14;
      var posados = 0, fuera = 0, todo = 0;
      final hechos = <BirdDoing>{};
      for (var t = 0.0; t < 1800; t += 0.5) {
        for (var k = 0; k < fountainBirdSlots; k++) {
          final v = birdVisit(l, k, t);
          hechos.add(v.doing);
          todo++;
          if (v.doing == BirdDoing.away) {
            fuera++;
            continue;
          }
          if (v.doing != BirdDoing.perched) continue;
          posados++;
          // En el brocal, entre el agua y el canto de fuera.
          final dx = v.at.x - l.cx, dz = v.at.z - l.cz;
          final r = math.sqrt(dx * dx + dz * dz);
          expect(r, greaterThan(taza * 0.80));
          expect(r, lessThan(taza));
          expect(v.at.y, greaterThanOrEqualTo(0.40));
        }
      }
      expect(hechos, containsAll(BirdDoing.values));
      // Cada tanto, no siempre.
      expect(posados, greaterThan(0));
      expect(fuera, greaterThan(0));
      expect(posados, lessThan(todo * 0.5));
    });

    test('de noche duermen', () {
      for (var t = 0.0; t < 600; t += 1) {
        for (var k = 0; k < fountainBirdSlots; k++) {
          expect(birdVisit(l, k, t, day: false).doing, BirdDoing.away);
        }
      }
    });

    test('van y vienen sin saltos de un fotograma al siguiente', () {
      for (var t = 0.0; t < 900; t += 1 / 30) {
        for (var k = 0; k < fountainBirdSlots; k++) {
          final a = birdVisit(l, k, t), b = birdVisit(l, k, t + 1 / 30);
          if (a.doing == BirdDoing.away || b.doing == BirdDoing.away) continue;
          // El cambio de vuelta: el que se fue ya está lejísimos, y el que
          // llega es otra visita.
          if (a.doing == BirdDoing.leaving && b.doing == BirdDoing.arriving) {
            continue;
          }
          expect((a.at - b.at).length, lessThan(0.2), reason: 'a los $t s');
        }
      }
    });

    test(
      'despacio: visitas espaciadas, sorbos lentos, y se van hacia arriba',
      () {
        // Unas cuarenta visitas por hora en toda la plaza: un tercio de las que
        // había, que eran demasiadas para una plaza tranquila.
        var visitas = 0;
        final antes = List.filled(fountainBirdSlots, BirdDoing.away);
        for (var t = 0.0; t < 3600; t += 0.5) {
          for (var k = 0; k < fountainBirdSlots; k++) {
            final d = birdVisit(l, k, t).doing;
            if (d == BirdDoing.arriving && antes[k] != BirdDoing.arriving) {
              visitas++;
            }
            antes[k] = d;
          }
        }
        expect(visitas, inInclusiveRange(20, 60));

        var lejos = double.infinity;
        for (var t = 0.0; t < 900; t += 1 / 30) {
          for (var k = 0; k < fountainBirdSlots; k++) {
            final a = birdVisit(l, k, t), b = birdVisit(l, k, t + 1 / 30);
            if (a.doing == BirdDoing.perched && b.doing == BirdDoing.perched) {
              // El pico no sube y baja a golpes.
              expect((a.pitch - b.pitch).abs(), lessThan(0.09));
            }
            if (a.doing == BirdDoing.leaving && b.doing != BirdDoing.leaving) {
              final dx = a.at.x - l.cx, dz = a.at.z - l.cz;
              lejos = math.min(
                lejos,
                math.sqrt(dx * dx + a.at.y * a.at.y + dz * dz),
              );
            }
          }
        }
        // No se desvanece a la vista: cuando deja de existir está a decenas
        // de metros, en diagonal, lejos de cualquier cuadro.
        expect(lejos, greaterThan(40));
      },
    );
  });
}
