/// De qué está hecha una persona: las cajas, y en qué orden se pintan.
///
/// La otra mitad de `folk.dart`, y la que no tiene nada que ver con la
/// primera. Aquélla decide **quién** vive en el pueblo, dónde está a cada hora
/// y hacia dónde va; ésta coge uno de ésos y un instante, y devuelve la
/// veintena de cajas que lo dibujan — el cuerpo, la ropa, el pelo, lo que
/// lleva en la mano.
///
/// De todo lo que había en aquel fichero, esto es lo único que sólo necesita
/// los dos tipos de datos: [Townsfolk] y [FolkAt]. Ni el plano del pueblo, ni
/// el censo, ni los caminos. Por eso se puede mirar una persona sola en medio
/// del prado en el expositor de actividades sin que haya un pueblo detrás.
library;

import 'dart:math' as math;

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/doings.dart';
import '../data/folknames.dart';
import 'folk.dart';
import 'pigeons.dart';
import 'solid.dart';
import 'solids.dart';

/// Lo dentro de casa que está la gente ahora mismo, de cero a uno.
///
/// Cero de día, uno de noche. Sale de la luz que hay y no de la hora, así que
/// en invierno se recogen antes — que es lo que pasa — sin que haya ninguna
/// hora escrita en ningún sitio.
///
/// La franja es ancha a propósito. Con una estrecha el pueblo se vaciaba en
/// diez minutos de reloj del valle, y un pueblo que se vacía de golpe es una
/// luz que se apaga: lo que tiene que verse es a todo el mundo tirando para su
/// casa mientras el sol baja, que es hora y media larga. Empieza en cuanto la
/// luz cede —no cuando ya es de noche— porque nadie espera a que oscurezca
/// para volver.
double folkHome(double daylight) => 1 - smoothstep(0.04, 0.88, daylight);

/// El paño con el que va vestida la gente de este valle.
///
/// Tintes que se sacaban de lo que había: rubia, gualda, glasto, nogal, y la
/// lana sin teñir, que era lo más barato y por eso lo más común. Nada
/// saturado — un vecino de tres píxeles con una camisa roja de semáforo se
/// lleva la mirada por delante del pueblo entero, que es lo contrario de lo
/// que hace falta.
const List<int> _cloth = [
  0xFF9A5A46, // rubia
  0xFF7E6B47, // nogal
  0xFF4F5F6E, // glasto
  0xFFA08650, // gualda
  0xFF8C8477, // lana sin teñir
  0xFF5E6B52, // verde de líquenes
  0xFF6E5566, // malva
];

/// Y la piel, que también tiene más de un color.
///
/// Doce y no cinco, y repartidos de verdad por todo el rango en vez de cuatro
/// tonos medios y uno oscuro. Un pueblo de cuarenta vecinos con cinco tonos se
/// ve como cinco personas repetidas ocho veces; con doce no se nota que haya
/// una lista detrás, que es justo lo que hay que conseguir.
const List<int> _skin = [
  0xFFF2D7BC,
  0xFFE8C4A0,
  0xFFDCB088,
  0xFFC79B77,
  0xFFBE8C68,
  0xFFAD7F5C,
  0xFF9C6E4E,
  0xFF8C6247,
  0xFF7A533C,
  0xFF6A4630,
  0xFF573827,
  0xFF462C1E,
];

/// Y el pelo, que es lo que se ve de una cabeza a esta distancia: una mancha
/// de color encima de la cara, que separa a dos vecinos mejor que la cara.
const List<int> _hair = [
  0xFF2B211A,
  0xFF3E2C1E,
  0xFF5A3C24,
  0xFF7A5330,
  0xFF9A7040,
  0xFFB89055,
  0xFF8A8178,
  0xFFD8D2C6,
  0xFF6B3A22,
];

/// La madera de los mangos y las varas, que es la misma en todo el valle.
const int _wood2 = 0xFF6B5236;

/// Una persona, en cajas cerradas como todo lo demás del valle.
///
/// Tres piezas: el cuerpo, la cabeza y el pelo. Con eso basta y sobra —
/// a la distancia a la que se mira un pueblo, un vecino ocupa entre tres y
/// veinte píxeles, y lo que se lee de él es la silueta y el color, no los
/// dedos. Lo que sí se lee, y mucho, es **que se mueva**: el paso de las
/// piernas y el bamboleo del cuerpo es lo que separa a una persona andando de
/// un palo deslizándose por el suelo.
///
/// [size] es lo que mide de alto, y sale de la altura de planta de la región:
/// una persona tiene que caber por su propia puerta, y las puertas de la
/// Sierra no miden lo que las de la Ribera.
///
/// [detail] baja de uno a cero con la distancia. Por debajo de la mitad se
/// quedan cuerpo y cabeza y se van las piernas, que a esa distancia son dos
/// píxeles que parpadean.
/// Las cajas de una persona, puestas en el orden en que hay que pintarlas
/// desde [eye]: primero las de atrás.
///
/// Descartar las caras traseras deja exacto el interior de *una* caja cerrada,
/// pero no dice nada de en qué orden van dos cajas distintas — y una persona
/// son cuatro o cinco: cuerpo, cabeza, pelo, y lo que lleve. Se pintaban en el
/// orden en que se crean, y lo que lleva se crea el último, así que el libro se
/// pintaba **siempre** encima del cuerpo: de frente colaba, y desde detrás se
/// veía el libro atravesando a quien lo estaba leyendo.
///
/// Aquí vale ordenar por el centro, y no es una excepción a la regla del valle
/// —«entre sólidos se ordena por geometría exacta, no por una media»—. Es que
/// la media *es* exacta en este caso: las cajas de una persona son pocas,
/// convexas y **no se atraviesan entre ellas**, y para sólidos separados el
/// orden por centro es el mismo que daría un plano de separación. Cuesta cinco
/// comparaciones en vez de un árbol por vecino y por fotograma.
///
/// Pública y aparte del render para que el barrido de cámaras de
/// `depth_test.dart` pruebe exactamente el orden que se pinta, y no una copia
/// suya escrita en el test.
List<Solid> folkInPaintOrder(List<Solid> solids, V3 eye) {
  if (solids.length < 2) return solids;
  double far(Solid s) {
    final box = Aabb.of(s.faces);
    if (box == null) return 0;
    final dx = box.cx - eye.x, dy = box.cy - eye.y, dz = box.cz - eye.z;
    return dx * dx + dy * dy + dz * dz;
  }

  final keyed = [for (final s in solids) (far(s), s)]
    ..sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final k in keyed) k.$2];
}

List<Solid> folkSolids(
  Townsfolk who,
  FolkAt at,
  double size, {
  double detail = 1.0,
  double lift = 0.0,
  V3? eye,
  FeastPose? feast,
  bool measuring = false,
}) {
  final seed = who.seed;
  // Lo que mide éste. Un crío mide dos tercios de lo que mide su madre, y un
  // pueblo donde todos miden lo mismo es un pueblo de maniquíes.
  final h = size * who.build;
  final cos = math.cos(at.heading), sin = math.sin(at.heading);

  // Del sistema de la persona —adelante en +z, a su izquierda en +x— al del
  // valle. Girar aquí y no en cada caja es lo que mantiene esto legible.
  //
  // **Todo va en partes de lo que mide.** Lo ancho estaba en unidades del
  // valle y lo alto en partes de la persona, y eso quiere decir dos cosas
  // malas a la vez: que un crío sale tan ancho como su madre —o sea, un
  // barril— y que en la Sierra, donde las plantas son más altas, la gente sale
  // más alta pero igual de ancha. Con una sola unidad, una persona es la misma
  // persona en todas las regiones y a cualquier talla.
  V3 world(double x, double y, double z) => V3(
    at.x + (x * cos + z * sin) * h,
    lift + y * h,
    at.z + (-x * sin + z * cos) * h,
  );

  final out = <Solid>[];
  void box(
    double x0,
    double y0,
    double z0,
    double x1,
    double y1,
    double z1,
    int tint,
    double ao,
  ) {
    // Las ocho esquinas giradas, y de ahí las seis caras. No se puede usar
    // `boxFaces`: eso da una caja alineada a los ejes del mundo, y una persona
    // mira hacia donde va.
    final p = [
      world(x0, y0, z0),
      world(x1, y0, z0),
      world(x1, y0, z1),
      world(x0, y0, z1),
      world(x0, y1, z0),
      world(x1, y1, z0),
      world(x1, y1, z1),
      world(x0, y1, z1),
    ];
    final up = V3(0, 1, 0);
    final fwd = V3(sin, 0, cos), right = V3(cos, 0, -sin);
    out.add(
      Solid(-1, [
        Facet([p[3], p[2], p[6], p[7]], fwd, Surface.cloth, ao: ao, tint: tint),
        Facet(
          [p[1], p[0], p[4], p[5]],
          V3(-fwd.x, 0, -fwd.z),
          Surface.cloth,
          ao: ao * 0.94,
          tint: tint,
        ),
        Facet(
          [p[1], p[5], p[6], p[2]],
          right,
          Surface.cloth,
          ao: ao * 0.97,
          tint: tint,
        ),
        Facet(
          [p[0], p[3], p[7], p[4]],
          V3(-right.x, 0, -right.z),
          Surface.cloth,
          ao: ao * 0.97,
          tint: tint,
        ),
        Facet([p[4], p[7], p[6], p[5]], up, Surface.cloth, ao: ao, tint: tint),
        Facet(
          [p[0], p[1], p[2], p[3]],
          V3(0, -1, 0),
          Surface.cloth,
          ao: ao * 0.8,
          tint: tint,
        ),
      ]),
    );
  }

  final pano = _cloth[hashInt(_cloth.length, seed, 2)];
  // El consejero, siempre el mismo: de piel clara en todos los valles. La
  // sacaba de su semilla, que cambia con el valle, y en uno nuevo salía de
  // otro color que en su pantalla, donde está el de siempre.
  final piel = who.sage ? _skin[1] : _skin[hashInt(_skin.length, seed, 3)];
  final pelo = _hair[hashInt(_hair.length, seed, 5)];

  final act = at.act;
  final ph = at.phase;

  // El cuerpo entero sale de cinco números de la tabla. No hay un caso por
  // actividad: hay una manera de moverse, y sesenta juegos de números.
  final sit = act?.sink ?? 0.0;
  // Sentado en el suelo pierde lo de abajo del cuerpo —las piernas, que
  // pasan a ir hacia delante— y no un poco de todo: el torso son los dos
  // tercios de arriba, las piernas el tercio de abajo, y la cabeza baja con
  // el torso. Ver [Doing.seated].
  final sentado = !at.moving && (act?.seated ?? false);
  final baja = sentado ? _piernas : sit * 0.26;

  /// A qué altura tiene los pies.
  ///
  /// Cero en el suelo, que es lo normal. Quien tiene banqueta se sienta
  /// **encima** de ella y no delante: sin esto el cuerpo seguía arrancando del
  /// suelo y la banqueta le salía por dentro, que era alguien de pie sobre una
  /// mesita.
  final asiento = sentado && act?.prop == PropKind.stool ? _banqueta : 0.0;

  // Lo único que anima a alguien sin brazos ni piernas: que suba y baje, que
  // se incline y que se balancee. Y alcanza de sobra — el paso de unas piernas
  // de dos píxeles no se ve, y el bamboleo de un cuerpo entero sí.
  //
  // Andando sube y baja dos veces por zancada, una por pie que no está ahí.
  // Parado, lo que diga lo que esté haciendo: el que habla se mueve, el que
  // pica piedra dobla el espinazo, el que baila da saltos, y el que no hace
  // nada respira.
  final beat = act == null ? 0.0 : ph * act.rate + hash01(seed, 16) * 6;
  final swing = act == null ? 0.0 : math.sin(beat);
  final salta = !at.moving && (act?.hop ?? false);
  final bob = at.moving || act == null || salta
      ? 0.0
      : act.bob * (act.bob < 0 ? math.max(0.0, swing) : swing);

  /// Y quien salta despega entero: no es estirarse, son los pies los que
  /// dejan el suelo. Sube con el valor absoluto, así que vuelve a tocar
  /// tierra dos veces por vuelta de [beat], con el golpe seco de un salto.
  ///
  /// **Andar también es dar saltitos**: uno por paso, despegando del suelo y
  /// cayendo seco. Antes andar era estirarse y encogerse sin levantar los
  /// pies, y una figura sin piernas que no despega se lee como algo que
  /// resbala por la calle. Con el saltito se lee el paso.
  final piso =
      asiento +
      (at.moving
          ? 0.045 * math.sin(at.gait).abs()
          : salta
          ? act!.bob * swing.abs()
          : 0.0);
  // Andando no se ladea: va derecho, a saltitos. El vaivén de un pie al otro
  // se leía como un zigzag del torso, y lo que dice «paso» ya lo dice el
  // saltito.
  final wag = at.moving ? 0.0 : (act?.wag ?? 0.0) * swing;
  final lean = at.moving ? 0.020 : (act?.lean ?? 0.0);

  /// Dónde le flota lo que lleva. No hay mano: hay un sitio a la altura y al
  /// lado de donde estaría, y lo que se sostiene se queda ahí. A esta
  /// distancia es lo mismo, y una mano de tres píxeles no es una mano.
  (double, double, double) hold(double s, double raise, double fwd) => (
    s * 0.150 + wag,
    piso + 0.26 + raise * 0.34 + bob - baja,
    0.13 + fwd + lean,
  );

  /// Una vara entre dos puntos: el mango de una herramienta, la cuerda de un
  /// caldero, el sedal de una caña. [box] sólo sabe hacer cajas rectas
  /// en el sistema de la persona, y una cuerda va en diagonal.
  void link(
    (double, double, double) a,
    (double, double, double) b,
    double r,
    int tint,
    double ao, {
    double? deep,
  }) {
    final dx = b.$1 - a.$1, dy = b.$2 - a.$2, dz = b.$3 - a.$3;
    final len = math.sqrt(dx * dx + dy * dy + dz * dz);
    if (len < 1e-5) return;
    final u = V3(dx / len, dy / len, dz / len);
    // Un perpendicular cualquiera, evitando el caso en que la vara es vertical.
    var pv = u.y.abs() > 0.9 ? V3(1, 0, 0) : V3(0, 1, 0);
    pv = (pv - u * pv.dot(u)).normalized;
    final q = u.cross(pv).normalized;
    V3 corner(double sa, double sp, double sq) {
      final at0 = sa < 0 ? a : b;
      return world(
        at0.$1 + pv.x * sp * r + q.x * sq * (deep ?? r),
        at0.$2 + pv.y * sp * r + q.y * sq * (deep ?? r),
        at0.$3 + pv.z * sp * r + q.z * sq * (deep ?? r),
      );
    }

    // Índice = extremo * 4 + p * 2 + q.
    final c = [
      for (final sa in [-1.0, 1.0])
        for (final sp in [-1.0, 1.0])
          for (final sq in [-1.0, 1.0]) corner(sa, sp, sq),
    ];
    V3 turn(V3 v) =>
        V3(v.x * cos + v.z * sin, v.y, -v.x * sin + v.z * cos).normalized;
    final pw = turn(pv), qw = turn(q), uw = turn(u);
    out.add(
      Solid(-1, [
        Facet([c[2], c[3], c[7], c[6]], pw, Surface.cloth, ao: ao, tint: tint),
        Facet(
          [c[1], c[0], c[4], c[5]],
          V3(-pw.x, -pw.y, -pw.z),
          Surface.cloth,
          ao: ao,
          tint: tint,
        ),
        Facet([c[3], c[1], c[5], c[7]], qw, Surface.cloth, ao: ao, tint: tint),
        Facet(
          [c[0], c[2], c[6], c[4]],
          V3(-qw.x, -qw.y, -qw.z),
          Surface.cloth,
          ao: ao,
          tint: tint,
        ),
        Facet([c[5], c[4], c[6], c[7]], uw, Surface.cloth, ao: ao, tint: tint),
        Facet(
          [c[0], c[1], c[3], c[2]],
          V3(-uw.x, -uw.y, -uw.z),
          Surface.cloth,
          ao: ao,
          tint: tint,
        ),
      ]),
    );
  }

  void props(Doing act) {
    switch (act.prop) {
      case PropKind.none:
        break;

      case PropKind.broom:
        // Mango y cepillo, y el cepillo apoyado en el suelo por delante. Lo que
        // hace que sea una escoba y no una vara es el cepillo: ancho, plano,
        // más oscuro que el palo y a ras de suelo.
        final m = hold(1, 0.52, 0.02);
        const cz = 0.52; // dónde apoya, por delante
        final barrido = math.sin(ph * act.rate) * 0.12;
        link(m, (barrido, 0.045, cz), 0.017, _wood2, 0.94);
        // El cepillo: ancho de lado a lado y en el sentido en que se barre.
        box(
          barrido - 0.115,
          0.0,
          cz - 0.050,
          barrido + 0.115,
          0.075,
          cz + 0.050,
          0xFFB99A55,
          0.90,
        );
        // Y el remate donde se enmanga, que es lo que separa el cepillo del
        // mango en vez de que uno salga del otro sin más.
        box(
          barrido - 0.038,
          0.070,
          cz - 0.032,
          barrido + 0.038,
          0.105,
          cz + 0.032,
          _wood2,
          0.94,
        );

      case PropKind.book:
        // Un libro abierto: dos páginas en ángulo con su tapa por debajo y el
        // lomo en medio. Sostenido delante y un poco inclinado, que es como se
        // lee sentado.
        // Delante y en medio, sobre las piernas: sentado en el suelo el libro
        // se sostiene encima del regazo, no a un costado.
        final m = hold(0, 0.42, 0.06);
        final y = m.$2, z = m.$3;
        const ancho = 0.140, fondo = 0.128;
        // El lomo.
        box(-0.016, y, z, 0.016, y + 0.022, z + fondo, 0xFF6B4B2E, 0.94);
        for (final lado in [1.0, -1.0]) {
          // La tapa, un pelo más ancha que la hoja y por debajo.
          box(
            lado * 0.016,
            y - 0.004,
            z,
            lado * (ancho + 0.012),
            y + 0.016,
            z + fondo,
            0xFF6B4B2E,
            0.93,
          );
          // Y la hoja encima, levantada por el canto de fuera: es ese desnivel
          // el que hace que se lea «abierto» y no «tablilla».
          box(
            lado * 0.016,
            y + 0.016,
            z,
            lado * ancho,
            y + 0.030,
            z + fondo,
            0xFFF2EDDD,
            1.06,
          );
        }

      case PropKind.rod:
        // La caña: una diagonal larga que sale del costado y cruza toda la
        // silueta hacia arriba, y el sedal cayendo al agua desde la punta. Es
        // la silueta más larga de todas, y por eso se reconoce de lejos.
        final m = hold(1, 0.30, 0.02);
        final punta = (m.$1 + 0.30, m.$2 + 0.78, m.$3 + 1.00);
        link(m, punta, 0.012, _wood2, 0.95);
        link(punta, (punta.$1, 0.01, punta.$3 + 0.06), 0.004, 0xFFD8D2C0, 1.06);
        // El flotador, donde el sedal toca el agua.
        box(
          punta.$1 - 0.028,
          0.010,
          punta.$3 + 0.032,
          punta.$1 + 0.028,
          0.060,
          punta.$3 + 0.088,
          0xFFBF4A32,
          1.04,
        );

      case PropKind.lute:
        // El laúd contra el pecho, cruzado y **con forma de laúd**.
        //
        // Lo que lo hace leerse a veinte píxeles sigue siendo lo de antes: la
        // caja del tamaño de la cabeza, más clara que cualquier sayo, y el
        // mástil saliendo por fuera de la silueta. Pero era una caja recta con
        // un palo pegado en diagonal, y un laúd es una sola línea: la caja va
        // a lo largo del mástil y se ensancha en pera hacia abajo. Así que
        // todo se arma sobre ese eje —la pera en tres tramos, la tapa clara
        // delante del fondo oscuro, la boca, el puente, el diapasón, las
        // cuerdas y el clavijero doblado hacia atrás con sus clavijas—, y
        // sigue siendo un puñado de cajas.
        final m = hold(-1, 0.50, 0.11);
        const ux = 0.79, uy = 0.61; // a lo largo del mástil
        const vx = -0.61, vy = 0.79; // a lo ancho de la tapa
        final cx = m.$1 - 0.10, cy = m.$2 - 0.02, cz = m.$3 + 0.055;
        (double, double, double) en(double a, double b, double dz) =>
            (cx + ux * a + vx * b, cy + uy * a + vy * b, cz + dz);
        const fondo = 0xFF8A5530, tapa = 0xFFEACB8E, oscuro = 0xFF2E1F14;
        const mastil = 0xFF6E4524;
        // La pera: ancha abajo, angosta hacia el mástil. El fondo, de nogal;
        // la tapa, de abeto claro, un poco más chica y por delante.
        for (final (a0, a1, r) in const [
          (-0.20, -0.10, 0.118),
          (-0.10, -0.01, 0.100),
          (-0.01, 0.05, 0.072),
        ]) {
          link(en(a0, 0, 0), en(a1, 0, 0), r, fondo, 0.92, deep: 0.052);
          link(
            en(a0 + 0.008, 0, 0.060),
            en(a1 - 0.004, 0, 0.060),
            r - 0.014,
            tapa,
            1.06,
            deep: 0.008,
          );
        }
        // La boca, con su rosa oscura, y el puente abajo, atravesado.
        link(
          en(-0.050, 0, 0.068),
          en(-0.004, 0, 0.068),
          0.026,
          oscuro,
          0.84,
          deep: 0.004,
        );
        link(
          en(-0.150, -0.050, 0.068),
          en(-0.150, 0.050, 0.068),
          0.009,
          oscuro,
          0.86,
          deep: 0.006,
        );
        // El mástil, y encima el diapasón negro, que es lo que lo afina a
        // la vista.
        link(
          en(0.04, 0, 0.010),
          en(0.43, 0, 0.010),
          0.024,
          mastil,
          1.0,
          deep: 0.020,
        );
        link(
          en(0.04, 0, 0.033),
          en(0.43, 0, 0.033),
          0.018,
          oscuro,
          0.9,
          deep: 0.004,
        );
        // Dos cuerdas claras, del puente a la cejuela.
        for (final b in const [-0.011, 0.011]) {
          link(
            en(-0.150, b, 0.074),
            en(0.43, b, 0.040),
            0.0028,
            0xFFF4EAD2,
            1.12,
            deep: 0.0028,
          );
        }
        // El clavijero, doblado hacia atrás —lo que tiene un laúd y no una
        // guitarra—, con tres clavijas claras a cada lado.
        final p0 = en(0.43, 0, 0.010), p1 = en(0.50, 0, -0.085);
        link(p0, p1, 0.026, oscuro, 0.92, deep: 0.016);
        for (var k = 0; k < 3; k++) {
          final t = 0.25 + k * 0.25;
          final p = (
            p0.$1 + (p1.$1 - p0.$1) * t,
            p0.$2 + (p1.$2 - p0.$2) * t,
            p0.$3 + (p1.$3 - p0.$3) * t,
          );
          link(
            (p.$1 - vx * 0.045, p.$2 - vy * 0.045, p.$3),
            (p.$1 + vx * 0.045, p.$2 + vy * 0.045, p.$3),
            0.007,
            0xFFE9D6AE,
            1.08,
          );
        }

      case PropKind.drum:
        // El tambor colgado delante de la tripa, con la piel clara arriba, y
        // las dos baquetas bajando una y otra. La caja roja y los aros oscuros
        // son lo que lo separa de un cubo.
        final y0 = piso + 0.22 + bob, y1 = y0 + 0.20;
        const z0 = 0.16, z1 = 0.40;
        box(-0.130, y0, z0, 0.130, y1, z1, 0xFFA34A30, 0.95);
        for (final ay in [y0 - 0.005, y1 - 0.030]) {
          box(
            -0.142,
            ay,
            z0 - 0.012,
            0.142,
            ay + 0.035,
            z1 + 0.012,
            0xFF5A3A24,
            0.90,
          );
        }
        box(
          -0.118,
          y1,
          z0 + 0.012,
          0.118,
          y1 + 0.014,
          z1 - 0.012,
          0xFFEADCB8,
          1.08,
        );
        for (final s in [1.0, -1.0]) {
          final alza = 0.5 + 0.5 * math.cos(beat + (s > 0 ? 0 : math.pi));
          final punta = (s * 0.055, y1 + 0.020 + alza * 0.20, 0.29);
          final mano = (s * 0.215, y1 + 0.110 + alza * 0.14, 0.20);
          link(mano, punta, 0.015, 0xFFD8C08A, 1.0);
          box(
            punta.$1 - 0.020,
            punta.$2 - 0.020,
            punta.$3 - 0.020,
            punta.$1 + 0.020,
            punta.$2 + 0.020,
            punta.$3 + 0.020,
            0xFFEADCB8,
            1.04,
          );
        }

      case PropKind.stool:
        // Una banqueta de tres patas, a la altura a la que se sienta quien se
        // sienta en ella (ver [_banqueta]).
        const alto = _banqueta;
        box(-0.135, alto - 0.045, -0.120, 0.135, alto, 0.120, _wood2, 0.88);
        for (final (px, pz) in [
          (-0.095, -0.080),
          (0.095, -0.080),
          (0.0, 0.092),
        ]) {
          box(
            px - 0.024,
            0.0,
            pz - 0.024,
            px + 0.024,
            alto - 0.040,
            pz + 0.024,
            _wood2,
            0.84,
          );
        }
    }
  }

  /// Lo que se trajo de casa, llevado: la banqueta colgando de una mano, el
  /// barreño delante con las dos, la carretilla empujada con la rueda en el
  /// suelo.
  void carried(PropKind what) {
    switch (what) {
      case PropKind.stool:
        final m = hold(1, 0.05, -0.02);
        const alto = 0.17;
        final y0 = m.$2 - alto - 0.02;
        box(
          m.$1 + 0.02,
          y0 + alto - 0.04,
          m.$3 - 0.10,
          m.$1 + 0.24,
          y0 + alto,
          m.$3 + 0.10,
          _wood2,
          0.88,
        );
        for (final (px, pz) in [(0.05, -0.07), (0.21, -0.07), (0.13, 0.08)]) {
          box(
            m.$1 + px - 0.020,
            y0,
            m.$3 + pz - 0.020,
            m.$1 + px + 0.020,
            y0 + alto - 0.04,
            m.$3 + pz + 0.020,
            _wood2,
            0.84,
          );
        }
      default:
        break;
    }
  }

  // La figura: un cuerpo, una cabeza y el pelo. Tres cajas.
  //
  // **Un cuerpo, no un tronco y unas calzas.** Eran dos cajas de dos colores
  // —la falda del sayo y los hombros— y a la distancia a la que se mira un
  // pueblo eso no se lee como ropa: se lee como una raya horizontal que le
  // parte la silueta a todo el mundo por el mismo sitio. De una pieza y de un
  // color, la silueta vuelve a ser una silueta.
  //
  // Y sin brazos ni piernas a propósito, que no es por ahorrar caras: un
  // vecino ocupa entre tres y veinte píxeles, y ahí unas piernas son dos rayas
  // que parpadean y unos brazos una mancha que ensancha la silueta hasta que
  // deja de parecer una persona. Lo que se lee a esa distancia es la silueta,
  // el color y el movimiento. Es además lo que hace el resto del valle: una
  // casa tampoco tiene picaporte.
  //
  // Las proporciones son las de cualquier cosa dibujada que caiga bien, y hubo
  // que llegar a ellas de tres intentos:
  //
  //  - La cabeza ocupa **casi la mitad** de lo que mide, y es cúbica: tan
  //    ancha como alta. Con una cabeza de un tercio y estrecha, la figura
  //    seguía leyéndose como un poste con gorro.
  //  - Y es **más ancha que el cuerpo**, un tercio más. Mientras las dos cajas
  //    medían casi lo mismo de ancho no había cabeza: había una columna con
  //    una raya de color.
  //  - El cuerpo, corto y ancho, uno a dos. Estrecho volvía la columna.
  if (act?.lying ?? false) {
    // Tumbado: la misma persona acostada, no una más agachada.
    //
    // Es una figura aparte y no otro número, porque no hay manera de decir
    // «acostado» con lo agachado que está alguien: el cuerpo se tiende a lo
    // largo, la cabeza se va a un extremo y el pecho sube y baja despacio, que
    // es lo único que distingue a alguien durmiendo de un bulto en el prado.
    // Largo y bajo, que es lo que hace que se lea «tumbado» y no «cajón»: un
    // cuerpo de pie mide uno de alto por tres décimas de ancho, y acostado
    // tiene que medir eso mismo girado.
    final resuella = bob * 0.7;
    box(-0.150, 0.0, -0.50, 0.150, 0.230 + resuella, 0.17, pano, 0.98);
    // La cabeza, un cubo entero por delante del cuerpo y apenas levantada del
    // suelo: apoyada del todo en la hierba no se distingue, y es lo único que
    // dice de qué lado está la cara.
    box(-0.185, 0.020, 0.16, 0.185, 0.390, 0.53, piel, 1.02);
    // **Y la cabeza gira con el cuerpo, no sólo el cuerpo.**
    //
    // El pelo iba encima de la cabeza, como de pie — así que alguien tumbado
    // mirando las nubes salía con la coronilla apuntando al cielo y la cara
    // hacia los pies, que es la postura de nadie. Acostado boca arriba la cara
    // mira arriba y la coronilla se va al extremo de más allá de la cabeza,
    // que es el lado contrario al cuerpo.
    //
    // Así que el pelo deja de ser una tapa y pasa a ser el testero: la misma
    // caja girada un cuarto de vuelta, en el canto de +z. Es lo único que hace
    // falta para que se lea tumbado, porque a esta distancia de qué lado está
    // el pelo **es** la orientación de la cabeza — no hay cara que mirar.
    if (detail > 0.25) {
      box(-0.191, 0.015, 0.44, 0.191, 0.396, 0.545, pelo, 1.0);
    }
    return out;
  }

  if (who.sage) {
    // Sentado, sobre el asiento del banco: la altura del asiento en partes de
    // lo que mide, que es en lo que va todo aquí.
    _sabio(
      box,
      link,
      at,
      piel,
      detail,
      bob,
      sentado ? PlazaBench.seat / h : 0,
      sentado ? feast : null,
    );
    return out;
  }

  box(
    -0.150 + wag,
    piso,
    -0.116 + lean * 0.5,
    0.150 + wag,
    piso + 0.56 + bob - baja,
    0.116 + lean * 0.5,
    pano,
    1.0,
  );
  // **Sentado: una sola postura para todos.** Leer en el prado, pescar en
  // la orilla, sentarse en la banqueta de la puerta: cualquier actividad
  // que diga [Doing.seated] se sienta así, y cambiar cómo se sienta la gente
  // es cambiar esto y nada más.
  //
  // Las piernas, del mismo color que el cuerpo, salen hacia delante desde su
  // pie: con el cuerpo hacen una L. Tan largas como lo que el cuerpo perdió
  // de alto, un tercio. Y si el asiento no es el suelo, bajan hasta él.
  if (sentado) {
    final frente = 0.116 + lean * 0.5;
    box(
      -0.150 + wag,
      piso,
      frente - 0.02,
      0.150 + wag,
      piso + 0.13,
      frente + _piernas,
      pano,
      0.97,
    );
    if (piso > 0.02) {
      box(
        -0.150 + wag,
        0.0,
        frente + _piernas - 0.11,
        0.150 + wag,
        piso,
        frente + _piernas,
        pano,
        0.95,
      );
    }
  }
  box(
    -0.205 + wag * 0.4,
    piso + 0.520 + bob - baja,
    -0.175 + lean * 1.5,
    0.205 + wag * 0.4,
    piso + 0.960 + bob - baja,
    0.175 + lean * 1.5,
    piel,
    1.02,
  );
  // El pelo, que es un gorro encima de la cara. A quince píxeles la cara es un
  // punto y el pelo es la mitad de la cabeza: es lo que hace que dos vecinos
  // no se confundan de lejos.
  //
  // **El gorro, y ellas una caja más.** Ellos, un gorro corto arriba; ellas,
  // el mismo gorro y la melena: una caja que cae por detrás y por los lados
  // hasta media espalda, con la cara asomando por delante. Con una sola caja
  // para ellas, de frente no les quedaba pelo sobre la frente y parecían
  // calvas; con tablas —nuca, mechones, flequillo— eran demasiadas figuras
  // para una persona que es tres cajas. Que las cajas se metan en la cabeza
  // no importa: de cerca el orden lo da un árbol de planos, que corta lo que
  // se cruza.
  if (detail > 0.25) {
    box(
      -0.212 + wag * 0.4,
      piso + 0.830 + bob - baja,
      -0.182 + lean * 1.5,
      0.212 + wag * 0.4,
      piso + 0.985 + bob - baja,
      0.182 + lean * 1.5,
      pelo,
      1.0,
    );
    if (folkIsWoman(seed)) {
      // Del mismo ancho, la misma nuca y la misma altura que el gorro, y del
      // mismo tono: las dos cajas se juntan a ras, sin escalón ni costura, y
      // se leen como una sola melena.
      box(
        -0.212 + wag * 0.4,
        piso + 0.380 + bob - baja,
        -0.182 + lean * 1.5,
        0.212 + wag * 0.4,
        piso + 0.985 + bob - baja,
        0.060 + lean * 1.5,
        pelo,
        1.0,
      );
    }
  }

  // Y lo que lleva.
  //
  // **Hecho de verdad, con las piezas que haga falta.** Antes eran quince
  // formas genéricas y cada actividad elegía una con otro tamaño y otro color,
  // y así la escoba salía siendo un palo. Un palo no es una escoba. No era que
  // la animación no se entendiera: era que el objeto estaba mal.
  //
  // Cada cosa se gasta las cajas que necesita para ser esa cosa y no otra. Son
  // pocas actividades a propósito, y por eso se pueden hacer bien.
  // Lo que lleva en las manos de un sitio a otro.
  final lleva = at.carry;
  if (lleva != null && detail > 0.1) carried(lleva);
  if (act == null || detail <= 0.1) return out;
  props(act);
  return out;
}

/// Lo que miden las piernas de alguien sentado en el suelo: un tercio del
/// cuerpo, que de pie mide 0,56. Ver [Doing.seated].
const double _piernas = 0.56 / 3;

/// A qué altura queda el asiento de una banqueta.
const double _banqueta = 0.20;

/// El consejero: túnica larga, barba blanca hasta el pecho, pelo cano y un
/// bastón. Ver `Townsfolk.sage`.
///
/// Es la misma persona de cajas que todos —cuerpo, cabeza, pelo— con lo que
/// lo hace él encima, y nada que no se lea de lejos: a doce píxeles, lo que
/// dice «el viejo sabio» es la mancha blanca que le baja de la cara hasta el
/// pecho y la raya del bastón al lado. Un sombrero de punta diría «mago», que
/// es otra cosa.
///
/// Anda despacio y apenas despega del suelo —nada de los saltitos de los
/// demás, que en él serían de un chico— y va un poco encorvado: la cabeza un
/// palmo por delante del cuerpo.
void _sabio(
  void Function(double, double, double, double, double, double, int, double)
  caja,
  void Function(
    (double, double, double),
    (double, double, double),
    double,
    int,
    double,
  )
  vara,
  FolkAt at,
  int piel,
  double detail,
  double bob,
  double asiento,
  FeastPose? feast,
) {
  const tunica = 0xFF4E5670;
  const ribete = 0xFF3D4459;
  const cano = 0xFFE8E4DA;
  final sentado = asiento > 0;
  // Andando apenas despega; sentado, los pies en el asiento.
  final piso = sentado
      ? asiento
      : at.moving
      ? 0.014 * math.sin(at.gait).abs()
      : 0.0;
  // Sentado pierde las piernas, que se van hacia delante (ver la postura
  // sentada de todos, más arriba): todo lo de arriba baja eso.
  final baja = sentado ? _piernas : 0.0;

  // Saludando no saluda sólo el bastón: saluda él. Se mece hacia el lado del
  // bastón y vuelve, la cabeza más que los pies —como quien se inclina, con
  // cajas que no se pueden torcer—, y da un saltito con cada vaivén.
  final saluda = at.act == Doing.greet;
  final alzaSaludo = saluda ? smoothstep(0, 0.45, at.phase) : 0.0;
  final vaivenSaludo = saluda ? math.sin(at.phase * 8.0) * alzaSaludo : 0.0;
  final saltito = saluda
      ? 0.02 * math.sin(at.phase * 8.0).abs() * alzaSaludo
      : 0.0;
  // Cuánto se corre algo a la altura [yy]: nada en los pies, todo en la
  // coronilla.
  double corre(double yy) =>
      0.08 * vaivenSaludo * clampD((yy - 0.05) / 0.95, 0, 1);
  void box(
    double x0,
    double y0,
    double z0,
    double x1,
    double y1,
    double z1,
    int tint,
    double ao,
  ) {
    if (!saluda) return caja(x0, y0, z0, x1, y1, z1, tint, ao);
    final d = corre((y0 + y1) / 2);
    caja(x0 + d, y0 + saltito, z0, x1 + d, y1 + saltito, z1, tint, ao);
  }

  void link(
    (double, double, double) a,
    (double, double, double) b,
    double r,
    int tint,
    double ao,
  ) {
    if (!saluda) return vara(a, b, r, tint, ao);
    vara(
      (a.$1 + corre(a.$2), a.$2 + saltito, a.$3),
      (b.$1 + corre(b.$2), b.$2 + saltito, b.$3),
      r,
      tint,
      ao,
    );
  }

  final y = piso + bob - baja; // a lo que se suma la altura de cada parte
  const corva = 0.035; // lo que adelanta la cabeza

  // La túnica, hasta el suelo y un poco más ancha abajo.
  box(-0.160, piso, -0.125, 0.160, y + 0.56, 0.125, tunica, 1.0);
  if (sentado) {
    // Las piernas hacia delante, sobre el asiento, y la túnica que cae
    // hasta el suelo por delante del banco.
    box(
      -0.160,
      piso,
      0.105,
      0.160,
      piso + 0.13,
      0.125 + _piernas,
      tunica,
      0.97,
    );
    box(
      -0.150,
      0.0,
      0.125 + _piernas - 0.11,
      0.150,
      piso,
      0.125 + _piernas,
      ribete,
      0.95,
    );
  } else {
    box(-0.176, piso, -0.136, 0.176, piso + 0.12, 0.136, ribete, 0.96);
  }

  // La cabeza, adelantada.
  box(
    -0.205,
    y + 0.520,
    -0.175 + corva,
    0.205,
    y + 0.950,
    0.175 + corva,
    piel,
    1.02,
  );
  if (detail > 0.25) {
    // El pelo cano: el gorro de siempre y la nuca, larga, por detrás.
    box(
      -0.212,
      y + 0.830,
      -0.182 + corva,
      0.212,
      y + 0.975,
      0.182 + corva,
      cano,
      1.0,
    );
    box(
      -0.212,
      y + 0.560,
      -0.182 + corva,
      0.212,
      y + 0.975,
      -0.060 + corva,
      cano,
      0.98,
    );
    // La barba: ancha bajo la cara, y cada vez más angosta hasta el pecho.
    final f = 0.175 + corva;
    box(-0.175, y + 0.500, f, 0.175, y + 0.705, f + 0.055, cano, 1.0);
    box(-0.120, y + 0.330, 0.128, 0.120, y + 0.520, 0.200, cano, 0.99);
    box(-0.060, y + 0.230, 0.128, 0.060, y + 0.335, 0.180, cano, 0.98);
  }
  if (detail > 0.4) {
    // El bastón, a su derecha, flotando a su lado: aquí nadie tiene brazos
    // ni manos. Andando va y viene con el paso; parado, apoyado; sentado,
    // entre las rodillas y el banco.
    final vaiven = at.moving ? 0.07 * math.sin(at.gait * 0.5) : 0.0;
    var arriba = sentado
        ? (-0.230, y + 0.500, 0.300)
        : (-0.250, y + 0.560, 0.190 + vaiven * 0.3);
    var pie = sentado ? (-0.250, 0.0, 0.420) : (-0.275, 0.0, 0.250 + vaiven);
    if (at.act == Doing.greet) {
      // Saluda con el bastón: lo levanta del suelo y lo alza pegado a su
      // costado, por encima de la cabeza, y la punta va y viene con él.
      final alza = alzaSaludo;
      final ida = vaivenSaludo;
      (double, double, double) mezcla(
        (double, double, double) a,
        (double, double, double) b,
      ) => (
        lerpD(a.$1, b.$1, alza),
        lerpD(a.$2, b.$2, alza),
        lerpD(a.$3, b.$3, alza),
      );
      arriba = mezcla(arriba, (-0.30 + 0.20 * ida, y + 1.28, 0.12));
      pie = mezcla(pie, (-0.25 + 0.03 * ida, y + 0.48, 0.10));
    }
    link(arriba, pie, 0.024, 0xFF6B5236, 0.95);
    // Y el puño, curvo, arriba.
    link(
      (arriba.$1, arriba.$2 - 0.02, arriba.$3),
      (arriba.$1, arriba.$2 + 0.10, arriba.$3 + 0.01),
      0.030,
      0xFF5A4430,
      0.95,
    );
  }
  if (feast != null && detail > 0.25) {
    // Dando de comer a las palomas (ver `pigeons.dart`). Sin brazos, como
    // todos: el pan sale solo de la túnica y se le queda en el regazo, y
    // cada miga se despega sola del pan, sube y sale volando hacia ellas.
    final (hx, hy, hz) = feast.afloat;
    final flota = (hx, piso + hy, hz);
    if (feast.bread > 0) {
      // Un pan alargado, de corteza tostada, que se va acortando.
      final largo = 0.075 * (0.35 + 0.65 * feast.bread);
      final (bx, by, bz) = feast.breadAfloat
          ? flota
          : (_panEnRegazo.$1, piso + _panEnRegazo.$2, _panEnRegazo.$3);
      box(
        bx - largo,
        by - 0.032,
        bz - 0.040,
        bx + largo,
        by + 0.032,
        bz + 0.040,
        0xFFB57B3E,
        1.0,
      );
      // La miga, clara, donde se partió.
      box(
        bx + largo - 0.012,
        by - 0.026,
        bz - 0.034,
        bx + largo + 0.004,
        by + 0.026,
        bz + 0.034,
        0xFFE9D3A4,
        1.02,
      );
    }
    if (feast.crumb) {
      // El pellizco de pan, que va solo por el aire.
      box(
        flota.$1 - 0.020,
        flota.$2 - 0.020,
        flota.$3 - 0.020,
        flota.$1 + 0.020,
        flota.$2 + 0.020,
        flota.$3 + 0.020,
        0xFFE9D3A4,
        1.02,
      );
    }
  }
}

/// Dónde queda el pan en el regazo, con la altura sobre el asiento. Es
/// [feastBreadRest], que es donde lo deja `pigeons.dart`.
const _panEnRegazo = feastBreadRest;
