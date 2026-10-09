import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';
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

  // Las tres altísimas, para ver la lista entera, y una del alto de un
  // teléfono, para ver cómo se abre de verdad.
  for (final (dev, hora, alto) in [
    (false, 13.0, 2000.0),
    (true, 13.0, 2000.0),
    (false, 22.0, 2000.0),
    (false, 13.0, 844.0),
  ]) {
    final nombre =
        '${dev ? 'desarrollo' : 'ajustes'}-${hora.toInt()}'
        '${alto < 1000 ? '-telefono' : ''}';
    testWidgets(nombre, (tester) async {
      const out = String.fromEnvironment('OUT', defaultValue: '/tmp/ajustes');
      Directory(out).createSync(recursive: true);
      await tester.runAsync(_letras);
      SharedPreferences.setMockInitialValues({});
      await Appearance.instance.load();
      final store = Store();
      await store.load();
      final pueblo = TownLayout(160, TownCharacter.all.first, seed: 21);
      tester.view.physicalSize = Size(390 * 2, alto * 2);
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
              body: Stack(
                children: [
                  // El pueblo detrás, que es sobre lo que se abre la hoja:
                  // sobre un color liso el vidrio no se ve.
                  Positioned.fill(
                    child: CustomPaint(
                      painter: TownPainter(
                        TownScene(
                          placed: 160,
                          palette: Palette.forMoment(hora),
                          camera: OrbitCamera()
                            ..yaw = 0.68
                            ..pitch = 0.5
                            ..focusY = 2
                            ..distance = 40
                            ..wallLength = pueblo.radius * 2,
                          time: 7.3,
                          hourOfDay: hora,
                          effects: EffectSystem(),
                          budget: 60000,
                          towns: [
                            TownEntry(
                              layout: pueblo,
                              name: 'Leer',
                              symbol: 'libro',
                              placed: 160,
                            ),
                          ],
                          active: 0,
                          labels: false,
                        ),
                        TouchMap(),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SettingsSheet(
                      store: store,
                      theme: UiTheme(Palette.forMoment(hora)),
                      dev: dev,
                    ),
                  ),
                ],
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
        File('$out/$nombre.png').writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
