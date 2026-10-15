import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/habit.dart';
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
  Future<void> rueda(
    WidgetTester tester,
    int veces, {
    Offset centro = const Offset(195, 422),
  }) async {
    for (var i = 0; i < veces; i++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(position: centro, scrollDelta: Offset(0, -100)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('acercarse mucho entra al pueblo de debajo', (tester) async {
    // Estando en el segundo, con la rueda encima del primero.
    final v = await valle(tester, activo: 1);
    final (cx, cz) = Habit.centreOf(0);
    final encima = v.mando.screenOf(cx, cz)!;
    await rueda(tester, 16, centro: encima);
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

  testWidgets('en el valle, alejarse tiene tope', (tester) async {
    final v = await valle(tester, activo: 1);
    final antes = v.mando.distanceTarget;
    for (var i = 0; i < 30; i++) {
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(195, 422),
          scrollDelta: Offset(0, 100),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(v.mando.distanceTarget, lessThanOrEqualTo(antes * 1.3 + 0.001));
    expect(v.mando.distanceTarget, greaterThan(antes));
    expect(v.mando.aloft, isTrue);
  });

  for (final activo in [0, 1]) {
    testWidgets(
      'el valle gira alrededor del pueblo del que se sale ($activo)',
      (tester) async {
        // Antes giraba siempre alrededor del centro, que es el primer pueblo:
        // saliendo del segundo, uno se encontraba girando alrededor de otro.
        final v = await valle(tester, activo: activo);
        final (cx, cz) = Habit.centreOf(activo);
        expect(v.mando.aim.x, closeTo(cx, 1e-6));
        expect(v.mando.aim.z, closeTo(cz, 1e-6));
      },
    );
  }

  testWidgets('en el valle, un dedo gira alrededor, como en el pueblo', (
    tester,
  ) async {
    // Hubo una cámara de mapa —un dedo corría el suelo— y era fácil perderse:
    // con cualquier gesto uno se pasaba de pueblo. Ahora gira sin moverse de
    // donde está mirando.
    final v = await valle(tester, activo: 1);
    final antes = v.mando.aim;
    final g = await tester.startGesture(const Offset(195, 500));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-12, -8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 400));
    final ahora = v.mando.aim;
    expect((ahora.yaw - antes.yaw).abs(), greaterThan(0.2));
    expect(ahora.x, closeTo(antes.x, 1e-9));
    expect(ahora.z, closeTo(antes.z, 1e-9));
    expect(v.mando.aloft, isTrue);
  });

  testWidgets('dos dedos lo corren, y no se sale del valle', (tester) async {
    final v = await valle(tester, activo: 1);
    final antes = v.mando.aim;
    final a = await tester.startGesture(const Offset(150, 300), pointer: 1);
    final b = await tester.startGesture(const Offset(240, 300), pointer: 2);
    for (var i = 0; i < 200; i++) {
      await a.moveBy(const Offset(0, 6));
      await b.moveBy(const Offset(0, 6));
    }
    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 100));
    final ahora = v.mando.aim;
    final corrido = math.sqrt(
      math.pow(ahora.x - antes.x, 2) + math.pow(ahora.z - antes.z, 2),
    );
    expect(corrido, greaterThan(3));
    // Dos pueblos: el valle no pasa de unas decenas de metros del centro.
    expect(math.sqrt(ahora.x * ahora.x + ahora.z * ahora.z), lessThan(200));
  });

  testWidgets('con el botón derecho del ratón gira', (tester) async {
    final v = await valle(tester, activo: 1);
    final antes = v.mando.aim;
    final g = await tester.startGesture(
      const Offset(195, 422),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect((v.mando.aim.yaw - antes.yaw).abs(), greaterThan(0.3));
    expect(v.mando.aim.x, closeTo(antes.x, 1e-9));
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
