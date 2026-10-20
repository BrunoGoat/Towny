import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/core/math3.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';
import 'package:towny/model/habit.dart';

/// Los carteles de los pueblos, vistos desde el valle.
void main() {
  test('desde el valle, todo pueblo que se ve tiene su nombre', () {
    // Cuando dos carteles se pisaban, el del pueblo de más lejos se ocultaba:
    // con dos pueblos casi en fila, según hacia dónde se girara la cámara el
    // otro pueblo se quedaba sin nombre. Ahora se pisan y ya.
    const size = Size(390, 844);
    final (cx, cz) = Habit.centreOf(1);
    final uno = TownLayout(8, TownCharacter.all.first, seed: 1);
    final dos = TownLayout(0, TownCharacter.all[1], cx: cx, cz: cz, seed: 2);
    final towns = [
      TownEntry(
        layout: uno,
        name: 'Saltar la cuerda',
        symbol: 'book',
        placed: 8,
      ),
      TownEntry(
        layout: dos,
        name: 'Aprontar las cosas',
        symbol: 'book',
        placed: 0,
      ),
    ];
    var probadas = 0;
    for (final pitch in [0.25, 0.40, 0.60]) {
      for (final lejos in [400.0, 700.0, 950.0]) {
        for (var k = 0; k < 72; k++) {
          final cam = OrbitCamera()
            ..reaches(-200, 200)
            ..focusY = 2
            ..yaw = k * math.pi / 36
            ..pitch = pitch
            ..distance = lejos;
          final p = cam.projector(size.width, size.height, 0);
          // Sólo cuenta si los dos pueblos están en pantalla.
          final a = p.project(const V3(0, 0, 0));
          final b = p.project(V3(cx, 0, cz));
          bool dentro(Offset2? o) =>
              o != null &&
              o.x > 60 &&
              o.x < size.width - 60 &&
              o.y > 120 &&
              o.y < size.height - 60;
          if (!dentro(a) || !dentro(b)) continue;
          final hits = TouchMap();
          TownPainter(
            TownScene(
              placed: 8,
              palette: Palette.forMoment(22),
              camera: cam,
              time: 3,
              hourOfDay: 22,
              effects: EffectSystem(),
              towns: towns,
              active: 0,
            ),
            hits,
          ).paint(Canvas(ui.PictureRecorder()), size);
          final carteles = <int>{
            for (var i = 0; i < hits.faceCount; i++)
              if (hits.faceOwner[i] == TouchMap.sign) hits.regionData[i],
          };
          expect(carteles, {
            0,
            1,
          }, reason: 'girando ${k * 5}°, inclinada $pitch, a $lejos');
          probadas++;
        }
      }
    }
    expect(probadas, greaterThan(20));
  });
}
