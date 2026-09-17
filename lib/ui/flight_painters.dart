import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/rng.dart';
import '../engine/palette.dart';
import 'flight_styles.dart';

/// Los diez dibujos del vuelo al valle.
///
/// Uno por estilo, y cada uno resuelve por su cuenta la única condición que
/// comparten: a mitad de camino la pantalla queda tapada del todo. Cada uno lo
/// consigue por construcción y no por suerte —una máscara con un agujero que
/// llega a cero, un macizo más hondo que la pantalla, una rejilla con menos paso
/// que radio— y hay un test que lo mide píxel a píxel en los diez.
void paintFlight(
  Canvas canvas,
  Size size,
  FlightStyle style,
  double t,
  Palette palette,
  int seed,
) {
  final cover = FlightPaint.coverOf(t);
  if (cover <= 0.001) return;
  final tone = FlightTones(palette);
  final hacia = FlightPaint.lightFrom(palette);
  final avance = t.clamp(0.0, 1.0);

  switch (style) {
    case FlightStyle.cumulos:
      _banks(canvas, size, avance, cover, tone, hacia, seed, vertical: true);
    case FlightStyle.cortina:
      _banks(canvas, size, avance, cover, tone, hacia, seed, vertical: false);
    case FlightStyle.ojo:
      _aperture(canvas, size, cover, tone, hacia, seed, twist: 0);
    case FlightStyle.remolino:
      _aperture(canvas, size, cover, tone, hacia, seed, twist: 2.6);
    case FlightStyle.cirros:
      _stripes(canvas, size, cover, tone, hacia, seed);
    case FlightStyle.niebla:
      _fog(canvas, size, avance, cover, tone, seed);
    case FlightStyle.algodon:
      _cotton(canvas, size, cover, tone, hacia, seed);
    case FlightStyle.nevada:
      _snow(canvas, size, avance, cover, tone, seed);
    case FlightStyle.picado:
      _dive(canvas, size, cover, tone, hacia, seed);
    case FlightStyle.tormenta:
      _storm(canvas, size, avance, cover, tone, seed);
  }
}

// --------------------------------------------------------------- 1 y 2

/// Dos bancos que se cierran: subiendo y bajando, o entrando de los lados.
///
/// **Macizo por dentro y con forma sólo en los cantos.** Empezó siendo una nube
/// de cúmulos sueltos, y en una pantalla alta y estrecha eso no tapa: el cúmulo
/// se mide contra el ancho —si no, no se lee como nube— y una pantalla de
/// teléfono tiene el doble de alto que de ancho, así que entre hilera e hilera
/// quedaban rendijas justo en el fotograma del corte. Relleno más cantos: el
/// hondo sale gratis y la forma está donde se ve.
void _banks(
  Canvas canvas,
  Size size,
  double t,
  double cover,
  FlightTones tone,
  Offset hacia,
  int seed, {
  required bool vertical,
}) {
  // El eje por el que se cierran, y el que cruza.
  final largo = vertical ? size.height : size.width;
  final hondo = largo * 1.15;
  final medida = size.width;

  for (var banco = 0; banco < 2; banco++) {
    final primero = banco == 0;
    // Tres pantallas de recorrido: en las puntas está entero fuera, y el
    // tapado sin rendijas va de t=0,3 a t=0,7.
    final centro = largo * (primero ? 2.0 - 3.0 * t : -1.0 + 3.0 * t);
    final cerca = centro - hondo / 2, lejos = centro + hondo / 2;
    if (lejos < -largo || cerca > largo * 2) continue;

    Rect franja(double a, double b) => vertical
        ? Rect.fromLTRB(-size.width, a, size.width * 2, b)
        : Rect.fromLTRB(a, -size.height, b, size.height * 2);

    canvas.drawRect(
      franja(cerca, lejos),
      Paint()
        ..shader = ui.Gradient.linear(
          vertical ? Offset(0, cerca) : Offset(cerca, 0),
          vertical ? Offset(0, lejos) : Offset(lejos, 0),
          [tone.luz, tone.medio, tone.sombra],
          [0.0, 0.48, 1.0],
        ),
    );

    // Masas grandes y flojas por dentro: cruzar un banco de nubes no es
    // quedarse mirando un rectángulo, son claros y oscuros pasando.
    for (var i = 0; i < 4; i++) {
      final s = hash32(seed, 0x11 + banco, i);
      final a = cerca + (lejos - cerca) * hashRange(0.05, 0.95, s, 2);
      final b = size.height * hashRange(-0.1, 1.1, s, 1);
      FlightPaint.blob(
        canvas,
        vertical ? Offset(b, a) : Offset(a, b),
        medida * hashRange(0.30, 0.55, s, 3),
        s,
        (hash01(s, 4) < 0.5 ? tone.luz : tone.sombra).withValues(alpha: 0.13),
      );
    }

    // Y los cúmulos de los dos cantos, que son los que rompen la raya recta.
    // Los dos y no sólo el de delante: al entrar se ve uno y al salir el otro,
    // y un banco que sale dejando un filo recto es un telón.
    for (var canto = 0; canto < 2; canto++) {
      final donde = canto == 0 ? cerca : lejos;
      if (donde < -largo * 0.5 || donde > largo * 1.5) continue;
      final delante = canto == 0;
      for (var i = 0; i < 6; i++) {
        final s = hash32(seed, banco * 2 + canto, i);
        final cruz =
            (vertical ? size.width : size.height) *
            ((i + 0.5) / 6 + hashJitter(0.08, s, 1));
        final r = medida * hashRange(0.17, 0.38, s, 3);
        final dentro = r * hashRange(-0.34, 0.16, s, 5) * (delante ? 1 : -1);
        FlightPaint.cumulus(
          canvas,
          vertical
              ? Offset(cruz, donde + dentro)
              : Offset(donde + dentro, cruz),
          r,
          s,
          tone,
          delante ? hacia : Offset(hacia.dx, -hacia.dy * 0.35),
          arriba: delante,
        );
      }
      // Jirones sueltos por delante: el borde de un banco de verdad no
      // termina, se deshilacha.
      for (var i = 0; i < 3; i++) {
        final s = hash32(seed, 0x33 + banco * 2 + canto, i);
        final cruz =
            (vertical ? size.width : size.height) * hashRange(0.0, 1.0, s, 1);
        final fuera = medida * hashRange(0.10, 0.30, s, 2);
        final r = medida * hashRange(0.07, 0.14, s, 3);
        final at = donde + (delante ? -fuera : fuera);
        _wisp(
          canvas,
          vertical ? Offset(cruz, at) : Offset(at, cruz),
          r,
          s,
          tone.medio.withValues(alpha: hashRange(0.5, 0.85, s, 4)),
        );
      }
    }
  }
}

/// Un jirón: dos óvalos estirados. Lo que se deshilacha del borde.
void _wisp(Canvas canvas, Offset at, double r, int s, Color color) {
  final path = Path();
  for (var k = 0; k < 2; k++) {
    path.addOval(
      Rect.fromCenter(
        center: at + Offset(r * (k == 0 ? -0.5 : 0.5), r * 0.12 * (k * 2 - 1)),
        width: r * hashRange(1.6, 2.6, s, 40 + k),
        height: r * hashRange(0.34, 0.6, s, 50 + k),
      ),
    );
  }
  canvas.drawPath(path, Paint()..color = color);
}

// --------------------------------------------------------------- 3 y 8

/// Un ojo de nube que se cierra sobre el centro, y que si [twist] no es cero
/// además gira: el remolino.
///
/// La pantalla entera está llena y lo que se dibuja es el **agujero**, que
/// mengua hasta cero. De ahí sale gratis la condición de tapar: cuando el
/// agujero vale cero, no queda nada sin pintar.
void _aperture(
  Canvas canvas,
  Size size,
  double cover,
  FlightTones tone,
  Offset hacia,
  int seed, {
  required double twist,
}) {
  final medio = Offset(size.width / 2, size.height / 2);
  final lejos = math.sqrt(size.width * size.width + size.height * size.height);
  // De más que la pantalla a nada. El 0,62 es lo que hace que a tapado cero el
  // agujero ya no quepa en el encuadre y no se vea un borde entrando.
  //
  // Y llega a cero **antes** de que el tapado llegue a uno: `_cerrado` es el
  // tapado estirado para que se agote al 85%. Sin eso, el agujero sólo está
  // del todo cerrado en el fotograma exacto de la mitad, y el corte de cámara
  // no es un fotograma: es un tramo, porque ni la animación cae en t=0,5 ni el
  // ojo perdona una rendija que se abre medio parpadeo antes de tiempo.
  final cerrado = (cover / 0.85).clamp(0.0, 1.0);
  final r = lejos * 0.62 * (1 - cerrado);
  final giro = twist * cover;

  // El hueco: un polígono de lóbulos, no un círculo. Un círculo perfecto que
  // se cierra es un diafragma de cámara; esto tiene que ser nube.
  final hueco = Path();
  const lados = 22;
  for (var i = 0; i <= lados; i++) {
    final a = i * 2 * math.pi / lados + giro;
    final rr = r * (0.82 + 0.18 * math.sin(i * 3.0 + giro * 1.7));
    final p = medio + Offset(math.cos(a) * rr, math.sin(a) * rr * 0.92);
    i == 0 ? hueco.moveTo(p.dx, p.dy) : hueco.lineTo(p.dx, p.dy);
  }
  hueco.close();

  // El relleno no es plano: va del tono de sombra junto al agujero al más
  // claro en los bordes de la pantalla. Eso es lo que hace que se lea como el
  // interior de algo y no como papel blanco con un recorte — plano, el ojo
  // cerrándose era un diafragma de cámara sobre una hoja.
  final relleno = Paint()
    ..shader = ui.Gradient.radial(
      medio,
      lejos * 0.62,
      [tone.sombra, tone.medio, tone.luz],
      const [0.0, 0.45, 1.0],
    );
  if (r < 0.5) {
    // Cerrado del todo: se pinta la pantalla y no se le resta nada. Restar un
    // polígono que ya no tiene área deja el borde suavizado de un punto, y un
    // punto suavizado en medio de la pantalla es exactamente la rendija.
    canvas.drawRect(Offset.zero & size, relleno);
  } else {
    final todo = Path()..addRect(Offset.zero & size);
    canvas.drawPath(
      Path.combine(PathOperation.difference, todo, hueco),
      relleno,
    );
  }

  // Y el borde del agujero, orlado de cúmulos: es lo único que se ve de cerca,
  // así que es donde va el detalle. El tamaño tiene un tope por arriba —la
  // pantalla— y otro por abajo —el propio hueco—: con sólo el primero, los
  // cúmulos del final se tragaban el agujero y lo que se veía cerrarse era un
  // bulto; con sólo el segundo, al principio son motas.
  if (r > 4) {
    for (var i = 0; i < 14; i++) {
      final s = hash32(seed, 0x51, i);
      final a = i * 2 * math.pi / 14 + giro + hashRange(0, 0.42, s, 1);
      final rr = r * hashRange(0.94, 1.14, s, 2);
      FlightPaint.cumulus(
        canvas,
        medio + Offset(math.cos(a) * rr, math.sin(a) * rr * 0.92),
        math.min(size.width * 0.26, r * 0.60) * hashRange(0.72, 1.0, s, 3),
        s,
        tone,
        hacia,
        // Los de abajo son panza y los de arriba cara: así el aro tiene un
        // arriba y un abajo, que es lo que le falta a un anillo para no
        // parecer una rosquilla.
        arriba: math.sin(a) < 0,
      );
    }
  }
}

// ----------------------------------------------------------------- 4

/// Nueve franjas finas que entran alternando izquierda y derecha.
///
/// Cuando todas están centradas se solapan —cada una es vez y media más alta
/// que su hueco— así que tapan. Antes de eso, la pantalla se lee a rayas, que
/// es lo que hace un cielo de cirros con viento.
void _stripes(
  Canvas canvas,
  Size size,
  double cover,
  FlightTones tone,
  Offset hacia,
  int seed,
) {
  const n = 9;
  final paso = size.height / n;
  final alto = paso * 1.55;
  // La raíz hace que entren rápido y frenen al llegar, que es lo que separa
  // una cortina de viento de un telón bajando.
  final dentro = math.sqrt(cover);
  for (var i = 0; i < n; i++) {
    final s = hash32(seed, 0x61, i);
    final dir = i.isEven ? 1.0 : -1.0;
    final off = dir * size.width * 1.7 * (1 - dentro);
    final y = paso * (i + 0.5);
    final r = Rect.fromCenter(
      center: Offset(size.width / 2 + off, y),
      width: size.width * 2.4,
      height: alto,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(alto * 0.5)),
      Paint()..color = tone.at(i % 3),
    );
    // Dos abultamientos por franja, para que no sea una pastilla.
    for (var k = 0; k < 2; k++) {
      FlightPaint.blob(
        canvas,
        Offset(
          size.width * hashRange(0.15, 0.85, s, 10 + k) + off,
          y + alto * hashRange(-0.18, 0.18, s, 20 + k),
        ),
        alto * hashRange(0.55, 0.85, s, 30 + k),
        hash32(s, k),
        tone.at((i + 1) % 3),
        aplanar: 0.42,
        lobes: 6,
      );
    }
  }
}

// ----------------------------------------------------------------- 5

/// Niebla: sin silueta ninguna. Se cierra y ya está.
///
/// La más callada de las diez y la única que no dibuja una sola nube. Lo que
/// hace el trabajo es el desenfoque, que en este estilo es el más fuerte de
/// todos; las manchas de debajo sólo evitan que sea un color plano.
void _fog(
  Canvas canvas,
  Size size,
  double t,
  double cover,
  FlightTones tone,
  int seed,
) {
  // El velo llega a opaco antes que el tapado a uno, por lo mismo que el ojo
  // se cierra antes: lo que tiene que estar tapado es el tramo del corte, no
  // su punto medio.
  canvas.drawRect(
    Offset.zero & size,
    Paint()..color = tone.medio.withValues(alpha: math.min(1.0, cover * 1.4)),
  );
  for (var i = 0; i < 6; i++) {
    final s = hash32(seed, 0x71, i);
    final deriva = size.width * (hashRange(-0.5, 0.5, s, 5)) * t;
    FlightPaint.blob(
      canvas,
      Offset(
        size.width * hashRange(-0.2, 1.2, s, 1) + deriva,
        size.height * hashRange(-0.1, 1.1, s, 2),
      ),
      size.width * hashRange(0.5, 0.95, s, 3),
      s,
      (hash01(s, 4) < 0.5 ? tone.luz : tone.sombra).withValues(
        alpha: cover * 0.30,
      ),
      aplanar: 0.55,
      lobes: 6,
    );
  }
}

// ----------------------------------------------------------------- 6

/// Un campo de bolas blandas que se junta hasta no dejar hueco.
///
/// Cada bola tiene su sitio en una rejilla y llega a él desde donde estaba
/// desperdigada. Como el paso de la rejilla es menor que el radio, cuando
/// todas están en su sitio no queda hueco: tapar sale de la cuenta, no del
/// tanteo.
void _cotton(
  Canvas canvas,
  Size size,
  double cover,
  FlightTones tone,
  Offset hacia,
  int seed,
) {
  const cols = 5;
  final filas = math.max(3, (size.height / (size.width / cols) + 1).ceil());
  final paso = size.width / cols;
  final r = paso * 0.95;
  final medio = Offset(size.width / 2, size.height / 2);
  final lejos = math.sqrt(size.width * size.width + size.height * size.height);
  // Llegan todas a la vez y **antes** de que el tapado llegue a uno, que es lo
  // que hace que el corte caiga con el campo ya cerrado y no justo al cerrarse.
  //
  // La primera versión las mandaba lejos multiplicando su distancia al centro,
  // y las del medio no se movían: la pantalla salía tapada desde el principio.
  // Salen despedidas en línea recta hacia afuera y todas la misma distancia.
  final llegada = math.pow((cover / 0.85).clamp(0.0, 1.0), 0.7).toDouble();
  for (var fy = -1; fy <= filas; fy++) {
    for (var fx = -1; fx <= cols; fx++) {
      final s = hash32(seed, fx + 7, fy + 7);
      final sitio = Offset(paso * (fx + 0.5), paso * (fy + 0.5));
      // De dónde viene: de fuera del encuadre, derecha hacia afuera. El ángulo
      // lo da su sitio, con un empujón al azar para que no salgan de un abanico
      // perfecto; la distancia es la misma para todas, así que ninguna se queda
      // en el centro sin moverse.
      final d = sitio - medio;
      final a =
          math.atan2(d.dy, d.dx == 0 && d.dy == 0 ? 1.0 : d.dx) +
          hashJitter(0.5, s, 4);
      final fuera =
          medio +
          Offset(math.cos(a), math.sin(a)) *
              (lejos * hashRange(0.80, 1.15, s, 5));
      final at = Offset.lerp(fuera, sitio, llegada)!;
      final grande = r * hashRange(1.0, 1.22, s, 2);
      canvas.drawCircle(at, grande, Paint()..color = tone.sombra);
      canvas.drawCircle(
        at + hacia * (grande * 0.16),
        grande * 0.80,
        Paint()..color = tone.medio,
      );
      canvas.drawCircle(
        at + hacia * (grande * 0.34),
        grande * 0.50,
        Paint()..color = tone.luz,
      );
    }
  }
}

// ----------------------------------------------------------------- 7

/// Una nevada que blanquea la pantalla.
///
/// Los copos no tapan nada —son copos— así que lo que tapa es el blanqueo, que
/// es lo que hace una ventisca de verdad: primero se ve nevar y después deja de
/// verse todo lo demás.
void _snow(
  Canvas canvas,
  Size size,
  double t,
  double cover,
  FlightTones tone,
  int seed,
) {
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..color = tone.luz.withValues(
        // Al cuadrado y pico para que el blanqueo llegue tarde —una ventisca
        // arranca dejando ver— pero con holgura de sobra para llegar a opaco
        // dentro del tramo del corte.
        alpha: math.min(1.0, math.pow(cover, 1.5).toDouble() * 1.45),
      ),
  );
  const cuantos = 120;
  for (var i = 0; i < cuantos; i++) {
    final s = hash32(seed, 0x81, i);
    final cerca = hash01(s, 9);
    final baja = (hashRange(0.2, 1.0, s, 1) + t * (1.2 + cerca * 2.2)) % 1.4;
    final at = Offset(
      size.width *
          (hashRange(0.0, 1.0, s, 2) +
              math.sin(t * 6 + hashRange(0, 6.2, s, 3)) * 0.035),
      size.height * (baja - 0.2),
    );
    final gordo = size.width * (0.007 + cerca * 0.026);
    final tinta = Paint()
      ..color = tone.luz.withValues(
        alpha: (0.35 + cerca * 0.6) * math.min(1, cover * 2.4),
      );
    canvas.drawCircle(at, gordo, tinta);
    // Los de delante caen deprisa y dejan un rastro corto. Sin él son puntos
    // quietos pegados a la pantalla; con él, la ventisca tiene velocidad.
    if (cerca > 0.55) {
      canvas.drawLine(
        at,
        at - Offset(0, gordo * (3 + cerca * 5)),
        tinta
          ..strokeCap = StrokeCap.round
          ..strokeWidth = gordo * 1.1,
      );
    }
  }
}

// ----------------------------------------------------------------- 9

/// Un picado: la nube viene de frente y se te echa encima.
///
/// Un disco que crece desde el centro hasta pasarse de la pantalla, con anillos
/// de cúmulos alrededor que salen despedidos hacia afuera. Tapa porque el disco
/// acaba siendo más grande que la diagonal.
void _dive(
  Canvas canvas,
  Size size,
  double cover,
  FlightTones tone,
  Offset hacia,
  int seed,
) {
  final medio = Offset(size.width / 2, size.height / 2);
  final lejos = math.sqrt(size.width * size.width + size.height * size.height);
  // La diagonal por 0,62 es más que el radio que hace falta para tapar (medio
  // diagonal), así que el disco tapa desde bastante antes de la mitad: al 75%
  // de tapado ya no se ve nada, y el corte va con margen por los dos lados.
  final r = lejos * 0.62 * math.pow(cover, 0.75).toDouble();

  // Los anillos primero, que van por delante del frente.
  for (var anillo = 2; anillo >= 1; anillo--) {
    final rr = r * (1 + anillo * 0.34);
    if (rr < 1) continue;
    for (var i = 0; i < 9; i++) {
      final s = hash32(seed, 0x91 + anillo, i);
      final a = i * 2 * math.pi / 9 + hashRange(0, 0.7, s, 1) + anillo * 0.5;
      FlightPaint.cumulus(
        canvas,
        medio + Offset(math.cos(a) * rr, math.sin(a) * rr * 0.9),
        math.min(rr, size.width) * hashRange(0.20, 0.34, s, 2),
        s,
        tone,
        hacia,
      );
    }
  }
  if (r > 0.5) {
    canvas.drawCircle(medio, r, Paint()..color = tone.medio);
    canvas.drawCircle(
      medio + hacia * (r * 0.22),
      r * 0.62,
      Paint()..color = tone.luz,
    );
  }
}

// ---------------------------------------------------------------- 10

/// Un chaparrón: gris, con la lluvia cruzando.
///
/// El único de los diez que no es pastel, y es a propósito: un aguacero que no
/// oscurece no es un aguacero. Tapa por el velo de plomo; la lluvia y las
/// panzas de nube que bajan son lo que se mira mientras tanto.
void _storm(
  Canvas canvas,
  Size size,
  double t,
  double cover,
  FlightTones tone,
  int seed,
) {
  canvas.drawRect(
    Offset.zero & size,
    Paint()..color = tone.plomo.withValues(alpha: math.min(1.0, cover * 1.4)),
  );
  // Las panzas, bajando desde arriba.
  for (var i = 0; i < 5; i++) {
    final s = hash32(seed, 0xA1, i);
    FlightPaint.blob(
      canvas,
      Offset(
        size.width * hashRange(-0.1, 1.1, s, 1),
        size.height * (hashRange(-0.45, -0.05, s, 2) + cover * 0.55),
      ),
      size.width * hashRange(0.40, 0.70, s, 3),
      s,
      Color.lerp(
        tone.plomo,
        tone.sombra,
        hash01(s, 4) * 0.6,
      )!.withValues(alpha: math.min(1, cover * 1.6)),
      aplanar: 0.5,
    );
  }
  // Y la lluvia, que va inclinada y a distintas velocidades.
  final lluvia = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = size.width * 0.005;
  for (var i = 0; i < 90; i++) {
    final s = hash32(seed, 0xB1, i);
    final cerca = hash01(s, 9);
    final baja = (hashRange(0.0, 1.0, s, 1) + t * (2.4 + cerca * 3.4)) % 1.35;
    final x =
        size.width * hashRange(-0.15, 1.15, s, 2) + baja * size.width * 0.2;
    final y = size.height * (baja - 0.25);
    final largo = size.height * (0.05 + cerca * 0.10);
    canvas.drawLine(
      Offset(x, y),
      Offset(x - largo * 0.22, y + largo),
      lluvia
        ..color = tone.luz.withValues(
          alpha: (0.18 + cerca * 0.42) * math.min(1, cover * 2.2),
        ),
    );
  }
}
