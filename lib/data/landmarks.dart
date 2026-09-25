import 'dart:math' as math;

import '../engine/mason.dart';

/// One landmark: a thing the town builds that marks an era rather than a week.
///
/// A landmark is a recipe, not a model. Everything here is written in the
/// mason's vocabulary, which is why there can be a hundred of them instead of
/// four — and why a new one is a dozen lines rather than a new renderer.
class Landmark {
  Landmark(
    this.id,
    this.name,
    this.cost,
    this.tier,
    this.blurb,
    this.build, {
    this.rigid = false,
    this.scale = 1.0,
  });

  /// Stable identity. Never reuse one: it is what a saved town remembers.
  final String id;

  final String name;

  /// One line, said once, the day it is finished. A landmark arrives every two
  /// or three weeks: it is worth having something to say about it.
  final String blurb;

  /// How many achievements it takes to finish.
  final int cost;

  /// How grand it is: 0 is a well or a pigsty, 2 is a cathedral. The town
  /// builds small things early and grand things once it has grown into them.
  final int tier;

  final void Function(Mason m) build;

  /// Si esta obra se construye en sus propias proporciones y no en las de la
  /// comarca.
  ///
  /// Casi todo lo que levanta un pueblo **tiene** que ser de ese pueblo: una
  /// casa de la Sierra es alta y estrecha con el tejado en punta, y la de la
  /// Costa es baja y ancha con el tejado casi plano. Eso es lo que hace que
  /// dos hábitos no sean el mismo valle dos veces, y por eso el estirado vive
  /// en el [Mason], en la única puerta por la que pasan todas las piezas.
  ///
  /// Pero hay obras que no son de nadie. Una cruz de término es una cruz: el
  /// palo y los brazos guardan una proporción entre sí, y estirarla un quinto
  /// a lo ancho y encogerla un décimo a lo alto no la hace «de la Costa», la
  /// hace una cruz mal hecha. Lo mismo un arco, un patíbulo o las aspas de un
  /// molino, que son una máquina y no una manera de vivir. Ésas se marcan
  /// aquí y se levantan igual en los seis valles.
  ///
  /// La regla, para cuando haya que decidir una nueva: **¿es una manera de
  /// construir, o es un objeto?** Si dentro vive o trabaja gente, es de la
  /// comarca. Si es un monumento o una máquina, es suyo.
  final bool rigid;

  /// Cuánto se aprieta la receta al construirla de verdad.
  ///
  /// Las obras grandes están escritas a tamaño de plano —una catedral de once
  /// de nave, un castillo de nueve de muralla— porque así se piensan y así se
  /// leen escritas. Pero el solar que el pueblo le deja a un hito de su nivel
  /// no da para tanto: los solares se reparten dejando libre el setenta y dos
  /// por ciento de la suma de los dos sitios, así que una obra que ocupe todo
  /// su sitio se mete en la casa de al lado.
  ///
  /// Y meterse en la casa de al lado no es sólo feo. Este rasterizador corta
  /// la geometría donde dos cuerpos se cruzan, y dos edificios que se tocan
  /// dejan de ser dos nudos para ser uno: medido, un pueblo de sesenta y
  /// cinco edificios pasó de sesenta y cinco grupos a quince, y el coste de
  /// cortar subió de siete mil novecientas caras a catorce mil. Cada pieza
  /// nueva vuelve a cortarlos a todos.
  ///
  /// Así que se aprieta aquí, en una sola línea por obra, en vez de repasar
  /// doscientos números a mano: uniforme —ancho y alto a la vez— para que
  /// nada cambie de proporción. Lo empinado del tejado no entra, que ése es
  /// de la comarca.
  final double scale;

  /// How much room the town keeps clear around this landmark.
  ///
  /// Fixed per tier, deliberately, rather than measured from the recipe. The
  /// spacing decides where every later building goes, so if it moved when a
  /// recipe was edited then widening a mill's sails would shuffle the whole
  /// town — and a town that rearranges itself when the app updates is not a
  /// record of anything. Tiers never change; recipes may.
  double get room => const [2.6, 4.0, 6.4][tier];

  /// How far the recipe actually reaches from its own middle, measured by
  /// building it once. Used for framing the camera and for the test that keeps
  /// a recipe inside the room its tier is given — never for the layout.
  double get reach => _reach ??= _measure();
  double? _reach;

  double _measure() {
    final m = Mason(0, 0, 0x5EED, true, spread: scale, storey: scale);
    build(m);
    var r = 0.0;
    for (final s in m.finish(cost)) {
      final far = math.max(s.cx.abs() + s.w / 2, s.cz.abs() + s.d / 2);
      if (far > r) r = far;
    }
    return r;
  }
}

/// Everything the town knows how to build.
///
/// The order here is not the order they are built in — [LandmarkPlan] shuffles
/// within each tier — so entries can be appended freely without moving anything
/// that is already standing in somebody's town.
final List<Landmark> landmarks = [
  // ------------------------------------------------------------------ tier 0
  // The small works: a day's walk apart in a real village, a week apart here.
  Landmark(
    'pozo',
    'Pozo del concejo',
    7,
    0,
    'Ya no hay que bajar al río. Un pueblo empieza cuando tiene agua propia.',
    (m) {
      m.plinth(1.5, 1.5, 0.26);
      m.parapet(1.1, 1.1, 0.6);
      final brocal = m.y;
      m.post(0.16, 1.2, dx: -0.46, at: brocal);
      m.post(0.16, 1.2, dx: 0.46, at: brocal);
      m.beam(1.15, 0.2, 0.16, at: brocal + 1.2);
      m.roof(1.55, 1.25, 0.44, at: brocal + 1.36);
      m.box(PieceKind.parapet, 1.3, 0.4, 0.3, dz: 1.25, at: 0);
    },
  ),

  Landmark(
    'cruz',
    'Cruz de término',
    6,
    0,
    'Marca dónde termina el pueblo. Que haya que marcarlo ya dice bastante.',
    (m) {
      m.plinth(1.6, 1.6, 0.24);
      m.plinth(1.15, 1.15, 0.24);
      m.plinth(0.8, 0.8, 0.24);
      m.post(0.26, 1.9, at: m.y);
      m.beam(1.05, 0.26, 0.26, at: m.y + 1.5);
      m.post(0.26, 0.4, at: m.y + 1.76);
    },
    rigid: true,
  ),

  Landmark(
    'palomar',
    'Palomar',
    7,
    0,
    'Palomas para la mesa y para las cartas. Las dos cosas hacían falta.',
    (m) {
      m.plinth(1.9, 1.9, 0.28);
      m.floor(1.35, 1.35, 1.15);
      m.floor(1.2, 1.2, 1.05);
      m.parapet(1.55, 1.55, 0.24);
      m.dome(1.4, 1.4, 0.75);
      m.box(PieceKind.parapet, 1.0, 0.45, 0.32, dz: 1.15, at: 0);
      m.tree(0.9, 1.4, dx: 1.5, dz: -1.05);
    },
  ),

  Landmark(
    'colmenar',
    'Colmenar',
    6,
    0,
    'Miel, cera para las velas y, con suerte, nadie picado.',
    (m) {
      m.plinth(2.6, 1.2, 0.22);
      final banco = m.y;
      m.dome(0.54, 0.54, 0.5, dx: -0.82, at: banco);
      m.dome(0.54, 0.54, 0.5, at: banco);
      m.dome(0.54, 0.54, 0.5, dx: 0.82, at: banco);
      m.palisade(2.9, 0.8, dz: -1.15);
      m.tree(1.1, 1.8, dx: 1.75, dz: -1.15);
    },
  ),

  Landmark(
    'huerto',
    'Huerto del cura',
    6,
    0,
    'Cuatro bancales y un cerco. Lo que se come el cura y lo que reparte.',
    (m) {
      m.field(2.4, 1.2, dz: -0.7);
      m.field(2.4, 1.2, dz: 0.7);
      m.palisade(2.8, 0.6, dz: -1.4);
      m.palisade(2.8, 0.6, dz: 1.4);
      m.tree(1.0, 1.6, dx: -1.5);
      m.tree(0.95, 1.5, dx: 1.5);
    },
  ),

  Landmark(
    'pajar',
    'Pajar',
    6,
    0,
    'La paja del verano, para el invierno. Guardar es una manera de tener fe.',
    (m) {
      // Un pajar no tiene ventanas ni tejas: es un muro ciego con un portón y
      // un techo de paja gordo. Con planta de vivienda y tejado de teja era
      // una casa más, que es lo que se vio en la hoja de contacto.
      m.box(PieceKind.plinth, 2.5, 2.0, 0.22, at: 0);
      m.box(PieceKind.parapet, 2.15, 1.7, 1.3, at: 0.22);
      m.box(PieceKind.thatch, 2.6, 2.15, 1.05, at: 1.52);
      m.box(PieceKind.parapet, 1.05, 0.42, 0.85, dz: 0.95, at: 0);
      m.field(2.2, 0.9, dz: -1.75);
      m.palisade(2.5, 0.6, dz: -2.2);
    },
  ),

  Landmark(
    'corral',
    'Corral',
    6,
    0,
    'Un cerco de estacas y ya nadie se pierde por la noche.',
    (m) {
      m.palisade(3.2, 0.95, dz: -1.6);
      m.palisade(3.2, 0.95, dz: 1.6);
      m.palisade(3.2, 0.95, dx: -1.6, along: false);
      m.outbuilding(1.35, 1.15, 0.9, 0.46, dx: 1.05, dz: -0.85);
      m.box(PieceKind.parapet, 1.3, 0.34, 0.3, dx: 0.3, dz: 0.95, at: 0);
    },
  ),

  Landmark(
    'gallinero',
    'Gallinero',
    5,
    0,
    'Huevos todos los días. La costumbre más antigua que hay.',
    (m) {
      m.plinth(1.6, 1.3, 0.32);
      m.floor(1.3, 1.05, 0.78);
      m.box(PieceKind.thatch, 1.55, 1.3, 0.5);
      m.stair(0.6, 0.32, 0.72, dz: 0.95);
      m.palisade(2.3, 0.62, dz: 1.4);
    },
  ),

  Landmark(
    'alfar',
    'Alfarería',
    7,
    0,
    'Barro, torno y horno. Todo lo que contiene algo en este pueblo nació en esta rueda.',
    (m) {
      m.plinth(2.0, 1.7, 0.22);
      m.floor(1.7, 1.45, 1.0);
      m.box(PieceKind.thatch, 2.05, 1.8, 0.62);
      m.dome(1.25, 1.25, 0.95, dx: 1.55, at: 0);
      m.box(
        PieceKind.chimney,
        0.26,
        0.26,
        0.5,
        dx: 1.55,
        ridge: true,
        at: 0.72,
      );
      m.water(1.15, 1.15, dx: -1.5, dz: 0.95);
      m.palisade(1.9, 0.55, dz: -1.35);
    },
  ),

  Landmark(
    'camposanto',
    'Camposanto',
    8,
    0,
    'Tapia, cipreses y una cruz. A partir de hoy hay gente que se quedó.',
    (m) {
      // Tapia de piedra y no estacas: el corral, el colmenar y éste eran el
      // mismo cerco con otro nombre, y a un metro de distancia no se sabía
      // cuál era cuál. Y baja, que lo que hay que ver es lo de dentro.
      m.box(PieceKind.parapet, 3.3, 0.26, 0.58, dz: -1.62, at: 0);
      m.box(PieceKind.parapet, 3.3, 0.26, 0.58, dz: 1.62, at: 0);
      m.box(PieceKind.parapet, 0.26, 3.5, 0.58, dx: -1.62, at: 0);
      m.box(PieceKind.parapet, 0.26, 3.5, 0.58, dx: 1.62, at: 0);
      m.plinth(0.95, 0.95, 0.28, dx: -0.5);
      m.post(0.24, 1.5, dx: -0.5, at: m.y);
      m.beam(0.85, 0.24, 0.24, dx: -0.5, at: m.y + 1.16);
      m.tree(0.95, 2.7, dx: 1.05, dz: 1.05);
    },
  ),

  Landmark(
    'atalaya',
    'Atalaya',
    8,
    0,
    'Se ve venir a quien viene. Dormir tranquilo también se construye.',
    (m) {
      m.plinth(1.9, 1.9, 0.34);
      m.shaft(1.35, 4, 0.82);
      m.parapet(1.7, 1.7, 0.46);
      // La bandera, en la almena y no en la punta del chapitel. Clavada
      // arriba del todo, el mástil salía del vértice de un cono y lo que se
      // veía era una bandera flotando en el aire por encima de la torre.
      m.banner(1.15, dx: 0.5, dz: 0.5, at: m.y);
      m.stair(0.95, 0.44, 0.85, dz: 1.3);
    },
  ),

  Landmark(
    'almenara',
    'Almenara',
    9,
    0,
    'Un fuego arriba, y en una hora lo sabe todo el valle.',
    (m) {
      m.plinth(2.1, 2.1, 0.34);
      m.stair(1.15, 0.56, 1.0, dz: -1.5);
      m.shaft(1.5, 3, 0.9);
      m.parapet(1.9, 1.9, 0.5);
      final almena = m.y;
      m.box(PieceKind.chimney, 0.9, 0.9, 0.62, at: almena, ridge: true);
      m.post(0.34, 0.42, dx: -0.72, dz: -0.72, at: almena);
      m.post(0.34, 0.42, dx: 0.72, dz: 0.72, at: almena);
      m.palisade(2.7, 0.6, dz: 1.5);
    },
  ),

  // ------------------------------------------------------------------ tier 1
  // The works of a town that has stopped being a hamlet.
  Landmark(
    'molinoViento',
    'Molino de viento',
    13,
    1,
    'Aspas contra el poniente y trigo alrededor. El pueblo ya muele su propio pan.',
    (m) {
      m.field(3.4, 1.5, dz: -2.5);
      m.field(3.4, 1.5, dz: 2.5);
      m.plinth(2.4, 2.4, 0.42);
      m.shaft(1.9, 4, 0.8, taper: 0.11);
      final coronilla = m.y;
      m.parapet(2.0, 2.0, 0.32);
      m.spire(1.8, 1.8, 1.1);
      // Las aspas, contra la cara de la torre y a la altura de la cara: el
      // eje va donde acaba el fuste, no a una altura escrita a mano que deja
      // de ser la buena en cuanto el fuste cambia de pisos.
      m.sails(4.0, dz: -1.35, at: coronilla - 0.5);
      m.stair(0.95, 0.42, 0.85, dz: 1.6);
      m.outbuilding(1.35, 1.15, 0.9, 0.5, dx: 2.4, dz: 1.5);
    },
    rigid: true,
  ),

  Landmark(
    'almazara',
    'Almazara y olivar',
    14,
    1,
    'Olivos viejos y una viga que aprieta. Aceite para la mesa y para las lámparas.',
    (m) {
      // El olivar delante y la prensa detrás, y **todo lo que está al lado
      // dice a qué altura está**. Lo de antes ponía el cobertizo de la viga
      // con un `plinth`, que se apila sobre la línea de obra: el cobertizo
      // salía flotando a la altura del tejado de la casa, y la viga y el
      // poste debajo de él, en el aire.
      m.plinth(2.8, 2.2, 0.32, dz: 1.2);
      m.floor(2.5, 1.95, 1.2, dz: 1.2);
      m.roof(2.85, 2.3, 0.8, dz: 1.2);
      m.chimney(0.32, 0.95, dx: 0.85, dz: 1.2);
      m.box(PieceKind.plinth, 1.8, 1.8, 0.3, dx: -2.3, dz: 1.2, at: 0);
      m.post(0.32, 1.6, dx: -2.3, dz: 1.2, at: 0.3);
      m.beam(2.3, 0.3, 0.28, dx: -2.3, dz: 1.2, at: 1.6);
      m.tree(1.35, 2.0, dx: -2.2, dz: -1.7);
      m.tree(1.35, 1.9, dx: -0.6, dz: -2.2);
      m.tree(1.35, 2.1, dx: 1.0, dz: -1.7);
      m.tree(1.25, 1.8, dx: 2.4, dz: -2.2);
      m.tree(1.25, 1.9, dx: 2.6, dz: 0.2);
      m.field(4.2, 1.1, dz: -3.1);
      m.palisade(3.4, 0.55, dx: -3.2, along: false);
    },
  ),

  Landmark(
    'cerveceria',
    'Cervecería',
    12,
    1,
    'Cebada, agua y tiempo. Y un sitio donde acaba el día.',
    (m) {
      m.plinth(2.7, 2.2, 0.32);
      m.floor(2.4, 1.9, 1.2);
      m.floor(2.35, 1.85, 1.05);
      m.roof(2.75, 2.3, 0.85);
      m.chimney(0.36, 1.15, dx: -0.75);
      m.dome(1.3, 1.3, 0.95, dx: 2.0, at: 0);
      m.box(PieceKind.chimney, 0.3, 0.3, 0.6, dx: 2.0, ridge: true, at: 0.72);
      m.water(1.3, 1.3, dx: -2.1, dz: 1.1);
      m.dome(0.55, 0.55, 0.48, dx: -1.5, dz: 1.6, at: 0);
      m.dome(0.55, 0.55, 0.48, dx: -0.75, dz: 1.6, at: 0);
      m.field(2.8, 1.1, dz: -2.2);
      m.tree(1.0, 1.7, dx: 2.3, dz: -1.5);
    },
  ),

  Landmark(
    'mercado',
    'Mercado cubierto',
    13,
    1,
    'Un techo, unas arcadas y un día fijo a la semana. Aquí empieza a haber dinero.',
    (m) {
      // Lo que lo distingue de las otras veinte casas con tejado del catálogo
      // es que **no tiene paredes**: se entra por cualquier lado. Toda la
      // planta baja es arcada.
      m.plinth(3.9, 3.1, 0.3);
      m.arcade(3.7, 1.75, 2.9, rise: true);
      m.parapet(3.95, 3.15, 0.3);
      final cornisa = m.y;
      m.roof(4.15, 3.35, 1.1);
      m.dormer(0.8, 0.65, dz: 1.0);
      m.dormer(0.8, 0.65, dz: -1.0);
      m.banner(1.3, dx: -1.75, dz: 1.5, at: cornisa);
      m.banner(1.3, dx: 1.75, dz: 1.5, at: cornisa);
      m.stair(1.8, 0.3, 0.8, dz: 1.95);
      m.water(1.05, 1.05, dx: -2.8, dz: 1.5);
      m.tree(1.15, 2.1, dx: 2.8, dz: -1.6);
      m.tree(0.95, 1.7, dx: -2.8, dz: -1.6);
      m.box(PieceKind.parapet, 1.4, 0.42, 0.34, dx: -2.75, dz: -0.3, at: 0);
    },
  ),

  Landmark(
    'salinas',
    'Salinas',
    15,
    1,
    'Charcas cuadradas y sol. La sal es lo que hace que el invierno se pueda comer.',
    (m) {
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 2; j++) {
          m.water(1.7, 1.7, dx: -1.9 + i * 1.9, dz: -1.0 + j * 2.0);
        }
      }
      m.box(PieceKind.parapet, 5.6, 0.3, 0.26, at: 0);
      m.palisade(5.4, 0.45, dz: -2.2);
      m.palisade(5.4, 0.45, dz: 2.2);
      m.dome(1.25, 1.25, 1.05, dx: 3.0, dz: 1.2, at: 0);
      m.dome(1.0, 1.0, 0.85, dx: 3.1, dz: -0.3, at: 0);
      m.outbuilding(1.5, 1.25, 0.9, 0.5, dx: 3.0, dz: -1.7);
      m.post(0.18, 1.35, dx: -3.1, at: 0);
      m.beam(0.5, 3.4, 0.16, dx: -3.1, at: 1.35);
    },
  ),

  Landmark(
    'ceca',
    'Casa de la moneda',
    14,
    1,
    'Moneda propia, con la marca del pueblo. Pocos sitios llegan a esto.',
    (m) {
      // Una ceca es un sitio cerrado: tapia alta alrededor, un bloque ciego
      // dentro y la torre del arca en una esquina. Nada de esto se parece a
      // una casa grande, que es lo que era antes.
      m.box(PieceKind.parapet, 5.2, 0.32, 1.15, dz: -2.6, at: 0);
      m.box(PieceKind.parapet, 5.2, 0.32, 1.15, dz: 2.6, at: 0);
      m.box(PieceKind.parapet, 0.32, 5.5, 1.15, dx: -2.6, at: 0);
      m.box(PieceKind.parapet, 0.32, 5.5, 1.15, dx: 2.6, at: 0);
      m.plinth(2.7, 2.1, 0.4);
      m.floor(2.4, 1.8, 1.35);
      m.floor(2.35, 1.75, 1.15);
      m.roof(2.7, 2.1, 0.75);
      m.chimney(0.34, 1.0, dx: -0.85);
      m.chimney(0.3, 0.9, dx: 0.85);
      m.box(PieceKind.floor, 1.15, 1.15, 3.1, dx: 1.6, dz: -1.5, at: 0);
      m.box(
        PieceKind.parapet,
        1.35,
        1.35,
        0.32,
        dx: 1.6,
        dz: -1.5,
        ridge: true,
        at: 3.1,
      );
      m.banner(1.05, dx: 1.6, dz: -1.5, at: 3.42);
      m.stair(1.3, 0.4, 0.75, dz: 1.5);
    },
  ),

  Landmark(
    'tejedores',
    'Gremio de tejedores',
    13,
    1,
    'Telares en la planta alta y un gremio que fija el precio. El oficio se defiende junto.',
    (m) {
      m.plinth(2.9, 2.3, 0.34);
      m.floor(2.6, 2.0, 1.25);
      m.floor(2.55, 1.95, 1.1);
      // El desván abierto donde se seca el paño: es lo que se ve desde la
      // calle y lo que lo distingue de las otras casas altas.
      m.arcade(2.5, 1.0, 1.9, rise: true);
      m.roof(2.95, 2.4, 0.9);
      m.dormer(0.7, 0.6, dz: 0.95);
      m.chimney(0.32, 0.95, dx: -0.95);
      m.post(0.18, 1.6, dx: -2.4, dz: 2.1, at: 0);
      m.post(0.18, 1.6, dx: 2.4, dz: 2.1, at: 0);
      m.beam(4.8, 0.2, 0.16, dz: 2.1, at: 1.6);
      m.banner(0.95, dx: -1.2, dz: 2.1, at: 1.76);
      m.banner(0.95, dx: 1.2, dz: 2.1, at: 1.76);
      m.field(2.8, 1.0, dz: -2.3);
    },
  ),

  Landmark(
    'hospederia',
    'Hospital de peregrinos',
    15,
    1,
    'Camas para los que van de paso rezando. Se les da lo que haga falta y no se pregunta.',
    (m) {
      m.plinth(3.7, 2.5, 0.34);
      m.floor(3.4, 2.2, 1.3);
      m.floor(3.35, 2.15, 1.1);
      m.roof(3.75, 2.6, 1.0);
      // El soportal delante, donde se espera y se duerme si no hay sitio.
      m.arcade(3.3, 1.2, 0.75, dz: 1.6, at: 0);
      m.roof(3.5, 1.05, 0.45, dz: 1.62, at: 1.2);
      m.dormer(0.7, 0.6, dx: -1.15, dz: 0.8);
      m.dormer(0.7, 0.6, dx: 1.15, dz: 0.8);
      m.chimney(0.34, 1.05, dx: -1.3);
      m.box(PieceKind.plinth, 1.0, 1.0, 0.26, dx: -2.8, dz: 1.3, at: 0);
      m.box(
        PieceKind.parapet,
        0.75,
        0.75,
        0.45,
        dx: -2.8,
        dz: 1.3,
        ridge: true,
        at: 0.26,
      );
      m.water(1.2, 1.2, dx: -2.8, dz: -0.2);
      m.tree(1.25, 2.3, dx: 2.8, dz: -1.4);
      m.palisade(3.4, 0.6, dz: -2.2);
      m.stair(1.5, 0.34, 0.7, dz: 2.15);
    },
  ),

  Landmark(
    'botica',
    'Botica',
    11,
    1,
    'Frascos, hierbas y un libro. Empieza a haber remedio para algunas cosas.',
    (m) {
      m.plinth(2.3, 1.9, 0.3);
      m.floor(2.0, 1.65, 1.15);
      m.floor(1.95, 1.6, 1.05);
      m.roof(2.35, 2.0, 0.8);
      m.dormer(0.6, 0.55, dz: 0.72);
      m.chimney(0.3, 0.9, dx: -0.6);
      // El rótulo cuelga de un poste plantado en la calle. Antes colgaba de
      // una altura escrita a mano y lo que se veía era un cartel en el aire.
      m.post(0.16, 1.45, dx: 1.1, dz: 1.05, at: 0);
      m.banner(0.75, dx: 1.1, dz: 1.05, at: 1.45);
      m.field(1.1, 1.0, dx: -1.75, dz: 1.0);
      m.field(1.1, 1.0, dx: -1.75, dz: -0.25);
      m.tree(0.95, 1.7, dx: 1.8, dz: -1.35);
    },
  ),

  Landmark(
    'escuela',
    'Escuela de gramática',
    13,
    1,
    'Latín y cuentas para quien quiera. A partir de hoy se puede salir de aquí sabiendo.',
    (m) {
      m.plinth(3.2, 2.3, 0.34);
      m.floor(2.9, 2.0, 1.3);
      m.floor(2.85, 1.95, 1.1);
      m.roof(3.25, 2.4, 0.95);
      m.arcade(2.8, 1.15, 0.7, dz: 1.4, at: 0);
      m.beam(3.0, 0.8, 0.18, dz: 1.4, at: 1.15);
      m.dormer(0.65, 0.6, dx: -0.9, dz: 0.75);
      m.dormer(0.65, 0.6, dx: 0.9, dz: 0.75);
      m.chimney(0.32, 0.95, dx: -1.1);
      // La espadaña de la campana, en su propia torrecilla y desde el suelo.
      m.box(PieceKind.floor, 0.95, 0.95, 2.7, dx: 1.75, dz: -1.15, at: 0);
      m.spire(1.1, 1.1, 0.95, dx: 1.75, dz: -1.15, at: 2.7);
      m.tree(1.25, 2.3, dx: -2.4, dz: 1.5);
      m.stair(1.5, 0.34, 0.7, dz: 1.8);
    },
  ),

  Landmark(
    'escribania',
    'Escribanía',
    12,
    1,
    'Alguien que sabe escribir lo que se acuerda. Las palabras dejan de perderse.',
    (m) {
      m.plinth(2.4, 2.0, 0.32);
      m.floor(2.1, 1.7, 1.2);
      m.floor(2.05, 1.65, 1.1);
      m.floor(2.0, 1.6, 1.0);
      m.roof(2.45, 2.05, 0.85);
      m.dormer(0.6, 0.55, dz: 0.78);
      m.chimney(0.3, 0.9, dx: -0.7);
      // La escalera de fuera, que es de donde se sube al despacho.
      m.stair(0.9, 1.52, 1.35, dz: 1.55);
      m.box(PieceKind.porch, 0.95, 0.55, 0.5, dz: 1.15, at: 1.52);
      m.post(0.16, 1.35, dx: 1.2, dz: 1.2, at: 0);
      m.banner(0.75, dx: 1.2, dz: 1.2, at: 1.35);
      m.tree(1.0, 1.9, dx: -1.95, dz: -1.25);
    },
  ),

  Landmark(
    'capilla',
    'Capilla',
    12,
    1,
    'Campana propia. Ahora las horas del pueblo las marca el pueblo.',
    (m) {
      m.plinth(2.5, 3.4, 0.34);
      m.floor(2.2, 3.1, 1.45);
      m.roof(2.55, 3.45, 1.15, along: false);
      m.box(PieceKind.floor, 1.15, 1.15, 2.9, dz: -2.3, at: 0);
      m.box(
        PieceKind.parapet,
        1.35,
        1.35,
        0.32,
        dz: -2.3,
        ridge: true,
        at: 2.9,
      );
      m.spire(1.2, 1.2, 1.15, dz: -2.3, at: 3.22);
      m.arcade(2.1, 1.05, 0.5, dz: 1.65, at: 0);
      m.roof(2.35, 0.75, 0.42, dz: 1.67, at: 1.05);
      m.stair(1.35, 0.34, 0.7, dz: 2.1);
      m.tree(1.25, 2.5, dx: 1.95, dz: 1.55);
      m.tree(1.15, 2.2, dx: -1.95, dz: 1.55);
      m.palisade(3.2, 0.55, dx: -1.85, along: false);
    },
  ),

  Landmark(
    'campanario',
    'Campanario exento',
    13,
    1,
    'La campana en su propia torre, suelta, en medio de la plaza. Se oye en todo el término.',
    (m) {
      m.plinth(2.4, 2.4, 0.42);
      m.shaft(1.8, 4, 0.9);
      // El cuerpo de campanas: dos pisos abiertos, que es lo que hace que una
      // torre sea un campanario y no un torreón.
      m.arcade(1.7, 1.1, 1.7, rise: true);
      m.arcade(1.7, 1.0, 1.7, rise: true);
      m.parapet(2.15, 2.15, 0.34);
      m.spire(1.9, 1.9, 1.6);
      m.stair(1.15, 0.42, 0.85, dz: 1.55);
      m.box(PieceKind.parapet, 2.8, 0.3, 0.5, dz: -2.0, at: 0);
      m.box(PieceKind.parapet, 1.3, 0.42, 0.35, dz: 1.6, at: 0);
      m.tree(1.25, 2.3, dx: 2.1, dz: 1.4);
    },
  ),

  Landmark(
    'claustro',
    'Claustro',
    18,
    1,
    'Cuatro galerías alrededor de un jardín. Se construye para poder pensar dando vueltas.',
    (m) {
      // Un claustro es un **hueco**: cuatro galerías de arcos mirando a un
      // patio. Antes era una casa con arcos en un lado, que es otra cosa.
      m.arcade(5.0, 1.35, 0.95, dz: -2.2, at: 0);
      m.arcade(5.0, 1.35, 0.95, dz: 2.2, at: 0);
      m.arcade(5.0, 1.35, 0.95, dx: -2.2, along: false, at: 0);
      m.arcade(5.0, 1.35, 0.95, dx: 2.2, along: false, at: 0);
      m.roof(5.3, 1.15, 0.5, dz: 2.2, at: 1.35);
      m.roof(1.15, 5.3, 0.5, dx: -2.2, along: false, at: 1.35);
      m.roof(1.15, 5.3, 0.5, dx: 2.2, along: false, at: 1.35);
      // El dormitorio, sobre la galería del norte. Va encima de **los arcos**
      // y no encima del tejadillo: un tejado sube lo que sube en cada
      // comarca, y lo que se apoye en su punta se queda en el aire en la
      // comarca que construye plano.
      m.box(PieceKind.floor, 5.0, 1.0, 1.15, dz: -2.2, ridge: true, at: 1.35);
      m.roof(5.3, 1.25, 0.55, dz: -2.2, at: 2.5);
      m.field(1.5, 1.5, dx: -0.85, dz: -0.85);
      m.field(1.5, 1.5, dx: 0.85, dz: -0.85);
      m.field(1.5, 1.5, dx: -0.85, dz: 0.85);
      m.field(1.5, 1.5, dx: 0.85, dz: 0.85);
      m.water(1.1, 1.1);
      m.box(PieceKind.plinth, 0.85, 0.85, 0.3, at: 0);
      m.box(PieceKind.parapet, 0.65, 0.65, 0.45, ridge: true, at: 0.3);
      m.tree(1.15, 2.0, dx: -1.5, dz: 1.5);
      m.tree(1.0, 1.7, dx: 1.5, dz: -1.5);
    },
  ),

  Landmark(
    'refectorio',
    'Refectorio',
    13,
    1,
    'Una mesa larga y nadie habla. Comer juntos todos los días es una manera de ser uno.',
    (m) {
      m.plinth(4.6, 2.4, 0.34);
      m.floor(4.3, 2.1, 1.75);
      m.roof(4.7, 2.5, 1.2);
      // Contrafuertes: la nave es larga y baja, y son ellos los que la hacen
      // leerse como refectorio y no como pajar grande.
      m.box(PieceKind.parapet, 0.34, 0.55, 1.45, dx: -1.55, dz: 1.2, at: 0);
      m.box(PieceKind.parapet, 0.34, 0.55, 1.45, dz: 1.2, at: 0);
      m.box(PieceKind.parapet, 0.34, 0.55, 1.45, dx: 1.55, dz: 1.2, at: 0);
      m.box(PieceKind.parapet, 0.34, 0.55, 1.45, dx: -1.55, dz: -1.2, at: 0);
      m.box(PieceKind.parapet, 0.34, 0.55, 1.45, dz: -1.2, at: 0);
      m.box(PieceKind.parapet, 0.34, 0.55, 1.45, dx: 1.55, dz: -1.2, at: 0);
      m.dormer(0.7, 0.6, dz: 0.8);
      m.chimney(0.34, 1.05, dx: -1.85);
      m.stair(1.5, 0.34, 0.7, dz: 1.6);
      m.tree(1.25, 2.3, dx: 2.9, dz: -1.3);
    },
  ),

  Landmark(
    'bodega',
    'Bodega',
    12,
    1,
    'Bajo tierra siempre hace la misma temperatura. El vino de este año espera al del que viene.',
    (m) {
      // Media bodega está enterrada: lo que se ve son los lomos de tierra, los
      // respiraderos y las portadas. Nada de esto es una casa con tejado.
      m.dome(1.9, 2.7, 0.95, dx: -1.7, at: 0);
      m.dome(1.9, 2.7, 0.95, dx: 0.4, at: 0);
      m.box(
        PieceKind.chimney,
        0.32,
        0.32,
        0.55,
        dx: -1.7,
        dz: -0.6,
        ridge: true,
        at: 0.7,
      );
      m.box(
        PieceKind.chimney,
        0.32,
        0.32,
        0.55,
        dx: 0.4,
        dz: -0.6,
        ridge: true,
        at: 0.7,
      );
      m.box(PieceKind.parapet, 1.25, 1.0, 0.95, dx: -1.7, dz: 1.55, at: 0);
      m.box(PieceKind.parapet, 1.25, 1.0, 0.95, dx: 0.4, dz: 1.55, at: 0);
      m.outbuilding(1.7, 1.35, 1.0, 0.58, dx: 2.5, dz: -0.4);
      m.box(PieceKind.parapet, 0.95, 0.4, 0.32, dx: 1.7, dz: 1.7, at: 0);
      m.field(3.8, 1.0, dz: -2.5);
      m.palisade(3.8, 0.55, dz: -3.0);
      m.tree(1.1, 2.0, dx: 2.5, dz: 1.6);
    },
  ),

  Landmark(
    'silos',
    'Silos de grano',
    13,
    1,
    'El grano de tres años, a cubierto. Un pueblo con silos llenos no le teme a un mal verano.',
    (m) {
      m.box(PieceKind.plinth, 5.6, 1.9, 0.32, at: 0);
      for (var i = 0; i < 3; i++) {
        final dx = -1.75 + i * 1.75;
        // Ciegos y altos: un silo no tiene ventanas, y con planta de vivienda
        // los tres salían siendo una hilera de casas con el tejado en punta.
        m.box(PieceKind.parapet, 1.3, 1.3, 3.3, dx: dx, at: 0.32);
        m.spire(1.45, 1.45, 1.1, dx: dx, at: 3.62);
      }
      m.stair(1.25, 0.32, 0.72, dz: 1.3);
      m.field(4.2, 1.2, dz: -2.3);
      m.palisade(4.6, 0.6, dz: -2.8);
      m.outbuilding(1.45, 1.2, 0.9, 0.5, dx: 3.1, dz: 1.3);
      m.tree(1.05, 1.9, dx: -3.1, dz: 1.4);
    },
  ),

  Landmark(
    'faro',
    'Faro',
    17,
    1,
    'Una luz que no se apaga, para los que vuelven de noche. Alguien tiene que subir cada tarde.',
    (m) {
      m.water(5.2, 2.4, dz: 2.4);
      m.water(5.2, 1.4, dz: -2.7);
      m.plinth(3.3, 3.3, 0.5);
      m.plinth(2.7, 2.7, 0.45);
      m.shaft(2.05, 5, 0.95, taper: 0.13);
      final galeria = m.y;
      m.parapet(2.35, 2.35, 0.36);
      m.box(PieceKind.floor, 1.5, 1.5, 0.95, at: m.y);
      m.dome(1.65, 1.65, 0.75, at: m.y + 0.95);
      m.banner(1.15, dx: 0.8, dz: 0.8, at: galeria + 0.36);
      m.box(PieceKind.parapet, 5.2, 0.42, 0.55, dz: 1.9, at: 0);
      m.arcade(2.5, 1.05, 0.65, dz: -2.1, at: 0);
      m.roof(2.7, 0.85, 0.42, dz: -2.1, at: 1.05);
      m.stair(1.3, 0.5, 0.95, dz: 1.4);
    },
  ),

  Landmark(
    'herreriaMayor',
    'Herrería mayor',
    13,
    1,
    'Dos fraguas y un mazo. De aquí salen las rejas, los clavos y lo que haga falta.',
    (m) {
      m.plinth(3.2, 2.4, 0.34);
      m.floor(2.9, 2.1, 1.55);
      m.roof(3.3, 2.5, 0.95);
      m.chimney(0.44, 1.5, dx: -0.9);
      m.chimney(0.4, 1.25, dx: 0.9);
      m.arcade(2.8, 1.25, 0.85, dz: 1.55, at: 0);
      m.roof(3.0, 1.05, 0.45, dz: 1.6, at: 1.25);
      m.water(1.35, 1.15, dx: -2.5, dz: 0.6);
      m.dome(0.95, 0.95, 0.58, dx: 2.4, dz: -0.8, at: 0);
      m.dome(0.85, 0.85, 0.5, dx: 2.4, dz: 0.35, at: 0);
      m.box(PieceKind.parapet, 0.7, 0.7, 0.52, dx: 2.4, dz: 1.5, at: 0);
      m.palisade(3.6, 0.6, dz: -2.1);
      m.tree(1.05, 1.9, dx: -2.7, dz: -1.6);
    },
  ),

  Landmark(
    'horca',
    'Campo de la horca',
    11,
    1,
    'Se levanta a la vista del camino, y ésa es toda la idea. Un pueblo que juzga es un pueblo.',
    (m) {
      m.plinth(2.7, 2.7, 0.36);
      m.plinth(2.1, 2.1, 0.3);
      final alto = m.y;
      m.post(0.3, 2.4, dx: -0.65, at: alto);
      m.post(0.3, 2.4, dx: 0.65, at: alto);
      m.beam(1.7, 0.3, 0.28, at: alto + 2.4);
      m.box(PieceKind.parapet, 0.55, 0.55, 0.32, dz: 0.75, at: alto);
      m.stair(1.05, 0.66, 1.0, dz: 1.55);
      m.palisade(3.0, 0.6, dz: -1.8);
      m.palisade(3.0, 0.6, dx: -1.8, along: false);
      m.field(2.6, 0.9, dz: -2.4);
      m.tree(1.15, 2.1, dx: 2.3, dz: -1.5);
    },
    rigid: true,
  ),

  Landmark(
    'palenque',
    'Palenque de torneos',
    16,
    1,
    'Arena, dos tribunas y una liza en medio. El pueblo entero cabe alrededor.',
    (m) {
      m.field(5.2, 3.6);
      m.palisade(5.6, 0.85, dz: -1.95);
      m.palisade(5.6, 0.85, dz: 1.95);
      m.palisade(3.9, 0.85, dx: -2.8, along: false);
      m.palisade(3.9, 0.85, dx: 2.8, along: false);
      m.box(PieceKind.plinth, 2.3, 1.05, 0.7, dz: -2.7, at: 0);
      m.arcade(2.3, 0.95, 1.05, dz: -2.7, at: 0.7);
      m.roof(2.6, 1.35, 0.5, dz: -2.7, at: 1.65);
      m.box(PieceKind.plinth, 2.3, 1.05, 0.7, dz: 2.7, at: 0);
      m.arcade(2.3, 0.95, 1.05, dz: 2.7, at: 0.7);
      m.roof(2.6, 1.35, 0.5, dz: 2.7, at: 1.65);
      m.post(0.2, 1.9, dx: -2.8, dz: -1.95, at: 0);
      m.banner(0.95, dx: -2.8, dz: -1.95, at: 1.9);
      m.post(0.2, 1.9, dx: 2.8, dz: 1.95, at: 0);
      m.banner(0.95, dx: 2.8, dz: 1.95, at: 1.9);
      m.tree(1.25, 2.3, dx: 3.3, dz: -2.3);
    },
  ),

  Landmark(
    'huertoMonjes',
    'Huerto de los monjes',
    16,
    1,
    'Cuadros de tierra, una acequia en cruz y una noria de brazo. Se come de lo que se cuida.',
    (m) {
      m.box(PieceKind.parapet, 5.8, 0.3, 0.95, dz: -2.75, at: 0);
      m.box(PieceKind.parapet, 5.8, 0.3, 0.95, dz: 2.75, at: 0);
      m.box(PieceKind.parapet, 0.3, 5.8, 0.95, dx: -2.75, at: 0);
      m.box(PieceKind.parapet, 0.3, 5.8, 0.95, dx: 2.75, at: 0);
      m.field(2.2, 2.2, dx: -1.3, dz: -1.3);
      m.field(2.2, 2.2, dx: 1.3, dz: -1.3);
      m.field(2.2, 2.2, dx: -1.3, dz: 1.3);
      m.field(2.2, 2.2, dx: 1.3, dz: 1.3);
      m.water(5.0, 0.45);
      m.water(0.45, 5.0);
      m.box(PieceKind.plinth, 1.0, 1.0, 0.3, at: 0);
      m.box(PieceKind.parapet, 0.78, 0.78, 0.45, ridge: true, at: 0.3);
      m.tree(1.2, 2.1, dx: -2.0, dz: -2.0);
      m.tree(1.2, 1.9, dx: 2.0, dz: -2.0);
      m.tree(1.2, 2.2, dx: -2.0, dz: 2.0);
      m.tree(1.2, 2.0, dx: 2.0, dz: 2.0);
    },
  ),

  Landmark(
    'vinedo',
    'Viñedo del cabildo',
    14,
    1,
    'Cepas en hilera y un lagar al fondo. El vino de misa y el de después.',
    (m) {
      m.field(5.2, 0.9, dz: -2.2);
      m.field(5.2, 0.9, dz: -1.1);
      m.field(5.2, 0.9);
      m.field(5.2, 0.9, dz: 1.1);
      m.palisade(5.4, 0.7, dz: -2.75);
      m.palisade(5.4, 0.7, dz: 1.7);
      m.plinth(2.4, 1.9, 0.3, dz: 2.6);
      m.floor(2.1, 1.6, 1.25, dz: 2.6);
      m.roof(2.45, 1.95, 0.75, dz: 2.6);
      m.chimney(0.3, 0.9, dx: 0.6, dz: 2.6);
      m.dome(0.55, 0.55, 0.48, dx: -1.6, dz: 2.6, at: 0);
      m.dome(0.55, 0.55, 0.48, dx: -2.25, dz: 2.6, at: 0);
      m.water(1.05, 1.05, dx: 2.1, dz: 1.9);
      m.tree(1.05, 1.8, dx: -2.7, dz: -2.6);
    },
  ),

  Landmark(
    'colmenarMayor',
    'Colmenar mayor',
    12,
    1,
    'Dos docenas de colmenas y un tilo delante. La miel de aquí se vende fuera.',
    (m) {
      for (var i = 0; i < 4; i++) {
        m.dome(0.62, 0.62, 0.56, dx: -1.9 + i * 1.25, dz: -1.25, at: 0);
      }
      for (var i = 0; i < 4; i++) {
        m.dome(0.62, 0.62, 0.56, dx: -1.9 + i * 1.25, at: 0);
      }
      m.outbuilding(1.7, 1.35, 1.0, 0.58, dz: 2.2);
      m.palisade(4.8, 0.7, dz: -1.95);
      m.tree(1.35, 2.3, dx: -2.7, dz: 0.9);
    },
  ),

  // ------------------------------------------------------------------ tier 2
  // The works a town only attempts once it is sure of itself.
  Landmark(
    'castillo',
    'Castillo',
    52,
    2,
    'Foso, cuatro torres y una torre del homenaje en medio. Ya no hay que huir a ninguna parte.',
    (m) {
      // Un castillo de verdad: foso alrededor, muralla con cuatro torres en
      // las esquinas, puerta con su puente, y la torre grande en el patio.
      m.water(11.8, 1.8, dz: -5.0);
      m.water(11.8, 1.8, dz: 5.0);
      m.water(1.8, 8.2, dx: -5.0);
      m.water(1.8, 8.2, dx: 5.0);
      m.box(PieceKind.parapet, 9.0, 0.6, 2.3, dz: -4.2, at: 0);
      m.box(PieceKind.parapet, 9.0, 0.6, 2.3, dz: 4.2, at: 0);
      m.box(PieceKind.parapet, 0.6, 9.0, 2.3, dx: -4.2, at: 0);
      m.box(PieceKind.parapet, 0.6, 9.0, 2.3, dx: 4.2, at: 0);
      m.box(PieceKind.parapet, 8.4, 0.34, 0.42, dz: -4.2, at: 2.3);
      m.box(PieceKind.parapet, 8.4, 0.34, 0.42, dz: 4.2, at: 2.3);
      m.box(PieceKind.parapet, 0.34, 8.4, 0.42, dx: -4.2, at: 2.3);
      m.box(PieceKind.parapet, 0.34, 8.4, 0.42, dx: 4.2, at: 2.3);
      for (final c in const [
        (-4.2, -4.2),
        (4.2, -4.2),
        (-4.2, 4.2),
        (4.2, 4.2),
      ]) {
        m.box(PieceKind.parapet, 1.9, 1.9, 2.4, dx: c.$1, dz: c.$2, at: 0);
        m.box(PieceKind.floor, 1.85, 1.85, 0.9, dx: c.$1, dz: c.$2, at: 2.4);
        m.box(
          PieceKind.parapet,
          2.2,
          2.2,
          0.42,
          dx: c.$1,
          dz: c.$2,
          ridge: true,
          at: 3.2,
        );
        m.spire(2.0, 2.0, 1.3, dx: c.$1, dz: c.$2, at: 3.62);
      }
      m.box(PieceKind.parapet, 3.2, 1.7, 2.9, dz: 4.2, at: 0);
      m.arcade(1.3, 1.9, 1.8, dz: 4.2, at: 0);
      m.box(PieceKind.parapet, 3.5, 2.0, 0.46, dz: 4.2, ridge: true, at: 2.9);
      m.banner(1.35, dx: -1.05, dz: 4.2, at: 3.36);
      m.banner(1.35, dx: 1.05, dz: 4.2, at: 3.36);
      m.box(PieceKind.plinth, 2.0, 2.6, 0.42, dz: 5.0, at: 0);
      m.stair(1.7, 0.42, 0.95, dz: 5.9);
      m.plinth(4.2, 4.2, 0.55);
      m.floor(3.6, 3.6, 1.6);
      m.floor(3.5, 3.5, 1.5);
      m.floor(3.4, 3.4, 1.4);
      final almenas = m.y;
      m.parapet(4.0, 4.0, 0.55);
      m.box(PieceKind.floor, 1.5, 1.5, 1.3, at: m.y);
      m.spire(1.7, 1.7, 1.5, at: m.y + 1.3);
      m.banner(1.5, dx: 1.35, dz: 1.35, at: almenas + 0.55);
      m.outbuilding(2.3, 1.7, 1.25, 0.62, dx: -2.9, dz: 1.4);
      m.outbuilding(2.0, 1.5, 1.15, 0.58, dx: 2.9, dz: 1.6);
      m.box(PieceKind.plinth, 1.0, 1.0, 0.3, dx: -2.6, dz: -1.2, at: 0);
      m.box(
        PieceKind.parapet,
        0.78,
        0.78,
        0.45,
        dx: -2.6,
        dz: -1.2,
        ridge: true,
        at: 0.3,
      );
      m.field(2.6, 1.8, dx: 2.4, dz: -2.4);
      m.tree(1.25, 2.3, dx: -2.8, dz: -2.8);
      m.tree(1.15, 2.1, dx: 2.8, dz: 2.8);
    },
    scale: 0.65,
  ),

  Landmark(
    'homenaje',
    'Torre del homenaje',
    23,
    2,
    'Cinco pisos de piedra y una escalera de caracol. Desde arriba se ve hasta el otro valle.',
    (m) {
      // Un dado de piedra enorme con el talud abajo, y nada más. Lo que la
      // hace impresionante es que no tenga adornos.
      m.box(PieceKind.parapet, 6.4, 0.5, 1.5, dz: -3.0, at: 0);
      m.box(PieceKind.parapet, 6.4, 0.5, 1.5, dz: 3.0, at: 0);
      m.box(PieceKind.parapet, 0.5, 6.4, 1.5, dx: -3.0, at: 0);
      m.box(PieceKind.parapet, 0.5, 6.4, 1.5, dx: 3.0, at: 0);
      m.plinth(5.0, 5.0, 0.9);
      m.plinth(4.4, 4.4, 0.6);
      m.box(PieceKind.parapet, 4.0, 4.0, 1.7, at: m.y);
      m.box(PieceKind.parapet, 3.95, 3.95, 1.6, at: m.y + 1.7);
      m.box(PieceKind.parapet, 3.9, 3.9, 1.6, at: m.y + 3.3);
      m.floor(3.85, 3.85, 1.5, dx: 0, dz: 0);
      final remate = m.y;
      m.parapet(4.5, 4.5, 0.62);
      for (final c in const [
        (-1.75, -1.75),
        (1.75, -1.75),
        (-1.75, 1.75),
        (1.75, 1.75),
      ]) {
        m.box(
          PieceKind.parapet,
          0.75,
          0.75,
          0.55,
          dx: c.$1,
          dz: c.$2,
          ridge: true,
          at: remate + 0.62,
        );
      }
      m.banner(1.5, at: remate + 0.62);
      m.box(PieceKind.floor, 1.5, 1.5, 2.2, dx: 2.4, dz: 2.4, at: 0);
      m.stair(1.5, 1.5, 2.4, dz: 3.4);
      m.arcade(1.4, 1.5, 0.7, dz: 2.55, at: 1.5);
      m.water(1.3, 1.3, dx: -2.6, dz: 3.4);
      m.tree(1.3, 2.4, dx: 3.4, dz: -3.2);
      m.tree(1.2, 2.2, dx: -3.4, dz: -3.4);
      m.field(3.0, 1.4, dz: -3.9);
    },
    scale: 0.65,
  ),

  Landmark(
    'puertaVilla',
    'Puerta de la villa',
    21,
    2,
    'Dos torreones y un arco en medio. Entrar en el pueblo pasa a ser un acto.',
    (m) {
      // Dos torreones **separados**, con el hueco de la puerta entre ellos y
      // el arco cruzándolo: ver el arco de la villa, que es el mismo
      // problema. Un trozo de muralla a cada lado para que se entienda que
      // es una puerta y no dos torres.
      for (final dx in const [-2.6, 2.6]) {
        m.box(PieceKind.plinth, 2.7, 2.7, 0.5, dx: dx, at: 0);
        m.box(PieceKind.parapet, 2.3, 2.3, 3.4, dx: dx, at: 0.5);
        m.box(PieceKind.floor, 2.25, 2.25, 1.3, dx: dx, at: 3.9);
        m.box(PieceKind.parapet, 2.6, 2.6, 0.5, dx: dx, ridge: true, at: 5.2);
        m.spire(2.4, 2.4, 1.6, dx: dx, at: 5.7);
      }
      m.arcade(3.3, 1.5, 2.3, at: 2.4);
      m.box(PieceKind.parapet, 6.2, 2.4, 0.6, ridge: true, at: 3.9);
      m.box(PieceKind.parapet, 2.6, 0.32, 0.45, dz: 1.0, at: 4.5);
      m.banner(1.4, dx: -0.85, dz: 0.95, at: 4.5);
      m.banner(1.4, dx: 0.85, dz: 0.95, at: 4.5);
      m.box(PieceKind.parapet, 2.4, 0.6, 2.2, dx: -5.0, at: 0);
      m.box(PieceKind.parapet, 2.4, 0.6, 2.2, dx: 5.0, at: 0);
      m.box(PieceKind.parapet, 2.2, 0.34, 0.42, dx: -5.0, at: 2.2);
      m.box(PieceKind.parapet, 2.2, 0.34, 0.42, dx: 5.0, at: 2.2);
      m.box(PieceKind.plinth, 3.2, 2.8, 0.22, dz: 2.6, at: 0);
      m.tree(1.3, 2.4, dx: -5.2, dz: 2.4);
    },
    scale: 0.65,
  ),

  Landmark(
    'muralla',
    'Lienzo de muralla',
    23,
    2,
    'Un tramo de verdad, con su adarve y sus torres. El pueblo deja de ser un sitio abierto.',
    (m) {
      // Un lienzo largo con tres torres, el adarve por arriba y el foso
      // delante. Se lee de un vistazo por lo largo que es.
      m.box(PieceKind.parapet, 11.0, 0.9, 2.6, at: 0);
      m.box(PieceKind.parapet, 10.6, 0.34, 0.5, dz: -0.28, at: 2.6);
      m.box(PieceKind.parapet, 10.6, 0.34, 0.5, dz: 0.28, at: 2.6);
      for (final dx in const [-4.2, 0.0, 4.2]) {
        m.box(PieceKind.parapet, 1.9, 1.9, 3.4, dx: dx, at: 0);
        m.box(PieceKind.parapet, 2.2, 2.2, 0.45, dx: dx, ridge: true, at: 3.4);
        m.spire(2.0, 2.0, 1.2, dx: dx, at: 3.85);
      }
      m.water(11.4, 1.8, dz: -2.2);
      m.box(PieceKind.plinth, 2.2, 2.0, 0.3, dz: -2.2, at: 0);
      m.arcade(1.5, 2.0, 1.0, at: 0);
      m.stair(1.6, 2.6, 2.4, dz: 2.4);
      m.banner(1.4, dx: -4.2, dz: 0.6, at: 3.85);
      m.banner(1.4, dx: 4.2, dz: 0.6, at: 3.85);
      m.box(PieceKind.parapet, 2.6, 0.5, 1.1, dx: -5.0, dz: 1.2, at: 0);
      m.box(PieceKind.parapet, 2.6, 0.5, 1.1, dx: 5.0, dz: 1.2, at: 0);
      m.tree(1.3, 2.4, dx: -5.6, dz: 2.6);
      m.tree(1.2, 2.2, dx: 5.6, dz: 2.6);
      m.field(4.0, 1.4, dz: 3.0);
    },
    scale: 0.65,
  ),

  Landmark(
    'alcazar',
    'Alcázar',
    31,
    2,
    'Palacio por dentro y fortaleza por fuera. Quien manda aquí ya no vive como los demás.',
    (m) {
      m.box(PieceKind.parapet, 10.4, 0.55, 2.0, dz: -4.6, at: 0);
      m.box(PieceKind.parapet, 0.55, 9.8, 2.0, dx: -4.6, at: 0);
      m.box(PieceKind.parapet, 0.55, 9.8, 2.0, dx: 4.6, at: 0);
      m.box(PieceKind.parapet, 10.0, 0.32, 0.4, dz: -4.6, at: 2.0);
      for (final c in const [(-4.6, -4.6), (4.6, -4.6)]) {
        m.box(PieceKind.floor, 2.0, 2.0, 3.4, dx: c.$1, dz: c.$2, at: 0);
        m.box(
          PieceKind.parapet,
          2.3,
          2.3,
          0.45,
          dx: c.$1,
          dz: c.$2,
          ridge: true,
          at: 3.4,
        );
        m.spire(2.1, 2.1, 1.4, dx: c.$1, dz: c.$2, at: 3.85);
      }
      m.plinth(8.4, 4.4, 0.5, dz: 2.2);
      m.floor(7.8, 4.0, 1.8, dz: 2.2);
      m.floor(7.7, 3.9, 1.6, dz: 2.2);
      m.parapet(8.2, 4.3, 0.5, dz: 2.2);
      m.roof(8.0, 4.2, 1.1, dz: 2.2);
      m.arcade(7.4, 1.7, 0.9, dz: 0.55, at: 0.5);
      m.arcade(7.4, 1.5, 0.9, dz: 0.55, at: 2.3);
      m.box(PieceKind.floor, 2.4, 2.4, 5.2, dx: -3.2, dz: 2.2, at: 0);
      m.box(
        PieceKind.parapet,
        2.7,
        2.7,
        0.5,
        dx: -3.2,
        dz: 2.2,
        ridge: true,
        at: 5.2,
      );
      m.spire(2.5, 2.5, 1.8, dx: -3.2, dz: 2.2, at: 5.7);
      m.banner(1.5, dx: -3.2, dz: 2.2, at: 5.7);
      m.water(3.4, 3.4, dz: -2.0);
      m.field(2.0, 2.0, dx: -2.8, dz: -2.0);
      m.field(2.0, 2.0, dx: 2.8, dz: -2.0);
      m.box(PieceKind.plinth, 1.0, 1.0, 0.3, dz: -2.0, at: 0);
      m.box(PieceKind.parapet, 0.8, 0.8, 0.45, dz: -2.0, ridge: true, at: 0.3);
      m.stair(2.4, 0.5, 1.0, dz: -0.4);
      m.tree(1.3, 2.4, dx: -3.4, dz: -3.4);
      m.tree(1.3, 2.2, dx: 3.4, dz: -3.4);
      m.tree(1.2, 2.0, dx: 3.6, dz: 0.2);
      m.outbuilding(2.2, 1.6, 1.2, 0.6, dx: 3.2, dz: -3.6);
    },
    scale: 0.65,
  ),

  Landmark(
    'palacio',
    'Palacio del señor',
    23,
    2,
    'Tres alas alrededor de un patio de honor. Aquí se recibe, que es distinto de vivir.',
    (m) {
      // En U: cuerpo al fondo y dos alas abriéndose, con el patio de honor
      // en medio. La silueta no se parece a ninguna otra del catálogo.
      m.box(PieceKind.plinth, 9.0, 2.6, 0.45, dz: -2.8, at: 0);
      m.box(PieceKind.floor, 8.4, 2.2, 1.9, dz: -2.8, at: 0.45);
      m.box(PieceKind.floor, 8.3, 2.1, 1.7, dz: -2.8, at: 2.35);
      m.roof(8.8, 2.7, 1.2, dz: -2.8, at: 4.05);
      m.box(PieceKind.plinth, 2.6, 4.4, 0.45, dx: -3.2, dz: 0.6, at: 0);
      m.box(PieceKind.floor, 2.2, 4.0, 1.9, dx: -3.2, dz: 0.6, at: 0.45);
      m.roof(2.7, 4.5, 1.0, dx: -3.2, dz: 0.6, along: false, at: 2.35);
      m.box(PieceKind.plinth, 2.6, 4.4, 0.45, dx: 3.2, dz: 0.6, at: 0);
      m.box(PieceKind.floor, 2.2, 4.0, 1.9, dx: 3.2, dz: 0.6, at: 0.45);
      m.roof(2.7, 4.5, 1.0, dx: 3.2, dz: 0.6, along: false, at: 2.35);
      m.arcade(4.0, 1.9, 0.8, dz: -1.5, at: 0.45);
      m.box(PieceKind.floor, 2.8, 2.8, 4.6, dz: -2.8, at: 0);
      m.box(PieceKind.parapet, 3.1, 3.1, 0.5, ridge: true, dz: -2.8, at: 4.6);
      m.spire(2.9, 2.9, 2.0, dz: -2.8, at: 5.1);
      m.banner(1.4, dx: -1.0, dz: -2.8, at: 5.1);
      m.banner(1.4, dx: 1.0, dz: -2.8, at: 5.1);
      m.water(2.2, 2.2, dz: 0.8);
      m.field(1.8, 1.8, dx: -1.6, dz: 2.4);
      m.field(1.8, 1.8, dx: 1.6, dz: 2.4);
      m.box(PieceKind.parapet, 6.6, 0.4, 0.75, dz: 3.6, at: 0);
      m.stair(2.6, 0.45, 1.0, dz: -0.6);
      m.tree(1.3, 2.4, dx: -3.4, dz: 3.2);
      m.tree(1.3, 2.3, dx: 3.4, dz: 3.2);
    },
    scale: 0.65,
  ),

  Landmark(
    'concejo',
    'Casa del concejo',
    20,
    2,
    'Un balcón para leer los bandos y una sala para discutirlos. El pueblo se gobierna solo.',
    (m) {
      // Lo que hace a un ayuntamiento: soportal abierto abajo, balcón corrido
      // arriba y el campanario del reloj encima.
      m.box(PieceKind.plinth, 6.6, 4.2, 0.4, at: 0);
      m.arcade(6.2, 1.9, 3.8, rise: true, at: 0.4);
      m.box(PieceKind.floor, 6.2, 3.8, 1.8, at: 2.3);
      m.box(PieceKind.parapet, 6.6, 0.34, 0.45, dz: 1.82, at: 2.4);
      m.box(PieceKind.parapet, 6.7, 4.3, 0.42, ridge: true, at: 4.1);
      m.roof(6.8, 4.4, 1.3, at: 4.52);
      m.dormer(0.9, 0.7, dz: 1.2);
      m.dormer(0.9, 0.7, dz: -1.2);
      // La torre del reloj, **desde el suelo y a un costado**. Encajada
      // encima del tejado del salón era una torre apoyada en unas tejas: el
      // tejado sube lo que sube en cada comarca y la torre se quedaba
      // flotando por encima del caballete en media docena de ellas.
      m.box(PieceKind.floor, 2.1, 2.1, 6.2, dx: 4.0, at: 0);
      m.arcade(1.8, 1.4, 1.8, dx: 4.0, at: 6.2);
      m.box(PieceKind.parapet, 2.4, 2.4, 0.42, dx: 4.0, ridge: true, at: 7.6);
      m.spire(2.2, 2.2, 1.7, dx: 4.0, at: 8.02);
      m.banner(1.4, dx: -2.6, dz: 1.9, at: 2.85);
      m.banner(1.4, dx: 2.6, dz: 1.9, at: 2.85);
      m.stair(2.4, 0.4, 0.9, dz: 2.5);
      m.box(PieceKind.parapet, 1.3, 0.45, 0.35, dx: -3.6, dz: 1.4, at: 0);
      m.box(PieceKind.parapet, 1.3, 0.45, 0.35, dx: -3.6, dz: -1.4, at: 0);
      m.tree(1.3, 2.4, dx: -4.6, dz: -1.4);
      m.tree(1.2, 2.2, dx: 4.4, dz: 2.6);
      m.box(PieceKind.plinth, 5.0, 1.6, 0.22, dz: 3.2, at: 0);
    },
    scale: 0.65,
  ),

  Landmark(
    'lonja',
    'Lonja de mercaderes',
    20,
    2,
    'Una sala con columnas donde se cierran los tratos. La palabra dada aquí vale en tres reinos.',
    (m) {
      // Una sola sala enorme, alta y sin pisos, sobre una lonja de arcos. Lo
      // que impresiona de una lonja es el vacío de dentro.
      m.box(PieceKind.plinth, 8.2, 5.2, 0.5, at: 0);
      m.box(PieceKind.floor, 7.6, 4.6, 3.6, at: 0.5);
      m.box(PieceKind.parapet, 7.9, 4.9, 0.55, ridge: true, at: 4.1);
      m.roof(8.0, 5.0, 1.2, at: 4.65);
      m.arcade(7.2, 2.4, 1.0, dz: 2.3, at: 0.5);
      m.arcade(7.2, 2.4, 1.0, dz: -2.3, at: 0.5);
      m.arcade(4.2, 2.4, 1.0, dx: -3.3, along: false, at: 0.5);
      m.arcade(4.2, 2.4, 1.0, dx: 3.3, along: false, at: 0.5);
      for (final c in const [
        (-3.8, -2.6),
        (3.8, -2.6),
        (-3.8, 2.6),
        (3.8, 2.6),
      ]) {
        m.box(
          PieceKind.parapet,
          0.75,
          0.75,
          0.7,
          dx: c.$1,
          dz: c.$2,
          ridge: true,
          at: 4.65,
        );
      }
      m.banner(1.4, dx: -3.8, dz: 2.6, at: 5.35);
      m.banner(1.4, dx: 3.8, dz: 2.6, at: 5.35);
      m.stair(3.0, 0.5, 1.0, dz: 3.3);
      m.box(PieceKind.parapet, 1.4, 0.5, 0.36, dx: -4.6, dz: 1.6, at: 0);
      m.box(PieceKind.parapet, 1.4, 0.5, 0.36, dx: 4.6, dz: 1.6, at: 0);
      m.tree(1.3, 2.4, dx: -4.8, dz: -1.8);
      m.tree(1.2, 2.2, dx: 4.8, dz: -1.8);
      m.box(PieceKind.plinth, 5.4, 1.5, 0.22, dz: 4.0, at: 0);
    },
    scale: 0.65,
  ),

  Landmark(
    'iglesia',
    'Iglesia',
    21,
    2,
    'Nave, crucero y una torre con campanas. El pueblo ya tiene sitio donde bautizar y donde despedir.',
    (m) {
      // Nave larga, crucero cruzado y torre a los pies: la planta de cruz es
      // lo que la distingue de la capilla, que es una caja con campanario.
      m.box(PieceKind.plinth, 4.0, 9.0, 0.45, at: 0);
      m.box(PieceKind.floor, 3.5, 8.4, 2.6, at: 0.45);
      m.roof(3.9, 8.8, 1.5, along: false, at: 3.05);
      m.box(PieceKind.plinth, 7.4, 3.2, 0.45, dz: -1.6, at: 0);
      m.box(PieceKind.floor, 6.9, 2.8, 2.6, dz: -1.6, at: 0.45);
      m.roof(7.3, 3.2, 1.3, dz: -1.6, at: 3.05);
      m.box(PieceKind.floor, 2.6, 2.6, 5.6, dz: 4.0, at: 0);
      m.arcade(2.2, 1.4, 2.2, dz: 4.0, at: 5.6);
      m.box(PieceKind.parapet, 2.9, 2.9, 0.5, dz: 4.0, ridge: true, at: 7.0);
      m.spire(2.7, 2.7, 2.4, dz: 4.0, at: 7.5);
      // El cimborrio arranca de **los muros** del crucero y no de su tejado:
      // un tejado sube lo que sube en cada comarca, y lo que se apoye en su
      // punta se queda en el aire donde se construye plano.
      m.box(PieceKind.floor, 2.5, 2.5, 1.3, dz: -1.6, at: 3.05);
      m.dome(2.7, 2.7, 1.5, dz: -1.6, at: 4.35);
      m.arcade(2.4, 2.0, 0.6, dz: 5.5, at: 0);
      m.box(PieceKind.parapet, 0.42, 0.5, 1.3, dx: -1.95, dz: 1.2, at: 0.45);
      m.box(PieceKind.parapet, 0.42, 0.5, 1.3, dx: 1.95, dz: 1.2, at: 0.45);
      m.stair(2.2, 0.45, 0.9, dz: 5.8);
      m.box(PieceKind.parapet, 4.6, 0.4, 0.8, dx: -3.4, dz: 2.6, at: 0);
      m.tree(1.3, 2.6, dx: 3.4, dz: 3.4);
      m.tree(1.3, 2.4, dx: -3.6, dz: 4.4);
      m.tree(1.2, 2.2, dx: 3.6, dz: -3.6);
      m.field(3.0, 1.4, dx: -3.2, dz: -3.4);
    },
    scale: 0.65,
  ),

  Landmark(
    'catedral',
    'Catedral',
    33,
    2,
    'Dos torres, un crucero y un cimborrio. Se empieza sabiendo que la terminan los nietos.',
    (m) {
      // Lo mismo que la iglesia, llevado al límite: nave más alta, dos torres
      // a los pies, cimborrio sobre el crucero y contrafuertes a los lados.
      m.box(PieceKind.plinth, 5.0, 10.4, 0.5, at: 0);
      m.box(PieceKind.floor, 4.4, 9.8, 4.2, at: 0.5);
      m.box(PieceKind.parapet, 4.7, 10.1, 0.5, ridge: true, at: 4.7);
      m.roof(4.6, 10.0, 1.8, along: false, at: 5.2);
      m.box(PieceKind.plinth, 9.6, 4.0, 0.5, dz: -1.8, at: 0);
      m.box(PieceKind.floor, 9.0, 3.5, 4.2, dz: -1.8, at: 0.5);
      m.roof(9.4, 3.9, 1.5, dz: -1.8, at: 4.7);
      m.box(PieceKind.floor, 3.2, 3.2, 5.4, dz: -1.8, at: 4.7);
      m.dome(3.4, 3.4, 2.2, dz: -1.8, at: 10.1);
      for (final dx in const [-1.7, 1.7]) {
        m.box(PieceKind.floor, 2.4, 2.4, 6.6, dx: dx, dz: 4.6, at: 0);
        m.arcade(2.0, 1.5, 2.0, dx: dx, dz: 4.6, at: 6.6);
        m.box(
          PieceKind.parapet,
          2.7,
          2.7,
          0.5,
          dx: dx,
          dz: 4.6,
          ridge: true,
          at: 8.1,
        );
        m.spire(2.5, 2.5, 2.6, dx: dx, dz: 4.6, at: 8.6);
      }
      for (final dz in const [-4.6, -3.0, 1.0, 2.6]) {
        m.box(PieceKind.parapet, 0.45, 0.6, 3.4, dx: -2.4, dz: dz, at: 0.5);
        m.box(PieceKind.parapet, 0.45, 0.6, 3.4, dx: 2.4, dz: dz, at: 0.5);
      }
      m.arcade(2.6, 2.4, 0.7, dz: 5.6, at: 0);
      m.box(PieceKind.parapet, 3.0, 0.8, 0.6, dz: 5.6, ridge: true, at: 2.4);
      m.stair(3.0, 0.5, 0.9, dz: 5.95);
      m.box(PieceKind.parapet, 0.6, 0.6, 1.4, dz: -5.0, at: 4.7);
      m.banner(1.4, dx: -1.7, dz: 5.5, at: 8.6);
      m.banner(1.4, dx: 1.7, dz: 5.5, at: 8.6);
      m.tree(1.3, 2.6, dx: -4.4, dz: 4.4);
      m.tree(1.3, 2.4, dx: 4.4, dz: 4.4);
    },
    scale: 0.65,
  ),

  Landmark(
    'monasterio',
    'Monasterio',
    27,
    2,
    'Iglesia, claustro y huerta dentro de una tapia. Un pueblo entero que reza y trabaja aparte.',
    (m) {
      // Un recinto: tapia, iglesia a un lado, claustro al otro y la huerta al
      // fondo. Es el único hito que es **varios edificios**.
      m.box(PieceKind.parapet, 12.0, 0.4, 1.1, dz: -5.4, at: 0);
      m.box(PieceKind.parapet, 12.0, 0.4, 1.1, dz: 5.4, at: 0);
      m.box(PieceKind.parapet, 0.4, 11.2, 1.1, dx: -5.8, at: 0);
      m.box(PieceKind.parapet, 0.4, 11.2, 1.1, dx: 5.8, at: 0);
      m.box(PieceKind.plinth, 3.4, 7.6, 0.4, dx: -3.6, dz: -1.0, at: 0);
      m.box(PieceKind.floor, 3.0, 7.0, 2.8, dx: -3.6, dz: -1.0, at: 0.4);
      m.roof(3.4, 7.4, 1.4, dx: -3.6, dz: -1.0, along: false, at: 3.2);
      m.box(PieceKind.floor, 2.2, 2.2, 5.4, dx: -3.6, dz: 2.4, at: 0);
      m.box(
        PieceKind.parapet,
        2.5,
        2.5,
        0.45,
        dx: -3.6,
        dz: 2.4,
        ridge: true,
        at: 5.4,
      );
      m.spire(2.3, 2.3, 2.0, dx: -3.6, dz: 2.4, at: 5.85);
      m.arcade(4.6, 1.5, 0.9, dx: 1.8, dz: -2.6, at: 0);
      m.arcade(4.6, 1.5, 0.9, dx: 1.8, dz: 1.8, at: 0);
      m.arcade(4.4, 1.5, 0.9, dx: -0.4, dz: -0.4, along: false, at: 0);
      m.arcade(4.4, 1.5, 0.9, dx: 4.0, dz: -0.4, along: false, at: 0);
      m.roof(4.9, 1.1, 0.5, dx: 1.8, dz: -2.6, at: 1.5);
      m.roof(4.9, 1.1, 0.5, dx: 1.8, dz: 1.8, at: 1.5);
      m.roof(1.1, 4.7, 0.5, dx: -0.4, dz: -0.4, along: false, at: 1.5);
      m.roof(1.1, 4.7, 0.5, dx: 4.0, dz: -0.4, along: false, at: 1.5);
      m.water(1.0, 1.0, dx: 1.8, dz: -0.4);
      m.box(PieceKind.plinth, 0.9, 0.9, 0.3, dx: 1.8, dz: -0.4, at: 0);
      m.field(3.0, 1.6, dx: 1.4, dz: 3.8);
      m.field(3.0, 1.6, dx: 4.4, dz: 3.8);
      m.field(3.0, 1.6, dx: 1.4, dz: -4.4);
      m.tree(1.3, 2.4, dx: 4.6, dz: -4.4);
      m.tree(1.2, 2.2, dx: -5.0, dz: 4.4);
      m.arcade(2.0, 1.8, 0.6, dz: -5.4, at: 0);
      m.stair(1.8, 0.4, 0.8, dz: -6.0);
    },
    scale: 0.65,
  ),

  Landmark(
    'abadia',
    'Abadía',
    24,
    2,
    'Iglesia grande, granero enorme y una bodega debajo. Se reza, pero también se administra.',
    (m) {
      m.box(PieceKind.plinth, 4.6, 9.4, 0.45, dx: -2.4, at: 0);
      m.box(PieceKind.floor, 4.0, 8.8, 3.4, dx: -2.4, at: 0.45);
      m.box(PieceKind.parapet, 4.3, 9.1, 0.45, dx: -2.4, ridge: true, at: 3.85);
      m.roof(4.2, 9.0, 1.6, dx: -2.4, along: false, at: 4.3);
      m.box(PieceKind.floor, 2.6, 2.6, 6.2, dx: -2.4, dz: 3.6, at: 0);
      m.box(
        PieceKind.parapet,
        2.9,
        2.9,
        0.45,
        dx: -2.4,
        dz: 3.6,
        ridge: true,
        at: 6.2,
      );
      m.spire(2.7, 2.7, 2.4, dx: -2.4, dz: 3.6, at: 6.65);
      for (final dz in const [-3.4, -1.2, 1.0]) {
        m.box(PieceKind.parapet, 0.45, 0.7, 2.8, dx: -4.5, dz: dz, at: 0.45);
        m.box(PieceKind.parapet, 0.45, 0.7, 2.8, dx: -0.3, dz: dz, at: 0.45);
      }
      m.box(PieceKind.plinth, 5.0, 6.4, 0.4, dx: 3.2, dz: -1.0, at: 0);
      m.box(PieceKind.floor, 4.5, 5.8, 2.6, dx: 3.2, dz: -1.0, at: 0.4);
      m.roof(4.9, 6.2, 1.8, dx: 3.2, dz: -1.0, along: false, at: 3.0);
      m.arcade(2.0, 2.0, 0.7, dx: 3.2, dz: 2.2, at: 0);
      m.dome(1.8, 2.4, 0.9, dx: 3.4, dz: 3.6, at: 0);
      m.box(
        PieceKind.chimney,
        0.32,
        0.32,
        0.5,
        dx: 3.4,
        dz: 3.2,
        ridge: true,
        at: 0.7,
      );
      m.field(4.0, 1.6, dz: -5.4);
      m.palisade(5.4, 0.7, dz: -6.2);
      m.tree(1.3, 2.5, dx: 5.4, dz: 4.2);
      m.tree(1.2, 2.2, dx: -5.4, dz: 5.2);
      m.stair(2.0, 0.45, 0.85, dz: 5.4);
    },
    scale: 0.65,
  ),

  Landmark(
    'colegiata',
    'Colegiata',
    22,
    2,
    'Una iglesia con cabildo propio, y un claustrillo detrás para los canónigos.',
    (m) {
      // Iglesia con claustrillo pegado: dos cosas distintas cosidas, que es
      // exactamente lo que es una colegiata.
      m.box(PieceKind.plinth, 4.2, 7.6, 0.45, dx: -1.6, at: 0);
      m.box(PieceKind.floor, 3.7, 7.0, 3.0, dx: -1.6, at: 0.45);
      m.roof(4.1, 7.4, 1.5, dx: -1.6, along: false, at: 3.45);
      m.box(PieceKind.floor, 2.4, 2.4, 6.0, dx: -1.6, dz: 3.2, at: 0);
      m.arcade(2.0, 1.3, 2.0, dx: -1.6, dz: 3.2, at: 6.0);
      m.box(
        PieceKind.parapet,
        2.7,
        2.7,
        0.45,
        dx: -1.6,
        dz: 3.2,
        ridge: true,
        at: 7.3,
      );
      m.spire(2.5, 2.5, 2.2, dx: -1.6, dz: 3.2, at: 7.75);
      m.arcade(4.0, 1.5, 0.9, dx: 2.6, dz: -2.4, at: 0);
      m.arcade(4.0, 1.5, 0.9, dx: 2.6, dz: 1.6, at: 0);
      m.arcade(4.0, 1.5, 0.9, dx: 0.9, along: false, dz: -0.4, at: 0);
      m.arcade(4.0, 1.5, 0.9, dx: 4.3, along: false, dz: -0.4, at: 0);
      m.roof(4.3, 1.1, 0.5, dx: 2.6, dz: -2.4, at: 1.5);
      m.roof(4.3, 1.1, 0.5, dx: 2.6, dz: 1.6, at: 1.5);
      m.roof(1.1, 4.3, 0.5, dx: 0.9, dz: -0.4, along: false, at: 1.5);
      m.roof(1.1, 4.3, 0.5, dx: 4.3, dz: -0.4, along: false, at: 1.5);
      m.field(1.6, 1.6, dx: 2.6, dz: -0.4);
      m.water(0.9, 0.9, dx: 2.6, dz: -0.4);
      m.box(PieceKind.parapet, 0.55, 0.55, 1.3, dx: -1.6, dz: -3.4, at: 3.45);
      m.arcade(2.2, 1.9, 0.6, dx: -1.6, dz: 4.6, at: 0);
      m.stair(2.0, 0.45, 0.85, dz: 4.9);
      m.tree(1.3, 2.5, dx: -3.8, dz: -3.0);
      m.tree(1.2, 2.2, dx: 4.6, dz: 3.0);
    },
    scale: 0.65,
  ),

  Landmark(
    'sinagoga',
    'Sinagoga',
    20,
    2,
    'Una sala clara con el arca al fondo y un patio con su fuente. Otra manera de ser de aquí.',
    (m) {
      m.box(PieceKind.plinth, 6.4, 5.4, 0.5, dz: -1.4, at: 0);
      m.box(PieceKind.floor, 5.8, 4.8, 3.6, dz: -1.4, at: 0.5);
      m.box(PieceKind.parapet, 6.1, 5.1, 0.5, dz: -1.4, ridge: true, at: 4.1);
      m.dome(4.6, 4.0, 1.9, dz: -1.4, at: 4.6);
      for (final dx in const [-2.9, 2.9]) {
        m.box(PieceKind.parapet, 0.7, 0.7, 0.9, dx: dx, dz: -3.6, at: 4.6);
        m.box(PieceKind.parapet, 0.7, 0.7, 0.9, dx: dx, dz: 0.8, at: 4.6);
      }
      m.arcade(4.4, 2.2, 0.8, dz: 1.4, at: 0.5);
      m.box(PieceKind.parapet, 4.8, 1.0, 0.5, dz: 1.4, ridge: true, at: 2.7);
      m.box(PieceKind.parapet, 6.2, 0.4, 1.0, dz: 4.6, at: 0);
      m.box(PieceKind.parapet, 0.4, 3.4, 1.0, dx: -3.0, dz: 3.0, at: 0);
      m.box(PieceKind.parapet, 0.4, 3.4, 1.0, dx: 3.0, dz: 3.0, at: 0);
      m.water(1.4, 1.4, dz: 3.0);
      m.box(PieceKind.plinth, 1.1, 1.1, 0.3, dz: 3.0, at: 0);
      m.box(PieceKind.parapet, 0.85, 0.85, 0.5, dz: 3.0, ridge: true, at: 0.3);
      m.field(1.6, 1.6, dx: -2.0, dz: 3.2);
      m.field(1.6, 1.6, dx: 2.0, dz: 3.2);
      m.stair(2.2, 0.5, 0.9, dz: 2.1);
      m.tree(1.3, 2.4, dx: -3.6, dz: 4.6);
      m.tree(1.2, 2.2, dx: 3.6, dz: 4.6);
    },
    scale: 0.65,
  ),

  Landmark(
    'mezquita',
    'Mezquita',
    21,
    2,
    'Un bosque de arcos, un patio con naranjos y un alminar. Se oye desde todo el barrio.',
    (m) {
      // Una mezquita es un **bosque de columnas**: la sala es toda arcada,
      // sin pisos, y el alminar sale del patio.
      m.box(PieceKind.plinth, 8.0, 6.0, 0.45, dz: -1.6, at: 0);
      for (final dz in const [-3.6, -2.2, -0.8, 0.6]) {
        m.arcade(7.4, 2.8, 1.1, dz: dz, at: 0.45);
      }
      m.box(PieceKind.parapet, 8.0, 6.0, 0.5, dz: -1.6, ridge: true, at: 3.25);
      m.roof(8.2, 6.2, 1.1, dz: -1.6, at: 3.75);
      m.dome(2.6, 2.6, 1.5, dz: -3.2, at: 3.75);
      m.box(PieceKind.floor, 2.0, 2.0, 6.4, dx: -3.2, dz: 3.4, at: 0);
      m.arcade(1.7, 1.2, 1.7, dx: -3.2, dz: 3.4, at: 6.4);
      m.box(
        PieceKind.parapet,
        2.3,
        2.3,
        0.4,
        dx: -3.2,
        dz: 3.4,
        ridge: true,
        at: 7.6,
      );
      m.spire(2.1, 2.1, 1.6, dx: -3.2, dz: 3.4, at: 8.0);
      m.box(PieceKind.parapet, 8.0, 0.4, 1.2, dz: 5.4, at: 0);
      m.box(PieceKind.parapet, 0.4, 4.2, 1.2, dx: 3.8, dz: 3.4, at: 0);
      m.water(2.0, 1.2, dz: 3.4);
      m.tree(1.2, 2.0, dx: 1.6, dz: 2.6);
      m.tree(1.2, 2.1, dx: 1.6, dz: 4.2);
      m.tree(1.2, 2.0, dx: -0.2, dz: 2.6);
      m.tree(1.2, 2.1, dx: -0.2, dz: 4.2);
      m.arcade(2.2, 2.0, 0.6, dz: 5.4, at: 0);
      m.stair(2.0, 0.45, 0.85, dz: 5.9);
    },
    scale: 0.65,
  ),

  Landmark(
    'baptisterio',
    'Baptisterio',
    18,
    2,
    'Ocho lados, una pila en medio y luz de arriba. Aquí entra en el pueblo el que nace.',
    (m) {
      // Un octógono exento: tres cuerpos que se van estrechando y la linterna
      // encima. Pequeño de planta y alto, que es lo contrario que la lonja.
      m.box(PieceKind.plinth, 5.6, 5.6, 0.5, at: 0);
      m.box(PieceKind.plinth, 4.8, 4.8, 0.45, at: 0.5);
      m.box(PieceKind.floor, 4.0, 4.0, 2.4, at: 0.95);
      m.arcade(3.6, 1.4, 3.6, at: 3.35);
      m.box(PieceKind.parapet, 4.3, 4.3, 0.5, ridge: true, at: 4.75);
      m.dome(3.9, 3.9, 2.0, at: 5.25);
      m.box(PieceKind.floor, 1.2, 1.2, 0.9, at: 6.55);
      m.spire(1.4, 1.4, 1.0, at: 7.45);
      m.arcade(2.4, 2.2, 0.8, dz: 2.4, at: 0.95);
      m.box(PieceKind.parapet, 2.8, 1.0, 0.5, dz: 2.4, ridge: true, at: 3.15);
      m.stair(2.6, 0.95, 1.2, dz: 3.5);
      m.water(1.6, 1.6, dx: -3.4, dz: -1.6);
      m.box(PieceKind.parapet, 4.4, 0.4, 0.7, dz: -3.4, at: 0);
      m.box(PieceKind.parapet, 0.4, 2.6, 0.7, dx: -2.2, dz: -2.2, at: 0);
      m.box(PieceKind.parapet, 0.4, 2.6, 0.7, dx: 2.2, dz: -2.2, at: 0);
      m.tree(1.3, 2.5, dx: -3.4, dz: 2.4);
      m.tree(1.2, 2.2, dx: 3.4, dz: 2.4);
      m.tree(1.2, 2.0, dx: 3.4, dz: -2.6);
    },
    scale: 0.65,
  ),

  Landmark(
    'hospitalMayor',
    'Hospital mayor',
    21,
    2,
    'Dos naves en cruz y un altar en el centro, para que todas las camas lo vean. Cuidar también se organiza.',
    (m) {
      // La planta en cruz no es un adorno: es la idea del sitio, cuatro salas
      // que miran todas al mismo centro.
      m.box(PieceKind.plinth, 3.8, 10.0, 0.45, at: 0);
      m.box(PieceKind.floor, 3.3, 9.4, 2.8, at: 0.45);
      m.roof(3.7, 9.8, 1.4, along: false, at: 3.25);
      m.box(PieceKind.plinth, 10.0, 3.8, 0.45, at: 0);
      m.box(PieceKind.floor, 9.4, 3.3, 2.8, at: 0.45);
      m.roof(9.8, 3.7, 1.4, at: 3.25);
      m.box(PieceKind.floor, 3.2, 3.2, 1.6, at: 3.25);
      m.box(PieceKind.parapet, 3.5, 3.5, 0.45, ridge: true, at: 4.85);
      m.dome(3.3, 3.3, 1.9, at: 5.3);
      m.box(PieceKind.floor, 1.0, 1.0, 0.8, at: 7.2);
      m.spire(1.2, 1.2, 0.9, at: 8.0);
      m.arcade(2.6, 2.2, 0.7, dz: 5.2, at: 0);
      m.box(PieceKind.parapet, 3.0, 0.9, 0.5, dz: 5.2, ridge: true, at: 2.2);
      m.stair(2.4, 0.45, 0.9, dz: 5.9);
      m.water(1.4, 1.4, dx: -3.4, dz: -3.4);
      m.box(PieceKind.plinth, 1.1, 1.1, 0.3, dx: -3.4, dz: -3.4, at: 0);
      m.field(2.6, 2.6, dx: 3.4, dz: -3.4);
      m.field(2.6, 2.6, dx: -3.4, dz: 3.4);
      m.tree(1.3, 2.5, dx: 3.4, dz: 3.4);
      m.tree(1.2, 2.2, dx: 3.6, dz: -1.0);
      m.box(PieceKind.parapet, 5.0, 0.4, 0.8, dz: -5.6, at: 0);
    },
    scale: 0.65,
  ),

  Landmark(
    'universidad',
    'Universidad',
    29,
    2,
    'Un patio con aulas alrededor y una escalera que todos suben. Lo que se sabe aquí se queda.',
    (m) {
      // Un patio cuadrado de dos pisos de arcos, con la torre del reloj en
      // una esquina. Es el claustro llevado a lo civil, y más alto.
      m.box(PieceKind.plinth, 11.0, 10.4, 0.4, at: 0);
      for (final dz in const [-4.4, 4.4]) {
        m.arcade(10.2, 2.1, 1.4, dz: dz, at: 0.4);
        m.arcade(10.2, 1.9, 1.4, dz: dz, at: 2.5);
        m.roof(10.6, 1.7, 0.7, dz: dz, at: 4.4);
      }
      for (final dx in const [-4.6, 4.6]) {
        m.arcade(7.2, 2.1, 1.4, dx: dx, along: false, at: 0.4);
        m.arcade(7.2, 1.9, 1.4, dx: dx, along: false, at: 2.5);
        m.roof(1.7, 7.6, 0.7, dx: dx, along: false, at: 4.4);
      }
      m.box(PieceKind.floor, 2.6, 2.6, 5.6, dx: -4.6, dz: -4.4, at: 0.4);
      m.arcade(2.2, 1.4, 2.2, dx: -4.6, dz: -4.4, at: 6.0);
      m.box(
        PieceKind.parapet,
        2.9,
        2.9,
        0.45,
        dx: -4.6,
        dz: -4.4,
        ridge: true,
        at: 7.4,
      );
      m.spire(2.7, 2.7, 2.2, dx: -4.6, dz: -4.4, at: 7.85);
      m.field(3.0, 2.6, dx: -1.8, dz: -1.6);
      m.field(3.0, 2.6, dx: 1.8, dz: -1.6);
      m.field(3.0, 2.6, dx: -1.8, dz: 1.6);
      m.field(3.0, 2.6, dx: 1.8, dz: 1.6);
      m.water(1.3, 1.3);
      m.box(PieceKind.plinth, 1.0, 1.0, 0.3, at: 0);
      m.box(PieceKind.parapet, 0.8, 0.8, 0.45, ridge: true, at: 0.3);
      m.arcade(2.8, 2.6, 1.5, dz: 4.4, at: 0.4);
      m.box(PieceKind.parapet, 3.2, 1.7, 0.6, dz: 4.4, ridge: true, at: 3.0);
      m.banner(1.4, dx: -1.4, dz: 4.4, at: 3.6);
      m.banner(1.4, dx: 1.4, dz: 4.4, at: 3.6);
      m.stair(2.8, 0.4, 0.9, dz: 5.6);
      m.tree(1.3, 2.5, dx: 4.8, dz: -5.4);
    },
    scale: 0.65,
  ),

  Landmark(
    'biblioteca',
    'Biblioteca',
    21,
    2,
    'Una sala larga con ventanales y anaqueles hasta el techo. Copiar un libro lleva un año.',
    (m) {
      // Una sola sala altísima, de ventanal en ventanal, sobre un podio.
      // Nada de pisos: lo que se ve es la altura de dentro.
      m.box(PieceKind.plinth, 6.0, 10.0, 0.6, at: 0);
      m.box(PieceKind.plinth, 5.4, 9.4, 0.4, at: 0.6);
      m.box(PieceKind.floor, 4.8, 8.8, 4.4, at: 1.0);
      m.box(PieceKind.parapet, 5.1, 9.1, 0.55, ridge: true, at: 5.4);
      m.roof(5.0, 9.0, 1.4, along: false, at: 5.95);
      for (final dz in const [-3.2, -1.1, 1.0, 3.1]) {
        m.box(PieceKind.parapet, 0.5, 0.7, 3.8, dx: -2.5, dz: dz, at: 1.0);
        m.box(PieceKind.parapet, 0.5, 0.7, 3.8, dx: 2.5, dz: dz, at: 1.0);
      }
      m.arcade(3.0, 2.6, 0.8, dz: 5.0, at: 1.0);
      m.box(PieceKind.parapet, 3.4, 1.0, 0.6, dz: 5.0, ridge: true, at: 3.6);
      m.stair(3.2, 1.0, 1.0, dz: 5.9);
      m.box(PieceKind.parapet, 1.4, 0.5, 0.4, dx: -3.4, dz: 4.4, at: 0);
      m.box(PieceKind.parapet, 1.4, 0.5, 0.4, dx: 3.4, dz: 4.4, at: 0);
      m.tree(1.3, 2.6, dx: -4.2, dz: 2.4);
      m.tree(1.3, 2.4, dx: 4.2, dz: 2.4);
      m.field(3.4, 1.6, dz: -5.6);
    },
    scale: 0.65,
  ),

  Landmark(
    'teatro',
    'Corral de misterios',
    24,
    2,
    'Un patio con galerías y un tablado al fondo. Una tarde al año el pueblo se cuenta a sí mismo.',
    (m) {
      // Un corral de comedias: patio descubierto, galerías de madera en tres
      // lados y el tablado al fondo, bajo cubierta.
      m.box(PieceKind.plinth, 8.0, 7.0, 0.3, at: 0);
      m.arcade(7.6, 1.6, 1.0, dz: -2.9, at: 0.3);
      m.arcade(7.6, 1.5, 1.0, dz: -2.9, at: 1.9);
      m.arcade(5.6, 1.6, 1.0, dx: -3.4, along: false, at: 0.3);
      m.arcade(5.6, 1.5, 1.0, dx: -3.4, along: false, at: 1.9);
      m.arcade(5.6, 1.6, 1.0, dx: 3.4, along: false, at: 0.3);
      m.arcade(5.6, 1.5, 1.0, dx: 3.4, along: false, at: 1.9);
      m.roof(7.9, 1.3, 0.6, dz: -2.9, at: 3.4);
      m.roof(1.3, 5.9, 0.6, dx: -3.4, along: false, at: 3.4);
      m.roof(1.3, 5.9, 0.6, dx: 3.4, along: false, at: 3.4);
      m.box(PieceKind.plinth, 4.6, 2.0, 0.85, dz: 2.6, at: 0.3);
      m.box(PieceKind.floor, 4.2, 0.5, 2.6, dz: 3.4, at: 1.15);
      m.box(PieceKind.parapet, 0.42, 1.9, 2.6, dx: -2.0, dz: 2.6, at: 1.15);
      m.box(PieceKind.parapet, 0.42, 1.9, 2.6, dx: 2.0, dz: 2.6, at: 1.15);
      m.roof(4.9, 2.4, 0.9, dz: 2.8, at: 3.75);
      m.banner(1.3, dx: -2.0, dz: 2.6, at: 3.75);
      m.banner(1.3, dx: 2.0, dz: 2.6, at: 3.75);
      m.field(6.4, 4.4, dz: -0.4);
      m.box(PieceKind.parapet, 3.0, 0.45, 0.4, dz: -3.9, at: 0);
      m.stair(2.0, 0.3, 0.8, dz: -4.2);
      m.tree(1.3, 2.4, dx: -4.4, dz: 3.4);
      m.tree(1.2, 2.2, dx: 4.4, dz: 3.4);
      m.post(0.22, 2.0, dx: -3.9, dz: -3.6, at: 0);
      m.banner(1.1, dx: -3.9, dz: -3.6, at: 2.0);
    },
    scale: 0.65,
  ),

  Landmark(
    'coso',
    'Coso y graderío',
    28,
    2,
    'Dos pisos de arcos en redondo y arena en medio. El pueblo entero cabe sentado.',
    (m) {
      // **La obra más grande que sabe hacer el pueblo**: un anillo cerrado de
      // arcos, dos pisos, con la arena dentro. Cuatro lienzos de arcada por
      // planta, que en esta geometría es lo que se lee como un anfiteatro.
      m.field(7.6, 7.6);
      for (final lado in const [-1, 1]) {
        m.arcade(10.0, 2.4, 1.3, dz: lado * 4.4, at: 0);
        m.arcade(10.0, 2.2, 1.3, dz: lado * 4.4, at: 2.4);
        m.arcade(8.0, 2.4, 1.3, dx: lado * 4.4, along: false, at: 0);
        m.arcade(8.0, 2.2, 1.3, dx: lado * 4.4, along: false, at: 2.4);
      }
      m.box(PieceKind.parapet, 10.4, 1.5, 0.5, dz: -4.4, ridge: true, at: 4.6);
      m.box(PieceKind.parapet, 10.4, 1.5, 0.5, dz: 4.4, ridge: true, at: 4.6);
      m.box(PieceKind.parapet, 1.5, 8.4, 0.5, dx: -4.4, ridge: true, at: 4.6);
      m.box(PieceKind.parapet, 1.5, 8.4, 0.5, dx: 4.4, ridge: true, at: 4.6);
      for (final c in const [
        (-4.4, -4.4),
        (4.4, -4.4),
        (-4.4, 4.4),
        (4.4, 4.4),
      ]) {
        m.box(PieceKind.floor, 1.7, 1.7, 5.1, dx: c.$1, dz: c.$2, at: 0);
        m.banner(1.5, dx: c.$1, dz: c.$2, at: 5.1);
      }
      m.box(PieceKind.plinth, 2.6, 1.6, 0.35, dz: 5.4, at: 0);
      m.stair(2.2, 0.35, 0.9, dz: 5.9);
      m.arcade(2.4, 2.6, 1.3, dz: 4.4, at: 0);
      m.box(PieceKind.parapet, 3.0, 1.6, 0.5, dz: 4.4, ridge: true, at: 2.6);
      m.box(PieceKind.parapet, 3.4, 0.5, 0.6, dz: -5.4, at: 0);
      m.tree(1.3, 2.4, dx: -5.5, dz: -5.0);
      m.tree(1.2, 2.2, dx: 5.5, dz: -5.0);
    },
    scale: 0.65,
  ),

  Landmark(
    'jardin',
    'Jardín del palacio',
    26,
    2,
    'Cuadros de boj, un estanque y un templete al fondo. Un sitio que no sirve para nada y hace falta.',
    (m) {
      // Todo el hito es suelo: parterres, agua y setos, con un templete
      // pequeño al fondo. Es la única obra del catálogo que casi no sube.
      m.box(PieceKind.parapet, 12.0, 0.36, 0.85, dz: -5.6, at: 0);
      m.box(PieceKind.parapet, 12.0, 0.36, 0.85, dz: 5.6, at: 0);
      m.box(PieceKind.parapet, 0.36, 11.2, 0.85, dx: -5.8, at: 0);
      m.box(PieceKind.parapet, 0.36, 11.2, 0.85, dx: 5.8, at: 0);
      for (final c in const [
        (-2.9, -2.9),
        (2.9, -2.9),
        (-2.9, 2.9),
        (2.9, 2.9),
      ]) {
        m.field(4.0, 4.0, dx: c.$1, dz: c.$2);
        m.palisade(3.9, 0.5, dx: c.$1, dz: c.$2 - 2.0);
      }
      m.water(2.6, 2.6);
      m.box(PieceKind.plinth, 3.2, 3.2, 0.24, at: 0);
      m.box(PieceKind.plinth, 1.0, 1.0, 0.3, at: 0);
      m.box(PieceKind.parapet, 0.8, 0.8, 0.5, ridge: true, at: 0.3);
      m.box(PieceKind.plinth, 3.6, 3.6, 0.45, dz: -4.0, at: 0);
      m.arcade(3.0, 2.2, 3.0, dz: -4.0, at: 0.45);
      m.box(PieceKind.parapet, 3.4, 3.4, 0.4, dz: -4.0, ridge: true, at: 2.65);
      m.dome(3.2, 3.2, 1.5, dz: -4.0, at: 3.05);
      m.stair(2.4, 0.45, 0.9, dz: -2.0);
      m.tree(1.4, 2.8, dx: -5.0, dz: -5.0);
      m.tree(1.4, 2.6, dx: 5.0, dz: -5.0);
      m.tree(1.4, 2.8, dx: -5.0, dz: 5.0);
      m.tree(1.4, 2.6, dx: 5.0, dz: 5.0);
      m.arcade(2.2, 1.9, 0.5, dz: 5.6, at: 0);
      m.box(PieceKind.parapet, 2.6, 0.9, 0.45, dz: 5.6, ridge: true, at: 1.9);
    },
    scale: 0.65,
  ),

  Landmark(
    'arcoVilla',
    'Arco de la villa',
    19,
    2,
    'Un arco que no cierra nada y no defiende nada. Se levanta sólo para decir que se pudo.',
    (m) {
      // **Lo que hace que un arco se lea como un arco es el agujero.** Dos
      // pilares separados de verdad, con aire entre ellos, y el arco cruzando
      // ese aire: si se rellena el hueco con obra, por mucha arcada que se le
      // dibuje encima lo que se ve es un bloque.
      m.box(PieceKind.plinth, 7.6, 3.6, 0.45, at: 0);
      m.box(PieceKind.plinth, 2.4, 3.0, 0.4, dx: -2.5, at: 0.45);
      m.box(PieceKind.plinth, 2.4, 3.0, 0.4, dx: 2.5, at: 0.45);
      m.box(PieceKind.parapet, 2.0, 2.7, 3.9, dx: -2.5, at: 0.85);
      m.box(PieceKind.parapet, 2.0, 2.7, 3.9, dx: 2.5, at: 0.85);
      m.arcade(3.4, 1.3, 2.7, at: 3.45);
      m.box(PieceKind.parapet, 7.2, 3.1, 0.55, ridge: true, at: 4.75);
      m.box(PieceKind.parapet, 6.6, 2.8, 0.85, ridge: true, at: 5.3);
      m.box(PieceKind.parapet, 3.6, 2.4, 0.95, ridge: true, at: 6.15);
      m.post(0.46, 3.0, dx: -3.3, dz: 1.5, at: 0.85);
      m.post(0.46, 3.0, dx: -1.7, dz: 1.5, at: 0.85);
      m.post(0.46, 3.0, dx: 1.7, dz: 1.5, at: 0.85);
      m.post(0.46, 3.0, dx: 3.3, dz: 1.5, at: 0.85);
      m.banner(1.5, dx: -2.5, dz: 0.9, at: 6.15);
      m.banner(1.5, dx: 2.5, dz: 0.9, at: 6.15);
      m.stair(3.2, 0.45, 0.95, dz: 2.25);
      m.box(PieceKind.plinth, 3.0, 2.0, 0.2, dz: -2.4, at: 0);
      m.tree(1.3, 2.4, dx: -4.8, dz: 2.0);
      m.tree(1.2, 2.2, dx: 4.8, dz: 2.0);
    },
    scale: 0.65,
    rigid: true,
  ),

  Landmark(
    'panteon',
    'Panteón de los fundadores',
    18,
    2,
    'Los nombres de los que empezaron esto, en piedra y bajo una cúpula. Ya hay a quién recordar.',
    (m) {
      // Una rotonda: podio, escalinata, pórtico de columnas y cúpula. Es la
      // única obra del catálogo que es redonda por fuera y por dentro.
      m.box(PieceKind.plinth, 6.2, 6.2, 0.45, at: 0);
      m.box(PieceKind.plinth, 5.4, 5.4, 0.4, at: 0.45);
      m.box(PieceKind.floor, 4.4, 4.4, 2.6, at: 0.85);
      m.box(PieceKind.parapet, 4.9, 4.9, 0.5, ridge: true, at: 3.45);
      m.dome(4.4, 4.4, 2.2, at: 3.95);
      m.arcade(3.4, 2.6, 1.1, dz: 2.6, at: 0.85);
      m.box(PieceKind.parapet, 3.7, 1.35, 0.55, ridge: true, at: 3.45);
      m.spire(3.4, 1.4, 1.0, dz: 2.6, at: 4.0);
      m.post(0.42, 2.6, dx: -1.35, dz: 3.05, at: 0.85);
      m.post(0.42, 2.6, dx: -0.45, dz: 3.05, at: 0.85);
      m.post(0.42, 2.6, dx: 0.45, dz: 3.05, at: 0.85);
      m.post(0.42, 2.6, dx: 1.35, dz: 3.05, at: 0.85);
      m.stair(3.6, 0.85, 1.2, dz: 4.2);
      m.tree(1.3, 2.6, dx: -3.6, dz: 3.2);
      m.tree(1.3, 2.4, dx: 3.6, dz: 3.2);
      m.box(PieceKind.parapet, 1.4, 0.45, 0.35, dx: -3.4, dz: 1.4, at: 0);
      m.box(PieceKind.parapet, 1.4, 0.45, 0.35, dx: 3.4, dz: 1.4, at: 0);
      m.palisade(5.6, 0.7, dz: -3.4);
    },
    scale: 0.65,
    rigid: true,
  ),
];
