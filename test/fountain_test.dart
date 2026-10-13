import 'package:flutter_test/flutter_test.dart';
import 'package:towny/core/math3.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/fountain.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/solids.dart';
import 'package:towny/engine/town.dart';

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
    // Y se mueve: el mismo hilo, otro color un momento después.
    final luego = fountainWater(l, ojo, 0.7, Palette.forMoment(11));
    expect([
      for (final f in luego) f.tint,
    ], isNot(equals([for (final f in dia) f.tint])));
  });

  test('la fuente y el tablón echan sombra sobre la plaza', () {
    final sombras = plazaShadows(l, 0, Palette.forMoment(8));
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
}
