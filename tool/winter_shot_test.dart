// El valle en invierno a varias horas, para mirarlo de una vez.
//
//   flutter test tool/winter_shot_test.dart --dart-define=OUT=/tmp/invierno.png
//
// No prueba nada: es para mirar. Cuatro horas de un mismo día de enero en el
// norte —lo más crudo, con la nieve entera— y el mismo pueblo en las cuatro.
// MONTH y DAY cambian el día, por si hace falta ver la nieve llegando.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/season.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el valle en invierno', () async {
    const out = String.fromEnvironment(
      'OUT',
      defaultValue: '/tmp/invierno.png',
    );
    const mes = int.fromEnvironment('MONTH', defaultValue: 1);
    const dia = int.fromEnvironment('DAY', defaultValue: 25);
    const piezas = 160;
    const w = 800, h = 440;
    const horas = [10.5, 13.0, 16.6, 22.0];

    final l = TownLayout(piezas, TownCharacter.all[0], seed: 21);
    final season = Season.on(DateTime(2026, mes, dia), Hemisphere.north);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (var i = 0; i < horas.length; i++) {
      final hora = horas[i];
      final cam = OrbitCamera()
        ..yaw = 0.68
        ..pitch = 0.20
        ..focusY = 3.0
        ..wallLength = l.radius * 2
        ..distance = const int.fromEnvironment('DIST', defaultValue: 44) * 1.0;
      final pal = Palette.forMoment(hora, season: season);
      canvas.save();
      canvas.translate((i % 2) * w * 1.0, (i ~/ 2) * h * 1.0);
      canvas.clipRect(const Rect.fromLTWH(0, 0, w * 1.0, h * 1.0));
      TownPainter(
        TownScene(
          placed: piezas,
          palette: pal,
          camera: cam,
          time: 7.3,
          hourOfDay: hora,
          effects: EffectSystem(),
          budget: 60000,
          towns: [
            TownEntry(layout: l, name: 'Leer', symbol: 'libro', placed: piezas),
          ],
          active: 0,
          labels: false,
        ),
        TouchMap(),
      ).paint(canvas, const Size(w * 1.0, h * 1.0));
      canvas.restore();
    }
    final img = await rec.endRecording().toImage(w * 2, h * 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
    // ignore: avoid_print
    print(
      'escrito $out (snow ${season.snow.toStringAsFixed(2)}, bare ${season.bare.toStringAsFixed(2)})',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
