import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/habit_sigil.dart';
import 'package:towny/ui/habits_sheet.dart';
import 'package:towny/ui/style.dart';

/// A los lados de la marca de la hoja del hábito no hay hoja: se ve el
/// pueblo. Tocar ahí tiene que cerrarla, como tocar más arriba — y tocar la
/// marca sigue abriendo el carrete.
void main() {
  Future<Store> abrir(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final t = UiTheme(Palette.forMoment(13));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => HabitsSheet(store: store, theme: t),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(HabitsSheet), findsOneWidget);
    return store;
  }

  testWidgets('tocar al lado de la marca cierra la hoja', (tester) async {
    await abrir(tester);
    final marca = tester.getCenter(find.byType(HabitSigil).first);
    // Bien a la izquierda y a la derecha, a la altura de la marca.
    await tester.tapAt(Offset(24, marca.dy));
    await tester.pumpAndSettle();
    expect(find.byType(HabitsSheet), findsNothing);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tapAt(Offset(366, marca.dy));
    await tester.pumpAndSettle();
    expect(find.byType(HabitsSheet), findsNothing);
  });

  testWidgets('y tocar la marca abre el carrete, no cierra', (tester) async {
    await abrir(tester);
    final antes = find.byType(HabitSigil).evaluate().length;
    await tester.tap(find.byType(HabitSigil).first);
    await tester.pumpAndSettle();
    expect(find.byType(HabitsSheet), findsOneWidget);
    // El carrete trae todas las marcas: hay muchas más que la de arriba.
    expect(find.byType(HabitSigil).evaluate().length, greaterThan(antes));
  });
}
