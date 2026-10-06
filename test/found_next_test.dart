import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/town_view.dart';

/// Fundar el pueblo siguiente: la cámara vuela hasta él, y la plaza cae
/// recién cuando llegó. Si cayera en el mismo momento, caería mientras la
/// cámara todavía mira el pueblo de antes, y no se vería.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la plaza espera a la cámara, y cae cuando llega', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setSoundOff(true);
    await Appearance.instance.setMusicOff(true);
    final store = Store();
    await store.load();
    for (var i = 0; i < 40; i++) {
      store.lay(store.habit, DateTime.now().subtract(Duration(days: 60 - i)));
    }
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
    await tester.pump(const Duration(seconds: 3));
    expect(mando.founding, 1.0);

    // Lo que hace el «+» al terminar la pantalla de fundar.
    store.addHabit('Correr', 'carrera');
    store.justFounded = true;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    // Lejos todavía: la plaza no empezó.
    expect(mando.farFromTown, greaterThan(1.2));
    expect(mando.founding, lessThan(0), reason: 'cayó antes de que llegara');

    // Vuela. Cuando la plaza empieza a caer, la cámara ya está encima.
    var empezo = false;
    for (var i = 0; i < 400 && !empezo; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (mando.founding >= 0) {
        empezo = true;
        expect(mando.farFromTown, lessThanOrEqualTo(1.2));
      }
    }
    expect(empezo, isTrue, reason: 'la plaza no cayó nunca');

    // Y termina de caer.
    await tester.pump(const Duration(seconds: 4));
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(mando.founding, 1.0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
