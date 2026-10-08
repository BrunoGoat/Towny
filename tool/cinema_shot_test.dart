// La calidad máxima al lado de la normal, a varias horas, para mirarlo.
//
//   flutter test tool/cinema_shot_test.dart --dart-define=OUT=/tmp/cine.png
//
// No prueba nada: es para mirar. Cada fila es una hora; a la izquierda el
// pueblo como se ve siempre y a la derecha en calidad máxima. YAW gira la
// cámara —para ponerle el sol delante y ver los rayos— y MONTH cambia la
// estación.
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

  test('calidad máxima', () async {
    const out = String.fromEnvironment('OUT', defaultValue: '/tmp/cine.png');
    const mes = int.fromEnvironment('MONTH', defaultValue: 7);
    const yaw = String.fromEnvironment('YAW', defaultValue: '0.68');
    const horasDef = String.fromEnvironment(
      'HOURS',
      defaultValue: '9.0,13.0,19.3,22.5',
    );
    const piezas = 180;
    const w = 720, h = 420;
    final horas = horasDef.split(',').map(double.parse).toList();

    final l = TownLayout(piezas, TownCharacter.all[0], seed: 21);
    final season = Season.on(DateTime(2026, mes, 15), Hemisphere.north);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (var i = 0; i < horas.length; i++) {
      for (final cine in [false, true]) {
        final hora = horas[i];
        final cam = OrbitCamera()
          ..yaw = double.parse(yaw)
          ..pitch = double.parse(
            const String.fromEnvironment('PITCH', defaultValue: '0.22'),
          )
          ..focusY = 3.0
          ..wallLength = l.radius * 2
          ..distance =
              const int.fromEnvironment('DIST', defaultValue: 40) * 1.0;
        final pal = Palette.forMoment(hora, season: season);
        canvas.save();
        canvas.translate(cine ? w * 1.0 : 0, i * h * 1.0);
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
              TownEntry(
                layout: l,
                name: 'Leer',
                symbol: 'libro',
                placed: piezas,
              ),
            ],
            active: 0,
            labels: false,
            cinematic: cine,
          ),
          TouchMap(),
        ).paint(canvas, const Size(w * 1.0, h * 1.0));
        canvas.restore();
      }
    }
    final img = await rec.endRecording().toImage(w * 2, h * horas.length);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
    // ignore: avoid_print
    print('escrito $out');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
