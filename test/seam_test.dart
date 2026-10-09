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

const int _w = 500, _h = 700;

/// Dos pisos uno encima del otro tienen que leerse como una sola pared.
///
/// Lo que se vio en un teléfono, de noche: entre el primer piso y el segundo
/// había una raya recta, el de abajo más claro que el de arriba. Era el
/// resplandor de las ventanas de abajo, que se pintaba justo detrás de su
/// ventana; el piso de arriba es otro grupo del árbol y se pintaba después,
/// así que su pared tapaba la mitad de arriba del resplandor y lo cortaba en
/// seco por la junta.
///
/// Se mide el salto de color a un lado y otro de la junta, sobre la pared y
/// fuera de las ventanas, comparado con el salto entre dos puntos igual de
/// separados dentro de un mismo piso.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final hora in [13.0, 22.0]) {
    test('sin raya entre pisos a las ${hora.toInt()}', () async {
      final l = TownLayout(3, TownCharacter.all.first, seed: 21);
      final abajo = l.pieces[1], arriba = l.pieces[2];
      expect(abajo.kind.name, 'floor');
      expect(arriba.kind.name, 'floor');
      final cam = OrbitCamera()
        ..yaw = 0.68
        ..pitch = 0.3
        ..focusY = 1.5
        ..distance = 6
        ..travel = abajo.cx
        ..focusZ = abajo.cz
        ..wallLength = l.radius * 2;
      final hits = TouchMap();
      final scene = TownScene(
        placed: 3,
        palette: Palette.forMoment(hora),
        camera: cam,
        time: 7.3,
        hourOfDay: hora,
        effects: EffectSystem(),
        budget: 60000,
        towns: [TownEntry(layout: l, name: 'L', symbol: 'libro', placed: 3)],
        active: 0,
        labels: false,
        folk: false,
        ghost: false,
      );
      final rec = ui.PictureRecorder();
      TownPainter(
        scene,
        hits,
      ).paint(Canvas(rec), const Size(_w * 1.0, _h * 1.0));
      final img = await rec.endRecording().toImage(_w, _h);
      final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final px = raw!.buffer.asUint8List();
      final p = cam.projector(_w * 1.0, _h * 1.0, scene.time);

      double luz(Offset o) {
        final i = (o.dy.round() * _w + o.dx.round()) * 4;
        return 0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2];
      }

      bool amarillo(Offset o) {
        final i = (o.dy.round() * _w + o.dx.round()) * 4;
        return px[i] - px[i + 2] > 45;
      }

      // Por las cuatro paredes, de punta a punta y a la altura de la junta.
      final y = abajo.y1;
      var medidas = 0;
      var peorJunta = 0.0;
      final x0 = abajo.x0, x1 = abajo.x1, z0 = abajo.z0, z1 = abajo.z1;
      for (final (a, b) in [
        (V3(x0, y, z0), V3(x1, y, z0)),
        (V3(x1, y, z0), V3(x1, y, z1)),
        (V3(x1, y, z1), V3(x0, y, z1)),
        (V3(x0, y, z1), V3(x0, y, z0)),
      ]) {
        for (var t = 0.05; t < 0.96; t += 0.05) {
          final w = V3(a.x + (b.x - a.x) * t, y, a.z + (b.z - a.z) * t);
          final c = p.project(w);
          if (c == null) continue;
          final o = Offset(c.x, c.y);
          const d = Offset(0, 3);
          // Las cuatro muestras tienen que caer en las paredes de esta casa.
          final muestras = [o - d * 2, o - d, o + d, o + d * 2];
          if (!muestras.every((m) => (hits.ownerAt(m.dx, m.dy) ?? -1) >= 1)) {
            continue;
          }
          // Y en la pared, no en una ventana: una ventana encendida es
          // amarilla y la pared no.
          if (muestras.any((m) => amarillo(m))) continue;
          // Sólo donde la pared es lisa a los dos lados —ni canto de
          // ventana ni esquina—: ahí cualquier salto es la junta.
          final dentro = math.max(
            (luz(o - d * 2) - luz(o - d)).abs(),
            (luz(o + d) - luz(o + d * 2)).abs(),
          );
          if (dentro > 3) continue;
          // Un salto de golpe de cuarenta tonos no es luz, es el canto de una
          // ventana que cae justo en la junta.
          if ((luz(o - d) - luz(o + d)).abs() > 40) continue;
          medidas++;
          peorJunta = math.max(peorJunta, (luz(o - d) - luz(o + d)).abs());
        }
      }
      expect(medidas, greaterThan(0), reason: 'no se vio la junta');
      expect(
        peorJunta,
        lessThan(7),
        reason: 'salto de $peorJunta en la junta entre los dos pisos',
      );
    });
  }
}
