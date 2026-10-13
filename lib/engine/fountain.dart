/// Lo que vive en la plaza y no es mampostería: el agua de la fuente, y las
/// sombras que caen sobre el enlosado.
///
/// Las dos cosas se mueven —el agua corre, la sombra gira con el sol— y por
/// eso no pueden ir dentro del árbol de orden, que se corta una vez cuando
/// cae una pieza. Van como van los vecinos: caras sueltas que bajan por el
/// árbol cada fotograma (ver `walkOrderRiders`), así que la casa de delante
/// tapa el chorro y el chorro tapa la casa de detrás, como tiene que ser.
library;

import 'dart:math' as math;

import 'dart:ui' show Color;

import '../core/math3.dart';
import '../core/rng.dart';
import 'fountain_birds.dart';
import 'palette.dart';
import 'solid.dart';
import 'solids.dart';
import 'town.dart';

// ------------------------------------------------------------------ el agua

/// La marca de las caras de agua: no son de nadie, como el resto de la plaza,
/// pero llevan su color ya hecho —con su transparencia— y el pintor no les
/// pone luz encima. Ver `_plainFaces` en el pintor.
const int waterPiece = -3;

/// Lo que tira de cada gota hacia abajo, en unidades del mundo por segundo al
/// cuadrado. Un poco más que la de verdad a esta escala —una persona mide
/// unos tres décimos—, que a la de verdad el agua parece de miel.
const double _g = 2.6;

/// Una gota en el aire: dónde está, hacia dónde va, cuánto lleva volando, qué
/// número es en su chorro —que es lo que la hace ella y no otra— y si es la
/// última, la que ya tocó el agua.
typedef _Gota = ({V3 p, V3 v, double edad, int i, bool fin});

/// El agua de la fuente de la plaza, vista desde [eye] en el segundo [time].
///
/// **No es una forma que cambia de color: son gotas.** Cada chorro es una
/// fila de gotas que salen del caño una detrás de otra, cada una con su
/// impulso —un poco distinto del de la anterior— y que desde ahí vuelan solas
/// con la gravedad. Lo que se dibuja es la cinta que las une. Así lo que se
/// mueve se mueve de verdad: un engrosamiento del chorro es una gota más
/// gorda que baja con las demás, el chorro respira porque el caño empuja a
/// golpes, y abajo, donde el agua ya va estirada, la cinta se rompe y lo que
/// cae son gotas sueltas.
///
/// **Como ⛲**: un surtidor en la taza de arriba que sube, se abre y vuelve a
/// caer en ella, y la taza que rebosa por todo el borde en un velo que se
/// rasga en hilos antes de llegar al pilón. Donde cae, espuma, salpicaduras y
/// ondas que se abren por el agua.
///
/// **De noche, más tranquila**: el surtidor sube la mitad, el velo cae casi
/// pegado a la taza y la espuma se calma. No se apaga: es el centro del
/// pueblo.
///
/// [detail] baja de uno a casi cero cuando la fuente se ve pequeña: menos
/// hilos, sin el alma clara de cada chorro, sin salpicaduras.
List<Facet> fountainWater(
  TownLayout l,
  V3 eye,
  double time,
  Palette pal, {
  double detail = 1,
}) {
  final cx = l.cx, cz = l.cz;
  final reach = TownLayout.plazaReach;
  final pozo = Plaza.poolOf(reach);
  final taza = Plaza.bowlOf(reach);
  final pilar = Plaza.basinOf(reach) / 1.14 * 0.20;
  const pilon = Plaza.poolLevel, aguaTaza = Plaza.bowlWater;

  final dia = smoothstep(0.05, 0.6, pal.daylight);
  final fino = detail >= 0.9;
  final medio = detail >= 0.45;

  // ------------------------------------------------------------ los colores
  //
  // El agua no tiene color propio: es el cielo que refleja y la luz que la
  // atraviesa. De día, clara y con el sol encendiéndola donde el chorro se
  // pone de canto a él; de noche, gris azulada, de luna.
  final luzSol = pal.isDaylight ? smoothstep(0.0, 0.25, pal.sunDir.y) : 0.35;
  final luz = pal.lightDir;
  final cuerpo = _mezcla(
    _mezcla(0xFF5E7596, _argb(pal.skyTop), 0.30),
    _mezcla(0xFFB4DDEA, _argb(pal.skyTop), 0.30),
    dia,
  );
  final blanco = _escala(0xFFF4FBFD, lerpD(0.62, 1.0, dia));
  // De noche el agua casi no se ve: se ve lo que brilla.
  final velada = lerpD(0.62, 1.0, dia);
  final destello = _mezcla(0xFFFFFFFF, _argb(pal.sun), 0.3);

  /// El color de un trozo de chorro que va en la dirección [t]: el cuerpo,
  /// más blanco cuanto más espuma lleve, y el destello del sol donde la
  /// superficie del chorro —un cilindro— lo refleja hacia el ojo, que es
  /// donde el eje del chorro queda de canto a la mitad entre la luz y el ojo.
  int tono(V3 p, V3 t, double espuma, double alfa) {
    final ojo = (eye - p).normalized;
    final h = (luz + ojo).normalized;
    final tl = t.length;
    final c = tl < 1e-9 ? 0.0 : t.dot(h) / tl;
    final brillo = math.pow(math.max(0.0, 1 - c * c), 28).toDouble() * luzSol;
    var col = _mezcla(cuerpo, blanco, espuma);
    col = _mezcla(col, destello, brillo * 0.85);
    final a = clampD(alfa * velada + brillo * 0.25, 0, 1);
    return (col & 0x00FFFFFF) | ((a * 255).round() << 24);
  }

  // ------------------------------------------------------------- el pintar
  //
  // Todo va en trozos con su distancia al ojo y se pinta de lejos a cerca:
  // el agua es transparente y el orden se ve.
  final hondo = <double>[];
  final trozos = <List<Facet>>[];
  void pon((double, List<Facet>) t) {
    hondo.add(t.$1);
    trozos.add(t.$2);
  }

  double lejos(V3 p) => (p - eye).length;
  Facet cara(List<V3> v, int color) {
    final c = v.fold<V3>(V3.zero, (a, b) => a + b) * (1 / v.length);
    var n = (v[1] - v[0]).cross(v[v.length - 1] - v[0]);
    if (n.length < 1e-12) n = eye - c;
    n = n.normalized;
    if (n.dot(eye - c) < 0) n = n * -1;
    return Facet(v, n, Surface.own, tint: color)..piece = waterPiece;
  }

  /// Hacia dónde se abre una cinta en [p] que va en [t], para que se vea de
  /// frente desde el ojo, y de medio ancho [w].
  ///
  /// Con [lamina], el chorro es parte de una lámina que se abre en esa
  /// dirección —el velo— y se abre sobre todo por ahí: una cinta que mira
  /// siempre al ojo se retuerce y se vuelve un pico cuando el agua viene
  /// derecho hacia él, y una lámina no.
  V3 lado(V3 p, V3 t, double w, [V3? lamina]) {
    var s = t.cross(eye - p);
    var n = s.length;
    if (lamina != null) {
      final ojo = n < 1e-9 ? V3.zero : s * (1 / n);
      final signo = ojo.dot(lamina) < 0 ? -1.0 : 1.0;
      s = lamina + ojo * (0.35 * signo);
      n = s.length;
    }
    if (n < 1e-9) return V3.zero;
    return s * (w / 2 / n);
  }

  /// Un tramo de chorro entre dos gotas: la piel, más ancha y más clara, y el
  /// alma, la mitad de ancha y más blanca encima.
  void tramo(
    _Gota a,
    _Gota b,
    double wa,
    double wb,
    double espuma,
    double alfa, {
    bool alma = false,
    V3? lamina,
  }) {
    final la = lado(a.p, a.v, wa, lamina), lb = lado(b.p, b.v, wb, lamina);
    if (la == V3.zero || lb == V3.zero) return;
    final m = (a.p + b.p) * 0.5;
    final t = b.p - a.p;
    final caras = [
      cara([a.p - la, b.p - lb, b.p + lb, a.p + la], tono(m, t, espuma, alfa)),
      if (alma && fino)
        cara([
          a.p - la * 0.42,
          b.p - lb * 0.42,
          b.p + lb * 0.42,
          a.p + la * 0.42,
        ], tono(m, t, math.min(1, espuma + 0.35), math.min(1, alfa + 0.25))),
    ];
    pon((lejos(m), caras));
  }

  /// Una gota suelta, estirada a lo largo de lo que lleva recorrido en un
  /// instante: así se lee que cae y no que flota.
  void gota(V3 p, V3 v, double w, double espuma, double alfa) {
    final rapida = v.length;
    if (rapida < 1e-9) return;
    final d = v * (1 / rapida);
    // Una lágrima: la cabeza redonda delante y la estela detrás, tan larga
    // como lo que la gota recorre en un instante.
    final cola = p - d * math.max(w * 0.7, rapida * 0.03);
    final la = lado(p, v, w);
    if (la == V3.zero) return;
    final cabeza = p + d * (w * 0.5);
    final hombro = p - d * (w * 0.05);
    pon((
      lejos(p),
      [
        cara([
          cola - la * 0.25,
          hombro - la,
          cabeza - la * 0.6,
          cabeza + la * 0.6,
          hombro + la,
          cola + la * 0.25,
        ], tono(p, v, espuma, alfa)),
      ],
    ));
  }

  /// Algo plano sobre el agua a la altura [y]: un polígono de [r] alrededor de
  /// ([x], [z]), girado [giro], de [lados] lados.
  void mancha(
    double x,
    double z,
    double y,
    double r,
    int color, {
    int lados = 6,
    double giro = 0,
    double aplana = 1,
  }) {
    pon((
      lejos(V3(x, y, z)) + 0.25,
      [
        Facet(
          [
            for (var k = lados - 1; k >= 0; k--)
              V3(
                x + r * math.cos(giro + k * 2 * math.pi / lados),
                y,
                z + r * aplana * math.sin(giro + k * 2 * math.pi / lados),
              ),
          ],
          const V3(0, 1, 0),
          Surface.own,
          tint: color,
        )..piece = waterPiece,
      ],
    ));
  }

  /// Una onda: un anillo fino sobre el agua, de radio [r].
  void onda(double y, double r, double ancho, int color, int lados) {
    for (var k = 0; k < lados; k++) {
      final a0 = k * 2 * math.pi / lados, a1 = (k + 1) * 2 * math.pi / lados;
      V3 at(double rr, double a) =>
          V3(cx + rr * math.cos(a), y, cz + rr * math.sin(a));
      final v = [at(r + ancho, a0), at(r + ancho, a1), at(r, a1), at(r, a0)];
      final mid = at(r, (a0 + a1) / 2);
      pon((
        lejos(mid) + 0.25,
        [
          Facet(v, const V3(0, 1, 0), Surface.own, tint: color)
            ..piece = waterPiece,
        ],
      ));
    }
  }

  int conAlfa(int c, double a) =>
      (c & 0x00FFFFFF) | ((clampD(a, 0, 1) * 255).round() << 24);

  // -------------------------------------------------------------- el vuelo

  /// Las gotas de un chorro en el aire ahora mismo, de la boca hacia fuera.
  ///
  /// Sale una cada [dt] segundos; la `i` de cada una es su turno, y todo lo
  /// que la distingue —su empuje, su grosor, si ahí se rompe el chorro— sale
  /// de la `i`, así que una gota es la misma gota de un fotograma al otro y
  /// sólo cambia dónde está. Vuela hasta que baja de [suelo] (o de lo que
  /// diga [sueloDe] para ella, si cae en otro sitio), y esa última se corta
  /// justo en el agua.
  List<_Gota> vuelo({
    required double dt,
    required int cuantas,
    required V3 Function(int i) boca,
    required V3 Function(int i, double sale) empuje,
    required double suelo,
    double Function(V3 p)? sueloDe,
  }) {
    final out = <_Gota>[];
    final n0 = (time / dt).floor();
    _Gota? antes;
    for (var j = -1; j < cuantas; j++) {
      final i = n0 - j;
      final sale = j < 0 ? time : i * dt;
      final edad = time - sale;
      final v0 = empuje(i, sale);
      final o = boca(i);
      var p = o + v0 * edad + V3(0, -_g * edad * edad / 2, 0);
      final v = v0 + V3(0, -_g * edad, 0);
      final hasta = sueloDe == null ? suelo : sueloDe(p);
      if (p.y <= hasta) {
        if (antes != null && antes.p.y > hasta) {
          final t = (antes.p.y - hasta) / (antes.p.y - p.y);
          p = antes.p + (p - antes.p) * t;
          out.add((p: p, v: v, edad: edad, i: i, fin: true));
        }
        break;
      }
      final g = (p: p, v: v, edad: edad, i: i, fin: false);
      out.add(g);
      antes = g;
    }
    return out;
  }

  // ---------------------------------------------------------------- el velo
  //
  // La taza rebosa por todo el borde. Arriba, recién salida, el agua es una
  // lámina: entre un hilo y el de al lado hay agua. Al caer se estira y se
  // rasga —cada trozo de lámina a su altura— y lo que llega al pilón son
  // hilos, y de los hilos, gotas.
  final hilos = fino ? 18 : (medio ? 14 : 10);
  final dtVelo = fino ? 0.036 : 0.055;
  final caeVelo = math.sqrt(2 * (Plaza.bowlLip - pilon) / _g) + 0.1;
  final cuantasVelo = (caeVelo / dtVelo).ceil() + 2;
  final empujeVelo = lerpD(0.07, 0.19, dia);
  final anchoVelo = lerpD(0.055, 0.090, dia);
  final velo = <List<_Gota>>[];
  final caidas = <V3>[];
  final borde = <V3>[];
  for (var k = 0; k < hilos; k++) {
    final a = (k + 0.5) * 2 * math.pi / hilos + 0.11;
    final dx = math.cos(a), dz = math.sin(a);
    borde.add(V3(-dz, 0, dx));
    final fase = hash01(k, 31) * 6.28;
    final gotas = vuelo(
      dt: dtVelo,
      cuantas: cuantasVelo,
      boca: (i) => V3(
        cx + dx * (taza + 0.004),
        Plaza.bowlLip + 0.010,
        cz + dz * (taza + 0.004),
      ),
      empuje: (i, sale) {
        // La taza no rebosa igual todo el rato: el surtidor le echa agua a
        // golpes y el borde la suelta a golpes.
        final ola =
            1 +
            0.12 * math.sin(2 * math.pi * 0.55 * sale + fase) +
            0.06 * math.sin(2 * math.pi * 1.7 * sale + fase * 2);
        // Y cada trozo de agua sale un poco distinto del de antes, pero no
        // de golpe: de a poco, que el agua no tiembla, ondula.
        final r = empujeVelo * ola * (1 + 0.16 * (_suave(k, 3, i / 5) - 0.5));
        final t = 0.05 * (_suave(k, 4, i / 7) - 0.5);
        return V3(dx * r - dz * t, 0.04, dz * r + dx * t);
      },
      suelo: pilon + 0.002,
    );
    velo.add(gotas);
    if (gotas.isNotEmpty && gotas.last.fin) caidas.add(gotas.last.p);
  }

  double gordo(int k, int i) => 0.70 + 0.60 * _suave(k, 5, i / 4);

  for (var k = 0; k < hilos; k++) {
    final gotas = velo[k];
    for (var j = 0; j + 1 < gotas.length; j++) {
      final a = gotas[j], b = gotas[j + 1];
      final u = clampD(a.edad / caeVelo, 0, 1);
      final wa = anchoVelo * gordo(k, a.i) * (1 - 0.40 * u);
      final wb = anchoVelo * gordo(k, b.i) * (1 - 0.40 * u);
      // Abajo se rompe: cuanto más ha caído, más fácil que entre esta gota
      // y la siguiente ya no haya agua.
      final roto = u > 0.68 && hash01(k, a.i, 6) < (u - 0.68) * 1.7;
      if (roto) {
        gota(a.p, a.v, wa * 0.85, 0.30, 0.62);
        continue;
      }
      tramo(
        a,
        b,
        wa,
        wb,
        0.12 + 0.25 * _suave(k, 7, a.i / 3),
        0.44,
        lamina: borde[k],
      );

      // Y la lámina entre este hilo y el siguiente, mientras no se rasgue.
      if (!medio) continue;
      final otro = velo[(k + 1) % hilos];
      if (j + 1 >= otro.length) continue;
      final c = otro[j], d = otro[j + 1];
      if (c.i != a.i || c.fin || d.fin || b.fin) continue;
      final rasga = 0.18 + 0.30 * _suave(k, 8, a.i / 3);
      if (a.edad > rasga) continue;
      final alfa = 0.30 * (1 - a.edad / rasga);
      final m = (a.p + b.p + c.p + d.p) * 0.25;
      pon((
        lejos(m) + 0.01,
        [
          cara([a.p, b.p, d.p, c.p], tono(m, b.p - a.p, 0.10, alfa)),
        ],
      ));
    }
  }

  // --------------------------------------------------------------- el pilón
  //
  // Donde cae el velo: espuma que bulle, gotas que saltan y ondas que se
  // abren hacia el borde y hacia el pilar.
  final yPilon = pilon + 0.004;
  final bulle = lerpD(0.45, 1.0, dia);
  for (var k = 0; k < caidas.length; k++) {
    final p = caidas[k];
    // Cada mancha a su aire: crece y mengua, se corre un poco y se ovala,
    // sin compás con las demás. Un collar de espumas iguales es un adorno.
    final r1 =
        (0.020 + 0.034 * _suave(k, 41, time * 2.3)) * lerpD(0.7, 1.0, bulle);
    final ex = 0.03 * (_suave(k, 42, time * 1.7) - 0.5);
    final ez = 0.03 * (_suave(k, 43, time * 1.9) - 0.5);
    mancha(
      p.x + ex,
      p.z + ez,
      yPilon,
      r1,
      conAlfa(blanco, (0.20 + 0.22 * _suave(k, 44, time * 3.1)) * bulle),
      lados: 7,
      giro: time * 0.9 + k,
      aplana: 0.6 + 0.4 * _suave(k, 45, time),
    );
    if (fino) {
      mancha(
        p.x - ex * 0.5,
        p.z - ez * 0.5,
        yPilon + 0.001,
        r1 * 0.5,
        conAlfa(blanco, 0.55 * bulle),
        lados: 5,
        giro: -time * 1.3 + k,
      );
    }
    if (!fino) continue;
    // Salpicaduras: cada una sale, sube un poco y vuelve a caer; cuando
    // cae, sale otra, de otro tamaño y hacia otro lado.
    for (var s = 0; s < 1; s++) {
      const vida = 0.38;
      final reloj = time / vida + hash01(k, s, 9);
      final turno = reloj.floor();
      final t = (reloj - turno) * vida;
      final ang = hash01(k, s, turno) * 2 * math.pi;
      final sube = lerpD(0.22, 0.48, hash01(k, s, turno, 1)) * bulle;
      final abre = 0.12 * hash01(k, s, turno, 2);
      final v0 = V3(math.cos(ang) * abre, sube, math.sin(ang) * abre);
      final q = p + v0 * t + V3(0, -_g * t * t / 2, 0);
      if (q.y <= pilon) continue;
      gota(q, v0 + V3(0, -_g * t, 0), 0.018, 0.65, 0.80);
    }
  }

  // Las ondas: donde cae el velo nace un anillo cada tanto, que se va hacia
  // el borde del pilón y otro hacia el pilar, apagándose.
  if (caidas.isNotEmpty) {
    var rCae = 0.0;
    for (final p in caidas) {
      rCae += math.sqrt((p.x - cx) * (p.x - cx) + (p.z - cz) * (p.z - cz));
    }
    rCae /= caidas.length;
    final lados = fino ? 20 : 12;
    final claro = _mezcla(cuerpo, blanco, 0.55);
    for (var o = 0; o < (medio ? 2 : 1); o++) {
      final f = (time * 0.75 * lerpD(0.6, 1, dia) + o / 2) % 1.0;
      final apaga = math.sin(math.pi * f);
      onda(
        yPilon,
        rCae + (pozo - 0.012 - rCae) * f,
        0.010,
        conAlfa(claro, 0.30 * apaga),
        lados,
      );
      onda(
        yPilon,
        rCae - 0.02 - (rCae - 0.02 - pilar - 0.01) * f,
        0.010,
        conAlfa(claro, 0.26 * apaga),
        lados,
      );
    }
  }

  // Y el sol en el agua: chispas que se encienden y se apagan, cada una en
  // un sitio distinto cada vez.
  if (fino && luzSol > 0.05) {
    for (var s = 0; s < 9; s++) {
      const vida = 0.9;
      final reloj = time / vida + hash01(s, 11);
      final turno = reloj.floor();
      final f = reloj - turno;
      final ang = hash01(s, turno, 12) * 2 * math.pi;
      final r = lerpD(pilar + 0.04, pozo - 0.03, hash01(s, turno, 13));
      mancha(
        cx + math.cos(ang) * r,
        cz + math.sin(ang) * r,
        yPilon + 0.002,
        0.016,
        conAlfa(destello, 0.85 * math.sin(math.pi * f) * luzSol),
        lados: 4,
        giro: 0.3,
        aplana: 0.5,
      );
    }
  }

  // ------------------------------------------------------------ el surtidor
  //
  // Del caño de la taza, derecho hacia arriba. La mayoría de las gotas suben
  // juntas —la columna— y una de cada cuatro sale abierta: es el penacho que
  // se abre arriba y cae como un paraguas sobre la taza.
  final altoChorro = lerpD(0.20, 0.46, dia);
  final vSube = math.sqrt(2 * _g * altoChorro);
  final dtChorro = fino ? 0.022 : 0.04;
  final vuela = 2 * vSube / _g + 0.12;
  final columna = <_Gota>[];
  final penacho = <_Gota>[];
  final boca = V3(cx, Plaza.spoutTop, cz);
  // La taza es donde cae casi todo; lo que se pase del borde sigue al pilón.
  double sueloChorro(V3 p) {
    final dx = p.x - cx, dz = p.z - cz;
    return dx * dx + dz * dz < (taza - 0.03) * (taza - 0.03)
        ? aguaTaza + 0.002
        : pilon + 0.002;
  }

  final chorro = vuelo(
    dt: dtChorro,
    cuantas: (vuela / dtChorro).ceil() + 2,
    boca: (i) => boca,
    empuje: (i, sale) {
      final ola =
          1 +
          0.07 * math.sin(2 * math.pi * 0.6 * sale) +
          0.04 * math.sin(2 * math.pi * 1.9 * sale + 1.0);
      final abierta = i % 4 == 0;
      final ang =
          (abierta ? hash01(i, 21) : _suave(0, 21, i / 8)) * 2 * math.pi;
      final abre = abierta
          ? lerpD(0.06, 0.20, hash01(i, 22)) * lerpD(0.6, 1, dia)
          : 0.022 * _suave(0, 23, i / 6);
      final sube =
          vSube *
          ola *
          (abierta ? 0.88 : 1 + 0.06 * (_suave(0, 24, i / 5) - 0.5));
      return V3(math.cos(ang) * abre, sube, math.sin(ang) * abre);
    },
    suelo: pilon + 0.002,
    sueloDe: sueloChorro,
  );
  for (final g in chorro) {
    (g.i % 4 == 0 ? penacho : columna).add(g);
  }
  final anchoChorro = lerpD(0.050, 0.068, dia);
  final caidasChorro = <V3>[];
  for (var j = 0; j + 1 < columna.length; j++) {
    final a = columna[j], b = columna[j + 1];
    if (b.i != a.i - 1 && b.i != a.i - 2) continue;
    final baja = a.v.y < 0;
    final roto = baja
        ? hash01(a.i, 25) < 0.80
        : a.v.y < 0.35 * vSube && hash01(a.i, 26) < 0.3;
    final wa =
        anchoChorro * (0.70 + 0.60 * _suave(0, 27, a.i / 4)) * (baja ? 0.7 : 1);
    if (roto || b.fin) {
      gota(a.p, a.v, wa * 0.60, 0.45, 0.62);
      if (b.fin) caidasChorro.add(b.p);
      continue;
    }
    final wb =
        anchoChorro *
        (0.70 + 0.60 * _suave(0, 27, b.i / 4)) *
        (b.v.y < 0 ? 0.7 : 1);
    tramo(a, b, wa, wb, 0.30 + 0.25 * hash01(a.i, 28), 0.62, alma: true);
  }
  for (final g in penacho) {
    if (g.fin) {
      caidasChorro.add(g.p);
      continue;
    }
    gota(g.p, g.v, anchoChorro * 0.40, 0.55, 0.62);
  }

  // Donde cae el surtidor, en la taza: anillos que se abren hasta el borde,
  // y donde cae algo, una chispa de espuma.
  final yTaza = aguaTaza + 0.004;
  if (medio) {
    final claro = _mezcla(cuerpo, blanco, 0.55);
    for (var o = 0; o < 2; o++) {
      final f = (time * 0.9 + o / 2) % 1.0;
      onda(
        yTaza,
        0.06 + (taza - 0.075) * f,
        0.008,
        conAlfa(claro, 0.30 * math.sin(math.pi * f)),
        fino ? 16 : 10,
      );
    }
  }
  for (final p in caidasChorro) {
    if (p.y < aguaTaza) continue;
    mancha(p.x, p.z, yTaza, 0.016, conAlfa(blanco, 0.55), lados: 5);
  }
  mancha(
    cx,
    cz,
    yTaza,
    0.05 + 0.01 * math.sin(time * 7),
    conAlfa(blanco, 0.40),
    lados: 7,
    giro: time,
  );

  // De lejos a cerca.
  // Y los pájaros que bajan a beber, ordenados con el agua: uno posado del
  // otro lado del pilón queda detrás del velo, y uno de este lado, delante.
  if (medio) {
    fountainBirds(l, eye, time, pal, (d, caras) => pon((d, caras)));
  }

  final orden = List<int>.generate(hondo.length, (i) => i)
    ..sort((a, b) => hondo[b].compareTo(hondo[a]));
  return [for (final i in orden) ...trozos[i]];
}

int _argb(Color c) => c.toARGB32();

/// Un ruido suave a lo largo de [x]: al azar en cada entero y de uno a otro
/// sin saltos. Es lo que hace que un chorro engorde y adelgace a lo largo de
/// unas cuantas gotas, y no de gota a gota como una sierra.
double _suave(int a, int b, double x) {
  final i = x.floor();
  final f = x - i;
  final t = f * f * (3 - 2 * f);
  return lerpD(hash01(a, b, i), hash01(a, b, i + 1), t);
}

int _mezcla(int a, int b, double t) {
  int ch(int s) {
    final x = (a >> s) & 0xFF, y = (b >> s) & 0xFF;
    return (x + (y - x) * t).round().clamp(0, 255);
  }

  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

int _escala(int a, double k) {
  int ch(int s) => (((a >> s) & 0xFF) * k).round().clamp(0, 255);
  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

// --------------------------------------------------------------- las sombras

/// Los puntos que echan sombra de una pieza, los mismos que usa la sombra en
/// el prado: la envolvente de éstos llevados al suelo a lo largo de la luz es
/// la sombra de la pieza.
void shadowPointsOf(
  TownPiece pc,
  void Function(double x, double y, double z) at,
) {
  void box(double y) {
    at(pc.x0, y, pc.z0);
    at(pc.x1, y, pc.z0);
    at(pc.x1, y, pc.z1);
    at(pc.x0, y, pc.z1);
  }

  switch (pc.kind) {
    case PieceKind.field:
    case PieceKind.water:
      return;
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
}

/// Los muebles de la plaza que echan sombra —la fuente y el tablón—, como
/// sólidos del mundo. Hechos una vez por plaza.
final Map<String, List<Solid>> _furniture = {};

List<Solid> plazaFurniture(TownLayout l) =>
    _furniture['${l.cx},${l.cz}'] ??= () {
      if (_furniture.length > 16) _furniture.clear();
      final todo = [
        ...Plaza.solidsAt(l.cx, l.cz, TownLayout.plazaReach),
        ...NoticeBoard.solidsAt(l.cx, l.cz),
      ];
      // Lo que asoma del suelo: el bordillo y la hierba de la plaza no echan
      // sombra que se vea, y el agua tampoco.
      return [
        for (final s in todo)
          if (s.faces.any((f) => f.v.any((v) => v.y > 0.15)) &&
              !s.faces.any((f) => f.surface == Surface.own))
            s,
      ];
    }();

/// La envolvente convexa de unos puntos del suelo, en el sentido contrario a
/// las agujas mirando desde arriba.
List<(double, double)> convexHull(List<(double, double)> pts) {
  if (pts.length < 3) return pts;
  final ps = [
    ...pts,
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  double cross((double, double) o, (double, double) a, (double, double) b) =>
      (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);
  final lower = <(double, double)>[];
  for (final p in ps) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }
  final upper = <(double, double)>[];
  for (final p in ps.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper.last, p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }
  lower.removeLast();
  upper.removeLast();
  return [...lower, ...upper];
}

/// Recorta el polígono [poly] con el polígono convexo [clip]. Los dos en el
/// mismo sentido que [convexHull].
List<(double, double)> clipConvex(
  List<(double, double)> poly,
  List<(double, double)> clip,
) {
  var out = poly;
  for (var i = 0; i < clip.length && out.isNotEmpty; i++) {
    final a = clip[i], b = clip[(i + 1) % clip.length];
    double side((double, double) p) =>
        (b.$1 - a.$1) * (p.$2 - a.$2) - (b.$2 - a.$2) * (p.$1 - a.$1);
    final inp = out;
    out = [];
    for (var j = 0; j < inp.length; j++) {
      final p = inp[j], q = inp[(j + 1) % inp.length];
      final sp = side(p), sq = side(q);
      if (sp >= 0) out.add(p);
      if ((sp >= 0) != (sq >= 0)) {
        final t = sp / (sp - sq);
        out.add((p.$1 + (q.$1 - p.$1) * t, p.$2 + (q.$2 - p.$2) * t));
      }
    }
  }
  return out;
}

/// Las sombras que caen sobre la plaza, como caras sobre su suelo.
///
/// La plaza está levantada del prado: las sombras del prado se pintan en el
/// suelo, por debajo de todo, y el césped de la plaza las tapaba. Se veía la
/// sombra de una casa llegar hasta el bordillo y cortarse en seco, y la fuente
/// y el tablón no echaban ninguna. Aquí se calculan sobre cada uno de los
/// tres suelos de la plaza —el césped, el bordillo y su canto, cada uno a su
/// altura— y se recortan a él, y se pintan de su color a la sombra.
List<Facet> plazaShadows(TownLayout l, int placed, Palette pal) {
  final dia = pal.isDaylight;
  final fuerza = dia
      ? 0.56 * smoothstep(0.02, 0.20, pal.sunDir.y)
      : 0.20 * smoothstep(0.2, 0.8, 1 - pal.daylight);
  if (fuerza < 0.01) return const [];
  final light = pal.lightDir;
  final ly = math.max(light.y, 0.10);
  final ox = -light.x / ly, oz = -light.z / ly;
  final reach = TownLayout.plazaReach;
  final cx = l.cx, cz = l.cz;

  // Lo que echa sombra, como puntos en el aire: la sombra de cada cosa sobre
  // un suelo a la altura `y` es la envolvente de esos puntos llevados a él.
  final echan = <List<V3>>[];
  final n = math.min(placed, l.pieces.length);
  final largo = math.sqrt(ox * ox + oz * oz);
  for (var i = 0; i < n; i++) {
    final pc = l.pieces[i];
    if (pc.y1 <= Plaza.lawnTop) continue;
    final dx = pc.cx - cx, dz = pc.cz - cz;
    final alcance = reach + largo * pc.y1 + math.max(pc.w, pc.d);
    if (dx * dx + dz * dz > alcance * alcance) continue;
    final pts = <V3>[];
    shadowPointsOf(pc, (x, y, z) => pts.add(V3(x, y, z)));
    if (pts.length >= 3) echan.add(pts);
  }
  for (final s in plazaFurniture(l)) {
    echan.add([for (final f in s.faces) ...f.v]);
  }

  // Los suelos: el césped entero, y el anillo de piedra en ocho trozos, que
  // un anillo no es convexo y cada trozo sí.
  List<List<(double, double)>> anillo(double r0, double r1) {
    final a = Plaza.ring(cx, cz, r0), b = Plaza.ring(cx, cz, r1);
    return [
      for (var k = 0; k < a.length; k++)
        convexHull([a[k], a[(k + 1) % a.length], b[(k + 1) % b.length], b[k]]),
    ];
  }

  // Del color de cada suelo, oscurecido lo mismo que oscurece la sombra del
  // prado —que es [fuerza] de tinta encima—, para que la de una casa que
  // empieza en el prado y acaba en la plaza se lea como una sola. `ao` escala
  // la luz entera, y la tinta es casi negra: con eso basta.
  final oscuro = 1 - fuerza * 0.92;
  final suelos = [
    (
      Plaza.lawnTop,
      [convexHull(Plaza.ring(cx, cz, reach * Plaza.lawnOut))],
      Surface.leaf,
      l.character.lawn.toARGB32(),
      1.02,
    ),
    (
      Plaza.kerbTop,
      anillo(reach * Plaza.lawnOut, reach * 0.975),
      Surface.stone,
      Plaza.kerbTint,
      1.0,
    ),
    (
      Plaza.kerbTop + 0.02,
      anillo(reach * 0.975, reach),
      Surface.stone,
      Plaza.edgeTint,
      0.94,
    ),
  ];

  final out = <Facet>[];
  for (final (alto, trozos, surface, tint, ao) in suelos) {
    final y = alto + 0.004;
    for (final pts in echan) {
      final suelo = [
        for (final v in pts)
          if (v.y > alto - 1e-6)
            (v.x + ox * (v.y - alto), v.z + oz * (v.y - alto)),
      ];
      if (suelo.length < 3) continue;
      final sombra = convexHull(suelo);
      for (final trozo in trozos) {
        final c = clipConvex(sombra, trozo);
        if (c.length < 3) continue;
        out.add(
          Facet(
              [for (final p in c) V3(p.$1, y, p.$2)],
              const V3(0, 1, 0),
              surface,
              ao: ao * oscuro,
              tint: tint,
            )
            ..data = l.character.order
            ..piece = -1,
        );
      }
    }
  }
  return out;
}
