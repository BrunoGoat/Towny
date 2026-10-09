// Las casas simplificadas de lejos, para mirarlas.
//
//   flutter test tool/simple_shot_test.dart --dart-define=OUT=/tmp/simple.png
//
// Tres filas del mismo valle: con presupuesto de sobra, con poco y sin la
// versión simple (lo que no cabe no se pinta), y con poco y con ella. De día a
// la izquierda y de noche a la derecha.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('casas simples', () async {
    const out = String.fromEnvironment('OUT', defaultValue: '/tmp/simple.png');
    const w = 720, h = 420;
    const piezas = 300;
    final towns = [
      for (var k = 0; k < 3; k++)
        TownEntry(
          layout: TownLayout(
            piezas,
            TownCharacter.all[k],
            cx: k * 124.0,
            cz: 0,
            seed: 7 + k,
          ),
          name: 'Pueblo $k',
          symbol: 'libro',
          placed: piezas,
        ),
    ];
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    const tope = int.fromEnvironment('BUDGET', defaultValue: 2500);
    final filas = [(60000, true), (tope, false), (tope, true)];
    for (var f = 0; f < filas.length; f++) {
      final (budget, simple) = filas[f];
      for (var c = 0; c < 2; c++) {
        final hora = c == 0 ? 14.0 : 22.5;
        final cam = OrbitCamera()
          ..yaw = 0.25
          ..pitch = 0.32
          ..distance =
              const int.fromEnvironment('DIST', defaultValue: 150) * 1.0
          ..focusY = 2.0
          ..travel =
              const int.fromEnvironment('TRAVEL', defaultValue: 124) * 1.0;
        cam.wallLength = towns.first.layout.radius * 2;
        TownPainter.simplifying = simple;
        final painter = TownPainter(
          TownScene(
            placed: piezas,
            palette: Palette.forMoment(hora),
            camera: cam,
            time: 3.0,
            hourOfDay: hora,
            effects: EffectSystem(),
            towns: towns,
            active: 0,
            budget: budget,
            labels: false,
          ),
          TouchMap(),
        );
        canvas.save();
        canvas.translate(c * w * 1.0, f * h * 1.0);
        canvas.clipRect(const Rect.fromLTWH(0, 0, w * 1.0, h * 1.0));
        painter.paint(canvas, const Size(w * 1.0, h * 1.0));
        canvas.restore();
        // ignore: avoid_print
        print(
          'presupuesto $budget simple $simple: '
          'simples ${painter.simplifiedWorks} '
          'sin pintar ${painter.unaffordableWorks}',
        );
      }
    }
    TownPainter.simplifying = true;
    final img = await rec.endRecording().toImage(w * 2, h * filas.length);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
