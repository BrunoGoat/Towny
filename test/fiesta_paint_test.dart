// Pinta cada fiesta del valle a varios instantes sobre un lienzo de mentira,
// para cazar lo que reviente al pintar sin tener que abrir la web:
//
//   flutter test test/fiesta_paint_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/fiesta_painter.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/fx/fiesta.dart';

void main() {
  for (final k in FiestaKind.values) {
    test('${k.name} se pinta entera', () {
      final towns = [
        for (var i = 0; i < 4; i++)
          FiestaTown(
            x: i * 40.0 - 60,
            z: (i % 2) * 30.0,
            radius: 10,
            symbol: 'book',
            name: 'P$i',
          ),
      ];
      final show = FiestaShow(k, towns, 0, DateTime(2026, 11, 8));
      final cam = OrbitCamera()
        ..pitch = 0.2
        ..distance = 180
        ..focusY = 8;
      final p = cam.projector(400, 820, 0);
      for (var t = 0.0; t < show.length; t += 0.25) {
        final rec = PictureRecorder();
        paintFiesta(
          Canvas(rec),
          p,
          const Size(400, 820),
          Palette.forMoment(11),
          show,
          t,
        );
        rec.endRecording().dispose();
      }
    });
  }
}
