import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/ui/first_run.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las cuatro pantallas de la primera vez, a disco, para poder mirarlas.
///
///   flutter test tool/first_run_shot_test.dart --dart-define=OUT=/tmp/fr
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setSoundOff(true);
  });

  testWidgets('las cuatro', (tester) async {
    const out = String.fromEnvironment('OUT', defaultValue: '/tmp/fr');
    Directory(out).createSync(recursive: true);
    // El lienzo del test mide 800x600 si no se le dice otra cosa, y una
    // pantalla de entrada juzgada en 4:3 no dice nada de cómo se ve en un
    // teléfono: lo que sobra o falta es precisamente el alto.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          devicePixelRatio: 2,
          padding: EdgeInsets.only(top: 44, bottom: 24),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: FirstRun(onDone: (_, _, _, _) {}),
          ),
        ),
      ),
    );

    Future<void> foto(String nombre) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await b.toImage(pixelRatio: 1.6);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$nombre.png').writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
      // ignore: avoid_print
      print(
        'escrito $out/$nombre.png  '
        'campos=${find.byType(TextField).evaluate().length} '
        'textos=${find.byType(Text).evaluate().length}',
      );
    }

    await foto('1-bienvenida');
    await tester.tap(find.text('FUNDAR MI PUEBLO'));
    await foto('2-nombre');
    await tester.enterText(find.byType(TextField).first, 'Leer');
    await tester.pump();
    await tester.tap(find.text('SEGUIR'));
    await foto('3-motivo');
    await tester.enterText(find.byType(TextField).first, 'para dormir mejor');
    await tester.pump();
    await tester.tap(find.text('SEGUIR'));
    await foto('4-minimo');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
