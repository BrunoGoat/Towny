import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/core/math3.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/engine/mason.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/scene.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/fx/effects.dart';

/// El vocabulario del albañil, una palabra por casilla.
///
/// Una receta se escribe con estas dieciocho palabras y nada más, así que
/// escribir una a ciegas es adivinar. Esto las pone todas delante.
///
///   flutter test tool/vocab_sheet_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const out = '/tmp/marks';
  const lado = 430.0;
  const columnas = 4;

  test('el vocabulario', () async {
    Directory(out).createSync(recursive: true);
    final palabras = <String, void Function(Mason)>{
      'plinth + floor + roof': (m) {
        m.plinth(2.2, 1.9, 0.25);
        m.floor(1.9, 1.6, 1.1);
        m.roof(2.1, 1.8, 0.6);
      },
      'thatch': (m) {
        m.floor(1.9, 1.6, 1.1);
        m.box(PieceKind.thatch, 2.1, 1.8, 0.7);
      },
      'chimney + dormer': (m) {
        m.floor(2.4, 1.8, 1.2);
        m.roof(2.6, 2.0, 0.8);
        m.chimney(0.34, 1.0, dx: 0.7);
        m.dormer(0.7, 0.5, dx: -0.4, dz: 0.4);
      },
      'porch + parapet': (m) {
        m.floor(2.0, 1.8, 1.2);
        m.box(PieceKind.porch, 1.0, 0.6, 0.9, dz: 1.1, at: 0);
        m.parapet(2.2, 2.0, 0.4);
      },
      'spire': (m) {
        m.floor(1.2, 1.2, 2.4);
        m.spire(1.3, 1.3, 2.2);
      },
      'dome': (m) {
        m.floor(2.0, 2.0, 1.4);
        m.dome(2.1, 2.1, 1.3);
      },
      'arcade (x2 alturas)': (m) {
        m.arcade(3.4, 1.3, 0.7, rise: true);
        m.arcade(3.4, 1.0, 0.7, rise: true);
        m.roof(3.6, 0.9, 0.5);
      },
      'stair': (m) {
        m.plinth(2.0, 2.0, 0.9);
        m.stair(1.4, 0.9, 1.0, dz: 1.4);
      },
      'palisade': (m) {
        m.palisade(3.0, 0.9, dz: -1.4);
        m.palisade(3.0, 0.9, dz: 1.4);
        m.palisade(2.8, 0.9, dx: -1.5, along: false);
      },
      'banner': (m) {
        m.plinth(0.8, 0.8, 0.3);
        m.banner(2.4, at: 0.3);
      },
      'field + water': (m) {
        m.field(3.0, 2.0, dz: -1.2);
        m.water(3.0, 1.6, dz: 1.2);
      },
      'tree': (m) {
        m.tree(1.2, 2.0, dx: -0.9);
        m.tree(0.9, 1.5, dx: 0.9, dz: 0.6);
      },
      'wheel': (m) {
        m.floor(1.6, 1.6, 1.8);
        m.wheel(1.8, dx: 1.5);
        m.water(3.4, 1.2, dx: 1.2);
      },
      'sails': (m) {
        m.shaft(1.8, 3, 0.9, taper: 0.18);
        m.roof(1.7, 1.7, 0.6);
        m.sails(3.2, dz: -1.0, at: 2.4);
      },
      'post + beam': (m) {
        m.post(0.2, 2.0, dx: -0.8);
        m.post(0.2, 2.0, dx: 0.8);
        m.beam(2.0, 0.24, 0.24, at: 2.0);
      },
      'outbuilding + hall': (m) {
        m.hall(3.0, 1.6, 1.3, 0.7);
        m.outbuilding(1.2, 1.0, 0.8, 0.4, dx: 1.9, dz: 1.0);
      },
    };

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final filas = (palabras.length + columnas - 1) ~/ columnas;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, lado * columnas, lado * filas),
      Paint()..color = const Color(0xFF1A1D22),
    );
    var i = 0;
    for (final e in palabras.entries) {
      final l = Landmark('v$i', e.key, 40, 1, 'Vocabulario.', e.value);
      canvas.save();
      canvas.translate((i % columnas) * lado, (i ~/ columnas) * lado);
      canvas.clipRect(const Rect.fromLTWH(0, 0, lado, lado));
      _retrato(canvas, l);
      _rotulo(canvas, e.key);
      canvas.restore();
      i++;
    }
    final img = await rec.endRecording().toImage(
      (lado * columnas).round(),
      (lado * filas).round(),
    );
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/vocabulario.png').writeAsBytesSync(png!.buffer.asUint8List());
    img.dispose();
    // ignore: avoid_print
    print('escrita en $out/vocabulario.png');
  });
}

void _retrato(Canvas canvas, Landmark l) {
  final ch = TownCharacter.all.first;
  final m = Mason(0, 0, 0x5EED, true);
  l.build(m);
  final layout = TownLayout.showcase(ch, landmark: l, placed: m.count);
  var top = 1.0;
  for (final p in layout.pieces) {
    if (p.y1 > top) top = p.y1;
  }
  final cam = OrbitCamera()
    ..yaw = 0.62
    ..pitch = 0.38
    ..focusY = top * 0.45
    ..distance = clampD(math.max(layout.radius * 2.1, top * 2.6), 6, 60)
    ..wallLength = layout.radius * 2;
  TownPainter(
    TownScene(
      placed: m.count,
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
          placed: m.count,
        ),
      ],
      active: 0,
      labels: false,
    ),
    TouchMap(),
  ).paint(canvas, const Size(430, 430));
}

void _rotulo(Canvas canvas, String texto) {
  final p = TextPainter(
    text: TextSpan(
      text: texto,
      style: const TextStyle(
        color: Color(0xFFF3EEE3),
        fontSize: 16,
        fontWeight: FontWeight.w600,
        shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 410);
  p.paint(canvas, const Offset(10, 398));
}
