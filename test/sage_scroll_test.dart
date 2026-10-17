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

  final flecha = find.byIcon(Icons.keyboard_double_arrow_down);

  testWidgets('llega cerrado, y un toque no lo abre ni lo cierra', (
    tester,
  ) async {
    await consejero(tester);
    expect(flecha, findsOneWidget);
    await tester.tapAt(const Offset(195, 420));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(flecha, findsOneWidget, reason: 'un toque lo abrió o lo cerró');
    expect(AdviceBook.instance.read(), isEmpty);
  });

  /// Arrastrar hacia abajo [px] píxeles en [ms] milisegundos, de a pasos de
  /// cincuenta —lo más que cuenta un fotograma: con pasos más largos el reloj
  /// del rollo iría más despacio que el del test—.
  Future<TestGesture> tirar(WidgetTester tester, double px, int ms) async {
    final g = await tester.startGesture(const Offset(195, 200));
    final pasos = ms ~/ 50;
    for (var i = 0; i < pasos; i++) {
      await g.moveBy(Offset(0, px / pasos));
      await tester.pump(const Duration(milliseconds: 50));
    }
    return g;
  }

  testWidgets('soltarlo a medias lo vuelve a enrollar', (tester) async {
    await consejero(tester);
    final g = await tirar(tester, 250, 1500);
    await g.up();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(flecha, findsOneWidget);
  });

  testWidgets('tirar de golpe no lo abre: hay que ir con él', (tester) async {
    await consejero(tester);
    final g = await tirar(tester, 600, 300);
    await g.up();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(flecha, findsOneWidget, reason: 'se abrió de un tirón');
  });

  testWidgets('se abre tirando hacia abajo, despacio', (tester) async {
    await consejero(tester);
    final g = await tirar(tester, 600, 3200);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(flecha, findsNothing, reason: 'no se abrió tirando');
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

  testWidgets('el de prueba llega sellado y no cuenta como leído', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await Appearance.instance.load();
      await Appearance.instance.setSoundOff(true);
    });
    AdviceBook.instance.forget();
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(SageScreen.trial(advice: dailyAdvice.first)),
              child: const Text('probar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('probar'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(flecha, findsOneWidget);
    final g = await tirar(tester, 600, 3200);
    await g.up();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(flecha, findsNothing);
    await tester.tapAt(const Offset(195, 420));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('probar'), findsOneWidget);
    expect(AdviceBook.instance.read(), isEmpty);
  });
}
