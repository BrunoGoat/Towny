/// Las palomas del consejero.
///
/// Cada mucho, cuando el viejo se sienta en el banco de la plaza, bajan unas
/// palomas. Se posan delante, se le arriman y se quedan mirándolo; él se mete
/// la mano en la túnica, saca un pan, lo deja en el regazo y empieza a tirarles
/// migas: pellizca, echa el brazo atrás y suelta el puñado con un golpe de
/// muñeca. Cada puñado son tres miguitas que caen juntas, y la paloma que antes
/// llega va andando —con ese cabeceo de paloma, la cabeza adelante y el cuerpo
/// detrás— y se las come de tres picotazos. Cuando el pan se acaba él se
/// sacude las manos, las palomas se quedan un poco picoteando el suelo por si
/// queda algo, y se van.
///
/// Como los pájaros de la fuente, todo sale de la hora: no hay estado, hay un
/// reloj —cuánto hace que el viejo se sentó, [Townsfolk.benchClock]— y una
/// cuenta que se rehace en cada fotograma y da lo mismo cada vez. Quién se come
/// qué miga se decide jugando el reparto entero desde el principio, que son
/// diez puñados y cinco palomas: nada.
library;

import 'dart:math' as math;

import '../core/math3.dart';
import '../core/rng.dart';
import 'folk.dart';
import 'fountain_birds.dart';
import 'solids.dart';
import 'town.dart';

/// Lo que tiene el viejo en las manos mientras da de comer.
///
/// Las medidas, como todo en una persona, en partes de lo que mide; la altura
/// de la mano, contada desde el asiento.
class FeastPose {
  const FeastPose({
    required this.bread,
    required this.hand,
    this.breadInHand = false,
    this.pinch = false,
  });

  /// Lo que queda del pan, de uno a cero. Cero es que ya no hay.
  final double bread;

  /// Dónde está la mano que tira: `(x, y, z)` con `y` sobre el asiento.
  final (double, double, double) hand;

  /// Si el pan va en la mano —sacándolo de la túnica— y no en el regazo.
  final bool breadInHand;

  /// Si lleva una miga entre los dedos, camino de tirarla.
  final bool pinch;
}

/// Todo lo de un momento de la comida: el viejo, las migas y las palomas.
class Feast {
  const Feast(this.pose, this.crumbs, this.pigeons);

  /// Nulo cuando el viejo no tiene nada en las manos.
  final FeastPose? pose;

  /// Las migas, en el suelo y en el aire.
  final List<V3> crumbs;
  final List<BirdVisit> pigeons;
}

/// Las veces que bajan: una vuelta de cada tres, más o menos.
const double _cadaCuanto = 0.34;

/// Cuándo se mete la mano en la túnica, cuándo tiene el pan en el regazo y
/// cuándo tira el primer puñado, en segundos desde que se sentó.
const double _saca = 5.0, _enRegazo = 6.6, _primero = 7.4;

/// Lo que dura un tiro entero —pellizcar, echar atrás, soltar y volver—, en
/// qué punto de él suelta, y lo que vuela una miga.
const double _tiro = 1.1, _suelta = 0.64, _vuelo = 0.52;

/// Lo que dura un picotazo, lo que tarda en bajar una paloma, y a qué paso
/// anda.
const double _pico = 0.42, _baja = 3.4, _paso = 0.24;

/// Lo que dura un paso de paloma: el cabeceo va con él.
const double _zancada = 0.19;

/// Las manos del viejo, quietas y de tiro. Ver [FeastPose.hand].
const _regazo = (0.12, 0.15, 0.26),
    _bolsillo = (0.19, 0.30, 0.02),
    _pellizco = (0.04, 0.18, 0.26),
    _atras = (0.20, 0.50, 0.16),
    _alante = (0.13, 0.40, 0.62);

(double, double, double) _entre(
  (double, double, double) a,
  (double, double, double) b,
  double t,
) {
  final e = smoothstep(0, 1, t);
  return (lerpD(a.$1, b.$1, e), lerpD(a.$2, b.$2, e), lerpD(a.$3, b.$3, e));
}

double _mezclaAng(double a, double b, double t) {
  var d = (b - a) % (2 * math.pi);
  if (d > math.pi) d -= 2 * math.pi;
  return a + d * t;
}

V3 _bezier(V3 a, V3 b, V3 c, double t) {
  final s = 1 - t;
  return a * (s * s) + b * (2 * s * t) + c * (t * t);
}

/// Un tramo de lo que hace una paloma en el suelo.
class _Tramo {
  _Tramo(this.t0, this.t1, this.que, this.desde, this.hasta, this.h0, this.h1);
  final double t0, t1;

  /// Quieta, andando o picando.
  final int que;
  final V3 desde, hasta;
  final double h0, h1;
}

const int _quieta = 0, _anda = 1, _pica = 2;

/// La comida del viejo en el segundo [time], o nulo si ahora no hay.
///
/// [h] es lo que mide el viejo, que es en lo que van sus manos; [day], si es
/// de día: de noche las palomas duermen.
Feast? sageFeast(
  Townsfolk sage,
  TownLayout l,
  double time, {
  required double h,
  bool day = true,
}) {
  final reloj = sage.benchClock(time);
  if (reloj == null || !day) return null;
  final p = reloj.since, sits = reloj.sits, lap = reloj.lap;
  if (p < 0 || p > sits + 15) return null;
  final s = sage.seed;
  if (hash01(s, lap, 0x9A1) >= _cadaCuanto) return null;

  final cx = l.cx, cz = l.cz;
  final bx = PlazaBench.xAt(cx), bz = PlazaBench.zAt(cz);
  final giro = PlazaBench.turn;
  // Hacia delante del banco y hacia un lado, en el suelo.
  final fx = math.sin(giro), fz = math.cos(giro);
  final rx = math.cos(giro), rz = -math.sin(giro);
  double suelo(double x, double z) =>
      Plaza.floorAt(x, z, cx, cz, TownLayout.plazaReach);
  V3 enSuelo(double x, double z) => V3(x, suelo(x, z), z);
  V3 delante(double d, double lado) =>
      enSuelo(bx + fx * d + rx * lado, bz + fz * d + rz * lado);
  double haciaViejo(V3 q) => math.atan2(bz - q.z, bx - q.x);

  // Los tiros: cuántos, cuándo, y dónde cae cada puñado.
  final tiros = 7 + hashInt(3, s, lap, 1);
  final cuando = <double>[];
  var t = _primero;
  for (var k = 0; k < tiros; k++) {
    cuando.add(t);
    t += 1.2 + 0.4 * hash01(s, lap, k, 2);
  }
  final cae = [
    for (var k = 0; k < tiros; k++)
      delante(
        0.34 + 0.40 * hash01(s, lap, k, 3),
        (hash01(s, lap, k, 4) - 0.5) * 0.85,
      ),
  ];
  // Las tres miguitas de cada puñado, un poco separadas.
  V3 miga(int k, int j) {
    final g = cae[k];
    return enSuelo(
      g.x + (hash01(s, lap, k * 3 + j, 5) - 0.5) * 0.07,
      g.z + (hash01(s, lap, k * 3 + j, 6) - 0.5) * 0.07,
    );
  }

  double vuela(int j) => _vuelo + 0.05 * j;

  // De dónde sale cada puñado: de la mano, en el momento de soltarlo.
  V3 manoEn(double cuando) {
    final at = sage.at(time - p + cuando);
    final c = math.cos(at.heading), sn = math.sin(at.heading);
    final (x, y, z) = _alante;
    final y0 = suelo(at.x, at.z) + PlazaBench.seat;
    return V3(
      at.x + (x * c + z * sn) * h,
      y0 + y * h,
      at.z + (-x * sn + z * c) * h,
    );
  }

  // Las palomas: cuántas, de qué color y dónde se posan.
  final n = 3 + hashInt(3, s, lap, 7);
  final llega = [
    for (var i = 0; i < n; i++) 0.4 + i * 1.0 + 0.7 * hash01(s, lap, i, 8),
  ];
  final posa = [
    for (var i = 0; i < n; i++)
      delante(
        0.58 + 0.32 * hash01(s, lap, i, 9),
        ((n == 1 ? 0.5 : i / (n - 1)) - 0.5) * 1.0 +
            (hash01(s, lap, i, 10) - 0.5) * 0.12,
      ),
  ];
  final espera = [
    for (var i = 0; i < n; i++)
      delante(
        0.40 + 0.14 * hash01(s, lap, i, 11),
        ((n == 1 ? 0.5 : i / (n - 1)) - 0.5) * 0.8,
      ),
  ];
  final kind = [
    for (var i = 0; i < n; i++)
      switch (hash01(s, lap, i, 12)) {
        < 0.6 => 1,
        < 0.85 => 3,
        _ => 4,
      },
  ];
  final talla = [
    for (var i = 0; i < n; i++) 1.0 + 0.16 * hash01(s, lap, i, 13),
  ];
  // Lo que adelanta el pico de los pies al picar: se para eso antes de la
  // miga, no encima.
  double alcance(int i) => 0.034 * talla[i] * 2.4;

  // El reparto, jugado desde el principio.
  final tramos = [for (var i = 0; i < n; i++) <_Tramo>[]];
  final donde = [...posa];
  final cara = [for (var i = 0; i < n; i++) haciaViejo(posa[i])];
  final libre = [for (var i = 0; i < n; i++) llega[i] + _baja];
  void quieta(int i, double hasta) {
    if (hasta <= libre[i]) return;
    final mira = haciaViejo(donde[i]);
    tramos[i].add(
      _Tramo(libre[i], hasta, _quieta, donde[i], donde[i], cara[i], mira),
    );
    cara[i] = mira;
    libre[i] = hasta;
  }

  void anda(int i, V3 a, double desde) {
    quieta(i, desde);
    final d = (a - donde[i]).length;
    if (d < 0.01) return;
    final rumbo = math.atan2(a.z - donde[i].z, a.x - donde[i].x);
    final fin = desde + math.max(0.25, d / _paso);
    tramos[i].add(_Tramo(desde, fin, _anda, donde[i], a, cara[i], rumbo));
    donde[i] = a;
    cara[i] = rumbo;
    libre[i] = fin;
  }

  // Al posarse, se arriman al viejo: le han visto cara de pan.
  for (var i = 0; i < n; i++) {
    anda(i, espera[i], libre[i] + 0.6 + 0.8 * hash01(s, lap, i, 14));
  }
  // Cuándo desaparece cada miga: en el pico de alguna.
  final comida = [
    for (var k = 0; k < tiros; k++) List<double>.filled(3, double.infinity),
  ];
  for (var k = 0; k < tiros; k++) {
    final g = cae[k];
    final enSueloYa = cuando[k] + _suelta + vuela(2);
    var mejor = -1;
    var llegaria = double.infinity;
    var parada = g;
    var sale = 0.0;
    for (var i = 0; i < n; i++) {
      final reacciona = 0.15 + 0.3 * hash01(s, lap, i * 31 + k, 15);
      final desde = math.max(libre[i], enSueloYa + reacciona);
      final hacia = g - donde[i];
      final d = math.sqrt(hacia.x * hacia.x + hacia.z * hacia.z);
      final para = d <= alcance(i) + 0.01
          ? donde[i]
          : enSuelo(
              g.x - hacia.x / d * alcance(i),
              g.z - hacia.z / d * alcance(i),
            );
      final en = desde + (para - donde[i]).length / _paso;
      if (en < llegaria) {
        llegaria = en;
        mejor = i;
        parada = para;
        sale = desde;
      }
    }
    final i = mejor;
    anda(i, parada, sale);
    // Si ya estaba encima, al menos se gira hacia la miga.
    final aMiga = math.atan2(g.z - donde[i].z, g.x - donde[i].x);
    final empieza = libre[i];
    final acaba = empieza + 3 * _pico;
    tramos[i].add(
      _Tramo(empieza, acaba, _pica, donde[i], donde[i], cara[i], aMiga),
    );
    cara[i] = aMiga;
    libre[i] = acaba;
    for (var j = 0; j < 3; j++) {
      comida[k][j] = empieza + (j + 0.45) * _pico;
    }
  }
  // Y cuando no queda nada, un rato más por si acaso, y se van: casi a la
  // vez, como se van las palomas, que una arranca y las demás detrás.
  var ultima = 0.0;
  for (var i = 0; i < n; i++) {
    ultima = math.max(ultima, libre[i]);
  }
  final orden = List<int>.generate(n, (i) => i)
    ..sort((a, b) => hash01(s, lap, a, 16).compareTo(hash01(s, lap, b, 16)));
  final vanse = List<double>.filled(n, 0);
  for (var o = 0; o < n; o++) {
    final i = orden[o];
    final cuando = math.min(
      ultima + 2.2 + o * 0.35 + 0.25 * hash01(s, lap, i, 17),
      sits - 3.2,
    );
    vanse[i] = math.max(cuando, libre[i]);
    quieta(i, vanse[i]);
  }

  // Las palomas en el segundo [p].
  final palomas = <BirdVisit>[];
  for (var i = 0; i < n; i++) {
    final v = _paloma(
      i,
      p,
      time,
      s,
      lap,
      llega[i],
      posa[i],
      haciaViejo(posa[i]),
      tramos[i],
      vanse[i],
      donde[i],
      cara[i],
      kind[i],
      talla[i],
      (bx, bz),
    );
    if (v.doing != BirdDoing.away) palomas.add(v);
  }

  // Las migas, por el aire y en el suelo.
  final migas = <V3>[];
  for (var k = 0; k < tiros; k++) {
    final suelta = cuando[k] + _suelta;
    if (p < suelta) break;
    final desde = manoEn(suelta);
    for (var j = 0; j < 3; j++) {
      final g = miga(k, j);
      final e = (p - suelta - 0.03 * j) / vuela(j);
      if (e < 0) continue;
      if (e < 1) {
        // Una parábola: sale con la mano, sube un poco y cae.
        final a = desde * (1 - e) + g * e;
        migas.add(V3(a.x, a.y + 4 * e * (1 - e) * 0.10, a.z));
      } else if (p < comida[k][j]) {
        migas.add(g);
      }
    }
  }

  // Y las manos del viejo.
  FeastPose? pose;
  if (p >= _saca && p <= sits) {
    var mano = _regazo;
    var pan = 1.0, enMano = false, pellizca = false;
    if (p < _saca + 0.7) {
      mano = _entre(_regazo, _bolsillo, (p - _saca) / 0.7);
      pan = 0;
    } else if (p < _enRegazo) {
      mano = _entre(
        _bolsillo,
        _regazo,
        (p - _saca - 0.7) / (_enRegazo - _saca - 0.7),
      );
      enMano = true;
    } else {
      var hechos = 0;
      for (var k = 0; k < tiros; k++) {
        final u = p - cuando[k];
        if (u >= 0.25) hechos++;
        if (u < 0 || u >= _tiro) continue;
        if (u < 0.25) {
          mano = _entre(_regazo, _pellizco, u / 0.25);
        } else if (u < 0.55) {
          mano = _entre(_pellizco, _atras, (u - 0.25) / 0.30);
          pellizca = true;
        } else if (u < 0.70) {
          // El golpe de muñeca: rápido, sin suavizar el arranque.
          final e = (u - 0.55) / 0.15;
          mano = (
            lerpD(_atras.$1, _alante.$1, e),
            lerpD(_atras.$2, _alante.$2, e),
            lerpD(_atras.$3, _alante.$3, e),
          );
          pellizca = u < _suelta;
        } else {
          mano = _entre(_alante, _regazo, (u - 0.70) / 0.40);
        }
      }
      // Lo que queda: el último pellizco se lleva el último trozo.
      pan = hechos >= tiros ? 0 : 1 - hechos / tiros;
      // Y al acabar, se sacude las manos sobre las rodillas.
      final sacude = p - (cuando.last + _tiro + 0.3);
      if (sacude >= 0 && sacude < 0.8) {
        final a =
            math.sin(sacude / 0.8 * math.pi * 4) *
            math.sin(sacude / 0.8 * math.pi);
        mano = (_regazo.$1 + 0.04 * a, _regazo.$2 + 0.05, _regazo.$3);
      }
    }
    pose = FeastPose(
      bread: pan,
      hand: mano,
      breadInHand: enMano,
      pinch: pellizca,
    );
  }
  return Feast(pose, migas, palomas);
}

BirdVisit _paloma(
  int i,
  double p,
  double time,
  int s,
  int lap,
  double llega,
  V3 posa,
  double caraAlPosar,
  List<_Tramo> tramos,
  double vanse,
  V3 ultimo,
  double caraFinal,
  int kind,
  double size,
  (double, double) viejo,
) {
  if (p < llega) return BirdVisit.none;
  if (p < llega + _baja) {
    // Baja de lo alto planeando y batiendo, y al final abre las alas para
    // frenar, como las de la fuente; pero una paloma bate más, y más fuerte.
    final t = (p - llega) / _baja;
    final e = t * t * (3 - 2 * t);
    final desde = hash01(s, lap, i, 20) * 2 * math.pi;
    final a = V3(
      posa.x + math.cos(desde) * 2.8,
      5.5 + 1.5 * hash01(s, lap, i, 21),
      posa.z + math.sin(desde) * 2.8,
    );
    final ctrl = V3((a.x + posa.x) / 2, posa.y + 0.9, (a.z + posa.z) / 2);
    final q0 = _bezier(a, ctrl, posa, e);
    final q1 = _bezier(a, ctrl, posa, math.min(1, e + 0.02));
    final rumbo = math.atan2(q1.z - q0.z, q1.x - q0.x);
    final ala = math.sin(time * 19 + i * 1.7);
    final planea =
        0.45 + 0.55 * smoothstep(-0.2, 0.6, math.sin(time * 1.1 + i));
    final bate = t < 0.78
        ? ala * planea
        : lerpD(ala * planea, 0.9, smoothstep(0.78, 1.0, t));
    return BirdVisit(
      doing: BirdDoing.arriving,
      at: q0,
      heading: t > 0.85
          ? _mezclaAng(rumbo, caraAlPosar, smoothstep(0.85, 1, t))
          : rumbo,
      flap: bate,
      kind: kind,
      size: size,
    );
  }
  final fuera = p - vanse;
  if (fuera >= 0) {
    if (fuera > 14) return BirdVisit.none;
    // Arranca de golpe —las palomas no se despiden— lejos del viejo y hacia
    // arriba, y después sube en diagonal hasta perderse.
    final lejos = math.atan2(ultimo.z - viejo.$2, ultimo.x - viejo.$1);
    final hacia = lejos + (hash01(s, lap, i, 22) - 0.5) * 1.4;
    const despega = 2.4;
    final b = V3(
      ultimo.x + math.cos(hacia) * 1.5,
      ultimo.y + 1.6 + 0.4 * hash01(s, lap, i, 23),
      ultimo.z + math.sin(hacia) * 1.5,
    );
    final ctrl = V3(ultimo.x, ultimo.y + 0.5, ultimo.z);
    V3 despegue(double t) => _bezier(ultimo, ctrl, b, t * t);
    final bate = math.sin(time * 22 + i * 1.3);
    if (fuera < despega) {
      final t = fuera / despega;
      final q0 = despegue(t);
      final q1 = despegue(math.min(1, t + 0.02));
      final rumbo = math.atan2(q1.z - q0.z, q1.x - q0.x);
      return BirdVisit(
        doing: BirdDoing.leaving,
        at: q0,
        heading: _mezclaAng(caraFinal, rumbo, smoothstep(0, 0.15, t)),
        flap: bate,
        kind: kind,
        size: size,
      );
    }
    final vel = (b - ctrl) * (2 / despega);
    final tau = fuera - despega;
    const tau0 = 1.2;
    final mezcla = tau0 * (1 - math.exp(-tau / tau0));
    final crucero = V3(math.cos(hacia) * 1.6, 1.0, math.sin(hacia) * 1.6);
    final q = b + vel * mezcla + crucero * (tau - mezcla);
    final ahora =
        vel * math.exp(-tau / tau0) + crucero * (1 - math.exp(-tau / tau0));
    final planea = 0.4 + 0.6 * smoothstep(-0.3, 0.5, math.sin(time * 0.9 + i));
    return BirdVisit(
      doing: BirdDoing.leaving,
      at: q,
      heading: math.atan2(ahora.z, ahora.x),
      flap: bate * planea,
      kind: kind,
      size: size,
    );
  }

  // En el suelo: el tramo que toca.
  var tr = tramos.isEmpty ? null : tramos.last;
  for (final x in tramos) {
    if (p < x.t1) {
      tr = x;
      break;
    }
  }
  if (tr == null || p < tr.t0) {
    // Recién posada, antes de su primer tramo: quieta, mirando al viejo.
    return BirdVisit(
      doing: BirdDoing.perched,
      at: posa,
      heading: caraAlPosar,
      kind: kind,
      size: size,
    );
  }
  final q = p - tr.t0;
  final largo = tr.t1 - tr.t0;
  var at = tr.desde;
  var heading = tr.h1;
  var pitch = 0.0, look = 0.0, lean = 0.0, crouch = 0.0, reach = 0.0;
  var tail = 0.0, wings = 0.0;
  switch (tr.que) {
    case _anda:
      // Andando a pasitos cortos, con el cabeceo de las palomas: la cabeza
      // sale para delante de golpe y se queda quieta en el aire mientras el
      // cuerpo la alcanza. Es lo que hace que una paloma se lea paloma.
      final e = clampD(q / largo, 0, 1);
      at = tr.desde * (1 - e) + tr.hasta * e;
      heading = _mezclaAng(tr.h0, tr.h1, smoothstep(0, 0.18, q));
      final f = (q / _zancada) % 1.0;
      final cabeceo = f < 0.28
          ? smoothstep(0, 1, f / 0.28)
          : 1 - (f - 0.28) / 0.72;
      reach = 0.62 * cabeceo - 0.20;
      at = V3(at.x, at.y + 0.004 * math.sin(f * math.pi), at.z);
      heading += 0.05 * math.sin(q / _zancada * math.pi);
      tail = 0.08 * math.sin(q / _zancada * 2 * math.pi);
    case _pica:
      // Tres picotazos secos a la miga, y entre uno y otro la cabeza arriba
      // a tragar.
      heading = _mezclaAng(tr.h0, tr.h1, smoothstep(0, 0.12, q));
      final j = math.min(2, (q / _pico).floor());
      final f = (q - j * _pico) / _pico;
      final b = smoothstep(0, 0.30, f) * (1 - smoothstep(0.48, 0.82, f));
      final golpe = b * math.sin(clampD((f - 0.22) / 0.2, 0, 1) * math.pi);
      pitch =
          1.45 * b +
          0.10 * golpe -
          0.18 * smoothstep(0.82, 0.95, f) * (1 - smoothstep(0.95, 1.0, f));
      lean = 0.85 * b;
      crouch = 0.38 * b;
      reach = 0.95 * b;
      tail = 0.50 * b;
    default:
      // Quieta, mirando al viejo a ver si cae algo. Se gira hacia él a
      // saltitos, mueve la cabeza a tirones —una paloma no gira la cabeza:
      // la cambia de sitio— y de vez en cuando pica el suelo por si acaso.
      final vuelta = math.min(0.35, largo);
      final g = clampD(q / vuelta, 0, 1);
      heading = _mezclaAng(tr.h0, tr.h1, smoothstep(0, 1, g));
      var giro = (tr.h1 - tr.h0) % (2 * math.pi);
      if (giro > math.pi) giro -= 2 * math.pi;
      if (giro.abs() > 0.5 && g < 1) {
        at = V3(at.x, at.y + 4 * g * (1 - g) * 0.012 * size, at.z);
      }
      final ventana = (p / 0.7 + i * 0.37).floor();
      final dentro = (p / 0.7 + i * 0.37) - ventana;
      double mira(int w) => (hash01(s, i, w, 30) - 0.5) * 1.1;
      look = lerpD(
        mira(ventana - 1),
        mira(ventana),
        smoothstep(0, 0.15, dentro),
      );
      // Un picotazo al suelo, una ventana de cada cuatro.
      final w2 = (p / 1.3 + i * 0.53).floor();
      final f2 = (p / 1.3 + i * 0.53) - w2;
      if (q > vuelta && hash01(s, i, w2, 31) < 0.25) {
        final b = smoothstep(0.1, 0.35, f2) * (1 - smoothstep(0.5, 0.75, f2));
        pitch = 1.40 * b;
        lean = 0.80 * b;
        crouch = 0.35 * b;
        reach = 0.85 * b;
        tail = 0.45 * b;
        look *= 1 - b;
      }
      // Y alguna vez se ahueca y se sacude.
      final w3 = (p / 4.0 + i * 0.71).floor();
      final f3 = (p / 4.0 + i * 0.71) - w3;
      if (hash01(s, i, w3, 32) < 0.2 && f3 > 0.6 && f3 < 0.78) {
        wings = math.sin((f3 - 0.6) / 0.18 * math.pi * 3).abs();
      }
  }
  return BirdVisit(
    doing: BirdDoing.perched,
    at: at,
    heading: heading,
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
