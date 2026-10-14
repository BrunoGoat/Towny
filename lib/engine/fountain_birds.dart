/// Los pájaros que bajan a beber a la fuente.
///
/// Cada tanto llega uno —a veces dos a la vez—, se posa en el borde del
/// pilón, bebe un par de veces, mira alrededor, da algún saltito por el
/// brocal y se va. No vienen a cuento de nada ni hacen nada: son lo que hace
/// que una plaza esté viva cuando no pasa nadie.
///
/// Todo sale de la hora, como el agua: dónde está cada pájaro es una cuenta
/// sobre `time`, sin estado, así que dos fotogramas seguidos se ponen de
/// acuerdo solos y un pájaro no se teletransporta al volver a la app.
library;

import 'dart:math' as math;

import '../core/math3.dart';
import '../core/rng.dart';
import 'bsp.dart';
import 'palette.dart';
import 'solid.dart';
import 'solids.dart';
import 'town.dart';

/// Lo que hace un pájaro en un instante.
enum BirdDoing { away, arriving, perched, leaving }

/// Dónde está y qué hace un pájaro de la fuente en el segundo [time].
///
/// [slot] es cuál de los que pueden venir (ver [fountainBirdSlots]). Cada uno
/// tiene su ciclo —de medio minuto largo a casi un minuto— y en cada vuelta
/// del ciclo viene o no, se queda más o menos y se posa en otro sitio.
class BirdVisit {
  const BirdVisit({
    required this.doing,
    required this.at,
    required this.heading,
    this.pitch = 0,
    this.look = 0,
    this.flap = 0,
    this.lean = 0,
    this.crouch = 0,
    this.reach = 0,
    this.tail = 0,
    this.wings = 0,
    this.kind = 0,
    this.size = 1,
  });

  static const none = BirdVisit(doing: BirdDoing.away, at: V3.zero, heading: 0);

  final BirdDoing doing;

  /// Los pies, en el mundo.
  final V3 at;

  /// Hacia dónde mira el cuerpo, en el plano: el ángulo de su frente.
  final double heading;

  /// Cuánto baja el pico, en radianes: beber es esto.
  final double pitch;

  /// Cuánto gira la cabeza a un lado o al otro.
  final double look;

  /// Cuánto se inclina el cuerpo hacia delante desde la cadera.
  final double lean;

  /// Cuánto dobla las patas, en alturas de pájaro: agacharse para llegar.
  final double crouch;

  /// Cuánto estira el cuello hacia delante.
  final double reach;

  /// Cuánto levanta la cola: el contrapeso de agacharse.
  final double tail;

  /// Cuánto separa las alas del cuerpo, posado: un sacudón al terminar.
  final double wings;

  /// Las alas: cero plegadas, y en vuelo, el batir de menos uno a uno.
  final double flap;

  /// Qué pájaro es: gorrión, paloma o petirrojo.
  final int kind;

  /// Su tamaño, que no es igual para todos.
  final double size;
}

/// Cuántos pájaros distintos pueden andar por la fuente.
const int fountainBirdSlots = 3;

/// Lo que dura la llegada, la partida —el despegue y la subida— y cada cosa
/// que hace posado, en segundos. Todo despacio: esta app se mira, no se usa,
/// y un pájaro que pica el agua a toda prisa es un pájaro con miedo.
const double _llega = 6.0, _despega = 3.0, _compas = 5.6;

BirdVisit birdVisit(TownLayout l, int slot, double time, {bool day = true}) {
  // Cada pájaro tiene su ciclo, largo: de minuto y medio a casi tres, y en
  // casi la mitad de las vueltas no viene. Una visita cada minuto y pico en
  // toda la plaza, y no tres a la vez.
  final ciclo = 90.0 + slot * 35.0 + hash01(slot, l.cx.round(), 3) * 20;
  final reloj = time / ciclo + hash01(slot, 41) + slot * 0.37;
  final vuelta = reloj.floor();
  final u = (reloj - vuelta) * ciclo;
  if (!day || hash01(slot, vuelta, 1) < 0.45) return BirdVisit.none;
  // Cuántas cosas hace antes de aburrirse: beber, mirar, algún saltito.
  final cosas = 5 + hashInt(6, slot, vuelta, 2);
  final queda = cosas * _compas;
  // Y no hay un final de visita: el que se va sigue volando, cada vez más
  // lejos y más alto, hasta que empieza la vuelta siguiente. Para entonces
  // está a decenas de metros, fuera de cualquier cuadro.

  final cx = l.cx, cz = l.cz;
  final taza = Plaza.basinOf(TownLayout.plazaReach) / 1.14;
  const brocal = 0.40;
  final kind = hashInt(3, slot, vuelta, 4);
  final size =
      (kind == 1 ? 1.30 : 1.0) * (0.92 + 0.16 * hash01(slot, vuelta, 5));

  // Dónde se posa: en el brocal, en un sitio de la vuelta que cambia cada
  // visita, y cada pájaro en su tercio para que dos no caigan uno encima del
  // otro.
  final sitio =
      slot * 2 * math.pi / fountainBirdSlots +
      (hash01(slot, vuelta, 6) - 0.5) * 1.6;
  final r = taza * 0.85;

  // Lo que hace en cada compás, y lo que avanzó saltando hasta ahora.
  int que(int j) {
    if (j == 0) return 0; // lo primero, siempre, beber
    final h = hash01(slot, vuelta, j, 7);
    return h < 0.62 ? 0 : (h < 0.88 ? 1 : 2); // beber, mirar, saltar
  }

  double salto(int j) => (hash01(slot, vuelta, j, 8) - 0.5) * 0.24;

  final quieto = (u - _llega).clamp(0.0, queda - 1e-6);
  final paso = (quieto / _compas).floor();
  var corrido = 0.0;
  for (var j = 0; j < paso; j++) {
    if (que(j) == 2) corrido += salto(j);
  }
  final f = (quieto - paso * _compas) / _compas;
  final posadoYa = u >= _llega && u < _llega + queda;
  final hace = posadoYa ? que(paso) : 0;
  var ang = sitio + corrido / r;
  var alto = 0.0;
  // Un saltito: sube y baja en [desde, hasta] del compás, con el golpe seco
  // de caer.
  double brinco(double desde, double hasta) {
    final a = clampD((f - desde) / (hasta - desde), 0, 1);
    return 4 * a * (1 - a) * 0.022 * size;
  }

  if (hace == 2) {
    // De costado no se desliza: va a saltitos, tres, cada uno un tercio.
    const n = 3;
    final g = clampD((f - 0.1) / 0.6, 0, 1) * n;
    final k = math.min(g.floor(), n - 1);
    final dentro = g - k;
    final avance = (k + smoothstep(0.15, 0.85, dentro)) / n;
    ang += salto(paso) * avance / r;
    if (g < n) alto = 4 * dentro * (1 - dentro) * 0.022 * size;
  }
  // Para beber se arrima al agua de un saltito, y al terminar —si lo que
  // sigue no es volver a beber— vuelve de otro.
  var rr = r;
  if (posadoYa && hace == 0) {
    const arrimo = 0.03;
    final venia = paso > 0 && que(paso - 1) == 0;
    final sigue = paso + 1 < cosas && que(paso + 1) == 0;
    final ida = venia ? 1.0 : smoothstep(0.0, 0.10, f);
    final vuelta = sigue ? 0.0 : smoothstep(0.90, 1.0, f);
    rr -= arrimo * (ida - vuelta);
    if (!venia) alto += brinco(0.0, 0.10);
    if (!sigue) alto += brinco(0.90, 1.0);
  }
  final posado = V3(
    cx + math.cos(ang) * rr,
    brocal + alto,
    cz + math.sin(ang) * rr,
  );
  // Mirando al agua, o un poco de lado.
  final alAgua = math.atan2(cz - posado.z, cx - posado.x);
  final lado = (hash01(slot, vuelta, paso, 9) - 0.5) * 1.0;

  if (u < _llega) {
    // Baja desde lo alto —de donde la cámara no mira—, planeando, y frena al
    // final abriendo las alas.
    final t = u / _llega;
    // Suave al empezar y al acabar: arriba no tiene por qué ir rápido, y
    // abajo se posa.
    final e = t * t * (3 - 2 * t);
    final desde = sitio + 1.0 * (hash01(slot, vuelta, 10) < 0.5 ? -1 : 1);
    final a = V3(
      cx + math.cos(desde) * 2.6,
      9.0 + 2 * hash01(slot, vuelta, 11),
      cz + math.sin(desde) * 2.6,
    );
    final ctrl = V3((a.x + posado.x) / 2, posado.y + 1.0, (a.z + posado.z) / 2);
    final p = _bezier(a, ctrl, posado, e);
    final q = _bezier(a, ctrl, posado, math.min(1, e + 0.02));
    final rumbo = math.atan2(q.z - p.z, q.x - p.x);
    // Bate despacio, planea a ratos, y abre las alas para frenar al final.
    final ala = math.sin(time * 16 + slot);
    final planea = 0.35 + 0.65 * smoothstep(-0.2, 0.6, math.sin(time * 0.9));
    final bate = t < 0.8
        ? ala * planea
        : lerpD(ala * planea, 0.9, smoothstep(0.8, 1.0, t));
    return BirdVisit(
      doing: BirdDoing.arriving,
      at: p,
      heading: t > 0.85
          ? _mezclaAng(rumbo, alAgua, smoothstep(0.85, 1, t))
          : rumbo,
      flap: bate,
      kind: kind,
      size: size,
    );
  }

  final fuera = u - _llega - queda;
  if (fuera >= 0) {
    // Se va como vino pero al revés: primero sale del brocal hacia un lado y
    // hacia arriba, y después sube y sube, hasta donde la cámara no mira. No
    // desaparece: se va.
    final hacia = ang + 1.2 * (hash01(slot, vuelta, 12) < 0.5 ? -1 : 1);
    final b = V3(
      cx + math.cos(hacia) * 1.7,
      1.5 + 0.4 * hash01(slot, vuelta, 13),
      cz + math.sin(hacia) * 1.7,
    );
    final ctrl = V3(posado.x, posado.y + 0.45, posado.z);
    V3 despegue(double t) => _bezier(posado, ctrl, b, t * t);
    final bate = math.sin(time * 18 + slot);
    if (fuera < _despega) {
      final t = fuera / _despega;
      final p = despegue(t);
      final q = despegue(math.min(1, t + 0.02));
      final rumbo = math.atan2(q.z - p.z, q.x - p.x);
      return BirdVisit(
        doing: BirdDoing.leaving,
        at: p,
        heading: _mezclaAng(alAgua + lado * 0.5, rumbo, smoothstep(0, 0.2, t)),
        flap: bate,
        kind: kind,
        size: size,
      );
    }
    // La subida: en diagonal, no derecho para arriba —un pájaro no es un
    // globo—, alejándose y subiendo a la vez, con una curva suave. La
    // velocidad que traía del despegue se va convirtiendo en la de crucero
    // sin saltos: el sitio es la integral de esa mezcla.
    final vel = (b - ctrl) * (2 / _despega);
    final tau = fuera - _despega;
    const tau0 = 1.4;
    final mezcla = tau0 * (1 - math.exp(-tau / tau0));
    final giro = (hash01(slot, vuelta, 14) - 0.5) * 0.04;
    final rumbo0 = hacia + giro * tau * 0.5;
    final crucero = V3(math.cos(rumbo0) * 1.5, 0.95, math.sin(rumbo0) * 1.5);
    final p = b + vel * mezcla + crucero * (tau - mezcla);
    final ahora =
        vel * math.exp(-tau / tau0) + crucero * (1 - math.exp(-tau / tau0));
    final planea =
        0.35 + 0.65 * smoothstep(-0.3, 0.5, math.sin(time * 0.8 + slot));
    return BirdVisit(
      doing: BirdDoing.leaving,
      at: p,
      heading: math.atan2(ahora.z, ahora.x),
      flap: bate * planea,
      kind: kind,
      size: size,
    );
  }

  // Posado, haciendo lo de este compás.
  var pitch = 0.0, look = 0.0, lean = 0.0, crouch = 0.0, reach = 0.0;
  var tail = 0.0, wings = 0.0;
  switch (hace) {
    case 0:
      // Beber, que en un pájaro es todo el cuerpo: dobla las patas, se
      // inclina, levanta la cola de contrapeso y estira el cuello hasta que
      // el pico toca el agua. Ahí da unos sorbitos —el pico va y viene— y
      // después levanta la cabeza bien alta para que el trago baje, porque
      // los pájaros no saben sorber: tragan con la cabeza para arriba. Al
      // final, a veces, se sacude las alas.
      final baja = smoothstep(0.08, 0.30, f) * (1 - smoothstep(0.46, 0.66, f));
      final sorbo =
          baja * math.sin(clampD((f - 0.30) / 0.20, 0, 1) * math.pi * 3);
      final alza = smoothstep(0.64, 0.76, f) * (1 - smoothstep(0.84, 0.94, f));
      final trago =
          alza * math.sin(clampD((f - 0.76) / 0.08, 0, 1) * math.pi * 2);
      pitch = 1.40 * baja + 0.08 * sorbo - 0.55 * alza + 0.06 * trago;
      lean = 0.85 * baja - 0.10 * alza;
      crouch = 0.45 * baja;
      reach = 1.10 * baja + 0.12 * sorbo;
      tail = 0.55 * baja;
      if (hash01(slot, vuelta, paso, 16) < 0.5) {
        wings =
            math.sin(clampD((f - 0.84) / 0.12, 0, 1) * math.pi * 3).abs() *
            smoothstep(0.84, 0.86, f);
      }
    case 1:
      // Mirar: gira la cabeza a un lado, se queda mirando, y vuelve.
      final gira = smoothstep(0.1, 0.35, f) * (1 - smoothstep(0.7, 0.92, f));
      look = gira * (hash01(slot, vuelta, paso, 15) < 0.5 ? 0.75 : -0.75);
  }
  return BirdVisit(
    doing: BirdDoing.perched,
    at: posado,
    heading: alAgua + (hace == 2 ? 0 : lado * 0.5),
    pitch: pitch,
    look: look,
    lean: lean,
    crouch: crouch,
    reach: reach,
    tail: tail,
    wings: wings,
    kind: kind,
    size: size,
  );
}

V3 _bezier(V3 a, V3 b, V3 c, double t) {
  final s = 1 - t;
  return a * (s * s) + b * (2 * s * t) + c * (t * t);
}

double _mezclaAng(double a, double b, double t) {
  var d = (b - a) % (2 * math.pi);
  if (d > math.pi) d -= 2 * math.pi;
  return a + d * t;
}

/// Los colores de cada pájaro: cuerpo, pecho, alas, cabeza y pico.
const _plumas = [
  // Gorrión: pardo, el pecho claro y una gorra más oscura.
  (0xFF8A6A4C, 0xFFC9B79C, 0xFF6A4E36, 0xFF6E5A48, 0xFF3A2F25),
  // Paloma: gris, el cuello un poco más oscuro.
  (0xFFA5A8AE, 0xFFB9BCC2, 0xFF8D9097, 0xFF7E838C, 0xFF4A3F3A),
  // Petirrojo: pardo con el pecho naranja.
  (0xFF7D6650, 0xFFD9793F, 0xFF66523F, 0xFF7D6650, 0xFF2E2620),
];

/// Las caras de los pájaros que andan por la fuente ahora, cada una con su
/// distancia al ojo para que se ordenen con el agua.
void fountainBirds(
  TownLayout l,
  V3 eye,
  double time,
  Palette pal,
  void Function(double lejos, List<Facet> caras) pon, {
  bool Function(V3 at, double radius)? seen,
}) {
  final dia = pal.isDaylight && pal.daylight > 0.25;
  for (var k = 0; k < fountainBirdSlots; k++) {
    final v = birdVisit(l, k, time, day: dia);
    if (v.doing == BirdDoing.away) continue;
    if (seen != null && !seen(v.at, 0.10 * v.size)) continue;
    final caras = birdFaces(v, eye);
    if (caras.isEmpty) continue;
    pon((v.at - eye).length - 0.02, caras);
  }
}

/// Un pájaro hecho de cajitas: cuerpo, pecho, cabeza, pico, cola y dos alas.
List<Facet> birdFaces(BirdVisit v, V3 eye) {
  final (cuerpo, pecho, alas, cabeza, pico) = _plumas[v.kind];
  final s = 0.034 * v.size;
  final f = V3(math.cos(v.heading), 0, math.sin(v.heading));
  final rr = V3(-f.z, 0, f.x);
  const up = V3(0, 1, 0);
  final vuela = v.doing != BirdDoing.perched;
  // Posado, el cuerpo va un poco levantado de pecho; volando, horizontal.
  // Lo demás lo dice lo que esté haciendo: cuánto se inclina, se agacha,
  // estira el cuello, levanta la cola o separa las alas.
  final tronco = vuela ? 0.0 : -0.25 + v.lean;
  final cuello = vuela ? 0.0 : v.pitch;
  final agacha = vuela ? 0.0 : v.crouch;
  final cadera = (0.0, 1.0 - agacha);
  const nuca = (1.15, 2.2), rabadilla = (-1.3, 1.9);

  (double, double) gira(double x, double y, (double, double) o, double a) {
    if (a == 0) return (x, y);
    final c = math.cos(a), sn = math.sin(a);
    final dx = x - o.$1, dy = y - o.$2;
    return (o.$1 + dx * c + dy * sn, o.$2 - dx * sn + dy * c);
  }

  // Del espacio del pájaro —x adelante, y arriba, z a la derecha, en `s`— al
  // mundo. Cada parte se mueve a su manera y después todas con el cuerpo:
  // las patas no se mueven —sólo se doblan, que es acortarlas—; el cuerpo
  // baja lo que se agacha y se inclina alrededor de la cadera; la cabeza
  // gira para mirar, se estira hacia delante y baja alrededor de la nuca; la
  // cola sube alrededor de la rabadilla, y las alas se abren desde el lomo.
  V3 mundo(double x, double y, double z, {int parte = 1, bool estira = true}) {
    if (parte == 0) return v.at + f * (x * s) + up * (y * s) + rr * (z * s);
    if (parte == 2) {
      if (v.look != 0) {
        final dx = x - nuca.$1;
        final c = math.cos(v.look), sn = math.sin(v.look);
        x = nuca.$1 + dx * c - z * sn;
        z = dx * sn + z * c;
      }
      if (estira && !vuela) x += v.reach;
      (x, y) = gira(x, y, nuca, cuello);
    } else if (parte == 3) {
      (x, y) = gira(x, y, rabadilla, vuela ? 0 : v.tail);
    } else if (parte == 4 && !vuela && v.wings != 0) {
      // El ala gira hacia fuera alrededor del borde del lomo.
      final lado = z < 0 ? -1.0 : 1.0;
      final a = v.wings * 0.9;
      final dy = y - 2.4, dz = z - lado * 0.55;
      final c = math.cos(a), sn = math.sin(a);
      y = 2.4 + dy * c + dz * lado * sn;
      z = lado * 0.55 + dz * c - dy * lado * sn;
    }
    y -= agacha;
    (x, y) = gira(x, y, cadera, tronco);
    return v.at + f * (x * s) + up * (y * s) + rr * (z * s);
  }

  final out = <Facet>[];

  /// Un sólido de ocho esquinas, en el orden de [hexFaces], sin las caras
  /// que miran para el otro lado.
  void solido(
    List<(double, double, double)> esquinas,
    int tinte, {
    int parte = 1,
    bool Function(double x)? estira,
  }) {
    final c = [
      for (final (x, y, z) in esquinas)
        mundo(x, y, z, parte: parte, estira: estira?.call(x) ?? true),
    ];
    for (final cara in hexFaces(c, Surface.own, tint: tinte)) {
      final a = cara.v.first;
      if ((eye - a).dot(cara.n) <= 0) continue;
      out.add(cara..piece = -1);
    }
  }

  void caja(
    double x0,
    double x1,
    double y0,
    double y1,
    double z0,
    double z1,
    int tinte, {
    int parte = 1,
  }) {
    solido(
      [
        (x0, y0, z0),
        (x1, y0, z0),
        (x1, y0, z1),
        (x0, y0, z1),
        (x0, y1, z0),
        (x1, y1, z0),
        (x1, y1, z1),
        (x0, y1, z1),
      ],
      tinte,
      parte: parte,
    );
  }

  // Las patas, posado: dos palitos.
  if (!vuela) {
    final rodilla = 1.0 - agacha;
    caja(-0.15, 0.05, 0, rodilla, -0.45, -0.25, pico, parte: 0);
    caja(-0.15, 0.05, 0, rodilla, 0.25, 0.45, pico, parte: 0);
  }
  // El cuerpo: más alto y más ancho delante, donde va el pecho, y más fino
  // hacia la cola, que es lo que hace que un taco se lea como un pájaro.
  solido([
    (-1.5, 1.35, -0.48),
    (1.3, 0.8, -0.78),
    (1.3, 0.8, 0.78),
    (-1.5, 1.35, 0.48),
    (-1.5, 2.25, -0.48),
    (1.3, 2.5, -0.78),
    (1.3, 2.5, 0.78),
    (-1.5, 2.25, 0.48),
  ], cuerpo);
  // Y el pecho, del color del pecho, asomando por delante y por debajo.
  caja(0.1, 1.42, 0.72, 1.85, -0.62, 0.62, pecho);
  // La cola, fina y hacia atrás.
  caja(-2.6, -1.2, 1.6, 1.9, -0.45, 0.45, alas, parte: 3);
  // La cabeza con su pico.
  caja(0.9, 2.1, 2.0, 3.1, -0.6, 0.6, cabeza, parte: 2);
  // Y el cuello, que sólo se ve cuando se estira: va del lomo a la cabeza,
  // con la punta de atrás quieta y la de delante con la cabeza.
  if (!vuela && v.reach > 0.05) {
    solido(
      [
        (0.7, 1.95, -0.42),
        (1.3, 1.95, -0.42),
        (1.3, 1.95, 0.42),
        (0.7, 1.95, 0.42),
        (0.7, 2.6, -0.42),
        (1.3, 2.6, -0.42),
        (1.3, 2.6, 0.42),
        (0.7, 2.6, 0.42),
      ],
      cabeza,
      parte: 2,
      estira: (x) => x > 1.0,
    );
  }
  caja(2.1, 2.9, 2.35, 2.65, -0.15, 0.15, pico, parte: 2);
  // Las alas: plegadas sobre el lomo posado; en vuelo, abiertas y batiendo
  // desde el hombro.
  if (!vuela) {
    caja(-1.6, 0.9, 1.6, 2.5, -0.85, -0.55, alas, parte: 4);
    caja(-1.6, 0.9, 1.6, 2.5, 0.55, 0.85, alas, parte: 4);
  } else {
    final alzar = v.flap * 0.9;
    for (final lado in [-1.0, 1.0]) {
      // Un ala es una tabla que sale del hombro: la punta sube y baja.
      const largo = 3.2;
      final c = math.cos(alzar), sn = math.sin(alzar);
      V3 m(double x, double y, double z) => mundo(x, y, z);
      final raiz0 = m(-0.9, 2.2, lado * 0.6), raiz1 = m(0.8, 2.2, lado * 0.6);
      final punta0 = m(-1.4, 2.2 + sn * largo, lado * (0.6 + c * largo));
      final punta1 = m(0.2, 2.2 + sn * largo, lado * (0.6 + c * largo));
      final v4 = [raiz0, raiz1, punta1, punta0];
      var n = (raiz1 - raiz0).cross(punta0 - raiz0).normalized;
      final mid = (raiz0 + punta1) * 0.5;
      if (n.dot(eye - mid) < 0) n = n * -1;
      out.add(Facet(v4, n, Surface.own, tint: alas)..piece = -1);
    }
  }
  // **En orden de árbol, no en el orden en que se armaron.** Pintadas tal
  // cual, la cabeza salía siempre después del cuerpo y el pico después de la
  // cabeza: mirado desde atrás, la cabeza tapaba el cuerpo —el pájaro se
  // quedaba sin tronco— y el pico se veía a través de ella. El árbol de
  // planos ordena cada cara contra las demás desde donde está el ojo, igual
  // que a la gente de cerca.
  final ordenadas = <Facet>[];
  BspTree.build(out).paint(eye, ordenadas.add);
  return ordenadas;
}
