import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/town_view.dart';

/// Tocar el tablón desde el pueblo, que es lo único que importa de todo esto:
/// lo demás —cuánto miden los blancos— son medios.
///
/// Lo que pasaba, y se vio usando la app: en un pueblo crecido no se podía
/// abrir. El blanco salía de **una sola cara** —la plancha—, que mira a la
/// fuente, y la cámara se planta en otro ángulo, así que de lo que se veía era
/// el canto. Con el pueblo chico colaba; según crece, la cámara se aleja con el
/// radio, el canto baja de doce píxeles y el blanco **se descartaba entero**.
/// Medido: a partir de las seiscientas piezas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Un pueblo de [piezas] piezas, montado como lo monta la app.
  Future<
    ({
      TownViewController mando,
      List<String> abierto,
      Future<void> Function(Offset) tocar,
    })
  >
  pueblo(WidgetTester tester, int piezas) async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.setSoundOff(true);
    await Appearance.instance.setMusicOff(true);
    final store = Store();
    await store.load();
    for (var i = 0; i < piezas; i++) {
      store.lay(store.habit, DateTime.now().subtract(Duration(days: 400 - i)));
    }
    store.justFounded = false;

    final abierto = <String>[];
    final mando = TownViewController();
    const size = Size(390, 844);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TownView(
            store: store,
            controller: mando,
            onTownLandmark: (_, _) {},
            onPlaced: (_) {},
            onStoneTapped: (_) => abierto.add('piedra'),
            onNothingTapped: () => abierto.add('nada'),
            onCameraMoved: () {},
            onFlewOut: () {},
            onSkyTapped: (_) => abierto.add('cielo'),
            onTownTapped: (_) => abierto.add('pueblo'),
            onBoardTapped: (_) => abierto.add('tablón'),
            onWhisper: (_, {duration = Duration.zero}) {},
            onPaletteChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump(const Duration(seconds: 3));
    expect(size, const Size(390, 844));

    // Un dedo de verdad: aprieta, se mueve un pelo, suelta. Y se le deja
    // expirar el reloj del doble toque, que es lo que hace esperar al simple.
    Future<void> tocar(Offset donde) async {
      final g = await tester.startGesture(donde);
      await tester.pump(const Duration(milliseconds: 90));
      await g.moveBy(const Offset(2, 1));
      await g.up();
      await tester.pump(const Duration(milliseconds: 350));
    }

    return (mando: mando, abierto: abierto, tocar: tocar);
  }

  group('el tablón se abre tocándolo', () {
    // Seiscientas es la cuenta en la que se rompía, y mil es un pueblo de los
    // que existen de verdad después de un año.
    for (final piezas in [10, 80, 300, 600, 1000]) {
      testWidgets('con $piezas piezas', (tester) async {
        final p = await pueblo(tester, piezas);
        expect(
          p.mando.boardTargets,
          isNotEmpty,
          reason: 'con $piezas piezas el tablón no tiene dónde tocarse',
        );

        await p.tocar(p.mando.boardTargets.first.center);
        expect(p.abierto, ['tablón'], reason: 'con $piezas piezas');

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });
}
