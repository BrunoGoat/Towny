import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:towny/core/rng.dart';
import 'package:towny/data/character.dart';
import 'package:towny/data/landmarks.dart';
import 'package:towny/engine/mason.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/model/habit.dart';

/// Los hitos que un pueblo levanta, en orden, sin crónica escrita: o sea, lo
/// que decidiría hoy un pueblo recién fundado.
List<String> road(
  TownCharacter c,
  int howMany, {
  List<String> from = const [],
}) {
  final out = <String>[];
  for (final w in TownPlan.of(c).walk(from)) {
    final mark = w.landmark;
    if (mark != null) out.add(mark.id);
    if (out.length >= howMany) break;
  }
  return out;
}

void main() {
  group('one achievement is one piece', () {
    test('n achievements produce n pieces, plus one ghost for the next', () {
      for (final n in [0, 1, 7, 30, 200, 900]) {
        expect(
          TownLayout(n, TownCharacter.all.first).pieces.length,
          n + 1,
          reason: 'with $n placed',
        );
      }
    });

    test('a piece laid today is in the same place tomorrow', () {
      final now = TownLayout(140, TownCharacter.all.first);
      final later = TownLayout(900, TownCharacter.all.first);
      for (var i = 0; i < now.pieces.length - 1; i++) {
        final a = now.pieces[i], b = later.pieces[i];
        expect(b.kind, a.kind, reason: 'piece $i changed kind');
        expect(b.cx, closeTo(a.cx, 1e-9), reason: 'piece $i moved');
        expect(b.cz, closeTo(a.cz, 1e-9), reason: 'piece $i moved');
        expect(b.y0, closeTo(a.y0, 1e-9), reason: 'piece $i moved');
        expect(b.y1, closeTo(a.y1, 1e-9), reason: 'piece $i moved');
        expect(b.building, a.building, reason: 'piece $i changed house');
      }
    });

    test('the same town is rebuilt exactly the same way', () {
      final a = TownLayout(333, TownCharacter.all.first),
          b = TownLayout(333, TownCharacter.all.first);
      for (var i = 0; i < a.pieces.length; i++) {
        expect(b.pieces[i].cx, a.pieces[i].cx);
        expect(b.pieces[i].y1, a.pieces[i].y1);
      }
    });
  });

  group('the buildings', () {
    test('every finished building cost exactly what the plan says', () {
      final city = TownLayout(900, TownCharacter.all.first);
      for (final b in city.buildings) {
        if (!b.finished) continue;
        final mine = city.pieces.where((p) => p.building == b.index).length;
        expect(mine, b.cost, reason: '${b.name} #${b.index}');
      }
    });

    test('a house is built from the ground up, with nothing left floating', () {
      final city = TownLayout(900, TownCharacter.all.first);
      for (final b in city.buildings) {
        final mine = city.pieces.where((p) => p.building == b.index).toList();
        if (mine.isEmpty) continue;
        // Something has to touch the ground, and every piece above it has to
        // stand on something already built rather than hang in the air. Water
        // and ploughed rows are cut into the ground, so they sit below it.
        expect(
          mine.map((p) => p.y0).reduce(math.min),
          lessThan(0.001),
          reason: '${b.name} floats',
        );
        final tops = <double>[0];
        for (final p in mine) {
          final rests = tops.any((t) => (p.y0 - t).abs() < 0.02 || p.y0 < t);
          expect(
            rests,
            isTrue,
            reason: '${b.name}: a ${p.kind.name} hangs at ${p.y0}',
          );
          tops.add(p.y1);
        }
      }
    });

    test('the piece that has not been laid yet counts for nothing', () {
      // The town always builds one piece more than has been earned, to show
      // the ghost of what is coming. Counting it as built gave a plot its yard
      // and a wall the roof that covers it a whole achievement early — which
      // is exactly the thing this app must never do.
      for (final n in [0, 1, 5, 8, 40, 300]) {
        final town = TownLayout(n, TownCharacter.all.first);
        var built = 0;
        for (final b in town.buildings) {
          built += b.placedPieces;
        }
        expect(built, n, reason: '$n placed');
      }
    });

    test('nothing is stacked on top of a roof', () {
      // The way a house goes wrong is the last piece landing above the ridge:
      // a door or a clock face left hanging over the tiles. Only a chimney is
      // allowed to come out through a roof.
      //
      // Y una torre, que no está encima del tejado sino que lo atraviesa: el
      // campanario de una iglesia o el cimborrio de una catedral nacen del
      // suelo y salen por las tejas, y lo que llevan arriba se apoya en la
      // torre. Lo que no vale es lo que no tiene debajo una columna que suba
      // desde más abajo del tejado hasta donde empieza.
      //
      // En todas las obras y todas las comarcas, y no en un pueblo de prueba:
      // así se probaba sólo lo que ese pueblo llegaba a levantar, y al cambiar
      // el orden de las obras aparecieron dos que nunca se habían mirado.
      const caps = {PieceKind.roof, PieceKind.spire};
      const crowns = {
        PieceKind.chimney,
        PieceKind.sail,
        PieceKind.banner,
        PieceKind.dome,
        PieceKind.spire,
      };
      bool over(TownPiece a, TownPiece b) =>
          (a.cx - b.cx).abs() < (a.w + b.w) * 0.4 &&
          (a.cz - b.cz).abs() < (a.d + b.d) * 0.4;
      void revisar(String name, List<TownPiece> mine) {
        for (final p in mine) {
          if (caps.contains(p.kind) || crowns.contains(p.kind)) continue;
          for (final cap in mine) {
            if (!caps.contains(cap.kind) || !over(p, cap)) continue;
            if (p.y0 < cap.y1 - 0.01) continue;
            // Bajando por la columna, pieza a pieza: un campanario es la
            // torre y encima los arcos, y los arcos se apoyan en la torre.
            bool sostenida(TownPiece x, int hondo) => mine.any(
              (q) =>
                  q != x &&
                  !caps.contains(q.kind) &&
                  over(x, q) &&
                  q.y0 < x.y0 - 0.01 &&
                  q.y1 >= x.y0 - 0.01 &&
                  (q.y0 <= cap.y0 + 0.01 ||
                      (hondo < 6 && sostenida(q, hondo + 1))),
            );
            expect(
              sostenida(p, 0),
              isTrue,
              reason: '$name: a ${p.kind.name} sits on the roof',
            );
          }
        }
      }

      final city = TownLayout(900, TownCharacter.all.first);
      for (final b in city.buildings) {
        revisar(
          b.name,
          city.pieces.where((p) => p.building == b.index).toList(),
        );
      }
      for (final mark in landmarks) {
        for (final c in TownCharacter.all) {
          final l = TownLayout.showcase(c, landmark: mark, placed: mark.cost);
          revisar('${mark.id} en ${c.region}', l.pieces);
        }
      }
    });

    test('no two houses are built on the same plot', () {
      final city = TownLayout(900, TownCharacter.all.first);
      final seen = <String>{};
      for (final b in city.buildings) {
        expect(
          seen.add('${b.cx.toStringAsFixed(3)},${b.cz.toStringAsFixed(3)}'),
          isTrue,
          reason: 'two houses on the same plot',
        );
      }
    });

    test('a year of use meets several different landmarks', () {
      final city = TownLayout(900, TownCharacter.all.first);
      final names = city.buildings
          .where((b) => b.isLandmark && b.finished)
          .map((b) => b.name)
          .toList();
      expect(
        names.length,
        greaterThanOrEqualTo(8),
        reason: 'a year should meet a good handful of landmarks',
      );
      expect(
        names.toSet().length,
        names.length,
        reason: 'and not the same one twice: \$names',
      );
    });
  });

  group('the town keeps its shape', () {
    test('it grows outward from the middle, never as a single line', () {
      // Se mide el reparto de todo el pueblo y no la casa más lejana: con
      // ocho casas, la más lejana es una sola casa y dice más del azar que de
      // la forma. Y se mide en treinta pueblos distintos y no en uno, que es
      // lo que hace falta desde que cada pueblo siembra sus propios solares:
      // que el único que había saliera redondo no probaba nada.
      for (final n in [30, 200, 900]) {
        for (var k = 0; k < 30; k++) {
          final city = TownLayout(
            n,
            TownCharacter.all.first,
            seed: hashText('h\$k'),
          );
          var sx = 0.0, sz = 0.0;
          for (final b in city.buildings) {
            sx += b.cx * b.cx;
            sz += b.cz * b.cz;
          }
          final ratio = math.sqrt(sx / math.max(sz, 1e-9));
          expect(ratio, greaterThan(0.5), reason: 'with \$n/\$k it is a strip');
          expect(ratio, lessThan(2.0), reason: 'with \$n/\$k it is a strip');
        }
      }
    });

    test('the town spreads slowly enough to stay one place', () {
      // A hundred times more achievements must not put the far side of town
      // a hundred times further away.
      expect(
        TownLayout(9000, TownCharacter.all.first).radius,
        lessThan(TownLayout(90, TownCharacter.all.first).radius * 12),
      );
    });
  });

  group('the catalogue', () {
    test('there are enough landmarks for a long life', () {
      // Sesenta, y el número bajó a propósito: eran ciento trece y la mitad
      // se confundían entre sí —tejar, tinte, batán, tenada, majada, todas el
      // mismo cobertizo con otro nombre—. Un catálogo en el que no se
      // distingue una obra de otra no es más largo, es más borroso.
      expect(landmarks.length, greaterThanOrEqualTo(55));

      // Y las retiradas ya no existen: ni se ofrecen ni se saben levantar.
      // Una crónica que nombre una obra que no está en el catálogo levanta
      // una casa corriente en su lugar.
      expect(TownPlan.landmarkOf('horno'), isNull);
      expect(TownPlan.landmarkOf('porqueriza'), isNull);
    });

    test('toda obra se arma en el pueblo igual que en su receta', () {
      // Lo que se vio: en la mitad de los pueblos el coso tenía dos lienzos de
      // arcada cruzándole la arena por el medio. El sentido de los tejados
      // salía al azar también para las obras, y eso giraba las arcadas, las
      // escaleras y las ruedas que no dicen su sentido —sin moverlas de
      // sitio—, mientras el taller de obras las armaba siempre derechas.
      //
      // Así que se exige pieza por pieza, en todas las obras y en todas las
      // comarcas: el mismo sentido y lo largo para el mismo lado que en la
      // receta, y la obra entera, sin que sobre ni falte ninguna pieza.
      for (final mark in landmarks) {
        final receta = Mason(0, 0, 1, true);
        mark.build(receta);
        expect(
          receta.out.length,
          mark.cost,
          reason:
              '${mark.id}: la receta da ${receta.out.length} piezas y '
              'cuesta ${mark.cost}',
        );
        // Lo empinado del tejado sí es de la comarca, y va aparte.
        // Y lo que se apoya en un tejado —la buhardilla— sube y baja con él.
        bool techoDe(PieceKind k) =>
            k == PieceKind.roof ||
            k == PieceKind.thatch ||
            k == PieceKind.dormer;
        for (final c in TownCharacter.all) {
          final l = TownLayout.showcase(c, landmark: mark, placed: mark.cost);
          final hechas = l.pieces.where((p) => p.building == 0).toList();
          expect(hechas.length, mark.cost, reason: '${mark.id} en ${c.region}');
          // Y en su sitio y a su tamaño: lo único que la comarca le hace a una
          // obra es estirarla entera, igual en todas sus piezas —a lo ancho
          // por un número y a lo alto por otro—, así que cada pieza tiene que
          // ser la del taller multiplicada por esos dos números.
          final ref = receta.out.indexWhere((r) => r.w > 0.2);
          final ancho = hechas[ref].w / receta.out[ref].w;
          final ox = hechas[ref].cx - receta.out[ref].cx * ancho;
          final oz = hechas[ref].cz - receta.out[ref].cz * ancho;
          final alzado = receta.out.indexWhere(
            (r) => r.y1 - r.y0 > 0.2 && !techoDe(r.kind),
          );
          final alto =
              (hechas[alzado].y1 - hechas[alzado].y0) /
              (receta.out[alzado].y1 - receta.out[alzado].y0);
          for (var i = 0; i < hechas.length; i++) {
            final r = receta.out[i], p = hechas[i];
            final donde = '${mark.id} pieza $i (${r.kind.name}) en ${c.region}';
            expect(p.cx, closeTo(ox + r.cx * ancho, 1e-6), reason: donde);
            expect(p.cz, closeTo(oz + r.cz * ancho, 1e-6), reason: donde);
            expect(p.w, closeTo(r.w * ancho, 1e-6), reason: donde);
            expect(p.d, closeTo(r.d * ancho, 1e-6), reason: donde);
            if (r.kind != PieceKind.dormer) {
              expect(p.y0, closeTo(r.y0 * alto, 1e-6), reason: donde);
            }
            if (!techoDe(r.kind)) {
              expect(p.y1, closeTo(r.y1 * alto, 1e-6), reason: donde);
            }
            // La comarca puede techar de paja lo que la receta techa de teja.
            PieceKind techo(PieceKind k) =>
                k == PieceKind.thatch ? PieceKind.roof : k;
            expect(techo(p.kind), techo(r.kind), reason: '${mark.id} pieza $i');
            expect(
              p.alongX,
              r.alongX,
              reason: '${mark.id} pieza $i en ${c.region}: girada',
            );
            if ((r.w - r.d).abs() > 1e-6) {
              expect(
                p.w > p.d,
                r.w > r.d,
                reason:
                    '${mark.id} pieza $i (${r.kind.name}) en '
                    '${c.region}: lo largo para el otro lado',
              );
            }
          }
        }
      }
    });

    test('every landmark has its own id and its own name', () {
      expect(landmarks.map((l) => l.id).toSet().length, landmarks.length);
      expect(landmarks.map((l) => l.name).toSet().length, landmarks.length);
    });

    test('every landmark has something said about it, once, and its own', () {
      for (final l in landmarks) {
        expect(l.blurb.length, greaterThan(24), reason: l.name);
        expect(l.blurb.endsWith('.'), isTrue, reason: l.name);
      }
      expect(landmarks.map((l) => l.blurb).toSet().length, landmarks.length);
    });

    test('every tier has enough in it to keep a long town varied', () {
      for (var t = 0; t < 3; t++) {
        final n = landmarks.where((l) => l.tier == t).length;
        expect(n, greaterThanOrEqualTo(12), reason: 'tier $t has only $n');
      }
    });

    test('every landmark builds to exactly what it costs', () {
      for (final l in landmarks) {
        final m = Mason(0, 0, 12345, true);
        l.build(m);
        expect(
          m.count,
          greaterThanOrEqualTo(l.cost),
          reason:
              '${l.name} lays ${m.count} pieces but costs ${l.cost}, so '
              'the last ones would be padding',
        );
        expect(
          m.count,
          lessThanOrEqualTo(l.cost + 3),
          reason:
              '${l.name} lays ${m.count} pieces but costs only ${l.cost}, '
              'so it would never be finished',
        );
      }
    });

    test('nada vuela: cada pieza se apoya en algo que tiene debajo', () {
      // **Ésta es la prueba que faltaba, y por eso había piezas volando.**
      //
      // La versión anterior daba por buena una pieza si *alguna* de las
      // anteriores llegaba a esa altura, mirase a donde mirase. Con eso, una
      // veleta a cuatro metros del suelo quedaba aprobada porque al otro lado
      // del solar había una torre igual de alta. Lo que hay que comprobar es
      // que tenga algo **debajo**, no en alguna parte.
      //
      // Se mide en las seis comarcas y no sólo en las proporciones en las que
      // están escritas las recetas: el estirado es afín, así que lo que se
      // toca se sigue tocando, pero el tejado tiene un cuarto número —lo
      // empinado que construye el sitio— y una chimenea clavada a una altura
      // fija se queda en el aire en cuanto el tejado baja.
      final fallos = <String>[];
      for (final l in landmarks) {
        for (final c in TownCharacter.all) {
          final propio = l.rigid;
          final m = Mason(
            0,
            0,
            999,
            true,
            spread: (propio ? 1.0 : c.spread) * l.scale,
            storey: (propio ? 1.0 : c.storey) * l.scale,
            pitch: propio ? 1.0 : c.pitch,
          );
          l.build(m);
          final built = m.finish(l.cost);
          expect(
            built.first.y0,
            lessThan(0.001),
            reason: '${l.name} empieza en el aire',
          );
          for (var i = 0; i < built.length; i++) {
            final s = built[i];
            if (s.y0 < 0.03) continue;
            var apoyada = false;
            for (var j = 0; j < i && !apoyada; j++) {
              final b = built[j];
              // Se tocan por arriba y se pisan por abajo. El solape pide algo
              // más que rozarse por un canto: una esquina que toca otra
              // esquina no sostiene nada.
              final anchoX = (s.w + b.w) / 2 - (s.cx - b.cx).abs();
              final anchoZ = (s.d + b.d) / 2 - (s.cz - b.cz).abs();
              apoyada =
                  b.y1 >= s.y0 - 0.06 &&
                  b.y0 <= s.y0 + 0.06 &&
                  anchoX > 0.04 &&
                  anchoZ > 0.04;
            }
            if (!apoyada) {
              fallos.add(
                '${l.id} (${l.name}) en ${c.region}: pieza $i, un '
                '${s.kind.name} flota a ${s.y0.toStringAsFixed(2)}',
              );
            }
          }
        }
      }
      expect(fallos, isEmpty, reason: fallos.join('\n'));
    });

    test('no landmark sprawls further than its own plot allows', () {
      for (final l in landmarks) {
        // Con el aprieto puesto: lo que tiene que caber en el solar es lo que
        // se levanta, no lo que está escrito. Ver [Landmark.scale].
        final m = Mason(0, 0, 7, true, spread: l.scale, storey: l.scale);
        l.build(m);
        var reach = 0.0;
        for (final s in m.finish(l.cost)) {
          final r = math.max(s.cx.abs() + s.w / 2, s.cz.abs() + s.d / 2);
          if (r > reach) reach = r;
        }
        expect(
          reach,
          closeTo(l.reach, 1e-9),
          reason: '${l.name} does not know how far it reaches',
        );
        // The town keeps a fixed amount of room clear per tier. A recipe that
        // grows past it would be standing in its neighbours' plots — and the
        // room cannot simply be widened, because the spacing is what decides
        // where every later building goes.
        expect(
          reach,
          lessThanOrEqualTo(l.room),
          reason:
              '${l.name} sprawls ${reach.toStringAsFixed(2)}, past the '
              '${l.room} its tier is given',
        );
      }
    });

    test('the room a landmark is given never depends on its recipe', () {
      // The spacing decides where every later building stands, so it must not
      // move when a recipe is edited: a town that rearranges itself on an app
      // update is not a record of anything.
      for (final l in landmarks) {
        expect(l.room, const [2.6, 4.0, 6.4][l.tier]);
      }
    });

    test('a long life meets the whole catalogue without repeating one', () {
      final n = landmarks.length;
      final seen = road(TownCharacter.all.first, n);
      expect(seen.length, n, reason: 'only ${seen.length} landmarks come up');
      expect(seen.toSet().length, n, reason: 'a landmark came round twice');
    });
  });

  group('a valley of towns', () {
    test('every plot is a different kind of place', () {
      final regions = TownCharacter.all.map((c) => c.region).toSet();
      expect(regions.length, TownCharacter.all.length);
      final orders = TownCharacter.all.map((c) => c.order).toSet();
      expect(orders.length, TownCharacter.all.length);
    });

    test('two towns meet the catalogue in a different order', () {
      // Four habits must not feel like the same thing four times, and the
      // clearest way they would is by hitting the same landmarks on the same
      // days. Every plot walks its own road.
      final roads = <String>{};
      for (final c in TownCharacter.all) {
        final first = road(c, 10);
        expect(first.length, 10);
        roads.add(first.join(','));
      }
      expect(
        roads.length,
        TownCharacter.all.length,
        reason: 'dos plots construyen los mismos hitos en el mismo orden',
      );
    });

    test('lo chico primero y lo grande cuando el pueblo ya es grande', () {
      // Un pueblo nuevo empieza con obras de cinco a diez piezas, que le
      // llegan seguido; desde el sexto hito —unas ciento cincuenta piezas—
      // puede salirle una grande, y al décimo seguro le salió. Hubo una lista
      // de obras de apertura que metía el castillo de cincuenta y dos piezas
      // entre las primeras, y un pueblo de sesenta con treinta de monumento se
      // ve chico, no importante.
      for (final c in TownCharacter.all) {
        for (var seed = 0; seed < 12; seed++) {
          final l = TownLayout(700, c, seed: seed);
          final hitos = [
            for (final b in l.buildings)
              if (b.isLandmark) b.landmark!,
          ];
          expect(hitos.length, greaterThan(10), reason: c.region);
          for (var i = 0; i < 3; i++) {
            expect(hitos[i].tier, 0, reason: '${c.region}/$seed hito $i');
          }
          for (var i = 0; i < 5; i++) {
            expect(
              hitos[i].tier,
              lessThan(2),
              reason: '${c.region}/$seed hito $i',
            );
          }
          expect(
            hitos.take(10).any((h) => h.tier == 2),
            isTrue,
            reason: '${c.region}/$seed: diez hitos y ninguno grande',
          );
        }
      }
    });

    test('entre hito y hito no hay un barrio de relleno', () {
      // Entre el décimo hito y el undécimo llegó a haber catorce casas. Ahora
      // la distancia empieza en tres casas y no pasa de seis.
      var antes = -1;
      for (var b = 0; b < 400; b++) {
        if (!TownPlan.isLandmarkSlot(b)) continue;
        if (antes >= 0) {
          expect(b - antes - 1, inInclusiveRange(3, 6), reason: 'en el $b');
        }
        antes = b;
      }
    });

    test('every town still opens with something worth waiting for', () {
      // Different, but never worse: an honest shuffle hands out a pigsty
      // before the mill, and that is a bad first month whichever plot it is.
      const dreary = {'camposanto', 'horca'};
      for (final c in TownCharacter.all) {
        for (final id in road(c, 4)) {
          expect(
            dreary.contains(id),
            isFalse,
            reason: '${c.region} abre con $id',
          );
        }
      }
    });

    test('two towns never stand on top of each other', () {
      for (var a = 0; a < Habit.maxSlots; a++) {
        for (var b = a + 1; b < Habit.maxSlots; b++) {
          final (ax, az) = Habit.centreOf(a);
          final (bx, bz) = Habit.centreOf(b);
          final d = math.sqrt((ax - bx) * (ax - bx) + (az - bz) * (az - bz));
          // Room for two towns of thirty thousand achievements each.
          expect(d, greaterThan(70.0), reason: 'plots $a y $b');
        }
      }
    });

    test('a town is built where its plot is, not at the origin', () {
      final (cx, cz) = Habit.centreOf(3);
      final t = TownLayout(200, TownCharacter.forSlot(3), cx: cx, cz: cz);
      for (final p in t.pieces) {
        expect((p.cx - cx).abs(), lessThan(40));
        expect((p.cz - cz).abs(), lessThan(40));
      }
    });
  });
}
