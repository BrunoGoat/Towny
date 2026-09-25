import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/scene.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/fx/effects.dart';

const int _w = 560, _h = 560;

/// El molino solo, mirado **desde detrás de las aspas**, que es donde se veía
/// el fallo: la cara norte de la torre, con el disco de las aspas al otro lado.
Future<ui.Image> _frame(double giro) async {
  final l = landmarks.firstWhere((m) => m.id == 'molinoViento');
  final layout = TownLayout.showcase(
    TownCharacter.all.first,
    landmark: l,
    placed: l.cost,
  );
  var alto = 1.0;
  for (final p in layout.pieces) {
    if (p.y1 > alto) alto = p.y1;
  }
  final cam = OrbitCamera()
    ..yaw = giro
    ..pitch = 0.30
    ..focusY = alto * 0.45
    ..distance = 15
    ..wallLength = layout.radius * 2;
  final rec = ui.PictureRecorder();
  TownPainter(
    TownScene(
      placed: l.cost,
      palette: Palette.forMoment(11, 1.0),
      camera: cam,
      integrity: 1,
      time: 2.0,
      hourOfDay: 11,
      effects: EffectSystem(),
      labelledBricks: const {},
      budget: 40000,
      towns: [
        TownEntry(
          layout: layout,
          name: 'Molino',
          symbol: 'torre',
          integrity: 1,
          placed: l.cost,
        ),
      ],
      active: 0,
      labels: false,
    ),
    TouchMap(),
  ).paint(Canvas(rec), const Size(_w * 1.0, _h * 1.0));
  return rec.endRecording().toImage(_w, _h);
}

/// Cuántos píxeles de madera oscura hay en un rectángulo.
///
/// La madera de las aspas es lo único a la vez **oscuro y cálido** que tiene
/// un molino por arriba: la pizarra del chapitel es fría —le gana el azul— y
/// la piedra de la torre es clara. Los huecos de las ventanas también son
/// oscuros y cálidos, y por eso el rectángulo se mide sobre el chapitel, que
/// no tiene ninguna.
Future<int> _madera(ui.Image img, int x0, int y0, int x1, int y1) async {
  final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = raw!.buffer.asUint8List();
  var n = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * _w + x) * 4;
      final r = px[i], g = px[i + 1], b = px[i + 2];
      if (r < 140 && r > g && g > b) n++;
    }
  }
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('las aspas no se ven a través del molino', () async {
    // El fallo, tal cual se vio: mirando el molino desde el lado contrario a
    // las aspas, el aspa se pintaba **encima** de la torre y la cruzaba de
    // lado a lado.
    //
    // La causa no era el dibujo sino el orden: la caja con la que se ordenan
    // las aspas se inflaba lo que miden de ancho hacia los cuatro lados, así
    // que un aspa de cuatro metros llevaba una caja de doce por doce que se
    // tragaba la torre entera. Dos cuerpos que no se pueden separar con un
    // plano no tienen orden, y el que salía dependía del ángulo.
    //
    // **Cómo se mide.** Las aspas son lo único de madera oscura que tiene un
    // molino —la torre es piedra clara y el chapitel pizarra—, así que basta
    // con contar píxeles oscuros dentro del cuerpo de la torre. Medido sobre
    // las dos versiones, en el rectángulo de abajo: con la caja inflada,
    // había aspa pintada sobre la piedra; con la caja del disco, no.
    final img = await _frame(0.0);
    final dentro = await _madera(img, 265, 195, 305, 218);
    img.dispose();
    expect(
      dentro,
      lessThan(15),
      reason:
          'hay $dentro píxeles de aspa pintados sobre el chapitel: se están '
          'viendo a través del molino',
    );
  });

  test('y desde el otro lado sí se ven, que para eso están', () async {
    // La otra mitad: arreglar el orden no puede querer decir esconderlas. De
    // frente, las aspas pasan por delante de la torre y se tienen que ver.
    final img = await _frame(3.14159);
    final dentro = await _madera(img, 265, 195, 305, 218);
    img.dispose();
    expect(
      dentro,
      greaterThan(35),
      reason:
          'de frente las aspas tendrían que cruzar el chapitel, y hay $dentro',
    );
  });
}
