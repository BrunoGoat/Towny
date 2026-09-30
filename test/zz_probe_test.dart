import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/demo.dart';
import 'package:la_muralla/model/pledge.dart';

void main() {
  test('el título en el valle de mentira, cualquier día', () {
    var ganados = 0, total = 0;
    final kept = <int>[];
    for (var d = 0; d < 21; d++) {
      final cuando = DateTime(2026, 3, 12, 21).add(Duration(days: d));
      final voy = identityStanding(demoValley(cuando).first, at: cuando)!;
      total++;
      if (voy.earned) ganados++;
      kept.add((voy.kept * 100).round());
    }
    // ignore: avoid_print
    print('ganado $ganados de $total · cumplimientos ${kept.join(' ')}');
  });
}
