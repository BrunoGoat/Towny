import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/core/math3.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/scene.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/fx/effects.dart';

/// El catálogo entero en hojas de contacto, para poder mirarlo.
///
/// Un hito se ve una vez cada dos o tres semanas dentro de un pueblo, y la
/// mitad no le sale a nadie en un año: desde dentro de la app el catálogo es
/// invisible. La sala de exposición lo enseña de uno en uno, que sirve para
/// juzgar uno; esto lo enseña de doce en doce, que es lo que hace falta para
/// juzgar el conjunto — si se parecen entre sí, si hay piezas volando, si
/// alguno no se entiende.
///
///   flutter test tool/marks_sheet_test.dart
///
/// Con `SOLO` se miran unos pocos, y con `GIRO` y `REGION` el mismo desde
/// otro lado o en otra comarca.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const out = '/tmp/marks';
  const solo = String.fromEnvironment('SOLO');
  const region = int.fromEnvironment('REGION', defaultValue: 0);
  const giro = int.fromEnvironment('GIRO', defaultValue: 36);
  const lado = 430.0;
  const columnas = 4, filas = 3;

  test('el catálogo en hojas de contacto', () async {
    Directory(out).createSync(recursive: true);
    final quiero = solo.isEmpty ? <String>{} : solo.split(',').toSet();
    final cuales = [
      for (final l in landmarks)
        if (quiero.isEmpty || quiero.contains(l.id)) l,
    ];

    final ch = TownCharacter.all[region % TownCharacter.all.length];
    var hoja = 0;
    for (var desde = 0; desde < cuales.length; desde += columnas * filas) {
      final tanda = cuales.skip(desde).take(columnas * filas).toList();
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, lado * columnas, lado * filas),
        Paint()..color = const Color(0xFF1A1D22),
      );
      for (var i = 0; i < tanda.length; i++) {
        final col = i % columnas, fila = i ~/ columnas;
        canvas.save();
        canvas.translate(col * lado, fila * lado);
        canvas.clipRect(const Rect.fromLTWH(0, 0, lado, lado));
        _retrato(canvas, tanda[i], ch, giro * math.pi / 180);
        _rotulo(canvas, '${tanda[i].name} · ${tanda[i].cost}');
        canvas.restore();
      }
      final img = await rec.endRecording().toImage(
        (lado * columnas).round(),
        (lado * filas).round(),
      );
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final nombre = solo.isEmpty ? 'hoja-$hoja' : 'solo-$hoja';
      File('$out/$nombre.png').writeAsBytesSync(png!.buffer.asUint8List());
      img.dispose();
      hoja++;
    }
    // ignore: avoid_print
    print('$hoja hojas con ${cuales.length} obras en $out');
  });
}

void _retrato(Canvas canvas, Landmark l, TownCharacter ch, double giro) {
  final layout = TownLayout.showcase(ch, landmark: l, placed: l.cost);
  var top = 1.0;
  for (final p in layout.pieces) {
    if (p.y1 > top) top = p.y1;
  }
  final cam = OrbitCamera()
    ..yaw = giro
    ..pitch = 0.38
    ..focusY = top * 0.45
    ..distance = clampD(math.max(layout.radius * 2.1, top * 2.6), 6, 60)
    ..wallLength = layout.radius * 2;
  final scene = TownScene(
    placed: l.cost,
    palette: Palette.forMoment(11, 1.0),
    camera: cam,
    integrity: 1,
    time: 3.0,
    hourOfDay: 11,
    effects: EffectSystem(),
    labelledBricks: const {},
    budget: 22000,
    towns: [
      TownEntry(
        layout: layout,
        name: l.name,
        symbol: 'torre',
        integrity: 1,
        placed: l.cost,
      ),
    ],
    active: 0,
    labels: false,
  );
  TownPainter(scene, TouchMap()).paint(canvas, const Size(430, 430));
}

void _rotulo(Canvas canvas, String texto) {
  final p = TextPainter(
    text: TextSpan(
      text: texto,
      style: const TextStyle(
        color: Color(0xFFF3EEE3),
        fontSize: 15,
        fontWeight: FontWeight.w600,
        shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 410);
  p.paint(canvas, const Offset(10, 398));
}
