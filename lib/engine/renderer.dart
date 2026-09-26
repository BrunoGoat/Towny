import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/character.dart';
import '../fx/effects.dart';
import 'backdrop.dart';
import 'bsp.dart';
import 'folk.dart';
import 'folk_body.dart';
import 'palette.dart';
import 'scene.dart';
import 'sigils.dart';
import 'solid.dart';
import 'solids.dart';
import 'tones.dart';
import 'town.dart';
import 'world.dart';

int _ch(double v) {
  final i = (v * 255.0).round();
  return i < 0 ? 0 : (i > 255 ? 255 : i);
}

class _Face {
  final Float32List pts = Float32List(56);
  int n = 0;
  int color = 0;
}

/// The three colours a house is painted in.
class _Tone {
  const _Tone(this.wall, this.stone, this.tile);
  final Color wall, stone, tile;
}

/// Un edificio y lo que pide para pintarse: cuánta pantalla ocupa, cuántas
/// caras cuesta y si es del pueblo que se está mirando.
class _Gasto {
  const _Gasto(this.cluster, this.area, this.faces, this.mine);
  final Object cluster;
  final double area;
  final int faces;
  final bool mine;
}

/// Draws the whole world: sky, ground, the wall in full detail nearby, and its
/// own silhouette receding into the haze when it gets long.
class TownPainter extends CustomPainter {
  TownPainter(this.scene, this.hits);

  final TownScene scene;

  /// Lo que el fotograma deja marcado para que se pueda tocar.
  final TouchMap hits;

  List<PickTarget> get picks => hits.pieces;
  List<SignHit> get signs => hits.signs;
  List<BoardHit> get boards => hits.boards;
  List<LecternHit> get lecterns => hits.lecterns;
  List<SkyHit> get skies => hits.skies;

  /// Filled every frame: where each town's sign is, for the gesture layer.

  /// And where each town's notice board is.

  /// Y dónde quedó su atril.

  /// Se rellena al pintar: dónde cayó la constelación de esta noche.

  /// Y dónde cayó cada cúpula.

  /// Room for everything the budget can ask for, with slack. A face that does
  /// not fit here is silently not drawn, which is a hole in a house — so the
  /// pool has to stay ahead of the budget rather than the other way round.
  static final List<_Face> _facePool = List.generate(26000, (_) => _Face());
  static final Float64List _clipA = Float64List(96);
  static final Float64List _clipB = Float64List(96);
  static final Path _scratch = Path();

  int _faceCount = 0;

  /// El lienzo de este fotograma, para saber qué cae fuera.
  double _canvasW = 0, _canvasH = 0;

  /// Lo que se le perdona al borde: la costura que cierra cada cara es un
  /// trazo de un píxel de ancho, o sea medio a cada lado.
  static const double _borde = 1.5;

  /// Cuántas caras se tiraron por caer fuera del lienzo. No lo lee la app;
  /// lo lee el banco de pruebas.
  int culled = 0;

  /// Y cuántos edificios se quedaron sin pintar, separando los dos motivos:
  /// los que no tocan la pantalla —que no cuestan nada y no se ven— y los que
  /// no cupieron en el presupuesto, que son los únicos que alguien podría
  /// echar de menos.
  int offScreenWorks = 0, unaffordableWorks = 0;

  /// La llave para apagar el recorte, que existe **para poder demostrar que no
  /// se nota**: la prueba pinta la misma escena con él y sin él y exige que no
  /// cambie ni un píxel. Fuera de esa prueba no la toca nadie.
  static bool clipping = true;

  /// Esta cara lleva una lámpara apuntada y no se puede tirar aunque caiga
  /// fuera: el halo de una ventana mide hasta cien píxeles de radio, así que
  /// una ventana que se sale por el canto sigue alumbrando dentro.
  bool _lampHeld = false;

  /// Los edificios que este fotograma no pinta: los que no tocan la pantalla y
  /// los que no entraron en el presupuesto. Por identidad del grupo, que es lo
  /// que el recorrido tiene a mano.
  final Set<Object> _skip = {};

  /// Where the lit windows landed on screen this frame, so their light can be
  /// laid over the town after the masonry is down. x, y, radius, strength.
  final List<double> _lamps = [];

  /// Cuántos números lleva cada lámpara: dónde cae, cómo de grande, cuánto
  /// alumbra y a qué cara pertenece.
  static const int _lampStride = 5;

  /// True while the town being painted is the one being built, so a tap is
  /// only ever resolved against a piece of that town.
  bool _picking = false;

  /// The colours each house is painted in, worked out once per town.
  final Map<int, _Tone> _tone = {};

  /// Pieces already given a tap target this frame.

  /// How high the finishing wave has climbed, and how bright it still is.
  double _sweep = -1;
  double _sweepFade = 0;

  /// The piece in the air, built fresh every frame because it is the one thing
  /// in the town that moves.
  BspTree? _falling;
  int _fallingPiece = -1;

  /// Whether the piece in the air has gone down yet this frame, so it goes
  /// down exactly once — with its own building if that building was drawn, and
  /// at the end if it never was.
  bool _fallingPainted = false;

  _Face? _nextFace() {
    if (_faceCount >= _facePool.length) return null;
    return _facePool[_faceCount++];
  }

  @override
  void paint(Canvas canvas, Size size) {
    hits.clear();
    _pickAt.clear();
    _faceCount = 0;
    _lamps.clear();
    _canvasW = size.width;
    _canvasH = size.height;

    final p = scene.camera.projector(size.width, size.height, scene.time);
    final fondo = Backdrop(scene, skies);
    final horizonY = horizonOf(p, size);
    final town = scene.town;

    fondo.drawSky(canvas, size, p, horizonY);
    fondo.drawGround(canvas, size, horizonY);
    fondo.drawRanges(canvas, p, size, horizonY);
    // La fugaz va aquí y no dentro del cielo. Dentro del cielo la pintaban
    // encima las tres cordilleras, que con el encuadre de siempre ocupan todo
    // lo que hay por encima del horizonte menos una franja de cuarenta
    // píxeles: aunque saliera donde se está mirando, se veía la mitad de una
    // y a veces ninguna. Delante de los montes, además, su luz les cae encima.
    fondo.drawShootingStar(canvas, size, p, horizonY);
    // La gente se resuelve una vez por fotograma y se usa dos: para su sombra
    // en el suelo, que va debajo de todo, y para pintarla en su sitio del
    // orden, que va entre los edificios. Resolverla dos veces sería que la
    // sombra estuviera medio paso por detrás del pie.
    _folkNow.clear();
    final solo = scene.soloFolk;
    if (solo != null) {
      final talla = folkHeight(scene.towns.first.layout.character);
      final at = solo.at(scene.time);
      final screen = p.project(V3(at.x, talla * 0.6, at.z));
      if (screen != null) {
        _folkNow[0] = [
          _Walker(
            solo,
            at,
            talla,
            p.focal / math.max(screen.depth, 0.01) * talla,
            screen.depth,
          ),
        ];
      }
    } else {
      for (var i = 0; i < scene.towns.length; i++) {
        final e = scene.towns[i];
        final take = math.min(e.placed, e.layout.pieces.length);
        if (take > 0) {
          _folkNow[i] = _folkOut(p, e, scene.palette, take, size);
        }
      }
    }
    for (var i = 0; i < scene.towns.length; i++) {
      _drawTownGround(
        canvas,
        p,
        scene.towns[i].layout,
        _folkNow[i] ?? const [],
      );
    }
    _drawRings(canvas, p, town, overlay: false);
    _collectTown(p, size);
    _flush(canvas, size);
    _drawBirds(canvas, p, size, town);
    _drawRings(canvas, p, town, overlay: true);
    _drawTownGhost(canvas, p, size, town);
    _drawTownLabels(canvas, p, size, town);
    _drawTownSigns(canvas, p, size);
    _findBoards(p, size);
    _drawParticles(canvas, p);
    fondo.drawAtmosphere(canvas, size, horizonY);
    fondo.drawStarLight(canvas, size, p);
  }

  // ------------------------------------------------------------- far wall

  void _quad(Projector p, V3 a, V3 b, V3 c, V3 d, int color) {
    final pts = [a, b, c, d];
    for (var i = 0; i < 4; i++) {
      final cp = p.cameraOf(pts[i]);
      _clipA[i * 3] = cp.x;
      _clipA[i * 3 + 1] = cp.y;
      _clipA[i * 3 + 2] = cp.z;
    }
    _emit(p, _clipA, 4, color);
  }

  /// Clips a camera-space polygon, projects it and queues it.
  ///
  /// Queues, not sorts. Faces are painted in the order they arrive here, and
  /// the order they arrive in is already the right one: that is what the tree
  /// walk and the box ordering are for. A depth number per face was the old
  /// way, and a single number cannot say which of two faces that overlap in
  /// depth is in front — there is no such number, which is why every bug this
  /// renderer ever had came back at a different angle.
  void _emit(Projector p, Float64List cam, int count, int color) {
    final conLampara = _lampHeld;
    _lampHeld = false;
    final m = clipNear(cam, count, _clipB, p.near);
    if (m < 3) return;
    final f = _nextFace();
    if (f == null) return;
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    for (var i = 0; i < m; i++) {
      final z = _clipB[i * 3 + 2];
      final x = p.screenX(_clipB[i * 3], z);
      final y = p.screenY(_clipB[i * 3 + 1], z);
      f.pts[i * 2] = x;
      f.pts[i * 2 + 1] = y;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
    // **Lo que cae entero fuera del lienzo no se guarda.**
    //
    // Se pintaba igual: se proyectaba, se sombreaba, se le armaba el trazado y
    // se mandaban dos llamadas de dibujo para que la tarjeta gráfica la
    // descartara. Medido con la cámara donde la pone la app, **la mitad de las
    // caras de un fotograma no tocan ni un píxel**: 1 741 de 3 378 con
    // doscientas piezas.
    //
    // Y no puede cambiar lo que se ve, que es lo que hay que exigirle a algo
    // así. El recorte contra el plano cercano ya pasó, así que todos los
    // vértices están delante de la cámara y su proyección es finita; un
    // polígono convexo cabe entero dentro del rectángulo de sus vértices, de
    // modo que si ese rectángulo no toca el lienzo, el polígono tampoco. El
    // margen es por la costura, que sobresale medio píxel.
    //
    // Esto **no toca el orden**: quita de la lista caras que no pintan nada,
    // y el orden lo siguen decidiendo los planos del árbol como siempre.
    if (clipping &&
        !conLampara &&
        (x1 < -_borde ||
            y1 < -_borde ||
            x0 > _canvasW + _borde ||
            y0 > _canvasH + _borde)) {
      _faceCount--;
      culled++;
      return;
    }
    f.n = m;
    f.color = color;
  }

  // --------------------------------------------------------------- stones

  /// Dónde en qué índice de `picks` está cada pieza de este fotograma.
  final Map<int, int> _pickAt = {};

  void _registerPick(_Face f, int brickIndex, Size size, double near) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < f.n; i++) {
      final x = f.pts[i * 2], y = f.pts[i * 2 + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    if (maxX < 0 || minX > size.width || maxY < 0 || minY > size.height) return;
    final had = _pickAt[brickIndex];
    if (had != null) {
      picks[had].grow(minX, minY, maxX, maxY, near);
      return;
    }
    _pickAt[brickIndex] = picks.length;
    picks.add(
      PickTarget(
        brickIndex,
        minX,
        minY,
        maxX,
        maxY,
        near,
        scene.labelledBricks.contains(brickIndex),
      ),
    );
  }

  /// The lanes between the blocks, and the shadow each building sits in.
  void _drawTownGround(
    Canvas canvas,
    Projector p,
    TownLayout town, [
    List<_Walker> folk = const [],
  ]) {
    final pal = scene.palette;
    // Debajo de cada casa hubo un ejido de tierra pisada: un polígono pardo de
    // ocho lados, desdibujado, que se pintaba en el suelo alrededor. La idea
    // era el suelo que la gente pisa, gastado junto a la puerta; lo que se veía
    // era una mancha de barro con la casa flotando encima, y ocho de ellas una
    // al lado de otra convertían el prado en un mapa de manchas. El pueblo está
    // sobre hierba y sobre hierba se queda: lo único que hace falta para que
    // una casa no flote es su sombra de contacto, que es la de aquí abajo.

    // A soft pool of shade under each building. The wall gets a real projected
    // shadow; a hundred and fifty houses would cost far too much for that, and
    // at this size a contact shadow is what stops them floating anyway.
    final light = pal.lightDir;
    final drop = clampD(1.0 / math.max(0.25, light.y), 0.8, 2.4);
    for (final b in town.buildings) {
      if (b.placedPieces <= 0 || b.peakY <= 0.05) continue;
      final h = b.peakY;
      final at = p.project(
        V3(
          b.cx - light.x * drop * h * 0.35,
          0.006,
          b.cz - light.z * drop * h * 0.35,
        ),
      );
      if (at == null) continue;
      final r = p.focal / at.depth * (1.3 + h * 0.18);
      if (r < 2) continue;
      canvas.drawCircle(
        Offset(at.x, at.y),
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(at.x, at.y), r, [
            pal.ink.withValues(alpha: 0.20 * scene.integrity.clamp(0.5, 1.0)),
            pal.ink.withValues(alpha: 0),
          ]),
      );
    }

    // Y una debajo de cada vecino, que es lo único que lo pega al suelo.
    //
    // Va aquí, con las de los edificios y antes de la mampostería, y no
    // después: una sombra pintada al final es una mancha encima de la hierba
    // y de todo lo que haya en medio. Pintada aquí la tapa cualquier cosa que
    // esté delante, que es lo que hace una sombra.
    for (final v in folk) {
      final at = p.project(V3(v.at.x, 0.007, v.at.z));
      if (at == null) continue;
      final r = p.focal / at.depth * v.size * 0.42;
      if (r < 1.1) continue;
      canvas.drawCircle(
        Offset(at.x, at.y),
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(at.x, at.y), r, [
            pal.ink.withValues(alpha: 0.30 * pal.daylight),
            pal.ink.withValues(alpha: 0),
          ]),
      );
    }
  }

  /// A ghost of the piece that is about to be laid.
  ///
  /// The town always shows you the next thing it is waiting for: an outline
  /// standing where the piece will go, breathing on its own and firming up as
  /// the button is held. It is the difference between pressing a button and
  /// finishing something you can already see.
  void _drawTownGhost(Canvas canvas, Projector p, Size size, TownLayout town) {
    if (scene.fx != null) return; // one is already in flight
    final piece = town.pieceFor(scene.placed);
    if (piece == null) return;
    final pal = scene.palette;
    final charge = scene.charge;

    // A slow breath when idle, and a firm hold while the button is down.
    final breath = 0.5 + 0.5 * math.sin(scene.time * 2.1);
    final alpha = 0.16 + breath * 0.10 + charge * 0.55;

    final y0 = piece.y0, y1 = piece.y1;
    final x0 = piece.x0, x1 = piece.x1, z0 = piece.z0, z1 = piece.z1;
    if (p.cameraOf(V3(piece.cx, (y0 + y1) / 2, piece.cz)).z <= p.near) return;

    Offset? at(double x, double y, double z) {
      final q = p.project(V3(x, y, z));
      return q == null ? null : Offset(q.x, q.y);
    }

    final lo = [at(x0, y0, z0), at(x1, y0, z0), at(x1, y0, z1), at(x0, y0, z1)];
    final hi = [at(x0, y1, z0), at(x1, y1, z0), at(x1, y1, z1), at(x0, y1, z1)];
    if (lo.contains(null) || hi.contains(null)) return;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 + charge * 1.6
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        pal.accent,
        Colors.white,
        0.35 + charge * 0.4,
      )!.withValues(alpha: alpha);

    // Only the uprights and the top: a full cage reads as a bug report.
    final path = Path();
    for (var i = 0; i < 4; i++) {
      path
        ..moveTo(hi[i]!.dx, hi[i]!.dy)
        ..lineTo(hi[(i + 1) % 4]!.dx, hi[(i + 1) % 4]!.dy);
      // The corner posts, drawn as short ticks up from the ground.
      final a = lo[i]!, b = hi[i]!;
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(a.dx + (b.dx - a.dx) * 0.28, a.dy + (b.dy - a.dy) * 0.28)
        ..moveTo(b.dx - (b.dx - a.dx) * 0.28, b.dy - (b.dy - a.dy) * 0.28)
        ..lineTo(b.dx, b.dy);
    }
    canvas.drawPath(path, line);

    // A patch of light on the ground where it will land, so the eye knows
    // where to look even when the piece itself is a chimney on a far roof.
    final foot = at(piece.cx, math.max(0.02, y0), piece.cz);
    if (foot != null) {
      final q = p.cameraOf(V3(piece.cx, y0, piece.cz));
      final r =
          p.focal / q.z * math.max(piece.w, piece.d) * (0.7 + charge * 0.3);
      if (r > 2) {
        canvas.drawCircle(
          foot,
          r,
          Paint()
            ..shader = ui.Gradient.radial(foot, r, [
              Color.lerp(
                pal.accent,
                Colors.white,
                0.5,
              )!.withValues(alpha: 0.10 + charge * 0.30),
              const Color(0x00000000),
            ]),
        );
      }
    }
  }

  /// The ring that runs out across the ground when something lands or is
  /// finished. Two lines and it is the thing the eye actually follows.
  void _drawRings(
    Canvas canvas,
    Projector p,
    TownLayout town, {
    required bool overlay,
  }) {
    final pal = scene.palette;

    void ring(
      double cx,
      double cz,
      double r,
      double alpha,
      Color c,
      double width,
    ) {
      if (alpha <= 0.01 || r <= 0.02) return;
      const steps = 28;
      final path = Path();
      for (var i = 0; i <= steps; i++) {
        final a = i * 2 * math.pi / steps;
        final at = p.project(
          V3(cx + math.cos(a) * r, 0.02, cz + math.sin(a) * r),
        );
        if (at == null) return;
        if (i == 0) {
          path.moveTo(at.x, at.y);
        } else {
          path.lineTo(at.x, at.y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = c.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
    }

    final fx = scene.fx;

    // The shadow of the piece still in the air, closing under it as it comes
    // down. This is the whole of the anticipation: you can see exactly where it
    // is going and exactly how long it has left.
    if (!overlay && fx != null && !fx.landed) {
      final piece = town.pieceFor(fx.brickIndex);
      if (piece != null) {
        final up = fx.yOffset;
        final t = clampD(1 - up / 2.3, 0, 1);
        final at = p.project(V3(piece.cx, math.max(piece.y0, 0.02), piece.cz));
        if (at != null) {
          final base = math.max(piece.w, piece.d) * 0.55;
          final r = p.focal / at.depth * base * (1.7 - t * 0.85);
          if (r > 1.5) {
            canvas.drawCircle(
              Offset(at.x, at.y),
              r,
              Paint()
                ..shader = ui.Gradient.radial(Offset(at.x, at.y), r, [
                  pal.ink.withValues(alpha: 0.10 + t * 0.30),
                  pal.ink.withValues(alpha: 0),
                ]),
            );
          }
        }
      }
    }

    // The dust ring under a piece that has just landed. Drawn before the
    // masonry, because dust goes behind a wall; the gold below is light, and
    // light goes in front.
    if (!overlay && fx != null && fx.landed) {
      final piece = town.pieceFor(fx.brickIndex);
      if (piece != null) {
        final t = clampD(fx.sinceImpact / 0.55, 0, 1);
        ring(
          piece.cx,
          piece.cz,
          0.25 + t * 2.1,
          (1 - t) * (1 - t) * 0.55,
          Color.lerp(pal.stoneWarm, Colors.white, 0.4)!,
          2.4,
        );
      }
    }

    if (!overlay) return;

    // Two rings out from a building that has just been finished.
    final justDone = scene.finished;
    if (justDone != null && justDone < town.buildings.length) {
      final b = town.buildings[justDone];
      for (var i = 0; i < 2; i++) {
        final t = clampD((scene.finishedAge - i * 0.22) / 1.5, 0, 1);
        if (t <= 0) continue;
        final ease = 1 - math.pow(1 - t, 3).toDouble();
        ring(
          b.cx,
          b.cz,
          0.4 + ease * (b.isLandmark ? 7.5 : 4.4),
          (1 - t) * (1 - t) * (b.isLandmark ? 0.85 : 0.6),
          const Color(0xFFF2C25B),
          b.isLandmark ? 3.0 : 2.2,
        );
      }
    }
  }

  /// La luz que echa una ventana encendida. La mitad de lo que es un pueblo de
  /// noche es el halo alrededor de las ventanas, no las ventanas.
  ///
  /// **Se pinta en su sitio del orden, no al final.** Se pintaba al final,
  /// sobre el pueblo ya levantado, y eso en un rasterizador sin búfer de
  /// profundidad quiere decir exactamente lo que parece: el resplandor de una
  /// ventana de la fila de atrás salía **a través** de la casa de delante, y
  /// desde lejos el pueblo entero se veía con manchas cálidas encima de los
  /// tejados que las tapan. El halo es geometría como todo lo demás y tiene
  /// que ir donde le toca — detrás de lo que está delante.
  void _lampAt(Canvas canvas, Size size, Paint paint, int i) {
    final x = _lamps[i], y = _lamps[i + 1];
    final r = _lamps[i + 2] * 3.0, k = _lamps[i + 3];
    if (x < -r || x > size.width + r || y < -r || y > size.height + r) return;
    const warm = Color(0xFFFFC978);
    paint.shader = ui.Gradient.radial(
      Offset(x, y),
      r,
      [
        warm.withValues(alpha: 0.16 * k),
        warm.withValues(alpha: 0.055 * k),
        const Color(0x00000000),
      ],
      [0.0, 0.38, 1.0],
    );
    canvas.drawCircle(Offset(x, y), r, paint);
  }

  /// The sign over each town: its symbol, its name and how much of it is
  /// standing.
  ///
  /// This is the whole reason several towns share a valley. From far enough
  /// back you cannot read a house, but you can read four signs and see under
  /// each one how big and how lit its town is — which is the answer to "me
  /// está yendo bien con esto y mal con lo otro", said in one look.
  ///
  /// (See [_drawTownSigns] below; this doc belongs to it.)

  /// Where each town's notice board landed, so a finger can find it.
  ///
  /// Worked out from the plank's own four corners rather than from a marker
  /// hung over the town: the thing you tap is the thing you can see, and from
  /// far enough away that it is a smudge there is nothing to tap at all.
  ///
  /// Desde cualquier lado, eso sí. Antes sólo se podía tocar desde delante,
  /// porque por detrás la plancha es una plancha; pero uno orbita el pueblo
  /// mirando cosas y al llegar al tablón quiere entrar, no dar media vuelta
  /// primero. De canto sigue sin poder tocarse, y eso lo resuelve solo el
  /// mínimo de doce píxeles: de canto no hay nada a lo que apuntar.
  void _findBoards(Projector p, Size size) {
    for (var i = 0; i < scene.towns.length; i++) {
      final e = scene.towns[i];
      if (e.placed <= 0) continue;
      final l = e.layout;
      final board = _screenBox(p, size, NoticeBoard.faceAt(l.cx, l.cz));
      if (board != null) boards.add(BoardHit(i, board));
      final desk = _screenBox(p, size, Lectern.faceAt(l.cx, l.cz));
      if (desk != null) lecterns.add(LecternHit(i, desk));
    }
  }

  /// El rectángulo que ocupa en pantalla una cara del mundo, o nulo si no hay
  /// nada ahí a lo que apuntar.
  ///
  /// Lo comparten el tablón y el atril, que son la misma clase de cosa: un
  /// mueble pequeño en la plaza cuyas cuatro esquinas se conocen. Fuera del
  /// encuadre no hay blanco, y más pequeño que la yema de un dedo tampoco:
  /// nadie apuntaba a algo de ocho píxeles, y de canto un tablero no tiene
  /// ancho ninguno.
  Rect? _screenBox(Projector p, Size size, List<V3> face) {
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    for (final v in face) {
      final at = p.project(v);
      if (at == null) return null;
      if (at.x < x0) x0 = at.x;
      if (at.x > x1) x1 = at.x;
      if (at.y < y0) y0 = at.y;
      if (at.y > y1) y1 = at.y;
    }
    if (x1 - x0 < 12 && y1 - y0 < 12) return null;
    if (x1 < 0 || x0 > size.width || y1 < 0 || y0 > size.height) return null;
    return Rect.fromLTRB(x0, y0, x1, y1).inflate(9);
  }

  void _drawTownSigns(Canvas canvas, Projector p, Size size) {
    if (scene.towns.length < 2) return;
    final pal = scene.palette;
    final dark = darkSky(scene.palette);

    // Nearest first, so a sign never covers one in front of it.
    final rows = <(double, int)>[];
    for (var i = 0; i < scene.towns.length; i++) {
      final l = scene.towns[i].layout;
      final dx = l.cx - p.eye.x, dz = l.cz - p.eye.z;
      rows.add((dx * dx + dz * dz, i));
    }
    rows.sort((a, b) => a.$1.compareTo(b.$1));

    final taken = <Rect>[];
    for (final (_, i) in rows) {
      final e = scene.towns[i];
      final l = e.layout;
      // Over the top of the town, not over the middle of it.
      //
      // It used to hang at a height guessed from how wide the town is, which
      // for a small one is barely off the ground — so a plate wider than the
      // hamlet under it covered the hamlet completely. Now it clears whatever
      // the tallest thing standing is, and then lifts a fixed distance further
      // up the screen, which holds at any angle and any distance: the valley
      // view is for looking at the towns, so nothing in it may sit on one.
      final top = math.max(l.tallest, 2.0) + 0.8;
      final at = p.project(V3(l.cx, top, l.cz));
      if (at == null) continue;
      final y = at.y - 30;
      if (at.x < -140 || at.x > size.width + 140) continue;
      if (y < -60 || y > size.height + 60) continue;

      // Signs matter most from far away; up close the town speaks for itself.
      final d = at.depth;
      final near = clampD((d - 26) / 30, 0, 1);
      if (near <= 0.02) continue;
      final on = i == scene.active;

      final ink = on ? pal.accent : (dark ? Colors.white : pal.ink);
      final fade = (on ? 0.95 : 0.62) * near;
      // No plate and no frame any more: a soft halo, the same one every other
      // piece of type in this app sits on when it stands straight on the
      // scene. A card behind a name is a card in front of a town.
      final shadow = Shadow(
        color: (dark ? Colors.black : const Color(0xFF3A3426)).withValues(
          alpha: (dark ? 0.62 : 0.34) * near,
        ),
        blurRadius: 10,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: e.name.toUpperCase(),
          style: TextStyle(
            color: ink.withValues(alpha: fade),
            fontSize: 11,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
            shadows: [shadow],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // The habit's own drawn mark, painted rather than typed: it is the same
      // hand that drew the landmarks, and it looks the same on every phone.
      const glyph = 15.0;
      const crown = 12.0;
      final wears = e.crowned;
      final content = glyph + 8 + tp.width + (wears ? crown + 5 : 0);
      // Donde cae, y no donde quepa. Estaba recortado contra los dos bordes de
      // la pantalla, así que un pueblo que se iba de cuadro dejaba su nombre
      // pegado al canto: girar la cámara se sentía como que el cartel te
      // seguía. Un cartel está clavado en su pueblo; si el pueblo se sale, el
      // cartel se sale con él y se corta como se cortaría un cartel de verdad.
      final cx = at.x;
      final box = Rect.fromLTWH(cx - content / 2 - 8, y - 10, content + 16, 32);
      if (taken.any(box.overlaps)) continue;
      taken.add(box);
      // Generous: a sign is small and a thumb is not.
      signs.add(SignHit(i, box.inflate(10)));

      final left = cx - content / 2;
      HabitSigils.draw(
        canvas,
        Rect.fromLTWH(left, y - 4 + (tp.height - glyph) / 2, glyph, glyph),
        e.symbol,
        ink.withValues(alpha: fade),
      );
      final after = left + glyph + 8;
      tp.paint(canvas, Offset(after, y - 4));
      // The valley's crown, on whichever town has laid the most.
      if (wears) {
        HabitSigils.crown(
          canvas,
          Rect.fromLTWH(
            after + tp.width + 5,
            y - 4 + (tp.height - crown) / 2 + 1,
            crown,
            crown * 0.82,
          ),
          const Color(0xFFF2C25B).withValues(alpha: fade),
        );
      }

      // Y nada debajo del nombre. Había una regla que se llenaba según lo que
      // el pueblo llevara puesto, y es la clase de cosa que parece informativa
      // y miente: una barra de progreso dibuja un final, y un hábito no tiene
      // final. Lo que hay es cuánto pueblo hay, que se ve mirando el pueblo.
    }
  }

  /// A few birds turning over the town.
  ///
  /// They cost almost nothing and they do something no amount of masonry can:
  /// they make the sky part of the place. A town with birds over it is somewhere
  /// you are looking at; a town without them is a model on a table.
  /// Dónde va un pájaro de una bandada en este instante.
  ///
  /// Alrededor **de su pueblo**, y ése era el fallo: la circunferencia se
  /// trazaba sobre el origen del valle, así que sólo el pueblo que cae ahí
  /// tenía pájaros y los demás los tenían dando vueltas a cientos de unidades,
  /// fuera de cuadro. Se saca aparte para poder comprobarlo sin dibujar nada.
  @visibleForTesting
  static V3 birdAt(
    TownLayout town,
    double t,
    int flock,
    int i,
    double radius,
    double height,
  ) {
    final drift = hash01(flock, 7) * 6.28;
    final a =
        t * (flock == 0 ? 0.085 : -0.062) +
        drift +
        i * 0.34 +
        hash01(flock, i, 3) * 0.5;
    final wobble = math.sin(t * 0.7 + i * 1.3) * 0.9;
    return V3(
      town.cx + math.cos(a) * (radius + wobble),
      height + math.sin(t * 0.55 + i * 0.9) * 0.7,
      town.cz + math.sin(a) * (radius + wobble) * 0.8,
    );
  }

  /// Cuánto se aleja del centro de su pueblo cada bandada, y a qué altura va.
  @visibleForTesting
  static (double radius, double height) flockRing(TownLayout town, int flock) =>
      (town.radius * (flock == 0 ? 0.55 : 0.85) + 4, 7.0 + flock * 4.5);

  void _drawBirds(Canvas canvas, Projector p, Size size, TownLayout town) {
    final pal = scene.palette;
    if (!pal.isDaylight) return;
    final t = scene.time;
    final ink = pal.ink.withValues(alpha: 0.42);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = ink;

    // Two loose flocks on wide circles at different heights and speeds.
    for (var flock = 0; flock < 2; flock++) {
      final n = flock == 0 ? 5 : 3;
      final (radius, height) = flockRing(town, flock);
      for (var i = 0; i < n; i++) {
        final at = p.project(birdAt(town, t, flock, i, radius, height));
        if (at == null) continue;
        if (at.x < -40 || at.x > size.width + 40) continue;
        if (at.y < -40 || at.y > size.height + 40) continue;
        final s = clampD(p.focal / at.depth * 0.16, 1.4, 9.0);
        // The beat of the wings, which is the whole animation.
        final beat = math.sin(t * 7.5 + i * 2.1);
        final lift = s * 0.55 * beat;
        paint
          ..strokeWidth = math.max(0.9, s * 0.20)
          ..color = ink.withValues(alpha: clampD(s / 6, 0.12, 0.42));
        final path = Path()
          ..moveTo(at.x - s, at.y - lift * 0.4)
          ..quadraticBezierTo(at.x - s * 0.4, at.y - lift, at.x, at.y)
          ..quadraticBezierTo(
            at.x + s * 0.4,
            at.y - lift,
            at.x + s,
            at.y - lift * 0.4,
          );
        canvas.drawPath(path, paint);
      }
    }
  }

  /// The whole valley's masonry, in the one order that is right.
  ///
  /// Nothing here sorts faces. Each building is a tree that was cut and filed
  /// when its pieces were laid, and walking that tree from wherever the camera
  /// happens to stand gives its own faces in exactly the right order — no
  /// heuristics, no bias, nothing forced in front of anything. The buildings
  /// are then filed behind planes with nothing straddling them, so which side
  /// of each plane is nearer is decided by where the camera stands and by
  /// nothing else. The renderer never guesses which of two things is in front,
  /// because it is never in a position where it has to.
  void _collectTown(Projector p, Size size) {
    final pal = scene.palette;
    final light = pal.lightDir;
    final fx = scene.fx;
    final night = !pal.isDaylight;

    // El expositor de actividades: una persona en el prado y nada más. No hay
    // mampostería que ordenar, así que no hay orden que recorrer.
    if (scene.soloFolk != null) {
      _paintFolk(
        p,
        scene.towns.first,
        _folkNow[0] ?? const [],
        pal,
        light,
        size,
      );
      return;
    }

    // How high the finishing wave has climbed, and how bright it still is.
    _sweep = -1.0;
    _sweepFade = 0.0;
    final justDone = scene.finished;
    final active = scene.town;
    if (justDone != null && justDone < active.buildings.length) {
      final b = active.buildings[justDone];
      const rise = 0.85; // seconds from footings to ridge
      final t = scene.finishedAge / rise;
      if (t < 1.7) {
        _sweep = (b.peakY + 0.6) * t;
        _sweepFade = t <= 1 ? 1.0 : clampD(1 - (t - 1) / 0.7, 0, 1);
      }
    }

    // The piece in the air. It is the one thing in the town that moves, so it
    // is the one thing built fresh every frame.
    //
    // It used to be painted last, over the whole valley, on the grounds that
    // it is above the building it is coming down into. It is — but it is not
    // above the houses standing between it and the eye, and painting it last
    // put a chimney straight through the roof in front of it every time one
    // was laid. So it goes in at the place its own building goes in: the
    // clusters are already in a correct far-to-near order, so anything nearer
    // than its building is painted after it and covers it, which is what
    // being behind something means.
    _falling = null;
    _fallingPiece = -1;
    _fallingPainted = false;
    if (fx != null &&
        fx.brickIndex >= 0 &&
        fx.brickIndex < active.pieces.length &&
        fx.brickIndex < scene.towns[scene.active].placed) {
      final q = active.pieces[fx.brickIndex];
      final flying = <Facet>[];
      for (final solid in solidsOf(
        q,
        place: active.character,
        lift: fx.yOffset,
        squash: fx.squash.$2,
      )) {
        for (final f in solid.faces) {
          f.piece = solid.piece;
          flying.add(f);
        }
      }
      if (flying.isNotEmpty) {
        _falling = BspTree.build(flying);
        _fallingPiece = fx.brickIndex;
      }
    }

    // **En qué se gasta el fotograma lo que puede pagar.**
    //
    // Se gastaba de cerca a lejos y salía un corte por distancia: a partir de
    // tantos metros, nada. Eso hace exactamente lo que no hay que hacer — con
    // el teléfono justo de fuerzas desaparece medio pueblo de golpe, y
    // desaparece por detrás, que es donde está la mitad que da la sensación de
    // pueblo.
    //
    // Ahora se gasta por **lo que ocupa cada edificio en la pantalla**, y el
    // pueblo que se está mirando va primero entero. Un edificio del pueblo de
    // al lado, que mide doce píxeles al otro lado del valle, se cae de la
    // lista mucho antes que la casa de treinta mil que tenés delante — y a
    // doce píxeles no se nota que falte, que es la diferencia entre recortar y
    // amputar.
    //
    // Y lo que no toca la pantalla no se cuenta ni se recorre: no es una
    // decisión de presupuesto, es que no está.
    _skip.clear();
    final gasto = <_Gasto>[];
    for (var w = 0; w < scene.towns.length; w++) {
      final e = scene.towns[w];
      final take = math.min(e.placed, e.layout.pieces.length);
      if (take <= 0) continue;
      for (final c in builtTown(e.layout, take).clusters) {
        gasto.add(
          _Gasto(c, _onScreen(p, c.bounds), c.faces, w == scene.active),
        );
      }
    }
    gasto.sort((a, b) {
      if (a.mine != b.mine) return a.mine ? -1 : 1;
      final c = b.area.compareTo(a.area);
      return c != 0 ? c : a.faces.compareTo(b.faces);
    });
    var spend = 0;
    offScreenWorks = 0;
    unaffordableWorks = 0;
    for (final g in gasto) {
      if (g.area <= 0) {
        _skip.add(g.cluster);
        offScreenWorks++;
        continue;
      }
      spend += g.faces;
      if (spend > scene.budget) {
        _skip.add(g.cluster);
        unaffordableWorks++;
      }
    }

    // The towns themselves, farthest first. Each has its own plot with the
    // valley between them, so no two of them interleave and how far away they
    // are is the whole of their order.
    final towns = List<int>.generate(scene.towns.length, (i) => i);
    Aabb? boundsOf(TownEntry e) =>
        builtTown(e.layout, math.min(e.placed, e.layout.pieces.length)).bounds;
    towns.sort(
      (a, b) => _away(
        p,
        boundsOf(scene.towns[b]),
      ).compareTo(_away(p, boundsOf(scene.towns[a]))),
    );

    for (final w in towns) {
      final e = scene.towns[w];
      final take = math.min(e.placed, e.layout.pieces.length);
      // Cero piezas ya no quiere decir que no haya nada: está la plaza, que
      // llega con la fundación. Lo que se salta es el pueblo que ni siquiera
      // se fundó — el hueco vacío del valle.
      if (take <= 0 && !e.founded) continue;
      final root = builtTown(e.layout, take).root;
      if (root == null) continue;
      final decay = 1.0 - e.integrity;

      // El día que se funda, la plaza sube del suelo en vez de estar ya puesta.
      // Con cero piezas lo único que hay en el pueblo es ella, así que se pinta
      // aparte —levantada y en tres tiempos— y el árbol de siempre se salta.
      if (take <= 0 && scene.founding < 1.0) {
        _tone.clear();
        _paintFounding(p, e, pal, light, night, size);
        continue;
      }
      // Every town limewashes its houses its own way, so the colours are
      // worked out per town and not once for the valley.
      _tone.clear();
      _picking = w == scene.active;
      // La gente va **repartida por el árbol**, como todo lo demás.
      //
      // Lo intenté de la otra manera —llevarlos pendientes e ir soltando, antes
      // de cada hoja, a los que quedaran detrás de ella— y era peor, porque el
      // orden de las hojas no es una lista por distancia: es un orden de pintor,
      // que garantiza cada par pero no un total. Alguien delante de la casa A
      // quedaba detrás de la casa B, se le soltaba antes de B, y luego A
      // —pintada más tarde y de hecho más cerca— le caía encima. En pantalla
      // eso es un vecino al que la pared le tapa el cuerpo y le deja los pies
      // asomando, y se veía sólo desde arriba: desde el suelo el orden salía
      // bien por casualidad.
      //
      // El árbol no tiene ese problema. Un punto baja por los planos hasta una
      // hoja, y para cualquier otra hoja hay un plano que las separa y que lo
      // pone del mismo lado que la suya. Su sitio en el orden es el de su hoja,
      // y eso sí es exacto.
      final vecinos = _folkNow[w] ?? const <_Walker>[];
      walkOrderWith<_Walker>(
        root,
        p.eye,
        vecinos,
        (v, axis) => switch (axis) {
          0 => (v.at.x, v.at.x),
          // De los pies a la coronilla. Una persona no es un punto: contra un
          // plano horizontal a media altura está en los dos lados.
          1 => (0.0, v.size),
          _ => (v.at.z, v.at.z),
        },
        (leaf, aqui) {
          final box = leaf.bounds;
          if (p.cameraOf(V3(box.cx, box.cy, box.cz)).z + box.radius < p.near) {
            // Se salta la mampostería, no a la gente: alguien puede estar
            // andando por delante de un edificio que la cámara ya dejó atrás.
            _paintFolk(p, e, aqui, pal, light, size);
            return;
          }
          final c = leaf.cluster;
          if (c == null) {
            _emitWeather(
              p,
              e,
              e.layout.pieces[leaf.weather],
              pal,
              night,
              decay,
            );
            _paintFolk(p, e, aqui, pal, light, size);
            return;
          }
          if (_skip.contains(c)) {
            _paintFolk(p, e, aqui, pal, light, size);
            return;
          }
          final mine = w == scene.active && c.members.contains(_fallingPiece);
          // Y dentro de su propia hoja, cada vecino cae **por el árbol del
          // edificio**, no a un lado o a otro de su caja.
          //
          // Se repartían comparándolos con la caja envolvente de la hoja, y una
          // caja no es un edificio: hay hojas cuya caja abarca media parcela
          // —las que llevan el sembrado, el agua o una bandera— y ahí dentro
          // cae todo el mundo, así que no había eje que separase a nadie y
          // todos se pintaban por delante. De ahí que se viera a la gente a
          // través de unos edificios y de otros no: dependía de lo apretada
          // que fuera la caja de cada uno, que es exactamente la clase de cosa
          // que en este valle no decide nada.
          //
          // El árbol son los planos de las propias paredes. Un punto contra un
          // plano está de un lado o del otro y no hay discusión, que es el
          // mismo criterio con el que se ordenan entre sí las caras del
          // edificio.
          c.tree.paintWith<_Walker>(
            p.eye,
            aqui,
            (v, n, d) {
              // **Por donde pisa, y no de los pies a la coronilla.**
              //
              // Lo primero que probé fue lo segundo: una persona mide lo suyo
              // de alto, así que contra un plano horizontal está en los dos
              // lados, y ahí no hay orden correcto — se elegía el lado del ojo.
              // Medido sobre el catálogo entero desde ocho ángulos, eso deja
              // trescientos sesenta y siete encuadres con alguien asomando por
              // una pared; con el punto del pie quedan seis.
              //
              // El motivo es que los planos que parten un edificio son sus
              // suelos y sus faldones, y quien está de pie en la calle los
              // cruza todos por el medio: al mandarlo al lado del ojo se iba
              // por delante del tejado, y la pared de la fachada —que vive al
              // otro lado de ese mismo plano— se pintaba antes que él. Por
              // donde pisa no hay empate que resolver, y el pie es además lo
              // único de una persona que está de verdad en un sitio.
              final base = n.x * v.at.x + n.z * v.at.z - d;
              return (base, base);
            },
            (f) {
              // `f.piece >= 0` matters: the town's own furniture is filed under
              // no achievement at all, and "no achievement" must not collide
              // with "the achievement that is in the air right now".
              if (w == scene.active &&
                  f.piece >= 0 &&
                  f.piece == _fallingPiece) {
                return;
              }
              _paint(p, e, f, pal, light, night, decay, size);
            },
            (gente) => _paintFolk(p, e, gente, pal, light, size),
          );
          // Straight after the building it belongs to, and before any building
          // nearer than that one.
          if (mine) _paintFalling(p, e, pal, light, night, size);
        },
      );
    }

    // If its own building never came up — filed away by the budget, or off
    // the side of the screen — the piece still has to be seen: it is the one
    // thing the person is looking at right now.
    if (_falling != null && !_fallingPainted) {
      final e = scene.towns[scene.active];
      _tone.clear();
      _picking = true;
      _paintFalling(p, e, pal, light, night, size);
    }
  }

  // Aquí vivían `_folkSides` y `_behind`, que repartían a la gente de una hoja
  // en «detrás de la caja» y «delante de la caja».
  //
  // Se fueron enteros. Una caja envolvente no es un edificio, y con hojas cuya
  // caja abarca media parcela —el sembrado, el agua, una bandera— no había eje
  // que separase a nadie y todos caían del lado de delante. Ahora el reparto lo
  // hace el árbol del propio edificio, que son los planos de sus paredes: ver
  // [BspTree.paintWith].

  /// La gente que hay ahora mismo en la calle de este pueblo, ya colocada.
  ///
  /// Se resuelve una vez por pueblo y por fotograma, no una vez por hoja del
  /// árbol: el recorrido los reparte, no los vuelve a calcular.
  /// La gente de cada pueblo, ya resuelta para este fotograma.
  final Map<int, List<_Walker>> _folkNow = {};

  List<_Walker> _folkOut(
    Projector p,
    TownEntry e,
    Palette pal,
    int take,
    Size size,
  ) {
    if (!scene.folk) return const [];
    final dentro = folkHome(pal.daylight);
    if (dentro > 0.985) return const [];
    final cuantos = folkOut(e.integrity);
    final talla = folkHeight(e.layout.character);
    final out = <_Walker>[];
    for (final who in folkOf(e.layout, take)) {
      // Los que hoy no salen. Por la semilla y no al azar, para que no haya
      // uno parpadeando entre existir y no existir cada fotograma.
      if (hash01(who.seed, 11) > cuantos) continue;

      // Descartar **antes** de calcular dónde anda.
      //
      // Saber dónde está uno cuesta recorrerle la ronda, y las dos pruebas de
      // más abajo —que se salga del cuadro, que no llegue a dos píxeles de
      // alto— sólo se podían hacer después de haberla pagado. Medido sobre un
      // valle de seis pueblos: quinientos cincuenta y siete vecinos resueltos
      // enteros, cada fotograma, para dibujar cincuenta y dos. Los otros cinco
      // pueblos están al otro lado del valle.
      //
      // Aquí se usa el círculo que contiene la ronda entera de uno, así que
      // las dos pruebas se hacen sobre **el caso más favorable posible**: lo
      // más cerca de la cámara que podría llegar a estar, y lo más adentro del
      // cuadro. Quien no pasa ni así no se ve a ninguna hora del día. Las
      // pruebas exactas siguen debajo y siguen decidiendo — esto sólo se ahorra
      // trabajo, nunca cambia quién sale.
      final ronda = who.roam;
      final centro = p.project(V3(ronda.x, talla * 0.6, ronda.z));
      if (centro == null) continue;
      final cerca = math.max(centro.depth - ronda.r, 0.01);
      if (p.focal / cerca * talla < 2.2) continue;
      final radio = p.focal / cerca * ronda.r;
      if (centro.x + radio < -60 ||
          centro.y + radio < -60 ||
          centro.x - radio > size.width + 60 ||
          centro.y - radio > size.height + 60) {
        continue;
      }

      var at = who.at(scene.time);
      if (dentro > 0.001) {
        // Cae la tarde: cada uno tira para su puerta. No es un camino
        // calculado, es la línea recta a su casa — y como todos arrancan
        // desde donde estaban, se ve un pueblo entero yéndose a casa a la vez,
        // que es exactamente lo que pasa a esa hora.
        final k = smoothstep(0.0, 0.86, dentro);
        final d = who.door;
        at = FolkAt(
          lerpD(at.x, d.$1, k),
          lerpD(at.z, d.$2, k),
          at.heading,
          at.gait,
          at.moving && k < 0.9,
          // De camino a casa no se charla ni se suelta una cometa: lo que se
          // hace es andar. Quien ya estaba andando sigue andando.
          null,
          at.phase,
        );
      }
      // Y en el umbral se meten dentro: se hunden en su propia puerta en vez
      // de apagarse en el aire.
      final hunde = clampD((dentro - 0.86) / 0.14, 0, 1);
      if (hunde >= 0.999) continue;
      final screen = p.project(V3(at.x, talla * 0.6, at.z));
      if (screen == null) continue;
      if (screen.x < -60 ||
          screen.y < -60 ||
          screen.x > size.width + 60 ||
          screen.y > size.height + 60) {
        continue;
      }
      // Cuánto se lee de él en pantalla, para no gastar piernas en dos
      // píxeles. Un vecino mide `talla` de alto: esto es lo que ocupa.
      final alto = p.focal / math.max(screen.depth, 0.01) * talla;
      if (alto < 2.2) continue;
      out.add(_Walker(who, at, talla * (1 - hunde), alto, screen.depth));
    }
    // Si no caben todos, se van los de más lejos.
    //
    // Antes se cortaba por orden de lista y se paraba en sesenta, y eso hacía
    // que la gente se esfumara en mitad de la pantalla: quién pasa los filtros
    // cambia al andar —uno se va del cuadro, otro se acerca— y con el corte
    // por orden de lista, el que se cae del sesenta puede ser el que tenés
    // delante. Por distancia, el que se cae es siempre el más chico de todos.
    // Y entre personas pasaba lo mismo que entre las cajas de una: se pintaban
    // en el orden en que salen del plano, que no tiene nada que ver con cuál
    // está delante. Dos vecinos que se cruzan en una calle estrecha se
    // atravesaban según quién viviera en la casa de número más bajo.
    //
    // Ordenados de cerca a lejos se recorta el tope —el que se cae es siempre
    // el más chico— y se pintan del revés, que es el orden en que hay que
    // pintarlos.
    out.sort((a, b) => a.depth.compareTo(b.depth));
    if (out.length > _folkCap) out.length = _folkCap;
    return out.reversed.toList();
  }

  /// Lo que mide una persona hecha, en un pueblo de esta región.
  ///
  /// Medido contra el propio pueblo y no a ojo, que es como estaba y por eso
  /// eran enanos. Las dos reglas salen de lo que el pueblo ya construye:
  ///
  ///  - una planta mide `1.155 * storey` de suelo a techo, y una persona son
  ///    dos tercios largos de eso;
  ///  - una ventana mide el cuarenta por ciento de la planta, o sea
  ///    `0.46 * storey`, y una persona es una ventana y media.
  ///
  /// Las dos dan el mismo número, que es la señal de que el número es ése. Con
  /// el 0.58 que tenía, una persona medía **media planta** y era más baja que
  /// la ventana por la que se asoma. Probado también a 1.0, y ahí pasa lo
  /// contrario: gigantes que le llegan al alero a su propia casa.
  ///
  /// Pública para poder exigirlo en un test contra las medidas de verdad de un
  /// pueblo levantado. Un número a ojo en mitad del render es exactamente la
  /// clase de cosa que nadie vuelve a mirar.
  /// Y un cuarto menos de lo que decía la cuenta, porque lo que la cuenta da
  /// es lo que mide una persona **de verdad**, y aquí las cabezas ocupan media
  /// figura. Con la talla exacta salían gigantes cabezones; a tres cuartos la
  /// silueta se posa bien contra las puertas y los aleros, que es lo que se
  /// mira. Es la única cifra de esto que no sale de una medida sino del ojo, y
  /// por eso va aparte y dicha.
  static double folkHeight(TownCharacter place) => 0.80 * 0.75 * place.storey;

  /// Cuántos se pintan como mucho.
  ///
  /// Un pueblo de dos mil piezas tiene cuatrocientas casas, y cuatrocientas
  /// personas son doce mil caras que se mueven todos los fotogramas. Sesenta
  /// es más gente de la que se distingue en una pantalla de teléfono.
  ///
  /// Subió de sesenta a ochenta cuando la gente empezó a descartar sus caras
  /// traseras: una figura pasó de doce caras a seis y de cuatro cajas a tres,
  /// así que ochenta cuestan hoy menos que sesenta ayer. Y cuanto más alto el
  /// tope, más lejos queda el que se cae de él.
  static const int _folkCap = 80;

  void _paintFolk(
    Projector p,
    TownEntry e,
    List<_Walker> folk,
    Palette pal,
    V3 light,
    Size size,
  ) {
    if (folk.isEmpty) return;
    for (final v in folk) {
      final solids = folkSolids(
        v.who,
        v.at,
        v.size,
        // Tres escalones y no dos: por debajo de catorce píxeles se van las
        // piernas y las mariposas, y por debajo de ocho se van también los
        // brazos. La cometa no se va nunca — es lo que se ve desde lejos.
        detail: v.pixels > 14
            ? 1.0
            : v.pixels > 8
            ? 0.35
            : 0.05,
      );

      // **De atrás hacia delante, y no en el orden en que se hicieron.**
      //
      // Descartar las caras traseras deja exacto el interior de *una* caja
      // cerrada, pero no dice nada de en qué orden van dos cajas distintas — y
      // una persona son cuatro o cinco: cuerpo, cabeza, pelo, y lo que lleve.
      // Se pintaban en el orden en que se crean, y lo que lleva se crea el
      // último, así que el libro se pintaba **siempre** encima del cuerpo. De
      // frente daba el pego; desde detrás se veía el libro atravesando a quien
      // lo estaba leyendo, que es exactamente lo que no puede pasar en un
      // valle que presume de ordenar por geometría y no por una media.
      //
      // Aquí sí vale una media, y no es una excepción a la regla del pueblo:
      // las cajas de una persona son pocas, convexas, del tamaño de un puño y
      // **no se atraviesan entre ellas** — el libro está delante del pecho, el
      // pelo encima de la cabeza. Con sólidos separados, ordenar por su centro
      // da el mismo orden que daría un plano de separación, y cuesta cinco
      // comparaciones en vez de un árbol por vecino y por fotograma.
      for (final solid in folkInPaintOrder(solids, p.eye)) {
        for (final f in solid.faces) {
          // Las que miran para el otro lado, fuera.
          //
          // Es la regla de toda la mampostería del valle —un sólido cerrado no
          // enseña sus caras de dentro— y la gente se la estaba saltando: se
          // pintaba por `_plain`, que no la aplica, así que cada caja sacaba
          // sus seis caras y la de atrás caía encima de la de delante. De ahí
          // que no acabaran de parecer sólidos y que según el ángulo se
          // comieran una cara.
          final a = f.v.first;
          if ((p.eye.x - a.x) * f.n.x +
                  (p.eye.y - a.y) * f.n.y +
                  (p.eye.z - a.z) * f.n.z <=
              0) {
            continue;
          }
          _plain(p, f, pal, light, 0);
        }
      }
    }
  }

  /// La plaza saliendo de la tierra, en tres tiempos: primero el enlosado,
  /// que es lo que dice dónde está el centro; después el tablón, que es lo que
  /// el pueblo va a decir de vos; y por último el atril, que es donde va a
  /// quedar escrito lo que digas vos.
  ///
  /// Se arma un árbol nuevo cada fotograma, como con la pieza que cae y por lo
  /// mismo: lo único que se mueve en todo el valle no puede salir de una caché
  /// que existe precisamente porque nada se mueve. Son tres docenas de caras
  /// durante segundo y medio.
  void _paintFounding(
    Projector p,
    TownEntry e,
    Palette pal,
    V3 light,
    bool night,
    Size size,
  ) {
    final l = e.layout;
    final caras = <Facet>[];
    void alzar(List<Solid> solidos, double k) {
      final t = _suave(k.clamp(0.0, 1.0));
      if (t <= 0.001) return;
      // Sale de debajo del suelo. Metro y medio basta: lo que tiene que leerse
      // es que sube, no de dónde.
      final dy = (t - 1.0) * 1.5;
      for (final s in solidos) {
        for (final f in s.faces) {
          caras.add(dy.abs() < 1e-4 ? f : f.lifted(dy));
        }
      }
    }

    final t = scene.founding;
    alzar(Plaza.solidsAt(l.cx, l.cz, TownLayout.plazaReach), t / 0.5);
    alzar(
      NoticeBoard.solidsAt(l.cx, l.cz, sheets: l.notices),
      (t - 0.3) / 0.45,
    );
    alzar(Lectern.solidsAt(l.cx, l.cz), (t - 0.55) / 0.45);
    if (caras.isEmpty) return;
    BspTree.build(
      caras,
    ).paint(p.eye, (f) => _paint(p, e, f, pal, light, night, 0, size));
  }

  static double _suave(double t) => t * t * (3 - 2 * t);

  void _paintFalling(
    Projector p,
    TownEntry e,
    Palette pal,
    V3 light,
    bool night,
    Size size,
  ) {
    final falling = _falling;
    if (falling == null || _fallingPainted) return;
    _fallingPainted = true;
    falling.paint(
      p.eye,
      (f) => _paint(p, e, f, pal, light, night, 1.0 - e.integrity, size),
    );
  }

  /// How far a box is from the eye, squared, which is all a sort needs.
  static double _away(Projector p, Aabb? b) {
    if (b == null) return double.infinity;
    final dx = b.cx - p.eye.x, dy = b.cy - p.eye.y, dz = b.cz - p.eye.z;
    return dx * dx + dy * dy + dz * dz;
  }

  /// Cuántos píxeles de pantalla ocupa una caja, o cero si no toca ninguno.
  ///
  /// Se proyectan las ocho esquinas. Si alguna se queda detrás del plano
  /// cercano la cuenta no vale —la cámara está dentro de la caja o casi— y
  /// entonces se devuelve el lienzo entero: ante la duda, es importante.
  ///
  /// **El margen es grande a propósito.** No es para curarse en salud con el
  /// borde: es que una ventana encendida deja un halo de hasta cien píxeles de
  /// radio, así que un edificio que se salió por el canto todavía puede estar
  /// alumbrando dentro. Saltárselo cambiaría lo que se ve, y eso es
  /// exactamente lo que no puede pasar.
  double _onScreen(Projector p, Aabb? b) {
    if (b == null) return 0;
    const halo = 110.0;
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    var detras = 0;
    for (var i = 0; i < 8; i++) {
      final at = p.project(
        V3(
          i & 1 == 0 ? b.x0 : b.x1,
          i & 2 == 0 ? b.y0 : b.y1,
          i & 4 == 0 ? b.z0 : b.z1,
        ),
      );
      // Las ocho esquinas detrás del plano cercano quieren decir que la caja
      // entera está detrás —es convexa, no hay forma de que asome— y eso sí
      // se puede saltar. Unas cuantas detrás y otras delante, no: ahí la
      // proyección no acota nada y hay que darla por importante.
      if (at == null) {
        detras++;
        continue;
      }
      if (at.x < x0) x0 = at.x;
      if (at.x > x1) x1 = at.x;
      if (at.y < y0) y0 = at.y;
      if (at.y > y1) y1 = at.y;
    }
    if (detras == 8) return 0;
    if (detras > 0) return _canvasW * _canvasH;
    if (x1 < -halo ||
        y1 < -halo ||
        x0 > _canvasW + halo ||
        y0 > _canvasH + halo) {
      return 0;
    }
    final w = math.min(x1, _canvasW) - math.max(x0, 0.0);
    final h = math.min(y1, _canvasH) - math.max(y0, 0.0);
    // Dentro del margen pero fuera del lienzo: no se ve, pero puede alumbrar,
    // así que cuesta lo mínimo y no se salta.
    if (w <= 0 || h <= 0) return 1;
    return w * h;
  }

  /// The wind-blown half of a piece: what a tree filed once cannot hold.
  void _emitWeather(
    Projector p,
    TownEntry e,
    TownPiece piece,
    Palette pal,
    bool night,
    double decay,
  ) {
    switch (piece.kind) {
      case PieceKind.field:
        _emitField(p, piece, piece.y0, pal, decay);
      case PieceKind.water:
        _emitWater(p, piece, piece.y0, pal, night);
      case PieceKind.sail:
        _emitSails(p, piece, piece.y0, piece.y1, pal.lightDir, pal);
      case PieceKind.banner:
        _emitBanner(p, piece, piece.y0, piece.y1, pal);
      default:
        break;
    }
  }

  /// Paints one face of something built.
  ///
  /// The only visibility decision left in the renderer, and it is the one that
  /// is always right: a face of a closed solid is seen exactly when the eye is
  /// on its outward side. There is no inside of a house here, so every face
  /// has a twin looking the other way and exactly one of the two is turned
  /// towards you — which is why a roof can no longer lose half of itself by
  /// being looked at from the wrong place.
  void _paint(
    Projector p,
    TownEntry e,
    Facet f,
    Palette pal,
    V3 light,
    bool night,
    double decay,
    Size size,
  ) {
    final v = f.v;
    final a = v[0];
    final eye = p.eye;
    if ((eye.x - a.x) * f.n.x + (eye.y - a.y) * f.n.y + (eye.z - a.z) * f.n.z <=
        0) {
      return;
    }
    // The notice board belongs to the town rather than to any achievement, so
    // it has no piece to take its colour or its weathering from. It takes them
    // from the town instead: a place nobody has been to in a month has a
    // weathered board like everything else in it.
    if (f.piece < 0) {
      _plain(p, f, pal, light, decay);
      return;
    }
    if (f.piece >= e.layout.pieces.length) return;
    final piece = e.layout.pieces[f.piece];
    final tone = _toneOf(e, piece, pal, decay);
    final colour = _colourOf(p, f, piece, tone, pal, light, decay, night);
    if (colour == null) return;
    _push(p, v, colour, piece, size);
    final decals = f.decals;
    if (decals == null) return;
    for (final g in decals) {
      final c = _colourOf(p, g, piece, tone, pal, light, decay, night);
      if (c != null) _push(p, g.v, c, piece, size);
    }
  }

  /// A face with no achievement behind it: the town's own furniture.
  void _plain(Projector p, Facet f, Palette pal, V3 light, double decay) {
    final at = f.v.first;
    // La ropa no se desgasta: quien la lleva no es del pueblo, vive en él. Y
    // en un pueblo apagado hace falta que a los pocos que quedan se los vea.
    final tono = _plainTone(f, at, pal);
    final albedo = f.surface == Surface.cloth ? tono : _weather(tono, decay, 0);
    final colour = hazeAt(
      _shade(f.n, albedo, light, pal, f.ao, 0, 0, f.surface),
      p,
      at.x,
      at.z,
      pal,
    ).toARGB32();
    _push(p, f.v, colour, null, null);
    final decals = f.decals;
    if (decals == null) return;
    for (final g in decals) {
      final c = hazeAt(
        _shade(
          g.n,
          g.surface == Surface.cloth
              ? _plainTone(g, at, pal)
              : _weather(_plainTone(g, at, pal), decay, 0),
          light,
          pal,
          g.ao,
          0,
          0,
          g.surface,
        ),
        p,
        at.x,
        at.z,
        pal,
      ).toARGB32();
      _push(p, g.v, c, null, null);
    }
  }

  void _push(
    Projector p,
    List<V3> v,
    int colour,
    TownPiece? piece,
    Size? size,
  ) {
    final m = v.length;
    if (m < 3 || m > 24) {
      _lampHeld = false;
      return;
    }
    for (var i = 0; i < m; i++) {
      final q = v[i];
      final cp = p.cameraOf(q);
      _clipA[i * 3] = cp.x;
      _clipA[i * 3 + 1] = cp.y;
      _clipA[i * 3 + 2] = cp.z;
    }
    final before = _faceCount;
    _emit(p, _clipA, m, colour);
    if (piece == null || size == null) return;
    // Todas sus caras, no la primera: la caja de una pieza es la de todo lo
    // que se ve de ella.
    if (_picking && _faceCount > before) {
      var near = double.infinity;
      for (var i = 0; i < m; i++) {
        final z = _clipA[i * 3 + 2];
        if (z < near) near = z;
      }
      _registerPick(
        _facePool[before],
        piece.index,
        size,
        math.max(near, p.near),
      );
    }
  }

  /// The colours a house is painted in. They belong to the house, not to the
  /// piece: a wall that changes tone halfway up, or a dormer that does not
  /// match its own roof, is the fastest way to make a town look like a pile of
  /// blocks.
  _Tone _toneOf(TownEntry e, TownPiece piece, Palette pal, double decay) {
    final key = piece.building;
    final had = _tone[key];
    if (had != null) return had;
    final h = hash32(piece.building, 0x51ed, 3);
    final ch = e.layout.character;
    // A house is plaster over stone: pale walls, a stone base, a warm roof.
    // Plaster takes a limewash, and every town has one it favours: Ribera is
    // white, Marca ochre, Costa indigo. Most houses take the local colour and
    // the rest go their own way, which is what stops a town reading as one
    // material repeated — and what makes two towns two places.
    final warm = hash01(h, 1);
    var wall = Color.lerp(pal.stoneCool, pal.stoneWarm, 0.35 + warm * 0.55)!;
    final wash = hash01(h, 2);
    if (wash < ch.washShare) {
      // At a third of the way the wash was not a colour, it was a hint of one:
      // the pale stone underneath won every time, and a town whose limewash is
      // indigo came out grey while the one whose limewash is ochre came out
      // beige — every region within a twelfth of every other. What varies now
      // is how much of the same wash a house took, not whether it took it, so
      // a street reads as one limewash weathered differently rather than as
      // six houses that never agreed on a colour.
      wall = Color.lerp(wall, ch.wash, 0.52 + hash01(h, 21) * 0.30)!;
    } else if (wash < ch.washShare + 0.07) {
      wall = Color.lerp(wall, const Color(0xFFC9836E), 0.34)!;
    } else if (wash < ch.washShare + 0.12) {
      wall = Color.lerp(wall, const Color(0xFFA8B47A), 0.28)!;
    }
    // What this roof is made of was settled when the town was laid out — the
    // straw ones are a different shape, so it had to be — and this only asks.
    // It used to roll its own hash here from the same mix, which meant two
    // files agreeing by hand about which houses were thatched.
    final b = piece.building;
    final marks = e.layout.buildings;
    final stuff = b >= 0 && b < marks.length ? marks[b].roof : RoofStuff.tile;
    final base = switch (stuff) {
      RoofStuff.tile => const Color(0xFFC05C38),
      RoofStuff.slate => const Color(0xFF5B6B72),
      RoofStuff.thatch => const Color(0xFFC2A054),
    };
    return _tone[key] = _Tone(
      wall,
      Color.lerp(pal.stoneCool, pal.stone, 0.55)!,
      Color.lerp(base, pal.stone, 0.08)!,
    );
  }

  /// What one face looks like right now, or null when it is not there at all —
  /// a plank across a window that nobody has abandoned yet.
  int? _colourOf(
    Projector p,
    Facet f,
    TownPiece piece,
    _Tone tone,
    Palette pal,
    V3 light,
    double decay,
    bool night,
  ) {
    final s = piece.seed;
    var flash = 0.0;
    if (_sweep >= 0 && piece.building == scene.finished) {
      final d = (piece.y0 - _sweep).abs();
      if (d < 0.9) flash = (1 - d / 0.9) * (1 - d / 0.9) * _sweepFade;
    }
    final fx = scene.fx;
    if (fx != null && fx.brickIndex == piece.index) flash = fx.flash;

    Color albedo;
    switch (f.surface) {
      case Surface.wall:
        albedo = _weather(tone.wall, decay, s);
      case Surface.stone:
        albedo = _weather(tone.stone, decay, s);
      case Surface.tile:
        albedo = _weather(tone.tile, decay, s);
      case Surface.thatch:
        // Straw is not a painted surface, it is a heaped one: every plane of
        // a thatched roof takes a step of its own so the thing reads as
        // bundles laid by hand and not as a wedge the colour of straw.
        albedo = _weather(
          Color.lerp(tone.tile, pal.stone, hash01(s, 17 + f.data) * 0.16)!,
          decay,
          s,
        );
      case Surface.brick:
        albedo = _weather(const Color(0xFF8C6A52), decay, s);
      case Surface.own:
        albedo = _weather(Color(f.tint ?? 0xFF808080), decay, s);
      case Surface.cloth:
        // La ropa no se desgasta con el abandono del pueblo, porque quien la
        // lleva no es del pueblo: es quien vive en él.
        albedo = Color(f.tint ?? 0xFF808080);
      case Surface.leaf:
        final leaf = leafOfYear(
          Color.lerp(
            const Color(0xFF4E5C3C),
            const Color(0xFF6E7448),
            hash01(s, 11),
          )!,
          s,
          pal.season,
        );
        // Pulled towards the ground's own tone so a tree reads as part of the
        // landscape rather than as a green block dropped onto it.
        albedo = Color.lerp(
          Color.lerp(leaf, pal.ground, 0.28)!,
          const Color(0xFF8A6E42),
          decay * 0.6,
        )!;
      case Surface.hollow:
        // The dark inside an arch is a shadow, not a surface: it is not lit,
        // and lighting it is what turns an opening into a grey sticker.
        return hazeAt(
          Color.lerp(pal.ink, tone.stone, 0.22)!,
          p,
          piece.cx,
          piece.cz,
          pal,
        ).toARGB32();
      case Surface.window:
        return _window(p, f, piece, pal, decay, night);
      case Surface.plank:
        if (!_shut(f, piece, decay, night)) return null;
        return hazeAt(
          _weather(const Color(0xFF7A6549), decay, s),
          p,
          piece.cx,
          piece.cz,
          pal,
        ).toARGB32();
    }
    return hazeAt(
      _shade(f.n, albedo, light, pal, f.ao, flash, 0, f.surface),
      p,
      piece.cx,
      piece.cz,
      pal,
    ).toARGB32();
  }

  /// Whether this window has a light on behind it.
  ///
  /// One place, because two places is what it was: the same expression written
  /// out twice, in the code that paints a window and in the code that decides
  /// whether to board one up, and two copies of a rule are two rules waiting
  /// to disagree.
  ///
  /// At full health every window is lit, which is what the app has been saying
  /// all along — «todas las ventanas encendidas» — while this quietly lit
  /// seventy-two per cent of them and left the rest dark on a town that had
  /// nothing wrong with it. They go out as the days without a piece add up,
  /// and always in the same order, so a town empties in a way you can
  /// recognise instead of flickering at random.
  bool _litWindow(Facet f, TownPiece piece, double decay, bool night) {
    if (!night) return false;
    final life = clampD(1 - decay, 0, 1);
    final lifeCurve = life * life * (3 - 2 * life);
    return hash01(piece.seed, 70, f.data) < lifeCurve;
  }

  /// Whether a window has been boarded up. The same ones go first every time,
  /// so a town empties in an order you can recognise rather than flickering at
  /// random.
  bool _shut(Facet f, TownPiece piece, double decay, bool night) {
    final s = piece.seed;
    if (_litWindow(f, piece, decay, night)) return false;
    final boarded = decay > 0.30 && hash01(s, 72) < (decay - 0.30) * 1.5;
    return boarded || hash01(s, 73, f.data) < decay * 0.8;
  }

  /// A window, which is where the town says how you are doing. A lit window is
  /// one achievement showing from the outside; a whole town of them read in a
  /// single glance is the thing the wall could never do. And when the days
  /// start going by without a piece, they go out one by one.
  int _window(
    Projector p,
    Facet f,
    TownPiece piece,
    Palette pal,
    double decay,
    bool night,
  ) {
    final life = clampD(1 - decay, 0, 1);
    final lifeCurve = life * life * (3 - 2 * life);
    final lit = _litWindow(f, piece, decay, night);
    final colour = lit
        ? Color.lerp(
            const Color(0xFF7A5C2E),
            const Color(0xFFFFD79A),
            0.35 + 0.65 * lifeCurve,
          )!
        : Color.lerp(pal.ink, pal.stoneCool, night ? 0.12 : 0.30)!;
    if (!lit) return hazeAt(colour, p, piece.cx, piece.cz, pal).toARGB32();
    // A lit window is a light, not a yellow rectangle. Remember where it fell
    // so a glow can be laid over the town once the walls are down.
    if (_lamps.length < _lampStride * 220) {
      final at = p.project(f.centroid);
      if (at != null) {
        final r = p.focal / at.depth * 0.34;
        if (r > 1.2) {
          _lamps
            ..add(at.x)
            ..add(at.y)
            ..add(math.min(r, 34))
            ..add(clampD(1 - decay * 0.7, 0.2, 1.0))
            // A qué cara pertenece: la que está a punto de emitirse con este
            // color, que es la ventana misma. De ahí sale su sitio en el
            // orden de pintado.
            ..add(_faceCount.toDouble());
          _lampHeld = true;
        }
      }
    }
    return colour.toARGB32();
  }

  // ------------------------------------------------------------------ wind

  /// One travelling gust, in -1..1.
  ///
  /// Everything that moves in the town moves to this same field, so the grass,
  /// the crops, the trees and the banners all lean the same way at the same
  /// moment. A dozen things each fidgeting to their own clock reads as noise;
  /// a dozen things leaning together reads as weather.
  double _gust(double x, double z, [double phase = 0]) {
    final t = scene.time;
    final a = math.sin(x * 0.36 + z * 0.23 - t * 1.25 + phase);
    final b = math.sin(x * 0.11 - z * 0.17 - t * 0.51 + phase * 0.6);
    return a * 0.62 + b * 0.38;
  }

  /// How hard it is blowing just now, so there are calm spells and gusty ones
  /// instead of one endless breeze.
  double get _windForce =>
      0.42 + 0.58 * (0.5 + 0.5 * math.sin(scene.time * 0.31));

  /// Ploughed rows, and the crop standing in them rippling with the wind.
  void _emitField(
    Projector p,
    TownPiece piece,
    double y0,
    Palette pal,
    double decay,
  ) {
    final s = piece.seed;
    // Real crop colours rather than a wash of the ground tone: young green,
    // ripe barley, the deep green of a kitchen garden.
    final t = hash01(s, 9);
    var crop = t < 0.36
        ? const Color(0xFF6FA341)
        : (t < 0.72 ? const Color(0xFFC9A94A) : const Color(0xFF4E8C46));
    // Un sembrado es lo que más se mueve con el año de todo lo que hay en el
    // valle: brota, madura, se siega y se queda en tierra pelada hasta la
    // primavera. Sin esto, una huerta en pleno enero está verde y lozana
    // debajo de la nieve, que es la clase de detalle que rompe el resto.
    final year = pal.season;
    crop = Color.lerp(crop, const Color(0xFF8FBE4A), year.spring * 0.50)!;
    crop = Color.lerp(crop, const Color(0xFFD9BE62), year.autumn * 0.55)!;
    final soil = const Color(0xFF6B563E);
    // Y en invierno queda la tierra, que es lo que hay en un bancal en enero.
    crop = Color.lerp(crop, soil, year.winter * 0.72)!;
    final along = piece.alongX;
    final across = along ? piece.d : piece.w;
    final rows = clampD(across / 0.26, 3, 14).round();
    final y = y0 + 0.012;
    final sway = 0.055 * _windForce;

    // The rows are sheets lying one behind the other on the ground: paint them
    // starting from the far side and each covers the join of the one before.
    // Which end is the far one depends on where you are standing, and that is
    // the whole of it.
    final back = along ? p.eye.z > piece.cz : p.eye.x > piece.cx;
    for (var k = 0; k < rows; k++) {
      final i = back ? k : rows - 1 - k;
      final lean = _gust(piece.cx, piece.cz, i * 0.5) * sway;
      final a = (i + 0.10) / rows, b = (i + 0.86) / rows;
      final ripe = Color.lerp(
        crop,
        const Color(0xFFE0C86A),
        0.18 * (0.5 + 0.5 * _gust(piece.cx, piece.cz, i * 0.9)),
      )!;
      final c = hazeAt(
        Color.lerp(i.isEven ? ripe : soil, pal.ground, decay * 0.45)!,
        p,
        piece.cx,
        piece.cz,
        pal,
      );
      // The crop stands a little proud of the soil, and leans.
      final h = i.isEven ? y + 0.10 : y;
      final push = i.isEven ? lean : 0.0;
      final V3 q0, q1, q2, q3;
      if (along) {
        final z0 = piece.z0 + across * a, z1 = piece.z0 + across * b;
        q0 = V3(piece.x0 + push, h, z0);
        q1 = V3(piece.x1 + push, h, z0);
        q2 = V3(piece.x1, y, z1);
        q3 = V3(piece.x0, y, z1);
      } else {
        final x0 = piece.x0 + across * a, x1 = piece.x0 + across * b;
        q0 = V3(x0, h, piece.z0 + push);
        q1 = V3(x0, h, piece.z1 + push);
        q2 = V3(x1, y, piece.z1);
        q3 = V3(x1, y, piece.z0);
      }
      _quad(p, q0, q1, q2, q3, c.toARGB32());
    }
  }

  /// Standing water: a colour of its own, bands of light running across it,
  /// and foam where it meets the bank.
  void _emitWater(
    Projector p,
    TownPiece piece,
    double y0,
    Palette pal,
    bool night,
  ) {
    final y = y0 + 0.05;
    final deep = night ? const Color(0xFF1E3A52) : const Color(0xFF35707B);
    final lit = night ? const Color(0xFF33556F) : const Color(0xFF5C9AA0);
    // Foam is water with air in it, not paint: it keeps the water's own colour
    // underneath, which is what stops it reading as a white sticker.
    final foam = Color.lerp(
      night ? const Color(0xFF8FA4B8) : const Color(0xFFE8F4F2),
      deep,
      0.32,
    )!;
    final cx = piece.cx, cz = piece.cz;

    int tint(Color c) => hazeAt(c, p, cx, cz, pal).toARGB32();

    // Every sheet here sits a hair higher than the one before it, and the
    // camera never gets below the waterline, so painting them in the order
    // they are written is painting them bottom up — which is the right order
    // and needs nothing said about depth.
    void plate(double x0, double x1, double z0, double z1, double h, Color c) {
      _quad(
        p,
        V3(x0, h, z1),
        V3(x1, h, z1),
        V3(x1, h, z0),
        V3(x0, h, z0),
        tint(c),
      );
    }

    plate(piece.x0, piece.x1, piece.z0, piece.z1, y, deep);

    // Bands of reflected light travelling across it. Each sits a hair higher
    // than the last so they never fight each other for the same depth.
    final w = piece.w, d = piece.d;
    const bands = 3;
    for (var i = 0; i < bands; i++) {
      final phase = scene.time * 0.33 + i * 0.41 + hash01(piece.seed, 21, i);
      final t = phase - phase.floorToDouble();
      final z = piece.z0 + d * t;
      final thick = d * (0.05 + 0.03 * math.sin(scene.time * 1.1 + i));
      if (z + thick > piece.z1) continue;
      final inset = w * 0.06;
      plate(
        piece.x0 + inset,
        piece.x1 - inset,
        z,
        z + thick,
        y + 0.004 + i * 0.002,
        Color.lerp(deep, lit, 0.55)!,
      );
    }

    // Foam: a frill round the edge that breathes with the wind, so still water
    // still looks alive.
    final swell = 0.014 + 0.012 * _windForce;
    final rim = math.min(math.min(w, d) * (0.05 + 0.025 * _windForce), 0.13);
    if (rim < 0.02) return;
    final fy = y + 0.012;
    for (var side = 0; side < 4; side++) {
      final wob = rim * (0.7 + 0.5 * _gust(cx, cz, side * 1.7).abs());
      switch (side) {
        case 0:
          plate(piece.x0, piece.x1, piece.z0, piece.z0 + wob, fy, foam);
        case 1:
          plate(piece.x0, piece.x1, piece.z1 - wob, piece.z1, fy, foam);
        case 2:
          plate(piece.x0, piece.x0 + wob, piece.z0, piece.z1, fy, foam);
        case 3:
          plate(piece.x1 - wob, piece.x1, piece.z0, piece.z1, fy, foam);
      }
    }
    // And a lick of white further in on the windward side.
    final lick = rim * 0.6 * (0.5 + 0.5 * math.sin(scene.time * 1.7));
    if (lick > 0.01) {
      plate(
        piece.x0 + rim,
        piece.x1 - rim,
        piece.z0 + rim,
        piece.z0 + rim + lick,
        y + swell,
        foam,
      );
    }
  }

  /// A pole with a banner hanging from it. The one piece of the town allowed a
  /// colour that is not stone, plaster or tile.
  void _emitBanner(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    Palette pal,
  ) {
    final ht = y1 - y0;
    // The pole is masonry and stands in the tree with everything else; what is
    // left here is the cloth, which is the one thing in the town that flies.
    final pick = hash01(piece.seed, 13);
    final cloth = pick < 0.34
        ? const Color(0xFFC0392B)
        : (pick < 0.67 ? const Color(0xFFE0A32E) : const Color(0xFF2E6FA8));
    final e = p.eye;
    final gust = _gust(piece.cx, piece.cz, piece.seed * 0.0007);
    final fly = ht * (0.30 + 0.18 * _windForce * (0.5 + 0.5 * gust));
    final top = y1 - ht * 0.08, bot = top - ht * 0.34;
    // The free corner lifts and falls; the hoist stays on the pole.
    final wave = ht * 0.11 * gust * _windForce;
    final c = hazeAt(cloth, p, piece.cx, piece.cz, pal).toARGB32();
    final shade = hazeAt(
      Color.lerp(cloth, Colors.black, 0.22)!,
      p,
      piece.cx,
      piece.cz,
      pal,
    ).toARGB32();
    if ((e.x - piece.cx).abs() > (e.z - piece.cz).abs()) {
      final z0 = piece.cz + 0.04, z1 = piece.cz + 0.04 + fly;
      _quad(
        p,
        V3(piece.cx, bot, z0),
        V3(piece.cx, bot + wave, z1),
        V3(piece.cx, top + wave, z1),
        V3(piece.cx, top, z0),
        c,
      );
      _quad(
        p,
        V3(piece.cx, bot, z0),
        V3(piece.cx, bot + wave, z1),
        V3(piece.cx, bot + wave - ht * 0.06, z1),
        V3(piece.cx, bot - ht * 0.02, z0),
        shade,
      );
    } else {
      final x0 = piece.cx + 0.04, x1 = piece.cx + 0.04 + fly;
      _quad(
        p,
        V3(x0, bot, piece.cz),
        V3(x1, bot + wave, piece.cz),
        V3(x1, top + wave, piece.cz),
        V3(x0, top, piece.cz),
        c,
      );
      _quad(
        p,
        V3(x0, bot, piece.cz),
        V3(x1, bot + wave, piece.cz),
        V3(x1, bot + wave - ht * 0.06, piece.cz),
        V3(x0, bot - ht * 0.02, piece.cz),
        shade,
      );
    }
  }

  /// Four sails on a windmill's cap, turning.
  ///
  /// Drawn as flat quads in the plane of the cap rather than as boxes, which is
  /// what lets them sit at any angle — and a windmill whose sails go round is
  /// the single most alive thing in the town.
  void _emitSails(
    Projector p,
    TownPiece piece,
    double y0,
    double y1,
    V3 light,
    Palette pal,
  ) {
    final r = (y1 - y0) / 2;
    final cy = y0 + r;
    final cx = piece.cx, cz = piece.cz - 0.16;
    const wood = Color(0xFF5A4835);
    final cloth = Color.lerp(const Color(0xFFF6EBD2), pal.stoneWarm, 0.18)!;
    final shade = Color.lerp(cloth, const Color(0xFF8A6E4A), 0.30)!;

    // The wheel turns at the wind's own pace, and freewheels a little when the
    // gust drops, so it never looks like a clock hand.
    //
    // Y despacio: iba a algo más de una vuelta cada cinco segundos con viento
    // fuerte, que en un pueblo de este tamaño se lee como un ventilador. Un
    // molino de verdad da unas diez vueltas por minuto, y eso es lo que hace
    // que mirarlo calme en vez de meter prisa.
    final turn =
        scene.time * (0.22 + 0.34 * _windForce) + hash01(piece.seed, 17) * 6.28;

    void blade(
      double ang,
      double from,
      double to,
      double halfW,
      Color c,
      double ao,
    ) {
      final dx = math.cos(ang), dy = math.sin(ang);
      final nx = -dy * halfW, ny = dx * halfW;
      _quad(
        p,
        V3(cx + dx * from + nx, cy + dy * from + ny, cz),
        V3(cx + dx * to + nx, cy + dy * to + ny, cz),
        V3(cx + dx * to - nx, cy + dy * to - ny, cz),
        V3(cx + dx * from - nx, cy + dy * from - ny, cz),
        hazeAt(
          _shade(const V3(0, 0, -1), c, light, pal, ao, 0, 0),
          p,
          cx,
          cz,
          pal,
        ).toARGB32(),
      );
    }

    for (var i = 0; i < 4; i++) {
      final a = turn + i * math.pi / 2;
      // The cloth first, then the stock over it, so the frame reads on top.
      blade(a, r * 0.30, r * 0.98, r * 0.20, i.isEven ? cloth : shade, 1.06);
      blade(a, r * 0.06, r * 1.0, r * 0.055, wood, 0.95);
    }
  }

  Color _weather(Color c, double decay, int seed) {
    if (decay < 0.02) return c;
    final moss = hash01(seed, 61) < decay * 0.55;
    final t = decay * (moss ? 0.42 : 0.22);
    return Color.lerp(c, const Color(0xFF5C6B4A), t)!;
  }

  /// The name of each landmark the town has finished.
  void _drawTownLabels(Canvas canvas, Projector p, Size size, TownLayout town) {
    if (!scene.labels) return;
    // From far enough back the valley is about which town is which, not which
    // building is which. The landmark names stand down for the town signs.
    if (scene.towns.length > 1 && scene.camera.distance > 95) return;
    // Nearest first, so when two names collide it is the one further away that
    // gives up its place.
    final show = <(double, Offset2, String, double)>[];
    for (final b in town.buildings) {
      if (!b.isLandmark || !b.finished) continue;
      if (scene.placed < b.firstPiece + b.cost) continue;
      final at = p.project(V3(b.cx, b.peakY + 0.5, b.cz));
      if (at == null) continue;
      if (at.x < -120 || at.x > size.width + 120) continue;
      // The one just finished comes in last so nothing can push it aside, and
      // rises into place rather than blinking on.
      final pop = b.index == scene.finished
          ? clampD(scene.finishedAge / 0.55, 0, 1)
          : 1.0;
      show.add((
        b.index == scene.finished ? -1.0 : at.depth,
        at,
        b.name.toUpperCase(),
        pop,
      ));
    }
    show.sort((a, b) => a.$1.compareTo(b.$1));
    final taken = <Rect>[];
    for (final row in show) {
      _drawLabel(canvas, row.$2, row.$3, size, taken: taken, pop: row.$4);
    }
  }

  Color _shade(
    V3 n,
    Color albedo,
    V3 light,
    Palette pal,
    double ao,
    double flash,
    double repairGlow, [
    Surface? on,
  ]) {
    final ndl = math.max(0.0, n.dot(light));
    final skyTerm = 0.5 + 0.5 * n.y;
    albedo = snowed(albedo, n, pal, on);
    // Stone in shadow is still stone: the sky term is modulated by the albedo
    // so unlit faces stay pale limestone instead of collapsing to black.
    final k = (0.44 + 0.58 * ndl + 0.26 * skyTerm) * ao * pal.contrast;
    var r =
        albedo.r * k +
        pal.sun.r * ndl * 0.06 +
        pal.skyLight.r * skyTerm * 0.045;
    var g =
        albedo.g * k +
        pal.sun.g * ndl * 0.06 +
        pal.skyLight.g * skyTerm * 0.045;
    var b =
        albedo.b * k +
        pal.sun.b * ndl * 0.06 +
        pal.skyLight.b * skyTerm * 0.045;
    if (flash > 0) {
      r = lerpD(r, 1.0, flash * 0.85);
      g = lerpD(g, 0.97, flash * 0.85);
      b = lerpD(b, 0.82, flash * 0.85);
    }
    if (repairGlow > 0) {
      r = lerpD(r, 1.0, repairGlow * 0.55);
      g = lerpD(g, 0.92, repairGlow * 0.5);
      b = lerpD(b, 0.68, repairGlow * 0.45);
    }
    return Color.fromARGB(255, _ch(r), _ch(g), _ch(b));
  }

  /// El color de una cara del mobiliario del pueblo: la huerta, el roble de la
  /// parcela, el tablón.
  ///
  /// Estas cosas no son piezas de nadie —nadie se las ganó— así que no tienen
  /// un edificio del que sacar el tono y lo dicen ellas mismas con un tinte.
  /// Pero una hoja es una hoja aunque no sea de nadie: la del roble de la
  /// parcela tiene que dorarse en octubre igual que la del bosque, y la huerta
  /// tiene que quedarse en tierra en enero. Sin esto, en un valle nevado había
  /// setos verde primavera al lado de cada casa.
  ///
  /// La semilla sale de dónde está, que es lo único propio que tiene una cara
  /// suelta, y así dos robles vecinos no se doran el mismo día.
  Color _plainTone(Facet f, V3 at, Palette pal) {
    final base = Color(f.tint ?? 0xFF808080);
    if (f.surface != Surface.leaf) return base;
    return leafOfYear(
      base,
      hash32((at.x * 64).round(), (at.z * 64).round(), 5),
      pal.season,
    );
  }

  // ---------------------------------------------------------------- flush

  /// Paints what was collected, in the order it was collected.
  ///
  /// There is no sort here any more and there is not meant to be one: by the
  /// time a face reaches this list its place has already been decided by
  /// geometry rather than guessed from a distance.
  void _flush(Canvas canvas, Size size) {
    if (_faceCount == 0) return;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    // Two neighbouring faces drawn separately with antialiasing leave a
    // hairline of whatever is behind them showing between the two. Cutting the
    // geometry is what makes the order right, and cutting makes more
    // neighbours, so closing the seam matters more here than it ever did:
    // running the same colour round the edge does it.
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    // Las lámparas van intercaladas, cada una justo detrás de su ventana: las
    // caras se recorren de lejos a cerca, así que todo lo que se pinte después
    // de un halo lo tapa, que es exactamente lo que tiene que pasar. Salen en
    // orden de cara porque se apuntaron durante el mismo recorrido.
    final lampara = Paint()..blendMode = BlendMode.plus;
    var luz = 0;
    for (var k = 0; k < _faceCount; k++) {
      final f = _facePool[k];
      _scratch.reset();
      _scratch.moveTo(f.pts[0], f.pts[1]);
      for (var i = 1; i < f.n; i++) {
        _scratch.lineTo(f.pts[i * 2], f.pts[i * 2 + 1]);
      }
      _scratch.close();
      paint.color = Color(f.color);
      canvas.drawPath(_scratch, paint);
      seam.color = paint.color;
      canvas.drawPath(_scratch, seam);
      while (luz < _lamps.length && _lamps[luz + 4] <= k) {
        _lampAt(canvas, size, lampara, luz);
        luz += _lampStride;
      }
    }
    // Y las que quedaron sin cara: una ventana recortada por el plano cercano
    // no llega a emitirse, y su luz se apuntó igual.
    while (luz < _lamps.length) {
      _lampAt(canvas, size, lampara, luz);
      luz += _lampStride;
    }
  }

  // ------------------------------------------------------------- extras

  /// A name set straight on the sky with a halo, and a hairline under it to tie
  /// it to the thing it names. No filled pill: that was the last of the heavy
  /// white chrome.
  void _drawLabel(
    Canvas canvas,
    Offset2 top,
    String name,
    Size size, {
    double? at,
    List<Rect>? taken,
    double pop = 1,
  }) {
    final depth = at ?? top.depth;
    // How far a name carries depends on how far back the camera has gone: from
    // across the valley the town should still say what its landmarks are.
    final far = math.max(24.0, scene.camera.distance * 1.15);
    final fade = clampD(1 - (depth - far) / (far * 0.75), 0, 1) * pop;
    if (fade <= 0.02) return;
    final dark = darkSky(scene.palette);
    final glow = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: (dark ? Colors.white : scene.palette.ink).withValues(
            alpha: 0.88 * fade,
          ),
          fontSize: 9.5,
          letterSpacing: 2.6,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: (dark ? Colors.black : const Color(0xFF3A3426)).withValues(
                alpha: (dark ? 0.6 : 0.34) * fade,
              ),
              blurRadius: 10,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // The camera buttons live down the right-hand edge; a name that lands
    // under them is unreadable, so it slides left far enough to clear them.
    var cx = top.x;
    final inButtons = top.y > 80 && top.y < 250;
    final right = size.width - (inButtons ? 74 : 6) - glow.width / 2;
    final left = 6 + glow.width / 2;
    if (right > left) cx = clampD(cx, left, right);

    // A name that has just been earned rises into place instead of appearing.
    final lift = (1 - pop) * 16;
    final origin = Offset(cx - glow.width / 2, top.y - glow.height / 2 + lift);

    // A town has a lot of names in it. Two of them written across each other
    // are worth less than one of them alone, so a name that would land on one
    // already written simply is not written.
    if (taken != null) {
      final box = Rect.fromLTWH(
        origin.dx - 6,
        origin.dy - 3,
        glow.width + 12,
        glow.height + 14,
      );
      for (final other in taken) {
        if (box.overlaps(other)) return;
      }
      taken.add(box);
    }

    glow.paint(canvas, origin);

    // A hairline under it, to tie the name to the thing it names.
    final w = glow.width * 0.5;
    canvas.drawLine(
      Offset(cx - w / 2, origin.dy + glow.height + 5),
      Offset(cx + w / 2, origin.dy + glow.height + 5),
      Paint()
        ..strokeWidth = 1
        ..color = (dark ? Colors.white : scene.palette.ink).withValues(
          alpha: 0.30 * fade,
        ),
    );
  }

  // ---------------------------------------------------------- stone marks

  // ------------------------------------------------------------- particles

  /// Cada edificio del pueblo activo metido en una caja.
  ///
  /// Sólo sirve para tapar el humo, que es lo único que se pinta después del
  /// pueblo y está metido dentro de él. Se rehace cuando cambia el pueblo o
  /// cuántas piezas lleva puestas, que es cuando puede haber cambiado una caja;
  /// girar la cámara no lo toca.
  List<_Box>? _boxes;
  TownLayout? _boxesOf;
  int _boxesAt = -1;

  List<_Box> _buildingBoxes() {
    if (scene.active < 0 || scene.active >= scene.towns.length) return const [];
    final e = scene.towns[scene.active];
    final take = math.min(e.placed, e.layout.pieces.length);
    if (_boxes != null && identical(_boxesOf, e.layout) && _boxesAt == take) {
      return _boxes!;
    }
    final por = <int, _Box>{};
    for (var i = 0; i < take; i++) {
      final q = e.layout.pieces[i];
      final caja = por[q.building];
      if (caja == null) {
        por[q.building] = _Box(q.building, q.x0, q.x1, q.z0, q.z1, q.y1);
      } else {
        caja.grow(q);
      }
    }
    _boxesOf = e.layout;
    _boxesAt = take;
    return _boxes = por.values.toList();
  }

  /// Si entre el ojo y este punto hay un edificio que no es el suyo.
  ///
  /// El humo se pinta al final, después de que el pueblo entero esté en el
  /// lienzo, porque es lo único que no se puede meter en el orden de caras: no
  /// tiene caras. Sin esto, una columna de humo de la casa de atrás se dibuja
  /// encima de la fachada de la de delante — y eso es exactamente lo que se
  /// veía: una mancha parda subiendo por un muro blanco.
  ///
  /// Se prueba contra la caja de cada edificio y no contra sus piezas: una casa
  /// es prácticamente su caja, y la diferencia —el hueco bajo el alero— cuesta
  /// que una voluta se esconda medio metro antes de lo debido. Lo otro cuesta
  /// recorrer todas las piezas del pueblo por cada partícula.
  bool _hidden(Projector p, V3 at, int owner) {
    final eye = p.eye;
    final dx = at.x - eye.x, dy = at.y - eye.y, dz = at.z - eye.z;
    for (final b in _buildingBoxes()) {
      if (b.building == owner) continue;
      var t0 = 0.0, t1 = 1.0;
      var fuera = false;
      for (var eje = 0; eje < 3 && !fuera; eje++) {
        final d = eje == 0 ? dx : (eje == 1 ? dy : dz);
        final o = eje == 0 ? eye.x : (eje == 1 ? eye.y : eye.z);
        final lo = eje == 0 ? b.x0 : (eje == 1 ? 0.0 : b.z0);
        final hi = eje == 0 ? b.x1 : (eje == 1 ? b.y1 : b.z1);
        if (d.abs() < 1e-9) {
          if (o < lo || o > hi) fuera = true;
          continue;
        }
        var a = (lo - o) / d, z = (hi - o) / d;
        if (a > z) {
          final w = a;
          a = z;
          z = w;
        }
        if (a > t0) t0 = a;
        if (z < t1) t1 = z;
        if (t0 > t1) fuera = true;
      }
      // Y el tramo tiene que quedar por delante del ojo. Sin esto, una cámara
      // metida dentro de una caja —que pasa acercándose mucho— sale con el
      // tramo empezando en cero y lo tapa todo.
      if (!fuera && t1 > t0 && t0 > 0.02) return true;
    }
    return false;
  }

  void _drawParticles(Canvas canvas, Projector p) {
    final pal = scene.palette;
    final paint = Paint();
    for (final part in scene.effects.live) {
      final pt = p.project(V3(part.x, part.y, part.z));
      if (pt == null) continue;
      if (part.kind == ParticleKind.smoke &&
          _hidden(p, V3(part.x, part.y, part.z), part.owner)) {
        continue;
      }
      final life = (part.life / part.maxLife).clamp(0.0, 1.0);
      final r = part.size * p.focal / pt.depth;
      if (r < 0.3) continue;
      switch (part.kind) {
        case ParticleKind.dust:
          paint
            ..color = Color.lerp(
              pal.stoneWarm,
              pal.haze,
              0.4,
            )!.withValues(alpha: life * 0.42)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
          canvas.drawCircle(Offset(pt.x, pt.y), r * (2.2 - life), paint);
          paint.maskFilter = null;
        case ParticleKind.chip:
          paint.color = pal.stoneCool.withValues(alpha: life);
          canvas.save();
          canvas.translate(pt.x, pt.y);
          canvas.rotate(part.angle);
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.4),
            paint,
          );
          canvas.restore();
        case ParticleKind.spark:
          paint.color = Color.lerp(
            pal.accent,
            Colors.white,
            0.4,
          )!.withValues(alpha: life);
          canvas.drawCircle(Offset(pt.x, pt.y), r * 1.3, paint);
        case ParticleKind.gold:
          paint.color = const Color(
            0xFFF2C25B,
          ).withValues(alpha: life * life * 0.85);
          canvas.drawCircle(Offset(pt.x, pt.y), r * 0.9, paint);
        case ParticleKind.ember:
          paint.color = Color.lerp(
            const Color(0xFFFF8A3D),
            const Color(0xFFFFD79A),
            life,
          )!.withValues(alpha: life);
          canvas.drawCircle(Offset(pt.x, pt.y), r, paint);
        case ParticleKind.moteRepair:
          paint.color = const Color(0xFFBFE8D0).withValues(alpha: life * 0.8);
          canvas.drawCircle(Offset(pt.x, pt.y), r, paint);
        case ParticleKind.smoke:
          // Thickest just after it leaves the flue, then thinning as it spreads
          // and takes the colour of the air it is drifting through.
          final age = 1 - life;
          final puff = Color.lerp(
            Color.lerp(pal.stoneCool, pal.ink, 0.22)!,
            pal.haze,
            age * 0.8,
          )!;
          paint
            ..color = puff.withValues(alpha: life * life * 0.30)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + age * 6);
          canvas.drawCircle(Offset(pt.x, pt.y), r * (1.0 + age * 3.2), paint);
          paint.maskFilter = null;
        case ParticleKind.glint:
          final k = math.sin(life * math.pi);
          paint
            ..color = Color.lerp(
              pal.sun,
              Colors.white,
              0.5,
            )!.withValues(alpha: k * 0.85)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
          canvas.drawCircle(Offset(pt.x, pt.y), r * (0.8 + k), paint);
          paint.maskFilter = null;
      }
    }
  }

  @override
  bool shouldRepaint(covariant TownPainter old) => true;
}

/// Un vecino resuelto para este fotograma: quién es, dónde está, lo que mide
/// y lo que ocupa en la pantalla.
class _Walker {
  _Walker(this.who, this.at, this.size, this.pixels, this.depth);
  final Townsfolk who;
  final FolkAt at;
  final double size, pixels;

  /// Lo lejos que está del ojo, para que el tope se lleve a los de atrás.
  final double depth;

  /// A media altura, que es por donde se le parte con un plano horizontal.
  double get y => size * 0.5;
}

/// Un edificio metido en una caja, para saber qué humo tapa.
class _Box {
  _Box(this.building, this.x0, this.x1, this.z0, this.z1, this.y1);

  final int building;
  double x0, x1, z0, z1, y1;

  void grow(TownPiece q) {
    if (q.x0 < x0) x0 = q.x0;
    if (q.x1 > x1) x1 = q.x1;
    if (q.z0 < z0) z0 = q.z0;
    if (q.z1 > z1) z1 = q.z1;
    if (q.y1 > y1) y1 = q.y1;
  }
}
