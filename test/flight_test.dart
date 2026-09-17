import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/model/flight_style.dart';
import 'package:la_muralla/ui/cloud_flight.dart';

/// Un fondo que no puede confundirse con una nube ni con un cielo.
class _Loud extends CustomPainter {
  const _Loud();
  @override
  void paint(Canvas c, Size s) =>
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFFF00FF));
  @override
  bool shouldRepaint(_Loud old) => false;
}

/// Cuántos píxeles del fondo sobreviven a las nubes.
Future<int> _leaks(
  WidgetTester tester,
  GlobalKey k,
  double t,
  Palette p,
  FlightStyle style,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: k,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _Loud()),
            CloudFlight(t: t, palette: p, style: style),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  var sueltos = 0;
  await tester.runAsync(() async {
    final ro = k.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: 1.0);
    final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    img.dispose();
    for (var i = 0; i < data.lengthInBytes; i += 4) {
      final r = data.getUint8(i), g = data.getUint8(i + 1);
      final b = data.getUint8(i + 2);
      // El fondo es magenta puro. Con el desenfuncado de por medio nada que
      // venga de él llega intacto, así que se cuenta lo que sigue siendo
      // rojísimo y azulísimo sin verde: eso sólo puede ser el fondo.
      if (r > 200 && b > 200 && g < 90) sueltos++;
    }
  });
  return sueltos;
}

void main() {
  group('el vuelo al valle', () {
    // Ésta es la única que importa de verdad, y va una por estilo. A la mitad
    // del vuelo la cámara salta del pueblo al valle —doscientos metros y otro
    // giro en un fotograma— y lo que hace que eso se lea como un viaje y no
    // como un fallo es que no se vea. Una rendija de dos píxeles en ese
    // instante y el truco se cae entero, y cada uno de los diez tapa a su
    // manera: un macizo más hondo que la pantalla, un agujero que llega a
    // cero, una rejilla con menos paso que radio, un velo que llega a opaco.
    // Ninguna de esas cuentas se comprueba sola.
    for (final style in FlightStyle.values) {
      testWidgets('${style.label} tapa la pantalla entera a mitad de camino', (
        tester,
      ) async {
        final k = GlobalKey();
        for (final size in [
          const Size(360, 780),
          const Size(412, 915),
          const Size(320, 640),
          const Size(820, 400),
          const Size(600, 600),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          for (final t in [0.42, 0.46, 0.5, 0.54, 0.58]) {
            expect(
              await _leaks(tester, k, t, Palette.forMoment(13, 1.0), style),
              0,
              reason: 'se ve el mundo a t=\$t en \$size con \${style.name}',
            );
          }
        }
      });
    }

    testWidgets('y al empezar y al terminar no tapan nada', (tester) async {
      // Lo contrario, que es igual de necesario: si al acabar quedara un jirón
      // de nube, el valle se vería a través de una gasa para siempre. Y vale
      // para los diez: el que se quede pegado no es el que se está mirando.
      final k = GlobalKey();
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final todo = 360 * 780;
      for (final style in FlightStyle.values) {
        for (final t in [0.0, 1.0]) {
          expect(
            await _leaks(tester, k, t, Palette.forMoment(13, 1.0), style),
            todo,
            reason: 'queda \${style.name} a t=\$t',
          );
        }
      }
    });

    test('los diez duran algo razonable y se guardan por su nombre', () {
      // Lo que se guarda en el disco es el nombre, así que un nombre repetido
      // o vacío sería una elección que no se puede volver a leer.
      final nombres = FlightStyle.values.map((v) => v.name).toSet();
      expect(nombres.length, FlightStyle.values.length);
      for (final style in FlightStyle.values) {
        expect(FlightStyle.byName(style.name), style);
        expect(style.label, isNotEmpty);
        expect(style.about, isNotEmpty);
        // Ni tan corto que no dé tiempo a tapar, ni tan largo que sea una
        // espera: esto se hace muchas veces al día.
        expect(style.millis, inInclusiveRange(500, 1000));
      }
      // Y lo que no existe vuelve a la de siempre en vez de reventar.
      expect(FlightStyle.byName(null), FlightStyle.cumulos);
      expect(FlightStyle.byName('lo que sea'), FlightStyle.cumulos);
    });

    test('la campana de tapado vale cero en las puntas y uno en el medio', () {
      expect(CloudFlight.coverOf(0), 0);
      expect(CloudFlight.coverOf(1), 0);
      expect(CloudFlight.coverOf(0.5), 1);
      // Y es simétrica: subir y bajar tienen que costar lo mismo.
      for (final t in [0.1, 0.25, 0.4]) {
        expect(
          CloudFlight.coverOf(t),
          closeTo(CloudFlight.coverOf(1 - t), 1e-9),
        );
      }
    });
  });
}
