import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/engine/world.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/ui/first_run.dart';

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

/// Lo que tarda en fundarse de verdad: la tarjeta se va y la cámara baja al
/// pueblo antes de avisar, que es cuando el pueblo toma el relevo.
Future<void> _bajar(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
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
    testWidgets('cinco pantallas, y lo que se contestó llega entero', (
      tester,
    ) async {
      // Los nombres de fuera no pueden llamarse igual que los parámetros con
      // nombre de la llamada, que si no los tapan.
      String? elNombre, laMarca, elMotivo, laIdentidad;
      int? laComarca;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (n, s, {required character, why, identity}) {
              elNombre = n;
              laMarca = s;
              laComarca = character;
              elMotivo = why;
              laIdentidad = identity;
            },
          ),
        ),
      );
      await _asentar(tester);

      await tester.tap(find.text('FUNDAR MI PUEBLO'));
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'Leer');
      await tester.pump();
      await tester.tap(find.text('SIGUIENTE'));
      await _asentar(tester);

      // La comarca, que es sólo cómo se ve, y que se dice así.
      expect(find.text('¿Qué clase de pueblo?'), findsOneWidget);
      expect(find.textContaining('Es sólo cómo se ve'), findsOneWidget);
      await tester.tap(find.text('Sierra'));
      await _asentar(tester);
      await tester.tap(find.text('SIGUIENTE'));
      await _asentar(tester);

      // Ni cuándo ni dónde: eso lo propone el pueblo cuando ya lo sabe.
      expect(find.text('¿Cuándo y dónde?'), findsNothing);
      expect(find.text('¿Para qué querés ese hábito?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'para dormir mejor');
      await tester.pump();
      await tester.tap(find.text('SIGUIENTE'));
      await _asentar(tester);

      expect(
        find.text('¿En quién te convierte tener ese hábito?'),
        findsOneWidget,
      );
      // El «alguien» ya está escrito delante del campo: se escribe el resto.
      expect(find.text('alguien'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        'que lee todos los días',
      );
      await tester.pump();
      // Y ésta es la última: no hay «lo mínimo que cuenta» detrás.
      await tester.tap(find.text('FUNDAR LEER'));
      await _asentar(tester);
      // Mientras baja la cámara todavía no se fundó nada: el pueblo toma el
      // relevo al llegar, no antes.
      expect(elNombre, isNull);
      expect(find.text('Leer'), findsWidgets, reason: 'el nombre, bajando');
      await _bajar(tester);

      expect(elNombre, 'Leer');
      expect(laMarca, isNotEmpty);
      expect(elMotivo, 'para dormir mejor');
      expect(laIdentidad, 'alguien que lee todos los días');
      expect(
        laComarca,
        TownCharacter.all.firstWhere((c) => c.region == 'Sierra').order,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('las dos se pueden saltar, que para eso son opcionales', (
      tester,
    ) async {
      String? elMotivo = 'sin tocar', laIdentidad = 'sin tocar';
      var fundado = false;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (n, s, {required character, why, identity}) {
              elMotivo = why;
              laIdentidad = identity;
              fundado = true;
            },
          ),
        ),
      );
      await _asentar(tester);
      await tester.tap(find.text('FUNDAR MI PUEBLO'));
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'Correr');
      await tester.pump();
      await tester.tap(find.text('SIGUIENTE'));
      await _asentar(tester);
      // La comarca no se salta: ya viene una elegida.
      await tester.tap(find.text('SIGUIENTE'));
      await _asentar(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Ahora no'));
        await _asentar(tester);
      }
      await _bajar(tester);
      expect(fundado, isTrue);
      expect(elMotivo, isNull);
      expect(laIdentidad, isNull);
    });

    testWidgets('no se puede seguir sin decir qué querés hacer', (
      tester,
    ) async {
      var fundado = false;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (_, _, {required character, why, identity}) =>
                fundado = true,
          ),
        ),
      );
      await _asentar(tester);
      await tester.tap(find.text('FUNDAR MI PUEBLO'));
      await _asentar(tester);
      // El botón está a la vista pero apagado: que se vea dónde está la salida
      // antes de poder usarla es la mitad de saber cuánto falta.
      expect(find.text('SIGUIENTE'), findsOneWidget);
      await tester.tap(find.text('SIGUIENTE'));
      await _asentar(tester);
      expect(find.text('¿Para qué querés ese hábito?'), findsNothing);
      expect(fundado, isFalse);
    });

    testWidgets('cabe en un teléfono chico, con el teclado abierto', (
      tester,
    ) async {
      for (final teclado in [0.0, 260.0]) {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 568),
              padding: const EdgeInsets.only(top: 20),
              viewInsets: EdgeInsets.only(bottom: teclado),
            ),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: FirstRun(
                onDone: (_, _, {required character, why, identity}) {},
              ),
            ),
          ),
        );
        await _asentar(tester);
        expect(tester.takeException(), isNull, reason: 'bienvenida, $teclado');
        // Con el teclado abierto la tarjeta rueda: el botón está, pero hay que
        // llegar a él.
        await tester.ensureVisible(find.text('FUNDAR MI PUEBLO'));
        await tester.pump();
        await tester.tap(find.text('FUNDAR MI PUEBLO'));
        await _asentar(tester);
        expect(tester.takeException(), isNull, reason: 'nombre, $teclado');
        await tester.enterText(find.byType(TextField).first, 'Leer');
        await tester.pump();
        await tester.ensureVisible(find.text('SIGUIENTE'));
        await tester.pump();
        await tester.tap(find.text('SIGUIENTE'));
        await _asentar(tester);
        expect(tester.takeException(), isNull, reason: 'comarca, $teclado');
        await tester.ensureVisible(find.text('SIGUIENTE'));
        await tester.pump();
        await tester.tap(find.text('SIGUIENTE'));
        await _asentar(tester);
        expect(tester.takeException(), isNull, reason: 'para qué, $teclado');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('fundar dos veces seguidas funda una sola', (tester) async {
      // Un dedo impaciente toca otra vez mientras baja la cámara.
      var veces = 0;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (_, _, {required character, why, identity}) => veces++,
          ),
        ),
      );
      await _asentar(tester);
      await tester.tap(find.text('FUNDAR MI PUEBLO'));
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'Leer');
      await tester.pump();
      await tester.tap(find.text('SIGUIENTE'));
      await _asentar(tester);
      await tester.tap(find.text('SIGUIENTE'));
      await _asentar(tester);
      await tester.tap(find.text('Ahora no'));
      await _asentar(tester);
      await tester.tap(find.text('Ahora no'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text('Ahora no'), warnIfMissed: false);
      await _bajar(tester);
      expect(veces, 1);
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
      // Por caras y no por grupos: el enlosado y el tablón se tocan,
      // así que el árbol los funde en uno solo y contar grupos da uno en los
      // dos casos. Lo que hay debajo de ese uno es muy distinto.
      expect(caras(solo) * 4, lessThan(caras(TownLayout(0, ch, seed: 3))));
    });
  });
}
