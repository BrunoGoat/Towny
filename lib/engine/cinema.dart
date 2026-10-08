import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/math3.dart';
import 'palette.dart';
import 'town.dart';

/// La calidad máxima: lo que se le hace al cuadro cuando ya está pintado.
///
/// El pueblo se pinta igual que siempre, pero en una grabación en vez de en la
/// pantalla, y esa grabación pasa por aquí antes de llegar. Cuatro cosas, y
/// las cuatro son de cámara y no de pueblo:
///
/// * **El color.** Una corrección por hora: el mediodía más vivo, la hora
///   dorada más dorada, la noche más azul y con más contraste.
/// * **El resplandor.** Lo que brilla sangra luz alrededor: las ventanas de
///   noche, el sol, la luna, la nieve con el sol encima.
/// * **Los rayos.** Con el sol bajo, la luz que pasa entre los montes y los
///   tejados se ve en el aire. Salen del propio cuadro —de lo que es claro
///   cerca del sol— así que un monte o una torre delante los corta.
/// * **El viñeteado y los reflejos de la lente** cuando el sol está en cuadro.
///
/// Todo con lo que el lienzo ya sabe hacer —capas, filtros de color, desenfoque
/// y una copia del cuadro a un cuarto de tamaño— y nada de sombreadores: así
/// se ve igual en la web, en el teléfono y en los tests.
class Cinema {
  Cinema(this.pal, this.p, this.size);

  final Palette pal;
  final Projector p;
  final Size size;

  /// A qué tamaño se hace la copia de la que salen el resplandor y los rayos.
  /// Las dos cosas se desenfocan después, así que un cuarto no se nota y cuesta
  /// la dieciseisava parte.
  static const double _small = 0.25;

  /// Cuánto de hora dorada hay ahora: sol fuera pero bajo.
  double get golden {
    final s = pal.sunDir.y;
    if (s < -0.06) return 0;
    return (1 - smoothstep(0.04, 0.42, s)) * smoothstep(-0.06, 0.02, s);
  }

  /// Cuánto de noche: lo contrario de [Palette.daylight].
  double get night => 1 - pal.daylight;

  /// Dónde está el sol —o la luna— en la pantalla, si está delante.
  Offset? get _light {
    final d = pal.isDaylight ? pal.sunDir : pal.moonDir;
    final den = d.dot(p.forward);
    if (den <= 0.05) return null;
    return Offset(
      p.cx + p.focal * d.dot(p.right) / den,
      p.cy - p.focal * d.dot(p.up) / den,
    );
  }

  void compose(Canvas canvas, ui.Picture world) {
    final rect = Offset.zero & size;

    // El cuadro, corregido de color.
    canvas.saveLayer(
      rect,
      Paint()..colorFilter = ColorFilter.matrix(grade(pal)),
    );
    canvas.drawPicture(world);
    canvas.restore();

    // La copia chica, y de ella el resplandor y los rayos, hechos también en
    // chico. Lo caro de los dos es desenfocar y repetir el cuadro, y a un
    // cuarto de lado eso es la dieciseisava parte de píxeles; al ampliarlo
    // después, como ya está desenfocado, no se nota.
    final w = math.max(1, (size.width * _small).round());
    final h = math.max(1, (size.height * _small).round());
    final chico = Size(w.toDouble(), h.toDouble());
    final small = _record(w, h, (c) {
      c
        ..scale(w / size.width, h / size.height)
        ..drawPicture(world);
    });
    final src = Offset.zero & chico;
    final luz = Paint()
      ..blendMode = BlendMode.plus
      ..filterQuality = FilterQuality.medium;

    final brillo = _record(w, h, (c) => _bloom(c, small));
    canvas.drawImageRect(brillo, src, rect, luz);
    brillo.dispose();

    if (_raysWanted) {
      final rayos = _record(w, h, (c) => _rays(c, small, chico));
      canvas.drawImageRect(rayos, src, rect, luz);
      rayos.dispose();
    }
    small.dispose();

    _flare(canvas);
    _vignette(canvas, rect);
  }

  /// Pinta en un lienzo de [w]×[h] y lo devuelve hecho imagen.
  static ui.Image _record(int w, int h, void Function(Canvas) draw) {
    final rec = ui.PictureRecorder();
    draw(Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble())));
    final pic = rec.endRecording();
    final img = pic.toImageSync(w, h);
    pic.dispose();
    return img;
  }

  // ------------------------------------------------------------ resplandor

  /// Sobre el lienzo chico: lo claro, desenfocado a tres radios y sumado.
  void _bloom(Canvas c, ui.Image small) {
    // De noche brilla casi todo lo encendido; de día sólo lo que deslumbra.
    // Y de noche el umbral no baja: una pared alumbrada por su ventana ya es
    // casi tan clara como la ventana, y si brilla todo no brilla nada.
    final umbral = lerpD(0.80, 0.82, night);
    final fuerza =
        lerpD(0.42, 0.70, night) + (pal.isDaylight ? golden * 0.3 : 0.0);
    final tinte = Color.lerp(
      const Color(0xFFFFF4E0),
      const Color(0xFFFFD9A0),
      math.max(golden, night * 0.6),
    )!;
    for (final (sigma, k) in [(5.0, 0.55), (18.0, 0.65), (46.0, 0.5)]) {
      final s = sigma * _small;
      c.drawImage(
        small,
        Offset.zero,
        Paint()
          ..blendMode = BlendMode.plus
          ..imageFilter = ui.ImageFilter.compose(
            outer: ui.ImageFilter.blur(
              sigmaX: s,
              sigmaY: s,
              tileMode: TileMode.decal,
            ),
            inner: ColorFilter.matrix(threshold(umbral, fuerza * k, tinte)),
          ),
      );
    }
  }

  // ----------------------------------------------------------------- rayos

  /// Si hay sol delante, o cerca, para echar rayos.
  bool get _raysWanted {
    // Sólo del sol. De noche lo único claro cerca de la luna son las casas
    // encendidas, y unos rayos saliendo de un tejado son un fallo.
    if (!pal.isDaylight) return false;
    final sol = _light;
    if (sol == null) return false;
    final lejos = size.longestSide;
    return sol.dx > -lejos * 0.6 &&
        sol.dx < size.width + lejos * 0.6 &&
        sol.dy > -lejos * 0.6 &&
        sol.dy < size.height + lejos * 0.4;
  }

  /// Sobre el lienzo chico: el cuadro repetido catorce veces, cada vez un poco
  /// más grande alrededor del sol, quedándose sólo con lo claro. Lo que tapa
  /// el sol —un monte, una torre— sale oscuro en todas las copias, y eso es
  /// la sombra que corta el rayo.
  void _rays(Canvas c, ui.Image small, Size chico) {
    final sol = _light! * _small;
    // Con el sol alto los rayos casi no se ven.
    final cuanto = 0.30 + golden * 1.1;
    final luz = Color.lerp(pal.sun, const Color(0xFFFFA650), golden * 0.7)!;
    final umbral = lerpD(0.62, 0.45, golden);
    final todo = Offset.zero & chico;

    c.saveLayer(
      todo,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: 1,
          sigmaY: 1,
          tileMode: TileMode.decal,
        ),
    );
    const pasos = 14;
    final pinta = Paint()
      ..blendMode = BlendMode.plus
      ..filterQuality = FilterQuality.medium;
    for (var k = 0; k < pasos; k++) {
      final s = 1.0 + k * 0.055;
      final peso = cuanto * 0.16 * math.pow(0.86, k);
      pinta.colorFilter = ColorFilter.matrix(threshold(umbral, peso, luz));
      c
        ..save()
        ..translate(sol.dx, sol.dy)
        ..scale(s)
        ..translate(-sol.dx, -sol.dy)
        ..drawImage(small, Offset.zero, pinta)
        ..restore();
    }
    // Lo que queda lejos del sol no es un rayo, es el cielo entero brillando.
    c.drawRect(
      todo,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.radial(
          sol,
          chico.longestSide * 0.9,
          [
            const Color(0xFFFFFFFF),
            const Color(0x66FFFFFF),
            const Color(0x00FFFFFF),
          ],
          [0.0, 0.35, 1.0],
        ),
    );
    c.restore();
  }

  // ------------------------------------------------------------------ lente

  void _flare(Canvas canvas) {
    if (!pal.isDaylight) return;
    final sol = _light;
    if (sol == null) return;
    if (sol.dx < 0 || sol.dx > size.width || sol.dy < 0) return;
    if (sol.dy > size.height) return;
    // Pegado al horizonte el sol suele estar detrás de un monte, y un reflejo
    // de algo tapado delata el truco.
    final a = smoothstep(0.06, 0.24, pal.sunDir.y) * (0.55 + golden * 0.45);
    if (a < 0.02) return;
    final centro = size.center(Offset.zero);
    final eje = centro - sol;
    final base = size.shortestSide;
    final tinte = Color.lerp(pal.sun, const Color(0xFFFF9A4D), golden)!;
    for (final (t, r, alfa, color) in [
      (0.35, 0.030, 0.10, tinte),
      (0.62, 0.060, 0.06, const Color(0xFF9FD8FF)),
      (1.10, 0.022, 0.12, tinte),
      (1.42, 0.110, 0.045, const Color(0xFFB4FFC8)),
      (1.80, 0.045, 0.07, const Color(0xFFFFB4E6)),
    ]) {
      final at = sol + eje * t;
      final rr = base * r;
      canvas.drawCircle(
        at,
        rr,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(
            at,
            rr,
            [
              color.withValues(alpha: alfa * a),
              color.withValues(alpha: alfa * a * 0.6),
              color.withValues(alpha: 0),
            ],
            [0.0, 0.7, 1.0],
          ),
      );
    }
    // Y el destello del propio sol: una estrella de seis puntas muy floja.
    final largo = base * (0.22 + golden * 0.18);
    for (var i = 0; i < 3; i++) {
      final ang = i * math.pi / 3 + 0.3;
      final d = Offset(math.cos(ang), math.sin(ang)) * largo;
      canvas.drawLine(
        sol - d,
        sol + d,
        Paint()
          ..blendMode = BlendMode.plus
          ..strokeWidth = 1.6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)
          ..shader = ui.Gradient.linear(
            sol - d,
            sol + d,
            [
              tinte.withValues(alpha: 0),
              tinte.withValues(alpha: 0.35 * a),
              tinte.withValues(alpha: 0),
            ],
            [0.0, 0.5, 1.0],
          ),
      );
    }
  }

  void _vignette(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          size.longestSide * 0.78,
          [
            const Color(0x00000000),
            const Color(0x00000000),
            Color.fromRGBO(0, 0, 0, 0.30 + night * 0.14),
          ],
          [0.0, 0.5, 1.0],
        ),
    );
  }

  // ------------------------------------------------------------- las cuentas

  /// La corrección de color de esta hora, como matriz de 4×5 de las de
  /// [ColorFilter.matrix]: saturación, contraste y tinte, en ese orden.
  static List<double> grade(Palette pal) {
    final g = Cinema._goldenOf(pal);
    final n = 1 - pal.daylight;
    final sat = lerpD(1.16, 0.92, n) + g * 0.14;
    final con = lerpD(1.10, 1.16, n) + g * 0.04;
    // El tinte: a la hora dorada se calienta, de noche se va al azul.
    final r = 1.0 + g * 0.08 - n * 0.10;
    final gg = 1.0 + g * 0.01 - n * 0.03;
    final b = 1.0 - g * 0.12 + n * 0.10;
    // Y de noche las sombras se levantan un poco hacia el azul en vez de
    // hundirse en negro.
    final lift = n * 6.0;
    var m = saturation(sat);
    m = mul(contrast(con), m);
    m = mul(<double>[
      r, 0, 0, 0, lift * 0.3, //
      0, gg, 0, 0, lift * 0.6,
      0, 0, b, 0, lift * 1.4,
      0, 0, 0, 1, 0,
    ], m);
    return m;
  }

  static double _goldenOf(Palette pal) {
    final s = pal.sunDir.y;
    if (s < -0.06) return 0;
    return (1 - smoothstep(0.04, 0.42, s)) * smoothstep(-0.06, 0.02, s);
  }

  /// Lo que pasa de [umbral] para arriba, multiplicado por [gain] y teñido de
  /// [tint]; lo demás, negro. Opaco siempre, porque se suma.
  static List<double> threshold(double umbral, double gain, Color tint) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    // Escala para que lo que esté en blanco salga con [gain].
    final k = gain / math.max(0.05, 1 - umbral);
    final off = -umbral * 255 * k;
    final tr = tint.r, tg = tint.g, tb = tint.b;
    // Mitad luminancia y mitad color propio: una ventana amarilla tiene que
    // dar luz amarilla, no blanca.
    List<double> fila(double t, int canal) {
      final propio = [0.0, 0.0, 0.0];
      propio[canal] = 0.5;
      return [
        k * t * (lr * 0.5 + propio[0]),
        k * t * (lg * 0.5 + propio[1]),
        k * t * (lb * 0.5 + propio[2]),
        0,
        off * t,
      ];
    }

    return [...fila(tr, 0), ...fila(tg, 1), ...fila(tb, 2), 0, 0, 0, 0, 255];
  }

  static List<double> saturation(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final i = 1 - s;
    return [
      lr * i + s, lg * i, lb * i, 0, 0, //
      lr * i, lg * i + s, lb * i, 0, 0,
      lr * i, lg * i, lb * i + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> contrast(double c) {
    final o = 128 * (1 - c);
    return [
      c, 0, 0, 0, o, //
      0, c, 0, 0, o,
      0, 0, c, 0, o,
      0, 0, 0, 1, 0,
    ];
  }

  /// `a × b` de dos matrices de color, cada una con la quinta fila implícita
  /// `0 0 0 0 1`: primero se aplica `b`, después `a`.
  static List<double> mul(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 5; j++) {
        var s = j == 4 ? a[i * 5 + 4] : 0.0;
        for (var k = 0; k < 4; k++) {
          s += a[i * 5 + k] * b[k * 5 + j];
        }
        out[i * 5 + j] = s;
      }
    }
    return out;
  }
}

// --------------------------------------------------------------- las sombras

/// Las sombras de verdad: cada pieza echa la suya sobre el prado, en la
/// dirección contraria al sol.
///
/// Largas al amanecer y al atardecer, cortas a mediodía, y girando con la hora.
/// De noche las echa la luna, más flojas y azules. La de cada pieza es la
/// envolvente de sus vértices llevados al suelo a lo largo de la luz —que es
/// la sombra exacta de un sólido convexo— y todas van en un solo trazado, así
/// que donde dos se pisan no se oscurece el doble.
void drawCastShadows(
  Canvas canvas,
  Projector p,
  Palette pal,
  Iterable<(TownLayout, int)> towns,
) {
  final dia = pal.isDaylight;
  final fuerza = dia
      ? 0.56 * smoothstep(0.02, 0.20, pal.sunDir.y)
      : 0.20 * smoothstep(0.2, 0.8, 1 - pal.daylight);
  if (fuerza < 0.01) return;
  final l = pal.lightDir;
  final ly = math.max(l.y, 0.10);
  final ox = -l.x / ly, oz = -l.z / ly;

  final path = Path();
  final xs = Float64List(40), zs = Float64List(40);
  for (final (town, take) in towns) {
    final n = math.min(take, town.pieces.length);
    for (var i = 0; i < n; i++) {
      final pc = town.pieces[i];
      if (pc.y1 <= 0.02) continue;
      var m = 0;
      void at(double x, double y, double z) {
        xs[m] = x + ox * y;
        zs[m] = z + oz * y;
        m++;
      }

      void box(double y) {
        at(pc.x0, y, pc.z0);
        at(pc.x1, y, pc.z0);
        at(pc.x1, y, pc.z1);
        at(pc.x0, y, pc.z1);
      }

      switch (pc.kind) {
        case PieceKind.field:
        case PieceKind.water:
          continue;
        case PieceKind.roof:
        case PieceKind.thatch:
          box(pc.y0);
          if (pc.alongX) {
            at(pc.x0, pc.y1, pc.cz);
            at(pc.x1, pc.y1, pc.cz);
          } else {
            at(pc.cx, pc.y1, pc.z0);
            at(pc.cx, pc.y1, pc.z1);
          }
        case PieceKind.spire:
          box(pc.y0);
          at(pc.cx, pc.y1, pc.cz);
        case PieceKind.dome:
        case PieceKind.tree:
          final mid = pc.y0 + (pc.y1 - pc.y0) * 0.5;
          final rx = pc.w / 2, rz = pc.d / 2;
          at(pc.cx, pc.y0, pc.cz);
          for (var k = 0; k < 10; k++) {
            final a = k * math.pi / 5;
            at(pc.cx + math.cos(a) * rx, mid, pc.cz + math.sin(a) * rz);
          }
          at(pc.cx, pc.y1, pc.cz);
        default:
          box(pc.y0);
          box(pc.y1);
      }
      _hullInto(path, p, xs, zs, m);
    }
  }
  final sombra = Color.lerp(pal.ink, pal.skyTop, dia ? 0.30 : 0.45)!;
  canvas.drawPath(
    path,
    Paint()
      ..color = sombra.withValues(alpha: fuerza)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
  );
}

final Float64List _hx = Float64List(84), _hz = Float64List(84);

/// La envolvente convexa (cadena monótona) de los puntos del suelo, proyectada
/// y añadida al trazado. Siempre en el mismo sentido, para que la unión de
/// todas sea una unión y no se resten.
void _hullInto(Path path, Projector p, Float64List xs, Float64List zs, int n) {
  if (n < 3) return;
  final idx = List<int>.generate(n, (i) => i)
    ..sort((a, b) {
      final c = xs[a].compareTo(xs[b]);
      return c != 0 ? c : zs[a].compareTo(zs[b]);
    });
  double cross(int o, int a, double x, double z) =>
      (_hx[a] - _hx[o]) * (z - _hz[o]) - (_hz[a] - _hz[o]) * (x - _hx[o]);
  var k = 0;
  void add(int i, int floor) {
    final x = xs[i], z = zs[i];
    while (k >= floor && cross(k - 2, k - 1, x, z) <= 0) {
      k--;
    }
    _hx[k] = x;
    _hz[k] = z;
    k++;
  }

  for (final i in idx) {
    add(i, 2);
  }
  final lower = k + 1;
  for (var j = idx.length - 2; j >= 0; j--) {
    add(idx[j], lower);
  }
  k--; // el último repite el primero
  if (k < 3) return;
  for (var i = 0; i < k; i++) {
    final s = p.project(V3(_hx[i], 0.005, _hz[i]));
    if (s == null) return;
    _sx[i] = s.x;
    _sy[i] = s.y;
  }
  path.moveTo(_sx[0], _sy[0]);
  for (var i = 1; i < k; i++) {
    path.lineTo(_sx[i], _sy[i]);
  }
  path.close();
}

final Float64List _sx = Float64List(84), _sy = Float64List(84);
