import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/town_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tocar el tablón y el atril desde el pueblo, que es lo único que importa de
/// todo esto: lo demás —cuánto miden los blancos, si se pisan— son medios.
///
/// Lo que pasaba, y se vio usando la app: en un pueblo crecido no se podía
/// abrir ninguno de los dos. El blanco salía de **una sola cara** —la plancha,
/// la tapa del libro—, las dos miran a la fuente y la cámara se planta en otro
/// ángulo, así que de lo que se veía era el canto. Con el pueblo chico colaba;
/// según crece, la cámara se aleja con el radio, el canto baja de doce píxeles
/// por los dos lados y el blanco **se descartaba entero**. Medido: el atril se
/// quedaba sin blanco a partir de las ochenta piezas y el tablón a partir de
/// las seiscientas.
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
            onLecternTapped: (_) => abierto.add('atril'),
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

  group('el tablón y el atril se abren tocándolos', () {
    // Ochenta y seiscientas son las dos cuentas en las que se rompía cada uno,
    // y mil es un pueblo de los que existen de verdad después de un año.
    for (final piezas in [10, 80, 300, 600, 1000]) {
      testWidgets('con $piezas piezas', (tester) async {
        final p = await pueblo(tester, piezas);
        expect(
          p.mando.boardTargets,
          isNotEmpty,
          reason: 'con $piezas piezas el tablón no tiene dónde tocarse',
        );
        expect(
          p.mando.lecternTargets,
          isNotEmpty,
          reason: 'con $piezas piezas el atril no tiene dónde tocarse',
        );

        await p.tocar(p.mando.boardTargets.first.center);
        expect(p.abierto, ['tablón'], reason: 'con $piezas piezas');
        p.abierto.clear();

        await p.tocar(p.mando.lecternTargets.first.center);
        expect(p.abierto, ['atril'], reason: 'con $piezas piezas');

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }

    /// Y el uno no se come al otro.
    ///
    /// Mientras el blanco fue la silueta de cada mueble daba igual el orden:
    /// están a lados opuestos de la fuente y no se tocan nunca. Desde que
    /// crecen hasta la yema de un pulgar sí se pisan desde algunos ángulos, y
    /// mirándolos en orden —el tablón primero— había ángulos desde los que el
    /// atril no se podía abrir. Ahora gana el que tenga el mueble más cerca
    /// del dedo, que es el que se quiso.
    testWidgets('aunque los blancos se pisen', (tester) async {
      final p = await pueblo(tester, 300);
      // Se da la vuelta al pueblo hasta encontrar un ángulo en el que el
      // blanco del tablón tape el centro del atril. Existe —lo encuentra en
      // una vuelta— y es donde el orden fijo dejaba el atril sin abrir.
      var pisados = false;
      for (var k = 0; k < 60 && !pisados; k++) {
        // Más de kPanSlop de tirón, o el gesto no llega a ser un giro: por
        // debajo de eso Flutter se lo queda el toque y la cámara no se mueve.
        final g = await tester.startGesture(const Offset(195, 500));
        await g.moveBy(const Offset(-40, 0));
        await g.moveBy(const Offset(-40, 0));
        await g.up();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        final b = p.mando.boardTargets;
        final a = p.mando.lecternTargets;
        pisados =
            b.isNotEmpty && a.isNotEmpty && b.first.contains(a.first.center);
      }
      expect(
        pisados,
        isTrue,
        reason:
            'no se encontró ningún ángulo en el que se pisen: '
            'la prueba no estaría probando nada',
      );
      p.abierto.clear();

      final atril = p.mando.lecternTargets.first;
      await p.tocar(atril.center);
      expect(p.abierto, [
        'atril',
      ], reason: 'el blanco del tablón tapa al atril y se lo come');
      p.abierto.clear();
      await p.tocar(p.mando.boardTargets.first.center);
      expect(p.abierto, ['tablón']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
