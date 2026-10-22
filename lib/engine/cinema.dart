import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';

import '../core/math3.dart';
import 'fountain.dart';
import 'palette.dart';
import 'render_debug.dart';
import 'solid.dart';
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
/// y capas a un cuarto de tamaño— y nada de sombreadores ni copias del cuadro: así
/// se ve igual en la web, en el teléfono y en los tests.
class Cinema {
  Cinema(this.pal, this.p, this.size);

  final Palette pal;
  final Projector p;
  final Size size;

  /// A qué tamaño se hacen el resplandor y los rayos. Las dos cosas se
  /// desenfocan después, así que un cuarto no se nota y cuesta la dieciseisava
  /// parte.
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
    final dbg = RenderDebug.instance;

    // El cuadro, corregido de color.
    if (dbg.grade) {
      canvas.saveLayer(
        rect,
        Paint()..colorFilter = ColorFilter.matrix(grade(pal)),
      );
      canvas.drawPicture(world);
      canvas.restore();
    } else {
      canvas.drawPicture(world);
    }

    // El resplandor y los rayos, hechos en chico y ampliados.
    //
    // **Sin sacar una imagen del cuadro.** Se hacía con una copia a un cuarto
    // de tamaño (`toImageSync`), y en la web eso es rasterizar el cuadro entero
    // en el procesador y leerlo de vuelta: cuatrocientos milisegundos por
    // fotograma, con un pueblo de ocho piezas. Ahora es una capa: el cuadro
    // se vuelve a pintar dentro, a un cuarto, con los filtros puestos, y al
    // cerrarla se amplía ×4. Todo queda en la tarjeta gráfica.
    if (dbg.bloom) _bloom(canvas, world, rect);
    // Los rayos ya no van acá: los pinta el cielo, detrás del pueblo
    // ([raysBehind]).

    _flare(canvas);
    _vignette(canvas, rect);
  }

  /// Abre una capa en la que lo que se pinta va a un cuarto de tamaño —un
  /// dieciseisavo de píxeles— y que al cerrarse se amplía al cuadro entero,
  /// con [filtro] aplicado antes de ampliar. Devuelve con el lienzo ya
  /// escalado: lo que se pinte después va en coordenadas del cuadro.
  void _capaChica(Canvas canvas, Rect rect, ui.ImageFilter filtro) {
    const k = 1 / _small;
    final ampliar = ui.ImageFilter.matrix(
      Float64List.fromList([k, 0, 0, 0, 0, k, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      filterQuality: FilterQuality.medium,
    );
    canvas.saveLayer(
      rect,
      Paint()
        ..blendMode = BlendMode.plus
        ..imageFilter = ui.ImageFilter.compose(outer: ampliar, inner: filtro),
    );
    canvas.save();
    canvas.scale(_small);
  }

  void _cierraCapaChica(Canvas canvas) {
    canvas.restore();
    canvas.restore();
  }

  // ------------------------------------------------------------ resplandor

  /// Lo claro del cuadro, desenfocado a dos radios y sumado.
  void _bloom(Canvas canvas, ui.Picture world, Rect rect) {
    // De noche brilla casi todo lo encendido; de día sólo lo que deslumbra.
    // Y de noche el umbral no baja: una pared alumbrada por su ventana ya es
    // casi tan clara como la ventana, y si brilla todo no brilla nada.
    //
    // Y de noche lo que brilla es lo cálido, no lo blanco. Al caer la tarde
    // las ventanas ya están encendidas pero una pared encalada todavía está
    // casi blanca de cielo —más clara que la ventana misma—, y por claridad
    // sola el resplandor la tomaba por una lámpara y la quemaba entera. La
    // luz de una ventana es amarilla: tiene mucho más rojo que azul, y una
    // pared clara no.
    final calido = 0.6 * night;
    final umbral = lerpD(0.80, 0.82, night);
    final fuerza =
        lerpD(0.42, 0.70, night) + (pal.isDaylight ? golden * 0.3 : 0.0);
    final tinte = Color.lerp(
      const Color(0xFFFFF4E0),
      const Color(0xFFFFD9A0),
      math.max(golden, night * 0.6),
    )!;
    // Eran tres radios; con dos —uno corto y uno ancho— se ve igual y es un
    // repintado menos.
    for (final (sigma, k) in [(8.0, 0.85), (34.0, 0.85)]) {
      final s = sigma * _small;
      _capaChica(
        canvas,
        rect,
        ui.ImageFilter.compose(
          outer: ui.ImageFilter.blur(
            sigmaX: s,
            sigmaY: s,
            tileMode: TileMode.decal,
          ),
          inner: ColorFilter.matrix(
            threshold(umbral, fuerza * k, tinte, calido: calido),
          ),
        ),
      );
      canvas.drawPicture(world);
      _cierraCapaChica(canvas);
    }
  }

  // ----------------------------------------------------------------- rayos

  /// Si hay sol delante, o cerca, para echar rayos.
  bool get raysWanted {
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

  /// Los rayos, pintados en el cielo, detrás del pueblo.
  ///
  /// **De [skyline] —el cielo y los montes— y no del cuadro entero.** Eran
  /// copias del cuadro, y cada copia era el pueblo entero pintado otra vez:
  /// con el sol en cuadro, mirar al sol hundía los fotogramas. El cielo y los
  /// montes son unas pocas formas, y repetirlos no cuesta nada. Lo que tapa
  /// el sol —un monte— sigue cortando los rayos; y como esto va antes del
  /// pueblo, una casa delante del sol los tapa por estar delante, que es lo
  /// que pasa de verdad.
  void raysBehind(Canvas canvas, ui.Picture skyline) =>
      _rays(canvas, skyline, Offset.zero & size);

  /// El cuadro repetido unas cuantas veces, cada vez un poco más grande
  /// alrededor del sol, quedándose sólo con lo claro. Lo que tapa el sol —un
  /// monte, una torre— sale oscuro en todas las copias, y eso es la sombra que
  /// corta el rayo.
  void _rays(Canvas canvas, ui.Picture world, Rect rect) {
    final sol = _light!;
    // Con el sol alto los rayos casi no se ven.
    final cuanto = 0.30 + golden * 1.1;
    final luz = Color.lerp(pal.sun, const Color(0xFFFFA650), golden * 0.7)!;
    final umbral = lerpD(0.62, 0.45, golden);
    _capaChica(
      canvas,
      rect,
      ui.ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0, tileMode: TileMode.decal),
    );
    // Eran catorce copias, después seis, y ahora tres más separadas, con más
    // desenfoque para que no se vean los escalones: llegan igual de lejos y
    // cada una pesa lo que pesaban las que reemplaza. **Cada copia es el
    // pueblo entero pintado otra vez**, y con el sol en cuadro eran seis de
    // nueve repintados por fotograma: mirar al sol hundía los fotogramas.
    const pasos = 3, junta = 14 / pasos;
    for (var k = 0; k < pasos; k++) {
      final s = 1.0 + k * 0.055 * junta;
      final peso = cuanto * 0.16 * junta * math.pow(0.86, k * junta);
      canvas.saveLayer(
        rect,
        Paint()
          ..blendMode = BlendMode.plus
          ..colorFilter = ColorFilter.matrix(
            threshold(umbral, peso.toDouble(), luz),
          ),
      );
      canvas
        ..translate(sol.dx, sol.dy)
        ..scale(s)
        ..translate(-sol.dx, -sol.dy)
        ..drawPicture(world);
      canvas.restore();
    }
    // Lo que queda lejos del sol no es un rayo, es el cielo entero brillando.
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.radial(
          sol,
          size.longestSide * 0.9,
          [
            const Color(0xFFFFFFFF),
            const Color(0x66FFFFFF),
            const Color(0x00FFFFFF),
          ],
          [0.0, 0.35, 1.0],
        ),
    );
    _cierraCapaChica(canvas);
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
    // La estrella de seis puntas del sol ya no va acá: ver [sunStar].
  }

  /// La estrella de seis puntas del sol, **en el cielo y no en la lente**.
  ///
  /// Se pintaba al final, encima del cuadro entero, y eso tenía dos fallos
  /// que se veían juntos: las puntas cruzaban el disco del sol —parecían
  /// rayos delante del sol, no saliendo de él— y seguían por encima de una
  /// casa o un monte que lo tapara. Ahora la pinta el cielo, antes del disco
  /// y antes de todo lo demás: el disco queda delante de sus puntas, y lo
  /// que está delante del sol queda delante de ellas.
  static void sunStar(
    Canvas canvas,
    Palette pal,
    Offset sol,
    double base,
    double disco,
  ) {
    final golden = _goldenOf(pal);
    final a = smoothstep(0.06, 0.24, pal.sunDir.y) * (0.55 + golden * 0.45);
    if (a < 0.02) return;
    final tinte = Color.lerp(pal.sun, const Color(0xFFFF9A4D), golden)!;
    final largo = base * (0.22 + golden * 0.18);
    for (var i = 0; i < 6; i++) {
      // Seis medias puntas que salen del borde del disco, no tres rayas que
      // lo atraviesan.
      final ang = i * math.pi / 3 + 0.3;
      final u = Offset(math.cos(ang), math.sin(ang));
      final desde = sol + u * (disco * 0.9);
      final hasta = sol + u * largo;
      // Sin desenfoque: en la web cada trazo desenfocado es una pasada más,
      // y esto se pinta en cada fotograma con el sol en cuadro. Una raya
      // ancha y tenue debajo de una fina hace lo mismo a la vista.
      for (final (ancho, k) in [(4.5, 0.35), (1.4, 1.0)]) {
        canvas.drawLine(
          desde,
          hasta,
          Paint()
            ..strokeWidth = ancho
            ..strokeCap = StrokeCap.round
            ..shader = ui.Gradient.linear(desde, hasta, [
              tinte.withValues(alpha: 0.45 * a * k),
              tinte.withValues(alpha: 0),
            ]),
        );
      }
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
  ///
  /// Con [calido] cuenta además cuánto más rojo que azul tiene cada punto:
  /// así una luz amarilla pasa y un blanco igual de claro no. El listón sube
  /// lo mismo que suma una luz amarilla, para que la ventana siga brillando
  /// lo que brillaba.
  static List<double> threshold(
    double umbral,
    double gain,
    Color tint, {
    double calido = 0,
  }) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    // Escala para que lo que esté en blanco salga con [gain].
    final k = gain / math.max(0.05, 1 - umbral);
    final off = -(umbral + calido * 0.4) * 255 * k;
    final tr = tint.r, tg = tint.g, tb = tint.b;
    // Mitad luminancia y mitad color propio: una ventana amarilla tiene que
    // dar luz amarilla, no blanca.
    List<double> fila(double t, int canal) {
      final propio = [calido, 0.0, -calido];
      propio[canal] += 0.5;
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
/// la sombra exacta de un sólido convexo—.
///
/// **Triángulos en una capa, y no un trazado.** Eran un solo trazado con todas
/// las sombras dentro —cientos de contornos pisándose— y un desenfoque
/// encima, para que donde dos se pisan no se oscureciera el doble. Un trazado
/// así es de lo más caro que se le puede pedir a la tarjeta gráfica, y en el
/// teléfono encender las sombras hundía los fotogramas. Ahora cada sombra son
/// unos triángulos, todos van en un solo lote de color macizo, y la
/// transparencia la pone la capa en la que se pintan: donde dos se pisan sigue
/// sin oscurecerse el doble, que la capa tiene un solo color por píxel.
void drawCastShadows(
  Canvas canvas,
  Projector p,
  Palette pal,
  Iterable<(TownLayout, int, Iterable<ShadowCaster>)> towns,
) {
  final dia = pal.isDaylight;
  final fuerza = dia
      ? 0.56 * smoothstep(0.02, 0.20, pal.sunDir.y)
      : 0.20 * smoothstep(0.2, 0.8, 1 - pal.daylight);
  if (fuerza < 0.01) return;
  final sombra = Color.lerp(pal.ink, pal.skyTop, dia ? 0.30 : 0.45)!;
  // Dos capas: lo macizo, y lo que deja pasar la luz —el agua—, que oscurece
  // menos.
  for (final claro in [false, true]) {
    final tri = _Triangulos();
    _castShadows(p, pal, towns, translucent: claro, emit: tri.add);
    if (tri.n == 0) continue;
    canvas.saveLayer(
      tri.bounds.inflate(2),
      Paint()..color = Color.fromRGBO(0, 0, 0, fuerza * (claro ? 0.45 : 1.0)),
    );
    canvas.drawVertices(
      ui.Vertices.raw(ui.VertexMode.triangles, tri.done()),
      BlendMode.dst,
      Paint()..color = sombra.withValues(alpha: 1),
    );
    canvas.restore();
  }
}

/// Los triángulos de todas las sombras de una capa, en abanico desde el
/// primer vértice de cada una (son convexas).
class _Triangulos {
  Float32List _xy = Float32List(4096);
  int n = 0;
  double x0 = double.infinity, y0 = double.infinity;
  double x1 = -double.infinity, y1 = -double.infinity;

  void add(Float64List sx, Float64List sy, int m) {
    final hacen = (m - 2) * 6;
    if (n + hacen > _xy.length) {
      final mas = Float32List(math.max(_xy.length * 2, n + hacen));
      mas.setRange(0, n, _xy);
      _xy = mas;
    }
    for (var i = 1; i < m - 1; i++) {
      _xy[n++] = sx[0];
      _xy[n++] = sy[0];
      _xy[n++] = sx[i];
      _xy[n++] = sy[i];
      _xy[n++] = sx[i + 1];
      _xy[n++] = sy[i + 1];
    }
    for (var i = 0; i < m; i++) {
      if (sx[i] < x0) x0 = sx[i];
      if (sx[i] > x1) x1 = sx[i];
      if (sy[i] < y0) y0 = sy[i];
      if (sy[i] > y1) y1 = sy[i];
    }
  }

  Rect get bounds => Rect.fromLTRB(x0, y0, x1, y1);
  Float32List done() => Float32List.sublistView(_xy, 0, n);
}

/// El trazado en pantalla de todas las sombras. Para los tests: lo que se
/// pinta son los mismos polígonos, en triángulos (ver [drawCastShadows]).
@visibleForTesting
Path castShadowPath(
  Projector p,
  Palette pal,
  Iterable<(TownLayout, int, Iterable<ShadowCaster>)> towns, {
  bool translucent = false,
}) {
  final path = Path();
  _castShadows(
    p,
    pal,
    towns,
    translucent: translucent,
    emit: (sx, sy, m) {
      path.moveTo(sx[0], sy[0]);
      for (var i = 1; i < m; i++) {
        path.lineTo(sx[i], sy[i]);
      }
      path.close();
    },
  );
  return path;
}

/// Las sombras, polígono a polígono, ya en la pantalla.
///
/// De dos clases de cosas: las piezas, por sus cajas ([shadowPointsOf]), y
/// todo lo demás que echa sombra ([ShadowCaster]): los muebles que se
/// archivaron con el pueblo y lo que se pinta este fotograma — la gente, los
/// pájaros, el agua. Con [translucent], sólo lo que se transparenta.
void _castShadows(
  Projector p,
  Palette pal,
  Iterable<(TownLayout, int, Iterable<ShadowCaster>)> towns, {
  required bool translucent,
  required void Function(Float64List sx, Float64List sy, int m) emit,
}) {
  final l = pal.lightDir;
  final ly = math.max(l.y, 0.10);
  final ox = -l.x / ly, oz = -l.z / ly;

  final xs = Float64List(40), zs = Float64List(40);
  for (final (town, take, otros) in towns) {
    if (!translucent) {
      for (final h in _piezasEnSuelo(town, take, ox, oz)) {
        _proyecta(p, h, emit);
      }
    }
    for (final c in otros) {
      if ((c.k < 1) != translucent) continue;
      var alto = 0.0;
      for (final v in c.pts) {
        if (v.y > alto) alto = v.y;
      }
      // Lo que está pegado al suelo no echa sombra que se vea.
      if (alto <= 0.02) continue;
      // Lo que no se mueve vuelve fotograma tras fotograma con la misma
      // lista: su envolvente en el suelo se guarda mientras el sol no se mueva.
      final hay = _enSuelo[c.pts];
      Float64List? h;
      if (hay != null && hay.$1 == ox && hay.$2 == oz) {
        h = hay.$3;
      } else {
        final pts = c.pts.length <= xs.length
            ? [for (final v in c.pts) (v.x + ox * v.y, v.z + oz * v.y)]
            : convexHull([
                for (final v in c.pts) (v.x + ox * v.y, v.z + oz * v.y),
              ]);
        if (pts.length <= xs.length) {
          for (var i = 0; i < pts.length; i++) {
            xs[i] = pts[i].$1;
            zs[i] = pts[i].$2;
          }
          h = _envolvente(xs, zs, pts.length);
        }
        _enSuelo[c.pts] = (ox, oz, h);
      }
      if (h != null) _proyecta(p, h, emit);
    }
  }
}

final Expando<(double, double, Float64List?)> _enSuelo = Expando();

/// Las sombras de las piezas de un pueblo en el suelo, guardadas: sólo
/// cambian cuando se mueve el sol o cae una pieza, y rehacer cientos de
/// envolventes en cada fotograma era la mitad de lo que costaban.
final Expando<(int, double, double, List<Float64List>)> _piezas = Expando();

List<Float64List> _piezasEnSuelo(
  TownLayout town,
  int take,
  double ox,
  double oz,
) {
  final hay = _piezas[town];
  if (hay != null && hay.$1 == take && hay.$2 == ox && hay.$3 == oz) {
    return hay.$4;
  }
  final xs = Float64List(40), zs = Float64List(40);
  final out = <Float64List>[];
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

    shadowPointsOf(pc, at);
    final h = _envolvente(xs, zs, m);
    if (h != null) out.add(h);
  }
  _piezas[town] = (take, ox, oz, out);
  return out;
}

final Float64List _hx = Float64List(84), _hz = Float64List(84);

/// La envolvente convexa (cadena monótona) de los puntos del suelo, como
/// x, z, x, z…, siempre en el mismo sentido. Nula si no llega a polígono.
Float64List? _envolvente(Float64List xs, Float64List zs, int n) {
  if (n < 3) return null;
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
  if (k < 3) return null;
  final out = Float64List(k * 2);
  for (var i = 0; i < k; i++) {
    out[i * 2] = _hx[i];
    out[i * 2 + 1] = _hz[i];
  }
  return out;
}

/// Una envolvente del suelo, llevada a la pantalla.
///
/// **Recortada contra el plano de la cámara, no tirada entera.** Si algún
/// vértice quedaba detrás del ojo, la sombra entera no se pintaba. Al
/// atardecer las sombras son largas y llegan por detrás de la cámara, así
/// que desaparecía de golpe la sombra de la casa que se tenía delante, y
/// volvía —como salida de la nada— al subir la vista un pelo.
void _proyecta(
  Projector p,
  Float64List h,
  void Function(Float64List sx, Float64List sy, int m) emit,
) {
  final k = h.length ~/ 2;
  for (var i = 0; i < k; i++) {
    final c = p.cameraOf(V3(h[i * 2], 0.005, h[i * 2 + 1]));
    _cx[i] = c.x;
    _cy[i] = c.y;
    _cz[i] = c.z;
  }
  final near = p.near + 0.01;
  var m = 0;
  for (var i = 0; i < k; i++) {
    final j = (i + 1) % k;
    final aIn = _cz[i] >= near, bIn = _cz[j] >= near;
    if (aIn) {
      _sx[m] = p.screenX(_cx[i], _cz[i]);
      _sy[m] = p.screenY(_cy[i], _cz[i]);
      m++;
    }
    if (aIn != bIn) {
      final t = (near - _cz[i]) / (_cz[j] - _cz[i]);
      final x = _cx[i] + (_cx[j] - _cx[i]) * t;
      final y = _cy[i] + (_cy[j] - _cy[i]) * t;
      _sx[m] = p.screenX(x, near);
      _sy[m] = p.screenY(y, near);
      m++;
    }
  }
  if (m < 3) return;
  emit(_sx, _sy, m);
}

final Float64List _sx = Float64List(170), _sy = Float64List(170);
final Float64List _cx = Float64List(84), _cy = Float64List(84);
final Float64List _cz = Float64List(84);
