import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/character.dart';
import 'package:towny/data/doings.dart';
import 'package:towny/engine/folk.dart';
import 'package:towny/engine/town.dart';

/// Lo que más se puede mover alguien andando entre dos instantes.
const double _paso = 0.05;

TownLayout _town(int pieces) => TownLayout(pieces, TownCharacter.all.first);

/// Recorre la prueba de [who] desde [t0] hasta que vuelve a su ronda, y
/// devuelve en qué segundo hizo [d] por primera vez y dónde.
({double? hizo, double x, double z, double fin}) _recorre(
  Townsfolk who,
  Doing d,
  double t0,
) {
  var antes = who.at(t0);
  double? hizo;
  var x = 0.0, z = 0.0;
  var t = t0;
  while (who.trying != null && t < t0 + 900) {
    t += _paso;
    final ahora = who.at(t);
    final salto = (ahora.x - antes.x).abs() + (ahora.z - antes.z).abs();
    expect(
      salto,
      lessThan(Townsfolk.pace * _paso * 1.6 + 1e-6),
      reason: 'la prueba de ${d.id} lo hace saltar en el segundo $t',
    );
    if (hizo == null && ahora.act == d) {
      hizo = t;
      x = ahora.x;
      z = ahora.z;
    }
    antes = ahora;
  }
  return (hizo: hizo, x: x, z: z, fin: t);
}

void main() {
  test('va hasta un sitio de esa clase, lo hace, y vuelve sin saltos', () {
    final t = _town(400);
    final gente = folkOf(t, 400);
    for (final d in Doing.all) {
      final who = gente[d.id.hashCode % gente.length];
      final t0 = 1000.0 + d.id.length;
      final hay = folkTryOut(t, 400, who, d, t0);
      if (d.where != Where.water && d.where != Where.work) {
        expect(hay, isTrue, reason: '${d.id}: siempre hay plaza, prado y casa');
      }
      expect(who.trying, d);
      final r = _recorre(who, d, t0);
      expect(r.hizo, isNotNull, reason: '${d.id} no se hizo nunca');
      if (d.where == Where.door) {
        // En su puerta, que es lo suyo — o a unos palmos, si lo que lleva
        // no cabe en el umbral.
        expect(
          (r.x - who.door.$1).abs() + (r.z - who.door.$2).abs(),
          lessThan(3.6),
        );
      }
      // Y al terminar sigue con su vida, desde su puerta y sin salto.
      expect(who.trying, isNull, reason: '${d.id} no termina nunca');
      final vuelta = who.at(r.fin + _paso);
      expect(
        (vuelta.x - who.door.$1).abs() + (vuelta.z - who.door.$2).abs(),
        lessThan(0.2),
        reason: '${d.id}: al terminar no sale de su puerta',
      );
    }
  });

  test('en un pueblo sin agua lo hace donde está, y se le quita', () {
    // Sin ningún hito terminado todavía: no hay agua en todo el pueblo.
    var n = 4;
    while (folkOf(_town(n), n).isEmpty) {
      n++;
    }
    final t = _town(n);
    expect(
      t.buildings.any((b) => b.isLandmark && b.firstPiece + b.cost <= n),
      isFalse,
    );
    final gente = folkOf(t, n);
    expect(gente, isNotEmpty);
    final who = gente.first;
    final pesca = Doing.all.firstWhere((d) => d.id == 'pescar');
    final antes = who.at(500);
    expect(folkTryOut(t, n, who, pesca, 500), isFalse);
    final r = _recorre(who, pesca, 500);
    expect(r.hizo, isNotNull);
    expect((r.x - antes.x).abs() + (r.z - antes.z).abs(), lessThan(1e-6));
    expect(who.trying, isNull);
    // Ya no pesca nunca más: era una prueba.
    for (var s = 0.0; s < who.period; s += 1) {
      expect(who.at(r.fin + s).act, isNot(pesca));
    }
  });

  test('seguido por la cámara o no, termina igual de bien', () {
    final t = _town(400);
    final who = folkOf(t, 400)[3];
    final d = Doing.all.firstWhere((d) => d.id == 'cometa');
    who.spotlight(200, on: true);
    folkTryOut(t, 400, who, d, 200);
    final r = _recorre(who, d, 200);
    expect(r.hizo, isNotNull);
    who.spotlight(r.fin + 1, on: false);
    final a = who.at(r.fin + 1), b = who.at(r.fin + 1 + _paso);
    expect((a.x - b.x).abs() + (a.z - b.z).abs(), lessThan(0.1));
  });

  test('el pintor no lo pierde cuando sale de su ronda', () {
    final t = _town(400);
    final who = folkOf(t, 400)[5];
    final d = Doing.all.firstWhere((d) => d.id == 'pescar');
    folkTryOut(t, 400, who, d, 10);
    var s = 10.0;
    while (who.trying != null && s < 900) {
      final at = who.at(s);
      final r = who.reach;
      final dx = at.x - r.x, dz = at.z - r.z;
      expect(dx * dx + dz * dz, lessThan(r.r * r.r));
      s += 0.5;
    }
  });
}
