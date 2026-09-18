import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/folk.dart';
import 'package:la_muralla/engine/town.dart';

/// Lo que cuesta poner una pieza, que es lo único que esta app hace.
///
///   flutter test tool/censo_test.dart
void main() {
  test('poner cien piezas seguidas', () {
    // ignore: avoid_print
    print('\n  piezas  vecinos    media/pieza   la peor   cien piezas');
    for (final n in [200, 600, 1000, 1500]) {
      final ch = TownCharacter.all.first;
      final l = TownLayout(n, ch, seed: 7);
      folkOf(l, n - 100);

      var total = 0, peor = 0;
      for (var k = n - 99; k <= n; k++) {
        final t = Stopwatch()..start();
        folkOf(l, k);
        t.stop();
        total += t.elapsedMicroseconds;
        if (t.elapsedMicroseconds > peor) peor = t.elapsedMicroseconds;
      }
      // ignore: avoid_print
      print(
        '  ${n.toString().padLeft(6)}  ${folkOf(l, n).length.toString().padLeft(7)}   '
        '${(total / 100 / 1000).toStringAsFixed(1).padLeft(9)} ms '
        '${(peor / 1000).toStringAsFixed(1).padLeft(9)} ms '
        '${(total / 1000).toStringAsFixed(0).padLeft(9)} ms',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
