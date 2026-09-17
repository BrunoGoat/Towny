import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/habit_bar.dart';
import 'package:la_muralla/ui/habit_sigil.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La fila de marcas es la única puerta que hay a la hoja del hábito.
///
/// Se le pone el nombre ahí, y la marca, y el para qué, y lo mínimo que cuenta
/// — y se llega tocando tu propia marca en esta fila y de ninguna otra manera.
/// Así que esta fila no puede desaparecer en ningún estado del valle, y eso es
/// exactamente lo que este archivo comprueba.
///
/// Existe porque se rompió: la fila se escondía cuando había un solo pueblo y
/// no se podía fundar otro. Hasta que el candado existió, eso no pasaba nunca
/// —con un hábito siempre se podía fundar el segundo—. Con el candado pasa el
/// primer día de la primera persona que instala la app, que se encontraba un
/// pueblo sin nombre y ninguna forma de nombrarlo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> barOf(Store store) async => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: HabitBar(
        store: store,
        theme: UiTheme(Palette.forMoment(13, 1.0)),
        onSelect: (_) {},
        onManage: () {},
        onAdd: () {},
      ),
    ),
  );

  testWidgets('la fila existe el primer día, con el candado cerrado', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.load();

    // El estado exacto de quien acaba de instalar: un pueblo, sin piezas y sin
    // el segundo solar abierto.
    expect(store.habits.length, 1);
    expect(store.canAddHabit, isFalse);
    expect(store.unlockProgress, 0);

    await tester.pumpWidget(await barOf(store));
    expect(
      find.byType(HabitSigil),
      findsOneWidget,
      reason: 'sin la marca no hay manera de abrir la hoja del hábito',
    );
  });

  testWidgets('y sigue existiendo con el valle lleno', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.load();
    for (var i = 1; i < 6; i++) {
      store.addHabit('Hábito $i', 'libro');
    }
    expect(store.canAddHabit, isFalse, reason: 'seis es el tope');

    await tester.pumpWidget(await barOf(store));
    expect(find.byType(HabitSigil), findsNWidgets(6));
  });

  testWidgets('el más cerrado se puede tocar: es cómo se sabe qué falta', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.load();
    var tocado = 0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: HabitBar(
            store: store,
            theme: UiTheme(Palette.forMoment(13, 1.0)),
            onSelect: (_) {},
            onManage: () {},
            onAdd: () => tocado++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(
      tocado,
      1,
      reason: 'un botón apagado que no contesta parece un fallo de la app',
    );
  });
}
