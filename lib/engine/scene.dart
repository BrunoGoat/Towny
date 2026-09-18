import 'dart:ui';

import '../data/constellations.dart';
import '../fx/effects.dart';
import 'camera.dart';
import 'folk.dart';
import 'palette.dart';
import 'town.dart';

/// Lo que hay que pintar, dicho antes de pintarlo.
///
/// Un fotograma entero descrito como datos: qué pueblos hay, cuántas piezas
/// lleva cada uno, dónde está la cámara, qué hora es y qué está pasando. Nada
/// de aquí sabe dibujar, y ésa es la idea — lo arma la pantalla, lo lee el
/// pintor, y entre los dos no hay más contrato que este fichero.
///
/// Se salieron de `renderer.dart` porque no tenían por qué estar ahí: un
/// rasterizador de tres mil líneas en el que las primeras doscientas son
/// definiciones de estructuras obliga a leerlas todas para llegar a la primera
/// cara pintada. Y porque quien arma una escena —la pantalla del pueblo, el
/// expositor, la cinemática, la hoja de elegir— no quiere el rasterizador
/// entero, quiere saber qué campos rellenar.
///
/// Aquí van también los seis sitios que el pintor deja marcados al pasar
/// —dónde cayó cada pieza, cada cartel, cada tablón, cada atril, cada cúpula y
/// la constelación de esta noche—, porque son la otra mitad del mismo
/// contrato: lo que entra a pintarse y lo que sale para poder tocarlo.

/// One town in the valley, and what the habit behind it is called.
class TownEntry {
  const TownEntry({
    required this.layout,
    required this.name,
    required this.symbol,
    required this.integrity,
    required this.placed,
    this.crowned = false,
  });

  final TownLayout layout;
  final String name;
  final String symbol;

  /// How lit this town is. A habit left alone goes dark, and from across the
  /// valley that is the whole comparison: this one is alive, that one is not.
  final double integrity;
  final int placed;

  /// True for the town with the most pieces in the valley.
  final bool crowned;
}

/// One stone as it appears on screen this frame, kept so taps can be resolved
/// back to the brick that was drawn there.
/// El sitio que una pieza ocupa en la pantalla, para poder tocarla.
///
/// Antes era un círculo alrededor del centro de **una** cara: la primera que se
/// pintaba de esa pieza, que casi nunca es la que se está mirando. De ahí las
/// dos quejas — que el blanco es más chico que la pieza, y que a veces sale la
/// de debajo. Ahora es la caja de **todas** sus caras juntas, y lleva la
/// distancia de la más cercana, que es lo que decide quién gana cuando dos se
/// pisan: la de adelante. Una pieza no se toca a través de otra.
class PickTarget {
  PickTarget(
    this.brickIndex,
    this.x0,
    this.y0,
    this.x1,
    this.y1,
    this.near,
    this.labelled,
  );

  final int brickIndex;

  /// Lo que abarca en pantalla, creciendo con cada cara suya que se pinta.
  double x0, y0, x1, y1;

  /// A qué distancia del ojo está lo más cercano suyo.
  double near;

  /// True when this stone carries a note, so it can be marked on the wall.
  final bool labelled;

  bool holds(double x, double y, double slack) =>
      x >= x0 - slack && x <= x1 + slack && y >= y0 - slack && y <= y1 + slack;

  void grow(double ax, double ay, double bx, double by, double z) {
    if (ax < x0) x0 = ax;
    if (ay < y0) y0 = ay;
    if (bx > x1) x1 = bx;
    if (by > y1) y1 = by;
    if (z < near) near = z;
  }
}

/// Where a town's sign landed on screen, so it can be tapped.
///
/// The sign is the only thing you can read about a town from the far side of
/// the valley; tapping the thing you are reading and being taken there is what
/// anybody expects it to do.
class SignHit {
  const SignHit(this.town, this.rect);
  final int town;
  final Rect rect;
}

/// Where a town's notice board landed on screen, so it can be read.
///
/// The board is a thing standing in the plaza and not a button floating over
/// the town, so this is worked out from the plank's own four corners.
/// La cúpula de un observatorio en pantalla, para que un dedo la encuentre.
///
/// Lo que se guarda es del valle y no de un pueblo, así que da igual cuál se
/// toque: todos abren el mismo cuaderno. Pero se toca el de un pueblo, que es
/// lo que hace que sea un sitio y no una pantalla de ajustes.
class DomeHit {
  const DomeHit(this.town, this.rect);
  final int town;
  final Rect rect;
}

/// Dónde quedó la constelación de esta noche, para que un dedo la encuentre.
class SkyHit {
  const SkyHit(this.id, this.rect);
  final String id;
  final Rect rect;
}

class BoardHit {
  const BoardHit(this.town, this.rect);
  final int town;
  final Rect rect;
}

/// Dónde quedó el atril de un pueblo, para que un dedo lo encuentre.
///
/// Igual que el tablón y por el mismo motivo: sale de las cuatro esquinas del
/// propio libro, así que lo que se toca es exactamente lo que se ve.
class LecternHit {
  const LecternHit(this.town, this.rect);
  final int town;
  final Rect rect;
}

class TownScene {
  TownScene({
    required this.placed,
    required this.palette,
    required this.camera,
    required this.integrity,
    required this.time,
    required this.hourOfDay,
    required this.effects,
    required this.labelledBricks,
    this.fx,
    this.budget = 16000,
    required this.towns,
    required this.active,
    this.finished,
    this.finishedAge = 99,
    this.selectedBrick,
    this.charge = 0,
    this.labels = true,
    this.tonight,
    this.skyNight = 0,
    this.folk = true,
    this.soloFolk,
  });

  /// How many achievements have been laid.
  final int placed;
  final Palette palette;
  final OrbitCamera camera;
  final double integrity;
  final double time;

  /// La hora que se está pintando, de 0 a 24. La paleta ya sale de ella, pero
  /// hay cosas que necesitan el número y no el color: una fugaz no sale a las
  /// siete de la tarde aunque en invierno a esa hora ya esté oscuro.
  final double hourOfDay;

  /// Si el pueblo tiene gente dentro.
  ///
  /// Se apaga para el expositor y para los tests que miden geometría: un test
  /// que cuenta caras no puede llevar a cuarenta vecinos andando dentro.
  final bool folk;

  /// Una persona sola en medio del prado, para el expositor de actividades.
  ///
  /// Cuando está puesta, es lo único que se pinta de gente: se planta en el
  /// origen y se la mira dando la vuelta. Va por el mismo camino que la gente
  /// de un pueblo —las mismas cajas, el mismo sombreado, el mismo descarte de
  /// caras— porque si no, el expositor enseñaría algo que no es lo que se ve
  /// luego, y entonces no sirve para decidir nada.
  final Townsfolk? soloFolk;

  final EffectSystem effects;

  /// How many faces are worth drawing this frame, trimmed to hold the frame
  /// rate on whatever phone this is.
  ///
  /// Faces and not pieces: a stake of a fence and a cathedral are both one
  /// achievement, and what the frame actually pays for is the face count.
  final int budget;

  /// Bricks the person wrote a note on.
  final Set<int> labelledBricks;

  final PlacementFx? fx;

  /// Every town in the valley, one per habit, and which of them is the one
  /// being built right now. They are all drawn: the whole point of a valley
  /// with several towns in it is being able to look at them together.
  final List<TownEntry> towns;
  final int active;

  TownLayout get town => towns[active].layout;

  /// The building that has just been finished, and how long ago in seconds.
  /// A house takes days to build and a second to celebrate.
  final int? finished;
  final double finishedAge;

  /// The stone the person just tapped, ringed so it is obvious which one the
  /// note belongs to.
  final int? selectedBrick;

  /// 0..1 while the place button is held down.
  final double charge;

  /// Qué noche es ésta. Decide dónde se cuelga la constelación, y se queda
  /// quieta hasta el mediodía siguiente.
  final int skyNight;

  /// La figura que hay en el cielo esta noche, si hay alguna. Muchas noches no
  /// hay ninguna, que es lo que hace que valga la pena mirar las que sí.
  final Constellation? tonight;

  /// Whether the landmark names are hung over the buildings. The exhibition
  /// hall says the name in its own header, and a second one floating in the
  /// sky over an empty world is only clutter.
  final bool labels;
}

/// Dónde quedó cada cosa que se puede tocar, apuntado al pintarla.
///
/// Las seis listas se rellenan en el mismo recorrido y se leen en el mismo
/// sitio —la capa de gestos, cuando alguien pone el dedo—, así que son una
/// cosa y no seis. Iban sueltas, y eso daba un pintor de siete parámetros
/// posicionales y cuatro sitios declarando las mismas seis listas, uno de
/// ellos así:
///
///     TownPainter(scene, [], [], [], [], [], [])
///
/// Seis corchetes vacíos en fila no dicen nada de lo que pasa ahí — y lo que
/// pasa es «este expositor no tiene nada que tocar».
class TouchMap {
  /// Cada pieza y el rectángulo que ocupa en pantalla.
  final List<PickTarget> pieces = [];

  /// El cartel de cada pueblo.
  final List<SignHit> signs = [];

  /// Su tablón.
  final List<BoardHit> boards = [];

  /// Y su atril.
  final List<LecternHit> lecterns = [];

  /// La constelación de esta noche, si salió.
  final List<SkyHit> skies = [];

  /// Y cada cúpula, que se abren al tocarlas.
  final List<DomeHit> domes = [];

  /// Se vacía entero al empezar cada fotograma. Que lo haga el propio mapa es
  /// lo que evita el fallo de olvidarse una: seis `clear()` en fila al
  /// principio de `paint` se convierten en cinco en cuanto alguien añade la
  /// séptima cosa tocable.
  void clear() {
    pieces.clear();
    signs.clear();
    boards.clear();
    lecterns.clear();
    skies.clear();
    domes.clear();
  }
}
