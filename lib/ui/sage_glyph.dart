import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// El botón del consejero: el viejo mismo, de trazo, como el del tablón es el
/// tablón. Cabeza, la barba que le cae hasta el pecho y el bastón al lado.
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

    // La cabeza, la barba en punta y el bastón.
    final cabeza = RRect.fromLTRBR(
      5.2,
      2.6,
      12.6,
      9.4,
      const Radius.circular(1.4),
    );
    final barba = Path()
      ..moveTo(5.6, 8.2)
      ..lineTo(12.2, 8.2)
      ..lineTo(10.4, 13.6)
      ..lineTo(8.9, 17.4)
      ..lineTo(7.4, 13.6)
      ..close();
    final baston = Path()
      ..moveTo(15.6, 5.0)
      ..quadraticBezierTo(15.6, 3.4, 17.0, 3.6)
      ..moveTo(15.6, 5.0)
      ..lineTo(15.2, 18.2);
    final todo = Path()
      ..addRRect(cabeza)
      ..addPath(barba, Offset.zero)
      ..addPath(baston, Offset.zero);

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
    canvas.drawRRect(cabeza, linea);
    // La barba, maciza a media tinta: es lo que dice que es un viejo.
    canvas.drawPath(
      barba,
      Paint()..color = color.withValues(alpha: color.a * 0.55),
    );
    canvas.drawPath(barba, linea);
    canvas.drawPath(baston, linea);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SageGlyphPainter old) =>
      old.color != color || old.shadows != shadows;
}
