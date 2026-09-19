import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';
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
}
