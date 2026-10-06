import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/math3.dart';

import '../data/character.dart';
import '../engine/camera.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../engine/scene.dart';
import '../engine/tones.dart';
import '../engine/town.dart';
import '../fx/effects.dart';

/// Un pueblo de muestra de [TownPortrait.pieces] piezas, en la comarca que se
/// le diga.
///
/// Para elegir comarca mirando y no leyendo: el mismo pueblo —la misma
/// semilla, las mismas obras— levantado con la cara de cada una, así que lo
/// único que cambia de un retrato a otro es lo que cambia la comarca.
class TownPortrait extends CustomPainter {
  TownPortrait({required this.place, required this.palette});

  final TownCharacter place;
  final Palette palette;

  /// Cuántas piezas tiene la muestra: medio año de un hábito, con calles
  /// enteras y algún hito grande, que es lo que hace falta para que se note
  /// la región.
  static const int pieces = 200;

  /// Siempre la misma semilla: el mismo pueblo en cada comarca.
  static const int _seed = 7;

  /// Un plano por comarca, hecho una vez: tocar los sellos de un lado a otro
  /// no puede rehacer un pueblo de cien piezas en cada toque.
  static final Map<int, TownLayout> _planos = {};

  static TownLayout layoutFor(TownCharacter c) =>
      _planos.putIfAbsent(c.order, () => TownLayout(pieces, c, seed: _seed));

  @override
  void paint(Canvas canvas, Size size) {
    final layout = layoutFor(place);
    final cam = frame(layout, size);
    canvas.drawRect(Offset.zero & size, Paint()..color = meadowTone(palette));
    TownPainter(
      TownScene(
        placed: pieces,
        palette: palette,
        camera: cam,
        time: 0,
        hourOfDay: palette.hour,
        effects: EffectSystem(),
        budget: 16000,
        towns: [
          TownEntry(
            layout: layout,
            name: place.region,
            symbol: place.symbol,
            placed: pieces,
          ),
        ],
        active: 0,
        labels: false,
        folk: false,
      ),
      // Un retrato no se toca.
      TouchMap(),
    ).paint(canvas, size);
  }

  /// Un plano de cine y no una foto desde arriba.
  ///
  /// Mirado desde lejos y en picado, todos los pueblos eran un puñado de
  /// cajas sobre un prado: lo que distingue a uno de otro no se veía. Así que
  /// la cámara baja y se acerca a lo que cuenta el pueblo —la obra más grande
  /// que tiene, o la plaza si es un pueblo que va de juntarse
  /// ([TownCharacter.portraitPlaza])— y se pone del lado de afuera mirando
  /// hacia el centro: la obra delante, grande, y el resto del pueblo detrás,
  /// que es lo que dice dónde está.
  static OrbitCamera frame(TownLayout layout, Size size) {
    final cx = layout.cx, cz = layout.cz;
    // La obra terminada más alta: una torre, un castillo, un campanario. La
    // más cara salía casi siempre la misma —un patio cuadrado y chato— y los
    // retratos se parecían todos; lo alto es lo que se ve desde lejos y lo
    // que hace que un pueblo se reconozca.
    TownBuilding? heroe;
    var techo = 0.0;
    if (!layout.character.portraitPlaza) {
      for (final b in layout.buildings) {
        if (!b.isLandmark || !b.finished) continue;
        var arriba = 0.0;
        for (final p in layout.pieces) {
          if (p.building == b.index && p.y1 > arriba) arriba = p.y1;
        }
        if (arriba > techo) {
          techo = arriba;
          heroe = b;
        }
      }
    }
    final hx = heroe?.cx ?? cx, hz = heroe?.cz ?? cz;

    // Lo que tiene que entrar entero: la obra (o la plaza), y su alto.
    final suyo = <V3>[];
    var alto = 1.0;
    for (final p in layout.pieces) {
      final dentro = heroe != null
          ? p.building == heroe.index
          : (p.cx - cx).abs() < TownLayout.plazaReach * 1.6 &&
                (p.cz - cz).abs() < TownLayout.plazaReach * 1.6;
      if (!dentro) continue;
      if (p.y1 > alto) alto = p.y1;
      suyo
        ..add(V3(p.cx - p.w / 2, p.y0, p.cz - p.d / 2))
        ..add(V3(p.cx + p.w / 2, p.y1, p.cz + p.d / 2));
    }
    if (heroe == null) {
      // La plaza misma, aunque no haya ninguna casa encima.
      const r = TownLayout.plazaReach;
      suyo
        ..add(V3(cx - r, 0, cz - r))
        ..add(V3(cx + r, 0, cz + r));
    }

    // Desde afuera hacia el centro, y un poco de lado: de frente es un
    // retrato de carnet. Si la obra está en el medio, el ángulo de siempre.
    final dx = hx - cx, dz = hz - cz;
    final lejos = math.sqrt(dx * dx + dz * dz) > 1.0;
    final cam = OrbitCamera()
      ..yawTarget = (lejos ? math.atan2(dx, dz) : 0.62) + 0.45
      ..pitchTarget = heroe != null ? 0.26 : 0.50
      // Un poco hacia el centro desde la obra, para que lo de detrás entre.
      ..travelTarget = hx + (cx - hx) * 0.25
      ..focusZTarget = hz + (cz - hz) * 0.25
      ..focusYTarget = alto * 0.40;
    cam.snap();
    // Primero el pueblo entero en cuadro, y después la cámara se mete: a
    // mitad de camino, que es donde la obra se ve grande y el pueblo sigue
    // detrás. Medir sólo la obra dejaba la cámara donde quisiera el resto —a
    // veces lejísimos—, y en un cuadro bajo y ancho el pueblo salía chiquito.
    final todo = <V3>[
      for (final p in layout.pieces) ...[
        V3(p.cx - p.w / 2, p.y0, p.cz - p.d / 2),
        V3(p.cx + p.w / 2, p.y1, p.cz + p.d / 2),
      ],
    ];
    final entero = cam.distanceToFit(todo, size.width, size.height);
    final protagonista = cam.distanceToFit(
      suyo,
      size.width,
      size.height,
      margin: heroe != null ? 0.80 : 0.55,
    );
    cam.distanceTarget = clampD(math.max(entero * 0.55, protagonista), 6, 90);
    cam.snap();
    return cam;
  }

  @override
  bool shouldRepaint(TownPortrait old) =>
      old.place.order != place.order || old.palette.hour != palette.hour;
}
