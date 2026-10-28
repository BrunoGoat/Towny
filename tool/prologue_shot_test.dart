import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/advice.dart';
import 'package:towny/model/advice_book.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/ui/first_run.dart';

/// La presentación del viejo, la primera vez, a disco: sus globos, un consejo
/// abierto, el botón de fundar, el salto a mitad y la primera pregunta.
///
///   flutter test tool/prologue_shot_test.dart --dart-define=OUT=/tmp/pr
///
/// W y H cambian el tamaño de la pantalla (por defecto 390 × 844).
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

  testWidgets('la presentación', (tester) async {
    const out = String.fromEnvironment('OUT', defaultValue: '/tmp/pr');
    final w = double.parse(
      const String.fromEnvironment('W', defaultValue: '390'),
    );
    final h = double.parse(
      const String.fromEnvironment('H', defaultValue: '844'),
    );
    Directory(out).createSync(recursive: true);
    await tester.runAsync(_letras);
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setSoundOff(true);
    await Appearance.instance.setFakeHour(true);
    await Appearance.instance.setFakeHourAt(17);
    AdviceBook.instance.forget();
    tester.view.physicalSize = Size(w * 2, h * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: Size(w, h),
          devicePixelRatio: 2,
          padding: const EdgeInsets.only(top: 44, bottom: 24),
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
    Future<void> espera(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> foto(String nombre) async {
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await b.toImage(pixelRatio: 1);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$nombre.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    Future<void> globo(String texto) async {
      await espera(5);
      final f = find.textContaining(texto, findRichText: true);
      await tester.tap(f.last, warnIfMissed: false);
      await espera(3);
    }

    Future<void> sigue(String texto) async {
      await tester.tap(
        find.textContaining(texto, findRichText: true).last,
        warnIfMissed: false,
      );
      await espera(6);
    }

    await espera(30);
    await foto('1-hola');
    final abre = SagePrologue.opening;
    for (var i = 0; i < abre.length; i++) {
      await globo(abre[i]);
      if (i == 2) await foto('2-piezas');
      await sigue(abre[i]);
    }
    await espera(12);
    await foto('3-sellado');
    final g = await tester.startGesture(Offset(w / 2, 200));
    for (var i = 0; i < 64; i++) {
      await g.moveBy(const Offset(0, 600 / 64));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await g.up();
    await espera(20);
    await foto('4-consejo');
    await tester.tapAt(Offset(w / 2, 420));
    await espera(30);
    await globo(SagePrologue.between);
    await sigue(SagePrologue.between);
    await espera(12);
    final g2 = await tester.startGesture(Offset(w / 2, 200));
    for (var i = 0; i < 64; i++) {
      await g2.moveBy(const Offset(0, 600 / 64));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await g2.up();
    await espera(20);
    await tester.tapAt(Offset(w / 2, 420));
    await espera(30);
    await globo(SagePrologue.closing.first);
    await sigue(SagePrologue.closing.first);
    await espera(40);
    await foto('5-fundar');
    final boton = find.byKey(const ValueKey('fundar-primero'));
    final g3 = await tester.startGesture(tester.getCenter(boton));
    await espera(14);
    for (final (n, ms) in [
      ('6-salto-a', 300),
      ('6-salto-b', 300),
      ('6-salto-c', 300),
      ('6-salto-d', 400),
    ]) {
      await tester.pump(Duration(milliseconds: ms));
      await foto(n);
    }
    await g3.up();
    await espera(20);
    await foto('7-pregunta');
    // ignore: avoid_print
    print('escritas en $out');
  });
}
