import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/choice_sheet.dart';
import 'package:la_muralla/ui/home_screen.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La pantalla de siempre a varias horas, y la tarjeta de elegir.
///
/// Lo que se mira acá no se puede comprobar con un `expect`: si el botón de
/// abajo y la fila de hábitos se leen encima del prado, que es lo que se vio
/// que no pasaba a las cinco y media de la tarde.
///
///   flutter test tool/chrome_shot_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const out = '/tmp/chrome';
  const size = Size(390, 844);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setSoundOff(true);
    await Appearance.instance.setMusicOff(true);
  });

  testWidgets('la pantalla a varias horas', (tester) async {
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // La hora, y cuántos días lleva el pueblo sin que nadie ponga una pieza.
    // Lo segundo es lo que apaga el valle, y con el valle apagado el cielo se
    // aclara de ceniza: es el caso en el que la interfaz volvía al pardo de
    // mediodía a las diez de la noche.
    const casos = [
      (11.0, 0),
      (17.2, 0),
      (17.6, 0),
      (19.6, 0),
      (23.0, 0),
      (22.0, 30),
    ];
    for (final (hora, dejado) in casos) {
      SharedPreferences.setMockInitialValues({});
      await Appearance.instance.load();
      await Appearance.instance.setSoundOff(true);
      await Appearance.instance.setFakeHour(true);
      await Appearance.instance.setFakeHourAt(hora);
      final store = Store();
      await store.load();
      store.renameHabit(0, name: 'Leer', symbol: 'libro');
      store.debugFill(38, endedDaysAgo: dejado);
      store.addHabit('Correr', 'carrera');
      store.debugFill(12, endedDaysAgo: dejado);
      store.select(0);

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
              home: HomeScreen(store: store),
            ),
          ),
        ),
      );
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      final nombre = dejado > 0
          ? 'dejado-${hora.toStringAsFixed(1)}'
          : 'hora-${hora.toStringAsFixed(1)}';
      await _shot(tester, key, '$out/$nombre.png');
      await tester.pumpWidget(const SizedBox());
    }
    // ignore: avoid_print
    print('escritas en $out');
  });

  testWidgets('la tarjeta de elegir', (tester) async {
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    for (final hora in [11.0, 21.0]) {
      final t = UiTheme(Palette.forMoment(hora, 1.0));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MediaQuery(
            data: const MediaQueryData(size: size),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: const Color(0xFF5E7040),
                body: ChoiceSheet(
                  options: [
                    landmarks.firstWhere((l) => l.id == 'iglesia'),
                    landmarks.firstWhere((l) => l.id == 'catedral'),
                  ],
                  place: TownCharacter.all.first,
                  theme: t,
                  onPick: (_) {},
                  onLeave: () {},
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await _shot(tester, key, '$out/elegir-${hora.toStringAsFixed(0)}.png');
    }
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
