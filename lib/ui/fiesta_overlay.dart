import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/rng.dart';
import '../engine/sigils.dart';
import '../fx/fiesta.dart';
import '../l10n/lang.dart';

/// Lo que la fiesta del valle completo pinta **pegado a la pantalla**. Lo que
/// está en un sitio del valle lo pinta `fiesta_painter.dart`.
///
/// Son dos capas: [back] va justo encima del pueblo y debajo de los botones
/// (la luz, los pétalos), y la otra encima de todo (las cuentas, el sello, los
/// banderines, las franjas de cine).
class FiestaOverlay extends StatefulWidget {
  const FiestaOverlay({super.key, required this.back});

  final bool back;

  @override
  State<FiestaOverlay> createState() => _FiestaOverlayState();
}

class _FiestaOverlayState extends State<FiestaOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (Fiesta.instance.show == null) _ticker.stop();
      if (mounted) setState(() {});
    });
    Fiesta.instance.addListener(_changed);
    if (Fiesta.instance.show != null) _ticker.start();
  }

  void _changed() {
    if (Fiesta.instance.show != null && !_ticker.isActive) _ticker.start();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Fiesta.instance.removeListener(_changed);
    _ticker.dispose();
    super.dispose();
  }

  static const _back = {FiestaKind.luz, FiestaKind.petalos};
  static const _front = {
    FiestaKind.cuentas,
    FiestaKind.sello,
    FiestaKind.banderines,
    FiestaKind.mayor,
  };

  @override
  Widget build(BuildContext context) {
    final s = Fiesta.instance.show;
    if (s == null || !(widget.back ? _back : _front).contains(s.kind)) {
      return const SizedBox.shrink();
    }
    final media = MediaQuery.of(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FiestaUi(s, s.t, media.padding),
      ),
    );
  }
}

double _ease(double x) {
  final u = x.clamp(0.0, 1.0);
  return u * u * (3 - 2 * u);
}

double _easeOut(double x) {
  final u = x.clamp(0.0, 1.0);
  return 1 - (1 - u) * (1 - u) * (1 - u);
}

double _window(double t, double a, double b, double c, double d) {
  if (t <= a || t >= d) return 0;
  if (t < b) return _ease((t - a) / (b - a));
  if (t > c) return 1 - _ease((t - c) / (d - c));
  return 1;
}

/// Un resorte que llega a 1 pasándose un poco, como algo que cae colgado.
double _spring(double x) {
  if (x <= 0) return 0;
  if (x >= 2.5) return 1;
  return 1 - math.exp(-5.5 * x) * math.cos(9 * x);
}

String _month(int m) => tr(
  const [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ][m - 1],
  const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m - 1],
);

class _FiestaUi extends CustomPainter {
  _FiestaUi(this.s, this.t, this.pad);

  final FiestaShow s;
  final double t;
  final EdgeInsets pad;

  final Paint _p = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    switch (s.kind) {
      case FiestaKind.cuentas:
        _cuentas(canvas, size);
      case FiestaKind.luz:
        _luz(canvas, size);
      case FiestaKind.sello:
        _sello(canvas, size);
      case FiestaKind.banderines:
        _banderines(canvas, size);
      case FiestaKind.petalos:
        _petalos(canvas, size);
      case FiestaKind.mayor:
        _mayor(canvas, size);
      default:
        break;
    }
  }

  void _text(
    Canvas c,
    String text,
    Offset center,
    TextStyle style, {
    double maxWidth = 400,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  // ------------------------------------------------------------------ cuentas

  void _cuentas(Canvas c, Size size) {
    final n = s.towns.length;
    final gap = 9.0;
    final d = math.min(30.0, (size.width - 60 - gap * (n - 1)) / n);
    final y = size.height - pad.bottom - 246;
    final total = n * d + (n - 1) * gap;
    final x0 = (size.width - total) / 2 + d / 2;
    final join = _ease((t - Fiesta.cuentaJoin) / 0.55);
    final out = 1 - _ease((t - (s.length - 1.1)) / 1.0);
    const crema = Color(0xFFF6EBD3);
    const tinta = Color(0xFF3A2E22);
    const oro = Color(0xFFF2C25B);
    final cx = size.width / 2;

    // Una cinta oscura detrás, para que se lea sobre cualquier pueblo. Se
    // encoge con ellas cuando se juntan.
    final fondo = _window(t, 0, 0.4, s.length - 1.3, s.length - 0.2);
    if (fondo > 0) {
      final ancho = total + 26 + (d * 1.7 + 26 - total - 26) * join;
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, y), width: ancho, height: d + 20),
        Radius.circular((d + 20) / 2),
      );
      _p
        ..color = const Color(0xFF1C1712).withValues(alpha: 0.62 * fondo)
        ..maskFilter = null;
      c.drawRRect(pill, _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = crema.withValues(alpha: 0.18 * fondo);
      c.drawRRect(pill, _p);
      _p.style = PaintingStyle.fill;
    }

    for (var k = 0; k < n; k++) {
      final mine = k == s.active;
      final appear = _easeOut((t - 0.1 - 0.05 * k) / 0.45);
      if (appear <= 0) continue;
      final home = Offset(x0 + k * (d + gap), y);
      final o = Offset.lerp(home, Offset(cx, y), join)!;
      var r = d / 2 * (0.6 + 0.4 * appear);
      // La tuya se llena con un golpecito.
      final fill = mine ? _easeOut((t - Fiesta.cuentaFill) / 0.22) : 1.0;
      final pop = mine
          ? 1 +
                0.28 *
                    math.exp(-math.max(0, t - Fiesta.cuentaFill) * 7) *
                    (t >= Fiesta.cuentaFill ? 1 : 0)
          : 1.0;
      r *= pop;
      final alpha = appear * out * (1 - join * 0.999);
      if (alpha <= 0.003) continue;
      _p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF000000).withValues(alpha: 0.28 * alpha);
      c.drawCircle(o.translate(0, 1.5), r, _p);
      _p.color = const Color(0xFF2A241D).withValues(alpha: 0.55 * alpha);
      c.drawCircle(o, r, _p);
      if (fill > 0) {
        _p.color = crema.withValues(alpha: alpha);
        c.drawCircle(o, r * fill, _p);
      }
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = crema.withValues(alpha: 0.9 * alpha);
      c.drawCircle(o, r, _p);
      _p.style = PaintingStyle.fill;
      // La marca del pueblo: oscura sobre la cuenta llena, clara si no.
      final m = Rect.fromCenter(center: o, width: r * 1.1, height: r * 1.1);
      HabitSigils.draw(
        c,
        m,
        s.towns[k].symbol,
        Color.lerp(crema, tinta, fill)!.withValues(alpha: alpha),
      );
      // Un brillo que recorre la fila una vez, después de llenarse.
      final brillo = _window(t - 1.65 - 0.06 * k, 0, 0.12, 0.12, 0.5);
      if (brillo > 0) {
        _p.color = const Color(
          0xFFFFFFFF,
        ).withValues(alpha: 0.45 * brillo * alpha);
        c.drawCircle(o, r, _p);
      }
      if (mine && t >= Fiesta.cuentaFill) {
        final a = t - Fiesta.cuentaFill;
        if (a < 0.8) {
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = oro.withValues(alpha: (1 - a / 0.8) * alpha);
          c.drawCircle(o, r * (1 + a * 1.4), _p);
          _p.style = PaintingStyle.fill;
        }
      }
    }

    // La cuenta grande, cuando se juntan.
    if (join > 0) {
      final a = t - Fiesta.cuentaJoin - 0.4;
      final big = d * 0.85 * (a < 0 ? join : 1 + 0.12 * math.exp(-a * 6));
      final alpha = join * out;
      final o = Offset(cx, y - 14 * _ease((t - (s.length - 1.1)) / 1.0));
      _p.color = const Color(0xFFFFFFFF);
      _p.shader = ui.Gradient.radial(o, big * 2.6, [
        oro.withValues(alpha: 0.45 * alpha),
        oro.withValues(alpha: 0),
      ]);
      c.drawCircle(o, big * 2.6, _p);
      _p.color = const Color(0xFFFFFFFF);
      _p.shader = ui.Gradient.radial(
        o.translate(-big * 0.3, -big * 0.35),
        big * 1.4,
        [
          const Color(0xFFFFF3C9).withValues(alpha: alpha),
          oro.withValues(alpha: alpha),
          const Color(0xFFC9932E).withValues(alpha: alpha),
        ],
        const [0, 0.55, 1],
      );
      c.drawCircle(o, big, _p);
      _p.shader = null;
      _text(
        c,
        '$n',
        o,
        TextStyle(
          fontFamily: 'EBGaramond',
          fontSize: big * 0.95,
          color: tinta.withValues(alpha: 0.85 * alpha),
          height: 1,
        ),
      );
      final cap = _ease((t - Fiesta.cuentaJoin - 0.5) / 0.6) * out;
      _text(
        c,
        tr('TODOS LOS PUEBLOS, HOY', 'EVERY TOWN, TODAY'),
        o.translate(0, big + 20),
        TextStyle(
          color: crema.withValues(alpha: 0.95 * cap),
          fontSize: 10.5,
          letterSpacing: 3.2,
          fontWeight: FontWeight.w500,
          shadows: const [Shadow(color: Color(0x99000000), blurRadius: 6)],
        ),
      );
    }
  }

  // ---------------------------------------------------------------------- luz

  void _luz(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final env = _window(t, 0, 1.6, s.length - 2.2, s.length);
    if (env <= 0) return;
    // Un baño cálido muy suave sobre todo, como cuando el sol sale de detrás
    // de una nube.
    _p
      ..blendMode = BlendMode.softLight
      ..color = const Color(0xFFFFB347).withValues(alpha: 0.32 * env);
    c.drawRect(Offset.zero & size, _p);
    _p.blendMode = BlendMode.screen;
    // El sol, fuera de la pantalla arriba a la derecha.
    final sol = Offset(w * 1.04, -h * 0.06);
    _p
      ..color = const Color(0xFFFFFFFF)
      ..shader = ui.Gradient.radial(
        sol,
        h * 0.62,
        [
          const Color(0xFFFFE6A8).withValues(alpha: 0.62 * env),
          const Color(0xFFFFC46B).withValues(alpha: 0.16 * env),
          const Color(0x00FFC46B),
        ],
        const [0, 0.35, 1],
      );
    c.drawRect(Offset.zero & size, _p);
    // Los rayos: cuñas de luz que salen del sol y cruzan la pantalla en
    // diagonal, cada una a su ritmo, girando apenas.
    const rayos = 8;
    for (var i = 0; i < rayos; i++) {
      final base =
          math.pi * (0.56 + 0.34 * i / (rayos - 1)) + hashJitter(0.04, i, 9);
      final phi = base + 0.035 * math.sin(t * 0.35 + i);
      final half = 0.018 + 0.03 * hash01(i, 10);
      final lum =
          (0.5 + 0.5 * math.sin(t * (0.7 + 0.4 * hash01(i, 11)) + i * 1.9)) *
          _window(t - 0.12 * i, 0.2, 1.6, s.length - 2.4, s.length - 0.6);
      if (lum <= 0.01) continue;
      final largo = h * 1.5;
      final a1 =
          sol + Offset(math.cos(phi - half), math.sin(phi - half)) * largo;
      final a2 =
          sol + Offset(math.cos(phi + half), math.sin(phi + half)) * largo;
      final fin = sol + Offset(math.cos(phi), math.sin(phi)) * largo;
      final cuna = Path()
        ..moveTo(sol.dx, sol.dy)
        ..lineTo(a1.dx, a1.dy)
        ..lineTo(a2.dx, a2.dy)
        ..close();
      _p
        ..color = const Color(0xFFFFFFFF)
        ..shader = ui.Gradient.linear(
          sol,
          fin,
          [
            const Color(0xFFFFEBC2).withValues(alpha: 0.42 * lum),
            const Color(0xFFFFEBC2).withValues(alpha: 0.16 * lum),
            const Color(0x00FFEBC2),
          ],
          const [0, 0.55, 1],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      c.drawPath(cuna, _p);
    }
    _p
      ..shader = null
      ..maskFilter = null
      ..blendMode = BlendMode.srcOver;
    // Polvo en la luz: motas que suben despacio, como en un granero.
    for (var i = 0; i < 46; i++) {
      final x = hash01(i, 1) * w + math.sin(t * 0.7 + i) * 10;
      final y = h * (0.1 + 0.75 * hash01(i, 2)) - t * (8 + 10 * hash01(i, 3));
      final tw = 0.5 + 0.5 * math.sin(t * (1.2 + hash01(i, 4) * 1.6) + i * 2);
      _p.color = const Color(0xFFFFF0C8).withValues(alpha: 0.6 * env * tw);
      c.drawCircle(Offset(x, y), 0.8 + 1.4 * hash01(i, 5), _p);
    }
  }

  // -------------------------------------------------------------------- sello

  void _sello(Canvas c, Size size) {
    final n = s.towns.length;
    final land = Fiesta.selloLands;
    final env = _window(t, 0, 0.25, s.length - 1.5, s.length);
    if (env <= 0) return;
    // La pantalla se apaga, más por los bordes, para que el sello sea lo
    // único.
    _p
      ..color = const Color(0xFFFFFFFF)
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height * 0.43),
        size.height * 0.7,
        [
          const Color(0xFF000000).withValues(alpha: 0.28 * env),
          const Color(0xFF000000).withValues(alpha: 0.62 * env),
        ],
      );
    c.drawRect(Offset.zero & size, _p);
    _p.shader = null;

    final r0 = math.min(size.width * 0.31, 128.0);
    final fall = (t / land).clamp(0.0, 1.0);
    var scale = t < land ? 2.3 - 1.3 * fall * fall : 1.0;
    if (t >= land) {
      final a = t - land;
      scale = 1 - 0.06 * math.exp(-a * 9) * math.cos(a * 30);
    }
    final leaving = _ease((t - (s.length - 1.5)) / 1.5);
    scale *= 1 - 0.08 * leaving;
    final o = Offset(size.width / 2, size.height * 0.43 + 12 * leaving);
    final alpha = (t / 0.18).clamp(0.0, 1.0) * (1 - leaving);
    final r = r0 * scale;

    // La sombra que se acerca mientras cae.
    _p
      ..color = const Color(
        0xFF000000,
      ).withValues(alpha: 0.45 * alpha * (t < land ? fall : 1))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 20 * (scale - 1));
    c.drawCircle(o.translate(4 * scale, 8 * scale), r * 1.02, _p);
    _p.maskFilter = null;

    // El lacre: un borde irregular, como aplastado a mano.
    final blob = Path();
    const pts = 64;
    for (var k = 0; k <= pts; k++) {
      final a = k / pts * math.pi * 2;
      final bump =
          1 +
          0.035 * math.sin(a * 7 + 1.3) +
          0.025 * math.sin(a * 13 + 0.4) +
          0.02 * math.sin(a * 3 + 2.0);
      final q = o + Offset(math.cos(a), math.sin(a)) * r * bump;
      if (k == 0) {
        blob.moveTo(q.dx, q.dy);
      } else {
        blob.lineTo(q.dx, q.dy);
      }
    }
    blob.close();
    _p.color = const Color(0xFFFFFFFF);
    _p.shader = ui.Gradient.radial(
      o.translate(-r * 0.35, -r * 0.4),
      r * 1.6,
      [
        const Color(0xFFC7362E).withValues(alpha: alpha),
        const Color(0xFF9E1B1B).withValues(alpha: alpha),
        const Color(0xFF5E0B0F).withValues(alpha: alpha),
      ],
      const [0, 0.45, 1],
    );
    c.drawPath(blob, _p);
    _p.shader = null;

    // El disco de dentro, hundido: sombra arriba, luz abajo.
    final ri = r * 0.80;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFF3E0608).withValues(alpha: 0.7 * alpha);
    c.drawCircle(o.translate(0, -1), ri, _p);
    _p.color = const Color(0xFFE8857A).withValues(alpha: 0.5 * alpha);
    c.drawCircle(o.translate(0, 1.2), ri, _p);
    _p.strokeWidth = 1;
    _p.color = const Color(0xFF3E0608).withValues(alpha: 0.5 * alpha);
    c.drawCircle(o, ri * 0.66, _p);
    _p.style = PaintingStyle.fill;

    // Las marcas de los pueblos, en relieve, alrededor.
    final markR = ri * 0.83;
    final markS = math.min(
      r * 0.17,
      (2 * math.pi * markR / math.max(n, 1)) * 0.62,
    );
    for (var k = 0; k < n; k++) {
      final a = -math.pi / 2 + k / n * math.pi * 2;
      final q = o + Offset(math.cos(a), math.sin(a)) * markR;
      final box = Rect.fromCenter(center: q, width: markS, height: markS);
      HabitSigils.draw(
        c,
        box.shift(const Offset(0, 1.3)),
        s.towns[k].symbol,
        const Color(0xFFF29C90).withValues(alpha: 0.85 * alpha),
      );
      HabitSigils.draw(
        c,
        box.shift(const Offset(0, -1.0)),
        s.towns[k].symbol,
        const Color(0xFF3A0507).withValues(alpha: alpha),
      );
      HabitSigils.draw(
        c,
        box,
        s.towns[k].symbol,
        const Color(0xFF8C1616).withValues(alpha: alpha),
      );
    }

    // Y en el centro, la fecha.
    void relieve(
      String text,
      Offset at,
      double fs, {
      double ls = 0,
      FontWeight? fw,
    }) {
      // Estampado en el lacre: el borde de arriba en sombra, el de abajo
      // con luz, y el fondo de la letra más oscuro que la superficie.
      for (final (dy, col) in [
        (1.3, const Color(0xFFF29C90)),
        (-1.0, const Color(0xFF3A0507)),
        (0.0, const Color(0xFF8C1616)),
      ]) {
        _text(
          c,
          text,
          at.translate(0, dy),
          TextStyle(
            fontFamily: 'EBGaramond',
            fontSize: fs,
            letterSpacing: ls,
            height: 1,
            fontWeight: fw,
            color: col.withValues(alpha: alpha * (dy > 0 ? 0.85 : 1)),
          ),
        );
      }
    }

    final dia = s.day;
    relieve(
      tr('TODO EL VALLE', 'THE WHOLE VALLEY'),
      o.translate(0, -ri * 0.42),
      r * 0.075,
      ls: 2.2,
    );
    relieve('${dia.day}', o.translate(0, ri * 0.02), r * 0.42);
    relieve(
      _month(dia.month).toUpperCase(),
      o.translate(0, ri * 0.42),
      r * 0.075,
      ls: 2.2,
    );

    // El brillo del lacre, arriba a la izquierda.
    _p.color = const Color(0xFFFFFFFF);
    _p.shader = ui.Gradient.radial(o.translate(-r * 0.45, -r * 0.5), r * 0.5, [
      const Color(0xFFFFFFFF).withValues(alpha: 0.22 * alpha),
      const Color(0x00FFFFFF),
    ]);
    c.drawCircle(o.translate(-r * 0.45, -r * 0.5), r * 0.5, _p);
    _p.shader = null;

    // Al caer: un anillo de aire que sale del golpe.
    if (t >= land) {
      final a = t - land;
      if (a < 0.6) {
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - a / 0.6)
          ..color = const Color(
            0xFFFFFFFF,
          ).withValues(alpha: 0.5 * (1 - a / 0.6));
        c.drawCircle(o, r * (1.05 + a * 0.9), _p);
        _p.style = PaintingStyle.fill;
      }
    }
  }

  // --------------------------------------------------------------- banderines

  static const List<Color> _telas = [
    Color(0xFFD9483B),
    Color(0xFFF2C14E),
    Color(0xFF4E9F6B),
    Color(0xFF3D7CC9),
    Color(0xFFF4EFE6),
    Color(0xFFE98A3A),
    Color(0xFF8E5BB5),
  ];

  void _banderines(Canvas c, Size size) {
    final w = size.width;
    final drop = _spring(t / 1.1);
    final up = _ease((t - (s.length - 1.2)) / 1.0);
    final n = s.towns.length;
    for (var row = 0; row < 2; row++) {
      final delay = row * 0.18;
      final d = _spring((t - delay) / 1.1);
      if (d <= 0) continue;
      final top = pad.top + (row == 0 ? 4.0 : 40.0);
      final sag = row == 0 ? 70.0 : 104.0;
      final lift = (1 - d) * -(sag + 80) - up * (sag + 120);
      final sway = math.sin(t * 1.7 + row) * 3;
      Offset cord(double u) {
        final x = -12 + (w + 24) * u;
        final y =
            top + sag * 4 * u * (1 - u) + lift + sway * math.sin(u * math.pi);
        return Offset(x, y);
      }

      // El cordel.
      final path = Path();
      for (var k = 0; k <= 40; k++) {
        final q = cord(k / 40);
        if (k == 0) {
          path.moveTo(q.dx, q.dy);
        } else {
          path.lineTo(q.dx, q.dy);
        }
      }
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0xFF3B2F25).withValues(alpha: 0.85);
      c.drawPath(path, _p);
      _p.style = PaintingStyle.fill;

      final flags = row == 0 ? math.max(n, 8) : 10;
      // Qué banderas de la primera llevan marca: repartidas, una por pueblo.
      final marcas = <int, int>{};
      if (row == 0) {
        for (var k = 0; k < n; k++) {
          marcas[((k + 0.5) * flags / n).floor().clamp(0, flags - 1)] = k;
        }
      }
      for (var k = 0; k < flags; k++) {
        final u = (k + 0.5) / flags;
        final q = cord(u);
        final q2 = cord(u + 0.01);
        final slope = math.atan2(q2.dy - q.dy, q2.dx - q.dx);
        final wave =
            math.sin(t * 3.1 + k * 0.9 + row * 2) * 0.12 * (1 - drop * 0.5);
        final fw = math.min(36.0, (w + 24) / flags * 0.86);
        final fh = fw * 1.25;
        final color = _telas[(k * 3 + row * 2) % _telas.length];
        c.save();
        c.translate(q.dx, q.dy);
        c.rotate(slope + wave);
        final tri = Path()
          ..moveTo(-fw / 2, 0)
          ..lineTo(fw / 2, 0)
          ..lineTo(0, fh)
          ..close();
        _p.color = const Color(0x33000000);
        c.save();
        c.translate(1.2, 2);
        c.drawPath(tri, _p);
        c.restore();
        _p.color = const Color(0xFFFFFFFF);
        _p.shader = ui.Gradient.linear(
          Offset(-fw / 2, 0),
          Offset(fw / 2, 0),
          [
            Color.lerp(color, const Color(0xFFFFFFFF), 0.18)!,
            color,
            Color.lerp(color, const Color(0xFF000000), 0.14)!,
          ],
          const [0, 0.5, 1],
        );
        c.drawPath(tri, _p);
        _p.shader = null;
        final m = marcas[k];
        if (m != null) {
          final claro = color.computeLuminance() > 0.45;
          HabitSigils.draw(
            c,
            Rect.fromCenter(
              center: Offset(0, fh * 0.33),
              width: fw * 0.56,
              height: fw * 0.56,
            ),
            s.towns[m].symbol,
            claro ? const Color(0xE63A2E22) : const Color(0xF2FFFFFF),
          );
        }
        c.restore();
      }
    }
  }

  // ------------------------------------------------------------------ pétalos

  static const List<Color> _petalo = [
    Color(0xFFF59AB5),
    Color(0xFFFBD3DF),
    Color(0xFFF07FA0),
    Color(0xFFFFFFFF),
    Color(0xFFF8B4C9),
  ];

  void _petalos(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final out = 1 - _ease((t - (s.length - 1.4)) / 1.4);
    for (var i = 0; i < 120; i++) {
      // Los primeros ya están en el aire cuando empieza, repartidos por toda
      // la pantalla: una lluvia que empieza arriba de todo tarda tres
      // segundos en llegar a la mitad.
      final born = hash01(i, 1) * (s.length - 1.8) - (i % 3 == 0 ? 2.5 : 0);
      final a = t - born;
      if (a < 0) continue;
      final cerca = i % 13 == 0;
      final fall = (cerca ? 150.0 : 70.0) + 50 * hash01(i, 2);
      final y = -30 + a * fall;
      if (y > h + 30) continue;
      final x =
          hash01(i, 3) * (w + 80) -
          60 +
          a * 22 +
          math.sin(a * (0.9 + hash01(i, 4)) + i) * 28;
      final flip = math.cos(a * (2.2 + 2 * hash01(i, 5)) + i);
      final rot = a * (0.8 + hash01(i, 6)) * (i.isEven ? 1 : -1) + i;
      final sz = (cerca ? 16.0 : 6.0 + 5 * hash01(i, 7));
      final col = _petalo[i % _petalo.length];
      final alpha = out * _ease(math.min(a, t) / 0.5) * (cerca ? 0.8 : 1.0);
      c.save();
      c.translate(x, y);
      c.rotate(rot);
      c.scale(0.3 + 0.7 * flip.abs(), 1);
      final petal = Path()
        ..moveTo(0, -sz)
        ..cubicTo(sz * 0.75, -sz * 0.7, sz * 0.6, sz * 0.6, 0, sz)
        ..cubicTo(-sz * 0.6, sz * 0.6, -sz * 0.75, -sz * 0.7, 0, -sz);
      // Una sombra mínima, para que se despeguen del pueblo.
      _p.color = const Color(0xFF5A2A3A).withValues(alpha: 0.18 * alpha);
      c.save();
      c.translate(1, 1.5);
      c.drawPath(petal, _p);
      c.restore();
      _p
        ..color = const Color(0xFFFFFFFF)
        ..shader = ui.Gradient.linear(Offset(0, -sz), Offset(0, sz), [
          Color.lerp(
            col,
            const Color(0xFFFFFFFF),
            0.35,
          )!.withValues(alpha: alpha),
          col.withValues(alpha: alpha),
        ])
        ..maskFilter = cerca
            ? const MaskFilter.blur(BlurStyle.normal, 2.2)
            : null;
      c.drawPath(petal, _p);
      _p
        ..shader = null
        ..maskFilter = null;
      c.restore();
    }
  }

  // -------------------------------------------------------------------- mayor

  void _mayor(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final topH = math.max(h * 0.12, pad.top + 92);
    final botH = math.max(h * 0.25, pad.bottom + 200);
    final inn = _easeOut(t / 1.0);
    final outB = _ease((t - (s.length - 1.1)) / 1.0);
    final k = inn * (1 - outB);
    _p.color = const Color(0xFF050505);
    c.drawRect(Rect.fromLTWH(0, 0, w, topH * k), _p);
    c.drawRect(Rect.fromLTWH(0, h - botH * k, w, botH * k), _p);

    // El título, en la franja de abajo, como los créditos de una película.
    final at = Fiesta.mayorTitle;
    final a1 = _window(t, at, at + 0.9, s.length - 1.8, s.length - 1.0);
    final a2 = _window(t, at + 0.5, at + 1.4, s.length - 1.8, s.length - 1.0);
    final a3 = _window(t, at + 1.0, at + 1.9, s.length - 1.8, s.length - 1.0);
    final cy = h - botH * k + botH * 0.40;
    const oro = Color(0xFFE9C46A);
    _text(
      c,
      tr('F I E S T A   M A Y O R', 'T H E   G R A N D   F A I R'),
      Offset(w / 2, cy - 34),
      TextStyle(
        fontFamily: 'EBGaramond',
        fontSize: 12,
        letterSpacing: 1.5 + 2 * (1 - a1),
        color: oro.withValues(alpha: a1),
      ),
    );
    _text(
      c,
      tr('Todo el valle', 'The whole valley'),
      Offset(w / 2, cy + 2 + 6 * (1 - a2)),
      TextStyle(
        fontFamily: 'EBGaramond',
        fontSize: 36,
        height: 1,
        color: const Color(0xFFF7F1E3).withValues(alpha: a2),
      ),
    );
    // La raya con el rombo, que se abre desde el medio.
    final half = 58 * _easeOut((t - at - 0.9) / 0.9);
    if (half > 0) {
      final y = cy + 36;
      _p
        ..color = oro.withValues(alpha: 0.8 * a3)
        ..strokeWidth = 1;
      c.drawLine(Offset(w / 2 - half, y), Offset(w / 2 - 6, y), _p);
      c.drawLine(Offset(w / 2 + 6, y), Offset(w / 2 + half, y), _p);
      c.save();
      c.translate(w / 2, y);
      c.rotate(math.pi / 4);
      c.drawRect(const Rect.fromLTWH(-2.2, -2.2, 4.4, 4.4), _p);
      c.restore();
    }
    final d = s.day;
    _text(
      c,
      tr(
        '${d.day} de ${_month(d.month)} de ${d.year}',
        '${_month(d.month)} ${d.day}, ${d.year}',
      ),
      Offset(w / 2, cy + 58),
      TextStyle(
        fontFamily: 'EBGaramond',
        fontSize: 13.5,
        letterSpacing: 0.6,
        fontStyle: FontStyle.italic,
        color: const Color(0xFFCFC6B4).withValues(alpha: a3),
      ),
    );
    _text(
      c,
      tr(
        '${s.towns.length} pueblos · una pieza cada uno',
        '${s.towns.length} towns · one piece each',
      ),
      Offset(w / 2, topH * k - 22),
      TextStyle(
        fontSize: 10,
        letterSpacing: 2.4,
        color: const Color(0xFF9A927F).withValues(alpha: a3),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _FiestaUi old) => true;
}
