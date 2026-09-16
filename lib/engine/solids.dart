import 'dart:math' as math;

import '../core/rng.dart';
import '../core/math3.dart';
import '../data/character.dart';
import 'solid.dart';
import 'town.dart';

/// Turns a piece of a building into closed geometry.
///
/// This file knows nothing about cameras, palettes or canvases. It says where
/// the stone is; the renderer says what it looks like at six in the evening in
/// November. Keeping the two apart is what makes "is this solid closed?" a
/// question a test can answer, and a closed solid is the reason a face can
/// never go missing at some angle: there is no such thing as the inside of a
/// house here, so every face has a twin looking the other way, and exactly one
/// of the two is turned towards you.
List<Solid> solidsOf(
  TownPiece piece, {
  TownCharacter? place,
  double lift = 0,
  double squash = 1.0,
}) {
  final y0 = piece.y0 + lift;
  final y1 = y0 + (piece.y1 - piece.y0) * squash;
  final x0 = piece.x0, x1 = piece.x1, z0 = piece.z0, z1 = piece.z1;
  final i = piece.index;
  final s = piece.seed;

  switch (piece.kind) {
    case PieceKind.floor:
      final faces = boxFaces(x0, y0, z0, x1, y1, z1, Surface.wall);
      _hangWindows(faces, y0, y1, place);
      return [Solid(i, faces)];

    case PieceKind.porch:
      return [
        Solid(i, boxFaces(x0, y0, z0, x1, y1, z1, Surface.wall, ao: 0.9)),
      ];

    case PieceKind.plinth:
      return [
        Solid(i, boxFaces(x0, y0, z0, x1, y1, z1, Surface.stone, ao: 0.86)),
      ];

    case PieceKind.parapet:
      return [
        Solid(i, boxFaces(x0, y0, z0, x1, y1, z1, Surface.stone, ao: 0.95)),
      ];

    case PieceKind.chimney:
      return [
        Solid(i, boxFaces(x0, y0, z0, x1, y1, z1, Surface.brick, ao: 0.92)),
      ];

    case PieceKind.roof:
      return [Solid(i, gableFaces(x0, y0, z0, x1, y1, z1, piece.alongX))];

    case PieceKind.thatch:
      return [Solid(i, thatchFaces(x0, y0, z0, x1, y1, z1, piece.alongX))];

    case PieceKind.spire:
      return [Solid(i, spireFaces(x0, y0, z0, x1, y1, z1))];

    case PieceKind.dome:
      return [
        Solid(i, domeFaces(piece.cx, piece.cz, piece.w, piece.d, y0, y1)),
      ];

    case PieceKind.dormer:
      // A window in the roof, not a crate on it: a low limewashed front with a
      // small roof of its own turned across the slope it comes out of.
      final eaves = y0 + (y1 - y0) * 0.58;
      return [
        Solid(i, boxFaces(x0, y0, z0, x1, eaves, z1, Surface.wall, ao: 0.95)),
        Solid(i, gableFaces(x0, eaves, z0, x1, y1, z1, !piece.alongX)),
      ];

    case PieceKind.stair:
      final out = <Solid>[];
      const steps = 3;
      final rise = (y1 - y0) / steps;
      final run = piece.alongX ? piece.d : piece.w;
      for (var k = 0; k < steps; k++) {
        final shrink = run * (k / steps) * 0.5;
        final w = piece.alongX ? piece.w : piece.w - shrink;
        final d = piece.alongX ? piece.d - shrink : piece.d;
        out.add(
          Solid(
            i,
            boxFaces(
              piece.cx - w / 2,
              y0 + k * rise,
              piece.cz - d / 2,
              piece.cx + w / 2,
              y0 + (k + 1) * rise,
              piece.cz + d / 2,
              Surface.stone,
              ao: 0.9 + k * 0.04,
            ),
          ),
        );
      }
      return out;

    case PieceKind.arcade:
      return _arcade(piece, y0, y1);

    case PieceKind.tree:
      final ht = y1 - y0;
      final trunk = piece.w * 0.16;
      final cx = piece.cx, cz = piece.cz;
      return [
        Solid(
          i,
          boxFaces(
            cx - trunk / 2,
            y0,
            cz - trunk / 2,
            cx + trunk / 2,
            y0 + ht * 0.42,
            cz + trunk / 2,
            Surface.own,
            ao: 0.85,
            tint: 0xFF6B573F,
          ),
        ),
        Solid(
          i,
          boxFaces(
            cx - piece.w * 0.41,
            y0 + ht * 0.36,
            cz - piece.d * 0.41,
            cx + piece.w * 0.41,
            y0 + ht * 0.74,
            cz + piece.d * 0.41,
            Surface.leaf,
            ao: 0.98,
          ),
        ),
        Solid(
          i,
          boxFaces(
            cx - piece.w * 0.26,
            y0 + ht * 0.70,
            cz - piece.d * 0.26,
            cx + piece.w * 0.26,
            y1,
            cz + piece.d * 0.26,
            Surface.leaf,
            ao: 1.08,
          ),
        ),
      ];

    case PieceKind.palisade:
      final along = piece.alongX;
      final len = along ? piece.w : piece.d;
      final n = clampD(len / 0.34, 2, 16).round();
      final step = len / n;
      final start = (along ? x0 : z0) + step / 2;
      final out = <Solid>[];
      for (var k = 0; k < n; k++) {
        final c = start + k * step;
        final top = y1 - hash01(s, 12, k) * (y1 - y0) * 0.18;
        final w = along ? step * 0.6 : piece.w;
        final d = along ? piece.d : step * 0.6;
        final ccx = along ? c : piece.cx;
        final ccz = along ? piece.cz : c;
        out.add(
          Solid(
            i,
            boxFaces(
              ccx - w / 2,
              y0,
              ccz - d / 2,
              ccx + w / 2,
              top,
              ccz + d / 2,
              Surface.own,
              ao: 0.9,
              tint: 0xFF7A6549,
            ),
          ),
        );
      }
      return out;

    case PieceKind.wheel:
      return _wheel(piece, y0, y1);

    case PieceKind.banner:
      // The pole is masonry's business; the cloth flies, and flying things are
      // drawn after the town is standing.
      return [
        Solid(
          i,
          boxFaces(
            piece.cx - 0.045,
            y0,
            piece.cz - 0.045,
            piece.cx + 0.045,
            y1,
            piece.cz + 0.045,
            Surface.own,
            ao: 0.9,
            tint: 0xFF6B573F,
          ),
        ),
      ];

    case PieceKind.sail:
      final r = (y1 - y0) / 2;
      final cy = y0 + r;
      final cz = piece.cz - 0.16 + 0.06;
      return [
        Solid(
          i,
          boxFaces(
            piece.cx - r * 0.14,
            cy - r * 0.14,
            cz - 0.11,
            piece.cx + r * 0.14,
            cy + r * 0.14,
            cz + 0.11,
            Surface.own,
            ao: 0.88,
            tint: 0xFF5A4835,
          ),
        ),
      ];

    case PieceKind.field:
    case PieceKind.water:
      // Ploughed rows and standing water are sheets lying on the ground that
      // move with the wind. They carry no volume and nothing stands on them.
      return const [];
  }
}

/// True when a piece has something that moves, drawn after the masonry.
/// What a plot has on it that nobody earned.
///
/// A kitchen garden and a tree. Neither is a piece: see `TownCharacter.gardens`
/// for why. Both are built as closed solids rather than as ground sheets,
/// because a sheet on the ground is only ever drawn along the wind's own path
/// and this is furniture, not weather.
///
/// Everything here names its own colour. Town furniture is painted by a
/// simpler road through the renderer than a piece is — one that asks the facet
/// what colour it is instead of asking the house it belongs to — so a facet
/// that does not say comes out the grey of nothing in particular, which is
/// what a vegetable bed and an oak both were until they were looked at.
class Yard {
  const Yard._();

  static const int _bark = 0xFF6B573F;
  static const List<int> _greens = [
    0xFF5E7040,
    0xFF6B7A42,
    0xFF54663C,
    0xFF77854C,
  ];

  /// Three raised beds and a pair of stakes. Read from above — which is how
  /// this town is nearly always read — that is a kitchen garden, and a
  /// ploughed field is not: a field is a shape in the distance, a garden is
  /// beds you could walk between.
  static List<Solid> gardenAt(double cx, double cz, double size, int seed) {
    final out = <Solid>[];
    const rows = 3;
    final wide = size * 0.84, deep = size * 0.84;
    final gap = deep / rows;
    for (var r = 0; r < rows; r++) {
      final z = cz - deep / 2 + gap * (r + 0.5);
      final h = size * (0.16 + hash01(seed, 60 + r) * 0.12);
      final w = wide * (0.74 + hash01(seed, 70 + r) * 0.24);
      out.add(
        Solid(
          -1,
          boxFaces(
            cx - w / 2,
            0,
            z - gap * 0.32,
            cx + w / 2,
            h,
            z + gap * 0.32,
            // Hoja y no «color propio»: así la huerta sigue el calendario
            // del año como cualquier otra hoja del valle, en vez de quedarse
            // verde primavera bajo la nieve.
            Surface.leaf,
            ao: 0.94,
            tint: _greens[(seed + r) & 3],
          ),
        ),
      );
    }
    // Two stakes on the corners: what says somebody keeps this, rather than
    // that the weeds happen to have come up in rows.
    for (var k = 0; k < 2; k++) {
      final x = cx + (k == 0 ? -1 : 1) * wide * 0.5;
      out.add(
        Solid(
          -1,
          boxFaces(
            x - 0.035,
            0,
            cz - deep * 0.5 - 0.035,
            x + 0.035,
            size * (0.38 + hash01(seed, 80 + k) * 0.16),
            cz - deep * 0.5 + 0.035,
            Surface.own,
            ao: 0.88,
            tint: _bark,
          ),
        ),
      );
    }
    return out;
  }

  /// One tree over the plot: a trunk and two boxes of leaves, the same tree a
  /// churchyard yew is, because a tree is a tree.
  static List<Solid> treeAt(double cx, double cz, double size, int seed) {
    final ht = size * (1.6 + hash01(seed, 90) * 0.8);
    final w = size * (0.80 + hash01(seed, 91) * 0.34);
    final trunk = w * 0.16;
    final leaf = _greens[seed & 3];
    return [
      Solid(
        -1,
        boxFaces(
          cx - trunk / 2,
          0,
          cz - trunk / 2,
          cx + trunk / 2,
          ht * 0.44,
          cz + trunk / 2,
          Surface.own,
          ao: 0.85,
          tint: _bark,
        ),
      ),
      Solid(
        -1,
        boxFaces(
          cx - w * 0.41,
          ht * 0.38,
          cz - w * 0.41,
          cx + w * 0.41,
          ht * 0.76,
          cz + w * 0.41,
          Surface.leaf,
          ao: 0.96,
          tint: leaf,
        ),
      ),
      Solid(
        -1,
        boxFaces(
          cx - w * 0.27,
          ht * 0.72,
          cz - w * 0.27,
          cx + w * 0.27,
          ht,
          cz + w * 0.27,
          Surface.leaf,
          ao: 1.0,
          tint: _greens[(seed + 1) & 3],
        ),
      ),
    ];
  }
}

bool hasWeather(PieceKind k) =>
    k == PieceKind.field ||
    k == PieceKind.water ||
    k == PieceKind.sail ||
    k == PieceKind.banner;

// --------------------------------------------------------------- the shapes

/// The six faces of a box, wound counter-clockwise seen from outside.
List<Facet> boxFaces(
  double x0,
  double y0,
  double z0,
  double x1,
  double y1,
  double z1,
  Surface s, {
  double ao = 1.0,
  int? tint,
  double top = 1.0,
}) => [
  Facet(
    [V3(x0, y0, z1), V3(x1, y0, z1), V3(x1, y1, z1), V3(x0, y1, z1)],
    const V3(0, 0, 1),
    s,
    ao: ao,
    tint: tint,
  ),
  Facet(
    [V3(x1, y0, z0), V3(x0, y0, z0), V3(x0, y1, z0), V3(x1, y1, z0)],
    const V3(0, 0, -1),
    s,
    ao: ao,
    tint: tint,
  ),
  Facet(
    [V3(x1, y0, z1), V3(x1, y0, z0), V3(x1, y1, z0), V3(x1, y1, z1)],
    const V3(1, 0, 0),
    s,
    ao: ao * 0.94,
    tint: tint,
  ),
  Facet(
    [V3(x0, y0, z0), V3(x0, y0, z1), V3(x0, y1, z1), V3(x0, y1, z0)],
    const V3(-1, 0, 0),
    s,
    ao: ao * 0.94,
    tint: tint,
  ),
  Facet(
    [V3(x0, y1, z1), V3(x1, y1, z1), V3(x1, y1, z0), V3(x0, y1, z0)],
    const V3(0, 1, 0),
    s,
    ao: ao * top,
    tint: tint,
  ),
  Facet(
    [V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1)],
    const V3(0, -1, 0),
    s,
    ao: ao * 0.55,
    tint: tint,
  ),
];

/// Un prisma recto de base cualquiera, cerrado.
///
/// La base va en sentido antihorario vista desde arriba. Sirve para lo que no
/// es una caja y tampoco un tejado: el enlosado octogonal de la plaza, el pie
/// de un atril. Se cierra con su tapa y su suelo como todo lo demás, que es lo
/// que permite descartar las caras traseras sin mirar nada más.
List<Facet> prismFaces(
  List<(double, double)> base,
  double y0,
  double y1,
  Surface s, {
  double ao = 1.0,
  int? tint,
  double top = 1.0,
}) {
  var mx = 0.0, mz = 0.0;
  for (final (x, z) in base) {
    mx += x;
    mz += z;
  }
  final mid = V3(mx / base.length, (y0 + y1) / 2, mz / base.length);
  final out = <Facet>[
    Facet(
      [for (final (x, z) in base) V3(x, y1, z)],
      const V3(0, 1, 0),
      s,
      ao: ao * top,
      tint: tint,
    ),
    Facet(
      [for (final (x, z) in base.reversed) V3(x, y0, z)],
      const V3(0, -1, 0),
      s,
      ao: ao * 0.55,
      tint: tint,
    ),
  ];
  for (var i = 0; i < base.length; i++) {
    final (x0, z0) = base[i];
    final (x1, z1) = base[(i + 1) % base.length];
    final v = [V3(x0, y0, z0), V3(x1, y0, z1), V3(x1, y1, z1), V3(x0, y1, z0)];
    out.add(
      Facet(
        v,
        Facet.normalOf(v, away: mid),
        s,
        ao: ao * 0.94,
        tint: tint,
      ),
    );
  }
  return out;
}

/// Gira un punto sobre el eje vertical que pasa por `(cx, cz)`.
///
/// El ángulo se mide de manera que una cara que miraba a `+z` acaba mirando a
/// `(sin a, 0, cos a)`, que es como se piensa cuando lo que se quiere es
/// «que mire hacia allá».
V3 turnedAt(V3 v, double cx, double cz, double sinA, double cosA) {
  final dx = v.x - cx, dz = v.z - cz;
  return V3(cx + dx * cosA + dz * sinA, v.y, cz - dx * sinA + dz * cosA);
}

/// Lo mismo, para una lista entera de sólidos y con sus normales.
///
/// **Y sus normales**, que es el punto. Todo lo que hay aguas abajo —qué caras
/// se descartan, por dónde se corta el árbol, en qué orden sale todo— está
/// construido sobre que la normal de una cara diga de verdad dónde está su
/// plano. Girar los vértices y dejar la normal quieta no es un error de
/// sombreado: es una mentira sobre la geometría.
///
/// Se construye el mueble mirando a `+z`, como si estuviera solo en el mundo,
/// y se gira al plantarlo. Escribir cada caja ya torcida habría sido escribir
/// ocho veces la misma trigonometría.
List<Solid> turnedSolids(
  List<Solid> solids,
  double cx,
  double cz,
  double angle,
) {
  final sinA = math.sin(angle), cosA = math.cos(angle);
  if (sinA.abs() < 1e-9 && cosA > 0) return solids;
  Facet turn(Facet f) => Facet(
    [for (final v in f.v) turnedAt(v, cx, cz, sinA, cosA)],
    turnedAt(V3(cx + f.n.x, f.n.y, cz + f.n.z), cx, cz, sinA, cosA) -
        V3(cx, 0, cz),
    f.surface,
    ao: f.ao,
    tint: f.tint,
    decals: f.decals == null ? null : [for (final d in f.decals!) turn(d)],
  );
  return [
    for (final s in solids) Solid(s.piece, [for (final f in s.faces) turn(f)]),
  ];
}

/// Un anillo recto: un brocal, un pretil, cualquier pared que rodee algo.
///
/// Sale en trozos y no de una pieza porque una pieza con un agujero en medio
/// no es un poliedro convexo ni se cierra con una tapa: cada tramo es su
/// propia caja torcida, cerrada por sí misma, y juntos hacen el anillo. Y es
/// lo que hace falta para que se vea lo que hay dentro — un brocal macizo con
/// agua debajo es un brocal macizo, y el agua no existe.
List<Solid> ringSolids(
  double cx,
  double cz,
  double rIn,
  double rOut,
  double y0,
  double y1,
  Surface s, {
  int sides = 8,
  double ao = 1.0,
  int? tint,
}) {
  final out = <Solid>[];
  for (var k = 0; k < sides; k++) {
    final a0 = math.pi / sides + k * 2 * math.pi / sides;
    final a1 = math.pi / sides + (k + 1) * 2 * math.pi / sides;
    (double, double) at(double r, double a) =>
        (cx + r * math.cos(a), cz - r * math.sin(a));
    final (xi0, zi0) = at(rIn, a0);
    final (xi1, zi1) = at(rIn, a1);
    final (xo0, zo0) = at(rOut, a0);
    final (xo1, zo1) = at(rOut, a1);
    out.add(
      Solid(
        -1,
        hexFaces(
          [
            V3(xi0, y0, zi0),
            V3(xo0, y0, zo0),
            V3(xo1, y0, zo1),
            V3(xi1, y0, zi1),
            V3(xi0, y1, zi0),
            V3(xo0, y1, zo0),
            V3(xo1, y1, zo1),
            V3(xi1, y1, zi1),
          ],
          s,
          ao: ao,
          tint: tint,
        ),
      ),
    );
  }
  return out;
}

/// Una caja torcida: ocho esquinas y seis caras, cerrada.
///
/// Los cuatro primeros son la cara de abajo en sentido antihorario vista desde
/// arriba, y los cuatro siguientes la de arriba, cada uno sobre el suyo. Es lo
/// que hace falta para una tabla inclinada —el tablero de un atril, la hoja de
/// un libro abierto—, que no es una caja y no vale fingir que lo es: una
/// normal que no sea perpendicular a su propia cara es una mentira sobre dónde
/// está el plano de la cara, y de eso cuelga todo el orden de pintado.
List<Facet> hexFaces(
  List<V3> c,
  Surface s, {
  double ao = 1.0,
  int? tint,
  double top = 1.0,
}) {
  assert(c.length == 8);
  var mx = 0.0, my = 0.0, mz = 0.0;
  for (final v in c) {
    mx += v.x;
    my += v.y;
    mz += v.z;
  }
  final mid = V3(mx / 8, my / 8, mz / 8);
  Facet side(List<V3> v, double shade) => Facet(
    v,
    Facet.normalOf(v, away: mid),
    s,
    ao: ao * shade,
    tint: tint,
  );
  return [
    side([c[4], c[5], c[6], c[7]], top),
    side([c[3], c[2], c[1], c[0]], 0.55),
    side([c[0], c[1], c[5], c[4]], 0.94),
    side([c[1], c[2], c[6], c[5]], 0.90),
    side([c[2], c[3], c[7], c[6]], 0.94),
    side([c[3], c[0], c[4], c[7]], 0.98),
  ];
}

/// A pitched roof: two slopes, two ends and the floor that closes it.
///
/// The floor is not decoration. Without it a roof is a shell, and a shell
/// cannot be back-face culled — which is exactly how half a roof used to
/// disappear depending on where you stood.
/// A roof in straw.
///
/// Thatch is not tile the colour of straw. Two things say so from across a
/// street, and both are shape: the eaves are a **fat lip** — half a metre of
/// packed straw with a blunt edge, not a tile's thin line — and the ridge is
/// **rounded over** rather than folded to an arris, because straw will not
/// hold an edge and the ridge is where a thatcher lays his thickest bundle.
///
/// So the cross-section is a hexagon, not a triangle: up the outside of the
/// lip, up the slope, across the flat of the ridge, and back down. Extruded
/// along the ridge with a cap at each end, it is a closed solid like
/// everything else here, which is the whole reason the renderer can be sure
/// which of its faces are seen.
List<Facet> thatchFaces(
  double x0,
  double y0,
  double z0,
  double x1,
  double y1,
  double z1,
  bool alongX,
) {
  final rise = y1 - y0;
  // Across the slope, the two numbers that make it straw: how deep the eaves
  // hang and how wide the ridge is rolled over.
  final across = alongX ? (z1 - z0) : (x1 - x0);
  final lip = math.min(rise * 0.30, across * 0.11);
  final roll = across * 0.06;
  final m = alongX ? (z0 + z1) / 2 : (x0 + x1) / 2;
  final r0 = m - roll, r1 = m + roll;
  final slope = (across / 2 - roll);
  final up = rise - lip;

  final out = <Facet>[];
  Facet face(List<V3> v, V3 n, Surface k, {double ao = 1.0, int data = 0}) =>
      Facet(v, n, k, ao: ao)..data = data;

  out.add(
    face(
      [V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1)],
      const V3(0, -1, 0),
      Surface.thatch,
      ao: 0.55,
    ),
  );

  if (alongX) {
    // the fat edge of the eaves, both sides
    out.add(
      face(
        [
          V3(x0, y0, z1),
          V3(x1, y0, z1),
          V3(x1, y0 + lip, z1),
          V3(x0, y0 + lip, z1),
        ],
        const V3(0, 0, 1),
        Surface.thatch,
        ao: 0.78,
        data: 1,
      ),
    );
    out.add(
      face(
        [
          V3(x1, y0, z0),
          V3(x0, y0, z0),
          V3(x0, y0 + lip, z0),
          V3(x1, y0 + lip, z0),
        ],
        const V3(0, 0, -1),
        Surface.thatch,
        ao: 0.72,
        data: 2,
      ),
    );
    // the two slopes
    out.add(
      face(
        [
          V3(x0, y0 + lip, z1),
          V3(x1, y0 + lip, z1),
          V3(x1, y1, r1),
          V3(x0, y1, r1),
        ],
        V3(0, slope, up).normalized,
        Surface.thatch,
        data: 3,
      ),
    );
    out.add(
      face(
        [
          V3(x1, y0 + lip, z0),
          V3(x0, y0 + lip, z0),
          V3(x0, y1, r0),
          V3(x1, y1, r0),
        ],
        V3(0, slope, -up).normalized,
        Surface.thatch,
        ao: 0.92,
        data: 4,
      ),
    );
    // the roll of the ridge
    out.add(
      face(
        [V3(x0, y1, r0), V3(x1, y1, r0), V3(x1, y1, r1), V3(x0, y1, r1)],
        const V3(0, 1, 0),
        Surface.thatch,
        data: 5,
      ),
    );
    // and a cap at each end
    for (final (x, n, ao) in [
      (x1, const V3(1, 0, 0), 0.86),
      (x0, const V3(-1, 0, 0), 0.80),
    ]) {
      out.add(
        face(
          [
            V3(x, y0, z0),
            V3(x, y0, z1),
            V3(x, y0 + lip, z1),
            V3(x, y1, r1),
            V3(x, y1, r0),
            V3(x, y0 + lip, z0),
          ],
          n,
          Surface.thatch,
          ao: ao,
          data: 6,
        ),
      );
    }
    return out;
  }

  out.add(
    face(
      [
        V3(x1, y0, z0),
        V3(x1, y0, z1),
        V3(x1, y0 + lip, z1),
        V3(x1, y0 + lip, z0),
      ],
      const V3(1, 0, 0),
      Surface.thatch,
      ao: 0.78,
      data: 1,
    ),
  );
  out.add(
    face(
      [
        V3(x0, y0, z1),
        V3(x0, y0, z0),
        V3(x0, y0 + lip, z0),
        V3(x0, y0 + lip, z1),
      ],
      const V3(-1, 0, 0),
      Surface.thatch,
      ao: 0.72,
      data: 2,
    ),
  );
  out.add(
    face(
      [
        V3(x1, y0 + lip, z0),
        V3(x1, y0 + lip, z1),
        V3(r1, y1, z1),
        V3(r1, y1, z0),
      ],
      V3(up, slope, 0).normalized,
      Surface.thatch,
      data: 3,
    ),
  );
  out.add(
    face(
      [
        V3(x0, y0 + lip, z1),
        V3(x0, y0 + lip, z0),
        V3(r0, y1, z0),
        V3(r0, y1, z1),
      ],
      V3(-up, slope, 0).normalized,
      Surface.thatch,
      ao: 0.92,
      data: 4,
    ),
  );
  out.add(
    face(
      [V3(r0, y1, z0), V3(r0, y1, z1), V3(r1, y1, z1), V3(r1, y1, z0)],
      const V3(0, 1, 0),
      Surface.thatch,
      data: 5,
    ),
  );
  for (final (z, n, ao) in [
    (z1, const V3(0, 0, 1), 0.86),
    (z0, const V3(0, 0, -1), 0.80),
  ]) {
    out.add(
      face(
        [
          V3(x0, y0, z),
          V3(x1, y0, z),
          V3(x1, y0 + lip, z),
          V3(r1, y1, z),
          V3(r0, y1, z),
          V3(x0, y0 + lip, z),
        ],
        n,
        Surface.thatch,
        ao: ao,
        data: 6,
      ),
    );
  }
  return out;
}

List<Facet> gableFaces(
  double x0,
  double y0,
  double z0,
  double x1,
  double y1,
  double z1,
  bool alongX,
) {
  final mx = (x0 + x1) / 2, mz = (z0 + z1) / 2;
  final rise = y1 - y0;
  final floor = Facet(
    [V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1)],
    const V3(0, -1, 0),
    Surface.tile,
    ao: 0.55,
  );
  if (alongX) {
    final run = (z1 - z0) / 2;
    return [
      Facet(
        [V3(x0, y0, z1), V3(x1, y0, z1), V3(x1, y1, mz), V3(x0, y1, mz)],
        V3(0, run, rise).normalized,
        Surface.tile,
      ),
      Facet(
        [V3(x1, y0, z0), V3(x0, y0, z0), V3(x0, y1, mz), V3(x1, y1, mz)],
        V3(0, run, -rise).normalized,
        Surface.tile,
        ao: 0.92,
      ),
      Facet(
        [V3(x1, y0, z1), V3(x1, y0, z0), V3(x1, y1, mz)],
        const V3(1, 0, 0),
        Surface.tile,
        ao: 0.86,
      ),
      Facet(
        [V3(x0, y0, z0), V3(x0, y0, z1), V3(x0, y1, mz)],
        const V3(-1, 0, 0),
        Surface.tile,
        ao: 0.86,
      ),
      floor,
    ];
  }
  final run = (x1 - x0) / 2;
  // The slope climbs `run` across and `rise` up, so its normal leans the other
  // way round: `rise` across and `run` up. Written the obvious way — the same
  // two numbers in the same order as the slope that carried them — every roof
  // whose ridge runs north to south has been lit as though it were shallow
  // when it is steep and steep when it is shallow, ever since there were
  // roofs. Only a test that checks a normal is square to its own face was ever
  // going to catch that; the eye never did.
  return [
    Facet(
      [V3(x1, y0, z0), V3(x1, y0, z1), V3(mx, y1, z1), V3(mx, y1, z0)],
      V3(rise, run, 0).normalized,
      Surface.tile,
    ),
    Facet(
      [V3(x0, y0, z1), V3(x0, y0, z0), V3(mx, y1, z0), V3(mx, y1, z1)],
      V3(-rise, run, 0).normalized,
      Surface.tile,
      ao: 0.92,
    ),
    Facet(
      [V3(x0, y0, z1), V3(x1, y0, z1), V3(mx, y1, z1)],
      const V3(0, 0, 1),
      Surface.tile,
      ao: 0.86,
    ),
    Facet(
      [V3(x1, y0, z0), V3(x0, y0, z0), V3(mx, y1, z0)],
      const V3(0, 0, -1),
      Surface.tile,
      ao: 0.86,
    ),
    floor,
  ];
}

/// A spire: four faces to a point, and the base that closes it.
List<Facet> spireFaces(
  double x0,
  double y0,
  double z0,
  double x1,
  double y1,
  double z1,
) {
  final mx = (x0 + x1) / 2, mz = (z0 + z1) / 2;
  final apex = V3(mx, y1, mz);
  final rise = y1 - y0;
  final rx = (x1 - x0) / 2, rz = (z1 - z0) / 2;
  return [
    Facet(
      [V3(x0, y0, z1), V3(x1, y0, z1), apex],
      V3(0, rz, rise).normalized,
      Surface.tile,
    ),
    Facet(
      [V3(x1, y0, z0), V3(x0, y0, z0), apex],
      V3(0, rz, -rise).normalized,
      Surface.tile,
      ao: 0.9,
    ),
    Facet(
      [V3(x1, y0, z1), V3(x1, y0, z0), apex],
      V3(rise, rx, 0).normalized,
      Surface.tile,
      ao: 0.95,
    ),
    Facet(
      [V3(x0, y0, z0), V3(x0, y0, z1), apex],
      V3(-rise, rx, 0).normalized,
      Surface.tile,
      ao: 0.95,
    ),
    Facet(
      [V3(x0, y0, z0), V3(x1, y0, z0), V3(x1, y0, z1), V3(x0, y0, z1)],
      const V3(0, -1, 0),
      Surface.tile,
      ao: 0.55,
    ),
  ];
}

/// A rounded cap: rings of quads narrowing to a point, on a closed base.
List<Facet> domeFaces(
  double cx,
  double cz,
  double w,
  double d,
  double y0,
  double y1,
) {
  const rings = 3, sides = 8;
  final rx = w / 2, rz = d / 2, rise = y1 - y0;
  V3 at(int ring, int i) {
    final t = ring / rings;
    final k = math.cos(t * math.pi / 2);
    // Wrapped, not run past the end: the eighth face has to close onto the
    // very same corner the first one started from, or the dome is a shell with
    // a hairline crack down it and nothing downstream can be sure it is shut.
    final a = (i % sides) * 2 * math.pi / sides;
    return V3(
      cx + math.cos(a) * rx * k,
      y0 + math.sin(t * math.pi / 2) * rise,
      cz + math.sin(a) * rz * k,
    );
  }

  final out = <Facet>[];
  final apex = V3(cx, y1, cz);
  // The middle of the dome's own base, so every face can be turned to look
  // away from it.
  final core = V3(cx, y0, cz);
  Facet shell(List<V3> v) =>
      Facet(v, Facet.normalOf(v, away: core), Surface.tile);
  for (var ring = 0; ring < rings; ring++) {
    for (var i = 0; i < sides; i++) {
      final a = at(ring, i), b = at(ring, i + 1);
      if (ring == rings - 1) {
        out.add(shell([a, b, apex]));
      } else {
        // Two triangles, not one quad. Four points on a curved surface are not
        // flat, and a face that is not flat has no plane — which is the one
        // thing everything after this needs it to have.
        final c = at(ring + 1, i + 1), d = at(ring + 1, i);
        out.add(shell([a, b, c]));
        out.add(shell([a, c, d]));
      }
    }
  }
  final base = <V3>[];
  for (var i = sides - 1; i >= 0; i--) {
    base.add(at(0, i));
  }
  out.add(Facet(base, const V3(0, -1, 0), Surface.tile, ao: 0.55));
  return out;
}

// ------------------------------------------------------------- the fiddly bits

/// A run of arches: the piers, the band they carry, and the shadow standing in
/// each opening, set back so the arch reads as a hole rather than a stripe.
List<Solid> _arcade(TownPiece piece, double y0, double y1) {
  final along = piece.alongX;
  final len = along ? piece.w : piece.d;
  final n = clampD(len / 0.95, 1, 8).round();
  final ht = y1 - y0;
  final pierW = len / n * 0.34;
  final step = len / n;
  final start = (along ? piece.x0 : piece.z0) + step / 2;
  final headY = y0 + ht * 0.72;
  final out = <Solid>[
    Solid(
      piece.index,
      boxFaces(
        piece.x0,
        headY,
        piece.z0,
        piece.x1,
        y1,
        piece.z1,
        Surface.stone,
      ),
    ),
  ];
  for (var i = 0; i <= n; i++) {
    final c = start - step / 2 + i * step;
    final w = along ? pierW : piece.w;
    final d = along ? piece.d : pierW;
    final ccx = along ? c : piece.cx;
    final ccz = along ? piece.cz : c;
    out.add(
      Solid(
        piece.index,
        boxFaces(
          ccx - w / 2,
          y0,
          ccz - d / 2,
          ccx + w / 2,
          headY,
          ccz + d / 2,
          Surface.stone,
          ao: 0.92,
        ),
      ),
    );
  }
  const set = 0.035;
  for (var i = 0; i < n; i++) {
    final c = start + i * step;
    final gap = step - pierW;
    final w = along ? gap : piece.w - set * 2;
    final d = along ? piece.d - set * 2 : gap;
    final ccx = along ? c : piece.cx;
    final ccz = along ? piece.cz : c;
    out.add(
      Solid(
        piece.index,
        boxFaces(
          ccx - w / 2,
          y0,
          ccz - d / 2,
          ccx + w / 2,
          headY,
          ccz + d / 2,
          Surface.hollow,
          ao: 0.7,
        ),
      ),
    );
  }
  return out;
}

/// A water wheel: a closed ring of chords, the paddles standing out of it, and
/// the hub.
List<Solid> _wheel(TownPiece piece, double y0, double y1) {
  final r = (y1 - y0) / 2;
  final cy = y0 + r;
  final cx = piece.cx, cz = piece.cz;
  final flat = piece.alongX;
  const spokes = 12;
  final thick = r * 0.16;
  final out = <Solid>[];

  void slab(
    double ccx,
    double ccz,
    double w,
    double d,
    double a,
    double b,
    int tint,
    double ao,
  ) {
    out.add(
      Solid(
        piece.index,
        boxFaces(
          ccx - w / 2,
          a,
          ccz - d / 2,
          ccx + w / 2,
          b,
          ccz + d / 2,
          Surface.own,
          ao: ao,
          tint: tint,
        ),
      ),
    );
  }

  for (var i = 0; i < spokes; i++) {
    final a = (i + 0.5) * 2 * math.pi / spokes;
    final px = math.cos(a) * r * 0.88, py = math.sin(a) * r * 0.88;
    final tangential = math.max(r * 2 * math.pi / spokes * 0.62, 0.08);
    final horiz = math.sin(a).abs() * tangential + math.cos(a).abs() * r * 0.16;
    final vert = math.cos(a).abs() * tangential + math.sin(a).abs() * r * 0.16;
    slab(
      flat ? cx + px : cx,
      flat ? cz : cz + px,
      flat ? horiz : thick,
      flat ? thick : horiz,
      cy + py - vert / 2,
      cy + py + vert / 2,
      0xFF8A7355,
      0.98,
    );
  }
  for (var i = 0; i < spokes ~/ 2; i++) {
    final a = i * 4 * math.pi / spokes;
    final px = math.cos(a) * r * 0.62, py = math.sin(a) * r * 0.62;
    slab(
      flat ? cx + px : cx,
      flat ? cz : cz + px,
      flat ? r * 0.5 : thick * 1.5,
      flat ? thick * 1.5 : r * 0.5,
      cy + py - r * 0.09,
      cy + py + r * 0.09,
      0xFF6E5A42,
      0.9,
    );
  }
  slab(
    cx,
    cz,
    flat ? r * 0.3 : thick * 1.4,
    flat ? thick * 1.4 : r * 0.3,
    cy - r * 0.15,
    cy + r * 0.15,
    0xFF6E5A42,
    0.88,
  );
  return out;
}

/// Windows, hung on the walls they belong to.
///
/// They are not faces of their own with a depth to be argued over: they are
/// carried by the wall's own face and painted the instant after it. A window
/// cannot fight its wall for depth when the question is never asked, which is
/// the end of the flicker that used to come and go as the camera swung round.
/// The windows of one storey.
///
/// How many and how big is where a wall says how thick it is. There is no
/// thickness to a wall in this world — a house is a closed box — so a thick
/// one is read the way a real one is: the opening is narrower, and it is set
/// back far enough to be ringed by its own shadow. A frontier town on the
/// Marca would rather have wall than window and gets both; on the Costa the
/// glass is almost flush and there is twice as much of it.
void _hangWindows(
  List<Facet> faces,
  double y0,
  double y1,
  TownCharacter? place,
) {
  final h = y1 - y0;
  if (h < 0.5) return;
  final thick = place?.wallThick ?? 0.0;
  final gap = place?.windowGap ?? 1.0;

  // Cuántas filas de ventanas lleva este cuerpo.
  //
  // Una por cuerpo mientras el cuerpo mida lo que mide una planta, que es como
  // está construido todo lo que hay hoy. Pero un cuerpo de cinco metros con
  // una sola fila de ventanas tiene ventanas de dos metros de alto, y entonces
  // deja de leerse como alto y pasa a leerse como un muro normal visto de
  // cerca. Un edificio se ve grande porque tiene muchas filas de ventanas
  // chicas, no una grande.
  //
  // El umbral está donde está para no tocar nada de lo que ya estaba: una
  // planta corriente mide entre uno y uno y medio, así que ninguna de las seis
  // regiones llega a dos filas. Está de antemano, para lo que venga.
  final filas = math.max(1, (h / 2.6).floor());
  final alto = h / filas;
  final hw = 0.15 * (1 - 0.28 * thick);
  // How far the opening is set back into the wall, as the width of the shadow
  // it throws around itself.
  final jamb = 0.062 * thick;
  for (final f in faces) {
    if (f.n.y.abs() > 0.01) continue;
    final onZ = f.n.z.abs() > 0.5;
    // The wall's own span, pulled in from its corners.
    var lo = double.infinity, hi = -double.infinity, out = 0.0;
    for (final p in f.v) {
      final t = onZ ? p.x : p.z;
      if (t < lo) lo = t;
      if (t > hi) hi = t;
      out = onZ ? p.z : p.x;
    }
    lo += 0.2;
    hi -= 0.2;
    final span = hi - lo;
    if (span < 0.5) continue;
    final n = math.max(1, (span / (0.62 * gap)).floor());
    final decals = <Facet>[];
    for (var fila = 0; fila < filas; fila++) {
      final base = y0 + alto * fila;
      final wy0 = base + alto * 0.34, wy1 = base + alto * 0.74;
      for (var i = 0; i < n; i++) {
        final c = lo + span * (i + 0.5) / n;
        List<V3> rect(double a, double b, double p0, double p1) => onZ
            ? [V3(a, p0, out), V3(b, p0, out), V3(b, p1, out), V3(a, p1, out)]
            : [V3(out, p0, a), V3(out, p0, b), V3(out, p1, b), V3(out, p1, a)];
        // The reveal first, so the opening is painted inside it: unlit, because
        // the inside of a hole in a thick wall is a shadow and not a surface.
        if (jamb > 0.002) {
          decals.add(
            Facet(
              rect(c - hw - jamb, c + hw + jamb, wy0 - jamb, wy1 + jamb),
              f.n,
              Surface.hollow,
            )..data = i,
          );
        }
        decals.add(
          Facet(rect(c - hw, c + hw, wy0, wy1), f.n, Surface.window)..data = i,
        );
        // Two planks nailed across it, drawn only once the place has been empty
        // a while. The geometry is always here; whether it is painted is the
        // renderer's business, because neglect changes by the day and stone
        // does not.
        for (var k = 0; k < 2; k++) {
          final py = wy0 + (wy1 - wy0) * (k == 0 ? 0.28 : 0.66);
          final th = (wy1 - wy0) * 0.13;
          decals.add(
            Facet(
              rect(c - hw * 1.25, c + hw * 1.25, py - th, py + th),
              f.n,
              Surface.plank,
            )..data = i,
          );
        }
      }
    }
    if (decals.isEmpty) continue;
    final at = faces.indexOf(f);
    faces[at] = Facet(
      f.v,
      f.n,
      f.surface,
      ao: f.ao,
      tint: f.tint,
      decals: decals,
    );
  }
}

/// The notice board in the plaza.
///
/// Not a piece and never earned: the plots are laid out around a crossing at
/// the middle of the town and this stands in it, from the first achievement
/// on. A town that made you pay an achievement for the place where it tells
/// you things would be charging you to read your own handwriting.
class NoticeBoard {
  /// Half the width of the plank people read.
  /// Two thirds of a metre across and shoulder high, near enough — smaller
  /// than a house wall and bigger than the thumb that has to find it.
  static const double reach = 0.37;
  static const double low = 0.52, high = 1.02;
  static const double _post = 0.065, _top = 1.08;

  /// Dónde queda dentro de la plaza, medido desde su centro.
  ///
  /// A un lado y no en medio: en medio está la fuente, y el atril está al otro
  /// lado. El desplazamiento lo aplica esta clase y no quien la llama, así que
  /// todo el que pregunte por el tablón pasa el centro del pueblo y no tiene
  /// que saber nada de esto.
  /// A la izquierda de la fuente, mirando hacia afuera. Sale del radio de la
  /// plaza y no de un número suelto: si la plaza crece, el tablón se corre con
  /// ella en vez de quedarse pegado a la fuente.
  static double get offX => -TownLayout.plazaReach * Plaza.boardOut;
  static double get offZ => TownLayout.plazaReach * Plaza.boardOut;

  static double xAt(double cx) => cx + offX;
  static double zAt(double cz) => cz + offZ;

  /// Hacia dónde mira: a la fuente.
  ///
  /// Estaba de cara al norte y de espaldas a la plaza, que es donde está la
  /// gente. Un tablón se planta mirando al sitio desde el que se lee, y el
  /// sitio desde el que se lee una plaza es la plaza. Sale de dónde está
  /// puesto y no de un número aparte: si se mueve, se gira solo.
  static double get turn => math.atan2(-offX, -offZ);

  /// The four corners of the plank, front face, counter-clockwise from the
  /// bottom left. The town's mark goes on it and a finger lands on it, and
  /// both want the same rectangle.
  static List<V3> faceAt(double cx, double cz) {
    final x = xAt(cx), z = zAt(cz);
    final a = turn, sinA = math.sin(a), cosA = math.cos(a);
    return [
      for (final v in [
        V3(x - reach, low, z + 0.05),
        V3(x + reach, low, z + 0.05),
        V3(x + reach, high, z + 0.05),
        V3(x - reach, high, z + 0.05),
      ])
        turnedAt(v, x, z, sinA, cosA),
    ];
  }

  /// Cuántas hojas caben en la plancha: dos filas de cinco, las mismas que
  /// tiene el tablón de cerca, para que la silueta se corresponda con lo que
  /// hay clavado de verdad.
  static const int rows = 2, cols = 5;
  static const int capacity = rows * cols;

  /// The plank, with the sheets that are actually pinned to it.
  ///
  /// The sheets are geometry and not a picture painted over the town, so a
  /// house standing between you and the board hides them the way it hides
  /// everything else. From across the plaza that is all a notice board is:
  /// pale paper on dark wood.
  ///
  /// [sheets] son los huecos ocupados del tablón de cerca, los mismos y en el
  /// mismo sitio. Así la plaza dice de lejos lo que se ve al acercarse —medio
  /// lleno se ve medio lleno, y con los papeles donde están— en vez de tener
  /// tres papeles de adorno que no querían decir nada.
  static List<Facet> _plank(double cx, double cz, int tint, List<int> sheets) {
    final faces = boxFaces(
      cx - reach,
      low,
      cz - 0.05,
      cx + reach,
      high,
      cz + 0.05,
      Surface.own,
      ao: 1.0,
      tint: tint,
    );
    const paper = 0xFFE9DCBC;
    // El hueco útil de la plancha, y una rejilla de dos por cinco dentro.
    const aire = 0.035;
    final usableW = (reach - aire) * 2, usableH = high - low - aire * 2;
    final colW = usableW / cols, rowH = usableH / rows;
    final w = colW * 0.36, h = w / 1.3;
    final papeles = <Facet>[];
    for (final hueco in sheets) {
      if (hueco < 0 || hueco >= capacity) continue;
      final row = hueco % rows, col = hueco ~/ rows;
      final mx = cx - reach + aire + (col + 0.5) * colW;
      final my = low + aire + (rows - 1 - row + 0.5) * rowH;
      papeles.add(
        Facet(
          [
            V3(mx - w, my - h, cz + 0.05),
            V3(mx + w, my - h, cz + 0.05),
            V3(mx + w, my + h, cz + 0.05),
            V3(mx - w, my + h, cz + 0.05),
          ],
          const V3(0, 0, 1),
          Surface.own,
          ao: 1.06,
          tint: paper,
        ),
      );
    }
    for (var i = 0; i < faces.length; i++) {
      if (faces[i].n.z < 0.9) continue;
      faces[i] = Facet(
        faces[i].v,
        faces[i].n,
        faces[i].surface,
        ao: faces[i].ao,
        tint: faces[i].tint,
        decals: papeles,
      );
    }
    return faces;
  }

  static List<Solid> solidsAt(
    double cxIn,
    double czIn, {
    List<int> sheets = const [0, 3, 6],
  }) {
    final cx = xAt(cxIn), cz = zAt(czIn);
    const wood = 0xFF6B573F;
    const plank = 0xFFC9B896;
    const shingle = 0xFF8A7355;
    Solid post(double at) => Solid(
      -1,
      boxFaces(
        cx + at - _post / 2,
        0,
        cz - _post / 2,
        cx + at + _post / 2,
        _top,
        cz + _post / 2,
        Surface.own,
        ao: 0.88,
        tint: wood,
      ),
    );

    return turnedSolids(
      [
        post(-reach + _post),
        post(reach - _post),
        Solid(-1, _plank(cx, cz, plank, sheets)),
        // A little roof, because paper left out in the rain is not a notice.
        Solid(
          -1,
          gableFaces(
                cx - reach - 0.09,
                high,
                cz - 0.17,
                cx + reach + 0.09,
                high + 0.17,
                cz + 0.17,
                true,
              )
              .map((f) => Facet(f.v, f.n, Surface.own, ao: f.ao, tint: shingle))
              .toList(),
        ),
      ],
      cx,
      cz,
      turn,
    );
  }
}

/// La plaza: el claro en el centro del pueblo.
///
/// Existe por un motivo concreto y se ve en cuanto un pueblo pasa de diez
/// casas: el tablón es la cosa más importante que hay en el pueblo y es también
/// la más pequeña, así que en cuanto empezaban a levantarse estructuras
/// quedaba escondido entre ellas. Un botón que lo abre lo arregla para el
/// dedo, no para el ojo — y lo que se estaba perdiendo era el sitio, no el
/// botón.
///
/// Así que el pueblo se funda con una plaza y ningún solar puede meter la
/// huella dentro. Y una plaza no es un claro: es un ejido de hierba con un
/// bordillo de piedra alrededor, la fuente en medio, el tablón a un lado y el
/// atril al otro. Desde cualquier punto del pueblo se sabe dónde está el
/// centro, y de cerca hay algo que mirar.
///
/// Hierba y no enlosado, que es al revés de como empezó. Un disco de piedra
/// con cuatro lunares verdes se leía como un pavimento con desperfectos; la
/// hierba con su bordillo se lee como un sitio. Y como la hierba va declarada
/// como hoja, la plaza sigue el calendario del año igual que el prado que la
/// rodea, en vez de quedarse verde primavera bajo la nieve.
class Plaza {
  const Plaza._();

  /// Piedra clara, de otro tono que los muros, para que el bordillo se lea
  /// como suelo y no como el cimiento de algo.
  static const int _kerb = 0xFFB9AE97;
  static const int _edge = 0xFF9C917B;

  /// La hierba de la plaza: la misma gama que la del prado y las huertas.
  static const int _grass = 0xFF6B7A42;
  static const int _basin = 0xFFA79B83;
  static const int _rim = 0xFF8E836D;

  /// El mismo verde azulado con el que el pueblo pinta el agua quieta de un
  /// estanque o de un río. Un celeste de piscina en medio de un valle en
  /// tierras y cales se lee como una calcomanía.
  static const int _water = 0xFF3F7C86;

  /// Un octógono de radio [r], en sentido antihorario visto desde arriba.
  static List<(double, double)> ring(
    double cx,
    double cz,
    double r, {
    int sides = 8,
    double turn = 0,
  }) => [
    for (var k = 0; k < sides; k++)
      (
        cx + r * math.cos(turn + math.pi / sides + k * 2 * math.pi / sides),
        cz - r * math.sin(turn + math.pi / sides + k * 2 * math.pi / sides),
      ),
  ];

  /// Dónde va cada cosa, medido desde el centro y en proporción al radio.
  ///
  /// En proporción y no en metros: si mañana la plaza crece o mengua, la
  /// fuente y los muebles se mueven con ella en vez de quedarse amontonados en
  /// el medio.
  static const double boardOut = 0.52, lecternOut = 0.52;

  /// Lo que ocupa la fuente, en proporción al radio de la plaza. Lo pregunta
  /// quien tenga que rodearla: la gente del pueblo no la atraviesa.
  static double basinOf(double reach) => reach * 0.27 * 1.14;

  /// La fuente: taza, brocal y el agua dentro.
  ///
  /// Pequeña a propósito. Hay un hito que es una fuente y cuesta sus piezas;
  /// ésta es el pilón de una plaza de pueblo, que es otra cosa y tiene que
  /// parecerlo: un brocal bajo con agua, sin surtidor ni figuras.
  static List<Solid> _fountain(double cx, double cz, double r) {
    final taza = basinOf(r) / 1.14;
    const suelo = 0.035;
    const alto = 0.40;
    return [
      // El escalón sobre el que se apoya, que es lo que la levanta del
      // enlosado y le da sombra propia.
      Solid(
        -1,
        prismFaces(
          ring(cx, cz, taza * 1.14, sides: 8),
          suelo,
          suelo + 0.07,
          Surface.stone,
          ao: 0.98,
          tint: _basin,
        ),
      ),
      // El brocal, que es un anillo y no un bloque: por eso se ve el agua.
      ...ringSolids(
        cx,
        cz,
        taza * 0.80,
        taza,
        suelo + 0.07,
        alto,
        Surface.stone,
        ao: 0.94,
        tint: _rim,
      ),
      // El agua, un dedo por debajo del canto: así la piedra asoma por encima
      // y lo de dentro se lee como agua contenida y no como una tapa azul.
      Solid(
        -1,
        prismFaces(
          ring(cx, cz, taza * 0.81, sides: 8),
          suelo + 0.07,
          alto - 0.055,
          Surface.own,
          ao: 1.0,
          tint: _water,
        ),
      ),
      // Y el pilar del caño en medio, que es lo que se ve de lejos.
      Solid(
        -1,
        prismFaces(
          ring(cx, cz, taza * 0.20, sides: 6),
          alto - 0.055,
          alto + 0.40,
          Surface.stone,
          ao: 0.94,
          tint: _basin,
        ),
      ),
      Solid(
        -1,
        prismFaces(
          ring(cx, cz, taza * 0.36, sides: 6),
          alto + 0.40,
          alto + 0.50,
          Surface.stone,
          ao: 1.0,
          tint: _rim,
        ),
      ),
    ];
  }

  /// Todo lo que hay en el suelo de la plaza.
  ///
  /// El ejido es un sólido de verdad y no una mancha pintada en el suelo:
  /// tiene canto, y ese canto —más el bordillo que lo rodea, que asoma un
  /// dedo por encima— es lo que hace que de perfil se vea que el suelo está
  /// levantado y no que alguien cambió el color de la hierba.
  static List<Solid> solidsAt(double cx, double cz, double reach) => [
    // El bordillo: un anillo de piedra, no un disco. Un disco debajo de la
    // hierba es un disco que no se ve.
    ...ringSolids(
      cx,
      cz,
      reach * 0.90,
      reach,
      0,
      0.085,
      Surface.stone,
      ao: 1.0,
      tint: _kerb,
    ),
    // Y su canto de fuera un tono más oscuro, que es lo que dibuja el octógono
    // desde arriba —que es desde donde se mira casi siempre— en vez de dejar
    // un anillo liso al que hay que adivinarle la forma.
    ...ringSolids(
      cx,
      cz,
      reach * 0.975,
      reach,
      0.085,
      0.105,
      Surface.stone,
      ao: 0.94,
      tint: _edge,
    ),
    // La hierba, hasta donde empieza la piedra.
    Solid(
      -1,
      prismFaces(
        ring(cx, cz, reach * 0.905),
        0,
        0.055,
        Surface.leaf,
        ao: 1.02,
        tint: _grass,
      ),
    ),
    ..._fountain(cx, cz, reach),
  ];
}

/// El atril de la plaza: donde se leen las leyendas de este pueblo.
///
/// Un libro abierto sobre un tablero inclinado. No es una pieza y no se gana:
/// está desde el primer logro, igual que el tablón, porque cobrar un logro por
/// el sitio donde se lee lo que uno mismo escribió sería cobrar por la propia
/// letra.
///
/// Se distingue del tablón a la primera ojeada y eso es a propósito: el tablón
/// es lo que el pueblo dice de vos, y el atril es lo que vos dijiste. Uno es
/// vertical y de papeles clavados; el otro está inclinado y tiene dos páginas.
class Lectern {
  const Lectern._();

  /// Enfrente del tablón, al otro lado de la fuente.
  ///
  /// Estaban los dos juntos y se leían como un solo mueble de dos partes. Una
  /// plaza tiene el tablón en una esquina y el facistol en otra, y la fuente
  /// en medio: así cada cosa es una cosa, y se llega a una sin pasar por la
  /// otra.
  static double get offX => TownLayout.plazaReach * Plaza.lecternOut;
  static double get offZ => TownLayout.plazaReach * Plaza.lecternOut;

  /// Lo que mide, de lo que llegó a medir.
  ///
  /// Empezó a tamaño de persona y era un mueble enorme para una cosa que se
  /// lee de pie y de cerca; bajó a la mitad y se quedó corto. Esto es un
  /// facistol de plaza: **más chico que el tablón, y a la vista**, que son las
  /// dos condiciones y no una.
  static const double _k = 0.62;

  /// Medidas del tablero: lo que ocupa y a qué altura se lee.
  static const double _wide = 0.30 * _k, _deep = 0.23 * _k;
  static const double _back = 1.04 * _k, _front = 0.86 * _k;
  static const double _thick = 0.045 * _k;

  /// Cuánto sobresale el libro por encima del tablero. Lo comparten la
  /// geometría y el blanco del dedo, para que lo que se toca sea exactamente
  /// la tapa que se ve y no un rectángulo flotando encima de ella.
  static const double _leafLift = 0.028 * _k;

  static const int _wood = 0xFF6B573F;
  static const int _dark = 0xFF54432F;
  static const int _stone = 0xFFA89C85;
  static const int _page = 0xFFEDE3C8;
  static const int _bind = 0xFF7A4034;

  static double xAt(double cx) => cx + offX;
  static double zAt(double cz) => cz + offZ;

  /// Hacia dónde mira: a la fuente, igual que el tablón y por lo mismo. El
  /// lado cuesta abajo del tablero es el lado desde el que se lee, y ése tiene
  /// que dar a la plaza.
  static double get turn => math.atan2(-offX, -offZ);

  /// Las cuatro esquinas de la cara de arriba del libro, que es lo que se ve y
  /// por lo tanto lo que se toca. Empezando por la de atrás a la izquierda.
  ///
  /// Sale de la propia geometría y no de un punto colgado encima: lo que el
  /// dedo busca es exactamente lo que el ojo encuentra, y desde lejos, cuando
  /// el atril es una mota, no hay nada que tocar — que es lo correcto.
  static List<V3> faceAt(double cx, double cz) {
    final x = xAt(cx), z = zAt(cz);
    const lift = _leafLift;
    final a = turn, sinA = math.sin(a), cosA = math.cos(a);
    return [
      for (final v in [
        V3(x - _wide, _back + lift, z - _deep),
        V3(x + _wide, _back + lift, z - _deep),
        V3(x + _wide, _front + lift, z + _deep),
        V3(x - _wide, _front + lift, z + _deep),
      ])
        turnedAt(v, x, z, sinA, cosA),
    ];
  }

  /// Una tabla inclinada: el mismo rectángulo de siempre, con la arista de
  /// atrás más alta que la de delante.
  static List<V3> _board(
    double x,
    double z,
    double w,
    double d,
    double back,
    double front,
    double thick,
  ) => [
    V3(x - w, back - thick, z - d),
    V3(x + w, back - thick, z - d),
    V3(x + w, front - thick, z + d),
    V3(x - w, front - thick, z + d),
    V3(x - w, back, z - d),
    V3(x + w, back, z - d),
    V3(x + w, front, z + d),
    V3(x - w, front, z + d),
  ];

  static List<Solid> solidsAt(double cx, double cz) {
    final x = xAt(cx), z = zAt(cz);
    // Media página: del lomo hacia fuera, e inclinada como el tablero.
    List<V3> leaf(double from, double to, double lift) => [
      V3(x + from, _back - 0.012 * _k + lift, z - _deep * 0.94),
      V3(x + to, _back - 0.012 * _k + lift, z - _deep * 0.94),
      V3(x + to, _front - 0.012 * _k + lift, z + _deep * 0.94),
      V3(x + from, _front - 0.012 * _k + lift, z + _deep * 0.94),
      V3(x + from, _back + lift, z - _deep * 0.94),
      V3(x + to, _back + lift, z - _deep * 0.94),
      V3(x + to, _front + lift, z + _deep * 0.94),
      V3(x + from, _front + lift, z + _deep * 0.94),
    ];

    return turnedSolids(
      [
        // El pie, de piedra, con su zócalo: un atril de una sola pata sobre la
        // hierba se lee como un cartel clavado, no como un mueble.
        Solid(
          -1,
          prismFaces(
            Plaza.ring(x, z, 0.21 * _k),
            0.035,
            0.035 + 0.065 * _k,
            Surface.stone,
            ao: 0.96,
            tint: _stone,
          ),
        ),
        Solid(
          -1,
          boxFaces(
            x - 0.055 * _k,
            0.035 + 0.065 * _k,
            z - 0.055 * _k,
            x + 0.055 * _k,
            _front - 0.10 * _k,
            z + 0.055 * _k,
            Surface.own,
            ao: 0.90,
            tint: _wood,
          ),
        ),
        // El tablero, y su listón de abajo para que el libro no resbale.
        Solid(
          -1,
          hexFaces(
            _board(
              x,
              z,
              _wide + 0.035 * _k,
              _deep + 0.03 * _k,
              _back,
              _front,
              _thick,
            ),
            Surface.own,
            ao: 0.98,
            tint: _wood,
          ),
        ),
        Solid(
          -1,
          hexFaces(
            _board(
              x,
              z + _deep + 0.015 * _k,
              _wide + 0.035 * _k,
              0.022 * _k,
              _front + 0.045 * _k,
              _front + 0.03 * _k,
              0.05 * _k,
            ),
            Surface.own,
            ao: 0.92,
            tint: _dark,
          ),
        ),
        // Y el libro: dos páginas y el lomo entre ellas.
        Solid(
          -1,
          hexFaces(
            leaf(-_wide, -0.018 * _k, _leafLift),
            Surface.own,
            ao: 1.06,
            tint: _page,
          ),
        ),
        Solid(
          -1,
          hexFaces(
            leaf(0.018 * _k, _wide, _leafLift),
            Surface.own,
            ao: 1.06,
            tint: _page,
          ),
        ),
        Solid(
          -1,
          hexFaces(
            leaf(-0.026 * _k, 0.026 * _k, _leafLift - 0.008 * _k),
            Surface.own,
            ao: 0.88,
            tint: _bind,
          ),
        ),
      ],
      x,
      z,
      turn,
    );
  }
}
