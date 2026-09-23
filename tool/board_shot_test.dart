import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/board_plan.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/model/board.dart';
import 'package:la_muralla/model/board_slots.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/notice_board.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El tablón a disco: como se llega, con un papel en la mano y escribiendo.
///
///   flutter test tool/board_shot_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el tablón', (tester) async {
    const out = '/tmp/tablon';
    Directory(out).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    BoardSlots.instance.forget();
    await BoardSlots.instance.load();
    await Appearance.instance.load();
    await Appearance.instance.setSoundOff(true);

    final store = Store();
    await store.load();
    store.renameHabit(0, name: 'Entrenar', symbol: 'pesa');
    store.debugFill(180);
    store.pinNote(store.habit, 'Zapatillas al lado de la puerta');
    store.pinNote(store.habit, 'El martes, con Ana');

    final hay = boardNotices(store.habit, valley: store.habits);
    final quienes = [for (final n in hay) noticeId(n)];
    BoardSlots.instance.assign(store.habit.id, hay, slots: BoardPlan.capacity);
    for (var i = 0; i < quienes.length && i < 4; i++) {
      BoardSlots.instance.place(store.habit.id, quienes, i, i);
    }

    const size = Size(390, 844);
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    await tester.pumpWidget(
      // El envoltorio va **por fuera** del `MaterialApp`: la hoja de escribir
      // es una ruta modal y vive en el telón del navegador, no dentro de la
      // pantalla. Envolviendo la pantalla, las capturas de la hoja salían
      // enseñando el tablón sin ella.
      RepaintBoundary(
        key: key,
        child: MediaQuery(
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
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _shot(tester, key, '$out/1-llegada.png');

    // Con un papel en la mano, a medio camino de otro hueco.
    final g = await tester.startGesture(const Offset(206, 344));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveTo(const Offset(300, 560));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await _shot(tester, key, '$out/2-en-la-mano.png');
    await g.up();
    await tester.pump(const Duration(milliseconds: 500));

    // Y la hoja de escribir.
    await tester.tap(find.text('Clavar una nota'));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await _shot(tester, key, '$out/3-escribir.png');
    await tester.enterText(find.byType(TextField), 'El martes, con Ana');
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await _shot(tester, key, '$out/4-escrita.png');
    await tester.pump(const Duration(milliseconds: 500));
    // ignore: avoid_print
    print('escritas en $out');
  });
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 1.6);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
    img.dispose();
  });
}
