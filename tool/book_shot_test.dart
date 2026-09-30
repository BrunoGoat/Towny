import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/legends_book.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El libro del atril, para mirarlo.
///
///   flutter test tool/book_shot_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const out = '/tmp/libro';
  const size = Size(390, 844);

  testWidgets('el libro', (tester) async {
    Directory(out).createSync(recursive: true);
    // La letra del libro, que en una prueba no existe hasta que se carga: sin
    // esto lo que sale es la fuente de los tests, que pinta cada letra como un
    // cuadrado y no sirve para mirar una página.
    await tester.runAsync(() async {
      final bytes = await File('assets/fonts/RobotoSlab.ttf').readAsBytes();
      await (FontLoader(
        'Chronicle',
      )..addFont(Future.value(bytes.buffer.asByteData()))).load();
    });
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    final store = Store();
    await store.load();
    store.renameHabit(0, name: 'Leer', symbol: 'libro');
    store.debugFill(520);
    // Con el plan y la identidad escritos: las páginas de la cuenta llevan las
    // dos, y sin ellas no hay manera de mirar cómo quedan.
    store.pledgeHabit(
      0,
      hour: 22,
      place: 'la cama',
      identity: 'alguien que lee todos los días',
    );
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MediaQuery(
          data: const MediaQueryData(size: size),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (context) => ColoredBox(
                color: const Color(0xFF3E4A2C),
                child: LegendsBook(
                  habit: store.habit,
                  theme: UiTheme(Palette.forMoment(11)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _shot(tester, key, '$out/portada.png');

    // Las páginas siguientes.
    for (var i = 1; i <= 7; i++) {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      await _shot(tester, key, '$out/pliego-$i.png');
    }
    // Y una hoja a media vuelta.
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await _shot(tester, key, '$out/hoja.png');
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
