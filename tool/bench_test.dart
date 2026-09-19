import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/core/math3.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/backdrop.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/scene.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/engine/world.dart';
import 'package:la_muralla/fx/effects.dart';

/// Cuánto cuesta un fotograma, y dónde se va el tiempo.
///
///   flutter test tool/bench_test.dart
///
/// No es un test: no afirma nada. Es el cronómetro con el que se decide qué
/// vale la pena optimizar, porque a ojo siempre se acierta en lo que no es.
const _size = Size(390, 844);

TownScene _escena(int piezas, {int pueblos = 1, double yaw = 0.6}) {
  final cam = OrbitCamera()
    ..yaw = yaw
    ..pitch = 0.34
    ..distance = 40
    ..focusY = 2.0;
  final towns = <TownEntry>[];
  for (var k = 0; k < pueblos; k++) {
    final ch = TownCharacter.all[k % TownCharacter.all.length];
    final l = TownLayout(piezas, ch, cx: k * 124.0, cz: 0, seed: 7 + k);
    towns.add(
      TownEntry(
        layout: l,
        name: 'Pueblo $k',
        symbol: 'libro',
        integrity: 1,
        placed: piezas,
      ),
    );
  }
  cam.wallLength = towns.first.layout.radius * 2;
  return TownScene(
    placed: piezas,
    palette: Palette.forMoment(14, 1.0),
    camera: cam,
    integrity: 1,
    time: 3.0,
    hourOfDay: 14,
    effects: EffectSystem(),
    labelledBricks: const {},
    towns: towns,
    active: 0,
  );
}

double _cronometra(TownScene scene, {int vueltas = 40}) {
  final hits = TouchMap();
  // Una vuelta en frío para que la caché del pueblo esté puesta: lo que se
  // mide es un fotograma de los sesenta, no el primero de todos.
  final rec0 = ui.PictureRecorder();
  TownPainter(scene, hits).paint(Canvas(rec0), _size);
  rec0.endRecording().dispose();
  final reloj = Stopwatch()..start();
  for (var i = 0; i < vueltas; i++) {
    final rec = ui.PictureRecorder();
    TownPainter(scene, hits).paint(Canvas(rec), _size);
    rec.endRecording().dispose();
  }
  reloj.stop();
  return reloj.elapsedMicroseconds / vueltas / 1000.0;
}

/// Sólo el fondo: cielo, suelo y cordilleras. Se puede medir aparte porque
/// quedó en su propia clase, que es media razón por la que se separó.
double _cronometraFondo(TownScene scene, {int vueltas = 40}) {
  final p = scene.camera.projector(_size.width, _size.height, scene.time);
  final y = horizonOf(p, _size);
  final fondo = Backdrop(scene, []);
  final rec0 = ui.PictureRecorder();
  final c0 = Canvas(rec0);
  fondo.drawSky(c0, _size, p, y);
  rec0.endRecording().dispose();

  final reloj = Stopwatch()..start();
  for (var i = 0; i < vueltas; i++) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    fondo.drawSky(c, _size, p, y);
    fondo.drawGround(c, _size, y);
    fondo.drawRanges(c, p, _size, y);
    fondo.drawAtmosphere(c, _size, y);
    rec.endRecording().dispose();
  }
  reloj.stop();
  return reloj.elapsedMicroseconds / vueltas / 1000.0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cuánto cuesta un fotograma', () {
    // ignore: avoid_print
    print('\n  piezas  pueblos   total    fondo   pueblo   caras');
    for (final (n, p) in [
      (60, 1),
      (200, 1),
      (600, 1),
      (1500, 1),
      (600, 2),
      (600, 6),
    ]) {
      final s = _escena(n, pueblos: p);
      var caras = 0;
      for (final e in s.towns) {
        caras += builtTown(
          e.layout,
          e.placed,
        ).clusters.fold<int>(0, (a, c) => a + c.faces);
      }
      // ignore: avoid_print
      final t = _cronometra(s);
      final f = _cronometraFondo(s);
      print(
        '  ${n.toString().padLeft(6)}  ${p.toString().padLeft(7)}  '
        '${t.toStringAsFixed(2).padLeft(6)}  '
        '${f.toStringAsFixed(2).padLeft(6)}  '
        '${(t - f).toStringAsFixed(2).padLeft(7)}  '
        '${caras.toString().padLeft(6)}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
