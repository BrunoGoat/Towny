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

import '../core/math3.dart';
import 'palette.dart';
import 'solid.dart';
import 'solids.dart';
import 'town.dart';

// ------------------------------------------------------------------ el agua

/// El agua de la fuente de la plaza, vista desde [eye] en el segundo [time].
///
/// **Un surtidor y una corona**, como ⛲: un chorro fino que sube del caño, se
/// abre arriba en ocho hilos que caen en arco hasta el pilón, y en cada caída
/// unas gotas que saltan. Los hilos son cintas que miran siempre a quien mira
/// —desde cualquier lado se ven igual de enteros— y por dentro de cada una
/// corre un brillo hacia afuera, que es lo que hace que se lea agua corriendo
/// y no alambre.
///
/// **De noche, más tranquila**: el chorro sube menos, corre más despacio y
/// los hilos son menos. La fuente no se apaga —es el centro del pueblo—,
/// pero baja la voz.
List<Facet> fountainWater(TownLayout l, V3 eye, double time, Palette pal) {
  final cx = l.cx, cz = l.cz;
  final taza = Plaza.basinOf(TownLayout.plazaReach) / 1.14;
  // Del caño, que es lo de arriba del pilar, al agua del pilón.
  const boca = 0.92, agua = 0.35;
  final dia = smoothstep(0.05, 0.6, pal.daylight);
  final alto = lerpD(0.16, 0.40, dia);
  final corre = lerpD(0.30, 0.62, dia);
  final hilos = dia > 0.5 ? 8 : 6;
  final lejos = taza * 0.60;

  final out = <Facet>[];

  // La parábola de un hilo: sale de la boca, sube [alto] y cae al agua a
  // [lejos]. `u` va de cero (la boca) a uno (el agua).
  final d = boca - agua;
  final ua = (-2 * alto + math.sqrt(4 * alto * alto + 4 * d * alto)) / (2 * d);
  final c = d / (1 - 2 * ua), b = 2 * c * ua;
  double y(double u) => boca + b * u - c * u * u;

  // Lo que hace de cinta: un tramo de [a] a [z] de ancho [w], de cara a [eye].
  void cinta(V3 a, V3 z, double w, int tint, double ao) {
    final dir = z - a;
    final mitad = (a + z) * 0.5;
    final ojo = eye - mitad;
    var lado = dir.cross(ojo);
    if (lado.length < 1e-9) return;
    lado = lado.normalized * (w / 2);
    var n = lado.cross(dir).normalized;
    if (n.dot(ojo) < 0) n = n * -1;
    out.add(
      Facet(
        [a - lado, z - lado, z + lado, a + lado],
        n,
        Surface.own,
        ao: ao,
        tint: tint,
      )..piece = -1,
    );
  }

  // Un brillo que corre por el hilo hacia afuera: claro donde pasa la ola,
  // agua donde no.
  int tono(double u, double fase) {
    final ola = 0.5 + 0.5 * math.sin(2 * math.pi * (u * 2.4 - fase));
    final k = ola * ola;
    return _mix(0xFF8EC7DC, 0xFFF4FCFF, k);
  }

  final fase = time * corre;

  // El chorro de en medio, que sube derecho un poco más que la corona.
  const pasosChorro = 5;
  for (var i = 0; i < pasosChorro; i++) {
    final u0 = i / pasosChorro, u1 = (i + 1) / pasosChorro;
    final y0 = boca + alto * 1.12 * u0, y1 = boca + alto * 1.12 * u1;
    cinta(
      V3(cx, y0, cz),
      V3(cx, y1, cz),
      0.034 * (1 - 0.35 * u0),
      tono(-u0, fase * 1.5),
      1.12,
    );
  }

  // La corona: los hilos en arco hasta el pilón.
  const pasos = 12;
  for (var k = 0; k < hilos; k++) {
    final a = k * 2 * math.pi / hilos + 0.2;
    final dx = math.cos(a), dz = math.sin(a);
    V3 at(double u) => V3(cx + dx * lejos * u, y(u), cz + dz * lejos * u);
    for (var i = 0; i < pasos; i++) {
      final u0 = i / pasos, u1 = (i + 1) / pasos;
      // Más fino al caer, que es lo que hace el agua al estirarse.
      cinta(at(u0), at(u1), 0.024 * (1 - 0.45 * u0), tono(u0, fase), 1.10);
    }
    // Y las gotas donde cae: saltan un poco y vuelven, cada una a su ritmo.
    final cae = at(1);
    for (var g = 0; g < 2; g++) {
      final t =
          (time * (1.1 + 0.3 * g) * (0.6 + 0.4 * dia) + k * 0.37 + g * 0.5) %
          1.0;
      final sube = 4 * t * (1 - t) * 0.07 * (0.5 + 0.5 * dia);
      final gx = cae.x + dx * 0.03 * (g == 0 ? 1 : -1) + dz * 0.025 * g;
      final gz = cae.z + dz * 0.03 * (g == 0 ? 1 : -1) - dx * 0.025 * g;
      final p = V3(gx, agua + 0.01 + sube, gz);
      cinta(p, p + const V3(0, 0.022, 0), 0.020, 0xFFE6F6FB, 1.12);
    }
  }
  return out;
}

int _mix(int a, int b, double t) {
  int ch(int s) {
    final x = (a >> s) & 0xFF, y = (b >> s) & 0xFF;
    return (x + (y - x) * t).round().clamp(0, 255);
  }

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
