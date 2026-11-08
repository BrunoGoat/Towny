// Las capas de interfaz de la fiesta del valle, a un PNG por instante, para
// mirarlas sin levantar el pueblo:
//
//   flutter test tool/fiesta_ui_shot_test.dart --dart-define=KIND=sello --dart-define=OUT=/tmp/f
//
// No prueba nada: es para mirar.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/fx/fiesta.dart';
import 'package:towny/ui/fiesta_overlay.dart';

void main() {
  testWidgets('la fiesta, cuadro a cuadro', (tester) async {
    const kind = String.fromEnvironment('KIND', defaultValue: 'banderines');
    const out = String.fromEnvironment('OUT', defaultValue: '/tmp/fiesta');
    const pasos = String.fromEnvironment(
      'PASOS',
      defaultValue: '0.5,2,5.6,6.4',
    );
    final k = FiestaKind.values.firstWhere((v) => v.name == kind);
    final towns = [
      for (final (i, sym) in ['book', 'run', 'weight', 'lute', 'wave'].indexed)
        FiestaTown(x: i * 40.0, z: 0, radius: 10, symbol: sym, name: sym),
    ];
    await tester.binding.setSurfaceSize(const Size(400, 820));
    final show = Fiesta.instance.start(k, towns, 0);
    for (final p in pasos.split(',')) {
      show.steps = [double.parse(p)];
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: Container(
              color: const Color(0xFF5B8A3A),
              child: Stack(
                children: const [
                  Positioned.fill(child: FiestaOverlay(back: true)),
                  Positioned.fill(child: FiestaOverlay(back: false)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() async {
        final b =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/${kind}_$p.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    Fiesta.instance.stop();
  });
}
