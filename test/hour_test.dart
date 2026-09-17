import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:la_muralla/ui/town_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fingir la hora', () {
    // El pueblo siempre hizo caso a la hora fingida —el cielo, la música, las
    // ventanas encendidas—, pero la interfaz no: los botones, los rótulos y
    // las hojas salen de un tema que se armaba **una sola vez**, en el primer
    // fotograma, y de ahí en adelante se quedaba con el color que tuviera el
    // cielo al abrir la app. Al fingir la noche el pueblo se hacía de noche y
    // la interfaz seguía siendo la parda del mediodía, con los botones casi
    // invisibles sobre un cielo negro.
    testWidgets('la interfaz se va con el cielo fingido', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // Sin sonido: lo que se está probando es la luz, y el reproductor de
      // audio no existe dentro de un test.
      await Appearance.instance.setSoundOff(true);
      await Appearance.instance.setFakeHour(false);
      final store = Store();
      await store.load();

      final vistas = <Palette>[];
      final mando = TownViewController();
      Widget arbol() => MaterialApp(
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
            onLecternTapped: (_) {},
            onWhisper: (_) {},
            onPaletteChanged: vistas.add,
          ),
        ),
      );

      await tester.pumpWidget(arbol());
      await tester.pump(const Duration(milliseconds: 40));
      expect(vistas, isNotEmpty, reason: 'no dijo con qué luz empezaba');

      // Mediodía fingido: la interfaz tiene que quedar clara.
      await Appearance.instance.setFakeHour(true);
      await Appearance.instance.setFakeHourAt(13.0);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        UiTheme(vistas.last).dark,
        isFalse,
        reason: 'el mediodía salió oscuro',
      );

      // Y las tres de la mañana, oscura. Esto es lo que no pasaba.
      await Appearance.instance.setFakeHourAt(3.0);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        UiTheme(vistas.last).dark,
        isTrue,
        reason: 'se fingió la madrugada y la interfaz siguió siendo de día',
      );

      await Appearance.instance.setFakeHour(false);
      await Appearance.instance.setSoundOff(false);
      await Appearance.instance.flush();
      // Y desmontar antes de irse, dándole a lo que guarda en el disco el
      // tiempo de su propio temporizador: si no, el andamio se queja de un
      // reloj pendiente y el fallo no es el que se está mirando.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
