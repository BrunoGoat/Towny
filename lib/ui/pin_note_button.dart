import 'package:flutter/material.dart';

import '../l10n/lang.dart';

/// El botón de clavar una nota en el tablón: una hoja en blanco abajo a la
/// derecha, con la punta doblada y una cruz hecha a mano.
///
/// Papel y no una pastilla redonda de vidrio, que era lo que no pegaba con el
/// resto del tablón; y sin palabras, que la cruz se entiende en cualquier
/// idioma.
class PinNoteButton extends StatefulWidget {
  const PinNoteButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<PinNoteButton> createState() => _PinNoteButtonState();
}

const _tinta = Color(0xFF3B2F22);
const _papel = Color(0xFFF4ECD6);
const _papelOscuro = Color(0xFFE6DABB);

class _PinNoteButtonState extends State<PinNoteButton> {
  bool _apretado = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _apretado = true),
    onTapCancel: () => setState(() => _apretado = false),
    onTapUp: (_) {
      setState(() => _apretado = false);
      widget.onTap();
    },
    child: AnimatedScale(
      scale: _apretado ? 0.94 : 1,
      duration: const Duration(milliseconds: 90),
      child: Semantics(
        button: true,
        label: tr('Clavar una nota', 'Pin a note'),
        child: SizedBox(
          width: 58,
          height: 58,
          child: CustomPaint(
            painter: _EsquinaPainter(),
            child: CustomPaint(painter: _MasPainter()),
          ),
        ),
      ),
    ),
  );
}

class _EsquinaPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    // Una hoja entera y cuadrada, con la punta de arriba a la izquierda
    // doblada hacia dentro, un poco torcida como clavada a mano.
    const pliegue = 16.0;
    c.save();
    c.translate(s.width / 2, s.height / 2);
    c.rotate(0.04);
    c.translate(-s.width / 2, -s.height / 2);
    final hoja = Path()
      ..moveTo(pliegue, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..lineTo(0, pliegue)
      ..close();
    c.drawShadow(hoja, Colors.black, 6, false);
    c.drawPath(
      hoja,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_papel, _papelOscuro],
        ).createShader(Offset.zero & s),
    );
    final dobla = Path()
      ..moveTo(pliegue, 0)
      ..lineTo(0, pliegue)
      ..lineTo(pliegue * 0.92, pliegue * 0.92)
      ..close();
    c.drawPath(dobla, Paint()..color = const Color(0xFFD3C39E));
    c.restore();
  }

  @override
  bool shouldRepaint(_EsquinaPainter old) => false;
}

class _MasPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    // Una cruz hecha a mano: dos trazos un poco torcidos.
    final p = Paint()
      ..color = _tinta
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final m = s.center(Offset.zero);
    c.drawPath(
      Path()
        ..moveTo(m.dx - 1, m.dy - 13)
        ..quadraticBezierTo(m.dx + 2, m.dy, m.dx + 1, m.dy + 13),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(m.dx - 13, m.dy + 1)
        ..quadraticBezierTo(m.dx, m.dy - 2, m.dx + 13, m.dy),
      p,
    );
  }

  @override
  bool shouldRepaint(_MasPainter old) => false;
}
