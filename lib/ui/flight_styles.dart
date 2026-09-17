import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/rng.dart';
import '../engine/palette.dart';
import '../model/flight_style.dart';

export '../model/flight_style.dart';

/// Los tres tonos de una nube: la panza, el cuerpo y la cara de arriba.
///
/// Tres y no cinco. Con cinco había volumen de sobra y también un contorno
/// oscuro alrededor de cada cúmulo, y eso no es una nube: es una ilustración de
/// una nube, con su línea de tinta.
///
/// **Y los tres son pastel**: mezclados con mucho blanco, así que entre uno y
/// otro hay un paso y no un salto. Lo que hace que se lea el volumen es que los
/// tres estén ordenados, no que estén lejos.
///
/// Salen de la paleta de la hora y no de una lista de grises, que es lo que
/// hace que a las seis de la tarde tiren a miel y de madrugada sean apenas una
/// mancha más clara que la noche — que es lo que es una nube de noche.
class FlightTones {
  FlightTones(Palette p)
    : sombra = Color.lerp(p.skyHorizon, Colors.white, 0.60)!,
      medio = Color.lerp(p.skyHorizon, Colors.white, 0.80)!,
      luz = Color.lerp(
        Color.lerp(p.skyHorizon, Colors.white, 0.94)!,
        p.sun,
        p.isDaylight ? 0.14 : 0.06,
      )!,
      // El gris del chaparrón, que es el único que no es pastel: un aguacero
      // que no oscurece no es un aguacero.
      plomo = Color.lerp(p.skyHorizon, const Color(0xFF4A5560), 0.55)!;

  final Color sombra, medio, luz, plomo;

  Color at(int i) => [sombra, medio, luz][i % 3];
}

/// Todo lo que las diez comparten: la campana de tapado y los trazos.
class FlightPaint {
  const FlightPaint._();

  /// Cuánto tapa ahora mismo: sube hasta uno a la mitad y baja.
  ///
  /// No es un triángulo sino una campana con los flancos estirados, porque lo
  /// que se está escondiendo es un instante —el corte— y lo que se quiere es
  /// que ese instante quede bien dentro del tapado, no rozándolo.
  static double coverOf(double t) {
    final x = (t.clamp(0.0, 1.0) * 2 - 1).abs();
    final k = 1 - x * x;
    return k * k;
  }

  /// Cuánto desenfoca cada estilo.
  ///
  /// Se apaga en cuanto tapa del todo: desenfocar la pantalla entera es lo más
  /// caro que hay aquí y en ese tramo no cambia un solo píxel.
  static double blurOf(FlightStyle style, double t) {
    final cover = coverOf(t);
    final base = math.sin(math.pi * t.clamp(0.0, 1.0)) * (1 - cover);
    return base *
        switch (style) {
          FlightStyle.niebla => 26.0,
          FlightStyle.picado => 24.0,
          FlightStyle.tormenta => 20.0,
          FlightStyle.cirros => 9.0,
          FlightStyle.nevada => 12.0,
          _ => 16.0,
        };
  }

  /// Un racimo de lóbulos: la mancha de la que están hechas casi todas.
  static void blob(
    Canvas canvas,
    Offset at,
    double r,
    int s,
    Color color, {
    double aplanar = 0.66,
    int lobes = 8,
  }) {
    final path = Path();
    for (var k = 0; k < lobes; k++) {
      final a = k * 2 * math.pi / lobes + hashRange(0, 0.7, s, 10 + k);
      final d = r * hashRange(0.26, 0.54, s, 20 + k);
      path.addOval(
        Rect.fromCircle(
          center: at + Offset(math.cos(a) * d, math.sin(a) * d * aplanar),
          radius: r * hashRange(0.44, 0.70, s, 30 + k),
        ),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Un cúmulo con volumen: tres pasadas, de la panza a la cara de arriba.
  ///
  /// Cada pasada es el mismo racimo encogido y corrido hacia la luz, así que lo
  /// que queda es una cebolla de tres tonos con la cara clara arriba del lado
  /// del sol. **Ninguna pasada es más grande que la primera**, y eso es lo que
  /// quita el contorno: una pasada más ancha que el cuerpo asoma por todo el
  /// borde y se lee como una línea de tinta.
  static void cumulus(
    Canvas canvas,
    Offset at,
    double r,
    int s,
    FlightTones tone,
    Offset hacia, {
    bool arriba = true,
  }) {
    final capas = arriba
        ? const [(1.00, 0.00, 0), (0.84, 0.13, 1), (0.60, 0.29, 2)]
        : const [(1.00, 0.00, 0), (0.78, 0.15, 1)];
    for (final (escala, corrido, cual) in capas) {
      blob(
        canvas,
        at + hacia * (corrido * r),
        r * escala,
        s,
        tone.at(cual),
        aplanar: arriba ? 0.66 : 0.78,
      );
    }
  }

  /// De qué lado le da la luz. El sol sale por el este y se pone por el oeste,
  /// así que esto se da la vuelta a lo largo del día.
  static Offset lightFrom(Palette p) =>
      Offset(p.lightDir.x >= 0 ? 0.68 : -0.68, -0.73);
}
