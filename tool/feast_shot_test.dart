// El viejo dando de comer a las palomas, de cerca, para mirar si el pan y
// las palomas se ven sobre la plaza o se meten en ella.
//
//   flutter test tool/feast_shot_test.dart --dart-define=OUT=/tmp/migas.png
//
// No prueba nada: es para mirar. Busca un momento en que haya migas en el
// suelo y palomas comiendo, y lo saca desde varios ángulos.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/folk.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/pigeons.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/solids.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';

final double _hora = double.parse(
  const String.fromEnvironment('HORA', defaultValue: '17.2'),
);

double _num(String k, double d) =>
    double.tryParse(
      const {
            'PITCH': String.fromEnvironment('PITCH'),
            'DIST': String.fromEnvironment('DIST'),
          }[k] ??
          '',
    ) ??
    d;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('las migas y las palomas', () async {
    const out = String.fromEnvironment('OUT', defaultValue: '/tmp/migas.png');
    const piezas = int.fromEnvironment('PIEZAS', defaultValue: 12);
    const w = 380, h = 380;
    final l = TownLayout(piezas, TownCharacter.all[0], seed: 7);
    final sabio = folkOf(l, piezas).firstWhere((v) => v.sage);
    final talla = TownPainter.folkHeight(l.character);
    // Un momento con migas en el suelo y palomas.
    double? cuando;
    for (var t = 0.0; t < 20000 && cuando == null; t += 0.5) {
      final f = sageFeast(sabio, l, t, h: talla * sabio.build);
      if (f != null && f.pigeons.length >= 3 && f.crumbs.length >= 6) {
        cuando = t;
      }
    }
    if (cuando == null) fail('no se encontró una comida');
    final bx = PlazaBench.xAt(l.cx), bz = PlazaBench.zAt(l.cz);
    final fx = math.sin(PlazaBench.turn), fz = math.cos(PlazaBench.turn);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final tomas = [
      for (final g in [0.6, 1.2, 1.8, 2.4, 3.0, 3.6])
        (g, _num('PITCH', 0.75), _num('DIST', 1.5)),
    ];
    for (var i = 0; i < tomas.length; i++) {
      final (giro, alto, lejos) = tomas[i];
      final cam = OrbitCamera()
        ..yaw = PlazaBench.turn + giro
        ..pitch = alto
        ..travel = bx + fx * 0.6
        ..focusZ = bz + fz * 0.6
        ..focusY = 0.1
        ..distance = lejos;
      canvas.save();
      canvas.translate((i % 3) * w * 1.0, (i ~/ 3) * h * 1.0);
      canvas.clipRect(const Rect.fromLTWH(0, 0, w * 1.0, h * 1.0));
      TownPainter(
        TownScene(
          placed: piezas,
          palette: Palette.forMoment(_hora),
          camera: cam,
          time: cuando,
          hourOfDay: _hora,
          effects: EffectSystem(),
          budget: 60000,
          towns: [
            TownEntry(layout: l, name: 'Leer', symbol: 'book', placed: piezas),
          ],
          active: 0,
          labels: false,
          cinematic: true,
        ),
        TouchMap(),
      ).paint(canvas, const Size(w * 1.0, h * 1.0));
      canvas.restore();
    }
    final img = await rec.endRecording().toImage(w * 3, h * 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
    // ignore: avoid_print
    print('escrito $out a los $cuando s');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
