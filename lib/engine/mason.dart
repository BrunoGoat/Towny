/// What a piece of a building is doing, which is all the renderer needs to know
/// to draw it.
///
/// This is the whole vocabulary the town is built out of. A landmark is not a
/// hand-modelled object: it is a short recipe written in these words, so a
/// hundred different landmarks cost a hundred short recipes instead of a
/// hundred models.
enum PieceKind {
  plinth,
  floor,
  roof,

  /// The same roof, in straw. Not a colour: a thatched roof is fat at the
  /// eaves and rounded at the ridge, and no amount of paint makes a tiled one
  /// look like it. Which of the two a building gets is decided when the town
  /// is laid out, from the character's mix, and never rolled again.
  thatch,
  chimney,
  dormer,
  porch,
  parapet,
  spire,

  /// Ploughed rows: the crops around a mill, a vineyard, a monastery garden.
  field,

  /// Standing water: a millrace, a moat, a washing place, salt pans.
  water,

  /// A vertical wheel with paddles, turned by the water beside it.
  wheel,

  /// The four sails of a windmill.
  sail,

  /// A rounded cap: a bread oven, a kiln, a baptistery, a mausoleum.
  dome,

  /// One tree: an orchard, a churchyard yew, a palace garden.
  tree,

  /// A run of stakes: a stockade, a pen, a vine trellis.
  palisade,

  /// A pole with a banner on it.
  banner,

  /// A run of arches: a cloister, a bridge, an aqueduct, a market hall.
  arcade,

  /// A flight of steps.
  stair,

  /// Un toldo de tela a rayas, de la pared hacia la calle (+z), bajando.
  awning,

  /// Un mostrador de madera con panes encima, de cara a la calle.
  counter,

  /// Un cartel colgado de un brazo de hierro que sale de la pared hacia la
  /// calle, con el dibujo de su oficio ([Spec.motif]).
  sign,

  /// Un tonel de madera, o una tinaja de barro o de aceite ([Spec.motif]).
  barrel,

  /// Un almiar: paja amontonada alrededor de un palo.
  haystack,

  /// Un tendedero con telas teñidas colgando.
  cloth,

  /// Una muela de piedra de canto sobre su pila, con el palo que la gira.
  millstone,

  /// Gallinas sueltas.
  hens,

  /// Una colmena de paja trenzada, en su banquito, con la piquera oscura.
  hive,

  /// Un piso de entramado: pared encalada con las vigas de madera oscura a la
  /// vista —soleras, esquineros, pies derechos y riostras— y sus ventanas.
  timber,

  /// Una planta de piedra clara, con ventanas: la de abajo de una casa de
  /// entramado, de otro material que la cal de arriba pero sin saltar a la
  /// vista.
  stonewall,

  /// The same stone, blind: a cellar, a store, a brewhouse, no windows.
  cellar,

  /// La caldera de cobre de cocer la cerveza, con su campana y el caño.
  kettle,

  /// Una pila de sacos de grano.
  sacks,

  /// Una mesa de taberna con sus dos bancos y las jarras encima.
  table,
}

/// One piece of a building, before it is given to an achievement.
class Spec {
  Spec({
    required this.kind,
    required this.cx,
    required this.cz,
    required this.w,
    required this.d,
    required this.y0,
    required this.y1,
    required this.alongX,
    this.motif = Motif.none,
    this.fixed = false,
  });

  /// Si es un objeto que mide lo mismo en todos los pueblos: ver
  /// [Mason.size].
  final bool fixed;
  final PieceKind kind;
  final double cx, cz, w, d, y0, y1;
  final bool alongX;

  /// Lo que lleva pintado o de qué es, en las piezas que lo dicen: el
  /// dibujo de un cartel, el barro o la madera de un tonel.
  final Motif motif;
}

/// El dibujo de un cartel de oficio, o el material de lo que lo tiene.
enum Motif {
  none,
  bread,
  horseshoe,
  coin,
  jug,
  mortar,
  quill,
  book,
  bed,
  cloth,
  grapes,
  clay,
  oil,
}

/// The hand that lays the pieces.
///
/// Every call adds exactly one piece, which is exactly one achievement, so the
/// cost of a landmark is simply how many times the mason is asked to do
/// something. Height accumulates as it goes, the way a real course of masonry
/// does; anything that belongs at a height of its own says so with `at`, and
/// anything that sits beside rather than on top says so with `ridge`.
class Mason {
  Mason(
    this.cx,
    this.cz,
    this.seed,
    this.alongX, {
    this.spread = 1.0,
    this.storey = 1.0,
    this.pitch = 1.0,
    this.size = 1.0,
    this.objectSpread = 1.0,
    this.objectStorey = 1.0,
  });

  final double cx, cz;
  final int seed;

  /// Which way the roofs of this building run.
  final bool alongX;

  /// The place this is being built in, as three numbers.
  ///
  /// Every recipe is written in one town's proportions and then stretched into
  /// this one's: wider or narrower on the ground by [spread], taller or lower
  /// by [storey], steeper or flatter in the roof by [pitch]. It happens here,
  /// at the one door every piece goes through, rather than in each recipe —
  /// which is why it also reaches every landmark. A castle in the
  /// Sierra used to be the same castle as a castle on the Costa, down to the
  /// centimetre, and a town whose landmarks are somebody else's landmarks is
  /// not a place.
  ///
  /// The stretch is affine and uniform, so nothing it touches can come apart:
  /// a chimney that met its roof still meets it, and a stair that reached a
  /// door still reaches it.
  final double spread, storey, pitch;

  /// **Lo que no es casa no se estira.** Las paredes, los pisos y los tejados
  /// son lo que hace distinto a cada pueblo, y se estiran con [spread] y
  /// [storey]. Pero una colmena, un cartel, un tonel, un pan o las aspas de
  /// un molino miden lo mismo en todas partes: estirados, en la Sierra salían
  /// colmenas altas como un hombre y en la Costa carteles aplastados. Esas
  /// piezas ([fixedKinds], o las que se piden con `fixed`) van a su sitio
  /// estirado —el cartel sigue en su pared, a su altura— pero con su tamaño
  /// de la receta por [size], que es sólo la escala de la obra.
  final double size;

  /// Las proporciones con que se ven los objetos en todos los pueblos: las de
  /// la Ribera, que es el pueblo de referencia (ver `TownCharacter.reference`).
  /// Así en la Ribera nada cambia, y en los demás los objetos se ven como
  /// allí. Una obra que no toma las proporciones de la comarca (`rigid`) no
  /// las toma tampoco para sus objetos: van a uno.
  final double objectSpread, objectStorey;

  /// Lo que mide un objeto de ancho y de alto por cada unidad de la receta.
  double get _ow => size * objectSpread;

  /// Lo que mide de alto un objeto por cada unidad de la receta, para colgar
  /// uno a una altura de la casa: ver el toldo de la panadería.
  double get objectHeight => _oh;
  double get _oh => size * objectStorey;

  /// Las piezas que son objetos y no arquitectura: miden siempre lo mismo.
  static const Set<PieceKind> fixedKinds = {
    PieceKind.awning,
    PieceKind.counter,
    PieceKind.sign,
    PieceKind.barrel,
    PieceKind.haystack,
    PieceKind.cloth,
    PieceKind.millstone,
    PieceKind.hens,
    PieceKind.hive,
    PieceKind.kettle,
    PieceKind.sacks,
    PieceKind.table,
    PieceKind.banner,
    PieceKind.wheel,
    PieceKind.sail,
    PieceKind.tree,
  };

  /// Objetos que van de punta a punta de una fachada: de ancho, el de ella.
  static const Set<PieceKind> _deFachada = {
    PieceKind.awning,
    PieceKind.counter,
  };

  final List<Spec> out = [];

  /// Dónde está el conjunto fijo que se está armando: ver [anchor].
  (double, double)? _ancla;

  /// Lo que sigue con `fixed`, hasta [unanchor], es un conjunto —un horno con
  /// su boca y su tiro— cuyo centro está en ([dx], [dz]) de la receta.
  void anchor(double dx, double dz) => _ancla = (dx, dz);
  void unanchor() => _ancla = null;

  /// Every roof laid so far, so a dormer knows where its tiles are.
  final List<_Roof> _roofs = [];

  /// The top of what has been laid so far.
  double y = 0;

  int get count => out.length;

  /// The one door every piece goes through, and so the one place the town's
  /// proportions are applied. The mason works in a single set of units and
  /// this turns them into this town's.
  void _add(
    PieceKind kind,
    double dx,
    double dz,
    double w,
    double d,
    double y0,
    double y1, {
    bool? along,
    Motif motif = Motif.none,
    bool fixed = false,
  }) {
    // Un objeto: a su sitio estirado, con su tamaño. Uno «fijo» del todo
    // —un horno, un tonel sobre otro— tampoco estira la altura a la que
    // empieza, porque se apila sobre otros objetos y no sobre la casa.
    final objeto = fixed || fixedKinds.contains(kind);
    final valla = kind == PieceKind.palisade;
    // Las partes de un conjunto fijo —el horno y su boca— guardan entre sí
    // las distancias de la receta: sólo el conjunto va a su sitio estirado.
    final ancla = fixed ? _ancla : null;
    final px = ancla == null
        ? dx * spread
        : ancla.$1 * spread + (dx - ancla.$1) * _ow;
    final pz = ancla == null
        ? dz * spread
        : ancla.$2 * spread + (dz - ancla.$2) * _ow;
    final base = fixed ? y0 * _oh : y0 * storey;
    final ya = objeto || valla ? base : y0 * storey;
    final yb = objeto || valla ? base + (y1 - y0) * _oh : y1 * storey;
    out.add(
      Spec(
        motif: motif,
        kind: kind,
        cx: cx + px,
        cz: cz + pz,
        // El toldo y el mostrador, de ancho el de la fachada en la que van.
        w: objeto && !_deFachada.contains(kind) ? w * _ow : w * spread,
        d: objeto ? d * _ow : d * spread,
        y0: ya,
        y1: yb,
        alongX: along ?? alongX,
        fixed: objeto,
      ),
    );
  }

  /// A rectangular mass. Raises the course line unless it is [ridge] work or
  /// pinned to a height of its own with [at].
  void box(
    PieceKind k,
    double w,
    double d,
    double ht, {
    double dx = 0,
    double dz = 0,
    bool ridge = false,
    double? at,
    bool? along,
    Motif motif = Motif.none,
    bool fixed = false,
  }) {
    // A roof is the one thing whose height is not the town's height: how steep
    // this place builds is a fourth number, on top of the other three.
    if (k == PieceKind.roof || k == PieceKind.thatch) ht *= pitch;
    final base = at ?? y;
    _add(
      k,
      dx,
      dz,
      w,
      d,
      base,
      base + ht,
      along: along,
      motif: motif,
      fixed: fixed,
    );
    if (k == PieceKind.roof || k == PieceKind.thatch) {
      _roofs.add(_Roof(dx, dz, w, d, base, ht, along ?? alongX));
    }
    if (!ridge && at == null) y += ht;
  }

  /// A storey with windows in it.
  void floor(double w, double d, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.floor, w, d, ht, dx: dx, dz: dz);

  /// Un piso de entramado de madera, con ventanas.
  void timber(double w, double d, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.timber, w, d, ht, dx: dx, dz: dz);

  /// A stone base, wider than what stands on it.
  void plinth(double w, double d, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.plinth, w, d, ht, dx: dx, dz: dz);

  /// A pitched roof. Sits on the course line without raising it, so a chimney
  /// laid afterwards comes up through it.
  void roof(
    double w,
    double d,
    double rise, {
    double dx = 0,
    double dz = 0,
    bool? along,
    double? at,
  }) => box(
    PieceKind.roof,
    w,
    d,
    rise,
    dx: dx,
    dz: dz,
    ridge: true,
    at: at,
    along: along,
  );

  void spire(
    double w,
    double d,
    double rise, {
    double dx = 0,
    double dz = 0,
    double? at,
  }) => box(PieceKind.spire, w, d, rise, dx: dx, dz: dz, at: at);

  void dome(
    double w,
    double d,
    double rise, {
    double dx = 0,
    double dz = 0,
    double? at,
  }) => box(PieceKind.dome, w, d, rise, dx: dx, dz: dz, at: at);

  void parapet(double w, double d, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.parapet, w, d, ht, dx: dx, dz: dz);

  /// A chimney, [ht] tall over the course line on a roof of ordinary pitch.
  ///
  /// On a steeper roof it grows by what the steeper slope adds over its own
  /// spot: written for a roof of pitch one, a chimney on the steep thatch of
  /// the oak country came up a hand's breadth above the straw, or not at all.
  void chimney(double side, double ht, {double dx = 0, double dz = 0}) {
    if (pitch > 1) {
      final tejas = _tilesAt(dx, dz) - y;
      if (tejas > 0) ht += tejas * (1 - 1 / pitch);
    }
    box(PieceKind.chimney, side, side, ht, dx: dx, dz: dz, ridge: true);
  }

  /// A dormer: a little window standing out of the slope of a roof.
  ///
  /// [dz] is down the slope and [dx] along the ridge, whichever way round this
  /// building's roof happens to run — the mason knows which way that is, and a
  /// recipe should not have to. Written straight into world axes a dormer half
  /// the time lands on the ridge itself, standing clear of the roof like a box
  /// somebody left on top of it.
  ///
  /// It is set on the tiles under its *lower* edge, because that is where a
  /// dormer's front stands; the slope rises across the rest of its footprint
  /// and buries it. Set on the tiles under its middle instead, the downhill
  /// half of it climbs out of the roof and what you see is a crate half sunk
  /// in the tiles rather than a window in them.
  void dormer(double w, double ht, {double dx = 0, double dz = 0, double? at}) {
    // On a steep roof the slope climbs faster across the dormer's depth and
    // buries more of it: taller, so its little gable still stands clear.
    if (pitch > 1) ht *= 1 + (pitch - 1) * 0.6;
    final deep = w * 0.55;
    final ox = alongX ? dx : dz;
    final oz = alongX ? dz : dx;
    final away = dz < 0 ? -1.0 : 1.0;
    final low = alongX
        ? _tilesAt(ox, oz + away * deep / 2)
        : _tilesAt(ox + away * deep / 2, oz);
    box(
      PieceKind.dormer,
      alongX ? w : deep,
      alongX ? deep : w,
      ht,
      dx: ox,
      dz: oz,
      ridge: true,
      // Hundida un poco en las tejas, menos cuanto más empinado: en un techo
      // de paja muy inclinado la paja tapaba toda su pared y quedaba sólo el
      // triángulo de arriba asomando.
      at: at ?? low - ht * (pitch > 1 ? 0.22 - 0.30 * (pitch - 1) : 0.22),
    );
  }

  /// How high the tiles are over a spot, or the course line where no roof
  /// covers it.
  double _tilesAt(double dx, double dz) {
    var top = y;
    for (final r in _roofs) {
      final s = r.surfaceAt(dx, dz);
      if (s != null && s > top) top = s;
    }
    return top;
  }

  // ------------------------------------------------------------- the ground

  /// Ploughed rows. Always on the ground, always beside the building.
  void field(double w, double d, {double dx = 0, double dz = 0, bool? along}) =>
      _add(PieceKind.field, dx, dz, w, d, 0, 0.10, along: along);

  /// Standing water, sunk a little into the ground.
  void water(double w, double d, {double dx = 0, double dz = 0}) =>
      _add(PieceKind.water, dx, dz, w, d, -0.06, 0.02);

  /// One tree, or a close clump read as one.
  void tree(double spread, double ht, {double dx = 0, double dz = 0}) =>
      _add(PieceKind.tree, dx, dz, spread, spread, 0, ht);

  /// A run of stakes along its longer side.
  void palisade(
    double len,
    double ht, {
    double dx = 0,
    double dz = 0,
    bool along = true,
  }) => _add(
    PieceKind.palisade,
    dx,
    dz,
    along ? len : 0.22,
    along ? 0.22 : len,
    0,
    ht,
    along: along,
  );

  /// A pole with a banner on it.
  void banner(double ht, {double dx = 0, double dz = 0, double? at}) =>
      _add(PieceKind.banner, dx, dz, 0.5, 0.5, at ?? 0, (at ?? 0) + ht);

  /// A run of arches carrying whatever is above them.
  void arcade(
    double len,
    double ht,
    double depth, {
    double dx = 0,
    double dz = 0,
    bool? along,
    double? at,
    bool rise = false,
    bool fixed = false,
  }) {
    final base = at ?? y;
    final a = along ?? alongX;
    _add(
      PieceKind.arcade,
      dx,
      dz,
      a ? len : depth,
      a ? depth : len,
      base,
      base + ht,
      along: a,
      fixed: fixed,
    );
    if (rise && at == null) y += ht;
  }

  /// A flight of steps climbing towards the centre of the building.
  void stair(
    double w,
    double rise,
    double run, {
    double dx = 0,
    double dz = 0,
    bool? along,
    double? at,
  }) => _add(
    PieceKind.stair,
    dx,
    dz,
    w,
    run,
    at ?? 0,
    (at ?? 0) + rise,
    along: along,
  );

  /// A water wheel, turning in the plane across its short side.
  void wheel(double diameter, {double dx = 0, double dz = 0, bool? along}) =>
      _add(
        PieceKind.wheel,
        dx,
        dz,
        diameter,
        diameter,
        0.0,
        diameter,
        along: along,
      );

  /// The sails of a windmill, on the face of whatever they are pinned to.
  void sails(
    double diameter, {
    double dx = 0,
    double dz = 0,
    required double at,
  }) {
    // El eje, a la altura estirada de la torre; las aspas, de su tamaño.
    final y0 = at - diameter * _oh / (2 * storey);
    _add(PieceKind.sail, dx, dz, diameter, diameter, y0, y0 + diameter);
  }

  /// A single upright: the leg of a well roof, a gallows, the end of a
  /// trellis.
  void post(
    double side,
    double ht, {
    double dx = 0,
    double dz = 0,
    double at = 0,
  }) => box(
    PieceKind.parapet,
    side,
    side,
    ht,
    dx: dx,
    dz: dz,
    ridge: true,
    at: at,
  );

  /// A horizontal member resting on posts. Without [at] it rests on the course
  /// line, which is where the thing it was laid after left off.
  void beam(
    double w,
    double d,
    double ht, {
    double dx = 0,
    double dz = 0,
    double? at,
  }) => box(
    PieceKind.parapet,
    w,
    d,
    ht,
    dx: dx,
    dz: dz,
    ridge: true,
    at: at ?? y,
  );

  // --------------------------------------------------------------- shortcuts

  /// El cartel de un oficio, colgado de la fachada que da a la calle en
  /// [front] (la z de la cara de la pared), con su dibujo.
  void sign(
    Motif motif, {
    double dx = 0,
    required double front,
    double at = 1,
  }) => box(
    PieceKind.sign,
    0.1,
    0.7,
    0.42,
    dx: dx,
    dz: front + 0.2 * _ow / spread,
    at: at,
    ridge: true,
    motif: motif,
  );

  /// Un tonel —o una tinaja, con [motif] de barro o de aceite— en el suelo.
  void barrel(
    double side,
    double ht, {
    double dx = 0,
    double dz = 0,
    double at = 0,
    Motif motif = Motif.none,
    bool lying = false,
  }) => box(
    PieceKind.barrel,
    side,
    side,
    ht,
    dx: dx,
    dz: dz,
    at: at,
    ridge: true,
    motif: motif,
    // Acostado, de punta a punta a lo ancho.
    along: lying ? false : null,
    // Sobre el suelo o sobre otro tonel: también su altura es la suya.
    fixed: true,
  );

  /// Un almiar.
  void haystack(double side, double ht, {double dx = 0, double dz = 0}) => box(
    PieceKind.haystack,
    side,
    side,
    ht,
    dx: dx,
    dz: dz,
    at: 0,
    ridge: true,
  );

  /// Un tendedero con telas, de [len] de largo.
  void cloths(
    double len,
    double ht, {
    double dx = 0,
    double dz = 0,
    bool along = true,
  }) => box(
    PieceKind.cloth,
    along ? len : 0.2,
    along ? 0.2 : len,
    ht,
    dx: dx,
    dz: dz,
    at: 0,
    ridge: true,
    along: along,
  );

  /// Una muela de piedra sobre su pila.
  void millstone(double side, double ht, {double dx = 0, double dz = 0}) => box(
    PieceKind.millstone,
    side,
    side * 0.7,
    ht,
    dx: dx,
    dz: dz,
    at: 0,
    ridge: true,
  );

  /// Una colmena de paja.
  void hive(double side, double ht, {double dx = 0, double dz = 0}) =>
      box(PieceKind.hive, side, side, ht, dx: dx, dz: dz, at: 0, ridge: true);

  /// Gallinas sueltas en un rectángulo.
  void hens(double w, double d, {double dx = 0, double dz = 0}) =>
      box(PieceKind.hens, w, d, 0.3, dx: dx, dz: dz, at: 0, ridge: true);

  /// Un toldo a rayas que sale de la fachada en [front] hacia la calle.
  void awning(
    double w,
    double reach, {
    double dx = 0,
    required double front,
    required double at,
    double drop = 0.3,
  }) => box(
    PieceKind.awning,
    w,
    reach + 0.15,
    drop,
    dx: dx,
    dz: front + (reach - 0.15) / 2 * _ow / spread,
    at: at,
    ridge: true,
  );

  /// Un mostrador con lo que se vende encima, delante de la fachada.
  void counter(
    double w, {
    double dx = 0,
    required double front,
    double at = 0,
  }) => box(
    PieceKind.counter,
    w,
    0.32,
    0.46,
    dx: dx,
    dz: front + 0.16 * _ow / spread,
    at: at,
    ridge: true,
  );

  /// A shaft of [storeys] storeys. One piece each, so the cost is honest.
  void shaft(double side, int storeys, double storeyH, {double taper = 0}) {
    for (var i = 0; i < storeys; i++) {
      floor(side - taper * i, side - taper * i, storeyH);
    }
  }

  /// A small building standing on the ground beside the main one: the miller's
  /// cottage, the lodge at the gate, the bakehouse behind the inn.
  ///
  /// It never touches the course line, in either direction. Written as an
  /// ordinary [floor] and [roof] with an offset it would inherit whatever
  /// height the main mass had reached, which is how a cottage ends up perched
  /// on top of a bell tower.
  void outbuilding(
    double w,
    double d,
    double ht,
    double rise, {
    double dx = 0,
    double dz = 0,
    bool? along,
  }) {
    box(PieceKind.floor, w, d, ht, dx: dx, dz: dz, ridge: true, at: 0);
    box(
      PieceKind.roof,
      w + 0.25,
      d + 0.25,
      rise,
      dx: dx,
      dz: dz,
      ridge: true,
      at: ht,
      along: along,
    );
  }

  /// A long low body: the nave of a church, the hall of a market.
  void hall(
    double w,
    double d,
    double ht,
    double rise, {
    double dx = 0,
    double dz = 0,
    bool? along,
  }) {
    floor(w, d, ht, dx: dx, dz: dz);
    roof(w + 0.2, d + 0.2, rise, dx: dx, dz: dz, along: along);
  }

  /// Pads out or trims down to exactly [want] pieces.
  ///
  /// Padding repeats the last piece, which lands in the same place and so reads
  /// as the mason taking one more day over the same detail. Trimming is what
  /// happens while the landmark is still going up.
  List<Spec> finish(int want) {
    while (out.length < want) {
      out.add(out.last);
    }
    return out.length > want ? out.sublist(0, want) : out;
  }
}

/// A roof that has been laid, and how high its tiles are over any spot.
class _Roof {
  const _Roof(
    this.dx,
    this.dz,
    this.w,
    this.d,
    this.base,
    this.rise,
    this.alongX,
  );
  final double dx, dz, w, d, base, rise;
  final bool alongX;

  /// The height of the tiles above a point, or null where this roof does not
  /// reach.
  double? surfaceAt(double x, double z) {
    final hw = w / 2, hd = d / 2;
    if (hw <= 0 || hd <= 0) return null;
    if ((x - dx).abs() > hw || (z - dz).abs() > hd) return null;
    // Highest at the ridge, down to nothing at the eaves.
    final across = alongX ? (z - dz).abs() / hd : (x - dx).abs() / hw;
    return base + rise * (1 - across);
  }
}
