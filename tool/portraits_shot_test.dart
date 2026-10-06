// Los retratos de las comarcas, todos juntos, para mirarlos y compararlos.
//
//   flutter test tool/portraits_shot_test.dart --dart-define=OUT=/tmp/retratos.png
//
// No prueba nada: es para mirar. Arriba Ribera, Sierra, Marca y Valle; abajo
// Costa, Robledal, Encrucijada y Alfar — el orden de la lista.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/ui/town_portrait.dart';

void main() {
  testWidgets('los retratos de las comarcas', (tester) async {
    const out = String.fromEnvironment(
      'OUT',
      defaultValue: '/tmp/retratos.png',
    );
    const hora = int.fromEnvironment('HOUR', defaultValue: 11);
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(1240, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFF2A2520),
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in TownCharacter.all)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 292,
                      height: 240,
                      child: CustomPaint(
                        painter: TownPortrait(
                          place: c,
                          palette: Palette.forMoment(hora.toDouble()),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage();
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(png!.buffer.asUint8List());
    });
    // ignore: avoid_print
    print('escrito $out');
  });
}
