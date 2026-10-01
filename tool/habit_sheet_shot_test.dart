import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/habits_sheet.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La hoja de un hábito, con todo escrito, para poder mirarla.
///
/// Lo que se juzga acá no se comprueba con un `expect`: cuántas secciones
/// parece tener, si se lee como una ficha o como un formulario, y si el plan
/// plegado se entiende sin abrirlo.
///
///   flutter test tool/habit_sheet_shot_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const out = '/tmp/hoja';
  const size = Size(390, 844);

  testWidgets('la hoja, plegada y abierta', (tester) async {
    Directory(out).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setSoundOff(true);
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final store = Store();
    await store.load();
    store.renameHabit(
      store.active,
      name: 'Despertarse temprano',
      symbol: store.habit.symbol,
    );
    store.pledgeHabit(
      store.active,
      hour: 22,
      place: 'en la mesa de la cocina',
      identity: 'alguien que se levanta temprano',
    );
    store.describeHabit(
      store.active,
      why: 'para tener más energía durante el día',
      floor: 'abrir el libro y leer una página',
    );
    store.setCadence(store.habit, 3);

    for (final hora in [13.0, 22.5]) {
      final t = UiTheme(Palette.forMoment(hora));
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MediaQuery(
            data: const MediaQueryData(
              size: size,
              padding: EdgeInsets.only(top: 44, bottom: 24),
            ),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Material(
                color: t.palette.ground,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: HabitsSheet(store: store, theme: t),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final h = hora.round();
      await _shot(tester, key, '$out/plegada-$h.png');
      // Y con el reloj abierto, que es lo que se ve al tocar la frase.
      await tester.tap(
        find.textContaining('Voy a despertarse', findRichText: true),
      );
      // Dos veces: en la primera el pliegue se entera de que creció y arranca
      // la animación, en la segunda ya llegó. Con una sola, lo que se
      // fotografía es el pliegue todavía cerrado recortando al reloj.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, key, '$out/abierta-$h.png');
      await tester.pumpWidget(const SizedBox());
    }
    // ignore: avoid_print
    print('escritas en $out');
  });
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
    img.dispose();
  });
}
