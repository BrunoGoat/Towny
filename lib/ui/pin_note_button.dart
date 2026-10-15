import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/lang.dart';

/// El botón de clavar una nota en el tablón, en diez maneras para elegir
/// mirándolas. Todas de la misma familia que el tablón —papel, madera,
/// chinchetas y letra a mano— y ninguna una pastilla redonda de vidrio, que
/// era lo que no pegaba con el resto. Cuando se elija una, las otras se van.
///
/// Cada una dice también dónde va: abajo en el medio, en una esquina, colgando
/// del borde. Ver [PinNoteButton.alignmentOf].
class PinNoteButton extends StatefulWidget {
  const PinNoteButton({super.key, required this.variant, required this.onTap});

  /// Cuál de las diez, de 0 a 9.
  final int variant;
  final VoidCallback onTap;

  /// Cuántas hay.
  static const int count = 10;

  /// Dónde va cada una en la pantalla.
  static Alignment alignmentOf(int v) => switch (v) {
    1 || 2 || 5 || 8 => Alignment.bottomRight,
    3 => Alignment.bottomLeft,
    7 => Alignment.topCenter,
    9 => Alignment.centerRight,
    _ => Alignment.bottomCenter,
  };

  /// Y el margen que deja con el borde.
  static EdgeInsets paddingOf(int v) => switch (v) {
    1 => EdgeInsets.zero,
    7 => EdgeInsets.zero,
    9 => const EdgeInsets.only(bottom: 120),
    3 => const EdgeInsets.fromLTRB(14, 0, 0, 14),
    _ => const EdgeInsets.fromLTRB(16, 0, 16, 14),
  };

  @override
  State<PinNoteButton> createState() => _PinNoteButtonState();
}

const _tinta = Color(0xFF3B2F22);
const _papel = Color(0xFFF4ECD6);
const _papelOscuro = Color(0xFFE6DABB);
const _rojo = Color(0xFFB8432F);

TextStyle _mano(double size, {Color color = _tinta}) => TextStyle(
  fontFamily: 'ArchitectsDaughter',
  fontSize: size,
  height: 1.15,
  color: color,
  fontWeight: FontWeight.w600,
);

List<BoxShadow> _sombra([double k = 1]) => [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.30 * k),
    blurRadius: 10 * k,
    offset: Offset(0, 4 * k),
  ),
];

class _PinNoteButtonState extends State<PinNoteButton>
    with SingleTickerProviderStateMixin {
  /// Para lo que se mueve solo: la nota que cuelga y se mece. Sólo anda
  /// en esa variante: las demás no tienen por qué pedir fotogramas.
  late final AnimationController _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _anda();
  }

  @override
  void didUpdateWidget(PinNoteButton old) {
    super.didUpdateWidget(old);
    _anda();
  }

  void _anda() {
    if (widget.variant == 9) {
      if (!_reloj.isAnimating) _reloj.repeat();
    } else {
      _reloj.stop();
    }
  }

  bool _apretado = false;

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  String get _texto => tr('Clavar una nota', 'Pin a note');

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
        label: _texto,
        child: _variante(widget.variant),
      ),
    ),
  );

  Widget _variante(int v) => switch (v) {
    // 0 · Un papelito clavado con una chincheta, abajo en el medio.
    0 => Transform.rotate(
      angle: -0.035,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          _Hoja(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 11),
            child: Text(_texto, style: _mano(16)),
          ),
          const Positioned(top: -6, child: _Chincheta(size: 16)),
        ],
      ),
    ),
    // 1 · La esquina de una hoja en blanco que asoma por abajo a la
    // derecha, con la punta doblada: tirar de ella es sacar una nota.
    1 => SizedBox(
      width: 112,
      height: 104,
      child: CustomPaint(
        painter: _EsquinaPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 44, 8, 8),
          child: Text(
            tr('Nota\nnueva', 'New\nnote'),
            style: _mano(15),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
    // 2 · Una chincheta grande y nada más, con su nombre a mano debajo.
    2 => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: _papel,
            borderRadius: BorderRadius.circular(6),
            boxShadow: _sombra(),
          ),
          alignment: Alignment.center,
          child: const _Chincheta(size: 30),
        ),
        const SizedBox(height: 6),
        Text(_texto, style: _mano(13, color: Colors.white)),
      ],
    ),
    // 3 · Un taco de hojas en blanco, abiertas en abanico, abajo a la
    // izquierda.
    3 => SizedBox(
      width: 120,
      height: 92,
      child: Stack(
        children: [
          for (final (i, giro) in [(0, -0.16), (1, 0.10), (2, -0.03)])
            Positioned(
              left: 8.0 + i * 4,
              top: 14.0 - i * 3,
              child: Transform.rotate(
                angle: giro,
                child: _Hoja(
                  width: 92,
                  height: 66,
                  child: i == 2
                      ? Center(
                          child: Text(
                            _texto,
                            style: _mano(13),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox(),
                ),
              ),
            ),
          const Positioned(left: 54, top: 6, child: _Chincheta(size: 14)),
        ],
      ),
    ),
    // 4 · Una tabla de madera con dos clavos, como la del tablón, con lo
    // que dice tallado.
    4 => Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8A6542), Color(0xFF6E4E31)],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: _sombra(),
        border: Border.all(color: const Color(0xFF4E361F), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Clavo(),
          const SizedBox(width: 14),
          Text(
            _texto,
            style: _mano(
              16,
              color: const Color(0xFFF1DFC0),
            ).copyWith(letterSpacing: 0.4),
          ),
          const SizedBox(width: 14),
          const _Clavo(),
        ],
      ),
    ),
    // 5 · Un lápiz cruzado sobre una hojita rayada, sin palabras.
    5 => SizedBox(
      width: 76,
      height: 76,
      child: CustomPaint(painter: _LapizPainter()),
    ),
    // 6 · Un anotador de espiral, con su título.
    6 => Container(
      width: 176,
      decoration: BoxDecoration(
        color: _papel,
        borderRadius: BorderRadius.circular(4),
        boxShadow: _sombra(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 14,
            child: CustomPaint(
              size: const Size(176, 14),
              painter: _EspiralPainter(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Text(
              tr('Escribir una nota', 'Write a note'),
              style: _mano(16),
            ),
          ),
        ],
      ),
    ),
    // 7 · Una tira de papel que cuelga del borde de arriba, clavada.
    7 => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Hoja(
          radius: const BorderRadius.vertical(bottom: Radius.circular(3)),
          padding: const EdgeInsets.fromLTRB(18, 48, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_texto, style: _mano(15)),
              const SizedBox(height: 4),
              const _Chincheta(size: 13),
            ],
          ),
        ),
      ],
    ),
    // 8 · Una hoja cuadrada con una cruz grande hecha a mano: añadir.
    8 => Transform.rotate(
      angle: 0.05,
      child: _Hoja(
        width: 64,
        height: 64,
        child: CustomPaint(painter: _MasPainter()),
      ),
    ),
    // 9 · Una nota colgada de un hilo desde el borde derecho, que se mece.
    _ => AnimatedBuilder(
      animation: _reloj,
      builder: (context, child) {
        final giro = math.sin(_reloj.value * 2 * math.pi) * 0.06;
        return SizedBox(
          width: 120,
          height: 128,
          child: CustomPaint(
            painter: _HiloPainter(giro),
            child: Transform.rotate(
              angle: giro,
              alignment: Alignment.topRight,
              child: child,
            ),
          ),
        );
      },
      child: Align(
        alignment: const Alignment(0.1, 0.8),
        child: Transform.rotate(
          angle: -0.06,
          child: _Hoja(
            width: 88,
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
            child: Text(_texto, style: _mano(13), textAlign: TextAlign.center),
          ),
        ),
      ),
    ),
  };
}

/// Un trozo de papel con su sombra y su filete, como las hojas del tablón.
class _Hoja extends StatelessWidget {
  const _Hoja({
    required this.child,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.radius = const BorderRadius.all(Radius.circular(2)),
  });
  final Widget child;
  final double? width, height;
  final EdgeInsets padding;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    padding: padding,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_papel, _papelOscuro],
      ),
      borderRadius: radius,
      boxShadow: _sombra(),
    ),
    child: child,
  );
}

/// Una chincheta roja, vista desde arriba: la cabeza con su brillo.
class _Chincheta extends StatelessWidget {
  const _Chincheta({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        center: Alignment(-0.35, -0.4),
        colors: [Color(0xFFE88A70), _rojo, Color(0xFF7E2618)],
        stops: [0, 0.55, 1],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 3,
          offset: const Offset(1, 2),
        ),
      ],
    ),
  );
}

/// La cabeza de un clavo de hierro.
class _Clavo extends StatelessWidget {
  const _Clavo();

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: Alignment(-0.3, -0.3),
        colors: [Color(0xFFB9B2A6), Color(0xFF4A453E)],
      ),
    ),
  );
}

class _EsquinaPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    // La hoja, que entra por el canto de abajo a la derecha, con la punta de
    // arriba a la izquierda doblada hacia dentro.
    const pliegue = 26.0;
    final hoja = Path()
      ..moveTo(18 + pliegue, 18)
      ..lineTo(s.width + 4, 6)
      ..lineTo(s.width + 4, s.height + 4)
      ..lineTo(8, s.height + 4)
      ..lineTo(18, 18 + pliegue)
      ..close();
    c.drawShadow(hoja, Colors.black, 6, false);
    c.drawPath(
      hoja,
      Paint()
        ..shader = const LinearGradient(
          colors: [_papel, _papelOscuro],
        ).createShader(Offset.zero & s),
    );
    final dobla = Path()
      ..moveTo(18 + pliegue, 18)
      ..lineTo(18, 18 + pliegue)
      ..lineTo(18 + pliegue * 0.92, 18 + pliegue * 0.92)
      ..close();
    c.drawPath(dobla, Paint()..color = const Color(0xFFD3C39E));
  }

  @override
  bool shouldRepaint(_EsquinaPainter old) => false;
}

class _LapizPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    // La hojita, con tres renglones.
    final hoja = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 10, s.width - 18, s.height - 16),
      const Radius.circular(2),
    );
    c.drawShadow(Path()..addRRect(hoja), Colors.black, 5, false);
    c.drawRRect(hoja, Paint()..color = _papel);
    final renglon = Paint()
      ..color = const Color(0xFF8DA6C4).withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    for (var k = 0; k < 3; k++) {
      final y = 26.0 + k * 11;
      c.drawLine(Offset(14, y), Offset(s.width - 22, y), renglon);
    }
    // El lápiz, en diagonal por encima.
    c.save();
    c.translate(s.width * 0.56, s.height * 0.5);
    c.rotate(-0.85);
    const largo = 64.0, ancho = 9.0;
    final cuerpo = Rect.fromLTWH(-largo / 2, -ancho / 2, largo - 14, ancho);
    c.drawRect(cuerpo, Paint()..color = const Color(0xFFE2B33F));
    c.drawRect(
      Rect.fromLTWH(-largo / 2, -ancho / 2, 7, ancho),
      Paint()..color = const Color(0xFFD9867B),
    );
    final punta = Path()
      ..moveTo(largo / 2 - 14, -ancho / 2)
      ..lineTo(largo / 2, 0)
      ..lineTo(largo / 2 - 14, ancho / 2)
      ..close();
    c.drawPath(punta, Paint()..color = const Color(0xFFE9CFA6));
    c.drawCircle(
      const Offset(largo / 2 - 2, 0),
      2,
      Paint()..color = const Color(0xFF3B3B3B),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_LapizPainter old) => false;
}

class _EspiralPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(
      Rect.fromLTWH(0, 6, s.width, s.height - 6),
      Paint()..color = _papelOscuro,
    );
    final anillo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF6E6A63);
    for (var x = 12.0; x < s.width - 8; x += 13) {
      c.drawArc(
        Rect.fromCenter(center: Offset(x, 6), width: 7, height: 12),
        math.pi * 0.9,
        math.pi * 1.4,
        false,
        anillo,
      );
    }
  }

  @override
  bool shouldRepaint(_EspiralPainter old) => false;
}

class _MasPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    // Una cruz hecha a mano: dos trazos un poco torcidos.
    final p = Paint()
      ..color = _tinta
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final m = s.center(Offset.zero);
    c.drawPath(
      Path()
        ..moveTo(m.dx - 1, m.dy - 17)
        ..quadraticBezierTo(m.dx + 2, m.dy, m.dx + 1, m.dy + 17),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(m.dx - 17, m.dy + 1)
        ..quadraticBezierTo(m.dx, m.dy - 2, m.dx + 17, m.dy),
      p,
    );
  }

  @override
  bool shouldRepaint(_MasPainter old) => false;
}

class _HiloPainter extends CustomPainter {
  _HiloPainter(this.giro);
  final double giro;

  @override
  void paint(Canvas c, Size s) {
    // Un hilo desde el borde de la pantalla, por arriba, hasta la nota, que
    // se mece colgada de él.
    final desde = Offset(s.width + 2, 6);
    final hasta = Offset(s.width * 0.58 + giro * 160, s.height * 0.36);
    c.drawLine(
      desde,
      hasta,
      Paint()
        ..color = const Color(0xFFEDE3CC)
        ..strokeWidth = 1.4,
    );
    c.drawCircle(hasta, 3, Paint()..color = _rojo);
  }

  @override
  bool shouldRepaint(_HiloPainter old) => old.giro != giro;
}
