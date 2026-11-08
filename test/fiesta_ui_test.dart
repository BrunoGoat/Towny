// La capa de interfaz de cada fiesta, a varios instantes, para cazar lo que
// reviente al pintar sin abrir la web:
//
//   flutter test test/fiesta_ui_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/fx/fiesta.dart';
import 'package:towny/ui/fiesta_overlay.dart';

void main() {
  for (final k in FiestaKind.values) {
    testWidgets('${k.name}: la interfaz se pinta entera', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 820));
      final towns = [
        for (final (i, sym) in ['book', 'run', 'weight', 'lute'].indexed)
          FiestaTown(x: i * 40.0, z: 0, radius: 10, symbol: sym, name: 'P$i'),
      ];
      final show = Fiesta.instance.start(k, towns, 1);
      for (var t = 0.0; t < show.length; t += 0.3) {
        show.steps = [t];
        await tester.pumpWidget(
          const MaterialApp(
            home: Stack(
              children: [
                Positioned.fill(child: FiestaOverlay(back: true)),
                Positioned.fill(child: FiestaOverlay(back: false)),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: '${k.name} a los $t s');
      }
      Fiesta.instance.stop();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 12));
    });
  }
}
