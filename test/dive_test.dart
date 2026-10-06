import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/style.dart';
import 'package:towny/ui/town_view.dart';

/// Acercarse mucho desde la vista del valle es entrar al pueblo que uno tiene
/// debajo: el mismo viaje que tocar su cartel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({TownViewController mando, List<int> tocados})> valle(
    WidgetTester tester, {
    required int activo,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.setSoundOff(true);
    await Appearance.instance.setMusicOff(true);
    final store = Store();
    await store.load();
    store.addHabit('Correr', 'carrera');
    store.select(activo);
    store.justFounded = false;
    final tocados = <int>[];
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
            onTownTapped: tocados.add,
            onBoardTapped: (_) {},
            onWhisper: (_, {duration = Duration.zero}) {},
            onPaletteChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    mando.frameValley();
    await tester.pump(const Duration(seconds: 3));
    expect(mando.aloft, isTrue);
    // Y lo avisa, que es lo que enciende el botón del valle.
    expect(mando.aloftNow.value, isTrue);
    return (mando: mando, tocados: tocados);
  }

  // La rueda del ratón, que en la web es el zoom. El pellizco va por el mismo
  // camino.
  Future<void> rueda(WidgetTester tester, int veces) async {
    const centro = Offset(195, 422);
    for (var i = 0; i < veces; i++) {
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: centro,
          scrollDelta: Offset(0, -100),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('acercarse mucho entra al pueblo de debajo', (tester) async {
    // El pueblo uno está en el centro del valle, y estando en el otro, ir
    // hacia el centro es ir hacia él.
    final v = await valle(tester, activo: 1);
    await rueda(tester, 16);
    expect(v.tocados, [0]);
    expect(v.mando.aloft, isFalse);
    expect(v.mando.aloftNow.value, isFalse);
  });

  testWidgets('acercarse un poco sigue siendo mirar el valle', (tester) async {
    final v = await valle(tester, activo: 1);
    await rueda(tester, 7);
    expect(v.tocados, isEmpty);
    expect(v.mando.aloft, isTrue);
  });

  testWidgets('y si el de debajo es el tuyo, baja a él', (tester) async {
    final v = await valle(tester, activo: 0);
    await rueda(tester, 16);
    expect(v.tocados, isEmpty);
    expect(v.mando.aloft, isFalse);
  });

  testWidgets('el botón encendido va del color de la hora', (tester) async {
    final t = UiTheme(Palette.forMoment(13));
    Color colorDe(bool on) {
      return tester.widget<Icon>(find.byIcon(Icons.travel_explore)).color!;
    }

    for (final on in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: GhostButton(
            icon: Icons.travel_explore,
            theme: t,
            on: on,
            onTap: () {},
          ),
        ),
      );
      if (on) {
        expect(colorDe(on), t.accent);
      } else {
        expect(colorDe(on), isNot(t.accent));
      }
    }
  });
}
