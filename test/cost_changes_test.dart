import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/model/cost_changes.dart';
import 'package:towny/model/habit.dart';
import 'package:towny/model/piece.dart';
import 'package:towny/model/works_log.dart';
import 'package:towny/ui/cost_change_notice.dart';

Habit _habit(int n) {
  final start = DateTime(2026, 3, 1, 19, 30);
  final h = Habit(
    id: 'h1758000000000001',
    name: 'Leer',
    symbol: 'wheel',
    slot: 0,
    createdAt: start,
    character: TownCharacter.all.first.order,
  );
  for (var i = 0; i < n; i++) {
    h.pieces.add(
      Piece(
        index: i,
        placedAt: start.add(Duration(days: i)),
      ),
    );
  }
  final plan = TownPlan.of(h.place, seed: h.townSeed);
  h.chronicle.addAll(plan.chronicleFor(n, const []));
  return h;
}

void main() {
  group('cuando una obra cambia de costo', () {
    test('sin cambios no hay nada que avisar', () {
      final h = _habit(300);
      expect(costChangesFor([h], currentCosts()), isEmpty);
    });

    test('si costaba más, son piezas a favor; si costaba menos, faltan', () {
      final h = _habit(300);
      final obras = worksOf(h);
      expect(obras.length, greaterThanOrEqualTo(2));
      final a = obras[0], b = obras[1];
      // Lo que «costaban antes»: una de más en la primera, dos de menos en
      // la segunda.
      final antes = {...currentCosts(), a.id: a.cost + 1, b.id: b.cost - 2};
      final c = costChangesFor([h], antes);
      expect(c.map((x) => x.id), containsAll([a.id, b.id]));
      final ca = c.firstWhere((x) => x.id == a.id);
      expect((ca.before, ca.after, ca.delta), (a.cost + 1, a.cost, 1));
      expect(piecesInFavour(c), greaterThanOrEqualTo(1));
      expect(piecesOwed(c), greaterThanOrEqualTo(2));
      expect(CostChangeNotice.summary(c), contains('a favor'));
      expect(CostChangeNotice.summary(c), contains('próximas'));
    });

    test('una obra que nadie empezó no avisa', () {
      final h = _habit(300);
      final empezadas = worksOf(h).map((w) => w.id).toSet();
      final otra = currentCosts().keys.firstWhere(
        (id) => !empezadas.contains(id),
      );
      final antes = {...currentCosts(), otra: 99};
      expect(costChangesFor([h], antes), isEmpty);
    });

    test(
      'se recuerda entre aperturas: la primera no avisa, la siguiente sí',
      () async {
        SharedPreferences.setMockInitialValues({});
        final h = _habit(300);
        expect(await CostMemory.check([h]), isEmpty);
        expect(await CostMemory.check([h]), isEmpty);
        // Como si la versión anterior de la app tuviera otro costo.
        final a = worksOf(h).first;
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('costes_obras_v1', '{"${a.id}": ${a.cost + 3}}');
        final c = await CostMemory.check([h]);
        expect(c.single.id, a.id);
        expect(piecesInFavour(c), 3);
        // Y avisado una vez, no vuelve a avisar.
        expect(await CostMemory.check([h]), isEmpty);
      },
    );
  });
}
