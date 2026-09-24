import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/core/rng.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/data/landmarks_retired.dart';
import 'package:la_muralla/engine/mason.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/habit.dart';

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
      const caps = {PieceKind.roof, PieceKind.spire};
      final city = TownLayout(900, TownCharacter.all.first);
      bool over(TownPiece a, TownPiece b) =>
          (a.cx - b.cx).abs() < (a.w + b.w) * 0.4 &&
          (a.cz - b.cz).abs() < (a.d + b.d) * 0.4;
      for (final b in city.buildings) {
        final mine = city.pieces.where((p) => p.building == b.index).toList();
        for (final p in mine) {
          // A church has a nave and a bell tower, so the comparison is per
          // column: only a roof this piece actually stands over counts.
          const crowns = {
            PieceKind.chimney,
            PieceKind.sail,
            PieceKind.banner,
            PieceKind.dome,
            PieceKind.spire,
          };
          if (caps.contains(p.kind) || crowns.contains(p.kind)) continue;
          for (final cap in mine) {
            if (!caps.contains(cap.kind) || !over(p, cap)) continue;
            expect(
              p.y0,
              lessThan(cap.y1 - 0.01),
              reason: '${b.name}: a ${p.kind.name} sits on the roof',
            );
          }
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

      // Y las retiradas siguen sabiéndose levantar, que es lo que protege a
      // un pueblo que ya tiene una en pie: ver `landmarks_retired.dart`.
      expect(retiredLandmarks.length, greaterThanOrEqualTo(50));
      final vivas = landmarks.map((l) => l.id).toSet();
      for (final l in retiredLandmarks) {
        expect(vivas.contains(l.id), isFalse, reason: l.id);
        expect(
          TownPlan.landmarkOf(l.id),
          isNotNull,
          reason: 'una crónica vieja ya no sabría levantar ${l.id}',
        );
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
            spread: propio ? 1.0 : c.spread,
            storey: propio ? 1.0 : c.storey,
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
        final m = Mason(0, 0, 7, true);
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

    test('every town still opens with something worth waiting for', () {
      // Different, but never worse: an honest shuffle hands out a pigsty
      // before the mill, and that is a bad first month whichever plot it is.
      const dreary = {'porqueriza', 'osario', 'picota', 'camposanto', 'horca'};
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
