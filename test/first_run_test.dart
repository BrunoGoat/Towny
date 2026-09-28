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

/// Toca una hora en el reloj del plan.
///
/// El reloj abre centrado en la hora que sea ahora mismo —que en una prueba es
/// la de verdad— así que primero se lleva al principio del día y desde ahí se
/// busca hacia adelante. Sin eso, la prueba pasaría o no según la hora a la que
/// alguien la ejecute.
Future<void> _tocarHora(WidgetTester tester, String hora) async {
  final reel = find.byType(ListView);
  await tester.drag(reel, const Offset(2400, 0));
  await tester.pump();
  await tester.scrollUntilVisible(
    find.text(hora),
    60,
    scrollable: find.descendant(of: reel, matching: find.byType(Scrollable)),
  );
  // Y visible de verdad: una lista construye un poco más de lo que enseña, así
  // que `scrollUntilVisible` la encuentra estando todavía fuera de cuadro y el
  // toque no llega a ella.
  await tester.ensureVisible(find.text(hora));
  await tester.pump();
  await tester.tap(find.text(hora));
  await _asentar(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setSoundOff(true);
  });

  group('la primera vez', () {
    testWidgets('las seis pantallas, y lo que se contestó llega entero', (
      tester,
    ) async {
      // Los nombres de fuera no pueden llamarse igual que los parámetros con
      // nombre de la llamada, que si no los tapan.
      String? elNombre, laMarca, elMotivo, elMinimo, elSitio, laIdentidad;
      int? laHora;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (n, s, {why, floor, vowHour, vowPlace, identity}) {
              elNombre = n;
              laMarca = s;
              elMotivo = why;
              elMinimo = floor;
              laHora = vowHour;
              elSitio = vowPlace;
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
      await tester.tap(find.text('SEGUIR'));
      await _asentar(tester);

      // El plan: la hora se toca en el reloj y el sitio se escribe.
      expect(find.text('¿Cuándo y dónde?'), findsOneWidget);
      await _tocarHora(tester, '22');
      await tester.enterText(find.byType(TextField).first, 'la cama');
      await tester.pump();
      // Y la promesa se ve armada antes de seguir, que es lo que la hace una
      // promesa y no dos campos.
      expect(find.text('Voy a leer a las 22 de la noche, en la cama.'),
          findsOneWidget);
      await tester.tap(find.text('SEGUIR'));
      await _asentar(tester);

      await tester.enterText(find.byType(TextField).first, 'para dormir mejor');
      await tester.pump();
      await tester.tap(find.text('SEGUIR'));
      await _asentar(tester);

      expect(find.text('¿En quién te convierte?'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        'alguien que lee todos los días',
      );
      await tester.pump();
      await tester.tap(find.text('SEGUIR'));
      await _asentar(tester);

      await tester.enterText(find.byType(TextField).first, 'una página');
      await tester.pump();
      await tester.tap(find.text('FUNDAR LEER'));
      await _asentar(tester);

      expect(elNombre, 'Leer');
      expect(laMarca, isNotEmpty);
      expect(elMotivo, 'para dormir mejor');
      expect(elMinimo, 'una página');
      expect(laHora, 22);
      expect(elSitio, 'la cama');
      expect(laIdentidad, 'alguien que lee todos los días');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'las cuatro se pueden saltar, que para eso son opcionales',
      (tester) async {
        // Se guardaron para el día malo, y obligar a escribirlas el día uno es
        // la manera de que salgan mal.
        String? elMotivo = 'sin tocar', elMinimo = 'sin tocar';
        String? elSitio = 'sin tocar', laIdentidad = 'sin tocar';
        int? laHora = 99;
        await tester.pumpWidget(
          _marco(
            FirstRun(
              onDone: (n, s, {why, floor, vowHour, vowPlace, identity}) {
                elMotivo = why;
                elMinimo = floor;
                laHora = vowHour;
                elSitio = vowPlace;
                laIdentidad = identity;
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
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.text('Ahora no'));
          await _asentar(tester);
        }
        expect(elMotivo, isNull);
        expect(elMinimo, isNull);
        expect(laHora, isNull);
        expect(elSitio, isNull);
        expect(laIdentidad, isNull);
      },
    );

    testWidgets('saltarse el plan no guarda la hora que se había tocado', (
      tester,
    ) async {
      // La hora se toca antes de decidir que no, y «ahora no» quiere decir que
      // no hay plan: un plan a medias guardado por descuido saldría mañana en
      // el tablón como si lo hubieras prometido.
      int? laHora = 99;
      String? elSitio = 'sin tocar';
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (n, s, {why, floor, vowHour, vowPlace, identity}) {
              laHora = vowHour;
              elSitio = vowPlace;
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
      await _tocarHora(tester, '07');
      await tester.enterText(find.byType(TextField).first, 'el parque');
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Ahora no'));
        await _asentar(tester);
      }
      expect(laHora, isNull);
      expect(elSitio, isNull);
    });

    testWidgets('no se puede seguir sin decir qué querés hacer', (
      tester,
    ) async {
      var fundado = false;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (_, _, {why, floor, vowHour, vowPlace, identity}) =>
                fundado = true,
          ),
        ),
      );
      await _asentar(tester);
      await tester.tap(find.text('FUNDAR MI PUEBLO'));
      await _asentar(tester);
      // El botón está a la vista pero apagado: que se vea dónde está la salida
      // antes de poder usarla es la mitad de saber cuánto falta.
      expect(find.text('SEGUIR'), findsOneWidget);
      await tester.tap(find.text('SEGUIR'));
      await _asentar(tester);
      expect(find.text('¿Cuándo y dónde?'), findsNothing);
      expect(fundado, isFalse);
    });

    testWidgets('y tampoco se puede seguir con el plan en blanco', (
      tester,
    ) async {
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (_, _, {why, floor, vowHour, vowPlace, identity}) {},
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
      // Ni hora ni sitio: el botón está apagado y hay que usar «ahora no».
      await tester.tap(find.text('SEGUIR'));
      await _asentar(tester);
      expect(find.text('¿Cuándo y dónde?'), findsOneWidget);
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
