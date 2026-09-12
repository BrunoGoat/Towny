import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/model/board.dart';
import 'package:la_muralla/model/findings.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';
import 'package:la_muralla/ui/board_plan.dart';
import 'package:la_muralla/ui/paper_ink.dart';

Habit _habit({List<String>? notes, int pieces = 40}) => Habit(
  id: 'h',
  name: 'Prueba',
  symbol: 'rueda',
  slot: 0,
  createdAt: DateTime(2026, 3, 1),
  character: TownCharacter.all.first.order,
  notes: notes,
  pieces: [
    for (var i = 0; i < pieces; i++)
      Piece(
        index: i,
        placedAt: DateTime(2026, 3, 1).add(Duration(days: i)),
      ),
  ],
);

String _line(String said, {int daysAgo = 0}) =>
    '${DateTime.now().subtract(Duration(days: daysAgo)).millisecondsSinceEpoch}'
    '|$said';

void main() {
  group('las notas tuyas', () {
    test('lo que clavás va lo primero del tablón', () {
      // Es tu tablón: ni una nota del pueblo ni un bando sobre una cabra
      // pueden dejar fuera lo que pusiste vos.
      final h = _habit(notes: [_line('Comprar cal')]);
      final said = boardNotices(h);
      expect(said.first.kind, NoticeKind.mine);
      expect(said.first.said, 'Comprar cal');
    });

    test('y nunca las recorta el tablón, por lleno que esté', () {
      final h = _habit(
        notes: [for (var i = 0; i < myNoticeCap; i++) _line('Nota $i')],
        pieces: 400,
      );
      final said = boardNotices(h);
      final mias = said.where((n) => n.kind == NoticeKind.mine).length;
      expect(mias, myNoticeCap);
      expect(said.length, lessThanOrEqualTo(BoardPlan.capacity));
    });

    test('clavadas de más se guardan, pero no se clavan todas', () {
      // Llenar el tablón entero de recordatorios dejaría fuera lo que el
      // pueblo averiguó, que es la mitad de para lo que existe.
      final h = _habit(notes: [for (var i = 0; i < 12; i++) _line('Nota $i')]);
      expect(h.notes.length, 12);
      expect(myNotices(h).length, myNoticeCap);
    });

    test('la más nueva va arriba', () {
      final h = _habit(notes: [_line('Hoy'), _line('Ayer', daysAgo: 1)]);
      final mias = myNotices(h);
      expect(mias[0].said, 'Hoy');
      expect(mias[0].because, 'Clavada hoy.');
      expect(mias[1].because, 'Clavada ayer.');
    });

    test('un renglón roto no tira el tablón abajo', () {
      final h = _habit(notes: ['', 'sinbarra', 'x|y', '|vacío', _line('Vale')]);
      final mias = myNotices(h);
      expect(mias.length, 1);
      expect(mias.first.said, 'Vale');
    });

    test('se guardan y se vuelven a leer', () {
      final h = _habit(notes: [_line('Con | barra dentro')]);
      final back = Habit.fromJson(h.toJson());
      expect(back.notes, h.notes);
      expect(myNotices(back).first.said, 'Con | barra dentro');
    });
  });

  group('se distinguen de las demás', () {
    test('papel distinto de las del pueblo y de las del tablón', () {
      // Tres clases, tres papeles. Si dos coincidieran, el tablón dejaría de
      // decir quién habla en cada hoja.
      final tonos = {
        BoardPlan.minePaper,
        BoardPlan.villagePaper,
        ...BoardPlan.debugPapers,
      };
      expect(tonos.length, 2 + BoardPlan.debugPapers.length);
    });

    test('y el papel tuyo es el más claro de todos', () {
      double luz(c) => c.r * 0.3 + c.g * 0.59 + c.b * 0.11;
      for (final otro in [BoardPlan.villagePaper, ...BoardPlan.debugPapers]) {
        expect(luz(BoardPlan.minePaper), greaterThan(luz(otro)));
      }
    });

    test('se lee de corrido, como un recado y no como una conclusión', () {
      // Una nota del tablón es una afirmación con sus cuentas debajo; «comprar
      // cal» no tiene cuentas que enseñar.
      final mia = PaperInk(
        const Notice(NoticeKind.mine, 'Comprar cal', 'Clavada hoy.'),
      );
      final suya = PaperInk(
        const Notice(NoticeKind.hour, 'Siempre a las siete.', '18 de 20 días'),
      );
      expect(mia.corrido, isTrue);
      expect(suya.corrido, isFalse);
    });

    test('y siempre con la misma letra, que es la tuya', () {
      final a = PaperInk(const Notice(NoticeKind.mine, 'Una', 'Hoy.'));
      final b = PaperInk(
        const Notice(NoticeKind.mine, 'Otra muy otra', 'Hoy.'),
      );
      expect(a.font, b.font);
    });
  });
}
