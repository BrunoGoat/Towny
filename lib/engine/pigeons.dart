/// Las palomas del consejero.
///
/// Cada mucho, cuando el viejo se sienta en el banco de la plaza, bajan unas
/// palomas. Se posan delante, se le arriman y se quedan mirándolo. Entonces
/// un pan sale solo de su túnica y se le acomoda en el regazo —aquí nadie
/// tiene brazos, y las cosas se mueven solas— y del pan se van despegando
/// migas: sube un pellizco, toma impulso y sale volando hacia las palomas.
/// Cada puñado son tres miguitas que caen juntas, y la paloma que antes
/// llega va andando —con ese cabeceo de paloma, la cabeza adelante y el cuerpo
/// detrás— y se las come de tres picotazos. Cuando el pan se acaba él se
/// queda mirándolas, las palomas se quedan un poco picoteando el suelo por si
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

/// El pan del viejo mientras da de comer, que se mueve solo.
///
/// Las medidas, como todo en una persona, en partes de lo que mide; las
/// alturas, contadas desde el asiento.
class FeastPose {
  const FeastPose({
    required this.bread,
    required this.afloat,
    this.breadAfloat = false,
    this.crumb = false,
  });

  /// Lo que queda del pan, de uno a cero. Cero es que ya no hay.
  final double bread;

  /// Dónde va lo que flota —el pan saliendo de la túnica, o la miga camino
  /// de las palomas—: `(x, y, z)` con `y` sobre el asiento.
  final (double, double, double) afloat;

  /// Si el pan va por el aire —saliendo de la túnica— y no en el regazo.
  final bool breadAfloat;

  /// Si hay una miga por el aire, despegada del pan y sin soltar aún.
  final bool crumb;
}

/// Todo lo de un momento de la comida: el viejo, las migas y las palomas.
class Feast {
  const Feast(this.pose, this.crumbs, this.pigeons);

  /// Nulo cuando el viejo no tiene pan.
  final FeastPose? pose;

  /// Las migas, en el suelo y en el aire.
  final List<V3> crumbs;
  final List<BirdVisit> pigeons;
}

/// Las veces que bajan: una vuelta de cada seis, más o menos. Era una de
/// cada tres, y tan seguido dejaba de ser un momento que se encuentra.
const double _cadaCuanto = 0.17;

/// Cuánto siguen volando las palomas después de irse, en segundos. Como los
/// pájaros de la fuente: se van lejos y alto, hasta que ya no se las ve, y
/// no se apagan en el aire. A los catorce segundos todavía se veían, y
/// desaparecían de golpe.
const double _seVan = 60;

/// Cuándo sale el pan de la túnica, cuándo lo tiene en el regazo y
/// cuándo tira el primer puñado, en segundos desde que se sentó.
const double _saca = 5.0, _enRegazo = 6.6, _primero = 7.4;

/// Dónde queda el pan en el regazo, con la altura sobre el asiento.
const feastBreadRest = (0.0, 0.162, 0.24);

/// Lo que tarda una miga desde que se despega del pan hasta que sale
/// disparada, y lo que vuela.
const double _suelta = 0.64, _vuelo = 0.52;

/// Lo que dura un picotazo, lo que tarda en bajar una paloma, y a qué paso
/// anda.
const double _pico = 0.42, _baja = 3.4, _paso = 0.24;

/// Lo que dura un paso de paloma: el cabeceo va con él.
const double _zancada = 0.19;

/// Cómo pica una paloma: cuánto inclina el cuerpo, se agacha y estira el
/// cuello. Lo que baja la cabeza sale de ahí: lo justo para que la punta
/// del pico toque la miga.
const double _inclina = 0.45, _agacha = 0.30, _estira = 0.45;

/// Hasta dónde baja la punta del pico al picar: hasta encima de la miga, que
/// es una cajita de un centímetro.
const double _tocaEn = 0.008;

/// La cabeza al picar —cuánto baja— y cuánto por delante de los pies cae
/// entonces la punta del pico, para una paloma de talla uno. Va en
/// proporción a la talla.
///
/// Sale del pájaro mismo, no de un número a ojo: picaba con la cabeza cinco
/// centímetros bajo el suelo y a dos de los pies, con la miga a ocho.
final (double, double) _picotazo = () {
  V3 punta(double baja) => birdBeakTip(
    BirdVisit(
      doing: BirdDoing.perched,
      at: const V3(0, 0, 0),
      heading: 0,
      pitch: baja,
      lean: _inclina,
      crouch: _agacha,
      reach: _estira,
      kind: 3,
    ),
  );
  var lo = 0.0, hi = 1.4;
  for (var k = 0; k < 40; k++) {
    final m = (lo + hi) / 2;
    if (punta(m).y > _tocaEn) {
      lo = m;
    } else {
      hi = m;
    }
  }
  return (lo, punta(lo).x);
}();

/// Cuánto baja todo al picar, en cada momento del picotazo: baja, toca y se
/// queda un instante, sube con la miga y traga.
double _bajada(double f) =>
    smoothstep(0, 0.30, f) * (1 - smoothstep(0.48, 0.80, f));

/// En qué momento del picotazo el pico toca la miga, y en cuál se la traga.
const double _toca = 0.31, _traga = 0.86;

/// Por dónde va lo que flota. Ver [FeastPose.afloat].
const _bolsillo = (0.19, 0.30, 0.02),
    _alto = (0.12, 0.42, 0.14),
    _pellizco = (0.06, 0.20, 0.25),
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
/// [h] es lo que mide el viejo, que es en lo que va su pan; [day], si es
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
  if (p < 0 || p > sits + _seVan) return null;
  final s = sage.seed;
  // El maestro, cuando se sienta solo, más seguido: es su rato del banco.
  final cada = sage.builder ? 0.5 : _cadaCuanto;
  if (hash01(s, lap, 0x9A1) >= cada) return null;

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

  // De dónde sale cada puñado: de donde iba flotando al soltarse.
  V3 sueltaEn(double cuando) {
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
  double alcance(int i) => _picotazo.$2 * talla[i];

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

  // Anda hasta [a], mirando adonde va o —si se le da [mira]— hacia ahí: el
  // pasito de costado o para atrás para ponerse frente a la miga siguiente.
  void anda(int i, V3 a, double desde, {double? mira}) {
    quieta(i, desde);
    final d = (a - donde[i]).length;
    if (d < 0.004) return;
    final rumbo = mira ?? math.atan2(a.z - donde[i].z, a.x - donde[i].x);
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
  // Cuándo la toca el pico de una paloma, cuál, y cuándo se la traga.
  final comida = [
    for (var k = 0; k < tiros; k++) List<double>.filled(3, double.infinity),
  ];
  final traga = [
    for (var k = 0; k < tiros; k++) List<double>.filled(3, double.infinity),
  ];
  final quien = [for (var k = 0; k < tiros; k++) List<int>.filled(3, 0)];
  for (var k = 0; k < tiros; k++) {
    final g = cae[k];
    final enSueloYa = cuando[k] + _suelta + vuela(2);
    var mejor = -1;
    var llegaria = double.infinity;
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
        sale = desde;
      }
    }
    final i = mejor;
    // Las tres migas, una por una, cada una de un picotazo, y antes de cada
    // uno se pone justo a la distancia: andando hasta la primera, y de una a
    // otra un pasito, si hace falta, sin dejar de mirarla. La más cercana
    // primero.
    var desde = sale;
    final quedan = [0, 1, 2];
    while (quedan.isNotEmpty) {
      quedan.sort(
        (a, b) => (miga(k, a) - donde[i]).length.compareTo(
          (miga(k, b) - donde[i]).length,
        ),
      );
      final j = quedan.removeAt(0);
      final m = miga(k, j);
      final hacia = m - donde[i];
      final d = math.sqrt(hacia.x * hacia.x + hacia.z * hacia.z);
      final aMiga = d < 1e-6 ? cara[i] : math.atan2(hacia.z, hacia.x);
      final ux = d < 1e-6 ? math.cos(aMiga) : hacia.x / d;
      final uz = d < 1e-6 ? math.sin(aMiga) : hacia.z / d;
      anda(
        i,
        enSuelo(m.x - ux * alcance(i), m.z - uz * alcance(i)),
        desde,
        mira: d > alcance(i) + 0.06 ? null : aMiga,
      );
      final empieza = libre[i];
      final acaba = empieza + _pico;
      tramos[i].add(
        _Tramo(empieza, acaba, _pica, donde[i], donde[i], cara[i], aMiga),
      );
      cara[i] = aMiga;
      libre[i] = acaba;
      comida[k][j] = empieza + _toca * _pico;
      traga[k][j] = empieza + _traga * _pico;
      quien[k][j] = i;
      desde = libre[i];
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
  final visitas = <BirdVisit>[];
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
    visitas.add(v);
    if (v.doing != BirdDoing.away) palomas.add(v);
  }

  // Las migas, por el aire y en el suelo.
  final migas = <V3>[];
  for (var k = 0; k < tiros; k++) {
    final suelta = cuando[k] + _suelta;
    if (p < suelta) break;
    final desde = sueltaEn(suelta);
    for (var j = 0; j < 3; j++) {
      final g = miga(k, j);
      final e = (p - suelta - 0.03 * j) / vuela(j);
      if (e < 0) continue;
      if (e < 1) {
        // Una parábola: sale disparada, sube un poco y cae.
        final a = desde * (1 - e) + g * e;
        migas.add(V3(a.x, a.y + 4 * e * (1 - e) * 0.10, a.z));
      } else if (p < comida[k][j]) {
        migas.add(g);
      } else if (p < traga[k][j]) {
        // En el pico, hasta que se la traga.
        final t = birdBeakTip(visitas[quien[k][j]]);
        migas.add(V3(t.x, t.y - 0.006, t.z));
      }
    }
  }

  // Y el pan del viejo, que se mueve solo.
  FeastPose? pose;
  if (p >= _saca && p <= sits) {
    var flota = _bolsillo;
    var pan = 1.0, panFlota = false, miga = false;
    if (p < _enRegazo) {
      // Sale de la túnica, sube un palmo y baja despacio a su regazo,
      // meciéndose un poco, como algo que alguien lleva con cuidado.
      final t = (p - _saca) / (_enRegazo - _saca);
      flota = t < 0.45
          ? _entre(_bolsillo, _alto, t / 0.45)
          : _entre(_alto, feastBreadRest, (t - 0.45) / 0.55);
      final mece = math.sin(t * math.pi * 2) * math.sin(t * math.pi);
      flota = (flota.$1 + 0.02 * mece, flota.$2, flota.$3);
      panFlota = true;
    } else {
      var hechos = 0;
      for (var k = 0; k < tiros; k++) {
        final u = p - cuando[k];
        if (u >= 0) hechos++;
        if (u < 0 || u >= _suelta) continue;
        // Una miga se despega sola del pan, sube y se va hacia atrás
        // tomando impulso, temblando un poco, y sale disparada hacia
        // las palomas.
        miga = true;
        if (u < 0.40) {
          final e = u / 0.40;
          final tiembla = 0.010 * math.sin(u * 60) * e;
          final q = _entre(_pellizco, _atras, e);
          flota = (q.$1 + tiembla, q.$2, q.$3);
        } else {
          final e = (u - 0.40) / (_suelta - 0.40);
          flota = (
            lerpD(_atras.$1, _alante.$1, e * e),
            lerpD(_atras.$2, _alante.$2, e * e),
            lerpD(_atras.$3, _alante.$3, e * e),
          );
        }
      }
      // Lo que queda: la última miga se lleva el último trozo.
      pan = hechos >= tiros ? 0 : 1 - hechos / tiros;
    }
    pose = FeastPose(
      bread: pan,
      afloat: flota,
      breadAfloat: panFlota,
      crumb: miga,
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
    if (fuera > _seVan) return BirdVisit.none;
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
      // Un picotazo seco a la miga: la punta del pico baja justo encima de
      // ella, se la lleva, sube y la traga con un tirón de cabeza para
      // atrás.
      heading = _mezclaAng(tr.h0, tr.h1, smoothstep(0, 0.12, q));
      final f = clampD(q / _pico, 0, 1);
      final b = _bajada(f);
      pitch =
          _picotazo.$1 * b -
          0.18 * smoothstep(0.80, 0.90, f) * (1 - smoothstep(0.90, 1.0, f));
      lean = _inclina * b;
      crouch = _agacha * b;
      reach = _estira * b;
      tail = 0.40 * b;
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
        pitch = _picotazo.$1 * b;
        lean = _inclina * b;
        crouch = _agacha * b;
        reach = _estira * b;
        tail = 0.40 * b;
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
