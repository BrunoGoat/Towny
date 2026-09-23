import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/board_plan.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/model/board.dart';
import 'package:la_muralla/model/board_slots.dart';
import 'package:la_muralla/model/notice.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/notice_board.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unas cuantas notas del pueblo, que son las que se llaman por lo que dicen.
List<Notice> _said(int n) => [
  for (var i = 0; i < n; i++) Notice(NoticeKind.pueblo, 'bando $i', ''),
];

Future<BoardSlots> _tabla() async {
  SharedPreferences.setMockInitialValues({});
  final t = BoardSlots.instance..forget();
  await t.load();
  return t;
}

void main() {
  group('llevar un papel a otro hueco', () {
    test('si el hueco estaba libre, se va y ya', () async {
      final tabla = await _tabla();
      final said = _said(3);
      final ids = [for (final n in said) noticeId(n)];
      final huecos = tabla.assign('h', said, slots: BoardPlan.capacity);
      // Un hueco que no tiene nadie.
      final libre = [
        for (var k = 0; k < BoardPlan.capacity; k++)
          if (!huecos.contains(k)) k,
      ].first;

      tabla.place('h', ids, 1, libre);
      expect(tabla.slotOf('h', ids[1]), libre);
      // Y los otros dos donde estaban.
      expect(tabla.slotOf('h', ids[0]), huecos[0]);
      expect(tabla.slotOf('h', ids[2]), huecos[2]);
    });

    test('si estaba ocupado, los dos se cambian de sitio', () async {
      // Lo que no puede pasar: que soltar un papel encima de otro lo haga
      // desaparecer. Un tablón así no es un tablón, es una papelera.
      final tabla = await _tabla();
      final said = _said(4);
      final ids = [for (final n in said) noticeId(n)];
      final huecos = tabla.assign('h', said, slots: BoardPlan.capacity);

      tabla.place('h', ids, 0, huecos[3]);
      expect(tabla.slotOf('h', ids[0]), huecos[3]);
      expect(tabla.slotOf('h', ids[3]), huecos[0], reason: 'se lo comió');
      // Y nadie acabó compartiendo agujero.
      final donde = [for (final id in ids) tabla.slotOf('h', id)];
      expect(donde.toSet().length, ids.length);
    });

    test('soltarlo donde estaba no hace nada', () async {
      final tabla = await _tabla();
      final said = _said(3);
      final ids = [for (final n in said) noticeId(n)];
      final huecos = tabla.assign('h', said, slots: BoardPlan.capacity);
      tabla.place('h', ids, 2, huecos[2]);
      expect(tabla.slotOf('h', ids[2]), huecos[2]);
    });

    test('no se cambia de sitio con una nota que ya no está clavada', () async {
      // La tabla guarda también huecos de notas que se descolgaron hace meses.
      // Cambiar de sitio con una de ésas dejaría dos papeles vivos en el mismo
      // agujero: el que se mueve y el que estaba allí de verdad.
      final tabla = await _tabla();
      final viejas = _said(6);
      tabla.assign('h', viejas, slots: BoardPlan.capacity);
      // Hoy sólo quedan tres de aquellas seis.
      final hoy = viejas.take(3).toList();
      final ids = [for (final n in hoy) noticeId(n)];
      final huecos = tabla.assign('h', hoy, slots: BoardPlan.capacity);
      // Y se lleva una al hueco de una de las que ya no están.
      final fantasma = tabla.slotOf('h', noticeId(viejas[5]))!;
      expect(huecos.contains(fantasma), isFalse);

      tabla.place('h', ids, 0, fantasma);
      expect(tabla.slotOf('h', ids[0]), fantasma);
      // Los otros dos, intactos.
      expect(tabla.slotOf('h', ids[1]), huecos[1]);
      expect(tabla.slotOf('h', ids[2]), huecos[2]);
    });

    test('y el sitio nuevo sobrevive a cerrar el tablón', () async {
      final tabla = await _tabla();
      final said = _said(3);
      final ids = [for (final n in said) noticeId(n)];
      tabla.assign('h', said, slots: BoardPlan.capacity);
      tabla.place('h', ids, 1, 7);
      await tabla.flush();

      tabla.forget();
      await tabla.load();
      expect(tabla.slotOf('h', ids[1]), 7);
      // Y al volver a repartir, el papel reclama el hueco que le diste.
      expect(tabla.assign('h', said, slots: BoardPlan.capacity)[1], 7);
    });
  });

  group('dónde cae un hueco', () {
    test('lo que dice el plano y lo que dice el dedo es el mismo sitio', () {
      // El acoplamiento que rompería el arrastre sin que nada diera error: el
      // dedo apunta a un hueco con una cuenta y el plano clava el papel con
      // otra, y el papel se suelta en un sitio y aparece en otro.
      final said = _said(BoardPlan.capacity);
      final huecos = [for (var k = 0; k < BoardPlan.capacity; k++) k];
      final plan = BoardPlan.of(said, slots: huecos);
      for (var i = 0; i < plan.papers.length; i++) {
        final semilla = stableHash(noticeId(said[i]));
        final (cx, cy) = BoardPlan.spotOf(huecos[i], semilla);
        expect(plan.papers[i].cx, closeTo(cx, 1e-9));
        expect(plan.papers[i].cy, closeTo(cy, 1e-9));
      }
    });

    test(
      'los diez huecos caen en diez sitios distintos y dentro de la madera',
      () {
        final vistos = <String>{};
        for (var k = 0; k < BoardPlan.capacity; k++) {
          final (cx, cy) = BoardPlan.spotOf(k, 0);
          vistos.add('${cx.toStringAsFixed(4)}/${cy.toStringAsFixed(4)}');
        }
        expect(vistos.length, BoardPlan.capacity);

        final plan = BoardPlan.of(_said(1), slots: const [0]);
        for (var k = 0; k < BoardPlan.capacity; k++) {
          final (cx, cy) = BoardPlan.spotOf(k, 0);
          expect(cx.abs(), lessThan(plan.halfWidth));
          expect(cy, greaterThan(plan.low));
          expect(cy, lessThan(plan.high));
        }
      },
    );
  });
  group('con el dedo, en el tablón de verdad', () {
    testWidgets('mantener un papel y soltarlo en otro sitio lo mueve', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      BoardSlots.instance.forget();
      await BoardSlots.instance.load();
      await Appearance.instance.load();
      final store = Store();
      await store.load();
      store.renameHabit(0, name: 'Entrenar', symbol: 'pesa');
      store.debugFill(120);
      final h = store.habit;
      store.pinNote(h, 'Una nota mía');
      store.pinNote(h, 'Y otra');

      // Los huecos se sortean del nombre de cada papel, así que un tablón de
      // pocas notas puede tenerlas todas en la columna de la derecha — y el
      // tablón se abre pegado al filo izquierdo, o sea fuera del cuadro. Se
      // les pone sitio a mano en la primera columna para que el dedo del test
      // tenga a qué apuntar.
      final hay = boardNotices(h, valley: store.habits);
      final quienes = [for (final n in hay) noticeId(n)];
      BoardSlots.instance.assign(h.id, hay, slots: BoardPlan.capacity);
      for (var i = 0; i < quienes.length && i < 3; i++) {
        BoardSlots.instance.place(h.id, quienes, i, i);
      }

      const size = Size(390, 844);
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: size),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: NoticeBoardScreen(
              valley: store.habits,
              habit: h,
              theme: UiTheme(Palette.forMoment(13, 1.0)),
              store: store,
            ),
          ),
        ),
      );
      // Que la cámara llegue y se pare: mientras viaja, los papeles no están
      // donde van a estar.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final said = boardNotices(h, valley: store.habits);
      expect(said, isNotEmpty, reason: 'el tablón salió vacío');
      List<int?> donde() => [
        for (final n in said) BoardSlots.instance.slotOf(h.id, noticeId(n)),
      ];
      final antes = donde();

      // Dónde cae un papel en pantalla no se sabe desde aquí —lo decide una
      // proyección que vive dentro de la escena— así que se prueba por la
      // rejilla hasta dar con uno. Lo que se comprueba es el gesto entero:
      // mantener, arrastrar y soltar.
      var movio = false;
      for (var fy = 0.25; fy <= 0.8 && !movio; fy += 0.07) {
        for (var fx = 0.15; fx <= 0.6 && !movio; fx += 0.15) {
          final from = Offset(size.width * fx, size.height * fy);
          final to = Offset(size.width * 0.85, size.height * 0.4);
          final g = await tester.startGesture(from);
          await tester.pump(
            kLongPressTimeout + const Duration(milliseconds: 80),
          );
          await g.moveTo(to);
          await tester.pump(const Duration(milliseconds: 80));
          await g.up();
          await tester.pump(const Duration(milliseconds: 250));
          expect(
            tester.takeException(),
            isNull,
            reason: 'al arrastrar en $from',
          );
          movio = !_igual(antes, donde());
        }
      }
      expect(movio, isTrue, reason: 'ningún arrastre movió un papel');
      // El sitio nuevo se escribe con un respiro de trescientos milisegundos,
      // para no tocar el disco en cada papel que se cambia de sitio. Hay que
      // dejarlo caer antes de acabar o el arnés se queja de un reloj pendiente.
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
  group('escribir una nota', () {
    testWidgets('pide una línea y nada más', (tester) async {
      SharedPreferences.setMockInitialValues({});
      BoardSlots.instance.forget();
      await BoardSlots.instance.load();
      await Appearance.instance.load();
      final store = Store();
      await store.load();
      store.renameHabit(0, name: 'Entrenar', symbol: 'pesa');
      store.debugFill(120);

      const size = Size(390, 844);
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: size),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: NoticeBoardScreen(
              valley: store.habits,
              habit: store.habit,
              theme: UiTheme(Palette.forMoment(13, 1.0)),
              store: store,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Clavar una nota'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Un renglón y la palabra que lo clava. Lo que ya no está: el rótulo, el
      // párrafo de tres líneas explicando de qué iba el papel, y el contador
      // puesto desde el primer carácter.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('CLAVARLA'), findsOneWidget);
      expect(find.text('UNA NOTA TUYA'), findsNothing);
      expect(find.textContaining('papel limpio'), findsNothing);
      expect(find.text('0/90'), findsNothing);

      // Y no clava nada mientras no haya nada escrito.
      await tester.tap(find.text('CLAVARLA'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.habit.notes, isEmpty, reason: 'clavó un papel en blanco');

      await tester.enterText(find.byType(TextField), 'Zapatillas en la puerta');
      await tester.pump();
      await tester.tap(find.text('CLAVARLA'));
      await tester.pump(const Duration(milliseconds: 400));
      // Se guardan con la hora delante, así que se busca lo que dicen.
      expect(
        store.habit.notes.where((n) => n.endsWith('Zapatillas en la puerta')),
        hasLength(1),
      );
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}

bool _igual(List<int?> a, List<int?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
