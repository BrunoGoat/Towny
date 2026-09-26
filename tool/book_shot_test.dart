import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    final store = Store();
    await store.load();
    store.renameHabit(0, name: 'Leer', symbol: 'libro');
    store.debugFill(520);
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
                  theme: UiTheme(Palette.forMoment(11, 1.0)),
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
    for (var i = 1; i <= 3; i++) {
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
