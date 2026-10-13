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

  /// Las alas: cero plegadas, y en vuelo, el batir de menos uno a uno.
  final double flap;

  /// Qué pájaro es: gorrión, paloma o petirrojo.
  final int kind;

  /// Su tamaño, que no es igual para todos.
  final double size;
}

/// Cuántos pájaros distintos pueden andar por la fuente.
const int fountainBirdSlots = 3;

/// Lo que dura la llegada y la partida, en segundos.
const double _llega = 2.4, _parte = 2.6;

BirdVisit birdVisit(TownLayout l, int slot, double time, {bool day = true}) {
  final ciclo = 34.0 + slot * 13.0 + hash01(slot, l.cx.round(), 3) * 9;
  final reloj = time / ciclo + hash01(slot, 41) + slot * 0.37;
  final vuelta = reloj.floor();
  final u = (reloj - vuelta) * ciclo;
  // Una de cada tres vueltas no viene: así no es un reloj.
  if (!day || hash01(slot, vuelta, 1) < 0.40) return BirdVisit.none;
  final queda = 6.0 + 9.0 * hash01(slot, vuelta, 2);
  final total = _llega + queda + _parte;
  if (u >= total) return BirdVisit.none;

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

  // Los saltitos por el brocal: cada segundo y pico decide qué hace, y lo
  // que avanzó saltando se va sumando.
  const compas = 1.3;
  final quieto = (u - _llega).clamp(0.0, queda);
  final paso = (quieto / compas).floor();
  var corrido = 0.0;
  for (var j = 0; j < paso; j++) {
    if (hash01(slot, vuelta, j, 7) < 0.22) {
      corrido += (hash01(slot, vuelta, j, 8) - 0.5) * 0.22;
    }
  }
  final f = (quieto - paso * compas) / compas;
  final salta = hash01(slot, vuelta, paso, 7) < 0.22 && u > _llega;
  var ang = sitio + corrido / r;
  var alto = 0.0;
  if (salta) {
    final d = (hash01(slot, vuelta, paso, 8) - 0.5) * 0.22;
    final s = smoothstep(0.0, 0.5, f);
    ang += d * s / r;
    alto = 4 * s * (1 - s) * 0.035 * size;
  }
  final posado = V3(
    cx + math.cos(ang) * r,
    brocal + alto,
    cz + math.sin(ang) * r,
  );
  // Mirando al agua, o un poco de lado.
  final alAgua = math.atan2(cz - posado.z, cx - posado.x);
  final lado = (hash01(slot, vuelta, paso, 9) - 0.5) * 1.4;

  if (u < _llega) {
    // Llega desde arriba y desde fuera, frenando al final.
    final t = u / _llega;
    final e = 1 - (1 - t) * (1 - t);
    final desde = sitio + 1.2 * (hash01(slot, vuelta, 10) < 0.5 ? -1 : 1);
    final a = V3(
      cx + math.cos(desde) * 2.3,
      2.2 + hash01(slot, vuelta, 11),
      cz + math.sin(desde) * 2.3,
    );
    final ctrl = V3((a.x + posado.x) / 2, posado.y + 0.9, (a.z + posado.z) / 2);
    final p = _bezier(a, ctrl, posado, e);
    final q = _bezier(a, ctrl, posado, math.min(1, e + 0.02));
    final rumbo = math.atan2(q.z - p.z, q.x - p.x);
    // Bate rápido al venir y abre las alas para frenar al final.
    final bate = t < 0.8
        ? math.sin(time * 38 + slot)
        : lerpD(math.sin(time * 38 + slot), 0.9, smoothstep(0.8, 1.0, t));
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
    final t = fuera / _parte;
    final e = t * t;
    final hacia = ang + 1.4 * (hash01(slot, vuelta, 12) < 0.5 ? -1 : 1);
    final b = V3(
      cx + math.cos(hacia) * 2.4,
      1.9 + 0.6 * hash01(slot, vuelta, 13),
      cz + math.sin(hacia) * 2.4,
    );
    final ctrl = V3(posado.x, posado.y + 0.5, posado.z);
    final p = _bezier(posado, ctrl, b, e);
    final q = _bezier(posado, ctrl, b, math.min(1, e + 0.02));
    final rumbo = math.atan2(q.z - p.z, q.x - p.x);
    return BirdVisit(
      doing: BirdDoing.leaving,
      at: p,
      heading: _mezclaAng(alAgua + lado, rumbo, smoothstep(0, 0.15, t)),
      flap: math.sin(time * 40 + slot),
      kind: kind,
      size: size,
    );
  }

  // Posado. Cada compás bebe, mira o salta: beber es bajar el pico hasta el
  // agua y volver; mirar es girar la cabeza a un lado.
  final que = hash01(slot, vuelta, paso, 14);
  var pitch = 0.0, look = 0.0;
  if (!salta && que < 0.55) {
    // Dos sorbos por compás.
    final sorbo = math.sin(f * 2 * math.pi * 2).abs();
    pitch = 0.95 * smoothstep(0.0, 0.35, sorbo);
  } else if (!salta) {
    look = math.sin(f * math.pi) * (que < 0.8 ? 0.7 : -0.7);
  }
  return BirdVisit(
    doing: BirdDoing.perched,
    at: posado,
    heading: alAgua + (salta ? 0 : lado * 0.5),
    pitch: pitch,
    look: look,
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
  void Function(double lejos, List<Facet> caras) pon,
) {
  final dia = pal.isDaylight && pal.daylight > 0.25;
  for (var k = 0; k < fountainBirdSlots; k++) {
    final v = birdVisit(l, k, time, day: dia);
    if (v.doing == BirdDoing.away) continue;
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
  // El cuerpo va un poco inclinado hacia arriba posado, y horizontal volando.
  final cabeceo = vuela ? 0.0 : -0.25 + v.pitch;
  final pivote = 1.6; // la altura del cuerpo, en `s`

  // Del espacio del pájaro —x adelante, y arriba, z a la derecha, en `s`— al
  // mundo, con el cabeceo alrededor de la cadera y, para la cabeza, el giro
  // de mirar alrededor del cuello.
  V3 mundo(double x, double y, double z, {bool cabeza = false}) {
    if (cabeza && v.look != 0) {
      const cuelloX = 1.3;
      final dx = x - cuelloX;
      final c = math.cos(v.look), sn = math.sin(v.look);
      x = cuelloX + dx * c - z * sn;
      z = dx * sn + z * c;
    }
    final c = math.cos(cabeceo), sn = math.sin(cabeceo);
    final dy = y - pivote;
    final x2 = x * c + dy * sn;
    final y2 = pivote - x * sn + dy * c;
    return v.at + f * (x2 * s) + up * (y2 * s) + rr * (z * s);
  }

  final out = <Facet>[];
  void caja(
    double x0,
    double x1,
    double y0,
    double y1,
    double z0,
    double z1,
    int tinte, {
    bool cabeza = false,
  }) {
    V3 m(double x, double y, double z) => mundo(x, y, z, cabeza: cabeza);
    final c = [
      m(x0, y0, z0),
      m(x1, y0, z0),
      m(x1, y0, z1),
      m(x0, y0, z1),
      m(x0, y1, z0),
      m(x1, y1, z0),
      m(x1, y1, z1),
      m(x0, y1, z1),
    ];
    for (final cara in hexFaces(c, Surface.own, tint: tinte)) {
      final a = cara.v.first;
      if ((eye - a).dot(cara.n) <= 0) continue;
      out.add(cara..piece = -1);
    }
  }

  // Las patas, posado: dos palitos.
  if (!vuela) {
    caja(-0.15, 0.05, 0, 1.0, -0.45, -0.25, pico);
    caja(-0.15, 0.05, 0, 1.0, 0.25, 0.45, pico);
  }
  // El cuerpo y el pecho.
  caja(-1.4, 1.2, 0.9, 2.4, -0.75, 0.75, cuerpo);
  caja(0.2, 1.45, 0.8, 1.9, -0.6, 0.6, pecho);
  // La cola, fina y hacia atrás.
  caja(-2.6, -1.2, 1.6, 1.9, -0.45, 0.45, alas);
  // La cabeza con su pico.
  caja(0.9, 2.1, 2.0, 3.1, -0.6, 0.6, cabeza, cabeza: true);
  caja(2.1, 2.9, 2.35, 2.65, -0.15, 0.15, pico, cabeza: true);
  // Las alas: plegadas sobre el lomo posado; en vuelo, abiertas y batiendo
  // desde el hombro.
  if (!vuela) {
    caja(-1.6, 0.9, 1.6, 2.5, -0.85, -0.55, alas);
    caja(-1.6, 0.9, 1.6, 2.5, 0.55, 0.85, alas);
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
  return out;
}
