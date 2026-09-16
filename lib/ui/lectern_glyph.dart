import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// El atril de la plaza, dibujado como icono.
///
/// Un libro suelto habría sido más fácil de reconocer y habría estado mal: lo
/// que hay al otro lado del botón no es «un libro», es el mueble que está en
/// la plaza, y el botón tiene que parecerse a dónde lleva. Así que es lo mismo
/// que el modelo —las dos hojas abiertas en ángulo, el pie de una sola pata y
/// la peana— reducido a lo que se distingue a veinte píxeles.
///
/// Y por eso mismo no se parece al del tablón, que es vertical y con papeles
/// clavados: son dos cosas distintas y están en dos sitios distintos de la
/// plaza. Uno es lo que el pueblo dice de vos; el otro es lo que dijiste vos.
class LecternGlyph extends StatelessWidget {
  const LecternGlyph({
    super.key,
    required this.color,
    this.size = 20,
    this.shadows,
  });

  final Color color;
  final double size;

  /// El mismo halo que llevan los iconos de al lado, para que un botón no se
  /// lea sobre el cielo y el de al lado no.
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _LecternGlyphPainter(color, shadows),
  );
}

class _LecternGlyphPainter extends CustomPainter {
  _LecternGlyphPainter(this.color, this.shadows);

  final Color color;
  final List<Shadow>? shadows;

  @override
  void paint(Canvas canvas, Size size) {
    // Todo se dibuja en una caja de veinte y se escala: así las proporciones
    // no dependen del tamaño al que se pida el icono.
    final k = size.width / 20;
    canvas.save();
    canvas.scale(k);

    const trazo = 1.25;
    final linea = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = trazo
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;

    // Las dos hojas, abiertas en ángulo sobre el lomo. El lomo va más alto que
    // los cantos de fuera: es lo que dice que el libro está apoyado en una
    // tabla inclinada y no tumbado en una mesa.
    final izquierda = Path()
      ..moveTo(10, 5.0)
      ..lineTo(3.2, 6.9)
      ..lineTo(3.2, 12.6)
      ..lineTo(10, 11.2)
      ..close();
    final derecha = Path()
      ..moveTo(10, 5.0)
      ..lineTo(16.8, 6.9)
      ..lineTo(16.8, 12.6)
      ..lineTo(10, 11.2)
      ..close();

    // El pie: una pata y la peana. Cortos a propósito — el atril de la plaza
    // llega por el muslo, y un pie largo lo convertía en un cartel.
    final pie = Path()
      ..moveTo(10, 11.2)
      ..lineTo(10, 16.9)
      ..moveTo(6.8, 17.9)
      ..lineTo(13.2, 17.9);

    final armazon = Path()
      ..addPath(izquierda, Offset.zero)
      ..addPath(derecha, Offset.zero)
      ..addPath(pie, Offset.zero);

    for (final s in shadows ?? const <Shadow>[]) {
      // El desenfoque va en unidades de la caja, y con tope: doce píxeles de
      // halo sobre un icono de veinte lo convierten en una mancha.
      final blur = math.min(s.blurRadius / k, 3.2);
      if (blur <= 0) continue;
      canvas.drawPath(
        armazon.shift(s.offset / k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = trazo
          ..color = s.color
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur),
      );
    }

    canvas.drawPath(izquierda, linea);
    canvas.drawPath(derecha, linea);
    canvas.drawPath(pie, linea);

    // Los renglones escritos, a media tinta: son el detalle que dice de qué es
    // el botón, no la forma por la que se reconoce. A trazo entero competían
    // con el contorno y a veinte píxeles eso es suciedad.
    final tinta = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: color.a * 0.5);
    for (final (y, corto) in [(8.5, false), (10.1, true)]) {
      canvas.drawLine(
        Offset(4.9, y + 0.45),
        Offset(corto ? 6.9 : 8.5, y - 0.02),
        tinta,
      );
      canvas.drawLine(
        Offset(11.5, y - 0.02),
        Offset(corto ? 13.1 : 15.1, y + 0.45),
        tinta,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LecternGlyphPainter old) =>
      old.color != color || old.shadows != shadows;
}
