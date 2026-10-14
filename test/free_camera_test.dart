import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/town_view.dart';

/// La cámara del pueblo: girar alrededor de lo encuadrado, y moverse libre
/// con dos dedos.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TownViewController> pueblo(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.setSoundOff(true);
    await Appearance.instance.setMusicOff(true);
    final store = Store();
    await store.load();
    store.justFounded = false;
    final mando = TownViewController();
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
            onStoneTapped: (_) {},
            onNothingTapped: () {},
            onCameraMoved: () {},
            onFlewOut: () {},
            onSkyTapped: (_) {},
            onTownTapped: (_) {},
            onBoardTapped: (_) {},
            onWhisper: (_, {duration = Duration.zero}) {},
            onPaletteChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(mando.aloft, isFalse);
    return mando;
  }

  Future<void> dosDedos(WidgetTester tester, Offset paso) async {
    final a = await tester.startGesture(const Offset(150, 420), pointer: 1);
    final b = await tester.startGesture(const Offset(240, 420), pointer: 2);
    for (var i = 0; i < 12; i++) {
      await a.moveBy(paso);
      await b.moveBy(paso);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> esperar(WidgetTester tester, int segundos) async {
    for (var i = 0; i < segundos * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('dos dedos llevan el suelo hacia cualquier lado', (tester) async {
    final mando = await pueblo(tester);
    final antes = mando.aim;
    // Hacia abajo de la pantalla es hacia el fondo del pueblo, que no es el
    // eje de las x: antes, dos dedos sólo corrían la vista a lo largo de él.
    await dosDedos(tester, const Offset(0, 14));
    final despues = mando.aim;
    expect((despues.z - antes.z).abs(), greaterThan(0.5));
    final dx = despues.x - antes.x, dz = despues.z - antes.z;
    expect(math.sqrt(dx * dx + dz * dz), lessThan(60));
  });

  testWidgets('en la cámara libre el pueblo no se da vueltas solo', (
    tester,
  ) async {
    final mando = await pueblo(tester);
    await dosDedos(tester, const Offset(10, 10));
    final quieto = mando.aim.yaw;
    await esperar(tester, 12);
    expect(mando.aim.yaw, closeTo(quieto, 1e-9));
    // Y encuadrar el pueblo vuelve a la de siempre, que sí gira despacio.
    mando.frameAll();
    await tester.pump(const Duration(seconds: 1));
    final antes = mando.aim.yaw;
    await esperar(tester, 12);
    expect(mando.aim.yaw, greaterThan(antes));
  });
}
