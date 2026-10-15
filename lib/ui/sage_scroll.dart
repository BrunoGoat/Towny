import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Un consejo como rollo: pergamino con sus varas, cerrado a lo que dice.
///
/// Diez maneras de vestirlo, para elegir mirándolas; cuando se elija una, las
/// otras se van.
class SageScroll extends StatelessWidget {
  const SageScroll({super.key, required this.variant, required this.child});

  /// Cuál de las diez, de 0 a 9.
  final int variant;
  final Widget child;

  /// Lo que se deja de margen por dentro en cada una, para que el texto no
  /// pise las varas.
  static EdgeInsets insetOf(int v) => switch (v) {
    0 => const EdgeInsets.fromLTRB(34, 14, 34, 14),
    1 => const EdgeInsets.fromLTRB(26, 20, 40, 20),
    2 => const EdgeInsets.fromLTRB(40, 16, 46, 16),
    3 => const EdgeInsets.fromLTRB(30, 14, 30, 14),
    4 => const EdgeInsets.fromLTRB(36, 18, 36, 18),
    5 => const EdgeInsets.fromLTRB(26, 18, 26, 18),
    6 => const EdgeInsets.fromLTRB(40, 14, 40, 14),
    7 => const EdgeInsets.fromLTRB(26, 16, 64, 16),
    8 => const EdgeInsets.fromLTRB(34, 14, 34, 22),
    _ => const EdgeInsets.fromLTRB(34, 14, 34, 14),
  };

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RolloPainter(variant),
    child: Padding(padding: insetOf(variant), child: child),
  );
}

class _RolloPainter extends CustomPainter {
  _RolloPainter(this.v);
  final int v;

  static const _pergamino = Color(0xFFEBDCB3);
  static const _pergaminoOscuro = Color(0xFFD2B887);
  static const _rojo = Color(0xFF9E2B25);
  static const _oro = Color(0xFFC9A04A);
  static const _madera = Color(0xFF6B4A2B);

  void _sombra(Canvas c, Path p) =>
      c.drawShadow(p, Colors.black.withValues(alpha: 0.5), 5, false);

  /// El papel, más oscuro hacia los bordes de las varas.
  void _papel(
    Canvas c,
    Rect r, {
    Color a = _pergamino,
    Color b = _pergaminoOscuro,
  }) {
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          colors: [b, a, a, b],
          stops: const [0, 0.1, 0.9, 1],
        ).createShader(r),
    );
  }

  /// Una vara vertical, cilíndrica, con sus remates.
  void _vara(
    Canvas c,
    double x,
    double y0,
    double y1,
    double w,
    Color color, {
    Color? remate,
    double sobra = 6,
  }) {
    final r = Rect.fromLTRB(x - w / 2, y0 - sobra, x + w / 2, y1 + sobra);
    c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(w / 2)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(color, Colors.black, 0.35)!,
            Color.lerp(color, Colors.white, 0.25)!,
            color,
            Color.lerp(color, Colors.black, 0.45)!,
          ],
          stops: const [0, 0.35, 0.6, 1],
        ).createShader(r),
    );
    if (remate != null) {
      for (final y in [y0 - sobra, y1 + sobra]) {
        c.drawCircle(Offset(x, y), w * 0.72, Paint()..color = remate);
        c.drawCircle(
          Offset(x - w * 0.2, y - w * 0.2),
          w * 0.22,
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        );
      }
    }
  }

  /// Un sello rojo cuadrado con un trazo dentro.
  void _sello(Canvas c, Offset o, double s) {
    final r = Rect.fromCenter(center: o, width: s, height: s);
    c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(s * 0.12)),
      Paint()..color = _rojo.withValues(alpha: 0.85),
    );
    final p = Paint()
      ..color = _pergamino.withValues(alpha: 0.85)
      ..strokeWidth = s * 0.09
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    c.drawLine(
      o + Offset(-s * 0.25, -s * 0.2),
      o + Offset(s * 0.25, -s * 0.2),
      p,
    );
    c.drawLine(o + Offset(0, -s * 0.28), o + Offset(0, s * 0.28), p);
    c.drawLine(
      o + Offset(-s * 0.22, s * 0.12),
      o + Offset(s * 0.22, s * 0.18),
      p,
    );
  }

  @override
  void paint(Canvas c, Size size) {
    final w = size.width, h = size.height;
    switch (v) {
      // 0 · El clásico: pergamino entre dos varas de madera con remates.
      case 0:
        final r = Rect.fromLTRB(14, 0, w - 14, h);
        _sombra(c, Path()..addRect(r));
        _papel(c, r);
        _vara(c, 14, 0, h, 12, _madera, remate: const Color(0xFF4A3220));
        _vara(c, w - 14, 0, h, 12, _madera, remate: const Color(0xFF4A3220));
      // 1 · Con cinta roja atada a la derecha y su lazo.
      case 1:
        final r = Rect.fromLTRB(6, 4, w - 18, h - 4);
        _sombra(c, Path()..addRect(r));
        _papel(c, r);
        _vara(c, w - 18, 4, h - 4, 16, _pergaminoOscuro);
        final cinta = Paint()..color = _rojo;
        c.drawRect(Rect.fromLTRB(w - 28, h * 0.42, w - 8, h * 0.58), cinta);
        final lazo = Path()
          ..moveTo(w - 18, h * 0.5)
          ..lineTo(w - 4, h * 0.5 + 18)
          ..lineTo(w - 12, h * 0.5 + 20)
          ..close()
          ..moveTo(w - 18, h * 0.5)
          ..lineTo(w - 26, h * 0.5 + 20)
          ..lineTo(w - 32, h * 0.5 + 16)
          ..close();
        c.drawPath(lazo, cinta);
      // 2 · El del dragón: varas de oro con puntas rojas y sello rojo.
      case 2:
        final r = Rect.fromLTRB(16, 0, w - 16, h);
        _sombra(c, Path()..addRect(r));
        _papel(c, r);
        final borde = Paint()
          ..color = _rojo.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        c.drawRect(r.deflate(7), borde);
        c.drawRect(r.deflate(10), borde..strokeWidth = 0.6);
        _vara(c, 16, 0, h, 13, _oro, remate: _rojo, sobra: 5);
        _vara(c, w - 16, 0, h, 13, _oro, remate: _rojo, sobra: 5);
        _sello(c, Offset(w - 38, h - 18), 15);
      // 3 · De bambú: tablillas finas atadas.
      case 3:
        final r = Rect.fromLTRB(6, 0, w - 6, h);
        _sombra(c, Path()..addRect(r));
        c.drawRect(r, Paint()..color = const Color(0xFFD8C08A));
        final linea = Paint()
          ..color = const Color(0xFF9C8250).withValues(alpha: 0.45)
          ..strokeWidth = 1;
        for (var x = r.left + 9.0; x < r.right; x += 9) {
          c.drawLine(Offset(x, 0), Offset(x, h), linea);
        }
        final cuerda = Paint()
          ..color = const Color(0xFF6B5236)
          ..strokeWidth = 2;
        c.drawLine(Offset(r.left, 5), Offset(r.right, 5), cuerda);
        c.drawLine(Offset(r.left, h - 5), Offset(r.right, h - 5), cuerda);
        // El texto va sobre una franja más clara para que se lea.
        c.drawRect(
          Rect.fromLTRB(r.left + 14, 10, r.right - 14, h - 10),
          Paint()..color = const Color(0xFFEFE2BE).withValues(alpha: 0.8),
        );
      // 4 · De seda: un marco rojo de seda alrededor del papel, varas de oro.
      case 4:
        final r = Rect.fromLTRB(16, 0, w - 16, h);
        _sombra(c, Path()..addRect(r));
        c.drawRect(r, Paint()..color = const Color(0xFF7E2320));
        c.drawRect(
          r.deflate(6),
          Paint()
            ..color = _oro.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        _papel(
          c,
          r.deflate(9),
          a: const Color(0xFFF1E6C8),
          b: const Color(0xFFE2D1A6),
        );
        _vara(c, 16, 0, h, 11, _oro, remate: const Color(0xFF3D2A12));
        _vara(c, w - 16, 0, h, 11, _oro, remate: const Color(0xFF3D2A12));
      // 5 · Viejo de verdad: bordes comidos y quemados.
      case 5:
        final rnd = math.Random(v * 31 + w.round());
        final p = Path()..moveTo(4, 4);
        for (var x = 4.0; x < w - 4; x += 8) {
          p.lineTo(x, 2 + rnd.nextDouble() * 5);
        }
        for (var y = 4.0; y < h - 4; y += 8) {
          p.lineTo(w - 2 - rnd.nextDouble() * 5, y);
        }
        for (var x = w - 4; x > 4; x -= 8) {
          p.lineTo(x, h - 2 - rnd.nextDouble() * 5);
        }
        for (var y = h - 4; y > 4; y -= 8) {
          p.lineTo(2 + rnd.nextDouble() * 5, y);
        }
        p.close();
        _sombra(c, p);
        c.drawPath(p, Paint()..color = const Color(0xFFEBDAB0));
        // Lo quemado: una orilla parda y desvanecida, sólo en el borde.
        c.save();
        c.clipPath(p);
        c.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..color = const Color(0xFF8E6A3A).withValues(alpha: 0.75)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        c.restore();
      // 6 · A medio abrir: los dos rollos todavía enrollados a los lados.
      case 6:
        final r = Rect.fromLTRB(22, 4, w - 22, h - 4);
        _sombra(c, Path()..addRect(r));
        _papel(c, r);
        for (final x in [8.0, w - 30]) {
          final rr = Rect.fromLTWH(x, 0, 22, h);
          c.drawRRect(
            RRect.fromRectAndRadius(rr, const Radius.circular(11)),
            Paint()
              ..shader = const LinearGradient(
                colors: [
                  Color(0xFFB89A62),
                  Color(0xFFF1E3BE),
                  Color(0xFFC9AE77),
                  Color(0xFF9C7E4A),
                ],
                stops: [0, 0.35, 0.65, 1],
              ).createShader(rr),
          );
          c.drawOval(
            Rect.fromLTWH(x + 3, 1, 16, 7),
            Paint()..color = const Color(0xFF8E7040),
          );
        }
      // 7 · Cerrado con lacre: una faja que lo envuelve y su sello de cera.
      case 7:
        final r = Rect.fromLTRB(4, 0, w - 4, h);
        final rr = RRect.fromRectAndRadius(r, Radius.circular(h / 2));
        _sombra(c, Path()..addRRect(rr));
        c.drawRRect(
          rr,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFC9AE77),
                Color(0xFFF1E3BE),
                Color(0xFFE2CC98),
                Color(0xFFA98C58),
              ],
              stops: [0, 0.3, 0.7, 1],
            ).createShader(r),
        );
        final lacre = Offset(w - 34, h / 2);
        c.drawCircle(lacre, 17, Paint()..color = const Color(0xFF8A1F1B));
        c.drawCircle(lacre, 12, Paint()..color = const Color(0xFFA8302A));
        _sello(c, lacre, 12);
      // 8 · De tinta: varas negras, papel crema y una pincelada debajo.
      case 8:
        final r = Rect.fromLTRB(14, 0, w - 14, h);
        _sombra(c, Path()..addRect(r));
        _papel(c, r, a: const Color(0xFFF4ECD6), b: const Color(0xFFE6D9B6));
        _vara(
          c,
          14,
          0,
          h,
          11,
          const Color(0xFF2A2420),
          remate: const Color(0xFF14110F),
        );
        _vara(
          c,
          w - 14,
          0,
          h,
          11,
          const Color(0xFF2A2420),
          remate: const Color(0xFF14110F),
        );
        final pincel = Path()
          ..moveTo(34, h - 12)
          ..quadraticBezierTo(w * 0.5, h - 18, w - 40, h - 11)
          ..quadraticBezierTo(w * 0.5, h - 14, 34, h - 9)
          ..close();
        c.drawPath(
          pincel,
          Paint()..color = const Color(0xFF2A2420).withValues(alpha: 0.75),
        );
      // 9 · De jade: remates verdes y borlas colgando.
      default:
        final r = Rect.fromLTRB(14, 0, w - 14, h);
        _sombra(c, Path()..addRect(r));
        _papel(c, r);
        const jade = Color(0xFF4F8F6E);
        _vara(c, 14, 0, h, 12, const Color(0xFF7A5A36), remate: jade);
        _vara(c, w - 14, 0, h, 12, const Color(0xFF7A5A36), remate: jade);
        final borla = Paint()
          ..color = jade
          ..strokeWidth = 1.6;
        for (final x in [14.0, w - 14]) {
          c.drawLine(Offset(x, h + 6), Offset(x, h + 14), borla);
          for (var k = -2; k <= 2; k++) {
            c.drawLine(Offset(x, h + 14), Offset(x + k * 1.6, h + 24), borla);
          }
        }
    }
  }

  @override
  bool shouldRepaint(_RolloPainter old) => old.v != v;
}
