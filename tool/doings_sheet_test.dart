import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/doings.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/engine/folk.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/scene.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/fx/effects.dart';

/// Todas las cosas que hace la gente, en hojas de contacto.
///
/// El expositor de la app enseña una y sirve para ver si **ésa** se entiende.
/// Lo que hay que ver es otra cosa: si se distinguen **entre sí**. Dos filas
/// de la tabla con nombres distintos y el mismo gesto son una sola actividad
/// con dos nombres, y eso sólo se ve poniéndolas al lado.
///
/// Cada casilla es la misma persona en cuatro instantes del gesto, uno encima
/// de otro, para que se vea el movimiento y no una foto quieta.
///
///   flutter test tool/doings_sheet_test.dart
///
/// Con `GIRO` se le da la vuelta —para comprobar que lo que lleva no le sale
/// por la espalda— y con `SOLO` se miran unas pocas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const out = '/tmp/gente';
  const solo = String.fromEnvironment('SOLO');
  const giro = int.fromEnvironment('GIRO', defaultValue: 36);
  const ancho = 250.0, alto = 200.0;
  const momentos = [0.0, 1.1, 2.2, 3.3];
  const porHoja = 5;

  test('la gente, cuatro instantes cada una', () async {
    Directory(out).createSync(recursive: true);
    final quiero = solo.isEmpty ? <String>{} : solo.split(',').toSet();
    final cuales = [
      Doing.idle,
      ...Doing.all,
    ].where((d) => quiero.isEmpty || quiero.contains(d.id)).toList();

    var hoja = 0;
    for (var desde = 0; desde < cuales.length; desde += porHoja) {
      final tanda = cuales.skip(desde).take(porHoja).toList();
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      final w = ancho * momentos.length, h = alto * tanda.length;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF1A1D22),
      );
      for (var i = 0; i < tanda.length; i++) {
        final d = tanda[i];
        for (var k = 0; k < momentos.length; k++) {
          canvas.save();
          canvas.translate(k * ancho, i * alto);
          canvas.clipRect(const Rect.fromLTWH(0, 0, ancho, alto));
          _retrato(
            canvas,
            d,
            momentos[k],
            giro * 3.14159 / 180,
            const Size(ancho, alto),
          );
          canvas.restore();
        }
        canvas.save();
        canvas.translate(0, i * alto);
        _rotulo(canvas, '${d.id} · ${d.name}', alto);
        canvas.restore();
      }
      final img = await rec.endRecording().toImage(w.round(), h.round());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final nombre = solo.isEmpty ? 'hoja-$hoja' : 'solo-$hoja';
      File('$out/$nombre.png').writeAsBytesSync(png!.buffer.asUint8List());
      img.dispose();
      hoja++;
    }
    // ignore: avoid_print
    print('$hoja hojas con ${cuales.length} actividades en $out');
  });
}

void _retrato(Canvas canvas, Doing d, double t, double giro, Size size) {
  final quien = Townsfolk.showcase(d, kid: d.who == Who.kid);
  final cam = OrbitCamera()
    ..yaw = giro
    ..pitch = 0.18
    ..distance = 1.30
    ..focusY = 0.27
    ..wallLength = 4;
  TownPainter(
    TownScene(
      placed: 0,
      palette: Palette.forMoment(11, 1.0),
      camera: cam,
      integrity: 1,
      time: t,
      hourOfDay: 11,
      effects: EffectSystem(),
      labelledBricks: const {},
      budget: 4000,
      towns: [
        TownEntry(
          layout: TownLayout.showcase(TownCharacter.all.first, placed: 0),
          name: d.name,
          symbol: 'torre',
          integrity: 1,
          placed: 0,
        ),
      ],
      active: 0,
      labels: false,
      soloFolk: quien,
    ),
    TouchMap(),
  ).paint(canvas, size);
}

void _rotulo(Canvas canvas, String texto, double alto) {
  final p = TextPainter(
    text: TextSpan(
      text: texto,
      style: const TextStyle(
        color: Color(0xFFF3EEE3),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 240);
  p.paint(canvas, Offset(8, alto - 22));
}
