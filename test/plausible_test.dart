import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/character.dart';
import 'package:towny/data/doings.dart';
import 'package:towny/engine/folk.dart';
import 'package:towny/engine/solids.dart';
import 'package:towny/engine/town.dart';

/// La regla de lo plausible: lo que se saca tiene que poder llevarse encima.
/// Nada grande ni vivo aparece de la nada: o ya está en el pueblo, fijo en su
/// sitio, o se saca de casa y se vuelve a guardar.
void main() {
  const n = 400;
  final pueblos = [
    for (var seed = 0; seed < 4; seed++)
      TownLayout(n, TownCharacter.all[seed], seed: seed * 101),
  ];

  bool hayFijo(TownLayout l, Doing d, double x, double z) =>
      folkFixtures(l, n).any(
        (f) =>
            f.doing.prop == d.prop &&
            (f.x - x).abs() < 0.3 &&
            (f.z - z).abs() < 0.3,
      );

  test('lo que vive en su sitio está donde se usa, y sólo ahí', () {
    var usos = 0;
    for (final l in pueblos) {
      expect(folkFixtures(l, n), isNotEmpty);
      for (final w in folkOf(l, n)) {
        if (w.sage) continue;
        for (var t = 0.0; t < w.period; t += 0.5) {
          final a = w.at(t);
          final d = a.act;
          if (d == null || !d.anchored) continue;
          usos++;
          expect(
            hayFijo(l, d, a.x, a.z),
            isTrue,
            reason:
                '${w.name} ${d.nameEs} en (${a.x.toStringAsFixed(1)}, '
                '${a.z.toStringAsFixed(1)}) y ahí no hay nada de eso',
          );
          expect(a.fixed, isFalse);
        }
      }
    }
    expect(usos, greaterThan(50), reason: 'nadie usa lo que vive en su sitio');
  });

  test('y siguiéndolo con la cámara, tampoco aparece en otro sitio', () {
    for (final l in pueblos.take(2)) {
      for (final w in folkOf(l, n).where((w) => !w.sage).take(30)) {
        w.spotlight(10, on: true);
        for (var t = 10.0; t < 10 + 400; t += 0.5) {
          final a = w.at(t);
          final d = a.act;
          if (d == null || !d.anchored) continue;
          expect(
            hayFijo(l, d, a.x, a.z),
            isTrue,
            reason: '${w.name} ${d.nameEs} siguiéndolo, donde no hay',
          );
        }
        w.spotlight(410, on: false);
      }
    }
  });

  test('lo que se saca de casa se lleva, se usa y se vuelve a guardar', () {
    var vistos = 0, puerta = 0;
    for (final l in pueblos) {
      for (final w in folkOf(l, n)) {
        if (w.sage) continue;
        var antes = w.at(0);
        for (var t = 0.1; t < w.period; t += 0.1) {
          final a = w.at(t);
          final d = a.act;
          final empieza = d != null && d.fetched && antes.act != d;
          final termina =
              antes.act != null && antes.act!.fetched && d != antes.act;
          // Justo antes de ponerse, lo tenía en las manos; justo después de
          // terminar, lo vuelve a tener.
          if (empieza) {
            vistos++;
            expect(
              antes.carry,
              d.prop,
              reason: '${w.name} se pone a ${d.nameEs} sin haberlo traído',
            );
          }
          if (termina) {
            expect(
              a.carry,
              antes.act!.prop,
              reason: '${w.name} deja ${antes.act!.nameEs} tirado',
            );
          }
          // Y se mete en casa a por ello o a dejarlo.
          if (a.sink > 0.5) puerta++;
          antes = a;
        }
      }
    }
    expect(vistos, greaterThan(5), reason: 'nadie saca nada de casa');
    expect(puerta, greaterThan(0), reason: 'nadie entra en casa de día');
  });

  test('lo que se trae no se esfuma: se usa o se guarda en casa', () {
    for (final l in pueblos) {
      for (final w in folkOf(l, n)) {
        if (w.sage) continue;
        var antes = w.at(0);
        for (var t = 0.1; t < w.period * 1.05; t += 0.1) {
          final a = w.at(t);
          if (antes.carry != null && a.carry == null) {
            // Se le va de las manos sólo para usarlo, o metiéndose en casa.
            expect(
              (a.act?.fetched ?? false) || a.sink > 0 || antes.sink > 0,
              isTrue,
              reason:
                  '${w.name} deja de llevar ${antes.carry!.name} en medio '
                  'de la calle',
            );
          }
          if (antes.carry == null && a.carry != null) {
            // Y le aparece en las manos sólo al dejar de usarlo, o saliendo
            // de casa.
            expect(
              (antes.act?.fetched ?? false) || a.sink > 0 || antes.sink > 0,
              isTrue,
              reason: '${w.name} saca ${a.carry!.name} de la nada',
            );
          }
          antes = a;
        }
      }
    }
  });

  test('el barco de papel, sólo asomado a la fuente de la plaza', () {
    var barcos = 0;
    for (var seed = 0; seed < 10; seed++) {
      final l = TownLayout(n, TownCharacter.all.first, seed: seed * 101);
      for (final w in folkOf(l, n)) {
        for (var t = 0.0; t < w.period; t += 1) {
          final a = w.at(t);
          if (a.act?.prop != PropKind.boat) continue;
          barcos++;
          final dx = l.cx - a.x, dz = l.cz - a.z;
          final r = math.sqrt(dx * dx + dz * dz);
          expect(
            r,
            lessThan(Plaza.basinOf(TownLayout.plazaReach) + 1.2),
            reason: 'un barco de papel lejos del agua',
          );
          var giro = (math.atan2(dx, dz) - a.heading) % (2 * math.pi);
          if (giro > math.pi) giro -= 2 * math.pi;
          expect(giro.abs(), lessThan(0.6), reason: 'de espaldas al pilón');
        }
      }
    }
    expect(barcos, greaterThan(0));
  });

  test('un puesto por plaza', () {
    for (final l in pueblos) {
      final puestos = folkFixtures(
        l,
        n,
      ).where((f) => f.doing.prop == PropKind.stall).length;
      expect(puestos, lessThanOrEqualTo(1));
    }
  });
}
