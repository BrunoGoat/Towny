// La estrella fugaz sola, para mirarla de cerca.
//
//   flutter test tool/star_shot_test.dart --dart-define=OUT=/tmp/fugaz.png
//
// No prueba nada. A la izquierda, entera sobre un cielo de noche y a la
// densidad de un teléfono (tres píxeles por punto); a la derecha, la cabeza
// ampliada cuatro veces sin suavizar, para ver si está nítida o borrosa.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/engine/shooting_star.dart';
import 'package:towny/engine/star_draw.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fugaz', () async {
    const out = String.fromEnvironment('OUT', defaultValue: '/tmp/fugaz.png');
    const w = 390.0, h = 300.0, dpr = 3.0;
    const star = ShootingStar(
      id: 7,
      az0: -0.35,
      el0: 0.42,
      sweep: 0.7,
      drop: 0.22,
      u: 0.55,
      glow: 1,
      light: 0,
      spin: 0.3,
    );
    Offset? aim(double az, double el) => Offset(w / 2 + az * 420, h - el * 420);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(dpr);
    c.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h), [
          const Color(0xFF090E1C),
          const Color(0xFF27314C),
        ]),
    );
    StarDraw.sky(c, const Size(w, h), aim, h, star, 1);
    final img = await rec.endRecording().toImage(
      (w * dpr).toInt(),
      (h * dpr).toInt(),
    );
    final a = star.aim(star.u)!;
    final head = aim(a.$1, a.$2)! * dpr;
    final rec2 = ui.PictureRecorder();
    final c2 = Canvas(rec2);
    c2.drawImage(img, Offset.zero, Paint());
    const lado = 120.0, zoom = 4.0;
    c2.drawImageRect(
      img,
      Rect.fromCenter(center: head, width: lado, height: lado),
      Rect.fromLTWH(w * dpr, 0, lado * zoom, lado * zoom),
      Paint()..filterQuality = FilterQuality.none,
    );
    final todo = await rec2.endRecording().toImage(
      (w * dpr + lado * zoom).toInt(),
      (h * dpr).toInt(),
    );
    final png = await todo.toByteData(format: ui.ImageByteFormat.png);
    File(out)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
