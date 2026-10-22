import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/style.dart';
import 'package:towny/ui/unlock_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tocar un hábito abre su detalle, y tocarlo otra vez lo cierra', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setSoundOff(true);
    await Appearance.instance.setFreeHabits(true);
    final s = Store();
    await s.load();
    s.renameHabit(0, name: 'Leer', symbol: 'book');
    s.addHabit('Correr', 'run');
    final hoy = DateTime.now();
    for (final d in [5, 3, 1]) {
      s.lay(s.habits[1], DateTime(hoy.year, hoy.month, hoy.day - d, 9));
    }
    await Appearance.instance.setFreeHabits(false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: UnlockSheet(store: s, theme: UiTheme(Palette.forMoment(13))),
          ),
        ),
      ),
    );
    expect(find.text('HECHOS'), findsNothing);
    await tester.tap(find.text('Correr'));
    await tester.pumpAndSettle();
    expect(find.text('HECHOS'), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: 'tres días con pieza');
    await tester.tap(find.text('Correr'));
    await tester.pumpAndSettle();
    expect(find.text('HECHOS'), findsNothing);

    // Uno a la vez: abrir otro cierra el que estaba abierto.
    await tester.tap(find.text('Leer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Correr'));
    await tester.pumpAndSettle();
    expect(find.text('HECHOS'), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: 'el de Correr');
  });
}
