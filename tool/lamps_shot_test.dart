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

/// Un pueblo pequeño al anochecer, que es cuando se vio el fallo: el
/// resplandor de las ventanas de atrás atravesando las casas de delante.
///
///   flutter test tool/lamps_shot_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('las ventanas', () async {
    final salida = Platform.environment['LAMPS_OUT'] ?? '/tmp/lamps/ahora';
    const w = 720, h = 1280;
    final ch = TownCharacter.all.first;
    final l = TownLayout(38, ch, seed: 21);

    // Dos encuadres: el de lejos, donde se veían las manchas sobre los
    // tejados, y uno pegado, como la primera captura.
    final planos = <String, (double, double, double)>{
      'lejos': (26.0, 0.30, 19.8),
      'cerca': (11.0, 0.16, 19.8),
    };
    for (final e in planos.entries) {
      final (dist, pitch, hora) = e.value;
      final cam = OrbitCamera()
        ..yaw = 0.68
        ..pitch = pitch
        ..focusY = 2.2
        ..distance = dist
        ..wallLength = l.radius * 2;
      final pal = Palette.forMoment(
        hora,
        1.0,
        season: Season.on(DateTime(2026, 5, 20), Hemisphere.north),
      );
      final scene = TownScene(
        placed: 38,
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
      ).paint(Canvas(rec), const Size(w * 1.0, h * 1.0));
      final img = await rec.endRecording().toImage(w, h);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('$salida-${e.key}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
      // ignore: avoid_print
      print('escrito ${f.path}');
      img.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
