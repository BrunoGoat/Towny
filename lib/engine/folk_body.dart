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
import 'folk.dart';
import 'solid.dart';

/// Cuánta gente sale hoy a la calle, de cero a uno.
///
/// Un pueblo desatendido no es sólo un pueblo más gris: es un pueblo del que
/// la gente se va. Es la única manera que tiene el sitio de decir «llevás doce
/// días sin venir» sin escribirlo en ninguna parte, y dice mucho más que el
/// color.
///
/// Nunca llega a cero, igual que la integridad: siempre queda alguien.
double folkOut(double integrity) => clampD(0.22 + integrity * 0.86, 0.0, 1.0);

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
  // persona en las seis regiones y a cualquier talla.
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
  final piel = _skin[hashInt(_skin.length, seed, 3)];
  final pelo = _hair[hashInt(_hair.length, seed, 5)];

  final act = at.act;
  final ph = at.phase;

  // El cuerpo entero sale de cinco números de la tabla. No hay un caso por
  // actividad: hay una manera de moverse, y sesenta juegos de números.
  final sit = act?.sink ?? 0.0;
  final baja = sit * 0.26;

  /// A qué altura tiene los pies.
  ///
  /// Cero en el suelo, que es lo normal. Quien tiene banqueta se sienta
  /// **encima** de ella y no delante: sin esto el cuerpo seguía arrancando del
  /// suelo y la banqueta le salía por dentro, que era alguien de pie sobre una
  /// mesita.
  final piso = act?.prop == PropKind.stool ? 0.30 - baja * 0.5 : 0.0;

  // Lo único que anima a alguien sin brazos ni piernas: que suba y baje, que
  // se incline y que se balancee. Y alcanza de sobra — el paso de unas piernas
  // de dos píxeles no se ve, y el bamboleo de un cuerpo entero sí.
  //
  // Andando sube y baja dos veces por zancada, una por pie que no está ahí.
  // Parado, lo que diga lo que esté haciendo: el que habla se mueve, el que
  // pica piedra dobla el espinazo, el que baila da saltos, y el que no hace
  // nada respira.
  final swing = act == null
      ? 0.0
      : math.sin(ph * act.rate + hash01(seed, 16) * 6);
  final bob = at.moving
      ? math.cos(at.gait * 2) * 0.016
      : (act == null
            ? 0.0
            : act.bob * (act.bob < 0 ? math.max(0.0, swing) : swing));
  final wag = at.moving ? math.sin(at.gait) * 0.014 : (act?.wag ?? 0.0) * swing;
  final lean = at.moving ? 0.020 : (act?.lean ?? 0.0);

  /// Dónde le flota lo que lleva. No hay mano: hay un sitio a la altura y al
  /// lado de donde estaría, y lo que se sostiene se queda ahí. A esta
  /// distancia es lo mismo, y una mano de tres píxeles no es una mano.
  (double, double, double) hold(double s, double raise, double fwd) => (
    s * 0.150 + wag,
    piso + 0.26 + raise * 0.34 + bob - baja,
    0.13 + fwd + lean,
  );

  /// Una vara entre dos puntos: el hilo de la cometa, su cola, el mango de una
  /// herramienta, la cuerda de un caldero. [box] sólo sabe hacer cajas rectas
  /// en el sistema de la persona, y una cuerda va en diagonal.
  void link(
    (double, double, double) a,
    (double, double, double) b,
    double r,
    int tint,
    double ao,
  ) {
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
        at0.$1 + (pv.x * sp + q.x * sq) * r,
        at0.$2 + (pv.y * sp + q.y * sq) * r,
        at0.$3 + (pv.z * sp + q.z * sq) * r,
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
  if (act == null || detail <= 0.1) return out;

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
      final m = hold(1, 0.46, 0.09);
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

    case PropKind.pail:
      // El caldero del pozo: la soga desde la mano y el caldero al final, y
      // lo que cuenta la historia es que **sube y baja** con el espinazo.
      //
      // La mano va por fuera del hombro y no donde la pondría `hold`: a esta
      // altura, el sitio donde se sostienen las cosas cae dentro de la
      // cabeza, y la soga le salía por la oreja.
      final h = hold(1, 0.92, 0.02);
      final m = (h.$1 + 0.11, h.$2, h.$3 + 0.06);
      final sube = 0.16 + math.max(0.0, swing) * 0.70;
      final cx = m.$1 + 0.09;
      link(m, (cx, sube + 0.20, m.$3), 0.010, 0xFF6A5A44, 0.92);
      // El asa, que es lo que lo separa de un cajón colgado.
      link(
        (cx - 0.090, sube + 0.145, m.$3),
        (cx + 0.090, sube + 0.145, m.$3),
        0.008,
        0xFF5A4A38,
        0.90,
      );
      box(
        cx - 0.098,
        sube,
        m.$3 - 0.098,
        cx + 0.098,
        sube + 0.145,
        m.$3 + 0.098,
        0xFF8A6A3E,
        0.90,
      );
      // El aro de arriba, un pelo más ancho: sin él es una caja.
      box(
        cx - 0.108,
        sube + 0.126,
        m.$3 - 0.108,
        cx + 0.108,
        sube + 0.158,
        m.$3 + 0.108,
        0xFF6B5236,
        0.94,
      );

    case PropKind.tub:
      // El barreño en el suelo, por delante, con la ropa dentro asomando. Se
      // lava de rodillas: el cuerpo ya está abajo, así que el barreño tiene
      // que estar **delante** y no debajo, o se lo come.
      const cz = 0.47;
      box(-0.215, 0.0, cz - 0.175, 0.215, 0.105, cz + 0.175, 0xFF7A6242, 0.88);
      box(
        -0.235,
        0.095,
        cz - 0.195,
        0.235,
        0.135,
        cz + 0.195,
        0xFF5E4A31,
        0.92,
      );
      // El paño mojado, que asoma por el canto y se mueve con el frote.
      final frota = swing * 0.045;
      box(
        -0.110 + frota,
        0.100,
        cz - 0.090,
        0.130 + frota,
        0.150,
        cz + 0.110,
        0xFFE8E2D2,
        1.05,
      );

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
      // El laúd contra el pecho, **grande y de madera clara**.
      //
      // Hicieron falta tres intentos. Con una caja chica y oscura y el mástil
      // hacia arriba, a veinte píxeles era un bulto con un palo — o sea lo
      // mismo que lleva quien saca agua del pozo. Lo que lo hace un laúd son
      // tres cosas: que la caja mida lo que la cabeza, que sea más clara que
      // cualquier sayo (si no, contra un pardo no existe), y que el mástil
      // salga por fuera de la silueta, que es lo único que no puede tener
      // ninguna otra cosa que se lleve encima.
      final m = hold(-1, 0.50, 0.11);
      final y = m.$2, z = m.$3;
      box(-0.255, y - 0.105, z, 0.020, y + 0.135, z + 0.110, 0xFFD9AE68, 1.0);
      // La tapa, por delante y más clara todavía: le da el bulto redondo.
      box(
        -0.230,
        y - 0.080,
        z + 0.105,
        -0.005,
        y + 0.110,
        z + 0.134,
        0xFFF0D69B,
        1.06,
      );
      // La boca, el agujero redondo.
      box(
        -0.150,
        y - 0.005,
        z + 0.130,
        -0.070,
        y + 0.060,
        z + 0.142,
        0xFF43301E,
        0.84,
      );
      // El mástil, largo y cruzado, asomando por el hombro del otro lado.
      link(
        (-0.030, y + 0.110, z + 0.055),
        (0.340, y + 0.330, z - 0.010),
        0.022,
        0xFFC79A54,
        1.0,
      );
      // El clavijero, doblado al final, que es lo que remata el mástil.
      box(
        0.312,
        y + 0.318,
        z - 0.060,
        0.392,
        y + 0.420,
        z + 0.014,
        0xFF43301E,
        0.92,
      );

    case PropKind.stall:
      // El puesto: el tablero sobre dos caballetes y el género encima. La
      // persona queda **detrás** del tablero, que es lo que hace la postura.
      const z0 = 0.30, z1 = 0.74, alto = 0.46;
      box(-0.46, alto - 0.040, z0, 0.46, alto, z1, 0xFF8A6F47, 0.92);
      for (final px in [-0.36, 0.36]) {
        box(
          px - 0.030,
          0.0,
          z0 + 0.040,
          px + 0.030,
          alto - 0.040,
          z0 + 0.100,
          _wood2,
          0.86,
        );
        box(
          px - 0.030,
          0.0,
          z1 - 0.100,
          px + 0.030,
          alto - 0.040,
          z1 - 0.040,
          _wood2,
          0.86,
        );
      }
      // El género: tres montones de distinto color, que es lo que dice que se
      // vende algo y no que hay una tabla.
      const generos = [
        (-0.30, 0xFFB4553A),
        (-0.02, 0xFF7E8E4C),
        (0.28, 0xFFC9A94E),
      ];
      for (final (px, tinte) in generos) {
        box(
          px - 0.085,
          alto,
          0.40,
          px + 0.085,
          alto + 0.090,
          0.62,
          tinte,
          1.02,
        );
      }

    case PropKind.mallet:
      // El sillar en el suelo y la maza cayéndole encima. El golpe es lo que
      // se ve: la maza baja con el mismo compás con el que se dobla el
      // espinazo, así que la figura entera golpea a la vez.
      const cz = 0.50;
      box(-0.190, 0.0, cz - 0.150, 0.190, 0.215, cz + 0.150, 0xFFB9B2A2, 0.90);
      box(
        -0.160,
        0.215,
        cz - 0.120,
        0.160,
        0.255,
        cz + 0.120,
        0xFFA79F8D,
        0.94,
      );
      final golpe = 0.32 + math.max(0.0, -swing) * 0.40;
      // La mano, por delante de la cabeza y por debajo: picando se dobla el
      // espinazo, la cabeza se va hacia adelante, y el mango le entraba por
      // la frente.
      final m = hold(1, 0.46, 0.13);
      link(m, (0.045, golpe + 0.055, cz - 0.02), 0.014, _wood2, 0.95);
      box(
        -0.055,
        golpe,
        cz - 0.095,
        0.145,
        golpe + 0.110,
        cz + 0.055,
        0xFF5C5348,
        0.92,
      );

    case PropKind.saw:
      // El madero sobre el caballete y la sierra pasando por él. Lo que se ve
      // moverse es la hoja, de lado a lado, y el cuerpo va con ella.
      const cz = 0.46, alto = 0.40;
      box(-0.055, 0.0, cz - 0.150, 0.055, alto, cz - 0.075, _wood2, 0.86);
      box(-0.055, 0.0, cz + 0.075, 0.055, alto, cz + 0.150, _wood2, 0.86);
      box(
        -0.340,
        alto,
        cz - 0.080,
        0.340,
        alto + 0.120,
        cz + 0.080,
        0xFF9A7B4E,
        0.93,
      );
      final pasada = swing * 0.150;
      // La hoja: clara, fina y alta, cruzando el madero.
      box(
        pasada - 0.030,
        alto + 0.055,
        cz - 0.135,
        pasada + 0.030,
        alto + 0.235,
        cz + 0.135,
        0xFFD2D6D8,
        1.08,
      );
      box(
        pasada - 0.034,
        alto + 0.225,
        cz - 0.060,
        pasada + 0.034,
        alto + 0.265,
        cz + 0.060,
        _wood2,
        0.95,
      );

    case PropKind.scythe:
      // La guadaña: el mango largo y la hoja **a ras de suelo**, barriendo de
      // lado a lado. Ninguna otra cosa del pueblo se mueve tan abajo y tan
      // ancho, y por eso se distingue del que barre.
      final m = hold(1, 0.62, 0.0);
      final corte = swing * 0.34;
      final pie = (corte * 0.6, 0.075, 0.56);
      link(m, pie, 0.016, _wood2, 0.94);
      // El agarre de en medio, que es lo que la hace guadaña y no palo.
      box(
        m.$1 - 0.030 - 0.055,
        m.$2 - 0.230,
        m.$3 + 0.150,
        m.$1 - 0.030 + 0.055,
        m.$2 - 0.180,
        m.$3 + 0.210,
        _wood2,
        0.90,
      );
      // Y la hoja, larga y curva hacia dentro, casi tocando la hierba.
      link(
        pie,
        (pie.$1 - 0.46 + corte * 0.5, 0.045, pie.$3 + 0.24),
        0.022,
        0xFFC8CCCE,
        1.06,
      );

    case PropKind.kite:
      // La cometa allá arriba y el hilo tenso. Es lo único del pueblo que
      // pasa por encima de las cabezas, así que se ve desde cualquier sitio.
      final m = hold(1, 0.80, 0.05);
      final vaiven = swing * 0.12;
      final cx = 0.62 + vaiven, cy = 1.62 + swing * 0.10, cz = 0.92;
      link(m, (cx, cy - 0.10, cz), 0.005, 0xFFE4DCC6, 1.04);
      // El rombo: dos cajas cruzadas, que a esta distancia es un rombo.
      box(
        cx - 0.215,
        cy - 0.052,
        cz - 0.022,
        cx + 0.215,
        cy + 0.052,
        cz + 0.022,
        0xFFC1543C,
        1.06,
      );
      box(
        cx - 0.062,
        cy - 0.245,
        cz - 0.022,
        cx + 0.062,
        cy + 0.245,
        cz + 0.022,
        0xFFD98C3C,
        1.04,
      );
      // Y la cola, tres lazos colgando, que es lo que dice que vuela.
      for (var k = 0; k < 3; k++) {
        final cai = cy - 0.27 - k * 0.135;
        box(
          cx - 0.030 - vaiven * (k + 1) * 0.6,
          cai - 0.048,
          cz - 0.016,
          cx + 0.030 - vaiven * (k + 1) * 0.6,
          cai,
          cz + 0.016,
          0xFFE4DCC6,
          1.02,
        );
      }

    case PropKind.line:
      // La cuerda entre dos palos con la ropa colgada. Pasa **por encima** de
      // la cabeza y la ropa cuelga a los lados, nunca en medio: colgada en el
      // centro le tapaba la cara a quien la tiende.
      const alto = 1.24;
      for (final px in [-0.64, 0.64]) {
        box(px - 0.028, 0.0, 0.30, px + 0.028, alto, 0.356, _wood2, 0.88);
      }
      link(
        (-0.64, alto - 0.02, 0.328),
        (0.64, alto - 0.02, 0.328),
        0.008,
        0xFF6A5A44,
        0.94,
      );
      const ropa = [(-0.48, 0xFFE8E2D2), (0.46, 0xFFCFC7B2)];
      for (final (px, tinte) in ropa) {
        final ondea = swing * 0.030;
        box(
          px - 0.105 + ondea,
          alto - 0.42,
          0.300,
          px + 0.105 + ondea,
          alto - 0.03,
          0.356,
          tinte,
          1.03,
        );
      }

    case PropKind.stool:
      // Una banqueta de tres patas. El asiento a la altura a la que la tabla
      // ya le ha bajado el cuerpo, así que se sienta en ella y no sobre ella.
      final alto = 0.30 - baja * 0.5;
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

  return out;
}
