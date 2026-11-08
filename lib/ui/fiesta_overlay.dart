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

  static const _back = {
    FiestaKind.luz,
    FiestaKind.petalos,
    FiestaKind.cronica,
    FiestaKind.mapa,
  };
  static const _front = {
    FiestaKind.cuentas,
    FiestaKind.sello,
    FiestaKind.banderines,
    FiestaKind.mayor,
    FiestaKind.pregon,
    FiestaKind.foto,
    FiestaKind.confeti,
    FiestaKind.ronda,
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
        painter: _FiestaUi(s, s.t, media.padding, Fiesta.instance.photo),
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
  _FiestaUi(this.s, this.t, this.pad, this.photo);

  final FiestaShow s;
  final double t;
  final EdgeInsets pad;
  final ui.Image? photo;

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
      case FiestaKind.pregon:
        _pregon(canvas, size);
      case FiestaKind.cronica:
        _cronica(canvas, size);
      case FiestaKind.mapa:
        _mapa(canvas, size);
      case FiestaKind.foto:
        _foto(canvas, size);
      case FiestaKind.confeti:
        _confeti(canvas, size);
      case FiestaKind.ronda:
        _ronda(canvas, size);
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

  // ------------------------------------------------------------------- pregón

  void _pregon(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final n = s.towns.length;
    final env = _window(t, 0, 0.3, s.length - 0.9, s.length);
    if (env <= 0) return;
    _p.color = const Color(0xFF000000).withValues(alpha: 0.32 * env);
    c.drawRect(Offset.zero & size, _p);
    final ancho = math.min(w * 0.8, 330.0);
    final altoPapel = math.min(h * 0.66, 150.0 + 26.0 * n);
    final x0 = (w - ancho) / 2;
    // Baja enrollado, se desenrolla, y al final se enrolla y se va.
    final baja = _easeOut(t / 0.45);
    final sube = _ease((t - (s.length - 1.0)) / 0.8);
    final y0 = pad.top + 70 - (1 - baja) * 140 - sube * (altoPapel + 220);
    final abre =
        _easeOut((t - 0.45) / 0.9) * (1 - _ease((t - (s.length - 1.6)) / 0.6));
    final alto = altoPapel * abre;
    const papel = Color(0xFFF1E3C2);
    const tinta = Color(0xFF3B2614);
    const rojo = Color(0xFF8A2A1F);
    // El papel, con los bordes tostados.
    final hoja = Rect.fromLTWH(x0, y0, ancho, alto);
    if (alto > 1) {
      _p
        ..color = const Color(0xFF000000).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      c.drawRect(hoja.shift(const Offset(0, 6)), _p);
      _p
        ..maskFilter = null
        ..color = const Color(0xFFFFFFFF)
        ..shader = ui.Gradient.linear(
          hoja.topLeft,
          hoja.topRight,
          [const Color(0xFFD9C08E), papel, papel, const Color(0xFFD9C08E)],
          const [0, 0.12, 0.88, 1],
        );
      c.drawRect(hoja, _p);
      _p.shader = null;
      c.save();
      c.clipRect(hoja);
      var y = y0 + 34;
      void linea(String text, TextStyle st, {double gap = 27}) {
        _text(c, text, Offset(w / 2, y), st, maxWidth: ancho - 30);
        y += gap;
      }

      linea(
        tr('¡OÍD, VECINOS!', 'HEAR YE, NEIGHBOURS!'),
        const TextStyle(
          fontFamily: 'EBGaramond',
          fontSize: 19,
          letterSpacing: 2.4,
          color: rojo,
        ),
        gap: 30,
      );
      final d = s.day;
      linea(
        tr(
          'Que hoy, ${d.day} de ${_month(d.month)},',
          'That today, ${_month(d.month)} ${d.day},',
        ),
        const TextStyle(
          fontFamily: 'EBGaramond',
          fontSize: 15.5,
          fontStyle: FontStyle.italic,
          color: tinta,
        ),
        gap: 32,
      );
      for (var k = 0; k < n; k++) {
        final town = s.towns[k];
        final aparece = _ease((t - 1.0 - 0.18 * k) / 0.4);
        final tp = TextPainter(
          text: TextSpan(
            text: town.name,
            style: TextStyle(
              fontFamily: 'EBGaramond',
              fontSize: 17,
              color: tinta.withValues(alpha: aparece),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: ancho - 80);
        final total = 22 + tp.width;
        final xs = w / 2 - total / 2;
        HabitSigils.draw(
          c,
          Rect.fromCenter(center: Offset(xs + 8, y), width: 15, height: 15),
          town.symbol,
          rojo.withValues(alpha: aparece),
        );
        tp.paint(c, Offset(xs + 22, y - tp.height / 2));
        y += 26;
      }
      y += 6;
      linea(
        tr('todos los pueblos del valle', 'every town in the valley'),
        const TextStyle(
          fontFamily: 'EBGaramond',
          fontSize: 15.5,
          fontStyle: FontStyle.italic,
          color: tinta,
        ),
        gap: 22,
      );
      linea(
        tr('tienen su pieza.', 'has its piece.'),
        const TextStyle(
          fontFamily: 'EBGaramond',
          fontSize: 15.5,
          fontStyle: FontStyle.italic,
          color: tinta,
        ),
      );
      c.restore();
    }
    // Los dos rodillos: el de arriba fijo, el de abajo baja al desenrollar.
    for (final yy in [y0, y0 + alto]) {
      final rod = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w / 2, yy),
          width: ancho + 22,
          height: 14,
        ),
        const Radius.circular(7),
      );
      _p
        ..color = const Color(0xFFFFFFFF)
        ..shader = ui.Gradient.linear(
          rod.outerRect.topCenter,
          rod.outerRect.bottomCenter,
          [
            const Color(0xFFE2C995),
            const Color(0xFFB8955A),
            const Color(0xFF7A5A2C),
          ],
          const [0, 0.5, 1],
        );
      c.drawRRect(rod, _p);
      _p.shader = null;
      for (final sx in [-1, 1]) {
        _p.color = const Color(0xFF5A3A1A);
        c.drawCircle(Offset(w / 2 + sx * (ancho / 2 + 13), yy), 5, _p);
      }
    }
  }

  // ------------------------------------------------------------------ crónica

  void _cronica(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final env = _window(t, 0, 0.6, s.length - 1.2, s.length);
    if (env <= 0) return;
    final cy = h * 0.36;
    // Una franja de papel de lado a lado, que se funde arriba y abajo, para
    // que la tinta se lea sobre cualquier pueblo.
    final banda = Rect.fromLTRB(0, cy - 78, w, cy + 82);
    _p
      ..color = const Color(0xFFFFFFFF)
      ..shader = ui.Gradient.linear(
        banda.topCenter,
        banda.bottomCenter,
        [
          const Color(0x00F6EEDC),
          const Color(0xFFF6EEDC).withValues(alpha: 0.9 * env),
          const Color(0xFFF6EEDC).withValues(alpha: 0.9 * env),
          const Color(0x00F6EEDC),
        ],
        const [0, 0.28, 0.72, 1],
      );
    c.drawRect(banda, _p);
    _p.shader = null;
    const tinta = Color(0xFF2B1D12);
    final d = s.day;
    final lineas = [
      (
        tr('${d.day} de ${_month(d.month)}.', '${_month(d.month)} ${d.day}.'),
        const TextStyle(
          fontFamily: 'EBGaramond',
          fontSize: 17,
          fontStyle: FontStyle.italic,
          color: tinta,
        ),
        0.45,
      ),
      (
        tr('Hoy, todo el valle.', 'Today, the whole valley.'),
        const TextStyle(
          fontFamily: 'EBGaramond',
          fontSize: 30,
          fontStyle: FontStyle.italic,
          color: tinta,
        ),
        1.15,
      ),
    ];
    var y = cy - 40;
    for (final (texto, estilo, desde) in lineas) {
      final tp = TextPainter(
        text: TextSpan(
          text: texto,
          style: estilo.copyWith(color: tinta.withValues(alpha: env)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (w - tp.width) / 2;
      // Se escribe de izquierda a derecha, al paso de una pluma.
      final u = ((t - desde) / (0.08 * texto.length)).clamp(0.0, 1.0);
      if (u > 0) {
        c.save();
        c.clipRect(
          Rect.fromLTWH(x - 4, y - 4, (tp.width + 8) * u, tp.height + 8),
        );
        tp.paint(c, Offset(x, y));
        c.restore();
        if (u < 1) {
          // La punta de la pluma, con su gota.
          final punta = Offset(x + tp.width * u, y + tp.height * 0.72);
          _p.color = tinta.withValues(alpha: 0.85 * env);
          c.drawCircle(punta, 1.8, _p);
        }
      }
      y += tp.height + 6;
    }
    // Y el rasgo de debajo, como quien firma.
    final r = _easeOut((t - 2.9) / 0.7);
    if (r > 0) {
      final path = Path()..moveTo(w / 2 - 70, y + 8);
      path.cubicTo(
        w / 2 - 20,
        y + 2,
        w / 2 + 10,
        y + 16,
        w / 2 + 70 * (2 * r - 1),
        y + 6 + 4 * r,
      );
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = tinta.withValues(alpha: 0.75 * env);
      final metric = path.computeMetrics().first;
      c.drawPath(metric.extractPath(0, metric.length * r), _p);
      _p.style = PaintingStyle.fill;
    }
  }

  // --------------------------------------------------------------------- mapa

  void _mapa(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final env = _window(t, 0, 1.0, s.length - 1.3, s.length);
    if (env <= 0) return;
    const tinta = Color(0xFF3B2614);
    // La cartela con el título, arriba.
    final ca = _ease((t - 2.4) / 0.8) * env;
    if (ca > 0) {
      final cy = pad.top + 118;
      final rect = Rect.fromCenter(
        center: Offset(w / 2, cy),
        width: math.min(w * 0.6, 260),
        height: 54,
      );
      _p.color = const Color(0xFFF3E4BE).withValues(alpha: 0.92 * ca);
      c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = tinta.withValues(alpha: 0.8 * ca);
      c.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(3)),
        _p,
      );
      _p.style = PaintingStyle.fill;
      for (final sx in [-1.0, 1.0]) {
        final punta = Offset(w / 2 + sx * (rect.width / 2 + 10), cy);
        final rombo = Path()
          ..moveTo(punta.dx, punta.dy - 5)
          ..lineTo(punta.dx + 5 * sx, punta.dy)
          ..lineTo(punta.dx, punta.dy + 5)
          ..lineTo(punta.dx - 5 * sx, punta.dy)
          ..close();
        _p.color = tinta.withValues(alpha: 0.8 * ca);
        c.drawPath(rombo, _p);
      }
      final d = s.day;
      _text(
        c,
        tr('El valle', 'The valley'),
        Offset(w / 2, cy - 9),
        TextStyle(
          fontFamily: 'EBGaramond',
          fontSize: 18,
          letterSpacing: 3,
          color: tinta.withValues(alpha: ca),
        ),
      );
      _text(
        c,
        tr(
          'a ${d.day} de ${_month(d.month)} de ${d.year}',
          '${_month(d.month)} ${d.day}, ${d.year}',
        ),
        Offset(w / 2, cy + 12),
        TextStyle(
          fontFamily: 'EBGaramond',
          fontSize: 12.5,
          fontStyle: FontStyle.italic,
          color: tinta.withValues(alpha: ca),
        ),
      );
    }
    // La rosa de los vientos, abajo a la izquierda.
    final ra = _ease((t - 1.6) / 0.9) * env;
    if (ra > 0) {
      final o = Offset(w - 54, h - pad.bottom - 262);
      final r = 26.0;
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate((1 - ra) * -0.6);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tinta.withValues(alpha: 0.75 * ra);
      c.drawCircle(Offset.zero, r * 0.72, _p);
      c.drawCircle(Offset.zero, r * 0.78, _p);
      _p.style = PaintingStyle.fill;
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4 - math.pi / 2;
        final largo = k.isEven ? r : r * 0.55;
        final punta = Offset(math.cos(a), math.sin(a)) * largo;
        final lado =
            Offset(math.cos(a + math.pi / 2), math.sin(a + math.pi / 2)) *
            (r * 0.13);
        final mitad1 = Path()
          ..moveTo(0, 0)
          ..lineTo(punta.dx, punta.dy)
          ..lineTo(lado.dx, lado.dy)
          ..close();
        final mitad2 = Path()
          ..moveTo(0, 0)
          ..lineTo(punta.dx, punta.dy)
          ..lineTo(-lado.dx, -lado.dy)
          ..close();
        _p.color = tinta.withValues(alpha: 0.85 * ra);
        c.drawPath(mitad1, _p);
        _p.color = const Color(0xFFF3E4BE).withValues(alpha: 0.9 * ra);
        c.drawPath(mitad2, _p);
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = tinta.withValues(alpha: 0.85 * ra);
        c.drawPath(mitad2, _p);
        _p.style = PaintingStyle.fill;
      }
      c.restore();
      _text(
        c,
        'N',
        o.translate(0, -r - 10),
        TextStyle(
          fontFamily: 'EBGaramond',
          fontSize: 13,
          color: tinta.withValues(alpha: ra),
        ),
      );
    }
  }

  // --------------------------------------------------------------------- foto

  void _foto(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final flash = Fiesta.fotoFlash;
    // Antes del flash: el visor, cuatro esquinas.
    if (t < flash + 0.1) {
      final a = _ease(t / 0.3);
      final m = Rect.fromLTWH(w * 0.08, h * 0.2, w * 0.84, h * 0.56);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85 * a);
      const l = 22.0;
      for (final (p, dx, dy) in [
        (m.topLeft, 1.0, 1.0),
        (m.topRight, -1.0, 1.0),
        (m.bottomLeft, 1.0, -1.0),
        (m.bottomRight, -1.0, -1.0),
      ]) {
        c.drawLine(p, p.translate(l * dx, 0), _p);
        c.drawLine(p, p.translate(0, l * dy), _p);
      }
      _p.style = PaintingStyle.fill;
    }
    // El flash.
    final f = t - flash;
    if (f >= 0 && f < 0.5) {
      _p.color = const Color(0xFFFFFFFF).withValues(alpha: 1 - _ease(f / 0.5));
      c.drawRect(Offset.zero & size, _p);
    }
    final img = photo;
    if (img == null || f < 0.05) return;
    // La foto: sale del tamaño de la pantalla y se queda en una copia con su
    // borde, ladeada, con la fecha a mano.
    final u = _easeOut((f - 0.05) / 0.8);
    final se = _ease((t - (s.length - 1.2)) / 1.1);
    final anchoFinal = w * 0.7;
    final ancho = w + (anchoFinal - w) * u;
    final borde = 10 * u, pie = 46 * u;
    final altoImg = ancho * (img.height / img.width);
    // Al achicarse se queda con la franja del medio, que es donde está el
    // valle: arriba hay botones y abajo, la barra.
    final altoVisto = altoImg * (1 - 0.38 * u);
    final centro = Offset(w / 2, h / 2 + (h * 0.42 - h / 2) * u + se * h * 0.7);
    c.save();
    c.translate(centro.dx, centro.dy);
    c.rotate(-0.06 * u + 0.25 * se);
    final marco = Rect.fromCenter(
      center: Offset(0, pie / 2 - borde / 2),
      width: ancho + borde * 2,
      height: altoVisto + borde + pie,
    );
    final alpha = 1 - se;
    _p
      ..color = const Color(0xFF000000).withValues(alpha: 0.35 * u * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    c.drawRect(marco.shift(const Offset(4, 8)), _p);
    _p
      ..maskFilter = null
      ..color = const Color(0xFFFBF8F1).withValues(alpha: alpha);
    c.drawRect(marco, _p);
    final dst = Rect.fromLTWH(-ancho / 2, marco.top + borde, ancho, altoVisto);
    final src = Rect.fromCenter(
      center: Offset(img.width / 2, img.height * 0.46),
      width: img.width.toDouble(),
      height: img.height * (altoVisto / altoImg),
    );
    _p
      ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha)
      ..filterQuality = FilterQuality.medium;
    c.drawImageRect(img, src, dst, _p);
    final d = s.day;
    if (u > 0.6) {
      _text(
        c,
        tr(
          'Todo el valle · ${d.day} ${_month(d.month).substring(0, 3)} ${d.year}',
          'The whole valley · ${_month(d.month).substring(0, 3)} ${d.day} ${d.year}',
        ),
        Offset(0, marco.bottom - pie / 2 + 2),
        TextStyle(
          fontFamily: 'ArchitectsDaughter',
          fontSize: 15,
          color: const Color(
            0xFF2E3A66,
          ).withValues(alpha: _ease((u - 0.6) / 0.4) * alpha),
        ),
      );
    }
    c.restore();
  }

  // ------------------------------------------------------------------- confeti

  static const List<Color> _papeles = [
    Color(0xFFE5484D),
    Color(0xFFF2C14E),
    Color(0xFF3D7CC9),
    Color(0xFF4E9F6B),
    Color(0xFFF4EFE6),
    Color(0xFFE98A3A),
    Color(0xFF8E5BB5),
    Color(0xFFF59AB5),
  ];

  void _confeti(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final out = 1 - _ease((t - (s.length - 1.2)) / 1.2);
    final base = h - pad.bottom - 150;
    for (var lado = 0; lado < 2; lado++) {
      final x0 = lado == 0 ? 6.0 : w - 6;
      final hacia = lado == 0 ? 1.0 : -1.0;
      // El fogonazo del tiro.
      final fl = math.exp(-t * 9);
      _p.color = const Color(0xFFFFF2C4).withValues(alpha: 0.6 * fl);
      c.drawCircle(Offset(x0, base), 30 * fl + 4, _p);
      for (var j = 0; j < 95; j++) {
        final a = t - hash01(lado, j, 1) * 0.12;
        if (a < 0) continue;
        // Sale disparado y frena en el aire; después cae despacio, girando.
        final ang = math.pi * (0.30 + 0.22 * hash01(lado, j, 2));
        final v = 900 + 650 * hash01(lado, j, 3);
        const k = 3.4;
        const caida = 85.0;
        final e = (1 - math.exp(-k * a)) / k;
        final x =
            x0 +
            hacia * math.cos(ang) * v * e +
            math.sin(a * (2 + hash01(lado, j, 4) * 2) + j) *
                14 *
                math.min(1, a);
        final y = base - math.sin(ang) * v * e + caida * a + 0.0;
        if (y > h + 20) continue;
        final flip = math.cos(a * (5 + 5 * hash01(lado, j, 5)) + j);
        final rot = a * (3 + 4 * hash01(lado, j, 6)) * (j.isEven ? 1 : -1);
        final col = _papeles[(j + lado * 3) % _papeles.length];
        c.save();
        c.translate(x, y);
        c.rotate(rot);
        c.scale(1, 0.15 + 0.85 * flip.abs());
        _p.color = Color.lerp(
          col,
          const Color(0xFF000000),
          flip < 0 ? 0.2 : 0,
        )!.withValues(alpha: out);
        if (j % 7 == 0) {
          // Unas cuantas serpentinas: una tira rizada.
          final tira = Path()..moveTo(0, 0);
          for (var q = 1; q <= 6; q++) {
            tira.lineTo(math.sin(q * 1.4 + a * 4) * 4, q * 4.0);
          }
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2;
          c.drawPath(tira, _p);
          _p.style = PaintingStyle.fill;
        } else {
          c.drawRect(const Rect.fromLTWH(-3, -4.5, 6, 9), _p);
        }
        c.restore();
      }
    }
  }

  // --------------------------------------------------------------------- ronda

  void _ronda(Canvas c, Size size) {
    final w = size.width;
    final n = s.towns.length;
    // El cartel del pueblo en el que se está, debajo de la barra de arriba.
    String? nombre;
    String? simbolo;
    var a = 0.0;
    for (var k = 0; k < n; k++) {
      final llega = Fiesta.rondaArrive(k);
      final va = _window(t, llega, llega + 0.35, llega + 1.25, llega + 1.6);
      if (va > a) {
        a = va;
        nombre = s.towns[s.path[k]].name;
        simbolo = s.towns[s.path[k]].symbol;
      }
    }
    final fin = Fiesta.rondaStep * n + 0.6;
    final todos = _window(t, fin, fin + 0.5, s.length - 1.0, s.length - 0.3);
    if (todos > a) {
      a = todos;
      nombre = tr('Todo el valle', 'The whole valley');
      simbolo = null;
    }
    if (nombre == null || a <= 0.01) return;
    final cy = pad.top + 128 - 8 * (1 - a);
    const crema = Color(0xFFF7F1E3);
    final tp = TextPainter(
      text: TextSpan(
        text: nombre,
        style: TextStyle(
          fontFamily: 'EBGaramond',
          fontSize: 28,
          color: crema.withValues(alpha: a),
          shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 10)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 60);
    final conMarca = simbolo != null;
    final total = tp.width + (conMarca ? 30 : 0);
    final x = (w - total) / 2;
    if (conMarca) {
      HabitSigils.draw(
        c,
        Rect.fromCenter(center: Offset(x + 10, cy), width: 20, height: 20),
        simbolo,
        crema.withValues(alpha: a),
      );
    }
    tp.paint(c, Offset(x + (conMarca ? 30 : 0), cy - tp.height / 2));
    final raya = 40 * a;
    _p
      ..color = const Color(0xFFE9C46A).withValues(alpha: 0.9 * a)
      ..strokeWidth = 1;
    c.drawLine(
      Offset(w / 2 - raya, cy + 22),
      Offset(w / 2 + raya, cy + 22),
      _p,
    );
  }

  @override
  bool shouldRepaint(covariant _FiestaUi old) => true;
}
