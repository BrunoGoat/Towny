import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/core/math3.dart';
import 'package:la_muralla/core/rng.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/solid.dart';
import 'package:la_muralla/engine/solids.dart';
import 'package:la_muralla/engine/town.dart';

String _k(V3 p) =>
    '${p.x.toStringAsFixed(6)},${p.y.toStringAsFixed(6)},${p.z.toStringAsFixed(6)}';

/// Si este sólido está cerrado: cada arista recorrida dos veces, una en cada
/// sentido. Es lo mismo que exige `depth_test` de todo lo que se construye, y
/// por el mismo motivo: en una cáscara, descartar las caras traseras deja un
/// agujero por el que se ve la hierba.
bool _closed(Solid s) {
  final edges = <String, int>{};
  for (final f in s.faces) {
    for (var i = 0; i < f.v.length; i++) {
      final a = f.v[i], b = f.v[(i + 1) % f.v.length];
      edges['${_k(a)}|${_k(b)}'] = (edges['${_k(a)}|${_k(b)}'] ?? 0) + 1;
    }
  }
  for (final e in edges.entries) {
    final p = e.key.split('|');
    if (e.value != 1 || edges['${p[1]}|${p[0]}'] != 1) return false;
  }
  return true;
}

double _far(double x, double z, double cx, double cz) =>
    math.sqrt((x - cx) * (x - cx) + (z - cz) * (z - cz));

void main() {
  group('la plaza queda despejada', () {
    test('ningún edificio mete la huella dentro, en ninguna región', () {
      // Lo que se veía: el tablón es lo más importante del pueblo y también lo
      // más pequeño, así que en cuanto había diez casas quedaba escondido
      // entre ellas y había que orbitar buscándolo.
      final dentro = <String>[];
      for (final c in TownCharacter.all) {
        for (var k = 0; k < 8; k++) {
          for (final n in [3, 20, 120, 600]) {
            final t = TownLayout(n, c, seed: hashText('h$k'));
            for (final b in t.buildings) {
              final d = _far(b.cx, b.cz, t.cx, t.cz);
              if (d - b.reach * 0.72 < TownLayout.plazaReach - 1e-9) {
                dentro.add(
                  '${c.region}/$k/$n ${b.name} a '
                  '${d.toStringAsFixed(2)} con alcance '
                  '${b.reach.toStringAsFixed(2)}',
                );
              }
            }
          }
        }
      }
      expect(dentro, isEmpty, reason: 'se plantaron en la plaza: $dentro');
    });

    test('ni la huerta ni el árbol de la casa de al lado', () {
      // La huerta y el árbol se plantan mirando sólo a su propia casa, así que
      // una parcela que da a la plaza le echaba el manzano dentro aunque la
      // casa respetara el claro.
      final dentro = <String>[];
      for (final c in TownCharacter.all) {
        for (var k = 0; k < 6; k++) {
          final t = TownLayout(300, c, seed: hashText('h$k'));
          for (final b in t.buildings) {
            if (b.yardSize > 0 &&
                _far(b.yardX, b.yardZ, t.cx, t.cz) - b.yardSize / 2 <
                    TownLayout.plazaReach) {
              dentro.add('${c.region}/$k huerta de ${b.index}');
            }
            if (b.treeSize > 0 &&
                _far(b.treeX, b.treeZ, t.cx, t.cz) - b.treeSize * 0.6 <
                    TownLayout.plazaReach) {
              dentro.add('${c.region}/$k árbol de ${b.index}');
            }
          }
        }
      }
      expect(dentro, isEmpty, reason: 'plantado en la plaza: $dentro');
    });

    test('y el pueblo sigue siendo un pueblo, no un anillo', () {
      // El claro empuja los solares hacia afuera, y si empujara de más lo que
      // quedaría es un pueblo con un agujero en el medio. Las primeras casas
      // tienen que seguir dando a la plaza.
      for (final c in TownCharacter.all) {
        final t = TownLayout(120, c, seed: hashText('hA'));
        final primera = _far(
          t.buildings.first.cx,
          t.buildings.first.cz,
          t.cx,
          t.cz,
        );
        expect(
          primera,
          lessThan(TownLayout.plazaReach + 3.2),
          reason: '${c.region}: la primera casa quedó lejísimos',
        );
      }
    });

    test('el tablón y el atril caben en ella y quedan lejos uno de otro', () {
      final t = TownLayout(10, TownCharacter.all.first);
      // Los dos, enteros dentro del enlosado.
      for (final v in [
        ...NoticeBoard.faceAt(t.cx, t.cz),
        ...Lectern.faceAt(t.cx, t.cz),
      ]) {
        expect(_far(v.x, v.z, t.cx, t.cz), lessThan(TownLayout.plazaReach));
      }
      // Y a lados opuestos de la fuente, no pegados: juntos se leían como un
      // solo mueble de dos partes.
      final entre = _far(
        Lectern.xAt(t.cx),
        Lectern.zAt(t.cz),
        NoticeBoard.xAt(t.cx),
        NoticeBoard.zAt(t.cz),
      );
      expect(entre, greaterThan(TownLayout.plazaReach * 0.9));
      // Cada uno fuera del pilón, que está en medio.
      final pilon = Plaza.basinOf(TownLayout.plazaReach);
      expect(
        _far(NoticeBoard.xAt(t.cx), NoticeBoard.zAt(t.cz), t.cx, t.cz),
        greaterThan(pilon + NoticeBoard.reach),
      );
      expect(
        _far(Lectern.xAt(t.cx), Lectern.zAt(t.cz), t.cx, t.cz),
        greaterThan(pilon + 0.3),
      );
    });
  });

  group('el tablón y el atril miran a la fuente', () {
    /// Hacia dónde mira la cara que se lee, sacada de sus propias esquinas.
    V3 mira(List<V3> cara, double x, double z) =>
        Facet.normalOf(cara, away: V3(x, 0.6, z));

    test('los dos, y no cada uno para su lado', () {
      final t = TownLayout(10, TownCharacter.all.first);
      for (final (nombre, cara, x, z) in [
        (
          'el tablón',
          NoticeBoard.faceAt(t.cx, t.cz),
          NoticeBoard.xAt(t.cx),
          NoticeBoard.zAt(t.cz),
        ),
        (
          'el atril',
          Lectern.faceAt(t.cx, t.cz),
          Lectern.xAt(t.cx),
          Lectern.zAt(t.cz),
        ),
      ]) {
        final n = mira(cara, x, z);
        // Hacia la fuente, normalizado y en el plano.
        final dx = t.cx - x, dz = t.cz - z;
        final d = math.sqrt(dx * dx + dz * dz);
        final coseno = (n.x * dx / d + n.z * dz / d) / math.sqrt(1 - n.y * n.y);
        expect(
          coseno,
          greaterThan(0.86),
          reason: '$nombre está vuelto a otra parte',
        );
      }
    });

    test('y girar el mueble no deja las caras mintiendo sobre su plano', () {
      // Lo que se rompe callando si se giran los vértices y se deja la normal
      // quieta: la normal deja de ser perpendicular a su propia cara y deja de
      // mirar hacia afuera. De eso cuelgan el descarte de caras traseras y el
      // orden de pintado entero, así que no es un detalle de sombreado.
      for (final partes in [
        NoticeBoard.solidsAt(4, -3),
        Lectern.solidsAt(4, -3),
      ]) {
        for (final s in partes) {
          var mx = 0.0, my = 0.0, mz = 0.0, n = 0;
          for (final f in s.faces) {
            for (final v in f.v) {
              mx += v.x;
              my += v.y;
              mz += v.z;
              n++;
            }
          }
          final cx = mx / n, cy = my / n, cz = mz / n;
          for (final f in s.faces) {
            // Perpendicular a su propio plano: con dos aristas de la cara
            // basta, y las dos tienen que dar cero contra la normal.
            for (var i = 0; i < f.v.length; i++) {
              final a = f.v[i], b = f.v[(i + 1) % f.v.length];
              final e = b - a;
              final largo = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
              if (largo < 1e-9) continue;
              final d = (f.n.x * e.x + f.n.y * e.y + f.n.z * e.z) / largo;
              expect(d.abs(), lessThan(1e-6), reason: 'normal torcida');
            }
            // Y mirando hacia afuera, que en un sólido convexo es esto.
            var fx = 0.0, fy = 0.0, fz = 0.0;
            for (final v in f.v) {
              fx += v.x;
              fy += v.y;
              fz += v.z;
            }
            final k = f.v.length;
            final fuera =
                f.n.x * (fx / k - cx) +
                f.n.y * (fy / k - cy) +
                f.n.z * (fz / k - cz);
            expect(fuera, greaterThan(0), reason: 'normal del revés');
          }
        }
      }
    });
  });

  group('los muebles de la plaza son sólidos cerrados', () {
    test('el enlosado', () {
      for (final s in Plaza.solidsAt(3, -2, TownLayout.plazaReach)) {
        expect(_closed(s), isTrue, reason: 'el enlosado es una cáscara');
      }
    });

    test('el atril, pieza por pieza', () {
      final partes = Lectern.solidsAt(3, -2);
      expect(partes.length, greaterThan(4), reason: 'un atril no es un palo');
      for (var i = 0; i < partes.length; i++) {
        expect(_closed(partes[i]), isTrue, reason: 'la parte $i está abierta');
      }
    });

    test('y el libro se apoya en el tablero, no flota', () {
      // La cara que se toca es la de arriba del libro, y tiene que estar justo
      // encima del atril: si se despega, el dedo apunta al aire.
      final cara = Lectern.faceAt(0, 0);
      var bajo = double.infinity, alto = -double.infinity;
      for (final s in Lectern.solidsAt(0, 0)) {
        for (final f in s.faces) {
          for (final v in f.v) {
            if (v.y < bajo) bajo = v.y;
            if (v.y > alto) alto = v.y;
          }
        }
      }
      expect(bajo, lessThan(0.06), reason: 'el atril no llega al suelo');
      for (final v in cara) {
        expect(v.y, lessThanOrEqualTo(alto + 1e-9));
      }
      // Y es un facistol de plaza: **más chico que el tablón, y a la vista**.
      // Son las dos condiciones y no una — a estatura de persona era un mueble
      // enorme, y a la mitad de eso se quedaba corto.
      expect(alto, greaterThan(0.55), reason: 'no se ve');
      expect(
        alto,
        lessThan(NoticeBoard.high * 0.75),
        reason: 'le hace sombra al tablón',
      );
    });

    test('la plaza es un ejido de hierba con el bordillo de piedra', () {
      // Al revés de como empezó: un disco de piedra con cuatro lunares verdes
      // se leía como un pavimento con desperfectos.
      const r = TownLayout.plazaReach;
      final partes = Plaza.solidsAt(0, 0, r);
      var hierbaHasta = 0.0, piedraDesde = double.infinity;
      for (final s in partes) {
        for (final f in s.faces) {
          if (f.n.y < 0.9) continue;
          for (final v in f.v) {
            final d = math.sqrt(v.x * v.x + v.z * v.z);
            // La fuente no es suelo: tiene su propio escalón de piedra en
            // medio y no es eso lo que se está midiendo.
            if (v.y > 0.2) continue;
            if (d < Plaza.basinOf(r) * 1.05) continue;
            if (f.surface == Surface.leaf && d > hierbaHasta) hierbaHasta = d;
            if (f.surface == Surface.stone && d < piedraDesde) piedraDesde = d;
          }
        }
      }
      // Hierba en el medio y hasta cerca del borde…
      expect(hierbaHasta, greaterThan(r * 0.85));
      // …y la piedra sólo a partir de ahí: un anillo, no un disco debajo.
      expect(piedraDesde, greaterThan(r * 0.85));
      // Y el bordillo llega al borde de verdad.
      var piedraHasta = 0.0;
      for (final s in partes) {
        for (final f in s.faces) {
          if (f.surface != Surface.stone) continue;
          for (final v in f.v) {
            final d = math.sqrt(v.x * v.x + v.z * v.z);
            if (v.y < 0.2 && d > piedraHasta) piedraHasta = d;
          }
        }
      }
      expect(piedraHasta, closeTo(r, 0.001));
    });

    test('y la fuente tiene agua a la vista, no debajo de la piedra', () {
      // El brocal empezó siendo un bloque macizo con el agua dentro, que es un
      // bloque macizo: el agua estaba en la geometría y no se veía desde
      // ningún ángulo. Por eso es un anillo.
      final partes = Plaza.solidsAt(0, 0, TownLayout.plazaReach);
      var techo = -1.0, aguaY = -1.0;
      for (final s in partes) {
        for (final f in s.faces) {
          final esAgua = f.tint == 0xFF3F7C86;
          for (final v in f.v) {
            if (esAgua && v.y > aguaY) aguaY = v.y;
          }
        }
      }
      expect(aguaY, greaterThan(0), reason: 'no hay agua en la fuente');
      // Nada de piedra tapa el agua por arriba dentro del radio del pilón.
      final dentro = Plaza.basinOf(TownLayout.plazaReach) * 0.6;
      for (final s in partes) {
        for (final f in s.faces) {
          if (f.tint == 0xFF3F7C86) continue;
          if (f.n.y < 0.9) continue;
          for (final v in f.v) {
            if (math.sqrt(v.x * v.x + v.z * v.z) < dentro && v.y > aguaY) {
              techo = v.y;
            }
          }
        }
      }
      // Sólo el pilar del caño, que sale del agua hacia arriba y es lo que se
      // ve de lejos; nada que sea una tapa sobre el agua.
      expect(
        techo < 0 || techo > aguaY + 0.3,
        isTrue,
        reason: 'hay piedra tapando el agua a $techo',
      );
    });
  });
}
