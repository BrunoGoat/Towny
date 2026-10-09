import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/settings_sheet.dart';
import 'package:towny/ui/style.dart';

/// Las dos hojas de ajustes, enteras y con la letra de verdad.
///
///   flutter test tool/settings_shot_test.dart --dart-define=OUT=/tmp/ajustes
///
/// No prueba nada: es para mirarlas. Salen altísimas a propósito, para que
/// quepa la lista entera sin desplazarla.
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
  ]);
  await carga('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final dev in [false, true]) {
    testWidgets(dev ? 'desarrollo' : 'ajustes', (tester) async {
      const out = String.fromEnvironment('OUT', defaultValue: '/tmp/ajustes');
      Directory(out).createSync(recursive: true);
      await tester.runAsync(_letras);
      SharedPreferences.setMockInitialValues({});
      await Appearance.instance.load();
      final store = Store();
      await store.load();
      const alto = 2300.0;
      tester.view.physicalSize = const Size(390 * 2, alto * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              backgroundColor: const Color(0xFF3D4A33),
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SettingsSheet(
                  store: store,
                  theme: UiTheme(Palette.forMoment(13)),
                  dev: dev,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await b.toImage(pixelRatio: 1.5);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/${dev ? 'desarrollo' : 'ajustes'}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
