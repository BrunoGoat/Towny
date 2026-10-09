import 'dart:math' as math;
import 'dart:typed_data';
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
/// Aquí van también los sitios que el pintor deja marcados al pasar —dónde
/// cayó cada pieza, cada cartel, cada tablón, cada cúpula y la constelación de
/// esta noche—, porque son la otra mitad del mismo
/// contrato: lo que entra a pintarse y lo que sale para poder tocarlo.

/// One town in the valley, and what the habit behind it is called.
class TownEntry {
  const TownEntry({
    required this.layout,
    required this.name,
    required this.symbol,
    required this.placed,
    this.founded = true,
  });

  final TownLayout layout;
  final String name;
  final String symbol;

  final int placed;

  /// Si este pueblo llegó a fundarse. Falso es el hueco del valle en el que
  /// todavía no hay nada: ni plaza, ni suelo, ni nombre.
  final bool founded;
}

/// Where a town's notice board landed on screen, so it can be read.
///
/// The board is a thing standing in the plaza and not a button floating over
/// the town, so this is worked out from the plank's own four corners.
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

class TownScene {
  TownScene({
    required this.placed,
    required this.palette,
    required this.camera,
    required this.time,
    required this.hourOfDay,
    required this.effects,
    this.fx,
    this.budget = 16000,
    required this.towns,
    required this.active,
    this.finished,
    this.finishedAge = 99,
    this.newborn,
    this.newbornAge = 99,
    this.selectedBrick,
    this.charge = 0,
    this.labels = true,
    this.tonight,
    this.skyNight = 0,
    this.skyLabel = 0,
    this.founding = 1.0,
    this.day = 0,
    this.folk = true,
    this.soloFolk,
    this.ghost = true,
    this.cinematic = false,
  });

  /// La calidad máxima: sombras de verdad, resplandor, rayos de sol y color
  /// de cine. Ver [Cinema].
  final bool cinematic;

  /// Si se dibuja el contorno de la pieza que viene. No en el valle de la
  /// primera vez: ahí todavía no hay pueblo, y un rectángulo de alambre en el
  /// prado se lee como un fallo y no como una promesa.
  final bool ghost;

  /// How many achievements have been laid.
  final int placed;
  final Palette palette;
  final OrbitCamera camera;
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

  /// La casa que acaba de rematarse y en la que todavía no vive nadie, y
  /// cuántos segundos hace que se posó su última pieza.
  ///
  /// Es el aviso con el que el vecino que nace de ella aprende cuándo le toca
  /// salir: ver [Townsfolk.debut]. Aparte de [finished] porque no es lo mismo
  /// ni dura lo mismo — aquello es la fiesta, que se apaga a los dos segundos
  /// y medio, y esto es el nacimiento, que es de la casa y de nadie más. Sólo
  /// lo lleva el pueblo que se está construyendo, y nunca un hito: en un
  /// puente no vive nadie.
  final int? newborn;
  final double newbornAge;

  /// The stone the person just tapped, ringed so it is obvious which one the
  /// note belongs to.
  final int? selectedBrick;

  /// 0..1 while the place button is held down.
  final double charge;

  /// Qué noche es ésta. Decide dónde se cuelga la constelación, y se queda
  /// quieta hasta el mediodía siguiente.
  final int skyNight;

  /// Cuánto lleva levantada la plaza del pueblo que se acaba de fundar, de
  /// cero a uno. Uno —lo normal— quiere decir que está en su sitio.
  ///
  /// Un pueblo se funda con su plaza, no con su primera casa: el enlosado y el
  /// tablón existen desde el minuto cero, porque son el claro
  /// alrededor del cual se reparten los solares. Esto es lo único que hace
  /// falta para que además **se vean llegar**, en vez de estar ya ahí la
  /// primera vez que se mira.
  final double founding;

  /// Qué día es hoy, como número —`20261001`— o cero si a nadie le importa.
  ///
  /// Lo mira una sola cosa: las matas de hierba que asoman entre la nieve, que
  /// se reparten distinto cada día. Entra por aquí y no se lee del reloj
  /// porque el pintor tiene que ser una función de lo que recibe: un
  /// `DateTime.now()` dentro del dibujo convierte cualquier prueba de píxeles
  /// en una lotería que un día falla sola.
  final int day;

  /// La figura que hay en el cielo esta noche, si hay alguna. Muchas noches no
  /// hay ninguna, que es lo que hace que valga la pena mirar las que sí.
  final Constellation? tonight;

  /// Cuánto se ve el nombre de la constelación, de cero a uno: sale unos
  /// segundos al tocarla y se va solo.
  final double skyLabel;

  /// Whether the landmark names are hung over the buildings. The exhibition
  /// hall says the name in its own header, and a second one floating in the
  /// sky over an empty world is only clutter.
  final bool labels;
}

/// Qué hay en cada punto de la pantalla, apuntado al pintarlo: lo único que
/// mira el dedo. Ver [add].
class TouchMap {
  /// Dónde quedó el tablón de cada pueblo. No decide si se tocó —eso lo dice
  /// lo que se ve—: sólo de qué pueblo es el tablón que se tocó.
  final List<BoardHit> boards = [];

  /// La constelación de esta noche, si salió: cuál es.
  final List<SkyHit> skies = [];

  /// Todo lo que se pintó en el fotograma, **en el orden en que se pintó**,
  /// y de quién es cada cosa: el cielo de la constelación, el suelo y las
  /// cordilleras, cada cara de las casas, de las piezas y del tablón, y los
  /// carteles de los pueblos encima de todo.
  ///
  /// Es lo único que mira el dedo. Lo que se toca es lo último que se pintó
  /// bajo él, porque el orden de pintado es el orden de profundidad: así
  /// nada se puede tocar a través de lo que tiene delante. Antes cada cosa
  /// tocable guardaba su rectángulo y se revisaban en un orden fijo —el cielo,
  /// el tablón, los carteles, las piezas—, y cada vez que algo quedaba detrás
  /// de otra cosa hacía falta un parche: el tablón detrás de una casa, la
  /// constelación detrás de un tejado. Con una sola lista no hay orden que
  /// parchear.
  ///
  /// Dueños: el número de la pieza (cero o más), o uno de [nobody] (algo que
  /// tapa pero no se toca: el prado, las montañas, la plaza), [building] (una
  /// casa de otro pueblo), [board], [sky] o [sign]. [regionData] lleva el
  /// pueblo del cartel.
  Float32List facePts = Float32List(0);
  Int32List faceStart = Int32List(1);
  Int32List faceOwner = Int32List(0);
  Int32List regionData = Int32List(0);
  int faceCount = 0;

  static const int nobody = -1;
  static const int building = -2;
  static const int board = -3;
  static const int sky = -4;
  static const int sign = -5;

  void _room(int faces, int floats) {
    if (faceOwner.length < faces) {
      final n = faces + faces ~/ 2 + 16;
      faceOwner = Int32List(n)..setRange(0, faceCount, faceOwner);
      regionData = Int32List(n)..setRange(0, faceCount, regionData);
      faceStart = Int32List(n + 1)..setRange(0, faceCount + 1, faceStart);
    }
    if (facePts.length < floats) {
      final used = faceStart[faceCount];
      facePts = Float32List(floats + floats ~/ 2 + 64)
        ..setRange(0, used, facePts);
    }
  }

  /// Algo pintado ahora, encima de todo lo anterior: un polígono de [n]
  /// vértices, con sus coordenadas `x, y` seguidas en [pts].
  void add(List<double> pts, int n, int owner, {int data = 0}) {
    final at = faceStart[faceCount];
    _room(faceCount + 1, at + n * 2);
    for (var i = 0; i < n * 2; i++) {
      facePts[at + i] = pts[i];
    }
    faceOwner[faceCount] = owner;
    regionData[faceCount] = data;
    faceCount++;
    faceStart[faceCount] = at + n * 2;
  }

  void addRect(Rect r, int owner, {int data = 0}) => add(
    [r.left, r.top, r.right, r.top, r.right, r.bottom, r.left, r.bottom],
    4,
    owner,
    data: data,
  );

  /// Lo que se ve en ese punto: el índice de lo último pintado ahí, o -1 si
  /// ahí no se pintó nada.
  int topAt(double x, double y) {
    for (var k = faceCount - 1; k >= 0; k--) {
      final a = faceStart[k], b = faceStart[k + 1];
      var dentro = false;
      for (var i = a, j = b - 2; i < b; j = i, i += 2) {
        final xi = facePts[i], yi = facePts[i + 1];
        final xj = facePts[j], yj = facePts[j + 1];
        if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
          dentro = !dentro;
        }
      }
      if (dentro) return k;
    }
    return -1;
  }

  /// De quién es lo que se ve en ese punto, o nulo si ahí no se pintó nada.
  int? ownerAt(double x, double y) {
    final k = topAt(x, y);
    return k < 0 ? null : faceOwner[k];
  }

  /// Si se puede tocar algo de [owner].
  static bool tappable(int owner) =>
      owner >= 0 || owner == board || owner == sky || owner == sign;

  /// Qué se toca en [pos]: lo que se ve bajo el dedo y, si eso no se puede
  /// tocar, lo tocable que se vea más cerca a menos de [reach] píxeles. Un
  /// tablón lejano o un cartel miden poco y un dedo no; pero sólo vale lo que
  /// **se ve**, así que la holgura nunca alcanza algo que esté tapado.
  ///
  /// Devuelve el índice de la zona, o -1 si no hay nada que tocar.
  int hitAt(Offset pos, {double reach = 8}) {
    final k = topAt(pos.dx, pos.dy);
    if (k >= 0 && tappable(faceOwner[k])) return k;
    for (var r = 3.0; r <= reach; r += 2.5) {
      var best = -1;
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        final o = topAt(pos.dx + math.cos(a) * r, pos.dy + math.sin(a) * r);
        if (o >= 0 && tappable(faceOwner[o]) && o > best) best = o;
      }
      if (best >= 0) return best;
    }
    return -1;
  }

  /// Se vacía entero al empezar cada fotograma. Que lo haga el propio mapa es
  /// lo que evita el fallo de olvidarse una: seis `clear()` en fila al
  /// principio de `paint` se convierten en cinco en cuanto alguien añade la
  /// séptima cosa tocable.
  void clear() {
    boards.clear();
    skies.clear();
    faceCount = 0;
  }
}
