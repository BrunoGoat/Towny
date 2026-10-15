import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// El botón del consejero: el viejo mismo, de trazo, como el del tablón es el
/// tablón. Su cara de frente, con la barba larga.
class SageGlyph extends StatelessWidget {
  const SageGlyph({
    super.key,
    required this.color,
    this.size = 20,
    this.shadows,
  });

  final Color color;
  final double size;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _SageGlyphPainter(color, shadows),
  );
}

class _SageGlyphPainter extends CustomPainter {
  _SageGlyphPainter(this.color, this.shadows);

  final Color color;
  final List<Shadow>? shadows;

  @override
  void paint(Canvas canvas, Size size) {
    // En una caja de veinte, como el del tablón.
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

    // La cara del viejo, de frente: la cabeza calva, las cejas pobladas, los
    // ojos cerrados de quien sonríe, el bigote y la barba larga en punta. Un
    // bastón al lado no se leía a veinte píxeles —era una raya—, y la barba
    // sola tampoco: lo que dice «el abuelo sabio» es la cara entera.
    final cabeza = Path()
      ..moveTo(4.6, 9.6)
      ..cubicTo(4.2, 1.6, 15.8, 1.6, 15.4, 9.6);
    // La barba, ancha y en tres puntas, como cae una barba de verdad.
    final barba = Path()
      ..moveTo(4.6, 9.6)
      ..cubicTo(3.4, 12.8, 4.6, 15.6, 6.4, 17.0)
      ..quadraticBezierTo(7.6, 16.4, 8.2, 17.4)
      ..quadraticBezierTo(9.2, 18.0, 10.0, 19.4)
      ..quadraticBezierTo(10.8, 18.0, 11.8, 17.4)
      ..quadraticBezierTo(12.4, 16.4, 13.6, 17.0)
      ..cubicTo(15.4, 15.6, 16.6, 12.8, 15.4, 9.6);
    // Y los mechones canos que le quedan sobre las orejas.
    final mechones = Path()
      ..moveTo(4.9, 5.4)
      ..quadraticBezierTo(2.6, 6.2, 3.0, 8.8)
      ..moveTo(15.1, 5.4)
      ..quadraticBezierTo(17.4, 6.2, 17.0, 8.8);
    final cejas = Path()
      ..moveTo(5.9, 7.1)
      ..quadraticBezierTo(7.4, 6.2, 8.9, 7.0)
      ..moveTo(11.1, 7.0)
      ..quadraticBezierTo(12.6, 6.2, 14.1, 7.1);
    final ojos = Path()
      ..moveTo(6.5, 8.9)
      ..quadraticBezierTo(7.4, 9.7, 8.3, 8.9)
      ..moveTo(11.7, 8.9)
      ..quadraticBezierTo(12.6, 9.7, 13.5, 8.9);
    final bigote = Path()
      ..moveTo(10.0, 11.2)
      ..cubicTo(8.8, 10.6, 6.8, 11.0, 6.0, 12.6)
      ..moveTo(10.0, 11.2)
      ..cubicTo(11.2, 10.6, 13.2, 11.0, 14.0, 12.6);
    final contorno = Path()
      ..addPath(cabeza, Offset.zero)
      ..addPath(barba, Offset.zero)
      ..addPath(mechones, Offset.zero);
    final todo = Path()
      ..addPath(contorno, Offset.zero)
      ..addPath(cejas, Offset.zero)
      ..addPath(bigote, Offset.zero);

    for (final s in shadows ?? const <Shadow>[]) {
      final blur = math.min(s.blurRadius / k, 3.2);
      if (blur <= 0) continue;
      canvas.drawPath(
        todo.shift(s.offset / k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = trazo
          ..color = s.color
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur),
      );
    }
    // La barba, maciza a media tinta debajo del bigote: es lo que dice que es
    // un viejo.
    final debajo = Path()
      ..moveTo(4.6, 9.6)
      ..lineTo(6.0, 12.6)
      ..cubicTo(6.8, 11.0, 8.8, 10.6, 10.0, 11.2)
      ..cubicTo(11.2, 10.6, 13.2, 11.0, 14.0, 12.6)
      ..lineTo(15.4, 9.6)
      ..cubicTo(16.6, 12.8, 15.4, 15.6, 13.6, 17.0)
      ..quadraticBezierTo(12.4, 16.4, 11.8, 17.4)
      ..quadraticBezierTo(10.8, 18.0, 10.0, 19.4)
      ..quadraticBezierTo(9.2, 18.0, 8.2, 17.4)
      ..quadraticBezierTo(7.6, 16.4, 6.4, 17.0)
      ..cubicTo(4.6, 15.6, 3.4, 12.8, 4.6, 9.6)
      ..close();
    canvas.drawPath(
      debajo,
      Paint()..color = color.withValues(alpha: color.a * 0.7),
    );
    canvas.drawPath(contorno, linea);
    canvas.drawPath(
      cejas,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.drawPath(ojos, linea..strokeWidth = 1.0);
    canvas.drawPath(bigote, linea..strokeWidth = 1.35);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SageGlyphPainter old) =>
      old.color != color || old.shadows != shadows;
}
