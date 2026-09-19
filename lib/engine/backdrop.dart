import 'dart:math' as math;
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
          ..shader = ui.Gradient.linear(
            Offset(0, hy - h * 0.22),
            Offset(0, hy),
            [
              pal.skyHorizon.withValues(alpha: 0),
              pal.haze.withValues(alpha: 0.85),
            ],
          ),
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
      var crest = size.height;
      for (var i = 0; i <= steps; i++) {
        final th = az - span + (i / steps) * (span * 2);
        final dx = math.sin(th), dz = math.cos(th);
        final h = Landscape.ridgeHeight(
          layer,
          look + dx * layer.radius,
          dz * layer.radius,
        );
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
    }

    canvas.restore();
  }

  // ----------------------------------------------------------------- ghost

  void drawAtmosphere(Canvas canvas, Size size, double horizonY) {
    final pal = scene.palette;
    final decay = 1 - scene.integrity;
    if (decay > 0.05) {
      // A town left alone does not fog over, it goes cold and quiet. Grey mist
      // reads as bad visibility; a cold, dim town reads as nobody home.
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = Color.lerp(
            pal.ink,
            const Color(0xFF3E4758),
            0.55,
          )!.withValues(alpha: 0.06 + decay * 0.20),
      );
    }
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
