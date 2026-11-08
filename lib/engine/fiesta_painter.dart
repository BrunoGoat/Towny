import 'dart:math' as math;
import 'dart:ui';

import '../core/math3.dart';
import '../core/rng.dart';
import '../fx/fiesta.dart';
import 'palette.dart';
import 'sigils.dart';

/// Lo que la fiesta del valle completo pinta **en el mundo**: lo que está en
/// un sitio del valle y se mueve con la cámara —las chispas de una plaza, el
/// hilo entre dos pueblos, un cohete—. Lo que va pegado a la pantalla (las
/// cuentas, el sello, los banderines) lo pinta `fiesta_overlay.dart`.
///
/// Va encima de todo lo demás, como las partículas: no hay z-buffer y esto
/// es luz, que se lee bien por delante de un tejado.
///
/// Todo sale de [t], los segundos desde que empezó. Ver [Fiesta].
void paintFiesta(
  Canvas canvas,
  Projector p,
  Size size,
  Palette pal,
  FiestaShow s,
  double t,
) {
  final f = _Fiesta(canvas, p, size, pal, s, t);
  switch (s.kind) {
    case FiestaKind.chispas:
      f.chispas(0.3);
    case FiestaKind.campanas:
      f.campanas();
    case FiestaKind.hilo:
      f.hilo();
    case FiestaKind.palomas:
      f.palomas();
    case FiestaKind.farolillos:
      f.farolillos();
    case FiestaKind.constelacion:
      f.constelacion();
    case FiestaKind.arcoiris:
      f.arcoiris();
    case FiestaKind.fuegos:
      f.fuegos();
    case FiestaKind.aurora:
      f.aurora();
    case FiestaKind.mayor:
      f.mayor();
    case FiestaKind.globos:
      f.globos();
    case FiestaKind.fugaces:
      f.fugaces();
    case FiestaKind.luciernagas:
      f.luciernagas();
    case FiestaKind.faros:
      f.faros();
    case FiestaKind.mapa:
      f.mapa();
    case FiestaKind.floracion:
      f.floracion();
    case FiestaKind.musica:
      f.musica();
    case FiestaKind.hogueras:
      f.hogueras();
    case FiestaKind.pompas:
      f.pompas();
    case FiestaKind.fuentes:
      f.fuentes();
    case FiestaKind.ronda:
      f.ronda();
    case FiestaKind.cuentas ||
        FiestaKind.luz ||
        FiestaKind.sello ||
        FiestaKind.banderines ||
        FiestaKind.petalos ||
        FiestaKind.pregon ||
        FiestaKind.cronica ||
        FiestaKind.foto ||
        FiestaKind.confeti:
      // Son de la interfaz.
      break;
  }
}

/// **El hilo del día**: el hilo de oro de la ronda, que se queda tendido
/// entre las plazas lo que queda del día en que el valle se completó.
///
/// Quieto y más tenue que en la fiesta, con una chispa que lo recorre de
/// vez en cuando, de punta a punta, como quien pasa la noticia. A la
/// medianoche deja de pintarse y no queda nada en su sitio: el día que no
/// se completa no falta ningún hilo, simplemente no lo hay.
///
/// [hilo] es una fiesta de la ronda que no corre: sólo se usan sus pueblos
/// y su recorrido. [time] es el reloj del pueblo, en segundos.
void paintHiloDelDia(
  Canvas canvas,
  Projector p,
  Size size,
  Palette pal,
  FiestaShow hilo,
  double time,
) {
  _Fiesta(canvas, p, size, pal, hilo, time).hiloQuieto();
}

/// Lo que brilla el hilo una vez tendido, contra el de la fiesta. La ronda
/// termina en este mismo brillo, para que al acabar no salte nada.
const double _hiloBrillo = 0.75;

/// Los colores de los cohetes, uno por pueblo. Cálidos y limpios: nada de
/// neón, que este cielo es de pueblo.
const List<Color> _fuegoColores = [
  Color(0xFFFFC857),
  Color(0xFFFF6B6B),
  Color(0xFF7FD8FF),
  Color(0xFFB8F27C),
  Color(0xFFE59CFF),
  Color(0xFFFFFFFF),
  Color(0xFFFF9F43),
  Color(0xFF9AA8FF),
];

const Color _oro = Color(0xFFF7CF6B);
const Color _oroClaro = Color(0xFFFFF1C4);

double _ease(double x) {
  final u = x.clamp(0.0, 1.0);
  return u * u * (3 - 2 * u);
}

double _easeOut(double x) {
  final u = x.clamp(0.0, 1.0);
  return 1 - (1 - u) * (1 - u) * (1 - u);
}

/// Sube de 0 a 1 entre [a] y [b] y vuelve a 0 entre [c] y [d].
double _window(double t, double a, double b, double c, double d) {
  if (t <= a || t >= d) return 0;
  if (t < b) return _ease((t - a) / (b - a));
  if (t > c) return 1 - _ease((t - c) / (d - c));
  return 1;
}

class _Fiesta {
  _Fiesta(this.c, this.p, this.size, this.pal, this.s, this.t);

  final Canvas c;
  final Projector p;
  final Size size;
  final Palette pal;
  final FiestaShow s;
  final double t;

  final Paint _paint = Paint()..isAntiAlias = true;

  double get span => s.valley.$3;
  double get length => s.length;

  /// Se apaga todo el último segundo, pase lo que pase: una fiesta no se
  /// corta en seco.
  double get _out => 1 - _ease((t - (length - 1.0)) / 1.0);

  Offset? _at(double x, double y, double z) {
    final q = p.project(V3(x, y, z));
    if (q == null) return null;
    return Offset(q.x, q.y);
  }

  /// Un tamaño del mundo en píxeles, en ese sitio, con un mínimo para que lo
  /// lejano no desaparezca y un máximo para que lo cercano no tape todo.
  double _px(
    double world,
    double x,
    double y,
    double z, {
    double min = 1.2,
    double max = 40,
  }) {
    final q = p.cameraOf(V3(x, y, z));
    if (q.z < p.near) return 0;
    return (world * p.focal / q.z).clamp(min, max);
  }

  void _glow(Offset o, double r, Color color, double alpha) {
    if (alpha <= 0.002 || r <= 0) return;
    _paint
      ..color = const Color(0xFFFFFFFF)
      ..shader = Gradient.radial(
        o,
        r,
        [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.35),
          color.withValues(alpha: 0),
        ],
        const [0, 0.35, 1],
      )
      ..maskFilter = null;
    c.drawCircle(o, r, _paint);
    _paint.shader = null;
  }

  void _dot(Offset o, double r, Color color, double alpha) {
    if (alpha <= 0.002) return;
    _paint.color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
    c.drawCircle(o, r, _paint);
  }

  /// Oscurece el cielo: de arriba hacia abajo, hasta [reach] de la pantalla.
  void _night(double amount, {double reach = 0.75, Color? tint}) {
    if (amount <= 0.002) return;
    final col = tint ?? const Color(0xFF0B1230);
    _paint.color = const Color(0xFFFFFFFF);
    _paint.shader = Gradient.linear(
      Offset.zero,
      Offset(0, size.height * reach),
      [
        col.withValues(alpha: 0.82 * amount),
        col.withValues(alpha: 0.55 * amount),
        col.withValues(alpha: (reach >= 1 ? 0.5 : 0.0) * amount),
      ],
      const [0, 0.55, 1],
    );
    c.drawRect(Offset.zero & size, _paint);
    _paint.shader = null;
    if (reach < 1) return;
  }

  /// Dónde cae el horizonte en la pantalla: un punto del suelo muy lejos,
  /// delante de la cámara.
  double _horizon() {
    final f = p.forward;
    final l = math.sqrt(f.x * f.x + f.z * f.z);
    if (l < 1e-6) return 0;
    final q = p.project(
      V3(p.eye.x + f.x / l * 1e5, 0, p.eye.z + f.z / l * 1e5),
    );
    return q == null ? size.height * 0.3 : q.y.clamp(0.0, size.height);
  }

  /// Unas estrellas finas en el cielo oscurecido.
  void _stars(double amount) {
    if (amount <= 0.01) return;
    // Sólo en el cielo de verdad: por encima del horizonte y de los montes,
    // que tapan su buen trozo.
    final techo = _horizon() - size.height * 0.07;
    if (techo <= 8) return;
    for (var i = 0; i < 46; i++) {
      final x = hash01(i, 71) * size.width;
      final y = math.pow(hash01(i, 72), 1.3) * techo;
      final tw = 0.55 + 0.45 * math.sin(t * (1.5 + hash01(i, 73) * 2) + i);
      _dot(
        Offset(x, y.toDouble()),
        0.6 + hash01(i, 74) * 0.9,
        const Color(0xFFFFFFFF),
        amount * tw * 0.8,
      );
    }
  }

  // ----------------------------------------------------------------- chispas

  /// Píxeles por unidad del mundo en ese punto del suelo.
  double _ppw(double x, double z) {
    final q = p.cameraOf(V3(x, 0, z));
    if (q.z < p.near) return 0;
    return p.focal / q.z;
  }

  /// Cuánto se agranda lo que se dibuja en la pantalla alrededor de un
  /// pueblo: uno para un pueblo de sesenta píxeles, más si está cerca. Lo de
  /// la fiesta se mide en la pantalla y no en el pueblo, porque desde el valle
  /// un pueblo son treinta píxeles y unas chispas de su tamaño no se ven.
  double _k(FiestaTown town) =>
      (town.radius * _ppw(town.x, town.z) / 30).clamp(0.8, 2.4);

  /// Una fuente de chispas en cada plaza, de uno en uno por el orden del
  /// valle, empezando a los [from] segundos.
  void chispas(double from, {double every = 0.25, double fade = 1}) {
    final n = s.path.length;
    // De uno en uno, y al final todos a la vez, más alto.
    final fin = from + every * n + 0.5;
    for (var k = 0; k < n; k++) {
      final i = s.path[k];
      final town = s.towns[i];
      _fuente(town, i, t - from - every * k, 1.0, fade);
      if (s.kind == FiestaKind.chispas) {
        _fuente(town, i + 50, t - fin - 0.04 * k, 1.45, fade);
      }
    }
  }

  /// Una fuente de chispas doradas en la plaza de [town], de [grande] veces
  /// el tamaño de la de siempre, que empezó hace [tt] segundos.
  void _fuente(
    FiestaTown town,
    int seed,
    double tt,
    double grande,
    double fade,
  ) {
    if (tt < 0 || tt > 3.2) return;
    final o = _at(town.x, 0, town.z);
    if (o == null) return;
    final m = _k(town) * grande;
    // El fogonazo de abajo, y una luz que se queda un rato en la plaza.
    final fl = _window(tt, 0, 0.1, 0.2, 1.4) * fade;
    _glow(o, 60 * m, _oro, 0.55 * fl * _out);
    _glow(
      o,
      18 * m,
      const Color(0xFFFFFFFF),
      0.7 * _window(tt, 0, 0.05, 0.1, 0.5),
    );
    final alto = 120 * m, ancho = 46 * m, cae = 30 * m;
    for (var j = 0; j < 70; j++) {
      final life = 1.6 + hash01(seed, j, 1) * 1.2;
      final a = tt - hash01(seed, j, 2) * 0.35;
      if (a < 0 || a > life) continue;
      final ang = hash01(seed, j, 3) * math.pi * 2;
      final e = 1 - math.exp(-2.6 * a);
      final h = alto * (0.5 + 0.5 * hash01(seed, j, 5));
      final sp = ancho * (0.15 + 0.85 * hash01(seed, j, 4));
      Offset at(double b) {
        final ee = 1 - math.exp(-2.6 * math.max(0, b));
        return o +
            Offset(
              math.cos(ang) * sp * ee,
              -h * ee + cae * b * b + math.sin(ang) * sp * 0.25 * ee,
            );
      }

      final q = at(a), q0 = at(a - 0.06);
      final u = a / life;
      // Lo que cae por debajo de la plaza se apaga: no llueve oro sobre los
      // botones.
      final bajo = 1 - ((q.dy - o.dy) / (24 * m)).clamp(0.0, 1.0);
      final alpha = (1 - u) * fade * _out * (e > 0 ? 1 : 0) * bajo;
      final tw = 0.55 + 0.45 * math.sin(a * 16 + j);
      final rr = (1.0 + 0.9 * hash01(seed, j, 6)) * math.min(m, 1.8);
      _paint
        ..color = _oroClaro.withValues(alpha: alpha * 0.6)
        ..strokeWidth = rr * 1.1
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      c.drawLine(q0, q, _paint);
      _paint.style = PaintingStyle.fill;
      _glow(q, rr * 5, _oro, 0.45 * alpha);
      _dot(q, rr, j % 4 == 0 ? const Color(0xFFFFFFFF) : _oroClaro, alpha * tw);
    }
  }

  // ----------------------------------------------------------------- campanas

  void _ring(
    double x,
    double z,
    double radius,
    double width,
    Color color,
    double alpha,
  ) {
    if (alpha <= 0.003) return;
    final path = Path();
    const n = 40;
    var started = false;
    for (var k = 0; k <= n; k++) {
      final a = k / n * math.pi * 2;
      final q = _at(x + math.cos(a) * radius, 0.05, z + math.sin(a) * radius);
      if (q == null) {
        started = false;
        continue;
      }
      if (!started) {
        path.moveTo(q.dx, q.dy);
        started = true;
      } else {
        path.lineTo(q.dx, q.dy);
      }
    }
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 3
      ..color = color.withValues(alpha: alpha * 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 1.5);
    c.drawPath(path, _paint);
    _paint
      ..strokeWidth = width
      ..color = color.withValues(alpha: alpha)
      ..maskFilter = null;
    c.drawPath(path, _paint);
    _paint.style = PaintingStyle.fill;
  }

  /// Un anillo en el suelo de la plaza, de [px] píxeles de radio.
  void _ringPx(
    FiestaTown town,
    double px,
    double width,
    Color color,
    double alpha,
  ) {
    final ppw = _ppw(town.x, town.z);
    if (ppw <= 0) return;
    _ring(town.x, town.z, px / ppw, width, color, alpha);
  }

  void campanas() {
    final n = s.towns.length;
    for (var k = 0; k < n; k++) {
      final town = s.towns[s.path[k]];
      final m = _k(town);
      final t0 = Fiesta.campanaAt(k);
      for (var w = 0; w < 3; w++) {
        final a = t - t0 - w * 0.22;
        if (a < 0 || a > 2.0) continue;
        final u = a / 2.0;
        _ringPx(
          town,
          (10 + 70 * _easeOut(u)) * m,
          2.4 - w * 0.5,
          _oroClaro,
          (1 - u) * (1 - u) * (1 - w * 0.25) * _out,
        );
      }
      final o = _at(town.x, 0, town.z);
      if (o != null) {
        final g = _window(t - t0, 0, 0.06, 0.3, 1.4);
        _glow(o, 40 * m, _oro, 0.6 * g);
      }
    }
    // Todas juntas: un anillo grande en cada plaza a la vez.
    final fin = Fiesta.campanaAt(n) + 0.15;
    for (final town in s.towns) {
      final m = _k(town);
      for (var w = 0; w < 2; w++) {
        final a = t - fin - w * 0.3;
        if (a < 0 || a > 2.6) continue;
        final u = a / 2.6;
        _ringPx(
          town,
          (14 + 110 * _easeOut(u)) * m,
          2.8,
          _oro,
          (1 - u) * (1 - u) * _out,
        );
      }
      final o = _at(town.x, 0, town.z);
      if (o != null) {
        _glow(o, 60 * m, _oro, 0.55 * _window(t - fin, 0, 0.1, 0.4, 2.0));
      }
    }
  }

  // ---------------------------------------------------------------------- hilo

  /// Un punto del hilo entre dos plazas, colgado en arco.
  V3 _thread(FiestaTown a, FiestaTown b, double u) {
    final d = math.sqrt((a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z));
    final h = d * 0.16 + 0.6;
    return V3(
      a.x + (b.x - a.x) * u,
      0.4 + 4 * h * u * (1 - u),
      a.z + (b.z - a.z) * u,
    );
  }

  void hilo() {
    final n = s.towns.length;
    final fin = Fiesta.hiloReach(n - 1, n);
    // Después de cerrarse, el hilo entero late una vez y se va.
    final pulso = _window(t, fin, fin + 0.25, fin + 0.6, fin + 2.2);
    final resto = t < fin + 0.6 ? 1.0 : 1 - _ease((t - fin - 0.6) / 1.6);
    if (resto <= 0) return;
    for (var k = 0; k < n - 1; k++) {
      final a = s.towns[s.path[k]], b = s.towns[s.path[k + 1]];
      final t0 = Fiesta.hiloReach(k, n), t1 = Fiesta.hiloReach(k + 1, n);
      if (t < t0) break;
      final head = _ease((t - t0) / (t1 - t0));
      final pts = <Offset>[];
      const steps = 36;
      for (var j = 0; j <= steps; j++) {
        final u = head * j / steps;
        final w = _thread(a, b, u);
        final q = _at(w.x, w.y, w.z);
        if (q != null) pts.add(q);
      }
      if (pts.length < 2) continue;
      final path = Path()..addPolygon(pts, false);
      final a1 = (0.85 + 0.15 * pulso) * resto;
      _paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 9 + 6 * pulso
        ..color = _oro.withValues(alpha: 0.22 * a1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      c.drawPath(path, _paint);
      _paint
        ..strokeWidth = 1.8 + 1.2 * pulso
        ..color = _oroClaro.withValues(alpha: a1)
        ..maskFilter = null;
      c.drawPath(path, _paint);
      _paint.style = PaintingStyle.fill;
      // La cabeza, mientras va.
      if (head < 1) {
        _glow(pts.last, 16, _oro, 0.8);
        _dot(pts.last, 2.6, const Color(0xFFFFFFFF), 1);
      }
      // Y chispas que se desprenden del hilo al final.
      if (t > fin + 0.3) {
        for (var j = 0; j < 14; j++) {
          final u = hash01(k, j, 9);
          final w = _thread(a, b, u);
          final a2 = t - fin - 0.3 - hash01(k, j, 10) * 0.5;
          if (a2 < 0) continue;
          final q = _at(w.x, w.y + a2 * span * 0.02, w.z);
          if (q == null) continue;
          _dot(q, 1.4, _oroClaro, (1 - a2 / 1.6).clamp(0.0, 1.0) * 0.9);
        }
      }
    }
    // El destello al llegar a cada plaza.
    for (var k = 0; k < n; k++) {
      final town = s.towns[s.path[k]];
      final a = t - Fiesta.hiloReach(k, n);
      if (a < 0) continue;
      final o = _at(town.x, 0.4, town.z);
      if (o == null) continue;
      final m = _k(town);
      _glow(
        o,
        44 * m,
        _oro,
        (0.75 * _window(a, 0, 0.08, 0.2, 1.2) + 0.35 * pulso) * resto,
      );
      if (a < 1.4) {
        _ringPx(
          town,
          (8 + 50 * _easeOut(a / 1.4)) * m,
          1.8,
          _oroClaro,
          (1 - a / 1.4) * 0.9,
        );
      }
    }
  }

  // ------------------------------------------------------------------- palomas

  void palomas() {
    final (vx, vz, _) = s.valley;
    final alto = span * 0.46 + 8;
    final ronda = span * 0.36 + 6;
    final n = s.towns.length;
    for (var k = 0; k < s.path.length; k++) {
      final i = s.path[k];
      final town = s.towns[i];
      final t0 = 0.15 * k;
      for (var d = 0; d < 9; d++) {
        final a = t - t0 - hash01(i, d, 20) * 0.45;
        if (a < 0) continue;
        // El despegue: una espiral que sube desde la plaza.
        final ang0 = hash01(i, d, 21) * math.pi * 2;
        final giro = 1.3 + 0.8 * hash01(i, d, 24);
        final sube = _easeOut(a / 1.9);
        final sx =
            town.x +
            math.cos(ang0 + a * giro) * town.radius * (0.2 + 0.7 * sube);
        final sz =
            town.z +
            math.sin(ang0 + a * giro) * town.radius * (0.2 + 0.7 * sube);
        final sy = 0.5 + sube * alto * (0.6 + 0.3 * hash01(i, d, 25));
        // La ronda: todas juntas sobre el valle, pero no en fila: cada una
        // a su radio, a su altura y a su paso, como una bandada de verdad.
        final fase =
            (i * 9 + d) / (n * 9) * math.pi * 2 + hashJitter(0.25, i, d, 26);
        final w = 0.42 + 0.12 * hash01(i, d, 27);
        final rr = ronda * (0.6 + 0.6 * hash01(i, d, 22));
        final cx = vx + math.cos(fase + t * w) * rr;
        final cz = vz + math.sin(fase + t * w) * rr * 0.8;
        final cy =
            alto * (0.8 + 0.5 * hash01(i, d, 28)) +
            math.sin(t * 1.6 + d) * span * 0.012;
        final m = _ease((a - 1.0) / 1.8);
        var x = sx + (cx - sx) * m;
        var y = sy + (cy - sy) * m;
        var z = sz + (cz - sz) * m;
        // Y se van: hacia fuera y hacia arriba.
        final ida = _ease((t - 4.4 - hash01(i, d, 23) * 0.8) / 2.0);
        if (ida > 0) {
          x += (x - vx) * ida * 1.6;
          z += (z - vz) * ida * 1.6;
          y += ida * span * 0.3;
        }
        final q = _at(x, y, z);
        if (q == null) continue;
        final dt = 0.05;
        final q2 = _at(
          x + (-math.sin(fase + t * w)) * rr * w * dt * m,
          y + (1 - m) * 0.5 * dt,
          z + math.cos(fase + t * w) * rr * w * dt * m,
        );
        final dx = q2 == null ? 0.0 : (q2.dx - q.dx);
        final big = _px(town.radius * 0.08, x, y, z, min: 4.2, max: 11);
        final flap = math.sin(
          t * (11 + 4 * hash01(i, d, 29)) + i * 3.1 + d * 1.7,
        );
        final alpha = (1 - ida) * _out * _ease(a / 0.3);
        _dove(q, dx, big, flap, alpha);
      }
    }
  }

  /// Una paloma vista de lejos: la silueta de siempre, dos alas en arco que
  /// suben y bajan, apenas ladeada hacia donde va.
  void _dove(Offset o, double dx, double s, double flap, double alpha) {
    if (alpha <= 0.01) return;
    final lean = (dx * 0.08).clamp(-0.35, 0.35);
    final tip = flap * s * 0.75;
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(lean);
    final path = Path()
      ..moveTo(-s * 1.7, -tip)
      ..quadraticBezierTo(-s * 0.8, -s * 0.55 - tip * 0.3, 0, 0)
      ..quadraticBezierTo(s * 0.8, -s * 0.55 - tip * 0.3, s * 1.7, -tip);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1.6, s * 0.5)
      ..color = const Color(0xFF2E3440).withValues(alpha: 0.22 * alpha);
    c.save();
    c.translate(0.8, 1.2);
    c.drawPath(path, _paint);
    c.restore();
    _paint.color = const Color(0xFFFFFFFB).withValues(alpha: alpha);
    c.drawPath(path, _paint);
    _paint.style = PaintingStyle.fill;
    c.restore();
    _dot(o, math.max(1.1, s * 0.3), const Color(0xFFFFFFFB), alpha);
  }

  // ---------------------------------------------------------------- farolillos

  void farolillos() {
    final noche = _window(t, 0, 1.4, length - 1.6, length);
    _night(noche * 0.8, reach: 1.0, tint: const Color(0xFF1A1440));
    _stars(noche * 0.7);
    final h = size.height;
    for (var k = 0; k < s.path.length; k++) {
      final i = s.path[k];
      final town = s.towns[i];
      final o = _at(town.x, 0, town.z);
      if (o == null) continue;
      final m = _k(town).clamp(0.8, 1.4);
      for (var j = 0; j < 5; j++) {
        final t0 = 0.4 + 0.22 * k + 0.6 * j + hash01(i, j, 30) * 0.3;
        final a = t - t0;
        if (a < 0) continue;
        // Suben en la pantalla, despacio al principio y cada vez más, y se
        // achican como lo que se va lejos.
        final vel = h * (0.075 + 0.04 * hash01(i, j, 33));
        final y = o.dy - 8 * m - vel * a - vel * 0.12 * a * a;
        if (y < -40) continue;
        final x =
            o.dx +
            hashJitter(22 * m, i, j, 31) +
            math.sin(a * 1.2 + j * 2) * 9 +
            a * 6 * (hash01(i, j, 34) - 0.3);
        final lejos = ((o.dy - y) / h).clamp(0.0, 1.0);
        final w = (8.5 * m) * (1 - 0.55 * lejos);
        final flick = 0.86 + 0.14 * math.sin(t * 9 + i * 2 + j * 5);
        final alpha = _ease(a / 0.6) * _out * (1 - _ease((lejos - 0.6) / 0.35));
        if (alpha <= 0.01) continue;
        final q = Offset(x, y);
        _glow(q, w * 6, const Color(0xFFFFA347), 0.45 * alpha * flick);
        final body = RRect.fromRectAndRadius(
          Rect.fromCenter(center: q, width: w * 1.5, height: w * 1.9),
          Radius.circular(w * 0.55),
        );
        _paint
          ..color = const Color(0xFFFFFFFF)
          ..shader = Gradient.linear(
            body.outerRect.topCenter,
            body.outerRect.bottomCenter,
            [
              const Color(0xFFFF8A3D).withValues(alpha: alpha),
              const Color(0xFFFFD27A).withValues(alpha: alpha),
              const Color(0xFFFFF4D6).withValues(alpha: alpha),
            ],
            const [0, 0.55, 1],
          );
        c.drawRRect(body, _paint);
        _paint.shader = null;
        _paint.color = const Color(0xFF7A3B12).withValues(alpha: alpha * 0.8);
        c.drawRect(
          Rect.fromLTWH(
            body.left + w * 0.2,
            body.top - w * 0.12,
            w * 1.1,
            w * 0.18,
          ),
          _paint,
        );
      }
    }
  }

  // -------------------------------------------------------------- constelación

  /// Dónde queda la estrella de cada pueblo: encima de él en la pantalla, en
  /// la franja del cielo, más alta cuanto más lejos está el pueblo. El valle
  /// queda dibujado arriba con su misma forma.
  List<Offset?> _starSpots() {
    final pies = [for (final town in s.towns) _at(town.x, 0, town.z)];
    final ys = [
      for (final q in pies)
        if (q != null) q.dy,
    ];
    final xs = [
      for (final q in pies)
        if (q != null) q.dx,
    ];
    if (ys.isEmpty) return pies;
    final lo = ys.reduce(math.min), hi = ys.reduce(math.max);
    final xlo = xs.reduce(math.min), xhi = xs.reduce(math.max);
    final w = size.width;
    // Entre los bordes y lejos de la columna de botones de la derecha.
    double sx(double x) => xhi - xlo < 1
        ? w * 0.45
        : w * 0.12 + (x - xlo) / (xhi - xlo) * w * 0.68;
    return [
      for (final q in pies)
        q == null
            ? null
            : Offset(
                sx(q.dx),
                size.height *
                    (0.12 +
                        0.2 * (hi - lo < 1 ? 0.5 : (q.dy - lo) / (hi - lo))),
              ),
    ];
  }

  void _sparkle(Offset o, double r, double alpha) {
    if (alpha <= 0.01) return;
    _glow(o, r * 5, const Color(0xFFCFE0FF), 0.45 * alpha);
    _paint
      ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    c.drawLine(o.translate(-r * 3.2, 0), o.translate(r * 3.2, 0), _paint);
    c.drawLine(o.translate(0, -r * 3.2), o.translate(0, r * 3.2), _paint);
    _paint.style = PaintingStyle.fill;
    _dot(o, r, const Color(0xFFFFFFFF), alpha);
  }

  void constelacion() {
    final noche = _window(t, 0, 1.2, length - 1.6, length);
    _night(noche * 0.85, reach: 0.9);
    _stars(noche * 0.7);
    final spots = _starSpots();
    final n = s.towns.length;
    final llegaron = <int>[];
    for (var k = 0; k < n; k++) {
      final i = s.path[k];
      final town = s.towns[i];
      final star = spots[i];
      final pie = _at(town.x, 0.5, town.z);
      if (star == null || pie == null) continue;
      final a = t - Fiesta.estrellaAt(k);
      if (a < 0) continue;
      final u = _ease(a / Fiesta.estrellaRise);
      final head = Offset.lerp(pie, star, u)!;
      if (u < 1) {
        // La luz subiendo, con su estela.
        final tail = Offset.lerp(pie, star, math.max(0, u - 0.35))!;
        _paint
          ..color = const Color(0xFFFFFFFF)
          ..shader = Gradient.linear(tail, head, [
            const Color(0x00FFFFFF),
            const Color(0xCCFFF6DA),
          ])
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        c.drawLine(tail, head, _paint);
        _paint
          ..shader = null
          ..style = PaintingStyle.fill;
        _glow(head, 12, const Color(0xFFFFF0C0), 0.9);
        _dot(head, 2.2, const Color(0xFFFFFFFF), 1);
        // Y el destello abajo, al salir.
        _glow(pie, 22, _oro, 0.6 * (1 - u));
      } else {
        llegaron.add(i);
        final b = a - Fiesta.estrellaRise;
        final pop = 1 + 1.4 * math.exp(-b * 5);
        final tw = 0.85 + 0.15 * math.sin(t * 3 + i);
        _sparkle(star, 1.9 * pop, noche * tw);
        // La marca del pueblo, chiquita, debajo de su estrella.
        final m = _ease((b - 0.3) / 0.8) * noche * 0.75;
        if (m > 0.01) {
          HabitSigils.draw(
            c,
            Rect.fromCenter(
              center: star.translate(0, 17),
              width: 13,
              height: 13,
            ),
            town.symbol,
            const Color(0xFFE9EEFF).withValues(alpha: m),
          );
        }
      }
    }
    // Las líneas, cuando ya están todas.
    final todas = Fiesta.estrellaAt(n - 1) + Fiesta.estrellaRise + 0.2;
    final dibujo = _ease((t - todas) / 1.2);
    if (dibujo > 0 && n > 1) {
      // En ronda alrededor del centro, que así las líneas no se cruzan.
      final orden = spots.whereType<Offset>().toList();
      final mx = orden.fold(0.0, (a, o) => a + o.dx) / orden.length;
      final my = orden.fold(0.0, (a, o) => a + o.dy) / orden.length;
      orden.sort(
        (a, b) => math
            .atan2(a.dy - my, a.dx - mx)
            .compareTo(math.atan2(b.dy - my, b.dx - mx)),
      );
      if (n > 2) orden.add(orden.first);
      final tramos = orden.length - 1;
      final hasta = dibujo * tramos;
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFDDE6FF).withValues(alpha: 0.55 * noche);
      for (var k = 0; k < tramos; k++) {
        final f = (hasta - k).clamp(0.0, 1.0);
        if (f <= 0) break;
        final a = orden[k], b = orden[k + 1];
        final d = b - a;
        final l = d.distance;
        if (l < 1) continue;
        // Sin tocar las estrellas, como en los mapas del cielo.
        final ua = 7 / l, ub = 1 - 7 / l;
        if (ub <= ua) continue;
        final e = ua + (ub - ua) * f;
        c.drawLine(a + d * ua, a + d * e, _paint);
      }
      _paint.style = PaintingStyle.fill;
    }
  }

  // ------------------------------------------------------------------ arcoíris

  void arcoiris() {
    final pies = [
      for (final town in s.towns) _at(town.x, 0, town.z),
    ].whereType<Offset>().toList();
    if (pies.isEmpty) return;
    final w = size.width, h = size.height;
    // Un arco grande, como se ve un arcoíris de verdad en una foto de
    // canto: el centro está en el suelo, debajo de los pueblos, y las patas
    // caen fuera de la pantalla. Lo que se ve es la parte de arriba, de
    // punta a punta, alta en el cielo.
    final base = pies.map((o) => o.dy).reduce(math.max) + 10;
    final cx = w / 2;
    final r = base - h * 0.13;
    final rect0 = Rect.fromCircle(center: Offset(cx, base), radius: r);
    // Antes del arco, el cielo se aclara un poco, como cuando sale el sol con
    // lluvia.
    final luz = _window(t, 0, 1.0, length - 2.0, length);
    _paint
      ..color = const Color(0xFFFFFFFF)
      ..shader = Gradient.radial(Offset(cx, base - r * 0.7), r * 1.2, [
        const Color(0xFFFFF7E0).withValues(alpha: 0.28 * luz),
        const Color(0x00FFF7E0),
      ]);
    c.drawRect(Offset.zero & size, _paint);
    _paint.shader = null;

    final grow = _easeOut((t - 0.3) / 2.2);
    final fade = 1 - _ease((t - (length - 2.4)) / 2.2);
    if (grow <= 0 || fade <= 0) return;
    const bands = [
      Color(0xFFE5484D),
      Color(0xFFF2994A),
      Color(0xFFF2D04A),
      Color(0xFF6FCF77),
      Color(0xFF4FA3E0),
      Color(0xFF6F6BD8),
      Color(0xFFA56CD1),
    ];
    // De dónde a dónde se ve: de un canto de la pantalla al otro.
    final borde = math.min(1.0, (w / 2 + 30) / r);
    final desde = math.pi + math.acos(borde);
    final hasta = 2 * math.pi - math.acos(borde);
    final barrido = (hasta - desde) * grow;
    final ancho = math.max(5.0, r * 0.026);
    // Un halo ancho detrás, para que no sea una pegatina.
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = ancho * 10
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.10 * fade)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, ancho * 3);
    c.drawArc(rect0.deflate(ancho * 3), desde, barrido, false, _paint);
    _paint.maskFilter = MaskFilter.blur(BlurStyle.normal, ancho * 0.4);
    for (var k = 0; k < bands.length; k++) {
      _paint
        ..strokeWidth = ancho * 1.08
        ..color = bands[k].withValues(alpha: 0.5 * fade);
      c.drawArc(rect0.deflate(k * ancho), desde, barrido, false, _paint);
    }
    // Y el segundo, más tenue y al revés, por fuera, como sale a veces.
    for (var k = 0; k < bands.length; k++) {
      _paint
        ..strokeWidth = ancho * 0.9
        ..color = bands[bands.length - 1 - k].withValues(alpha: 0.13 * fade);
      c.drawArc(
        rect0.inflate(ancho * 4 + k * ancho * 0.9),
        desde,
        barrido,
        false,
        _paint,
      );
    }
    _paint
      ..maskFilter = null
      ..style = PaintingStyle.fill;
    // La cabeza, mientras se dibuja.
    if (grow < 1) {
      final a = desde + barrido;
      final rr = r - ancho * 3;
      final o = Offset(cx + math.cos(a) * rr, base + math.sin(a) * rr);
      _glow(o, ancho * 9, const Color(0xFFFFFFFF), 0.75);
    }
  }

  // --------------------------------------------------------------------- fuegos

  /// Un cohete. La subida sale de su plaza; el estallido va en la
  /// pantalla, en la franja del cielo, para que reviente siempre arriba y
  /// del mismo tamaño se mire el valle de donde se mire.
  ///
  /// Tres clases, según la semilla: la de siempre (una bola), la corona (un
  /// anillo limpio) y el sauce (dorado, que cae despacio dejando estela).
  void _cohete(Cohete k, double nightBoost) {
    final town = s.towns[k.town % s.towns.length];
    final a = t - k.at;
    if (a < 0) return;
    final o = _at(town.x, 0, town.z);
    if (o == null) return;
    final w = size.width, h = size.height;
    final clase = k.big ? 0 : k.seed % 3;
    final burst = Offset(
      (o.dx + hashJitter(46, k.seed, 2)).clamp(w * 0.14, w * 0.86),
      h *
          (k.big
              ? 0.12 + 0.06 * hash01(k.seed, 1)
              : 0.09 + 0.17 * hash01(k.seed, 1)),
    );
    final color = clase == 2
        ? const Color(0xFFFFCF70)
        : _fuegoColores[k.color % _fuegoColores.length];
    if (a < k.rise) {
      // Subiendo: una chispa con su estela, que frena al llegar arriba.
      Offset at(double u) {
        final e = 1 - (1 - u) * (1 - u);
        return Offset(
          o.dx + (burst.dx - o.dx) * u + math.sin(u * 9 + k.seed) * 2,
          o.dy + (burst.dy - o.dy) * e,
        );
      }

      final u = a / k.rise;
      final q = at(u), q0 = at(math.max(0, u - 0.16));
      _paint
        ..color = const Color(0xFFFFFFFF)
        ..shader = Gradient.linear(q0, q, [
          const Color(0x00FFE7B0),
          const Color(0xEEFFE7B0),
        ])
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      c.drawLine(q0, q, _paint);
      _paint
        ..shader = null
        ..style = PaintingStyle.fill;
      _glow(q, 9, const Color(0xFFFFE7B0), 0.8);
      _dot(q, 2.2, const Color(0xFFFFFFFF), 1);
      return;
    }
    final b = a - k.rise;
    final life = clase == 2 ? 2.9 : (k.big ? 2.5 : 2.1);
    if (b > life) return;
    final m = math.min(w, h) / 400;
    final radio = (k.big ? 104.0 : 66 + 22 * hash01(k.seed, 7)) * m;
    // El fogonazo, que aclara el cielo un instante.
    final flash = math.exp(-b * 6);
    _glow(burst, radio * 2.2, color, 0.35 * flash * nightBoost);
    _glow(burst, radio * 0.45, const Color(0xFFFFFFFF), 0.8 * flash);
    final n = k.big ? 84 : (clase == 1 ? 44 : 64);
    final caida = (clase == 2 ? 30.0 : 20.0) * m;
    for (var j = 0; j < n; j++) {
      double dx, dy, sp;
      if (clase == 1) {
        final th = j / n * math.pi * 2 + hash01(k.seed, 8);
        dx = math.cos(th);
        dy = math.sin(th) * 0.92;
        sp = 1;
      } else {
        final zz = hash01(k.seed, j, 4) * 2 - 1;
        final th = hash01(k.seed, j, 5) * math.pi * 2;
        final rr = math.sqrt(1 - zz * zz);
        dx = rr * math.cos(th);
        dy = zz;
        sp = 0.88 + 0.12 * hash01(k.seed, j, 6);
      }
      Offset at(double bb) {
        if (bb < 0) bb = 0;
        final e = 1 - math.exp(-(clase == 2 ? 2.4 : 3.4) * bb);
        return burst +
            Offset(dx * radio * sp * e, dy * radio * sp * e + caida * bb * bb);
      }

      final cola = clase == 2 ? 0.42 : 0.12;
      final q = at(b), q0 = at(b - cola);
      final u = b / life;
      final fade = clase == 2 ? (1 - u) : (1 - u) * (1 - u);
      // Algunas titilan al final: el brillo que queda colgado.
      final glitter = j % 3 == 0 && u > 0.5
          ? (math.sin(b * 40 + j * 1.7) > 0 ? 1.0 : 0.25)
          : 1.0;
      final col = Color.lerp(
        const Color(0xFFFFFFFF),
        color,
        math.min(1, b * 3.5),
      )!;
      _paint
        ..color = const Color(0xFFFFFFFF)
        ..shader = Gradient.linear(q0, q, [
          col.withValues(alpha: 0),
          col.withValues(alpha: fade * glitter),
        ])
        ..strokeWidth = clase == 2 ? 1.6 : 2.1
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      c.drawLine(q0, q, _paint);
      _paint
        ..shader = null
        ..style = PaintingStyle.fill;
      _dot(
        q,
        1.5,
        Color.lerp(col, const Color(0xFFFFFFFF), 0.5)!,
        fade * glitter,
      );
      if (j % 2 == 0) _glow(q, 7, col, 0.3 * fade * glitter * nightBoost);
    }
  }

  void fuegos({double? nightFrom}) {
    final desde = nightFrom ?? 0.0;
    final noche = _window(t, desde, desde + 0.8, length - 1.4, length);
    _night(noche, reach: 1.0, tint: const Color(0xFF070B22));
    _stars(noche);
    for (final k in Fiesta.cohetes(s)) {
      _cohete(k, 0.5 + 0.5 * noche);
    }
  }

  // -------------------------------------------------------------------- aurora

  void aurora() {
    final noche = _window(t, 0, 1.6, length - 2.0, length);
    _night(noche * 0.95, reach: 0.95, tint: const Color(0xFF06122A));
    _stars(noche);
    final env = _window(t, 0.8, 3.0, length - 2.6, length - 0.4);
    if (env <= 0) return;
    final w = size.width, h = size.height;
    const cortinas = [
      (0.20, 0.13, 0.0, Color(0xFF6CFFB0), Color(0xFF8A6CFF)),
      (0.27, 0.10, 2.1, Color(0xFF52F0C8), Color(0xFFB36CFF)),
      (0.15, 0.08, 4.0, Color(0xFF9CFF8A), Color(0xFF5FA8FF)),
    ];
    for (var r = 0; r < cortinas.length; r++) {
      final (base, largo, fase, abajo, arriba) = cortinas[r];
      const paso = 6.0;
      final pos = <Offset>[];
      final cols = <Color>[];
      for (var x = -paso * 2; x <= w + paso * 2; x += paso) {
        final ox = x / w;
        final yb =
            h * base +
            h * 0.035 * math.sin(ox * 5.2 + t * 0.55 + fase) +
            h * 0.015 * math.sin(ox * 13 - t * 0.9 + fase * 2);
        // Los pliegues: la cortina no es pareja, tiene rayos más largos y
        // más cortos, como las de verdad.
        final l =
            h *
            largo *
            (0.7 +
                0.2 * math.sin(ox * 9 + t * 1.3 + fase) +
                0.25 * math.sin(ox * 47 + t * 0.6 + fase * 3).abs());
        final brillo =
            (0.4 +
                    0.3 * math.sin(ox * 7.3 - t * 1.1 + fase) +
                    0.15 * math.sin(ox * 23 + t * 2.3 + r) +
                    0.25 * math.sin(ox * 61 - t * 0.8 + r * 2))
                .clamp(0.0, 1.0);
        final a = env * brillo * (r == 0 ? 0.55 : 0.4);
        pos
          ..add(Offset(x, yb))
          ..add(Offset(x + math.sin(t + ox * 4) * 6, yb - l));
        cols
          ..add(abajo.withValues(alpha: a))
          ..add(arriba.withValues(alpha: 0));
      }
      final v = Vertices(VertexMode.triangleStrip, pos, colors: cols);
      _paint
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFFFFFF);
      c.drawVertices(v, BlendMode.dst, _paint);
      // Y el borde de abajo, que es lo que más brilla en una aurora de verdad.
      final borde = Path()..moveTo(pos[0].dx, pos[0].dy);
      for (var k = 2; k < pos.length; k += 2) {
        borde.lineTo(pos[k].dx, pos[k].dy);
      }
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = abajo.withValues(alpha: 0.35 * env)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      c.drawPath(borde, _paint);
      _paint
        ..style = PaintingStyle.fill
        ..maskFilter = null
        ..blendMode = BlendMode.srcOver;
    }
    // El reflejo verde en el horizonte.
    _paint.color = const Color(0xFFFFFFFF);
    _paint.shader = Gradient.linear(
      Offset(0, h * 0.3),
      Offset(0, h * 0.62),
      [
        const Color(0x0052F0C8),
        const Color(0x2252F0C8).withValues(alpha: 0.13 * env),
        const Color(0x0052F0C8),
      ],
      const [0, 0.5, 1],
    );
    c.drawRect(Offset.zero & size, _paint);
    _paint.shader = null;
  }

  // --------------------------------------------------------------------- mayor

  void mayor() {
    chispas(0.8, every: 0.35);
    fuegos(nightFrom: 4.9);
  }

  // ------------------------------------------------------------------- globos

  static const List<Color> _globoColores = [
    Color(0xFFE5484D),
    Color(0xFFF2C14E),
    Color(0xFF3D7CC9),
    Color(0xFF4E9F6B),
    Color(0xFFF4EFE6),
    Color(0xFFE98A3A),
    Color(0xFF8E5BB5),
  ];

  void globos() {
    final h = size.height;
    for (var k = 0; k < s.path.length; k++) {
      final i = s.path[k];
      final o = _at(s.towns[i].x, 0, s.towns[i].z);
      if (o == null) continue;
      final m = _k(s.towns[i]).clamp(0.8, 1.5);
      for (var j = 0; j < 6; j++) {
        final a = t - (0.25 + 0.18 * k + 0.32 * j + hash01(i, j, 40) * 0.25);
        if (a < 0) continue;
        final vel = h * (0.085 + 0.045 * hash01(i, j, 41));
        final y = o.dy - 10 * m - vel * a - vel * 0.08 * a * a;
        if (y < -60) continue;
        final sway = math.sin(a * (1.4 + hash01(i, j, 42)) + j * 2.1);
        final x =
            o.dx +
            hashJitter(26 * m, i, j, 43) +
            sway * 10 +
            a * 9 * (hash01(i, j, 44) - 0.4);
        final lejos = ((o.dy - y) / h).clamp(0.0, 1.0);
        final w =
            (10.0 * m) * (1 - 0.5 * lejos) * (0.85 + 0.3 * hash01(i, j, 45));
        final alpha = _ease(a / 0.4) * _out * (1 - _ease((lejos - 0.65) / 0.3));
        if (alpha <= 0.01) continue;
        final col = _globoColores[(i * 3 + j) % _globoColores.length];
        final q = Offset(x, y);
        // El hilo, que cuelga y se mece al revés que el globo.
        final cuelga = Path()..moveTo(q.dx, q.dy + w * 1.15);
        for (var u = 1; u <= 6; u++) {
          final yy = q.dy + w * 1.15 + u * w * 0.55;
          cuelga.lineTo(
            q.dx - sway * u * 0.9 + math.sin(u * 1.3 + t * 3) * 1.2,
            yy,
          );
        }
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = const Color(0xFF3B3326).withValues(alpha: 0.7 * alpha);
        c.drawPath(cuelga, _paint);
        _paint.style = PaintingStyle.fill;
        // La sombra mínima, y el globo con su brillo.
        final cuerpo = Rect.fromCenter(
          center: q,
          width: w * 1.7,
          height: w * 2.1,
        );
        _paint
          ..color = const Color(0xFFFFFFFF)
          ..shader = Gradient.radial(
            q.translate(-w * 0.35, -w * 0.45),
            w * 1.6,
            [
              Color.lerp(
                col,
                const Color(0xFFFFFFFF),
                0.45,
              )!.withValues(alpha: alpha),
              col.withValues(alpha: alpha),
              Color.lerp(
                col,
                const Color(0xFF000000),
                0.25,
              )!.withValues(alpha: alpha),
            ],
            const [0, 0.5, 1],
          );
        c.drawOval(cuerpo, _paint);
        _paint.shader = null;
        // El nudo.
        final nudo = Path()
          ..moveTo(q.dx, q.dy + w * 1.0)
          ..lineTo(q.dx - w * 0.18, q.dy + w * 1.22)
          ..lineTo(q.dx + w * 0.18, q.dy + w * 1.22)
          ..close();
        _paint.color = Color.lerp(
          col,
          const Color(0xFF000000),
          0.2,
        )!.withValues(alpha: alpha);
        c.drawPath(nudo, _paint);
        _dot(
          q.translate(-w * 0.38, -w * 0.5),
          w * 0.18,
          const Color(0xFFFFFFFF),
          0.7 * alpha,
        );
      }
    }
  }

  // ------------------------------------------------------------------ fugaces

  void fugaces() {
    final noche = _window(t, 0, 1.0, length - 1.4, length);
    _night(noche * 0.9, reach: 1.0, tint: const Color(0xFF070B22));
    _stars(noche);
    final w = size.width, h = size.height;
    final n = s.towns.length;
    for (var i = 0; i < n; i++) {
      final a = t - Fiesta.fugazAt(i);
      if (a < -0.2) continue;
      // La plaza de su pueblo se ilumina un poco mientras pasa: es la suya.
      final town = s.towns[s.path[i]];
      final o = _at(town.x, 0, town.z);
      if (o != null) {
        _glow(
          o,
          36 * _k(town),
          const Color(0xFFCFE0FF),
          0.45 * _window(a, -0.1, 0.2, 0.6, 1.6) * noche,
        );
      }
      const vida = 1.0;
      if (a < 0 || a > vida) continue;
      final x0 = w * (0.25 + 0.75 * hash01(i, 50));
      final y0 = h * (0.03 + 0.16 * hash01(i, 51));
      final ang = math.pi * (0.78 + 0.08 * hash01(i, 52));
      final dir = Offset(math.cos(ang), math.sin(ang).abs() * 0.75 + 0.25);
      final d = dir / dir.distance;
      final vel = 430 + 160 * hash01(i, 53);
      final head = Offset(x0, y0) + d * vel * a;
      final cola = 150 + 90 * hash01(i, 54);
      final u = a / vida;
      final brillo = math.sin(math.pi * u.clamp(0.0, 1.0));
      final tail = head - d * cola * (0.4 + 0.6 * brillo);
      _paint
        ..color = const Color(0xFFFFFFFF)
        ..shader = Gradient.linear(tail, head, [
          const Color(0x00FFFFFF),
          const Color(0xFFE9F0FF).withValues(alpha: 0.95 * brillo),
        ])
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      c.drawLine(tail, head, _paint);
      _paint
        ..maskFilter = null
        ..strokeWidth = 1.4;
      c.drawLine(Offset.lerp(tail, head, 0.4)!, head, _paint);
      _paint
        ..shader = null
        ..style = PaintingStyle.fill;
      _glow(head, 22, const Color(0xFFDDE8FF), 0.8 * brillo);
      _dot(head, 2.6, const Color(0xFFFFFFFF), brillo);
    }
  }

  // --------------------------------------------------------------- luciérnagas

  void luciernagas() {
    final tarde = _window(t, 0, 1.4, length - 1.6, length);
    _night(tarde * 0.8, reach: 1.0, tint: const Color(0xFF0D1A2C));
    _stars(tarde * 0.5);
    for (var k = 0; k < s.path.length; k++) {
      final i = s.path[k];
      final town = s.towns[i];
      final o = _at(town.x, 0, town.z);
      if (o == null) continue;
      final m = _k(town).clamp(0.8, 1.8);
      for (var j = 0; j < 36; j++) {
        final a = t - (0.5 + 0.2 * k + hash01(i, j, 60) * 1.6);
        if (a < 0) continue;
        final ang = hash01(i, j, 61) * math.pi * 2;
        final rr = 0.35 + 0.65 * math.sqrt(hash01(i, j, 62));
        final bx = o.dx + math.cos(ang) * rr * 70 * m;
        final by = o.dy + math.sin(ang) * rr * 26 * m;
        final f1 = 0.4 + 0.5 * hash01(i, j, 63),
            f2 = 0.3 + 0.5 * hash01(i, j, 64);
        final q = Offset(
          bx + math.sin(a * f1 * 2 + j) * 12 * m,
          by - a * 5 * m + math.cos(a * f2 * 2 + j * 1.7) * 7 * m - 6 * m,
        );
        // Parpadean despacio, cada una a su ritmo, como las de verdad.
        final ritmo = 1.2 + 1.4 * hash01(i, j, 65);
        final pulso = math
            .pow(math.max(0, math.sin(a * ritmo + j * 2.3)), 2.5)
            .toDouble();
        final alpha = pulso * _ease(a / 0.8) * tarde;
        if (alpha <= 0.02) continue;
        _glow(q, 13 * math.min(m, 1.4), const Color(0xFFB6FF3C), 0.6 * alpha);
        _dot(q, 1.8 * math.min(m, 1.4), const Color(0xFFF2FFB0), alpha);
      }
    }
  }

  // --------------------------------------------------------------------- faros

  void faros() {
    final n = s.towns.length;
    final noche = _window(t, 0, 0.8, length - 1.2, length);
    _night(noche * 0.72, reach: 1.0, tint: const Color(0xFF0B1230));
    final fin = Fiesta.faroAt(n) + 0.1;
    final todos = _window(t, fin, fin + 0.25, fin + 0.6, fin + 1.6);
    for (var k = 0; k < n; k++) {
      final town = s.towns[s.path[k]];
      final o = _at(town.x, 0, town.z);
      if (o == null) continue;
      final a = t - Fiesta.faroAt(k);
      if (a < 0) continue;
      final m = _k(town).clamp(0.8, 1.6);
      final sube = _easeOut(a / 0.5);
      final alto = o.dy * sube;
      final flick = 0.9 + 0.1 * math.sin(t * 13 + k * 3);
      final fuerza =
          (0.75 + 0.6 * todos) * flick * _out * math.min(1, a / 0.15);
      final abajo = 9 * m, arriba = 26 * m;
      final haz = Path()
        ..moveTo(o.dx - abajo, o.dy)
        ..lineTo(o.dx - arriba, o.dy - alto)
        ..lineTo(o.dx + arriba, o.dy - alto)
        ..lineTo(o.dx + abajo, o.dy)
        ..close();
      _paint
        ..color = const Color(0xFFFFFFFF)
        ..blendMode = BlendMode.plus
        ..shader = Gradient.linear(
          o,
          o.translate(0, -math.max(1.0, alto)),
          [
            const Color(0xFFFFE6A0).withValues(alpha: 0.55 * fuerza),
            const Color(0xFFFFE6A0).withValues(alpha: 0.18 * fuerza),
            const Color(0x00FFE6A0),
          ],
          const [0, 0.5, 1],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      c.drawPath(haz, _paint);
      // El alma del haz, fina y blanca.
      _paint
        ..maskFilter = null
        ..shader = Gradient.linear(o, o.translate(0, -math.max(1.0, alto)), [
          const Color(0xFFFFFFFF).withValues(alpha: 0.8 * fuerza),
          const Color(0x00FFFFFF),
        ]);
      c.drawRect(
        Rect.fromLTRB(o.dx - 1.6 * m, o.dy - alto, o.dx + 1.6 * m, o.dy),
        _paint,
      );
      _paint
        ..shader = null
        ..blendMode = BlendMode.srcOver;
      _glow(o, 40 * m, _oro, 0.6 * fuerza);
      _glow(
        o,
        12 * m,
        const Color(0xFFFFFFFF),
        0.8 * fuerza * math.exp(-a * 3),
      );
    }
  }

  // ---------------------------------------------------------------------- mapa

  /// Una línea a mano: con su temblor, para que sea tinta y no regla.
  Path _aMano(List<Offset> pts, int seed, {double temblor = 1.4}) {
    final path = Path();
    for (var k = 0; k < pts.length; k++) {
      final q =
          pts[k] +
          Offset(
            hashJitter(temblor, seed, k, 1),
            hashJitter(temblor, seed, k, 2),
          );
      if (k == 0) {
        path.moveTo(q.dx, q.dy);
      } else {
        path.lineTo(q.dx, q.dy);
      }
    }
    return path;
  }

  void mapa() {
    final papel = _window(t, 0, 1.0, length - 1.3, length);
    // El papel: el valle se tiñe de pergamino, con los bordes tostados.
    // Primero se aclara, como un dibujo viejo y desvaído, y después se tiñe.
    _paint.color = const Color(0xFFF1E2BE).withValues(alpha: 0.55 * papel);
    c.drawRect(Offset.zero & size, _paint);
    _paint
      ..color = const Color(0xFFE6CF9C).withValues(alpha: 0.75 * papel)
      ..blendMode = BlendMode.multiply;
    c.drawRect(Offset.zero & size, _paint);
    _paint
      ..blendMode = BlendMode.srcOver
      ..color = const Color(0xFFFFFFFF)
      ..shader = Gradient.radial(
        size.center(Offset.zero),
        size.longestSide * 0.62,
        [
          const Color(0x00F3E6C4),
          const Color(0xFF7A5328).withValues(alpha: 0.5 * papel),
        ],
        const [0.55, 1],
      );
    c.drawRect(Offset.zero & size, _paint);
    _paint.shader = null;
    const tinta = Color(0xFF3B2614);
    final n = s.towns.length;
    final pies = [for (final i in s.path) _at(s.towns[i].x, 0, s.towns[i].z)];
    // Los caminos, a trazos, de pueblo en pueblo.
    for (var k = 0; k < n - 1; k++) {
      final a = pies[k], b = pies[k + 1];
      if (a == null || b == null) continue;
      final u = _ease((t - 0.8 - k * 0.45) / 0.7);
      if (u <= 0) continue;
      final d = b - a;
      final l = d.distance;
      if (l < 1) continue;
      final perp = Offset(-d.dy, d.dx) / l;
      final pts = <Offset>[];
      const pasos = 28;
      for (var j = 0; j <= pasos * u; j++) {
        final v = j / pasos;
        pts.add(
          a +
              d * v +
              perp * math.sin(v * math.pi) * l * 0.12 * (k.isEven ? 1 : -1),
        );
      }
      // A trazos: un tramo sí y otro no.
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..color = tinta.withValues(alpha: 0.85 * papel);
      for (var j = 0; j + 1 < pts.length; j += 2) {
        c.drawLine(pts[j], pts[j + 1], _paint);
      }
      _paint.style = PaintingStyle.fill;
    }
    // Un círculo a mano en cada pueblo, doble, como quien lo marca.
    for (var k = 0; k < n; k++) {
      final o = pies[k];
      if (o == null) continue;
      final u = _ease((t - 0.7 - k * 0.45) / 0.6);
      if (u <= 0) continue;
      final m = _k(s.towns[s.path[k]]);
      final r = 30 * m;
      for (var vuelta = 0; vuelta < 2; vuelta++) {
        final pts = <Offset>[];
        final giro = 0.3 + vuelta * 0.5;
        for (var j = 0; j <= 30 * u; j++) {
          final a = giro + j / 30 * math.pi * 2.15;
          final rr = r * (1 + 0.06 * vuelta + 0.04 * math.sin(a * 3 + k));
          pts.add(o + Offset(math.cos(a) * rr, math.sin(a) * rr * 0.62));
        }
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = vuelta == 0 ? 1.8 : 1.0
          ..color = tinta.withValues(alpha: (vuelta == 0 ? 0.85 : 0.5) * papel);
        c.drawPath(_aMano(pts, k * 7 + vuelta, temblor: 0.8), _paint);
      }
      _paint.style = PaintingStyle.fill;
    }
  }

  // ----------------------------------------------------------------- floración

  static const List<Color> _flores = [
    Color(0xFFF7A8C4),
    Color(0xFFFFFFFF),
    Color(0xFFF7D154),
    Color(0xFFB79CF0),
    Color(0xFFEF6B6B),
    Color(0xFFFFB86B),
  ];

  void floracion() {
    for (var k = 0; k < s.path.length; k++) {
      final i = s.path[k];
      final town = s.towns[i];
      final a = t - Fiesta.floraAt(k);
      if (a < 0) continue;
      final m = _k(town).clamp(0.7, 2.0);
      final o = _at(town.x, 0, town.z);
      if (o != null) {
        _glow(
          o,
          70 * m,
          const Color(0xFFFFF0B8),
          0.35 * _window(a, 0, 0.3, 0.6, 2.0),
        );
      }
      // El campo de alrededor, no el pueblo: las flores salen en el prado,
      // fuera de las casas, abriéndose en corro alrededor.
      const n = 46;
      for (var j = 0; j < n; j++) {
        final ang = hash01(i, j, 70) * math.pi * 2;
        final b = a - ang / (math.pi * 2) * 0.8;
        if (b < 0) continue;
        final rr = town.radius * (1.25 + 0.75 * hash01(i, j, 71));
        final q = _at(
          town.x + math.cos(ang) * rr,
          0,
          town.z + math.sin(ang) * rr,
        );
        if (q == null) continue;
        final abre = b < 0.5 ? _spring(b / 0.5) : 1.0;
        final sz = (1.3 + 0.8 * hash01(i, j, 72)) * math.min(m, 1.6) * abre;
        final col = _flores[(i + j * 5) % _flores.length];
        final alpha = _out;
        for (var p2 = 0; p2 < 5; p2++) {
          final pa = p2 / 5 * math.pi * 2 + j;
          _dot(
            q + Offset(math.cos(pa), math.sin(pa) * 0.7) * sz,
            sz * 0.7,
            col,
            alpha,
          );
        }
        _dot(q, sz * 0.45, const Color(0xFFF2B630), alpha);
      }
    }
  }

  double _spring(double x) {
    if (x <= 0) return 0;
    if (x >= 2.5) return 1;
    return 1 - math.exp(-5.5 * x) * math.cos(9 * x);
  }

  // -------------------------------------------------------------------- música

  void _nota(Offset q, double s0, bool doble, double alpha) {
    if (alpha <= 0.01) return;
    void dibuja(Offset o, Color col) {
      _paint.color = col;
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(-0.35);
      c.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: s0 * 1.25,
          height: s0 * 0.9,
        ),
        _paint,
      );
      c.restore();
      final tallo = Offset(o.dx + s0 * 0.55, o.dy);
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, s0 * 0.16);
      c.drawLine(tallo, tallo.translate(0, -s0 * 2.4), _paint);
      if (doble) {
        final o2 = o.translate(s0 * 1.6, -s0 * 0.4);
        final t2 = Offset(o2.dx + s0 * 0.55, o2.dy);
        c.drawLine(t2, t2.translate(0, -s0 * 2.4), _paint);
        _paint.strokeWidth = math.max(2, s0 * 0.42);
        c.drawLine(
          tallo.translate(0, -s0 * 2.3),
          t2.translate(0, -s0 * 2.3),
          _paint,
        );
        _paint.style = PaintingStyle.fill;
        c.save();
        c.translate(o2.dx, o2.dy);
        c.rotate(-0.35);
        c.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: s0 * 1.25,
            height: s0 * 0.9,
          ),
          _paint,
        );
        c.restore();
      } else {
        final top = tallo.translate(0, -s0 * 2.4);
        final bandera = Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(
            top.dx + s0 * 1.1,
            top.dy + s0 * 0.6,
            top.dx + s0 * 0.7,
            top.dy + s0 * 1.5,
          );
        c.drawPath(bandera, _paint);
      }
      _paint.style = PaintingStyle.fill;
    }

    dibuja(
      q.translate(1, 1.5),
      const Color(0xFF2B2118).withValues(alpha: 0.3 * alpha),
    );
    dibuja(q, const Color(0xFFFFF6E0).withValues(alpha: alpha));
  }

  void musica() {
    const pulso = 60 / 132;
    for (var k = 0; k < s.path.length; k++) {
      final i = s.path[k];
      final town = s.towns[i];
      final o = _at(town.x, 0, town.z);
      if (o == null) continue;
      final m = _k(town).clamp(0.8, 1.6);
      for (var j = 0; j < 16; j++) {
        final born = 0.3 + 0.12 * k + j * pulso * 0.9 + hash01(i, j, 80) * 0.15;
        if (born > length - 2.2) break;
        final a = t - born;
        if (a < 0 || a > 2.8) continue;
        final lado = j.isEven ? 1 : -1;
        // Se mecen al compás: un lado en cada pulso.
        final vaiven = math.sin((t / pulso) * math.pi) * 6 * m;
        final q =
            o +
            Offset(
              lado * (8 + 14 * hash01(i, j, 81)) * m + vaiven + a * lado * 6,
              -14 * m - a * 34 * m,
            );
        final latido = 1 + 0.12 * math.pow(math.cos((t / pulso) * math.pi), 8);
        final alpha = _ease(a / 0.3) * (1 - _ease((a - 2.0) / 0.8)) * _out;
        _nota(q, 4.2 * m * latido, j % 3 == 1, alpha);
      }
    }
  }

  // ------------------------------------------------------------------ hogueras

  void hogueras() {
    final noche = _window(t, 0, 1.2, length - 1.4, length);
    _night(noche * 0.85, reach: 1.0, tint: const Color(0xFF0C0A1E));
    _stars(noche * 0.8);
    for (var k = 0; k < s.path.length; k++) {
      final i = s.path[k];
      final town = s.towns[i];
      final o = _at(town.x, 0, town.z);
      if (o == null) continue;
      final a = t - (0.4 + 0.3 * k);
      if (a < 0) continue;
      final m = _k(town).clamp(0.8, 1.8);
      final prende = _easeOut(a / 0.9) * _out;
      // La luz del fuego sobre la plaza.
      _paint
        ..color = const Color(0xFFFFFFFF)
        ..blendMode = BlendMode.plus;
      _glow(
        o,
        90 * m * (0.9 + 0.1 * math.sin(t * 9 + k)),
        const Color(0xFFFF8A3D),
        0.5 * prende,
      );
      _paint.blendMode = BlendMode.srcOver;
      // Los leños.
      _paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.6 * m
        ..color = const Color(
          0xFF3A2414,
        ).withValues(alpha: math.min(1, a * 3) * _out);
      c.drawLine(
        o.translate(-8 * m, 2 * m),
        o.translate(7 * m, -3 * m),
        _paint,
      );
      c.drawLine(
        o.translate(8 * m, 2 * m),
        o.translate(-7 * m, -3 * m),
        _paint,
      );
      _paint.style = PaintingStyle.fill;
      // Las llamas: tres capas que tiemblan cada una a su ritmo.
      for (final (capa, col, ancho, alto) in [
        (0, const Color(0xFFD9381E), 11.0, 30.0),
        (1, const Color(0xFFFF8A2A), 8.0, 23.0),
        (2, const Color(0xFFFFD66B), 4.6, 13.0),
      ]) {
        final tiembla =
            1 +
            0.18 * math.sin(t * (11 + capa * 3) + i) +
            0.1 * math.sin(t * 23 + capa);
        final w = ancho * m * prende, hh = alto * m * prende * tiembla;
        final lean = math.sin(t * 2.3 + i) * 2.5 * m;
        final llama = Path()
          ..moveTo(o.dx - w, o.dy - 2 * m)
          ..quadraticBezierTo(
            o.dx - w * 0.9,
            o.dy - hh * 0.55,
            o.dx + lean,
            o.dy - hh,
          )
          ..quadraticBezierTo(
            o.dx + w * 0.9,
            o.dy - hh * 0.55,
            o.dx + w,
            o.dy - 2 * m,
          )
          ..close();
        _paint
          ..color = col.withValues(alpha: 0.92)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            capa == 0 ? 2.5 : 1.2,
          );
        c.drawPath(llama, _paint);
      }
      _paint.maskFilter = null;
      // Las brasas que suben al cielo.
      for (var j = 0; j < 22; j++) {
        final life = 1.6 + 1.2 * hash01(i, j, 90);
        final b = (a - hash01(i, j, 91) * 2.2) % (life + 0.4);
        if (b < 0 || b > life || a < 0.3) continue;
        final q =
            o +
            Offset(
              hashJitter(6 * m, i, j, 92) + math.sin(b * 3 + j) * 8 * m,
              -20 * m - b * (40 + 30 * hash01(i, j, 93)) * m,
            );
        final u = b / life;
        final col = Color.lerp(
          const Color(0xFFFFE08A),
          const Color(0xFFFF5A1F),
          u,
        )!;
        _glow(q, 5 * m, col, 0.5 * (1 - u) * _out);
        _dot(q, 1.1 * math.min(m, 1.4), col, (1 - u) * _out);
      }
    }
  }

  // -------------------------------------------------------------------- pompas

  void pompas() {
    for (var k = 0; k < s.path.length; k++) {
      final i = s.path[k];
      final town = s.towns[i];
      final o = _at(town.x, 0, town.z);
      if (o == null) continue;
      final m = _k(town).clamp(0.8, 1.7);
      for (var j = 0; j < 16; j++) {
        final born = 0.3 + 0.15 * k + hash01(i, j, 100) * (length - 3.2);
        final life = 2.0 + 1.6 * hash01(i, j, 101);
        final a = t - born;
        if (a < 0 || a > life + 0.3) continue;
        final r = (5 + 8 * hash01(i, j, 102)) * m;
        final q =
            o +
            Offset(
              hashJitter(30 * m, i, j, 103) +
                  math.sin(a * 1.7 + j) * 12 * m +
                  a * 10,
              -12 * m - a * (24 + 18 * hash01(i, j, 104)) * m,
            );
        if (a > life) {
          // Revienta: un aro que se abre y unas gotitas.
          final u = (a - life) / 0.3;
          _paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(
              0xFFFFFFFF,
            ).withValues(alpha: (1 - u) * 0.8 * _out);
          c.drawCircle(q, r * (1 + u * 0.6), _paint);
          _paint.style = PaintingStyle.fill;
          for (var g = 0; g < 5; g++) {
            final ga = g / 5 * math.pi * 2 + j;
            _dot(
              q + Offset(math.cos(ga), math.sin(ga)) * r * (1.2 + u),
              1.0,
              const Color(0xFFFFFFFF),
              (1 - u) * _out,
            );
          }
          continue;
        }
        final alpha = _ease(a / 0.3) * _out;
        // El brillo irisado: un barrido de colores pastel muy transparentes,
        // que gira despacio. Se gira el lienzo y no el barrido: con ángulos
        // fuera de la vuelta, el motor de la web no pinta el cuadro.
        c.save();
        c.translate(q.dx, q.dy);
        c.rotate((a * 2 + j) % (math.pi * 2));
        _paint
          ..color = const Color(0xFFFFFFFF)
          ..shader = Gradient.sweep(
            Offset.zero,
            [
              const Color(0xFFFFB3D9).withValues(alpha: 0.28 * alpha),
              const Color(0xFFB3E5FF).withValues(alpha: 0.22 * alpha),
              const Color(0xFFD9FFB3).withValues(alpha: 0.26 * alpha),
              const Color(0xFFFFE6B3).withValues(alpha: 0.22 * alpha),
              const Color(0xFFFFB3D9).withValues(alpha: 0.28 * alpha),
            ],
            const [0, 0.25, 0.5, 0.75, 1],
          );
        c.drawCircle(Offset.zero, r, _paint);
        _paint.shader = null;
        c.restore();
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.65 * alpha);
        c.drawCircle(q, r, _paint);
        // El reflejo de la ventana, arriba a la izquierda.
        _paint
          ..strokeWidth = 1.6
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85 * alpha);
        c.drawArc(
          Rect.fromCircle(center: q, radius: r * 0.7),
          math.pi * 1.1,
          0.7,
          false,
          _paint,
        );
        _paint.style = PaintingStyle.fill;
      }
    }
  }

  // ------------------------------------------------------------------- fuentes

  void fuentes() {
    for (var k = 0; k < s.path.length; k++) {
      final i = s.path[k];
      final town = s.towns[i];
      final o = _at(town.x, 0, town.z);
      if (o == null) continue;
      final m = _k(town).clamp(0.9, 1.9);
      final a = t - (0.2 + 0.08 * k);
      if (a < 0) continue;
      const dura = 3.2;
      // La neblina del chorro, celeste.
      final niebla = _window(a, 0, 0.4, dura, dura + 0.9) * _out;
      _glow(
        o.translate(0, -50 * m),
        58 * m,
        const Color(0xFFBFE6FF),
        0.32 * niebla,
      );
      // Un ramillete: un chorro alto en el medio y arcos que se abren
      // alrededor, como las fuentes de las plazas grandes.
      for (var j = 0; j < 150; j++) {
        final arco = j % 3 != 0;
        final alto =
            (arco
                ? 62 + 30 * hash01(i, j, 114)
                : 128 + 22 * hash01(i, j, 115)) *
            m;
        const sube = 0.55;
        final g = 2 * alto / (sube * sube);
        final v0 = g * sube;
        final born = hash01(i, j, 110) * dura;
        final b = a - born;
        final vida = 2 * sube * (arco ? 1.0 : 0.92);
        if (b < 0 || b > vida) continue;
        final ang = hash01(i, j, 112) * math.pi * 2;
        final abre = arco ? (34 + 18 * hash01(i, j, 113)) * m : 5 * m;
        final vx = math.cos(ang) * abre / vida;
        final vz = math.sin(ang) * abre * 0.35 / vida;
        Offset en(double bb) =>
            o + Offset(vx * bb, -v0 * bb + 0.5 * g * bb * bb + vz * bb - 4 * m);
        final q = en(b), q0 = en(math.max(0, b - 0.045));
        final glint = math.sin(b * 31 + j) > 0.6 ? 1.0 : 0.7;
        final col = Color.lerp(
          const Color(0xFFFFFFFF),
          const Color(0xFF9FD4FF),
          hash01(i, j, 116) * 0.6,
        )!;
        _paint
          ..color = col.withValues(alpha: 0.9 * glint * _out)
          ..strokeWidth = (arco ? 1.6 : 2.2) * math.min(m, 1.5)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        c.drawLine(q0, q, _paint);
        _paint.style = PaintingStyle.fill;
        if (glint > 0.9) {
          _glow(q, 4 * m, const Color(0xFFFFFFFF), 0.4 * _out);
        }
      }
      // Y la salpicadura en el pilón.
      if (a > 0.5 && a < dura + 1.0) {
        for (var w = 0; w < 3; w++) {
          final u = ((a * 1.4 + w / 3) % 1.0);
          _ringPx(
            town,
            (10 + 40 * u) * m,
            1.4,
            const Color(0xFFEAF7FF),
            (1 - u) * 0.75 * _out,
          );
        }
      }
    }
  }

  // --------------------------------------------------------------------- ronda

  /// Un tramo de hilo de oro, de la plaza [a] a la [b], tendido hasta
  /// [head] (de 0 a 1), con [pulso] de brillo de más.
  void _tramo(
    FiestaTown a,
    FiestaTown b,
    double head,
    double pulso,
    double fade,
  ) {
    if (head <= 0 || fade <= 0) return;
    final pts = <Offset>[];
    const steps = 40;
    for (var j = 0; j <= steps; j++) {
      final w = _thread(a, b, head * j / steps);
      final q = _at(w.x, w.y, w.z);
      if (q != null) pts.add(q);
    }
    if (pts.length < 2) return;
    final path = Path()..addPolygon(pts, false);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10 + 6 * pulso
      ..color = _oro.withValues(alpha: 0.22 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    c.drawPath(path, _paint);
    _paint
      ..strokeWidth = 2.0 + 1.2 * pulso
      ..color = _oroClaro.withValues(alpha: fade)
      ..maskFilter = null;
    c.drawPath(path, _paint);
    _paint.style = PaintingStyle.fill;
    if (head < 1) {
      _glow(pts.last, 18, _oro, 0.85 * fade);
      _dot(pts.last, 2.8, const Color(0xFFFFFFFF), fade);
    }
  }

  void ronda() {
    final n = s.towns.length;
    final fin = Fiesta.rondaFin(n);
    // Al encenderse todos, el hilo entero late una vez.
    final pulso = _window(t, fin, fin + 0.3, fin + 0.6, fin + 2.0);
    // El hilo: un tramo por viaje, que se tiende a la par de la cámara y se
    // queda, así desde el valle se ve el recorrido entero.
    for (var k = 1; k < n; k++) {
      final a = s.towns[s.path[k - 1]], b = s.towns[s.path[k]];
      // Al terminar no se apaga: se queda en el brillo del hilo del día, que
      // sigue tendido después (ver [paintHiloDelDia]).
      _tramo(
        a,
        b,
        Fiesta.rondaTravel(k, t),
        pulso,
        _hiloBrillo + (1 - _hiloBrillo) * _out,
      );
    }
    for (var k = 0; k < n; k++) {
      final town = s.towns[s.path[k]];
      final a = t - Fiesta.rondaArrive(k);
      if (a < 0) continue;
      final o = _at(town.x, 0, town.z);
      if (o == null) continue;
      final m = _k(town);
      // Al llegar, la plaza se enciende y queda una luz cálida.
      final luz = _window(a, 0, 0.3, 1.0, 2.4) * 0.32 + 0.1 + 0.3 * pulso;
      _glow(o, 55 * math.min(m, 1.6), const Color(0xFFFFD27A), luz * _out);
      if (a < 1.6) {
        _ringPx(
          town,
          (12 + 70 * _easeOut(a / 1.6)) * m,
          2.2,
          _oroClaro,
          (1 - a / 1.6) * _out,
        );
      }
      _fuente(town, k + 300, a - 0.05, 0.5, 0.8);
    }
    // Y al final, desde arriba, todas a la vez.
    for (final town in s.towns) {
      final a = t - fin;
      if (a < 0 || a > 2.4) continue;
      _ringPx(
        town,
        (14 + 90 * _easeOut(a / 2.4)) * _k(town),
        2.6,
        _oro,
        (1 - a / 2.4) * _out,
      );
    }
  }

  /// El hilo del día. Ver [paintHiloDelDia].
  void hiloQuieto() {
    final n = s.towns.length;
    if (n < 2) return;
    // Respira muy despacio, para que se vea que está vivo sin llamar la
    // atención.
    final respira = _hiloBrillo * (0.88 + 0.12 * math.sin(t * 0.8));
    for (var k = 1; k < n; k++) {
      _tramo(s.towns[s.path[k - 1]], s.towns[s.path[k]], 1, 0, respira);
    }
    // Y una chispa que lo recorre entero cada tanto, de tu pueblo al último.
    const vuelta = 9.0, viaje = 3.2;
    final fase = t % vuelta;
    if (fase > viaje) return;
    final pos = fase / viaje * (n - 1);
    final k = pos.floor().clamp(0, n - 2);
    final w = _thread(s.towns[s.path[k]], s.towns[s.path[k + 1]], pos - k);
    final q = _at(w.x, w.y, w.z);
    if (q == null) return;
    final brillo = math.sin(math.pi * fase / viaje);
    _glow(q, 14, _oro, 0.7 * brillo);
    _dot(q, 2.2, const Color(0xFFFFFFFF), brillo);
  }
}
