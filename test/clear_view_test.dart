import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:towny/core/math3.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/clear_view.dart';
import 'package:towny/engine/folk.dart';
import 'package:towny/engine/town.dart';

/// Si el tramo de [a] a [b] pasa por dentro de alguna pieza puesta.
bool _tapado(TownLayout l, int placed, V3 a, V3 b) {
  const pasos = 60;
  for (var k = 1; k <= pasos; k++) {
    final t = k / pasos;
    final q = a + (b - a) * t;
    if ((q - a).length < 0.3) continue;
    for (var i = 0; i < placed && i < l.pieces.length; i++) {
      final p = l.pieces[i];
      if (q.x > p.x0 &&
          q.x < p.x1 &&
          q.z > p.z0 &&
          q.z < p.z1 &&
          q.y > p.y0 &&
          q.y < p.y1) {
        return true;
      }
    }
  }
  return false;
}

void main() {
  group('la cámara que sigue a alguien', () {
    test('no se mete en un tejado ni deja una pared en medio', () {
      var antes = 0, despues = 0, vistos = 0;
      for (final (n, ch) in [(300, 0), (900, 1), (1500, 2)]) {
        final l = TownLayout(n, TownCharacter.all[ch], seed: 11);
        final talla = folkTalla(l.character);
        final gente = folkOf(l, n);
        for (var g = 0; g < gente.length; g += 3) {
          for (final t in [30.0, 90.0, 170.0]) {
            final at = folkWhere(gente[g], t, 0);
            if (at == null) continue;
            final foco = V3(at.at.x, talla * 0.6, at.at.z);
            for (var y = 0; y < 8; y++) {
              final yaw = y * math.pi / 4;
              const pitch = 0.75, quiere = 5.06;
              final cp = math.cos(pitch);
              final dir = V3(
                math.sin(yaw) * cp,
                math.sin(pitch),
                math.cos(yaw) * cp,
              );
              vistos++;
              if (_tapado(l, n, foco, foco + dir * quiere)) antes++;
              final d = clearDistance(l, n, foco, yaw, pitch, quiere);
              expect(d, lessThanOrEqualTo(quiere));
              if (d > 1.4 + 1e-9 && _tapado(l, n, foco, foco + dir * d)) {
                despues++;
              }
            }
          }
        }
      }
      // Que el caso existía, y que ya no.
      expect(antes, greaterThan(0), reason: 'la prueba no encuentra el fallo');
      expect(despues, 0, reason: '$despues de $vistos encuadres tapados');
    });

    test('con nada en medio, se queda donde quería', () {
      final l = TownLayout(0, TownCharacter.all.first, seed: 3);
      expect(clearDistance(l, 0, const V3(0, 0.5, 0), 0.4, 0.75, 5.06), 5.06);
    });
  });
}
