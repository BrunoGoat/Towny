import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/advice.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/model/advice_book.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/sage_screen.dart';
import 'package:towny/ui/style.dart';

/// Un consejo nuevo se abre a mano, y cuesta.
void main() {
  Future<Store> consejero(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    late Store store;
    await tester.runAsync(() async {
      await Appearance.instance.load();
      await Appearance.instance.setSoundOff(true);
      store = Store();
      await store.load();
    });
    AdviceBook.instance.forget();
    AdviceBook.instance.meet();
    AdviceBook.instance.setGoal(store.habit.id, AdviceGoal.start);
    AdviceBook.instance.visit(store.habits);
    expect(AdviceBook.instance.pending(), isNotEmpty);
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SageScreen(store: store, theme: UiTheme(Palette.forMoment(13))),
      ),
    );
    // Lo que dice se escribe de a una letra, y las respuestas salen después.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.textContaining(SageLines.yes));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return store;
  }

  final huella = find.byIcon(Icons.fingerprint);

  testWidgets('llega cerrado, y un toque no lo abre ni lo cierra', (
    tester,
  ) async {
    await consejero(tester);
    expect(huella, findsOneWidget);
    await tester.tapAt(const Offset(195, 420));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(huella, findsOneWidget, reason: 'un toque lo abrió o lo cerró');
    expect(AdviceBook.instance.read(), isEmpty);
  });

  testWidgets('soltarlo a medias lo vuelve a enrollar', (tester) async {
    await consejero(tester);
    final g = await tester.startGesture(const Offset(195, 420));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await g.up();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(huella, findsOneWidget);
  });

  testWidgets('se abre manteniendo el dedo unos segundos, y no antes', (
    tester,
  ) async {
    await consejero(tester);
    final g = await tester.startGesture(const Offset(195, 420));
    // Un segundo y medio no alcanza. De a cincuenta milisegundos, que es lo
    // más que cuenta un fotograma: con pasos más largos el reloj del rollo
    // iría más despacio que el del test.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(huella, findsOneWidget, reason: 'se abrió demasiado fácil');
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(huella, findsNothing, reason: 'no se abrió manteniendo el dedo');
    // Levantar el dedo que lo abrió no lo cierra.
    await g.up();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(AdviceBook.instance.read(), isEmpty);
    // Un toque, ya abierto, lo cierra y queda en la lista.
    await tester.tapAt(const Offset(195, 420));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(AdviceBook.instance.read(), hasLength(1));
  });
}
