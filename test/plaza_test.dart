import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/core/math3.dart';
import 'package:towny/core/rng.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/folk.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/season.dart';
import 'package:towny/engine/solid.dart';
import 'package:towny/engine/solids.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';

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

/// **La plaza**: el ejido, la fuente y el tablón. No es de nadie y
/// no se gana; está desde que el pueblo se funda, y por ella se anda.
const int _w = 460, _h = 460;

/// El pueblo con su plaza, visto desde donde se lo mira casi siempre. [t] es el
/// reloj del valle, que es lo que mueve a la gente.
Future<ui.Image> _frame({
  bool folk = false,
  Season season = Season.none,
  double t = 7.5,
}) async {
  final layout = TownLayout(40, TownCharacter.all.first, seed: 7);
  final cam = OrbitCamera()
    ..yaw = 0.62
    ..pitch = 0.34
    ..distance = 9
    ..focusY = 1.0
    ..wallLength = layout.radius * 2;
  final rec = ui.PictureRecorder();
  TownPainter(
    TownScene(
      placed: 40,
      palette: Palette.forMoment(11, season: season),
      camera: cam,
      time: t,
      hourOfDay: 11,
      effects: EffectSystem(),
      budget: 40000,
      towns: [
        TownEntry(layout: layout, name: 'Pueblo', symbol: 'rueda', placed: 40),
      ],
      active: 0,
      labels: false,
      folk: folk,
      ghost: false,
    ),
    TouchMap(),
  ).paint(Canvas(rec), const Size(_w * 1.0, _h * 1.0));
  return rec.endRecording().toImage(_w, _h);
}

/// La plaza sola y de cerca, que es donde se le ve el color al césped.
Future<ui.Image> _plaza(Season season) async {
  final layout = TownLayout(0, TownCharacter.all.first, seed: 7);
  final cam = OrbitCamera()
    ..yaw = 0.62
    ..pitch = 0.9
    ..distance = 7
    ..focusY = 0.4
    ..wallLength = layout.radius * 2;
  final rec = ui.PictureRecorder();
  TownPainter(
    TownScene(
      placed: 0,
      palette: Palette.forMoment(11, season: season),
      camera: cam,
      time: 2,
      hourOfDay: 11,
      effects: EffectSystem(),
      budget: 40000,
      towns: [
        TownEntry(layout: layout, name: 'Pueblo', symbol: 'rueda', placed: 0),
      ],
      active: 0,
      labels: false,
      folk: false,
      ghost: false,
    ),
    TouchMap(),
  ).paint(Canvas(rec), const Size(_w * 1.0, _h * 1.0));
  return rec.endRecording().toImage(_w, _h);
}

/// Cuántas manchas de color grandes tiene una imagen.
///
/// Una cara lisa es una mancha. Se cuentan las que ocupan cuatrocientos
/// píxeles o más, para que el contorno dentado de dos caras vecinas no cuente
/// como una tercera.
int _manchas(Uint8List px) {
  final cuenta = <int, int>{};
  for (var i = 0; i < px.length; i += 4) {
    final k = ((px[i] >> 3) << 10) | ((px[i + 1] >> 3) << 5) | (px[i + 2] >> 3);
    cuenta[k] = (cuenta[k] ?? 0) + 1;
  }
  return cuenta.values.where((n) => n >= 400).length;
}

Future<Uint8List> _bytes(ui.Image img) async => (await img.toByteData(
  format: ui.ImageByteFormat.rawRgba,
))!.buffer.asUint8List();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

    test('el tablón cabe en ella, fuera del pilón', () {
      final t = TownLayout(10, TownCharacter.all.first);
      // Entero dentro del enlosado.
      for (final v in NoticeBoard.faceAt(t.cx, t.cz)) {
        expect(_far(v.x, v.z, t.cx, t.cz), lessThan(TownLayout.plazaReach));
      }
      // Y fuera del pilón, que está en medio.
      final pilon = Plaza.basinOf(TownLayout.plazaReach);
      expect(
        _far(NoticeBoard.xAt(t.cx), NoticeBoard.zAt(t.cz), t.cx, t.cz),
        greaterThan(pilon + NoticeBoard.reach),
      );
    });
  });

  group('el tablón mira a la fuente', () {
    /// Hacia dónde mira la cara que se lee, sacada de sus propias esquinas.
    V3 mira(List<V3> cara, double x, double z) =>
        Facet.normalOf(cara, away: V3(x, 0.6, z));

    test('y no para otro lado', () {
      final t = TownLayout(10, TownCharacter.all.first);
      for (final (nombre, cara, x, z) in [
        (
          'el tablón',
          NoticeBoard.faceAt(t.cx, t.cz),
          NoticeBoard.xAt(t.cx),
          NoticeBoard.zAt(t.cz),
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
      for (final partes in [NoticeBoard.solidsAt(4, -3)]) {
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

  group('la plaza se ve y se pisa', () {
    test('en otoño la plaza es tan lisa como en verano, con otro color', () async {
      // El fallo, tal cual se vio: en otoño la plaza salía partida en gajos de
      // ocres distintos —uno por cada triángulo de la tapa del enlosado—
      // mientras que en las otras tres estaciones se veía lisa.
      //
      // **Cómo se mide.** Cuántas manchas grandes de color tiene el cuadro. Una
      // cara lisa es una mancha, así que si el otoño no parte nada, otoño y
      // verano tienen que tener las mismas. Medido sobre las dos versiones:
      // lisa, 20 en verano y 19 en otoño; a gajos, 20 y 31.
      final verano = await _plaza(Season.none);
      final otono = await _plaza(const Season(0.75));
      final a = await _bytes(verano), b = await _bytes(otono);
      verano.dispose();
      otono.dispose();
      final enVerano = _manchas(a), enOtono = _manchas(b);
      expect(
        enOtono,
        lessThanOrEqualTo(enVerano + 2),
        reason:
            'el otoño parte la plaza: $enOtono manchas de color contra las '
            '$enVerano del verano',
      );

      // Y que sea otoño de verdad, no verano dos veces: el color cambia, lo que
      // no cambia es que sea uno solo.
      var movidos = 0;
      for (var i = 0; i < a.length; i += 4) {
        if ((a[i] - b[i]).abs() > 8 || (a[i + 2] - b[i + 2]).abs() > 8) {
          movidos++;
        }
      }
      expect(movidos, greaterThan(5000), reason: 'el otoño no se nota');
    });

    test('el césped de la plaza se dora entero, y no a cuartos', () {
      // El fallo, tal cual se vio: en otoño la plaza salía partida en gajos de
      // ocres distintos, uno por cada cara del enlosado, mientras que en las
      // otras tres estaciones se veía lisa.
      //
      // La causa: el día en que una hoja se dora sale de su semilla, y la
      // semilla se sacaba de **dónde está la cara**. Para un roble eso es lo que
      // se quiere —dos robles vecinos no se doran el mismo día— pero las caras
      // de un mismo bulto están cada una en un sitio, así que cada cara del
      // césped se doraba por su cuenta. Ahora la semilla es la del bulto.
      final losas = Plaza.solidsAt(0, 0, TownLayout.plazaReach);
      final semillas = <int>{};
      for (final s in losas) {
        asFurniture(s);
        final suyas = <int>{};
        for (final f in s.faces) {
          expect(f.piece, -1, reason: 'la plaza no es pieza de nadie');
          if (f.surface == Surface.leaf) suyas.add(f.data);
        }
        expect(
          suyas.length,
          lessThan(2),
          reason: 'un mismo bulto tiene ${suyas.length} semillas de hoja',
        );
        semillas.addAll(suyas);
      }
      expect(semillas, isNotEmpty, reason: 'la plaza no tiene césped');

      // Y la otra mitad: dos matas distintas sí se doran días distintos, que es
      // de donde venía la idea.
      final a = Yard.gardenAt(0, 0, 1.0, 3)..forEach(asFurniture);
      final b = Yard.gardenAt(9, 4, 1.0, 3)..forEach(asFurniture);
      int? hojaDe(List<Solid> ss) {
        for (final s in ss) {
          for (final f in s.faces) {
            if (f.surface == Surface.leaf) return f.data;
          }
        }
        return null;
      }

      expect(hojaDe(a), isNotNull);
      expect(hojaDe(a), isNot(hojaDe(b)));
    });

    test('quien entra en la plaza se ve, en vez de tragárselo el enlosado', () async {
      // El fallo: el ejido tiene cinco centímetros de canto y la gente andaba
      // con los pies a cero, o sea **metida dentro de la losa**. Dos cuerpos que
      // se atraviesan no tienen plano que los separe y por tanto no tienen
      // orden; el que salía era el de la losa, y como desde arriba la losa tapa
      // todo el octógono, cualquiera que cruzaba la plaza se borraba entero.
      //
      // **Cómo se mide.** El mismo fotograma con gente y sin ella. En este
      // —semilla 7, segundo 7,5— hay un vecino parado en la plaza, a un metro y
      // cuarto de la fuente, y lo que lo dibuja es lo único que cambia entre los
      // dos. Medido sobre las dos versiones: tragado quedaban 149 píxeles suyos
      // —poco más que la cabeza, asomando por el canto del enlosado—; de pie
      // sobre la losa se le ven 418, que es el vecino entero.
      final sin = await _frame();
      final con = await _frame(folk: true);
      final a = await _bytes(sin), b = await _bytes(con);
      sin.dispose();
      con.dispose();
      var vecino = 0;
      for (var i = 0; i < a.length; i += 4) {
        if ((a[i] - b[i]).abs() > 8 ||
            (a[i + 1] - b[i + 1]).abs() > 8 ||
            (a[i + 2] - b[i + 2]).abs() > 8) {
          vecino++;
        }
      }
      expect(
        vecino,
        greaterThan(200),
        reason: 'sólo $vecino píxeles de vecino: la plaza se lo está comiendo',
      );
    });

    test('y la gente de la plaza anda por encima del enlosado', () {
      // La misma cosa dicha en metros, que es donde se arregló: a quien está
      // dentro de la plaza el suelo le queda a la altura del enlosado.
      const r = TownLayout.plazaReach;
      expect(Plaza.floorAt(0, 0, 0, 0, r), Plaza.lawnTop);
      expect(Plaza.floorAt(r * 0.95, 0, 0, 0, r), Plaza.kerbTop);
      expect(Plaza.floorAt(r * 1.4, 0, 0, 0, r), 0);
      // Y el pueblo de al lado tiene la suya en su sitio, no en el origen.
      expect(Plaza.floorAt(40, 12, 40, 12, r), Plaza.lawnTop);
      expect(Plaza.floorAt(0, 0, 40, 12, r), 0);
    });

    test(
      'hay gente que pisa la plaza, que es lo que hace falta probar nada',
      () {
        // Si nadie entrara nunca, las dos pruebas de arriba estarían midiendo el
        // vacío. Hay cuatro vecinos y uno pasa por el medio.
        final layout = TownLayout(40, TownCharacter.all.first, seed: 7);
        final gente = folkOf(layout, 40);
        var dentro = false;
        for (var t = 0.0; t < 60 && !dentro; t += 0.5) {
          for (final who in gente) {
            final at = who.at(t);
            if (math.sqrt(at.x * at.x + at.z * at.z) <
                TownLayout.plazaReach * 0.9) {
              dentro = true;
              break;
            }
          }
        }
        expect(dentro, isTrue, reason: 'nadie entra nunca en la plaza');
      },
    );
  });

  group('tocarlos con el dedo', () {
    /// El encuadre que deja la app sola al abrir un pueblo. Ver `_frameTown`.
    TouchMap blancos(TownLayout layout, {double yaw = 0.62}) {
      final cam = OrbitCamera()
        ..yaw = yaw
        ..pitch = 0.46
        ..distance = (layout.radius * 1.9).clamp(9.0, 60.0)
        ..travel = layout.cx
        ..focusZ = layout.cz
        ..focusY = 1.4
        ..wallLength = layout.radius * 2;
      final hits = TouchMap();
      final rec = ui.PictureRecorder();
      TownPainter(
        TownScene(
          placed: 40,
          palette: Palette.forMoment(11),
          camera: cam,
          time: 3,
          hourOfDay: 11,
          effects: EffectSystem(),
          budget: 40000,
          towns: [
            TownEntry(
              layout: layout,
              name: 'Pueblo',
              symbol: 'rueda',
              placed: 40,
            ),
          ],
          active: 0,
          labels: false,
          folk: false,
          ghost: false,
        ),
        hits,
      ).paint(Canvas(rec), const Size(390, 844));
      rec.endRecording().dispose();
      return hits;
    }

    /// Lo que no se había pensado, y se notaba usando la app: con el encuadre
    /// de siempre **el tablón se ve de canto**.
    ///
    /// La plancha mira a la fuente, o sea al sudeste; la cámara se planta en
    /// `yaw = 0.62`, que es por donde se entra a un pueblo. Entre las dos cosas
    /// hay cien grados. Medido en un pueblo de cuarenta piezas: la plancha
    /// ocupa **tres píxeles de ancho** por veintiuno de alto. El blanco salía de ahí, así que era un pelo
    /// vertical en medio de una plaza y lo que le llegaba al dedo era la casa
    /// de detrás.
    ///
    /// De canto una tabla mide lo que mide, así que esto no se arregla
    /// midiendo mejor: el blanco de un dedo y la silueta de una cosa no son la
    /// misma cosa.
    test('aunque se vean de canto, se pueden tocar', () {
      var mirados = 0;
      for (final c in TownCharacter.all) {
        final layout = TownLayout(40, c, seed: 7);
        final hits = blancos(layout);
        for (final (quien, r) in [
          for (final b in hits.boards) ('el tablón', b.rect),
        ]) {
          mirados++;
          expect(
            r.width,
            greaterThan(43.9),
            reason: '${c.region}: $quien mide ${r.width.round()} de ancho',
          );
          expect(
            r.height,
            greaterThan(43.9),
            reason: '${c.region}: $quien mide ${r.height.round()} de alto',
          );
        }
      }
      // Que no se esté midiendo el vacío: con seis comarcas son seis, y de
      // cuadro se sale alguno.
      expect(mirados, greaterThan(3), reason: 'sólo se miraron $mirados');
    });

    /// Y desde cualquier lado, que es lo que uno hace: dar la vuelta al pueblo
    /// mirando cosas y tocar la que le interesa desde donde esté.
    test('desde cualquier ángulo', () {
      final layout = TownLayout(40, TownCharacter.all.first, seed: 7);
      for (var yaw = 0.0; yaw < 6.28; yaw += 0.3) {
        final hits = blancos(layout, yaw: yaw);
        // Fuera de cuadro no hay blanco, y eso está bien: lo que no se ve no
        // se toca. Lo que se exige es de los que sí están.
        for (final b in hits.boards) {
          expect(b.rect.width, greaterThan(43.9), reason: 'yaw $yaw');
          expect(b.rect.height, greaterThan(43.9), reason: 'yaw $yaw');
        }
      }
    });

    /// Y un pueblo visto desde el otro lado del valle no reparte blancos de
    /// cuarenta y cuatro píxeles: ahí el pueblo entero mide eso.
    test('de lejos no hay nada que tocar', () {
      final layout = TownLayout(40, TownCharacter.all.first, seed: 7);
      final cam = OrbitCamera()
        ..yaw = 0.62
        ..pitch = 0.9
        ..distance = 320
        ..focusY = 1.4
        ..wallLength = layout.radius * 2;
      final hits = TouchMap();
      final rec = ui.PictureRecorder();
      TownPainter(
        TownScene(
          placed: 40,
          palette: Palette.forMoment(11),
          camera: cam,
          time: 3,
          hourOfDay: 11,
          effects: EffectSystem(),
          budget: 40000,
          towns: [
            TownEntry(
              layout: layout,
              name: 'Pueblo',
              symbol: 'rueda',
              placed: 40,
            ),
          ],
          active: 0,
          labels: false,
          folk: false,
          ghost: false,
        ),
        hits,
      ).paint(Canvas(rec), const Size(390, 844));
      rec.endRecording().dispose();
      expect(hits.boards, isEmpty);
    });
  });
}
