import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/first_run.dart';
import 'package:towny/ui/home_screen.dart';

/// Las pantallas de la primera vez, a disco, a tres horas del día.
///
///   flutter test tool/first_run_shot_test.dart --dart-define=OUT=/tmp/fr
///
/// Con la letra de verdad: la de las pruebas pinta cada letra como un
/// cuadrado, y una pantalla que se juzga por cómo se lee no se puede mirar
/// así. Roboto sale de la caché del propio Flutter —es la del teléfono— y las
/// demás del proyecto.
Future<void> _letras() async {
  Future<void> carga(String familia, List<String> archivos) async {
    final l = FontLoader(familia);
    for (final a in archivos) {
      final f = File(a);
      if (!f.existsSync()) continue;
      l.addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
    }
    await l.load();
  }

  final sdk =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final material = '$sdk/bin/cache/artifacts/material_fonts';
  await carga('Roboto', [
    '$material/Roboto-Regular.ttf',
    '$material/Roboto-Medium.ttf',
    '$material/Roboto-Bold.ttf',
    '$material/Roboto-Light.ttf',
  ]);
  await carga('EBGaramond', ['assets/fonts/EBGaramond.ttf']);
  await carga('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final hora in [11.0, 19.2, 23.0]) {
    testWidgets('a las $hora', (tester) async {
      const out = String.fromEnvironment('OUT', defaultValue: '/tmp/fr');
      Directory(out).createSync(recursive: true);
      await tester.runAsync(_letras);
      SharedPreferences.setMockInitialValues({});
      await Appearance.instance.load();
      await Appearance.instance.setSoundOff(true);
      await Appearance.instance.setFakeHour(true);
      await Appearance.instance.setFakeHourAt(hora);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final key = GlobalKey();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            devicePixelRatio: 3,
            padding: EdgeInsets.only(top: 44, bottom: 24),
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'Roboto'),
            home: RepaintBoundary(
              key: key,
              child: FirstRun(
                onDone: (_, _, {required character, why, identity}) {},
              ),
            ),
          ),
        ),
      );

      final h = hora.toStringAsFixed(0).padLeft(2, '0');
      Future<void> foto(String nombre) async {
        // En cuadros de verdad: el valle lleva su propio reloj y avanza un
        // cuadro por cada `pump`, así que dos saltos largos son dos cuadros.
        for (var i = 0; i < 110; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final b =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final img = await b.toImage(pixelRatio: 1.2);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$out/$h-$nombre.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          img.dispose();
        });
        // ignore: avoid_print
        print('escrito $out/$h-$nombre.png');
      }

      await foto('1-bienvenida');
      await tester.tap(find.text('FUNDAR MI PUEBLO', skipOffstage: false).last);
      await foto('2-nombre');
      await tester.enterText(find.byType(TextField).last, 'Leer');
      await tester.pump();
      await tester.tap(find.text('SIGUIENTE').last);
      await foto('3-comarca');
      await tester.tap(find.text('SIGUIENTE').last);
      await foto('4-para-que');
      await tester.enterText(find.byType(TextField).last, 'para dormir mejor');
      await tester.pump();
      await tester.tap(find.text('SIGUIENTE').last);
      await foto('5-quien');
      await tester.enterText(find.byType(TextField).last, 'que lee');
      await tester.pump();
      await tester.tap(find.text('FUNDAR LEER').last);
      // La bajada, en tres momentos. Sin esperar a que se asiente: lo que hay
      // que ver es el movimiento.
      Future<void> momento(String nombre, int ms) async {
        for (var i = 0; i < ms ~/ 16; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final b =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final img = await b.toImage(pixelRatio: 1.2);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$out/$h-$nombre.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          img.dispose();
        });
      }

      await momento('5-baja-a', 450);
      await momento('5-baja-b', 450);
      await momento('5-baja-c', 700);
    });
  }

  // Y el relevo: el pueblo recién fundado en sus primeros segundos, que tiene
  // que arrancar en la misma toma en la que terminaron las preguntas.
  testWidgets('el relevo', (tester) async {
    const out = String.fromEnvironment('OUT', defaultValue: '/tmp/fr');
    await tester.runAsync(_letras);
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setSoundOff(true);
    await Appearance.instance.setFakeHour(true);
    await Appearance.instance.setFakeHourAt(11);
    final store = Store();
    await store.load();
    store.renameHabit(0, name: 'Leer', symbol: 'libro');
    store.justFounded = true;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          devicePixelRatio: 3,
          padding: EdgeInsets.only(top: 44, bottom: 24),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          home: RepaintBoundary(
            key: key,
            child: HomeScreen(store: store),
          ),
        ),
      ),
    );
    var ms = 0;
    for (final hasta in [0, 900, 2000, 4500]) {
      while (ms < hasta) {
        await tester.pump(const Duration(milliseconds: 16));
        ms += 16;
      }
      await tester.pump();
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await b.toImage(pixelRatio: 1.2);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/11-6-pueblo-$hasta.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 8));
  });
}
