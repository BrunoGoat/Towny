import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/constellations.dart';
import 'landscape.dart';
import 'scene.dart';
import 'shooting_star.dart';
import 'star_draw.dart';
import 'tones.dart';

/// Todo lo que no es el pueblo: el cielo, el sol, las estrellas, el prado y
/// las tres cordilleras del fondo.
///
/// Es la mitad de lo que se ve en pantalla y no comparte **nada** con la otra
/// mitad. El rasterizador de sólidos lleva un montón de estado vivo —el saco
/// de caras del fotograma, los sitios que se pueden tocar, el tono de cada
/// casa, la pieza que está cayendo— y ninguna de estas funciones toca uno solo
/// de esos campos: entra la escena, entra un lienzo, y sale un fondo. Eso se
/// midió antes de mover nada, método por método, y fue lo que dijo dónde
/// estaba el corte.
///
/// Lo que queda al otro lado, en `renderer.dart`, es el rasterizador de verdad:
/// recortar, ordenar, sombrear y rellenar caras. Que ahora se puedan leer por
/// separado es el punto — se estaban leyendo juntos porque estaban en el mismo
/// fichero, no porque tuvieran algo que decirse.
///
/// El orden en el que se pinta sigue estando en `TownPainter.paint`, que es
/// donde tiene que estar: cielo, suelo, montes y fugaz por debajo del pueblo,
/// y la bruma y la luz de la fugaz por encima. Lo de arriba y lo de abajo no se
/// pueden separar aunque estén en el mismo sitio, porque lo que va en medio es
/// el pueblo.
class Backdrop {
  Backdrop(this.scene, this.skies);

  final TownScene scene;

  /// Dónde cayó la constelación de esta noche, para poder tocarla. Es lo único
  /// que este fichero devuelve hacia fuera.
  final List<SkyHit> skies;

  void drawSky(Canvas canvas, Size size, Projector p, double horizonY) {
    final pal = scene.palette;
    final h = size.height;
    final top = 0.0;
    final hy = clampD(horizonY, -h * 3, h * 4);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final span = math.max(1.0, hy - top);
    final paint = Paint()
      ..shader = ui.Gradient.linear(Offset(0, hy - span), Offset(0, hy), [
        pal.skyTop,
        pal.skyHorizon,
      ]);
    canvas.drawRect(rect, paint);

    if (pal.starAlpha > 0.02) {
      drawStars(canvas, size, p, horizonY);
      drawConstellation(canvas, size, p, horizonY);
    }
    drawSun(canvas, size, p);

    // A soft band of haze sitting on the horizon.
    if (hy > -h && hy < h * 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, hy - h * 0.22, size.width, h * 0.22),
        Paint()
          ..shader =
              ui.Gradient.linear(Offset(0, hy - h * 0.22), Offset(0, hy), [
                pal.skyHorizon.withValues(alpha: 0),
                winterHaze(pal).withValues(alpha: 0.85),
              ]),
      );
    }
  }

  void drawStars(Canvas canvas, Size size, Projector p, double horizonY) {
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 130; i++) {
      final az = hash01(i, 3) * math.pi * 2;
      final el = 0.06 + hash01(i, 5) * 1.4;
      final at = skyPoint(p, az, el, minDen: 0.05);
      if (at == null) continue;
      final sx = at.dx, sy = at.dy;
      if (sx < 0 || sx > size.width || sy < 0 || sy > horizonY) continue;
      final tw = 0.55 + 0.45 * math.sin(scene.time * 1.7 + i * 2.1);
      paint.color = Colors.white.withValues(
        alpha: (0.25 + 0.55 * hash01(i, 9)) * tw * scene.palette.starAlpha,
      );
      canvas.drawCircle(Offset(sx, sy), 0.6 + hash01(i, 11) * 1.1, paint);
    }
  }

  /// La constelación de esta noche.
  ///
  /// Colgada del cielo por su forma real: las coordenadas de sus estrellas son
  /// las del catálogo, y `hang` rehace el plano tangente donde se la ponga, así
  /// que los ángulos entre ellas son los de verdad. Lo que se ve es la figura
  /// que se ve levantando la cabeza, no una parecida.
  ///
  /// Dónde se cuelga lo decide la noche y no el reloj: pasa la noche entera en
  /// el mismo sitio del cielo, que es lo que permite salir a buscarla. Girar
  /// la cámara la encuentra; esperar, no.
  void drawConstellation(
    Canvas canvas,
    Size size,
    Projector p,
    double horizonY,
  ) {
    final c = scene.tonight;
    if (c == null) return;
    final night = scene.skyNight;
    final az = hash01(night, 77) * math.pi * 2;
    // Colgada por su borde de abajo y no por su centro. Lo que hay que
    // garantizar es que el pie de la figura quede unos grados por encima del
    // horizonte —si no, se la come una cordillera— y eso depende de lo ancha
    // que sea: Escorpio ocupa veinticinco grados de cielo y la Cruz del Sur
    // seis. Puesta por el centro, la grande quedaba fuera de la pantalla.
    final el = c.spread * 0.5 + 0.09 + hash01(night, 79) * 0.11;

    // Quieta y floja. Antes latía —crecía y menguaba— porque había algo que
    // hacer con ella: tocarla la anotaba en un cuaderno, y un latido es la
    // manera de decir «acá». Ya no hay cuaderno, así que tampoco hay por qué
    // pedir nada: es una figura de estrellas en el cielo de esta noche y con
    // eso basta. Lo que sí se queda es que se puede tocar, y suena.
    final ink = scene.palette.starAlpha * 0.62;
    if (ink < 0.03) return;

    final at = <Offset?>[];
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    var seen = 0;
    for (final (sa, se) in hang(c, az, el)) {
      final o = skyPoint(p, sa, se, minDen: 0.10);
      at.add(o);
      if (o == null) continue;
      seen++;
      if (o.dx < x0) x0 = o.dx;
      if (o.dx > x1) x1 = o.dx;
      if (o.dy < y0) y0 = o.dy;
      if (o.dy > y1) y1 = o.dy;
    }
    // Media figura no es una figura: o se ve entera o no se ofrece.
    if (seen < c.stars.length) return;
    if (x1 < 0 || x0 > size.width || y1 < 0 || y0 > horizonY) return;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: ink * 0.34);
    for (var k = 0; k + 1 < c.lines.length; k += 2) {
      final a = at[c.lines[k]], b = at[c.lines[k + 1]];
      if (a == null || b == null) continue;
      canvas.drawLine(a, b, line);
    }
    final dot = Paint()..color = Colors.white;
    for (var i = 0; i < at.length; i++) {
      final o = at[i];
      if (o == null) continue;
      // Por magnitud, y al revés de lo que parece: cuanto más chica, más
      // brilla. Sirio en menos uno y media tiene que verse como Sirio.
      final mag = c.stars[i].mag;
      final size01 = clampD((3.2 - mag) / 4.6, 0.22, 1.0);
      dot.color = Colors.white.withValues(alpha: ink * (0.55 + 0.45 * size01));
      canvas.drawCircle(o, 1.0 + 1.9 * size01, dot);
    }

    final box = Rect.fromLTRB(x0, y0, x1, y1).inflate(16);
    skies.add(SkyHit(c.id, box));

    // Y no lleva nombre escrito debajo.
    //
    // Lo llevó, y la razón era buena: sin él, unas cuantas estrellas unidas por
    // rayas no son Casiopea. Pero un rótulo en mayúsculas flotando sobre el
    // valle no es una cosa del cielo, es una etiqueta encima del cielo — y lo
    // que tiene que hacer una constelación acá es pasar desapercibida hasta que
    // alguien levante la vista. El nombre sigue estando: sale al tocarla, que
    // es cuando alguien preguntó.
  }

  /// Una estrella fugaz, cada tanto, cuando hay noche.
  ///
  /// Quién decide si hay una y por dónde va está en [ShootingStar], y cómo se
  /// pinta en [StarDraw], porque el tablón de cerca dibuja su propio cielo y
  /// necesita las dos cosas iguales.
  void drawShootingStar(
    Canvas canvas,
    Size size,
    Projector p,
    double horizonY,
  ) {
    final star = ShootingStar.at(
      scene.time,
      scene.hourOfDay,
      SkyView.of(p, size.width, size.height),
    );
    if (star == null) return;
    StarDraw.sky(
      canvas,
      size,
      (az, el) => skyPoint(p, az, el, minDen: 0.08),
      horizonY,
      star,
      scene.palette.starAlpha,
    );
  }

  /// La luz que echa una fugaz sobre el pueblo. El dibujo está en [StarDraw],
  /// que es el mismo que usa el tablón de la plaza.
  void drawStarLight(Canvas canvas, Size size, Projector p) {
    final star = ShootingStar.at(
      scene.time,
      scene.hourOfDay,
      SkyView.of(p, size.width, size.height),
    );
    if (star == null) return;
    StarDraw.land(
      canvas,
      size,
      (az, el) => skyPoint(p, az, el, minDen: 0.02),
      star,
      scene.palette.starAlpha,
    );
  }

  /// The sun through the day, the moon through the night. Both ride the same
  /// arc, which is what makes the shadows swing round as the hours pass.
  void drawSun(Canvas canvas, Size size, Projector p) {
    final pal = scene.palette;
    final day = pal.isDaylight;
    final d = day ? pal.sunDir : pal.moonDir;
    final den = d.dot(p.forward);
    if (den <= 0.08) return;
    final sx = p.cx + p.focal * d.dot(p.right) / den;
    final sy = p.cy - p.focal * d.dot(p.up) / den;
    if (sx < -400 || sx > size.width + 400) return;

    final r = size.shortestSide * (day ? 0.052 : 0.040);
    final glow = day ? 5.5 : 3.4;
    // Low sun reddens and swells, the way it does near the horizon.
    final low = 1 - clampD(d.y * 2.4, 0, 1);
    final disc = day
        ? Color.lerp(pal.sun, const Color(0xFFFF9A4D), low * 0.55)!
        : const Color(0xFFEFF3FF);

    canvas.drawCircle(
      Offset(sx, sy),
      r * glow * (1 + low * 0.5),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(sx, sy),
          r * glow * (1 + low * 0.5),
          [
            disc.withValues(alpha: day ? 0.32 : 0.20),
            disc.withValues(alpha: 0.0),
          ],
        ),
    );
    canvas.drawCircle(
      Offset(sx, sy),
      r,
      Paint()..color = disc.withValues(alpha: 0.94),
    );
    if (!day) {
      // A bite out of the disc, so it reads as a moon and not a pale sun.
      canvas.drawCircle(
        Offset(sx + r * 0.42, sy - r * 0.30),
        r * 0.88,
        Paint()..color = pal.skyTop.withValues(alpha: 0.92),
      );
    }
  }

  void drawGround(Canvas canvas, Size size, double horizonY) {
    final hy = clampD(horizonY, -size.height, size.height * 2);
    if (hy > size.height) return;
    final rect = Rect.fromLTWH(0, hy, size.width, size.height - hy);
    if (rect.height <= 0) return;
    // Un solo verde, sin degradado.
    //
    // Lo tuvo, y ése era el problema. Un degradado entre dos verdes que se
    // llevan treinta unidades, estirado sobre mil píxeles, no puede salir
    // suave: a ocho bits no hay más que treinta valores entre uno y otro, así
    // que el aparato lo trama, y el tramado se lee como una persiana de rayas
    // horizontales. Las casas y las montañas nunca la tuvieron porque son
    // rellenos planos: no hay nada entre lo que escalonar. El prado era lo
    // único degradado del cuadro y era lo único rayado.
    //
    // Antes de esto se probó a taparlo con manchas de hierba, y salió peor:
    // ancladas al mundo se veía la baldosa desde el valle, y creciendo con la
    // altura del ojo se movían al hacer zoom, que es lo último que puede hacer
    // un prado. La respuesta buena era la más corta: si el degradado es lo que
    // se escalona, que no haya degradado. Un relleno plano no tiene nada que
    // tramar y no puede salir a rayas por construcción.
    //
    // Lo que sí tenía que cambiar sigue cambiando: el verde es otro a cada
    // hora.
    canvas.drawRect(rect, Paint()..color = meadowTone(scene.palette));
  }

  /// Las matas de hierba que asoman entre la nieve.
  ///
  /// Un prado nevado no es una sábana: la nieve se posa desigual y por los
  /// claros asoma lo de debajo. Con el prado de un solo color —que es lo que
  /// tiene que ser, ver [drawGround]— el invierno salía como una pared blanca
  /// sin nada dentro.
  ///
  /// **Pegadas al suelo, quietas, y siempre las mismas.** Cada mata es un
  /// polígono tumbado en el prado, en coordenadas del mundo, y se proyecta con
  /// la misma cámara que el pueblo: de lejos se aplasta y se achica, de cerca
  /// se abre, como cualquier cosa que está en el piso. Dónde hay una no
  /// depende de la cámara en absoluto, ni cuáles se dibujan: se dibujan
  /// todas las del valle, a cualquier distancia. Primero salían de una
  /// rejilla alrededor del ojo y aparecían y desaparecían al mover la cámara;
  /// después se apagaban pasados unos metros y al sacar zoom el valle
  /// quedaba blanco. Ahora alejarse es ver las mismas matas más chicas.
  ///
  /// **Cómo se hace sin que cueste un mundo.** Las del valle entero son
  /// decenas de miles, así que se arman una vez —por día— con sus contornos
  /// ya calculados ([_matasDelValle]) y en cada fotograma sólo se proyectan.
  /// Y la que de lejos mide pocos píxeles no se proyecta vértice a vértice:
  /// se proyecta su centro y dos pasos de un metro, y el contorno se lleva a
  /// pantalla con eso, que a ese tamaño es exactamente lo mismo.
  ///
  /// **Y cambian cada día.** La semilla lleva la fecha dentro, así que el
  /// reparto de mañana no es el de hoy: la nieve no se posa dos noches igual.
  ///
  /// No son otro verde: son **el prado de debajo**, el mismo que se vería si
  /// no hubiera nevado, con el pardo que le toque al mes.
  void drawTufts(Canvas canvas, Projector p, Size size, double horizonY) {
    final pal = scene.palette;
    if (pal.season.snow < 0.10) return;
    // Del mismo peso que el manto: una mata asoma sobre lo blanco que haya.
    final nieve = snowCover(pal.season);
    // Y más claros cuanto menos nieve: así se ve llegar y se ve irse.
    final claros = 1 + 1.2 * (1 - pal.season.snow);

    // De noche, a medio camino de la propia nieve. El verde de la hierba
    // nocturna es casi negro, y casi negro sobre un prado nevado no se lee
    // como un claro sino como un agujero: de día son matas y de noche eran
    // charcos de alquitrán.
    //
    // Y de día, también algo hundidas en la nieve: a verde lleno sobre blanco
    // eran un estampado de camuflaje, más fuertes que el pueblo mismo.
    final manto = meadowTone(pal);
    final verde = Color.lerp(
      tuftTone(pal),
      manto,
      0.22 + (1 - pal.daylight) * 0.45,
    )!;
    // Dos tonos y no uno. Un claro de hierba y otro de hierba seca al lado es
    // lo que hace que un campo pelado no parezca estampado.
    final pardo = Color.lerp(verde, manto, 0.34)!;

    var lejos = 0.0;
    for (final e in scene.towns) {
      final l = e.layout;
      lejos = math.max(lejos, math.sqrt(l.cx * l.cx + l.cz * l.cz) + l.radius);
    }
    final matas = _matasDelValle(scene.day, claros, lejos + _margen);

    final caminos = [Path(), Path()];
    final ex = p.eye.x, ez = p.eye.z;
    final fl = math.sqrt(p.forward.x * p.forward.x + p.forward.z * p.forward.z);
    final fx = fl > 0.001 ? p.forward.x / fl : 0.0;
    final fz = fl > 0.001 ? p.forward.z / fl : 1.0;
    final w = size.width, h = size.height;
    // La proyección escrita a mano, sin crear un vector por mata: son miles
    // por fotograma, y lo que costaba era eso y no la cuenta.
    final r = p.right, u = p.up, f = p.forward, foc = p.focal;
    final ey = -p.eye.y;
    final ry = r.y * ey, uy0 = u.y * ey, fy = f.y * ey;
    var puestas = 0;

    for (final m in matas) {
      final vx = m.x - ex, vz = m.z - ez;
      // Lo que queda claramente detrás ni se proyecta.
      if (vx * fx + vz * fz < -m.reach) continue;
      final kx = vx * r.x + ry + vz * r.z;
      final ky = vx * u.x + uy0 + vz * u.z;
      final kz = vx * f.x + fy + vz * f.z;
      if (kz < p.near) continue;
      final cxs = p.cx + kx * foc / kz, cys = p.cy - ky * foc / kz;
      // Lo que mide en pantalla, más o menos: con eso se descarta lo que cae
      // fuera y se elige cómo proyectarla.
      final mide = foc * m.reach / kz;
      // Menos de un cuarto de píxel no pinta nada que se vea.
      if (mide < 0.25) continue;
      if (cxs < -mide || cxs > w + mide || cys > h + mide) continue;
      if (cys < horizonY - mide - 2) continue;
      final camino = caminos[m.kind];
      if (mide < 40) {
        // A esta escala el suelo es plano en pantalla: cuánto se mueve el
        // punto en pantalla por cada metro hacia cada lado —la derivada de la
        // proyección en el centro— dice dónde cae cada punto del contorno.
        final k2 = foc / (kz * kz);
        final ux = k2 * (r.x * kz - kx * f.x), uy = -k2 * (u.x * kz - ky * f.x);
        final wx = k2 * (r.z * kz - kx * f.z), wy = -k2 * (u.z * kz - ky * f.z);
        // Y con menos vértices cuanto más chica: en una mata de cuatro
        // píxeles, catorce puntos y cinco dibujan lo mismo, y de lejos son
        // decenas de miles de matas.
        final paso = mide < 4 ? 6 : (mide < 10 ? 4 : 2);
        for (final b in m.contornos) {
          for (var j = 0; j < b.length; j += paso) {
            final dx = b[j] - m.x, dz = b[j + 1] - m.z;
            final sx = cxs + ux * dx + wx * dz, sy = cys + uy * dx + wy * dz;
            if (j == 0) {
              camino.moveTo(sx, sy);
            } else {
              camino.lineTo(sx, sy);
            }
          }
          camino.close();
        }
      } else {
        // De cerca, vértice a vértice: ahí la perspectiva dentro de la misma
        // mata ya se nota. Si algún vértice cae detrás del ojo, la mata
        // entera se deja: es la que está pegada a la cámara.
        final pts = <double>[];
        var ok = true;
        for (final b in m.contornos) {
          pts.clear();
          for (var j = 0; j < b.length; j += 2) {
            final at = p.project(V3(b[j], 0, b[j + 1]));
            if (at == null) {
              ok = false;
              break;
            }
            pts
              ..add(at.x)
              ..add(at.y);
          }
          if (!ok) break;
          camino.moveTo(pts[0], pts[1]);
          for (var j = 2; j < pts.length; j += 2) {
            camino.lineTo(pts[j], pts[j + 1]);
          }
          camino.close();
        }
      }
      puestas++;
    }
    if (puestas == 0) return;
    canvas.drawPath(
      caminos[0],
      Paint()..color = verde.withValues(alpha: nieve),
    );
    canvas.drawPath(
      caminos[1],
      Paint()..color = pardo.withValues(alpha: nieve),
    );
  }

  /// Cuánto prado con matas hay más allá del pueblo más alejado del centro.
  /// Más lejos que esto, desde cualquier sitio al que llega la cámara, una
  /// mata mide menos de un píxel.
  static const double _margen = 700;

  /// Las matas del valle entero de un día, con sus contornos ya hechos. Se
  /// rehacen sólo si cambia el día, lo nevado o el tamaño del valle.
  static List<_MataHecha> _matasDelValle(int dia, double claros, double radio) {
    final clave = '$dia:${(claros * 20).round()}:${(radio / 50).ceil()}';
    if (clave == _claveMatas) return _matas;
    _claveMatas = clave;
    _matas = [
      for (final m in tuftsAround(
        0,
        0,
        (radio / 50).ceil() * 50.0,
        dia,
        claros,
      ))
        _MataHecha(m),
    ];
    return _matas;
  }

  static String? _claveMatas;
  static List<_MataHecha> _matas = const [];

  /// El lado de la casilla del mundo que puede tener una mata.
  static const double _casilla = 3.0;

  /// Las matas que hay a menos de [reach] metros de (`ex`, `ez`).
  ///
  /// Dónde está cada una sale sólo de su casilla del mundo y del día —nunca
  /// del ojo—, así que mirar desde otro sitio da exactamente las mismas matas
  /// donde se solapan: el ojo sólo elige qué trozo del prado se recorre.
  static Iterable<GroundTuft> tuftsAround(
    double ex,
    double ez,
    double reach,
    int dia,
    double claros,
  ) sync* {
    final i0 = ((ex - reach) / _casilla).floor();
    final i1 = ((ex + reach) / _casilla).ceil();
    final k0 = ((ez - reach) / _casilla).floor();
    final k1 = ((ez + reach) / _casilla).ceil();
    final r2 = reach * reach;
    for (var i = i0; i <= i1; i++) {
      for (var k = k0; k <= k1; k++) {
        final x = (i + 0.5 + (hash01(i, k, 1, dia) - 0.5) * 0.8) * _casilla;
        final z = (k + 0.5 + (hash01(i, k, 2, dia) - 0.5) * 0.8) * _casilla;
        final dx = x - ex, dz = z - ez;
        if (dx * dx + dz * dz > r2) continue;
        // Por rodales y no salpicadas parejo: la hierba asoma donde el
        // viento barrió la nieve, que es en manchas grandes, y entre rodal y
        // rodal el blanco queda limpio.
        final hierba = hash01(i, k, 7, dia) < 0.30 * claros * _rodal(i, k, dia);
        if (hierba) {
          yield GroundTuft(
            x,
            z,
            hash01(i, k, 4, dia) < 0.42 ? 1 : 0,
            0.35 + hash01(i, k, 3, dia) * 0.55,
            hashInt(1 << 30, i, k, 5, dia),
          );
        }
      }
    }
  }

  /// Cuánta hierba asoma por aquí, de cero a uno: ruido suave a la escala de
  /// una era, para que las matas vayan por rodales.
  static double _rodal(int gi, int gk, int dia) {
    const lado = 9;
    final fx = gi / lado, fz = gk / lado;
    final x0 = fx.floor(), z0 = fz.floor();
    final tx = fx - x0, tz = fz - z0;
    final sx = tx * tx * (3 - 2 * tx), sz = tz * tz * (3 - 2 * tz);
    double v(int a, int b) => hash01(a, b, 11, dia);
    final n = lerpD(
      lerpD(v(x0, z0), v(x0 + 1, z0), sx),
      lerpD(v(x0, z0 + 1), v(x0 + 1, z0 + 1), sx),
      sz,
    );
    return smoothstep(0.30, 0.78, n);
  }

  void drawRanges(Canvas canvas, Projector p, Size size, double horizonY) {
    final pal = scene.palette;
    final light = pal.lightDir;

    // Below the horizon is the ground plane, and a range hundreds of units away
    // is behind it. Clipping there is what stops the mountains from floating in
    // the middle of the field when the camera looks down at the wall, and what
    // makes their feet meet the ground instead of hanging over it.
    final cut = clampD(horizonY, -1.0, size.height + 1.0);
    if (cut <= 0) return;
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, -size.height, size.width, cut + size.height + 1),
    );

    // Only the arc in front of the camera: everything else is behind the eye,
    // where projection is meaningless. Sampled just wide enough for the lens.
    final az = math.atan2(p.forward.x, p.forward.z);
    final span = math.atan(size.width * 0.5 / p.focal) + 0.30;
    const steps = 210;
    final floor = size.height + 40;
    final look = scene.camera.travel;

    // Where the sun is across the screen, for the light that grazes the tops.
    // A number, not a side: the old code asked «is this slope facing the
    // light?» and got a yes or a no, which put a hard vertical edge down the
    // middle of every range at the two points where the answer flipped.
    final sunTh = wrap(math.atan2(light.x, light.z) - az);
    final sunX = size.width / 2 + p.focal * math.tan(clampD(sunTh, -1.3, 1.3));

    for (var li = Landscape.ridges.length - 1; li >= 0; li--) {
      final layer = Landscape.ridges[li];
      final (body, foot) = rangeTone(pal, li, Landscape.ridges.length);

      // Every sample first, then the paint, then the shapes. In one pass the
      // gradient of a strip could only start at that strip's own highest
      // point, so two strips of the same range began their fade at different
      // heights and met along a visible step. One range, one paint.
      // Proyectadas como direcciones y no como puntos: una cordillera está
      // infinitamente lejos, y lo que eso quiere decir es que gira con la
      // cámara y no se mueve con ella.
      //
      // Antes se muestreaba en `ojo + dirección × radio` con la altura en
      // coordenadas del mundo: la posición horizontal seguía a la cámara pero
      // la vertical no, así que al subir el ojo —que es lo que hace alejarse—
      // las montañas se hundían proporcionalmente a la altura partido el
      // radio. Con el radio de la primera en ciento cincuenta y el ojo subiendo
      // decenas de unidades, eso es media cordillera de salto: se movían como
      // si estuvieran a diez metros, y en el peor caso su pie se metía por
      // debajo del horizonte y el prado se las comía.
      //
      // Así, en cambio, la elevación cero cae exactamente en el horizonte por
      // construcción, que es el sitio donde el suelo empieza. No hay forma de
      // que el pasto tape una montaña.
      final xs = <double>[], ys = <double>[];
      // Y de cada muestra, hacia dónde cae, cuánto mide y en qué sitio del
      // mundo está: la nieve se decide con eso, no con la pantalla.
      final ths = <double>[],
          hs = <double>[],
          wxs = <double>[],
          wzs = <double>[];
      var crest = size.height;
      for (var i = 0; i <= steps; i++) {
        final th = az - span + (i / steps) * (span * 2);
        final dx = math.sin(th), dz = math.cos(th);
        final h = Landscape.ridgeHeight(
          layer,
          look + dx * layer.radius,
          dz * layer.radius,
        );
        ths.add(th);
        hs.add(h);
        wxs.add(look + dx * layer.radius);
        wzs.add(dz * layer.radius);
        // El perfil sigue cambiando con el viaje, así que caminar por el valle
        // descubre otra sierra: eso es paralaje de verdad, y es la única que
        // una cosa tan lejos tiene derecho a tener.
        final at = skyPoint(
          p,
          th,
          math.atan2(math.max(h, layer.base), layer.radius),
          minDen: 0.02,
        );
        if (at == null) {
          xs.add(double.nan);
          ys.add(double.nan);
          continue;
        }
        xs.add(at.dx);
        ys.add(at.dy);
        if (at.dy < crest) crest = at.dy;
      }

      // Each range fades into the haze where it meets the horizon, the way
      // distance actually works. Into the haze and not into the ground: fading
      // to the ground's own colour made the two indistinguishable exactly where
      // they meet, and the skyline dissolved instead of standing against the
      // field.
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, math.min(crest, cut - 1)),
          Offset(0, cut),
          [body, foot],
        );

      final shapes = <Path>[];
      Path? path;
      var startX = 0.0, lastX = 0.0;
      for (var i = 0; i <= steps; i++) {
        if (ys[i].isNaN) {
          if (path != null) {
            shapes.add(
              path
                ..lineTo(lastX, floor)
                ..lineTo(startX, floor)
                ..close(),
            );
            path = null;
          }
          continue;
        }
        if (path == null) {
          path = Path()..moveTo(xs[i], floor);
          path.lineTo(xs[i], ys[i]);
          startX = xs[i];
        } else {
          path.lineTo(xs[i], ys[i]);
        }
        lastX = xs[i];
      }
      if (path != null) {
        shapes.add(
          path
            ..lineTo(lastX, floor)
            ..lineTo(startX, floor)
            ..close(),
        );
      }

      for (final shape in shapes) {
        canvas.drawPath(shape, paint);
      }

      // And the sun on the tops, as a wash that comes and goes across the
      // screen rather than a side that is either lit or not. Near ranges take
      // more of it: the far ones are too much air away to catch anything.
      final near01 =
          (Landscape.ridges.length - 1 - li) /
          math.max(1, Landscape.ridges.length - 1);
      // Por cuánto de día es, y no siempre. El barrido usaba el color del sol
      // a plena fuerza a cualquier hora: a las tres de la mañana pintaba una
      // mancha clara en la ladera, del lado donde estaría el sol si lo
      // hubiera. De noche no le da el sol a nada.
      final strength = (0.20 + 0.16 * near01) * pal.daylight;
      if (strength > 0.02 && sunX > -size.width && sunX < size.width * 2) {
        final reach = size.width * 0.85;
        final glow = Paint()
          ..shader = ui.Gradient.linear(
            Offset(sunX - reach, 0),
            Offset(sunX + reach, 0),
            [
              pal.sun.withValues(alpha: 0),
              pal.sun.withValues(alpha: strength),
              pal.sun.withValues(alpha: 0),
            ],
            const [0.0, 0.5, 1.0],
          );
        for (final shape in shapes) {
          canvas.drawPath(shape, glow);
        }
      }

      // La nieve de las cumbres, encima y maciza.
      final cap = snowCap(pal, li, Landscape.ridges.length);
      if (cap != null) {
        final (nieve, linea) = cap;
        final manto = Path();
        _snowOn(manto, p, layer, linea, ths, hs, wxs, wzs, xs, ys);
        canvas.drawPath(manto, Paint()..color = nieve);
      }
    }

    canvas.restore();
  }

  /// La nieve de una sierra: lo que pasa de la línea de nieve, relleno.
  ///
  /// Antes era un degradado de pantalla que empezaba en el pico más alto que
  /// se viera, así que al girar la cámara —y entrar o salir de cuadro otro
  /// pico— la nieve subía y bajaba por las laderas como una luz. Ahora la
  /// línea de nieve es una **altura del mundo** ([linea], en las mismas
  /// unidades que la sierra), y la nieve es la parte de la montaña que la
  /// pasa: un sólido del mismo plano que la roca, que no se mueve al mirar
  /// desde otro lado porque la montaña tampoco.
  ///
  /// La línea no es recta: sube y baja un poco con el sitio —ruido sobre la
  /// posición en el mundo, no en la pantalla, y al paso de las propias
  /// montañas ([snowEdge])—, que es lo que la nieve hace en un monte, entrar
  /// por las canaletas y quedarse corta en las aristas.
  static void _snowOn(
    Path manto,
    Projector p,
    RidgeLayer layer,
    double linea,
    List<double> ths,
    List<double> hs,
    List<double> wxs,
    List<double> wzs,
    List<double> xs,
    List<double> ys,
  ) {
    double cota(int i) =>
        linea + layer.height * 0.09 * snowEdge(layer, wxs[i], wzs[i]);
    Offset? pie(int i, double h) => skyPoint(
      p,
      ths[i],
      math.atan2(math.max(h, layer.base), layer.radius),
      minDen: 0.02,
    );

    final arriba = <Offset>[], abajo = <Offset>[];
    void cerrar() {
      if (arriba.length >= 2) {
        manto.moveTo(arriba.first.dx, arriba.first.dy);
        for (final o in arriba.skip(1)) {
          manto.lineTo(o.dx, o.dy);
        }
        for (final o in abajo.reversed) {
          manto.lineTo(o.dx, o.dy);
        }
        manto.close();
      }
      arriba.clear();
      abajo.clear();
    }

    final n = hs.length;
    for (var i = 0; i < n; i++) {
      if (ys[i].isNaN) {
        cerrar();
        continue;
      }
      final sobra = hs[i] - cota(i);
      final antes = i > 0 && !ys[i - 1].isNaN ? hs[i - 1] - cota(i - 1) : null;
      if (sobra > 0) {
        // Entrando en la nieve: el borde donde la ladera cruza la línea.
        if (antes != null && antes <= 0) {
          final t = antes / (antes - sobra);
          final o = Offset(
            lerpD(xs[i - 1], xs[i], t),
            lerpD(ys[i - 1], ys[i], t),
          );
          arriba.add(o);
          abajo.add(o);
        }
        final b = pie(i, cota(i));
        if (b == null) {
          cerrar();
          continue;
        }
        arriba.add(Offset(xs[i], ys[i]));
        abajo.add(b);
      } else if (arriba.isNotEmpty) {
        // Saliendo: el mismo borde del otro lado, y se cierra el trozo.
        if (antes != null && antes > 0) {
          final t = antes / (antes - sobra);
          final o = Offset(
            lerpD(xs[i - 1], xs[i], t),
            lerpD(ys[i - 1], ys[i], t),
          );
          arriba.add(o);
          abajo.add(o);
        }
        cerrar();
      }
    }
    cerrar();
  }

  // ----------------------------------------------------------------- ghost

  void drawAtmosphere(Canvas canvas, Size size, double horizonY) {
    final pal = scene.palette;
    // A soft vignette to hold the eye on the town.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.52),
          size.longestSide * 0.72,
          [Colors.transparent, pal.ink.withValues(alpha: 0.26)],
          [0.55, 1.0],
        ),
    );
  }
}

// ------------------------------------------------------------------- sky

/// Dónde cae la línea del horizonte. Estática porque no mira nada de la
/// escena: sólo hacia dónde apunta la cámara. El tablón de cerca dibuja su
/// propio prado y necesita exactamente esta cuenta, y dos copias de esto
/// serían dos horizontes que se separan en cuanto una de las dos cambie.
double horizonOf(Projector p, Size size) {
  final f = p.forward;
  var hx = f.x, hz = f.z;
  final l = math.sqrt(hx * hx + hz * hz);
  if (l < 1e-5) return -size.height; // looking straight down
  hx /= l;
  hz /= l;
  final d = V3(hx, 0, hz);
  final den = d.dot(p.forward);
  if (den.abs() < 1e-5) return -size.height;
  return p.cy - p.focal * (d.dot(p.up) / den);
}

/// Dónde cae en pantalla algo que está infinitamente lejos, dado su azimut y
/// su elevación.
///
/// Las estrellas, las fugaces y las tres cordilleras usan esto mismo, y ése
/// es el asunto: son las tres cosas de esta escena que están tan lejos que
/// sólo giran con la cámara y no se mueven con ella. La cuenta no tiene un
/// solo término con `eye` dentro, y por eso trasladar el ojo —caminar por el
/// valle, alejarse, subir— no las mueve ni un píxel.
///
/// De ahí sale además, gratis, la propiedad que hacía falta: la elevación
/// cero cae exactamente en la línea del horizonte, que es donde el suelo
/// empieza a dibujarse. Un pie de montaña no puede quedar por debajo del
/// prado.
Offset? skyPoint(Projector p, double az, double el, {double minDen = 0.03}) {
  final ce = math.cos(el);
  final d = V3(math.sin(az) * ce, math.sin(el), math.cos(az) * ce);
  final den = d.dot(p.forward);
  if (den <= minDen) return null;
  return Offset(
    p.cx + p.focal * d.dot(p.right) / den,
    p.cy - p.focal * d.dot(p.up) / den,
  );
}

/// An angle brought back into -pi..pi, so «how far round is the sun from
/// where we are looking» never comes out as most of a circle.
double wrap(double a) {
  var x = a;
  while (x > math.pi) {
    x -= 2 * math.pi;
  }
  while (x < -math.pi) {
    x += 2 * math.pi;
  }
  return x;
}

/// Una mata en el prado nevado: dónde está en el mundo y de qué tamaño. Ver
/// [Backdrop.drawTufts].
class GroundTuft {
  const GroundTuft(this.x, this.z, this.kind, this.size, this.seed);

  /// El centro, en el suelo.
  final double x, z;

  /// Cero hierba, uno hierba seca.
  final int kind;

  /// El radio de la mata, en metros.
  final double size;

  final int seed;

  /// Hasta dónde llega desde el centro, para descartarla sin proyectarla.
  double get reach => size * 2.4;

  /// Los contornos, en el suelo: pares x, z.
  ///
  /// Una mata es una o tres manchas montadas, cada una de otro tamaño y
  /// corrida de su sitio, con los radios torcidos: una forma redonda sola se
  /// lee como una moneda tirada en el suelo, y lo que hace que algo parezca
  /// hierba es que no tenga una forma que se pueda nombrar.
  Iterable<List<double>> blobs() sync* {
    double h(int salt) => hash01(seed, salt);
    final cuantas = h(2) < 0.45 ? 1 : 3;
    for (var b = 0; b < cuantas; b++) {
      final r = size * (b == 0 ? 1.0 : 0.45 + h(10 + b) * 0.40);
      final cx = x + (b == 0 ? 0.0 : (h(20 + b) - 0.5) * size * 2.2);
      final cz = z + (b == 0 ? 0.0 : (h(30 + b) - 0.5) * size * 2.2);
      final giro = h(40 + b) * math.pi;
      // Los radios torcidos pero suavizados con los vecinos: torcidos sueltos
      // salían estrellas de puntas, y una mata no tiene puntas.
      const lados = 14;
      double crudo(int j) => 0.70 + h(50 + b * 20 + j % lados) * 0.50;
      yield [
        for (var j = 0; j < lados; j++)
          ...() {
            final a = giro + j * 2 * math.pi / lados;
            final rr =
                r *
                (crudo(j + lados - 1) * 0.25 +
                    crudo(j) * 0.5 +
                    crudo(j + 1) * 0.25);
            return [cx + math.cos(a) * rr, cz + math.sin(a) * rr];
          }(),
      ];
    }
  }
}

/// Una mata con sus contornos ya calculados, para no rehacerlos en cada
/// fotograma.
class _MataHecha {
  _MataHecha(GroundTuft m)
    : x = m.x,
      z = m.z,
      kind = m.kind,
      reach = m.reach,
      contornos = [for (final b in m.blobs()) Float64List.fromList(b)];

  final double x, z, reach;
  final int kind;
  final List<Float64List> contornos;
}
