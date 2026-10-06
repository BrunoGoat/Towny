import 'package:flutter/material.dart';

import '../data/character.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../engine/scene.dart';
import '../engine/tones.dart';
import '../engine/town.dart';
import '../fx/effects.dart';
import 'choice_sheet.dart';

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

  /// Cuántas piezas tiene la muestra: unos meses de un hábito, con casas,
  /// algún hito y calles, que es lo que hace falta para que se note la región.
  static const int pieces = 100;

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
    final cam = WorkPortrait.frame(layout, size);
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

  @override
  bool shouldRepaint(TownPortrait old) =>
      old.place.order != place.order || old.palette.hour != palette.hour;
}
