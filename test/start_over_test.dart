import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/settings_sheet.dart';
import 'package:towny/ui/style.dart';

/// Empezar de cero desde ajustes: borra el valle y vuelve a la primera vez,
/// pero sólo después de decir que sí.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Store> abrirAjustes(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setOnboarded();
    final store = Store();
    await store.load();
    store.renameHabit(0, name: 'Leer', symbol: 'libro');
    store.addHabit('Correr', 'carrera');
    for (var i = 0; i < 5; i++) {
      store.placePiece();
    }
    await tester.binding.setSurfaceSize(const Size(393, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => SettingsSheet(
                  store: store,
                  theme: UiTheme(Palette.forMoment(11)),
                ),
              ),
              child: const Text('ajustes'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ajustes'));
    await tester.pumpAndSettle();
    final fila = find.text('Empezar de cero');
    await tester.scrollUntilVisible(fila, 120);
    await tester.ensureVisible(fila);
    await tester.pumpAndSettle();
    await tester.tap(fila);
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('pregunta antes, y decir que no no toca nada', (tester) async {
    final store = await abrirAjustes(tester);
    expect(find.text('¿Borrar todo y empezar de cero?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(store.habits.length, 2);
    expect(store.total, 5);
    expect(Appearance.instance.onboarded, isTrue);
  });

  testWidgets('decir que sí borra el valle y vuelve a la primera vez', (
    tester,
  ) async {
    final store = await abrirAjustes(tester);
    await tester.tap(find.text('Borrar todo'));
    await tester.pumpAndSettle();
    expect(store.habits.length, 1);
    expect(store.total, 0);
    expect(Appearance.instance.onboarded, isFalse);
    // Y la hoja de ajustes se cerró sola.
    expect(find.text('AJUSTES'), findsNothing);
    // Y no queda nada en el disco: al volver a abrir, un valle en blanco.
    final again = Store();
    await again.load();
    expect(again.habits.length, 1);
    expect(again.total, 0);
  });
}
