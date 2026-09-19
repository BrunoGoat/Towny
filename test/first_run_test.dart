import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/engine/world.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/ui/first_run.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _marco(Widget child) => MediaQuery(
  data: const MediaQueryData(
    size: Size(390, 844),
    padding: EdgeInsets.only(top: 44, bottom: 24),
  ),
  child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
);

Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setSoundOff(true);
  });

  group('la primera vez', () {
    testWidgets('las cuatro pantallas, y lo que se contestó llega entero', (
      tester,
    ) async {
      String? name, symbol, why, floor;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (n, s, w, f) {
              name = n;
              symbol = s;
              why = w;
              floor = f;
            },
          ),
        ),
      );
      await _asentar(tester);

      await tester.tap(find.text('FUNDAR MI PUEBLO'));
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'Leer');
      await tester.pump();
      await tester.tap(find.text('SEGUIR'));
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'para dormir mejor');
      await tester.pump();
      await tester.tap(find.text('SEGUIR'));
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'una página');
      await tester.pump();
      await tester.tap(find.text('FUNDAR LEER'));
      await _asentar(tester);

      expect(name, 'Leer');
      expect(symbol, isNotEmpty);
      expect(why, 'para dormir mejor');
      expect(floor, 'una página');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'las dos frases se pueden saltar, que para eso son opcionales',
      (tester) async {
        // Se guardaron para el día malo, y obligar a escribirlas el día uno es
        // la manera de que salgan mal.
        String? why = 'sin tocar', floor = 'sin tocar';
        await tester.pumpWidget(
          _marco(
            FirstRun(
              onDone: (n, s, w, f) {
                why = w;
                floor = f;
              },
            ),
          ),
        );
        await _asentar(tester);
        await tester.tap(find.text('FUNDAR MI PUEBLO'));
        await _asentar(tester);
        await tester.enterText(find.byType(TextField).first, 'Correr');
        await tester.pump();
        await tester.tap(find.text('SEGUIR'));
        await _asentar(tester);
        await tester.tap(find.text('Ahora no'));
        await _asentar(tester);
        await tester.tap(find.text('Ahora no'));
        await _asentar(tester);
        expect(why, isNull);
        expect(floor, isNull);
      },
    );

    testWidgets('no se puede seguir sin decir qué querés hacer', (
      tester,
    ) async {
      var fundado = false;
      await tester.pumpWidget(
        _marco(FirstRun(onDone: (_, _, _, _) => fundado = true)),
      );
      await _asentar(tester);
      await tester.tap(find.text('FUNDAR MI PUEBLO'));
      await _asentar(tester);
      // El botón está a la vista pero apagado: que se vea dónde está la salida
      // antes de poder usarla es la mitad de saber cuánto falta.
      expect(find.text('SEGUIR'), findsOneWidget);
      await tester.tap(find.text('SEGUIR'));
      await _asentar(tester);
      expect(find.text('¿Para qué lo querés?'), findsNothing);
      expect(fundado, isFalse);
    });
  });

  group('la plaza', () {
    test('existe desde que se funda, no desde la primera pieza', () {
      // Antes hacía falta una pieza puesta, y eso era una plaza apareciendo de
      // la nada a la vez que la primera casa.
      for (final ch in TownCharacter.all) {
        final l = TownLayout(0, ch, seed: 3);
        final t = builtTown(l, 0);
        expect(
          t.clusters,
          isNotEmpty,
          reason: '${ch.region}: un pueblo fundado sin plaza',
        );
        expect(t.bounds, isNotNull);
      }
    });

    test('y el expositor no la tiene, que no es un pueblo', () {
      // El expositor planta una estructura sola en un prado, sobre su peana.
      // Una plaza ahí sería decorado de un sitio que no existe.
      final ch = TownCharacter.all.first;
      final solo = TownLayout.showcase(
        ch,
        kind: BuildingKind.values.first,
        placed: 0,
      );
      int caras(TownLayout l) =>
          builtTown(l, 0).clusters.fold<int>(0, (a, c) => a + c.faces);
      // Por caras y no por grupos: el enlosado, el tablón y el atril se tocan,
      // así que el árbol los funde en uno solo y contar grupos da uno en los
      // dos casos. Lo que hay debajo de ese uno es muy distinto.
      expect(caras(solo) * 4, lessThan(caras(TownLayout(0, ch, seed: 3))));
    });
  });
}
