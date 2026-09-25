import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/data/landmarks_retired.dart';
import 'package:la_muralla/engine/mason.dart';

double alcance(Landmark l) {
  final m = Mason(0, 0, 7, true);
  l.build(m);
  var r = 0.0;
  for (final s in m.finish(l.cost)) {
    final x = math.max(s.cx.abs() + s.w / 2, s.cz.abs() + s.d / 2);
    if (x > r) r = x;
  }
  return r;
}

void main() {
  test('audit', () {
    for (final t in [0, 1, 2]) {
      final viejas = [
        for (final l in retiredLandmarks)
          if (l.tier == t) alcance(l),
      ]..sort();
      final nuevas = [
        for (final l in landmarks)
          if (l.tier == t) alcance(l),
      ]..sort();
      // ignore: avoid_print
      print(
        'tier $t  retiradas max=${viejas.isEmpty ? 0 : viejas.last.toStringAsFixed(2)} '
        'mediana=${viejas.isEmpty ? 0 : viejas[viejas.length ~/ 2].toStringAsFixed(2)} | '
        'vivas max=${nuevas.last.toStringAsFixed(2)} mediana=${nuevas[nuevas.length ~/ 2].toStringAsFixed(2)}',
      );
    }
    for (final l in landmarks) {
      final a = alcance(l);
      final tope = const [1.9, 2.9, 4.6][l.tier];
      if (a > tope) {
        // ignore: avoid_print
        print('GRANDE ${l.id} t${l.tier} ${a.toStringAsFixed(2)} > $tope');
      }
    }
  });
}
