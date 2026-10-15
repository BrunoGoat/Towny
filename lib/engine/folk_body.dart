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
  final piel = _skin[hashInt(_skin.length, seed, 3)];
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
      // La cometa de toda la vida: un rombo de cuatro colores y una cola con
      // tres lazos, allá arriba y con su hilo.
      //
      // **Y mirando siempre a quien la mira.** Un rombo es plano, y de canto
      // —que es como se lo ve la mitad del tiempo, porque la cámara da
      // vueltas— era un palo con una raya flotando. Así que se gira sobre sí
      // misma hacia el ojo, que es además lo que hace una cometa de verdad:
      // se pone de cara al viento. Sin ojo (en las cuentas de lo que ocupa)
      // mira hacia delante.
      final m = hold(1, 0.80, 0.05);
      final vaiven = swing * 0.12;
      final cx = 0.62 + vaiven, cy = 1.66 + swing * 0.08, cz = 0.92;
      // El ojo, en el sistema de la persona: hacia dónde tiene que mirar.
      var ox = 0.0, oz = 1.0;
      if (eye != null) {
        final dX = eye.x - (at.x + (cx * cos + cz * sin) * h);
        final dZ = eye.z - (at.z + (-cx * sin + cz * cos) * h);
        ox = dX * cos - dZ * sin;
        oz = dX * sin + dZ * cos;
        final l = math.sqrt(ox * ox + oz * oz);
        if (l > 1e-6) {
          ox /= l;
          oz /= l;
        } else {
          ox = 0;
          oz = 1;
        }
      }
      // A lo ancho del rombo: de lado respecto del ojo.
      final rx = oz, rz = -ox;
      (double, double, double) en(double a, double up) =>
          (cx + rx * a, cy + up, cz + rz * a);
      final arriba = en(0, 0.27), abajo = en(0, -0.48);
      final izq = en(-0.25, 0), der = en(0.25, 0), medio = en(0, 0);
      // Un triángulo por las dos caras: se ve de frente y de espaldas.
      void tela(
        (double, double, double) a,
        (double, double, double) b,
        (double, double, double) c,
        int tinte,
      ) {
        final pa = world(a.$1, a.$2, a.$3);
        final pb = world(b.$1, b.$2, b.$3);
        final pc = world(c.$1, c.$2, c.$3);
        final n = (pb - pa).cross(pc - pa).normalized;
        final atras = V3(-n.x, -n.y, -n.z);
        out.add(
          Solid(-1, [
            Facet([pa, pb, pc], n, Surface.cloth, ao: 1.06, tint: tinte),
            Facet([pa, pb, pc], atras, Surface.cloth, ao: 0.96, tint: tinte),
          ]),
        );
      }

      tela(arriba, izq, medio, 0xFFE0524A);
      tela(arriba, medio, der, 0xFF22AE9C);
      tela(izq, abajo, medio, 0xFFEFB02E);
      tela(medio, abajo, der, 0xFFC56BA8);
      // El hilo, a la cruz de las varillas.
      link(m, medio, 0.005, 0xFFE4DCC6, 1.04);
      // La cola: una cuerda que ondea y tres lazos azules.
      var antes = abajo;
      for (var k = 1; k <= 6; k++) {
        final ondea = math.sin(ph * 2.2 - k * 0.9) * 0.05 - vaiven * k * 0.04;
        final punto = en(ondea, -0.48 - k * 0.11);
        link(antes, punto, 0.006, 0xFF2F62B0, 1.0);
        if (k.isOdd) {
          // El lazo: dos triangulitos que salen del nudo, uno a cada lado.
          for (final lado in [-1.0, 1.0]) {
            final p = punto;
            tela(
              p,
              (p.$1 + rx * 0.11 * lado, p.$2 + 0.05, p.$3 + rz * 0.11 * lado),
              (p.$1 + rx * 0.11 * lado, p.$2 - 0.05, p.$3 + rz * 0.11 * lado),
              0xFF2F62B0,
            );
          }
        }
        antes = punto;
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

    case PropKind.balls:
      // Tres pelotas de colores que suben por un lado, pasan por encima de la
      // cabeza y caen por el otro, y vuelven a cruzar abajo, a la altura de
      // las manos. Las manos no están, pero el arco las dibuja: arriba alto y
      // despacio, abajo plano y deprisa, que es como se ve un malabar. Y
      // quien las lanza mira hacia arriba, a ellas.
      const colores = [0xFFC1543C, 0xFFD9B43C, 0xFF4F7FA8];
      for (var k = 0; k < 3; k++) {
        final c = beat * 0.32 + k / 3;
        final f = c - c.floorToDouble();
        // Dos tercios de la vuelta en el aire, un tercio en las manos.
        final double bx, by;
        if (f < 0.68) {
          final u = f / 0.68;
          bx = -0.17 + 0.34 * u;
          by = 0.52 + 0.64 * 4 * u * (1 - u);
        } else {
          final u = (f - 0.68) / 0.32;
          bx = 0.17 - 0.34 * u;
          by = 0.50 - 0.06 * math.sin(math.pi * u);
        }
        final x = bx + wag, y = piso + by + bob, z = 0.34 + lean;
        box(
          x - 0.050,
          y - 0.050,
          z - 0.050,
          x + 0.050,
          y + 0.050,
          z + 0.050,
          colores[k],
          1.06,
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

    case PropKind.rope:
      // La comba: la cuerda da la vuelta entera alrededor de quien salta, por
      // encima de la cabeza y por debajo de los pies, y el salto va con ella.
      // Da dos vueltas por cada vuelta de [beat] porque el cuerpo salta dos
      // veces en ella (sube con el valor absoluto), y así cada salto cae
      // justo cuando la cuerda pasa por el suelo.
      final giro = 2 * beat;
      final cy = piso + 0.52 + bob;
      const r = 0.56, ancho = 0.36;
      // Ancha y plana por abajo, no en pico: con un arco de seno la cuerda
      // sólo libraba los pies en el centro, y a los lados le atravesaba el
      // cuerpo.
      (double, double, double) punto(double u) {
        final s = math.pow(math.sin(math.pi * u), 0.35).toDouble();
        return (
          -ancho + 2 * ancho * u,
          cy + r * s * math.cos(giro),
          r * s * math.sin(giro),
        );
      }

      const tramos = 10;
      for (var i = 0; i < tramos; i++) {
        link(
          punto(i / tramos),
          punto((i + 1) / tramos),
          0.013,
          0xFFE2D3A4,
          1.04,
        );
      }
      // Las empuñaduras, que es donde se ve que la cuerda la lleva alguien.
      for (final s in [1.0, -1.0]) {
        box(
          s * ancho - 0.024,
          cy - 0.070,
          -0.024,
          s * ancho + 0.024,
          cy + 0.020,
          0.024,
          0xFF9A5A34,
          0.96,
        );
      }

    case PropKind.axe:
      // El tocón, el leño de pie encima y el hacha. Lo que se lee es el
      // hacha **por encima de la cabeza** y cayendo de golpe: sube despacio,
      // baja en un cuarto del tiempo y se queda clavada un momento. El pico
      // de piedra golpea abajo y a compás; esto es otro gesto.
      const cz = 0.66;
      box(-0.13, 0.0, cz - 0.13, 0.13, 0.16, cz + 0.13, 0xFF6A4A2E, 0.86);
      box(
        -0.115,
        0.160,
        cz - 0.115,
        0.115,
        0.172,
        cz + 0.115,
        0xFFD8B47A,
        1.02,
      );
      box(
        -0.050,
        0.172,
        cz - 0.055,
        0.050,
        0.330,
        cz + 0.055,
        0xFFC09A62,
        0.97,
      );
      final u = beat / (2 * math.pi) - (beat / (2 * math.pi)).floorToDouble();
      // Cuánto está arriba: cae de golpe hasta el cuarto de vuelta, que es
      // cuando el cuerpo se dobla, y vuelve a subir despacio.
      final arriba = u < 0.25
          ? 1 - (u / 0.25) * (u / 0.25)
          : smoothstep(0.32, 0.95, u);
      final a = 1.82 + (-0.05 - 1.82) * arriba;
      final mano = (0.0, piso + 0.42 + 0.38 * arriba + bob, 0.31 + lean);
      final d = (math.cos(a), math.sin(a));
      final filo = (-math.sin(a), math.cos(a));
      final cabo = (0.0, mano.$2 + d.$1 * 0.36, mano.$3 + d.$2 * 0.36);
      link(mano, cabo, 0.015, _wood2, 0.95);
      // La hoja: una chapa plana, fina de lado y ancha a lo largo del mango,
      // que es lo que la hace hacha y no martillo.
      for (var k = -2; k <= 2; k++) {
        final o = k * 0.016;
        final largo = 0.12 - k.abs() * 0.012;
        final y = cabo.$2 - d.$1 * (0.02 - o), z = cabo.$3 - d.$2 * (0.02 - o);
        link(
          (0.0, y - filo.$1 * 0.03, z - filo.$2 * 0.03),
          (0.0, y + filo.$1 * largo, z + filo.$2 * largo),
          0.010,
          0xFFB9BDC0,
          1.06,
        );
      }

    case PropKind.hens:
      // Tres gallinas alrededor, cada una mirando a un lado y picoteando a su
      // ritmo, y el grano cayendo de la mano. Lo que las hace gallinas y no
      // cajitas es la cresta roja y la cola levantada.
      const gallinas = [
        (-0.44, 0.40, 1.0, 0.0, 0xFFEDE6D6),
        (0.42, 0.56, -1.0, 0.0, 0xFFA0603A),
        (-0.04, 0.80, 0.0, -1.0, 0xFFC08A4A),
      ];
      for (var k = 0; k < gallinas.length; k++) {
        final (cx, cz, dx, dz, pluma) = gallinas[k];
        void parte(
          double f0,
          double y0,
          double l0,
          double f1,
          double y1,
          double l1,
          int tint,
          double ao,
        ) {
          final xa = cx + f0 * dx + l0 * dz, xb = cx + f1 * dx + l1 * dz;
          final za = cz + f0 * dz - l0 * dx, zb = cz + f1 * dz - l1 * dx;
          box(
            math.min(xa, xb),
            y0,
            math.min(za, zb),
            math.max(xa, xb),
            y1,
            math.max(za, zb),
            tint,
            ao,
          );
        }

        parte(-0.10, 0.05, -0.065, 0.08, 0.17, 0.065, pluma, 1.0);
        parte(-0.15, 0.12, -0.035, -0.08, 0.23, 0.035, pluma, 0.94);
        for (final l in [-0.030, 0.030]) {
          parte(
            -0.012,
            0.0,
            l - 0.009,
            0.012,
            0.05,
            l + 0.009,
            0xFFD9A040,
            0.95,
          );
        }
        // Picotea: la cabeza baja al suelo de vez en cuando, cada una a su
        // aire.
        final pica = math
            .pow(math.max(0.0, math.sin(ph * 2.6 + k * 2.1)), 3)
            .toDouble();
        final hf = 0.07 + pica * 0.05, hy = 0.17 - pica * 0.14;
        parte(hf, hy, -0.032, hf + 0.065, hy + 0.070, 0.032, pluma, 1.02);
        parte(
          hf + 0.010,
          hy + 0.070,
          -0.010,
          hf + 0.050,
          hy + 0.098,
          0.010,
          0xFFC0392B,
          1.04,
        );
        parte(
          hf + 0.065,
          hy + 0.022,
          -0.012,
          hf + 0.095,
          hy + 0.044,
          0.012,
          0xFFE0A030,
          1.04,
        );
      }
      // El grano, cayendo de la mano en un chorrito.
      final m = hold(1, 0.40, 0.12);
      for (var k = 0; k < 3; k++) {
        final c = ph * 1.3 + k / 3;
        final f = c - c.floorToDouble();
        final gy = m.$2 * (1 - f);
        final gx = m.$1 + 0.04 + f * 0.10 + (k - 1) * 0.02;
        final gz = m.$3 + 0.04 + f * 0.08;
        box(
          gx - 0.014,
          gy - 0.014,
          gz - 0.014,
          gx + 0.014,
          gy + 0.014,
          gz + 0.014,
          0xFFE8D27A,
          1.08,
        );
      }

    case PropKind.boat:
      // De rodillas al borde del agua, con un barco de papel meciéndose y
      // una ramita para empujarlo. El charco va dibujado porque al lado del
      // pozo o de la fuente no siempre hay agua a los pies, y sin él el
      // barco estaría navegando por la hierba. De tres manchas que se pisan,
      // para que tenga borde de charco y no de mantel.
      const agua = 0xFF4F86AE;
      box(-0.30, 0.0, 0.34, 0.30, 0.012, 0.86, agua, 1.0);
      box(-0.40, 0.0, 0.44, 0.38, 0.012, 0.76, agua, 1.0);
      box(-0.20, 0.0, 0.28, 0.18, 0.012, 0.94, agua, 1.0);
      box(-0.22, 0.012, 0.44, 0.02, 0.015, 0.48, 0xFF8FB8D2, 1.06);
      final bx = math.sin(ph * 0.45) * 0.08;
      final by = 0.014 + (0.5 + 0.5 * math.sin(ph * 1.9)) * 0.015;
      const bz = 0.62;
      const papel = 0xFFF4F0E4;
      box(
        bx - 0.105,
        by,
        bz - 0.050,
        bx + 0.105,
        by + 0.045,
        bz + 0.050,
        papel,
        1.02,
      );
      box(
        bx - 0.165,
        by + 0.045,
        bz - 0.066,
        bx + 0.165,
        by + 0.085,
        bz + 0.066,
        papel,
        1.06,
      );
      box(
        bx - 0.072,
        by + 0.085,
        bz - 0.016,
        bx + 0.072,
        by + 0.180,
        bz + 0.016,
        papel,
        1.10,
      );
      box(
        bx - 0.030,
        by + 0.180,
        bz - 0.014,
        bx + 0.030,
        by + 0.255,
        bz + 0.014,
        papel,
        1.10,
      );
      final m = hold(1, 0.40, 0.08);
      link(m, (bx + 0.19, by + 0.06, bz - 0.04), 0.009, 0xFF7A5A38, 0.94);

    case PropKind.barrow:
      // La carretilla delante: el cajón con piedras, la rueda al frente y
      // las dos varas hasta las manos. Empujar es ir y venir un poco y
      // levantar las patas del suelo; la rueda no se mueve de sitio.
      final empuja = swing * 0.030;
      final alza = math.max(0.0, swing) * 0.035;
      final z0 = 0.44 + empuja, z1 = 0.86 + empuja;
      final y0 = 0.20 + alza, y1 = 0.36 + alza;
      box(-0.20, y0, z0, 0.20, y1, z1, 0xFF8A6A42, 0.92);
      box(
        -0.17,
        y1 - 0.02,
        z0 + 0.03,
        0.17,
        y1 + 0.002,
        z1 - 0.03,
        0xFF4E3B28,
        0.84,
      );
      const piedras = [
        (-0.08, 0.58, 0.075, 0xFFB9B2A2),
        (0.07, 0.66, 0.065, 0xFFA79F8D),
        (-0.02, 0.76, 0.060, 0xFFC4BDAE),
      ];
      for (final (px, pz, r, tinte) in piedras) {
        box(
          px - r,
          y1,
          pz + empuja - r,
          px + r,
          y1 + r * 1.1,
          pz + empuja + r,
          tinte,
          0.96,
        );
      }
      // La rueda, debajo del frente del cajón y tocándolo: suelta delante se
      // leía como una caja más. Dos cajas cruzadas, que a este tamaño ya es
      // algo redondo, y el eje en medio.
      final rz = z1 - 0.05;
      box(-0.026, 0.0, rz - 0.060, 0.026, 0.20, rz + 0.060, 0xFF3E2E20, 0.86);
      box(-0.026, 0.040, rz - 0.100, 0.026, 0.16, rz + 0.100, 0xFF3E2E20, 0.86);
      box(-0.045, 0.085, rz - 0.018, 0.045, 0.115, rz + 0.018, _wood2, 0.9);
      for (final s in [1.0, -1.0]) {
        box(
          s * 0.15 - 0.022,
          alza,
          z0 + 0.02,
          s * 0.15 + 0.022,
          y0,
          z0 + 0.06,
          _wood2,
          0.86,
        );
        link(
          (s * 0.20, piso + 0.40 + bob + alza, 0.22),
          (s * 0.17, y1 - 0.04, z0 + 0.02),
          0.016,
          _wood2,
          0.94,
        );
      }

    case PropKind.crook:
      // El cayado de pie al costado, con la vuelta arriba que lo hace
      // cayado y no bastón, y dos ovejas paciendo. Las ovejas son lo que
      // cuenta qué hace: sin ellas es alguien con un palo.
      final vaiven = swing * 0.02;
      const cx = 0.28, cz = 0.20;
      final arriba = (cx + vaiven, 1.15, cz);
      link((cx, 0.0, cz), arriba, 0.016, _wood2, 0.94);
      final c1 = (cx + vaiven, 1.25, cz + 0.06);
      final c2 = (cx + vaiven, 1.23, cz + 0.14);
      final c3 = (cx + vaiven, 1.14, cz + 0.155);
      link(arriba, c1, 0.016, _wood2, 0.94);
      link(c1, c2, 0.016, _wood2, 0.94);
      link(c2, c3, 0.016, _wood2, 0.94);
      const ovejas = [(-0.66, 0.58, 0.0, 1.0), (0.62, 0.98, -1.0, 0.0)];
      for (var k = 0; k < ovejas.length; k++) {
        final (ox, oz, dx, dz) = ovejas[k];
        void parte(
          double f0,
          double y0,
          double l0,
          double f1,
          double y1,
          double l1,
          int tint,
          double ao,
        ) {
          final xa = ox + f0 * dx + l0 * dz, xb = ox + f1 * dx + l1 * dz;
          final za = oz + f0 * dz - l0 * dx, zb = oz + f1 * dz - l1 * dx;
          box(
            math.min(xa, xb),
            y0,
            math.min(za, zb),
            math.max(xa, xb),
            y1,
            math.max(za, zb),
            tint,
            ao,
          );
        }

        parte(-0.19, 0.10, -0.115, 0.14, 0.31, 0.115, 0xFFEFEADF, 1.02);
        for (final f in [-0.13, 0.08]) {
          for (final l in [-0.065, 0.065]) {
            parte(
              f - 0.022,
              0.0,
              l - 0.022,
              f + 0.022,
              0.11,
              l + 0.022,
              0xFF3A332C,
              0.90,
            );
          }
        }
        // Pace: la cabeza casi siempre abajo, y de tanto en tanto la levanta.
        final mira = math
            .pow(math.max(0.0, math.sin(ph * 0.5 + k * 2.4)), 4)
            .toDouble();
        final hf = 0.15 - mira * 0.02, hy = 0.04 + mira * 0.18;
        parte(hf, hy, -0.055, hf + 0.11, hy + 0.10, 0.055, 0xFF3A332C, 0.96);
        parte(
          hf + 0.005,
          hy + 0.07,
          -0.085,
          hf + 0.04,
          hy + 0.10,
          0.085,
          0xFF3A332C,
          0.92,
        );
      }

    case PropKind.flowers:
      // En cuclillas cogiendo flores: las que quedan delante, en el suelo, y
      // el cesto al lado lleno de las ya cogidas. Una va y viene en la mano,
      // del suelo al cesto, al compás con que se agacha.
      const cesto = 0xFFB08850;
      box(-0.52, 0.0, 0.06, -0.28, 0.14, 0.30, cesto, 0.92);
      box(-0.535, 0.12, 0.045, -0.265, 0.155, 0.315, 0xFF8A6A3A, 0.94);
      link((-0.40, 0.15, 0.07), (-0.40, 0.31, 0.18), 0.010, 0xFF8A6A3A, 0.94);
      link((-0.40, 0.31, 0.18), (-0.40, 0.15, 0.29), 0.010, 0xFF8A6A3A, 0.94);
      const tintes = [0xFFD8505A, 0xFFE8C341, 0xFFB57BC4, 0xFFF2EEE4];
      const enCesto = [
        (-0.47, 0.11),
        (-0.34, 0.12),
        (-0.45, 0.24),
        (-0.33, 0.24),
      ];
      for (var k = 0; k < enCesto.length; k++) {
        final (fx, fz) = enCesto[k];
        box(
          fx - 0.035,
          0.150,
          fz - 0.035,
          fx + 0.035,
          0.205,
          fz + 0.035,
          tintes[k],
          1.06,
        );
      }
      const enSuelo = [(0.06, 0.50), (-0.14, 0.64), (0.24, 0.62), (0.08, 0.80)];
      for (var k = 0; k < enSuelo.length; k++) {
        final (fx, fz) = enSuelo[k];
        link((fx, 0.0, fz), (fx, 0.12, fz), 0.008, 0xFF5E8A3E, 0.94);
        box(
          fx - 0.038,
          0.12,
          fz - 0.038,
          fx + 0.038,
          0.175,
          fz + 0.038,
          tintes[(k + 1) % tintes.length],
          1.06,
        );
      }
      final coge = math.max(0.0, swing);
      final p = (
        -0.30 + 0.38 * coge,
        piso + 0.30 + bob - baja + (1 - coge) * 0.0 - coge * 0.08,
        0.24 + 0.22 * coge,
      );
      link(p, (p.$1, p.$2 + 0.10, p.$3), 0.008, 0xFF5E8A3E, 0.94);
      box(
        p.$1 - 0.032,
        p.$2 + 0.10,
        p.$3 - 0.032,
        p.$1 + 0.032,
        p.$2 + 0.15,
        p.$3 + 0.032,
        tintes[0],
        1.08,
      );

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
  box,
  void Function(
    (double, double, double),
    (double, double, double),
    double,
    int,
    double,
  )
  link,
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
      // Saluda con el bastón: se levanta solo del suelo, sube al costado de
      // la cabeza y la punta va y viene, como una mano en alto.
      final alza = smoothstep(0, 0.45, at.phase);
      final ida = math.sin(at.phase * 8.0) * alza;
      (double, double, double) mezcla(
        (double, double, double) a,
        (double, double, double) b,
      ) => (
        lerpD(a.$1, b.$1, alza),
        lerpD(a.$2, b.$2, alza),
        lerpD(a.$3, b.$3, alza),
      );
      arriba = mezcla(arriba, (-0.34 + 0.22 * ida, y + 1.30, 0.14));
      pie = mezcla(pie, (-0.30 + 0.03 * ida, y + 0.50, 0.12));
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
