import 'package:flutter/material.dart';

/// Un consejo como rollo de bambú: tablillas finas cosidas una al lado de la
/// otra, una cuerda arriba y otra abajo que las atan, y en medio una franja
/// más clara donde va lo escrito.
///
/// Se usa cerrado, en la lista, y abierto, en el detalle: [open] es cuánto
/// está desenrollado, de cero —una tira con sus dos cuerdas juntas— a uno. Lo
/// que se dibuja es siempre del tamaño que ocupa ahora, así que las cuerdas
/// van con los bordes mientras se abre, y lo escrito se va descubriendo desde
/// el medio.
class SageScroll extends StatelessWidget {
  const SageScroll({
    super.key,
    required this.child,
    this.open = 1,
    this.padding = inset,
  });

  final Widget child;
  final double open;
  final EdgeInsets padding;

  /// Lo que se deja de margen por dentro, para que el texto no pise las
  /// cuerdas ni el borde de la franja.
  static const EdgeInsets inset = EdgeInsets.fromLTRB(30, 14, 30, 14);

  /// Lo que mide cerrado, de alto: las dos cuerdas y un poco de bambú.
  static const double closed = 14;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _BambuPainter(),
    child: open >= 1
        ? Padding(padding: padding, child: child)
        : _Abriendo(
            open: open,
            child: Padding(padding: padding, child: child),
          ),
  );
}

/// Lo de dentro, recortado a lo que ya se abrió y crecido desde el medio.
class _Abriendo extends StatelessWidget {
  const _Abriendo({required this.open, required this.child});
  final double open;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SageScroll.closed),
      child: Align(
        heightFactor: open.clamp(0.0, 1.0),
        child: Opacity(opacity: Curves.easeIn.transform(open), child: child),
      ),
    ),
  );
}

class _BambuPainter extends CustomPainter {
  const _BambuPainter();

  @override
  void paint(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final r = Rect.fromLTRB(6, 0, w - 6, h);
    c.drawShadow(
      Path()..addRect(r),
      Colors.black.withValues(alpha: 0.5),
      5,
      false,
    );
    c.drawRect(r, Paint()..color = const Color(0xFFD8C08A));
    // Las tablillas.
    final linea = Paint()
      ..color = const Color(0xFF9C8250).withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var x = r.left + 9.0; x < r.right; x += 9) {
      c.drawLine(Offset(x, 0), Offset(x, h), linea);
    }
    // El texto va sobre una franja más clara para que se lea.
    if (h > 22) {
      c.drawRect(
        Rect.fromLTRB(r.left + 14, 10, r.right - 14, h - 10),
        Paint()..color = const Color(0xFFEFE2BE).withValues(alpha: 0.8),
      );
    }
    // Y las dos cuerdas que las atan.
    final cuerda = Paint()
      ..color = const Color(0xFF6B5236)
      ..strokeWidth = 2;
    c.drawLine(Offset(r.left, 5), Offset(r.right, 5), cuerda);
    c.drawLine(Offset(r.left, h - 5), Offset(r.right, h - 5), cuerda);
  }

  @override
  bool shouldRepaint(_BambuPainter old) => false;
}
