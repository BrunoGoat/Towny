import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';
import 'package:la_muralla/model/reel.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/reel_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un hábito con [n] piezas, una al día desde el 1 de marzo, en el pueblo
/// [slot] y empezando [desde] días después del principio del valle.
Habit _habit(int n, {int slot = 0, String id = 'h', int desde = 0}) => Habit(
  id: id,
  name: 'Leer',
  symbol: 'libro',
  slot: slot,
  createdAt: DateTime(2026, 3, 1),
  character: TownCharacter.all[slot % TownCharacter.all.length].order,
  pieces: [
    for (var i = 0; i < n; i++)
      Piece(
        index: i,
        placedAt: DateTime(2026, 3, 1, 19).add(Duration(days: desde + i)),
      ),
  ],
);

Future<Store> _store(List<Habit> habits) async {
  SharedPreferences.setMockInitialValues({});
  final s = Store();
  await s.load();
  s.habits
    ..clear()
    ..addAll(habits);
  return s;
}

Widget _marco(Widget child) => MediaQuery(
  data: const MediaQueryData(
    size: Size(390, 844),
    padding: EdgeInsets.only(top: 44, bottom: 24),
  ),
  child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
);

/// Pasa la cinemática entera a saltos, pintando de verdad en cada uno.
///
/// A mano y no con `pumpAndSettle`, que aquí no vuelve nunca: la pantalla
/// tiene un `Ticker` corriendo de principio a fin, que es justamente lo que
/// `pumpAndSettle` espera que pare.
///
/// Y el paso es de cincuenta milisegundos exactos porque es el tope al que la
/// pantalla recorta el suyo. La cinemática no mira el reloj de pared: suma el
/// `dt` de cada fotograma recortado a cinco centésimas, para que volver de
/// tener el teléfono en el bolsillo no dé un salto de medio minuto. Un test
/// que empujara de cuarto en cuarto de segundo avanzaría **una quinta parte**
/// de lo que cree, y lo que vería es una cinemática que no acaba nunca.
Future<void> _correr(
  WidgetTester tester, {
  Duration paso = const Duration(milliseconds: 50),
  double segundos = 67,
}) async {
  for (var t = 0.0; t < segundos; t += paso.inMilliseconds / 1000) {
    await tester.pump(paso);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Sin música. No es por gusto: en un test no hay plugin de audio, y
    // `AudioPlayer` arranca su inicialización por su cuenta en cuanto se
    // construye — fuera de cualquier `try` que podamos poner — así que pedirle
    // que suene tira una excepción asíncrona que cae encima del test y no de
    // la pantalla. Apagada, la cinemática no la pide, y lo que se prueba aquí
    // es lo que se ve, que es de lo que va esta pantalla.
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setMusicOff(true);
  });

  testWidgets('el valle de dos pueblos se pinta entero sin caerse', (
    tester,
  ) async {
    final s = await _store([
      _habit(90, id: 'a'),
      _habit(60, id: 'b', slot: 1, desde: 30),
    ]);
    await tester.pumpWidget(_marco(ReelScreen(store: s)));
    await _correr(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('acaba enseñando lo que hay, no una pieza menos', (tester) async {
    // Ciento veinte piezas en cuatro meses, que es un uso real y no un caso de
    // laboratorio: hay ráfagas, hay huecos y hay un invierno por el medio.
    final s = await _store([_habit(120)]);
    await tester.pumpWidget(_marco(ReelScreen(store: s)));
    await _correr(tester);
    expect(tester.takeException(), isNull);
    // La tarjeta del final dice la cuenta de verdad. Es el único número que
    // esta pantalla escribe y el único que no se puede equivocar.
    expect(find.text('120'), findsOneWidget);
    expect(find.text('piezas'), findsOneWidget);
    expect(find.text('VOLVER AL VALLE'), findsOneWidget);
  });

  testWidgets('mientras corre se puede saltar, y al acabar se puede salir', (
    tester,
  ) async {
    final s = await _store([_habit(40)]);
    await tester.pumpWidget(_marco(ReelScreen(store: s)));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('SALTAR'), findsOneWidget);
    // Y la tarjeta no está antes de tiempo: sería contar el final a los tres
    // segundos de empezar.
    expect(find.text('VOLVER AL VALLE'), findsNothing);
    await _correr(tester);
    expect(find.text('SALTAR'), findsNothing);
    expect(find.text('VOLVER AL VALLE'), findsOneWidget);
  });

  testWidgets('la fecha que se enseña avanza y llega a la última', (
    tester,
  ) async {
    // Un pueblo que cruza un año entero: si la fecha no corriera, el valle no
    // cambiaría de estación y la cinemática no contaría el paso del tiempo,
    // que es la mitad de lo que tiene que contar.
    final s = await _store([_habit(200)]);
    await tester.pumpWidget(_marco(ReelScreen(store: s)));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('MARZO DE 2026'), findsOneWidget);
    await _correr(tester);
    // Doscientos días desde el 1 de marzo caen en septiembre.
    expect(find.text('SEPTIEMBRE DE 2026'), findsOneWidget);
  });

  testWidgets('un pueblo sin crónica no abre nada y no revienta', (
    tester,
  ) async {
    final s = await _store([_habit(0)]);
    await tester.pumpWidget(_marco(ReelScreen(store: s)));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('la corta enseña el pueblo hecho y le tira encima lo que llegó', (
    tester,
  ) async {
    final h = _habit(40);
    final s = await _store([h]);
    // Las tres últimas son las que se tocaron en el widget.
    final llegaron = [
      for (final p in h.pieces.skip(37)) ReelStep(p.placedAt, 0, null),
    ];
    await tester.pumpWidget(
      _marco(ReelScreen.arrivals(store: s, pieces: llegaron)),
    );
    await _correr(tester, segundos: 14);
    expect(tester.takeException(), isNull);
    // La tarjeta cuenta lo que llegó, no el pueblo entero: quien abre la app
    // ya sabe cuántas piezas tiene, y lo que no sabe es cuántas puso sin mirar.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('piezas'), findsOneWidget);
    expect(find.text('desde la pantalla de inicio'), findsOneWidget);
    expect(find.text('AL VALLE'), findsOneWidget);
  });

  testWidgets('con una sola pieza también, y dice «pieza»', (tester) async {
    // El caso de todos los días: una pieza, una vez, sin abrir la app.
    final h = _habit(12);
    final s = await _store([h]);
    await tester.pumpWidget(
      _marco(
        ReelScreen.arrivals(
          store: s,
          pieces: [ReelStep(h.pieces.last.placedAt, 0, null)],
        ),
      ),
    );
    await _correr(tester, segundos: 14);
    expect(tester.takeException(), isNull);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('pieza'), findsOneWidget);
  });

  testWidgets('y sin nada que enseñar se va sola en vez de quedarse en negro', (
    tester,
  ) async {
    final s = await _store([_habit(5)]);
    await tester.pumpWidget(
      _marco(ReelScreen.arrivals(store: s, pieces: const [])),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('el acercamiento no vuelve atrás nunca', (tester) async {
    // El fallo que esto vigila se vio mirándolo y no leyéndolo: el encuadre
    // salía de lo que había construido en ese fotograma, así que crecía con
    // cada pieza y la cámara se alejaba un poco en cada ráfaga y volvía a
    // acercarse en cada pausa. Visto seguido es un zoom que respira, y no hay
    // texto en pantalla que lo delate.
    final s = await _store([_habit(160)]);
    await tester.pumpWidget(_marco(ReelScreen.town(store: s, habit: 0)));
    final estado = tester.state<ReelScreenState>(find.byType(ReelScreen));
    var antes = double.infinity;
    var peor = 0.0;
    for (var t = 0.0; t < 60; t += 0.05) {
      await tester.pump(const Duration(milliseconds: 50));
      final d = estado.camera.distance;
      if (d > antes) peor = math.max(peor, d - antes);
      antes = d;
    }
    expect(
      peor,
      lessThan(1e-6),
      reason: 'la cámara se alejó $peor en mitad de la cinemática',
    );
  });

  testWidgets('y en el valle tampoco, aunque salte de pueblo en pueblo', (
    tester,
  ) async {
    final s = await _store([
      _habit(70, id: 'a'),
      _habit(50, id: 'b', slot: 1, desde: 20),
    ]);
    await tester.pumpWidget(_marco(ReelScreen(store: s)));
    final estado = tester.state<ReelScreenState>(find.byType(ReelScreen));
    var antes = double.infinity;
    for (var t = 0.0; t < 60; t += 0.05) {
      await tester.pump(const Duration(milliseconds: 50));
      final d = estado.camera.distance;
      expect(d, lessThanOrEqualTo(antes + 1e-6), reason: 'se alejó en $t s');
      antes = d;
    }
  });

  testWidgets('la crónica de un pueblo no enseña los otros', (tester) async {
    // Lo que se pidió es poder mirar **un** pueblo, no el valle encuadrado
    // sobre uno: si las piezas de los demás siguieran cayendo, la cinemática
    // contaría otra cosa de la que dice contar.
    final s = await _store([_habit(40, id: 'a'), _habit(40, id: 'b', slot: 1)]);
    await tester.pumpWidget(_marco(ReelScreen.town(store: s, habit: 1)));
    await _correr(tester);
    expect(tester.takeException(), isNull);
    // Cuarenta, las de ese pueblo, y no ochenta.
    expect(find.text('40'), findsOneWidget);
  });
}
