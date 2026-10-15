import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/folk.dart';
import 'package:towny/engine/town.dart';

/// Si el punto cae dentro de alguna pieza que llega al suelo, con un palmo
/// de tolerancia por el ancho del cuerpo.
bool _dentro(TownLayout t, int placed, double x, double z) {
  for (var i = 0; i < math.min(placed, t.pieces.length); i++) {
    final p = t.pieces[i];
    if (p.y0 > 0.95) continue;
    if (x > p.x0 + 0.05 &&
        x < p.x1 - 0.05 &&
        z > p.z0 + 0.05 &&
        z < p.z1 - 0.05) {
      return true;
    }
  }
  return false;
}

/// Una tarde entera en [segundos], de pleno día a noche cerrada.
double _tarde(double s, double segundos) => (s / segundos).clamp(0.0, 1.0);

void main() {
  test('al caer la tarde vuelven a casa por la calle, no por las paredes', () {
    // Esto es lo que se vio: alguien yendo a su puerta en línea recta y
    // cruzando una casa de lado a lado.
    for (final c in TownCharacter.all) {
      for (final placed in [4, 12, 60, 300]) {
        final t = TownLayout(placed, c);
        final gente = folkOf(t, placed).where((v) => !v.sage);
        const dura = 300.0, paso = 0.1;
        for (final w in gente) {
          // De día primero, para que se le haya visto antes de la tarde.
          expect(folkWhere(w, 0, 0), isNotNull);
          (double, double)? antes;
          for (var s = paso; s <= dura + 60; s += paso) {
            final d = folkWhere(w, s, _tarde(s, dura));
            if (d == null) {
              antes = null;
              continue;
            }
            final a = d.at;
            expect(
              _dentro(t, placed, a.x, a.z),
              isFalse,
              reason:
                  '${c.region} $placed: ${w.name} cruza una pared '
                  'volviendo a casa en el segundo $s',
            );
            if (antes != null) {
              final salto = (a.x - antes.$1).abs() + (a.z - antes.$2).abs();
              expect(
                salto,
                lessThan(Townsfolk.pace * paso * 1.6 + 1e-6),
                reason: '${c.region} $placed: ${w.name} salta en el segundo $s',
              );
            }
            antes = (a.x, a.z);
          }
          // Y de noche cerrada, todos dentro.
          expect(folkWhere(w, dura + 400, 1.0), isNull);
        }
      }
    }
  });

  test('no se van todos a la vez', () {
    final t = TownLayout(300, TownCharacter.all.first);
    final gente = folkOf(t, 300).where((v) => !v.sage).toList();
    // A media tarde, unos ya están en casa y otros todavía no.
    for (final w in gente) {
      folkWhere(w, 0, 0);
    }
    var dentro = 0;
    for (var s = 0.0; s < 200; s += 0.5) {
      for (final w in gente) {
        folkWhere(w, s, 0.4);
      }
    }
    for (final w in gente) {
      if (folkWhere(w, 200, 0.4) == null) dentro++;
    }
    expect(dentro, greaterThan(0));
    expect(dentro, lessThan(gente.length));
  });

  test('de mañana salen por su puerta y siguen sin saltos', () {
    final t = TownLayout(300, TownCharacter.all.first);
    final w = folkOf(t, 300)[2];
    folkWhere(w, 0, 0);
    expect(folkWhere(w, 10, 1.0), isNull);
    final sale = folkWhere(w, 20, 0)!;
    expect(
      (sale.at.x - w.door.$1).abs() + (sale.at.z - w.door.$2).abs(),
      lessThan(0.2),
    );
    expect(sale.sink, greaterThan(0.5));
    var antes = sale.at;
    for (var s = 20.05; s < 80; s += 0.05) {
      final a = folkWhere(w, s, 0)!.at;
      expect((a.x - antes.x).abs() + (a.z - antes.z).abs(), lessThan(0.1));
      antes = a;
    }
  });

  test('quien se ve por primera vez de noche ya está en casa', () {
    // Otro pueblo, para que nadie lo haya visto en las pruebas de antes.
    final t = TownLayout(300, TownCharacter.all.first, seed: 4242);
    final w = folkOf(t, 300)[7];
    expect(folkWhere(w, 5, 0.95), isNull);
  });
}
