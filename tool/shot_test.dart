import 'dart:io';
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

/// Una foto del pueblo para el README.
///
///   flutter test tool/shot_test.dart --dart-define=OUT=doc/pueblo.png
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('una foto', () async {
    const out = String.fromEnvironment('OUT', defaultValue: 'doc/pueblo.png');
    const piezas = 430;
    const region = 0;
    const hora = 18.8;
    const yaw = 0.68;
    const pitch = 0.215;
    const w = 1500, h = 780;

    final ch = TownCharacter.all[region % TownCharacter.all.length];
    final l = TownLayout(piezas, ch, seed: 21);
    final cam = OrbitCamera()
      ..yaw = yaw
      ..pitch = pitch
      ..focusY = 3.0
      ..wallLength = l.radius * 2;
    // A la distancia justa para que quepa con aire alrededor.
    // A ojo, mirando el resultado: el pueblo mide veintisiete de radio y a
    // esta distancia llena el cuadro dejándole aire por los cuatro lados.
    cam.distance = 39;

    final pal = Palette.forMoment(
      hora,
      1.0,
      season: Season.on(DateTime(2026, 5, 20), Hemisphere.north),
    );
    final scene = TownScene(
      placed: piezas,
      palette: pal,
      camera: cam,
      integrity: 1,
      time: 7.3,
      hourOfDay: hora,
      effects: EffectSystem(),
      labelledBricks: const {},
      budget: 60000,
      towns: [
        TownEntry(
          layout: l,
          name: 'Leer',
          symbol: 'libro',
          integrity: 1,
          placed: piezas,
        ),
      ],
      active: 0,
      labels: false,
    );

    final rec = ui.PictureRecorder();
    TownPainter(
      scene,
      TouchMap(),
    ).paint(Canvas(rec), const Size(w * 1.0, h * 1.0));
    final img = await rec.endRecording().toImage(w, h);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
    // ignore: avoid_print
    print('escrito $out (${(png.lengthInBytes / 1024).round()} KB)');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
