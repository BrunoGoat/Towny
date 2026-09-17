import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/palette.dart';
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
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: k,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _Loud()),
            CloudFlight(t: t, palette: p),
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
    testWidgets('a mitad de camino la niebla tapa la pantalla entera', (
      tester,
    ) async {
      // Ésta es la única que importa de verdad. A la mitad del vuelo la cámara
      // salta del pueblo al valle —doscientos metros y otro giro en un
      // fotograma— y lo que hace que eso se lea como un viaje y no como un
      // fallo es que no se vea. Una rendija de dos píxeles en ese instante y el
      // truco se cae entero.
      //
      // Y se mide en un tramo y no en el fotograma de la mitad, porque el corte
      // tampoco cae exactamente ahí: el velo llega a opaco con holgura por los
      // dos lados y eso es lo que se comprueba.
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
            await _leaks(tester, k, t, Palette.forMoment(13, 1.0)),
            0,
            reason: 'se ve el mundo a t=$t en $size',
          );
        }
      }
    });

    testWidgets('y al empezar y al terminar no tapa nada', (tester) async {
      // Lo contrario, que es igual de necesario: si al acabar quedara un jirón
      // de niebla, el valle se vería a través de una gasa para siempre.
      final k = GlobalKey();
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final todo = 360 * 780;
      for (final t in [0.0, 1.0]) {
        expect(
          await _leaks(tester, k, t, Palette.forMoment(13, 1.0)),
          todo,
          reason: 'queda niebla a t=$t',
        );
      }
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
