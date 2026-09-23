import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/scene.dart';
import 'package:la_muralla/engine/season.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/fx/effects.dart';

const int _w = 720, _h = 1280;

/// El mismo pueblo, el mismo sitio y la misma hora en los que se vio el fallo:
/// treinta y ocho piezas al anochecer, mirando desde donde se ven los tejados
/// de las casas de delante con casas encendidas detrás.
///
/// La escena va escrita aquí entera y no sacada de ninguna herramienta: lo que
/// este test mide es un rectángulo de píxeles, y un rectángulo de píxeles sólo
/// quiere decir algo si lo que hay debajo no se mueve.
Future<ui.Image> _frame() async {
  final l = TownLayout(38, TownCharacter.all.first, seed: 21);
  final cam = OrbitCamera()
    ..yaw = 0.68
    ..pitch = 0.30
    ..focusY = 2.2
    ..distance = 26
    ..wallLength = l.radius * 2;
  final pal = Palette.forMoment(
    19.8,
    1.0,
    season: Season.on(DateTime(2026, 5, 20), Hemisphere.north),
  );
  final scene = TownScene(
    placed: 38,
    palette: pal,
    camera: cam,
    integrity: 1,
    time: 7.3,
    hourOfDay: 19.8,
    effects: EffectSystem(),
    labelledBricks: const {},
    budget: 60000,
    towns: [
      TownEntry(
        layout: l,
        name: 'Leer',
        symbol: 'libro',
        integrity: 1,
        placed: 38,
      ),
    ],
    active: 0,
    labels: false,
  );
  final rec = ui.PictureRecorder();
  TownPainter(
    scene,
    TouchMap(),
  ).paint(Canvas(rec), const Size(_w * 1.0, _h * 1.0));
  return rec.endRecording().toImage(_w, _h);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la luz de una ventana no atraviesa lo que tiene delante', () async {
    // El fallo, tal cual se vio en un teléfono: el resplandor de las ventanas
    // se pintaba al final, sobre el pueblo ya levantado, y este rasterizador
    // no tiene búfer de profundidad. Así que la luz de las ventanas de la fila
    // de atrás salía **a través** de la casa de delante, y los tejados que las
    // tapan aparecían con manchas cálidas encima.
    //
    // **Cómo se mide sin comparar con una imagen guardada.** Una cara plana se
    // pinta de un color plano: por dentro de un tejado, quitando los cantos,
    // no puede haber más que un puñado de tonos. Un resplandor pintado encima
    // en el espacio de la pantalla es un degradado, y un degradado sobre una
    // cara plana se delata contando colores. No hace falta saber de qué color
    // es el tejado ni dónde cae la luz: basta con que el tejado sea de un
    // color.
    //
    // El rectángulo es el tejado de pizarra de la casa de abajo, que en esta
    // escena tiene casas encendidas justo detrás. Medido sobre las dos
    // versiones: con el resplandor al final salían **462** tonos distintos
    // ahí dentro; con cada halo en su sitio del orden de pintado, 58 — los del
    // caballete y los cantos.
    final img = await _frame();
    final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    expect(raw, isNotNull);
    final px = raw!.buffer.asUint8List();

    final tonos = <int>{};
    for (var y = 846; y < 866; y++) {
      for (var x = 355; x < 455; x++) {
        final i = (y * _w + x) * 4;
        tonos.add((px[i] << 16) | (px[i + 1] << 8) | px[i + 2]);
      }
    }
    expect(
      tonos.length,
      lessThan(150),
      reason:
          'el tejado tiene ${tonos.length} tonos distintos: algo le está '
          'pintando un degradado encima',
    );
  });
}
