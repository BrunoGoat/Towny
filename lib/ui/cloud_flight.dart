import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/palette.dart';
import 'flight_painters.dart';
import 'flight_styles.dart';

/// El vuelo al valle: subir por encima de las nubes y volver a bajar.
///
/// Ir del pueblo al valle era un salto: la cámara estaba a quince metros de tu
/// plaza y en el fotograma siguiente a doscientos, mirando a otra parte y con
/// otro giro. No importa cuánto se suavice el movimiento — a esa escala el ojo
/// no reconstruye el camino, sólo registra que el mundo cambió. Y el valle
/// dejaba de ser un sitio al que se va para ser una pantalla que se abre.
///
/// Esto es el camino. Se levanta el vuelo, la tierra se pierde de foco, algo
/// tapa la pantalla entera, y cuando se abre estás arriba. Lo caro se hace
/// detrás de las nubes, que es donde se ha hecho siempre en cualquier historia
/// que valga.
///
/// Qué es exactamente ese algo lo dice [style], y hay diez. El widget no sabe
/// dibujar ninguno: reparte el lienzo y pone el desenfoque, que es lo único
/// que comparten.
class CloudFlight extends StatelessWidget {
  const CloudFlight({
    super.key,
    required this.t,
    required this.palette,
    this.style = FlightStyle.cumulos,
    this.seed = 0x5C1E,
  });

  /// Cero al despegar, uno al aterrizar. A la mitad la pantalla está tapada.
  final double t;

  /// La del momento: las nubes de las cuatro de la mañana no son blancas, y el
  /// sol de las siete de la tarde les da por un lado y no por el otro.
  final Palette palette;

  /// Cuál de los diez. El que esté elegido en los ajustes.
  final FlightStyle style;

  final int seed;

  /// Cuánto tapan las nubes ahora mismo: sube hasta uno a la mitad y baja.
  static double coverOf(double t) => FlightPaint.coverOf(t);

  @override
  Widget build(BuildContext context) {
    final cover = FlightPaint.coverOf(t);
    if (cover <= 0.001) return const SizedBox.shrink();
    // El desenfoque no acompaña a las nubes: va por delante. La tierra se
    // pierde de foco antes de que la tape nada, que es lo que hace que el
    // corte se lea como altura y no como una cortina.
    //
    // Y se apaga en cuanto tapa del todo. Desenfocar la pantalla entera es lo
    // más caro que hay aquí, y justo en el tramo en que no se ve nada de lo
    // que hay debajo no cambia un solo píxel: sale gratis y se nota en los
    // fotogramas por segundo del único momento en que hay dos cosas pesadas a
    // la vez.
    final blur = FlightPaint.blurOf(style, t);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (blur > 0.4)
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: const SizedBox.expand(),
            ),
          CustomPaint(
            painter: _FlightPainter(
              t: t,
              palette: palette,
              style: style,
              seed: seed,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlightPainter extends CustomPainter {
  _FlightPainter({
    required this.t,
    required this.palette,
    required this.style,
    required this.seed,
  });

  final double t;
  final Palette palette;
  final FlightStyle style;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) =>
      paintFlight(canvas, size, style, t, palette, seed);

  @override
  bool shouldRepaint(_FlightPainter old) =>
      old.t != t ||
      old.palette != palette ||
      old.style != style ||
      old.seed != seed;
}
