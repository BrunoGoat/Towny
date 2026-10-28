import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/character.dart';
import 'package:towny/data/doings.dart';
import 'package:towny/engine/folk.dart';
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

  test(
    'no queda nada fijo en el pueblo: ni tendedero, ni tocón, ni puesto',
    () {
      // Se sacaron a pedido, con lo que se hacía con ellos.
      const fuera = {
        'tender',
        'lena',
        'gallinas',
        'puesto',
        'malabares',
        'comba',
        'barquito',
        'pozo',
        'lavar',
        'cantero',
        'serrar',
        'carretilla',
        'segar',
        'flores',
      };
      for (final d in Doing.all) {
        expect(fuera, isNot(contains(d.id)), reason: d.nameEs);
      }
      for (final l in pueblos) {
        for (final w in folkOf(l, n)) {
          for (var t = 0.0; t < w.period; t += 2) {
            final d = w.at(t).act;
            if (d == null) continue;
            expect(
              fuera,
              isNot(contains(d.id)),
              reason: '${w.name} ${d.nameEs}',
            );
          }
        }
      }
    },
  );

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
}
