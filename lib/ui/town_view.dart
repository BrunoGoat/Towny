import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/constellations.dart';
import '../data/landmarks.dart';
import '../engine/camera.dart';
import '../engine/folk.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../engine/scene.dart';
import '../engine/shooting_star.dart';
import '../engine/solids.dart';
import '../engine/town.dart';
import '../engine/world.dart';
import '../fx/effects.dart';
import '../fx/sensory.dart';
import '../l10n/lang.dart';
import '../model/appearance.dart';
import '../model/board.dart';
import '../model/board_slots.dart';
import '../model/habit.dart';
import '../model/piece.dart';
import '../model/store.dart';

/// Handle the surrounding UI uses to drive the wall.
class TownViewController {
  _TownViewState? _state;

  /// Si se está mirando el valle entero, para quien tenga que enterarse en
  /// el momento: el botón del valle se enciende mientras dura. [aloft] dice
  /// lo mismo, pero preguntado; esto avisa cuando cambia.
  final ValueNotifier<bool> aloftNow = ValueNotifier(false);

  /// Dónde va la fundación de la plaza: de cero a uno mientras cae, uno
  /// cuando está puesta, y negativo mientras espera a que llegue la cámara.
  @visibleForTesting
  double get founding => _state?._founding ?? 1.0;

  /// Cuánto le falta a la cámara para estar encima del pueblo elegido.
  @visibleForTesting
  double get farFromTown => _state?._farFromTown ?? 0.0;

  /// A qué distancia va la cámara.
  @visibleForTesting
  double get distanceTarget => _state?._cam.distanceTarget ?? 0.0;

  /// Hacia dónde mira la cámara y sobre qué punto del suelo.
  @visibleForTesting
  ({double yaw, double x, double z}) get aim => (
    yaw: _state?._cam.yawTarget ?? 0.0,
    x: _state?._cam.travelTarget ?? 0.0,
    z: _state?._cam.focusZTarget ?? 0.0,
  );

  void place() => _state?.placePiece();

  /// 0..1 while the place button is being held. The wall answers by lighting
  /// up where the stone is about to land.
  void setCharge(double v) => _state?.setCharge(v);
  void clearSelection() => _state?.clearSelection();
  void frameAll() => _state?.frameAll();
  void frameValley() => _state?.frameValley();

  /// El despegue: un empujón hacia arriba antes de que entren las nubes, para
  /// que el vuelo empiece a verse antes de que haya nada que lo tape.
  void liftOff() => _state?.liftOff();

  /// Y la llegada, que se hace detrás de las nubes: la cámara ya está en el
  /// valle cuando se abren.
  void arriveAtValley() => _state?.arriveAtValley();

  /// Si la cámara está arriba, mirando el valle entero.
  bool get aloft => _state?._aloft ?? false;

  /// True once there is more than one town to compare.
  bool get hasValley => (_state?._entries.length ?? 1) > 1;
  void goTo(double x, double z) => _state?.goTo(x, z);

  /// Lleva la cámara al hueco donde va a caer la que viene.
  void lookAtNext() => _state?.lookAtNext();
  double get travel => _state?._cam.travelTarget ?? 0;

  Palette? get palette => _state?._palette;

  /// En qué huecos del tablón de la plaza hay papel, según el plano que la
  /// vista tiene ahora mismo en la mano.
  ///
  /// Está para poder exigir en un test lo que no se ve desde fuera: que mover
  /// un papel llegue de verdad hasta el plano del pueblo. Todo lo de debajo
  /// —el aviso de la tabla, las calcomanías de la plancha— estaba bien y
  /// probado, y en la pantalla no se movía nada, porque el plano se guarda por
  /// hábito y por piezas y lo que volvía era el de antes.
  @visibleForTesting
  List<int> get notices => _state?._town.notices ?? const [];

  /// Dónde hay que tocar para abrir el tablón de cada pueblo.
  ///
  /// Para poder exigir en un test lo único que de verdad importa de todo
  /// esto: que tocando el mueble se abra **su** hoja. Lo de dentro —cuánto
  /// miden los blancos, si se pisan— son medios; esto es el fin.
  @visibleForTesting
  List<Rect> get boardTargets => [
    for (final b in _state?._hits.boards ?? const []) b.rect,
  ];

  /// De quién es lo que se ve en ese punto: ver [TouchMap.ownerAt].
  @visibleForTesting
  int? ownerAt(Offset at) => _state?._hits.ownerAt(at.dx, at.dy);
}

/// El encargo de un pueblo: lo que hace falta para levantarlo, y nada más.
///
/// Vive suelto y no dentro de la vista porque lo piden dos sitios: la vista,
/// que construye el plano y lo pinta, y el arranque de la app, que se lo manda
/// a otro hilo para que cuando la vista lo pida ya esté hecho. Si los dos
/// armaran el encargo por su cuenta y uno cambiara, el pueblo que vuelve del
/// otro hilo no sería el que la vista espera — y no se rompería nada, pero el
/// trabajo se tiraría a la basura sin que nadie se enterara.
TownOrder townOrder(Habit h, {required List<Habit> valley, int? placed}) {
  final (cx, cz) = Habit.centreOf(h.slot);
  return TownOrder(
    placed: placed ?? h.total,
    character: h.place.order,
    cx: cx,
    cz: cz,
    chronicle: h.chronicle,
    // La misma lista que guarda el hábito, no una copia: lo que se apunte
    // justo debajo lo tiene que ver el plano sin volver a construirlo.
    folk: h.folk,
    // En qué huecos de su tablón hay papel. Sale de las mismas dos cuentas
    // que lo clavan al acercarse —qué hay que decir, y dónde quedó clavado
    // cada papel—, así que la silueta que se ve desde el valle es la de lo que
    // hay de verdad y en su sitio.
    notices: BoardSlots.instance.assign(
      h.id,
      boardNotices(h, valley: valley),
      slots: NoticeBoard.capacity,
    ),
    seed: h.townSeed,
  );
}

class TownView extends StatefulWidget {
  const TownView({
    super.key,
    required this.store,
    required this.controller,
    required this.onTownLandmark,
    required this.onPlaced,
    required this.onStoneTapped,
    required this.onNothingTapped,
    required this.onCameraMoved,
    required this.onFlewOut,
    required this.onSkyTapped,
    required this.onTownTapped,
    required this.onBoardTapped,
    required this.onWhisper,
    required this.onPaletteChanged,
  });

  final Store store;
  final TownViewController controller;

  /// A landmark of the town finished, and which number it is.
  final void Function(Landmark mark, int ordinal) onTownLandmark;

  /// A piece has just been laid, and which one it is.
  final void Function(Piece piece) onPlaced;
  final void Function(Piece piece) onStoneTapped;

  /// Alguien se quedó mirando la constelación de esta noche y la tocó.
  final void Function(String id) onSkyTapped;

  /// Alguien tocó la cúpula de un observatorio.

  /// Un toque en el aire. Cerrar la tarjeta de pieza que estuviera abierta es lo mismo
  /// que dejar de mirar la pieza, así que lo hace el mismo gesto y no un aspa.
  final VoidCallback onNothingTapped;

  /// Alguien movió la cámara a mano. Lo que hubiera puesto encima sobra.
  final VoidCallback onCameraMoved;

  /// Se alejó tanto del pueblo que lo que está mirando ya es el valle.
  ///
  /// El botón de explorar el valle existe y está a un toque, pero apartarse
  /// hasta que el pueblo es una mancha es pedir lo mismo con el gesto que
  /// tiene a mano — y quedarse ahí, con el pueblo pequeño y el valle sin
  /// encuadrar, es el peor de los dos sitios.
  final VoidCallback onFlewOut;

  /// The sign over another town was tapped: go and live there.
  final void Function(int index) onTownTapped;

  /// The notice board in a town's plaza was tapped: read it.
  final void Function(int index) onBoardTapped;

  /// Un susurro sobre la escena. Con [duration] para lo que no se lee en tres
  /// segundos: el título que acaba de ganarse es una frase entera y es la
  /// única vez que va a salir.
  final void Function(String message, {Duration duration}) onWhisper;
  final void Function(Palette palette) onPaletteChanged;

  @override
  State<TownView> createState() => _TownViewState();
}

class _TownViewState extends State<TownView>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final OrbitCamera _cam = OrbitCamera();
  final EffectSystem _fx = EffectSystem();

  /// Lo que el pintor deja marcado al pasar, para poder tocarlo. Aquí no se
  /// toca: se le pasa, él lo vacía y lo rellena.
  final TouchMap _hits = TouchMap();

  late TownLayout _town;
  int _layoutFor = -1;
  int _slotFor = -1;

  /// Las comarcas del valle con las que se hizo el plano. Si alguna cambia
  /// (ver [Store.changeRegion]) hay que rehacerlo, aunque no cambie la cuenta
  /// de piezas.
  String _regionsFor = '';
  static String _regionsOf(Store s) =>
      [for (final h in s.habits) h.character].join(',');

  /// Every town in the valley, the neighbours included. A neighbour's layout
  /// only changes when its own habit is built in, so they are kept rather than
  /// rebuilt on every piece.
  final Map<String, TownLayout> _valley = {};
  List<TownEntry> _entries = const [];

  PlacementFx? _placement;
  PlaceResult? _pendingResult;

  double _time = 0;

  /// Cuál fue la última fugaz que sonó, para no tocarla sesenta veces. Null
  /// cuando no hay ninguna en el cielo, que es cuando hay que callar la suya.
  int? _lastWish;
  Duration _last = Duration.zero;

  /// The building that has just been finished, and how long since.
  int? _finished;
  double _finishedAge = 99;

  /// La casa que acaba de rematarse y el vecino que todavía no ha salido de
  /// ella, con los segundos que lleva en pie.
  ///
  /// Aparte de [_finished] porque no duran lo mismo: la fiesta se apaga a los
  /// dos segundos y medio y el vecino sale a los tres. Ver [Townsfolk.debut].
  int? _newborn;
  double _newbornAge = 99;

  /// A landmark being shown off: the camera turns slowly around it.
  int? _showcase;
  double _showcaseAge = 0;

  int? _selectedPiece;
  double _charge = 0;

  static const int _budgetOverride = int.fromEnvironment(
    'BUDGET',
    defaultValue: -1,
  );

  /// Cuántas caras **de las que se ven** vale la pena dibujar. Se cede cuando
  /// el fotograma se alarga y se recupera cuando no, para que un teléfono
  /// viejo enseñe un pueblo más pobre en vez de uno a tirones.
  ///
  /// Lo que se recorta ya no es «lo que está lejos» sino «lo que ocupa menos
  /// pantalla», y el pueblo que se está mirando se sirve primero: eso vive en
  /// el renderizador. Aquí sólo está el termostato.
  int _budget = _budgetOverride > 0 ? _budgetOverride : 15000;

  /// El suelo del termostato: nueve mil caras en pantalla es un pueblo de
  /// trescientas piezas entero, así que por debajo de eso no se baja nunca.
  ///
  /// Estaba en cuatro mil, que son menos de las que tiene un pueblo de
  /// doscientas — y por eso un teléfono que se quedaba corto un momento se
  /// comía medio pueblo y tardaba en devolverlo. Bajar es más lento y subir
  /// más rápido por el mismo motivo: de los dos errores posibles, enseñar de
  /// menos es el que se nota.
  static const int _suelo = 9000;
  static const int _sueloMax = 18000;
  double _frameAvg = 16;

  late Palette _palette;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _palette = _buildPalette();
    _rebuildLayout();
    _frameTown();
    // Fixed framing for development screenshots.
    const camYaw = int.fromEnvironment('CAM_YAW', defaultValue: -999);
    const camPitch = int.fromEnvironment('CAM_PITCH', defaultValue: -999);
    const camDist = int.fromEnvironment('CAM_DIST', defaultValue: -999);
    if (camYaw != -999) _cam.yawTarget = camYaw * math.pi / 180;
    if (camPitch != -999) _cam.pitchTarget = camPitch * math.pi / 180;
    if (camDist != -999) _cam.distanceTarget = camDist.toDouble();
    // Aims the town camera at a spot on the ground while judging a landmark.
    const camX = int.fromEnvironment('CAM_X', defaultValue: -999);
    const camZ = int.fromEnvironment('CAM_Z', defaultValue: -999);
    if (camX != -999) _cam.travelTarget = camX / 10;
    if (camZ != -999) _cam.focusZTarget = camZ / 10;
    _cam.snap();
    // Recién fundado, el pueblo no arranca en su encuadre: arranca en la toma
    // en la que lo dejaron las preguntas, que pintaban este mismo valle, y
    // baja desde ahí. Así no hay corte entre una pantalla y la otra.
    if (widget.store.justFounded) HandoffShot.apply(_cam);
    _ticker = createTicker(_tick)..start();
    widget.store.addListener(_onStoreChanged);
    // Y al tablón, que es lo único que cambia cómo se ve el pueblo sin que se
    // ponga una pieza: mover un papel de hueco tiene que verse también en la
    // plancha de la plaza, que es la misma plancha.
    BoardSlots.instance.addListener(_renotice);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPaletteChanged(_palette);
    });
  }

  /// One town's layout, kept between frames unless its own count moved.
  TownLayout _layoutOf(Habit h, int? override) {
    final n = override ?? h.total;
    // La comarca va en la clave: el mismo hábito con la misma cuenta de
    // piezas es otro plano si cambió de comarca.
    final key = '${h.id}:${h.character}:$n';
    final had = _valley[key];
    if (had != null) return had;
    // Only ever one layout per habit in flight: the old one is dropped the
    // moment its count changes.
    _valley.removeWhere((k, _) => k.startsWith('${h.id}:'));
    final made = townOrder(h, valley: widget.store.habits, placed: n).layout;
    // Quién ha nacido. Aquí y no en el almacén porque aquí ya está el plano
    // construido —levantarlo otra vez para contar casas cuesta lo que cuesta
    // un pueblo— y porque esto pasa exactamente una vez por cada cuenta de
    // piezas, que es cuando puede haber nacido alguien.
    widget.store.enrol(h, made);
    return _valley[key] = made;
  }

  /// Puts the camera where a town is best first seen: from its own plaza,
  /// far enough back to take it in.
  /// Tells the camera how wide the valley it is standing in actually is.
  ///
  /// Every town, not only the one in front: a piece laid in the town on the
  /// far side still has to be somewhere the camera is allowed to look, and
  /// panning across the valley has to reach the far edge of it.
  void _tellCameraTheWorld() {
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final e in _entries) {
      final reach = e.layout.radius + 4;
      if (e.layout.cx - reach < lo) lo = e.layout.cx - reach;
      if (e.layout.cx + reach > hi) hi = e.layout.cx + reach;
    }
    if (lo > hi) {
      lo = -2;
      hi = 2;
    }
    _cam.reaches(lo, hi);
  }

  /// Si la cámara está arriba, mirando el valle entero.
  bool _aloft = false;

  /// Cuánto lleva levantada la plaza del pueblo recién fundado, de cero a uno.
  ///
  /// Arranca en cero la primera vez que se pinta un valle que acaba de
  /// fundarse, sube en segundo y medio y se queda en uno para siempre. No se
  /// guarda: es un instante.
  double _founding = 1.0;

  /// Cuánto lleva esperando la plaza a que la cámara llegue (ver [_tick]).
  double _arriving = 0;

  /// A qué distancia del centro del pueblo, en el suelo, se da por llegada la
  /// cámara; y cuánto se espera como mucho, por si no llega nunca —alguien
  /// que la arrastra hacia otro lado mientras vuela—.
  static const double _arrived = 1.2, _arrivalLimit = 5.0;

  /// Lo que le falta a la cámara para estar encima del pueblo, en el suelo.
  double get _farFromTown {
    final dx = _cam.travel - _town.cx, dz = _cam.focusZ - _town.cz;
    return math.sqrt(dx * dx + dz * dz);
  }

  /// Segundos que le quedan a la cámara de planeo, después de fundar.
  double _glide = 0;

  /// Para no pedir el vuelo dos veces mientras se sigue apartando.
  bool _asked = false;

  /// A partir de dónde lo que se está mirando ya no es este pueblo.
  ///
  /// Siete veces su propio radio, que es el doble de lo que era. A tres y medio
  /// el pueblo todavía ocupa un tercio de la pantalla, y apartarse un poco para
  /// ver dónde cae una casa nueva es algo que se hace constantemente: salía
  /// volando al valle quien sólo estaba mirando. El botón está a un toque, así
  /// que el gesto no tiene por qué ser el atajo rápido — tiene que ser
  /// inconfundible, y eso quiere decir apartarse hasta que este pueblo ya no
  /// sea de lo que va la pantalla.
  ///
  /// Va de la mano de [_townReach], que es lo que la cámara deja alejarse
  /// dentro de un pueblo: esto tiene que quedar por debajo de aquello o no se
  /// llega nunca.
  double get _leaveAt => math.max(_town.radius * 7.2, 68.0);

  /// Hasta dónde se puede uno apartar dentro de un pueblo.
  ///
  /// La cámara corta el alejarse en el doble de esto, así que queda un cinco
  /// por ciento de holgura por encima de [_leaveAt]: lo justo para que el
  /// último pellizco cruce la raya en vez de quedarse pegado a ella.
  double get _townReach => math.max(_town.radius * 3.8, 36.0);

  /// El despegue: la cámara se levanta un poco antes de que entren las nubes.
  void liftOff() {
    _cam.distanceTarget = clampD(
      _cam.distanceTarget * 1.5,
      OrbitCamera.minDistance,
      OrbitCamera.maxDistance,
    );
    _cam.pitchTarget = clampD(
      _cam.pitchTarget + 0.10,
      OrbitCamera.minPitch,
      OrbitCamera.maxPitch,
    );
    _cam.focusYTarget += 1.4;
    _cam.follow = false;
  }

  /// Y la llegada, detrás de las nubes.
  ///
  /// Se encuadra el valle y se **salta** hasta él: lo que hay que esconder es
  /// justo eso, y para eso están las nubes. Lo único que no se salta es el
  /// último palmo — se llega un poco más arriba y más lejos de lo que toca, y
  /// esa última caída la hace el amortiguador de la cámara mientras las nubes
  /// se abren, así que lo primero que se ve ya se está moviendo.
  void arriveAtValley() {
    frameValley();
    _cam.snap();
    _cam.distance *= 1.07;
    _cam.focusY += 1.8;
    _cam.pitch = clampD(
      _cam.pitch + 0.06,
      OrbitCamera.minPitch,
      OrbitCamera.maxPitch,
    );
  }

  void _frameTown() {
    _landed();
    _cam.travelTarget = _town.cx;
    _cam.focusZTarget = _town.cz;
    _cam.focusYTarget = 1.4;
    _cam.distanceTarget = clampD(
      _town.radius * 1.9,
      9.0,
      OrbitCamera.townFraming,
    );
    _cam.yawTarget = 0.62;
    _cam.pitchTarget = 0.46;
    _cam.wallLength = _townReach;
    _tellCameraTheWorld();
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    BoardSlots.instance.removeListener(_renotice);
    widget.controller._state = null;
    _ticker.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    final store = widget.store;
    if (store.shownTotal != _layoutFor ||
        store.habit.slot != _slotFor ||
        _regionsOf(store) != _regionsFor) {
      _rebuildLayout();
    }
  }

  /// Alguien movió un papel del tablón: vuelve a mirar en qué hueco quedó.
  ///
  /// **Sólo eso.** No se rehace el plano ni se vuelve a levantar el pueblo:
  /// mover un papel no mueve un vértice. Lo que cambia es la lista de huecos
  /// del plano, y con ella las calcomanías que `renotice` estampa sobre la
  /// plancha de la plaza en el fotograma siguiente.
  ///
  /// Esto antes llamaba a [_rebuildLayout], y por eso no funcionaba: el plano
  /// se guarda por hábito y por cuenta de piezas, mover un papel no cambia
  /// ninguna de las dos, y lo que volvía era el mismo plano con los huecos de
  /// antes. El pueblo se enteraba al cerrar y abrir la app y no antes.
  void _renotice() {
    final store = widget.store;
    for (final h in store.habits) {
      final huecos = BoardSlots.instance.assign(
        h.id,
        boardNotices(h, valley: store.habits),
        slots: NoticeBoard.capacity,
      );
      // El plano de este hábito, sea cual sea la cuenta de piezas con la que
      // esté guardado — que durante una caída no es la misma que la del
      // almacén. [_layoutOf] deja uno solo por hábito, así que esto toca uno.
      for (final e in _valley.entries) {
        if (e.key.startsWith('${h.id}:')) e.value.notices = huecos;
      }
    }
  }

  void _rebuildLayout() {
    final store = widget.store;
    final wasSlot = _slotFor;
    _entries = [
      for (var i = 0; i < store.habits.length; i++)
        _entryFor(store, store.habits[i]),
    ];
    _town = _entries[store.active.clamp(0, _entries.length - 1)].layout;
    _layoutFor = store.shownTotal;
    _slotFor = store.habit.slot;
    _regionsFor = _regionsOf(store);
    _cam.wallLength = _townReach;
    _tellCameraTheWorld();

    // Moving to another habit is moving to another town: take the camera
    // there rather than leaving it hanging over an empty valley.
    if (wasSlot != _slotFor) {
      _frameTown();
      _fx.clear();
      _placement = null;
      _finished = null;
      _newborn = null;
      _showcase = null;
    }
  }

  TownEntry _entryFor(Store store, Habit h) {
    final mine = h.id == store.habit.id;
    return TownEntry(
      layout: _layoutOf(h, mine ? store.shownTotal : null),
      name: h.name,
      symbol: h.symbol,
      placed: mine ? store.shownTotal : h.total,
    );
  }

  /// Overrides the clock during development so every time of day can be
  /// inspected without waiting for it.
  static const int _hourOverride = int.fromEnvironment(
    'HOUR',
    defaultValue: -1,
  );

  /// La hora con la que se pinta el cielo. La música se mezcla con la misma,
  /// así que la luz y lo que suena cambian a la vez.
  double get _hour {
    if (_hourOverride >= 0) return _hourOverride.toDouble();
    return Appearance.instance.hourNow;
  }

  Palette _buildPalette() =>
      Palette.forMoment(_hour, season: Appearance.instance.season);

  // ------------------------------------------------------------------ tick

  void _tick(Duration elapsed) {
    final dtRaw = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final dt = dtRaw.clamp(0.0005, 0.05);
    _time += dt;
    if (widget.store.justFounded && _founding >= 1.0) {
      widget.store.justFounded = false;
      // La cámara mira el claro desde cerca: lo que va a pasar pasa ahí, y de
      // lejos una plaza subiendo del suelo son tres píxeles moviéndose.
      _frameTown();
      _cam.distanceTarget = 11.0;
      _cam.pitchTarget = 0.30;
      _glide = 3.6;
      // **Primero llegar, después fundar.** El pueblo siguiente se funda
      // lejos de donde está mirando la cámara —en el pueblo de antes—, y si la
      // plaza empezaba a caer en el mismo instante, caía mientras la cámara
      // todavía volaba hacia ella: se veía el final, o nada. Así que espera,
      // sin dibujarse, a que la cámara esté encima. La primera vez la cámara
      // ya llega mirando el claro, y ahí empieza en seguida, como siempre.
      _founding = _farFromTown > _arrived ? -1.0 : 0.0;
      _arriving = 0;
    }
    if (_founding < 0) {
      _arriving += dt;
      // Que siga planeando mientras vuela: es el mismo viaje.
      if (_glide < 1) _glide = 1;
      if (_farFromTown <= _arrived || _arriving > _arrivalLimit) {
        _founding = 0.0;
      }
    } else if (_founding < 1.0) {
      final antes = _founding;
      _founding = math.min(1.0, _founding + dt / FoundingShow.seconds);
      _plazaCae(antes, _founding);
      if (_founding >= 1.0) _frameTown();
    }

    if (_budgetOverride <= 0) {
      _frameAvg = _frameAvg * 0.92 + dtRaw * 1000 * 0.08;
      // En calidad máxima el detalle no se recorta tanto: quien la encendió
      // eligió ver más a cambio de menos fotogramas.
      final suelo = Appearance.instance.cinematic ? _sueloMax : _suelo;
      if (_budget < suelo) _budget = suelo;
      if (_frameAvg > 24 && _budget > suelo) {
        _budget -= 220;
      } else if (_frameAvg < 15 && _budget < 26000) {
        _budget += 420;
      }
    }

    // Planea mientras baja al pueblo recién fundado, y sigue al dedo el resto
    // del tiempo. Un toque corta el planeo: quien mueve la cámara la quiere ya.
    if (_glide > 0) _glide -= dt;
    _cam.step(dt, rate: _glide > 0 ? 1.5 : 7.5);
    _watchTheHorizon();
    _fx.update(dt);
    if (_finished != null) {
      _finishedAge += dt;
      if (_finishedAge > 2.6) _finished = null;
    }
    if (_newborn != null) {
      _newbornAge += dt;
      // Un poco más de lo que tarda en salir: para cuando se apaga, el vecino
      // ya tiene apuntada su hora y no hace falta seguir diciéndolo.
      if (_newbornAge > Townsfolk.settleIn + 1.0) _newborn = null;
    }
    _turnAround(dt);

    final p = _placement;
    if (p != null) {
      final wasLanded = p.landed;
      p.update(dt);
      if (!wasLanded && p.landed) _onImpact(p);
      if (p.done) _placement = null;
    }

    _spawnAmbient(dt);

    Sensory.instance.music(_hour, dt);
    // Una sola vez por fugaz: esto corre en cada fotograma y la fugaz dura
    // cinco segundos. Por su nombre y no por el reloj, porque las que se piden
    // a mano desde los ajustes no caen en ninguna ventana del reloj.
    //
    // Y el sonido se corta con ella: dura lo mismo que el vuelo, así que si se
    // pierde la estrella —se apaga la pantalla, se sale del pueblo— lo que no
    // puede quedar es la música sonando en un cielo que ya no está.
    final medida = context.size;
    final fugaz = medida == null
        ? null
        : ShootingStar.at(
            _time,
            _hour,
            SkyView.of(
              _cam.projector(medida.width, medida.height, _time),
              medida.width,
              medida.height,
              travel: _cam.travel,
            ),
          );
    if (fugaz != null && fugaz.id != _lastWish) {
      _lastWish = fugaz.id;
      Sensory.instance.wish();
    } else if (fugaz == null && _lastWish != null) {
      _lastWish = null;
      Sensory.instance.hushWish();
    }

    final pal = _buildPalette();
    final antes = _palette;
    _palette = pal;

    // Y avisar arriba cuando la luz cambia de verdad.
    //
    // Esto se hacía **una sola vez**, en el primer fotograma, y de ahí en
    // adelante los botones, los rótulos y las hojas se quedaban con el color
    // que tuviera el cielo al abrir la app. Con el reloj de verdad casi no se
    // notaba —quien abre de día y sigue abierto hasta la noche es raro— pero al
    // fingir la hora saltaba entero: el pueblo se hacía de noche y la interfaz
    // seguía siendo la parda del mediodía, con los botones casi invisibles
    // sobre un cielo negro. La interfaz sale de la luz de la escena; si la luz
    // cambia y ella no, deja de salir de ahí.
    //
    // Se mira si cambió algo que importe y no cada fotograma a ciegas: el color
    // del cielo va en ocho bits, así que entre minuto y minuto es el mismo
    // número y esto no dispara nada.
    if (pal.skyTop != antes.skyTop || pal.accent != antes.accent) {
      widget.onPaletteChanged(pal);
    }

    if (mounted) setState(() {});
  }

  /// The slow turn around a finished landmark, and the slower one the town
  /// takes on its own when nobody has touched it for a while.
  ///
  /// A town that sits perfectly still is a photograph. One that keeps turning,
  /// a degree every few seconds, is a place you keep watching without deciding
  /// to — which is exactly what it should be doing while you are not building.
  void _turnAround(double dt) {
    final show = _showcase;
    if (show != null) {
      _showcaseAge += dt;
      if (_showcaseAge > 6.5) {
        _showcase = null;
      } else {
        _cam.yawTarget += dt * 0.28;
        _cam.follow = false;
        return;
      }
    }
    _idleFor += dt;
    if (_idleFor > 5.0) {
      // Eases in over a couple of seconds so it never starts with a jolt.
      final k = clampD((_idleFor - 5.0) / 2.5, 0, 1);
      _cam.yawTarget += dt * 0.05 * k;
    }
  }

  double _idleFor = 0;
  void _touched() {
    _idleFor = 0;
    _glide = 0;
  }

  int _ambientCounter = 0;

  /// The town smoking away on its own.
  ///
  /// A chimney with smoke coming out of it is the cheapest thing in the whole
  /// app and the one that most makes the place look lived in: it turns a model
  /// of a town into a town where somebody has just lit a fire.
  void _spawnAmbient(double dt) {
    _ambientCounter++;
    final town = _town;
    final take = math.min(widget.store.shownTotal, town.pieces.length);
    if (take <= 0) return;

    // The same gust the renderer leans everything else with.
    final wx = math.sin(_time * 0.31) * 0.34 + 0.12;
    final wz = math.cos(_time * 0.23) * 0.26 - 0.08;

    // A handful of chimneys per frame, chosen round-robin so every one of them
    // gets its turn without the cost of walking the whole town.
    var found = 0;
    for (var k = 0; k < 40 && found < 3; k++) {
      final i = (_ambientCounter * 7 + k * 131) % take;
      final piece = town.pieces[i];
      if (piece.kind != PieceKind.chimney) continue;
      final dx = piece.cx - _cam.travel, dz = piece.cz - _cam.focusZ;
      if (dx * dx + dz * dz > 26 * 26) continue;
      // Todas las chimeneas echan humo. Se apagaban a suertes —«no todos los
      // hogares están encendidos»—, pero un pueblo empieza con dos casas: una
      // chimenea humeando al lado de otra que no se lee como que ésa está rota.
      found++;
      if (_ambientCounter % 4 != 0) continue;
      _fx.smoke(
        piece.cx,
        piece.y1 + 0.06,
        piece.cz,
        wx,
        wz,
        owner: piece.building,
      );
    }

    // Sun on the water.
    if (_palette.isDaylight && _ambientCounter % 5 == 0) {
      for (var k = 0; k < 26; k++) {
        final i = (_ambientCounter * 13 + k * 97) % take;
        final piece = town.pieces[i];
        if (piece.kind != PieceKind.water) continue;
        final dx = piece.cx - _cam.travel, dz = piece.cz - _cam.focusZ;
        if (dx * dx + dz * dz > 20 * 20) continue;
        _fx.glint(
          piece.cx + hashJitter(piece.w * 0.42, _ambientCounter, k, 1),
          0.07,
          piece.cz + hashJitter(piece.d * 0.42, _ambientCounter, k, 2),
        );
        break;
      }
    }
  }

  /// Where the camera should sit to watch a piece land, in whichever world we
  /// are building. The wall travels along its own axis; the town orbits its
  /// plaza, so the most the camera does there is look at the right height.
  void _followPlacement(int index) {
    final piece = _town.pieceFor(index);
    if (piece == null) return;
    _cam.follow = true;
    _cam.travelTo(piece.cx);
    _cam.focusZTarget = piece.cz;
    _cam.focusYTarget = clampD(piece.y1 + 0.6, 1.0, 6.0);
    if (_cam.distanceTarget > 20) _cam.distanceTarget = 15;
  }

  // --------------------------------------------------------------- placing

  void placePiece() {
    _touched();
    _showcase = null;
    final store = widget.store;
    store.setPreview(null);
    final result = store.placePiece();
    _selectedPiece = null;
    _followPlacement(result.piece.index);
    _pendingResult = result;
    // In the town a piece is set down, not dropped from a crane: from high up
    // it reads as a bug, and the anticipation is in the shadow closing under
    // it rather than in the height it falls from.
    _placement = PlacementFx(result.piece.index, dropHeight: 2.3);
    widget.onPlaced(result.piece);
    setState(() {});
  }

  /// El enlosado y el tablón tocando el suelo el día que se funda el
  /// pueblo.
  ///
  /// Caen del cielo como cualquier pieza, así que aterrizan como cualquier
  /// pieza: polvo, un temblor corto y el golpe. Sin esto la caída se para en
  /// seco y no se lee como que algo se posó, sino como que algo dejó de
  /// moverse.
  ///
  /// Se mira si el reloj de la fundación **cruzó** el instante del aterrizaje
  /// en este fotograma, y no si ya pasó: a sesenta por segundo, «ya pasó» es
  /// un golpe por fotograma durante el resto de la caída.
  ///
  /// El enlosado golpea como un sillar y el tablón menos, porque pesa menos y
  /// porque viene detrás: dos temblores de los grandes seguidos marean. El del enlosado levanta polvo en todo su ancho, que
  /// es lo que hace que se lea como una plaza entera posándose y no como una
  /// tapa.
  void _plazaCae(double antes, double ahora) {
    final l = _town;
    for (final (cuando, x, z, radio, fuerza) in [
      (FoundingShow.plazaLands, l.cx, l.cz, TownLayout.plazaReach * 1.1, 1.1),
      (
        FoundingShow.boardLands,
        NoticeBoard.xAt(l.cx),
        NoticeBoard.zAt(l.cz),
        0.8,
        0.8,
      ),
    ]) {
      if (antes >= cuando || ahora < cuando) continue;
      _fx.impact(V3(x, 0, z), radio, strength: fuerza);
      _cam.shake = fuerza > 1 ? 0.055 : 0.035;
      Sensory.instance.impact(strength: fuerza);
    }
  }

  /// The town's version of the landing: the shake and the sound, and a
  /// celebration when a building is finished rather than when a milestone is.
  void _onImpact(PlacementFx fx) {
    final town = _town;
    final piece = town.pieceFor(fx.brickIndex);
    final result = _pendingResult;
    _pendingResult = null;
    if (piece == null) return;

    _fx.impact(V3(piece.cx, piece.y0, piece.cz), piece.w * 0.7, strength: 1.1);
    _cam.shake = 0.05;
    Sensory.instance.impact(strength: 1.1);

    final building = town.buildings[piece.building];
    final done = piece.index == building.firstPiece + building.cost - 1;
    if (done) {
      _finished = building.index;
      _finishedAge = 0;
      // Y en una casa —no en un hito, que no es de nadie— acaba de nacer
      // alguien. Se cuenta desde aquí, que es cuando la pieza se posa y no
      // cuando se soltó.
      if (!building.isLandmark) {
        _newborn = building.index;
        _newbornAge = 0;
      }
      _fx.celebrate(
        V3(building.cx, 0, building.cz),
        (building.isLandmark ? 1.9 : 1.15),
        count: building.isLandmark ? 52 : 30,
      );
      // Step back far enough to see the whole of what was just finished. The
      // point of the moment is the building, not the confetti.
      _cam.follow = false;
      _cam.travelTo(building.cx);
      _cam.focusZTarget = building.cz;
      // Aimed a little low, so the building sits in the upper half of the
      // screen and the card that comes up has somewhere to go.
      _cam.focusYTarget = clampD(building.peakY * 0.18, 0.3, 2.2);
      _cam.pitchTarget = clampD(_cam.pitchTarget, 0.14, 0.34);
      _cam.distanceTarget = clampD(building.peakY * 2.6 + 4.0, 9, 28);
      Future.delayed(const Duration(milliseconds: 220), () {
        Sensory.instance.milestone();
      });
      final mark = building.landmark;
      if (mark != null) {
        var ordinal = 0;
        for (final b in town.buildings) {
          if (b.isLandmark && b.index <= building.index) ordinal++;
        }
        // The camera takes a slow turn around it while the card is up: it is
        // the one moment where the thing itself is worth looking at from more
        // than one side.
        _showcase = building.index;
        _showcaseAge = 0;
        widget.onTownLandmark(mark, ordinal);
      } else {
        widget.onWhisper(
          tr('${building.name} en pie', '${building.name} is standing'),
        );
      }
    }
    if (result != null && result.returned) _welcomeBack(result, town, done);
    // Y si ésta fue la pieza que abrió el valle, se dice. Pasa una sola vez en
    // la vida de un valle, y si no se dijera nadie se enteraría: el anillo del
    // más se cierra y ya está, que es muy poco para lo que acaba de pasar.
    if (result != null && result.unlocked) {
      _fx.celebrate(V3(town.cx, 0, town.cz), 2.0, count: 46);
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) Sensory.instance.milestone();
      });
      widget.onWhisper(
        tr(
          'El valle abre un segundo solar. Ya podés fundar otro pueblo.',
          'The valley opens a second plot. You can found another town now.',
        ),
      );
    }
    // Y si ésta fue la pieza que ganó el título, el pueblo lo dice en voz alta
    // y por sorpresa. Es lo único de toda la app que llega sin avisar: no hay
    // cuenta atrás en ninguna pantalla, ni papel diciendo lo que falta, así que
    // esto y el papel que aparece en el tablón son todo lo que hay. Y por eso
    // se celebra como un hito, que es lo que es.
    final titulo = result?.crowned;
    if (titulo != null) {
      _fx.celebrate(V3(town.cx, 0, town.cz), 2.4, count: 54);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Sensory.instance.milestone();
      });
      widget.onWhisper(titulo, duration: const Duration(seconds: 7));
    }
  }

  /// El regreso, que es el momento más importante que tiene esta app.
  ///
  /// Se despachaba con el mismo susurro de tres segundos que «Molino en pie»,
  /// y no es la misma clase de cosa. Una app de hábitos no consigue que nadie
  /// sea perfecto; lo más que puede hacer es que abandonar del todo sea cada
  /// vez más difícil, y eso se juega entero acá — en si volver se siente como
  /// una fiesta o como pasar lista.
  ///
  /// Así que la celebración crece con lo largo que fue el hueco, medido desde
  /// donde empieza a ser un hueco para vos: volver después de veinte días
  /// tiene que sentirse como rematar un hito, porque psicológicamente es más
  /// que eso. Alguien que vuelve está demostrando que el abandono no era
  /// definitivo, y eso vale más que cualquier racha que pudiera haber
  /// conservado.
  ///
  /// Antes esto se medía por lo apagado que estaba el pueblo, y las luces
  /// volvían despacio. El pueblo ya no se apaga; la fiesta es la misma.
  void _welcomeBack(PlaceResult result, TownLayout town, bool finished) {
    // Cero en el umbral de lo tuyo, uno dos semanas más allá.
    final desde = Store.awayAfter(widget.store.habit);
    final hondo = clampD((result.awayDays - desde) / 14.0, 0.0, 1.0);

    // Una vuelta de verdad se oye. Es el sonido de reparar, que ya existía
    // para esto exactamente y no se usaba en el único sitio donde significa
    // algo.
    if (hondo > 0.25) {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) Sensory.instance.repair();
      });
    }

    // Y se ve. Chispas desde la plaza, tantas como largo fue el hueco, y la
    // cámara se aparta para que se vea el pueblo entero en vez de la piedra
    // que acabás de poner.
    if (hondo > 0.45) {
      _fx.celebrate(
        V3(town.cx, 0, town.cz),
        1.6 + 1.2 * hondo,
        count: (24 + 40 * hondo).round(),
      );
      // Salvo que esta misma pieza haya rematado un edificio: entonces la
      // cámara ya está puesta sobre él y es suya. Dos encuadres peleándose por
      // el mismo momento es peor que cualquiera de los dos.
      if (finished) return;
      _cam.follow = false;
      _cam.travelTarget = town.cx;
      _cam.focusZTarget = town.cz;
      _cam.focusYTarget = 1.8;
      _cam.pitchTarget = 0.52;
      _cam.distanceTarget = clampD(_townDistance(), 9, 90);
    }

    widget.onWhisper(
      result.woke
          // Volvió antes de lo que había dicho. Eso no se corrige, se celebra.
          ? tr(
              'El pueblo despierta antes de tiempo.',
              'The town wakes up early.',
            )
          : hondo > 0.6
          ? tr(
              'Volviste. Está todo donde lo dejaste.',
              "You're back. Everything is where you left it.",
            )
          : tr('El pueblo te estaba esperando', 'The town was waiting for you'),
    );
  }

  // ---------------------------------------------------------------- camera

  /// The whole valley: every town at once, from high enough to take them all
  /// in. This is the view that answers how the habits are doing against each
  /// other, so it is one tap away rather than a gesture nobody finds.
  void frameValley() {
    _touched();
    var far = 20.0;
    for (final e in _entries) {
      final d = math.sqrt(
        e.layout.cx * e.layout.cx + e.layout.cz * e.layout.cz,
      );
      if (d + e.layout.radius > far) far = d + e.layout.radius;
    }
    _cam.travelTarget = 0;
    _cam.focusZTarget = 0;
    _cam.focusYTarget = 2.0;
    _cam.wallLength = far * 2;
    _tellCameraTheWorld();
    // Low enough to keep the sky and the hills in it. Straight down is a map;
    // the point of the valley is that it is a place.
    _cam.pitchTarget = 0.40;

    // Salís por encima del pueblo del que venís.
    //
    // Antes no: el foco va al centro del anillo —tiene que ir, es el único
    // sitio desde el que caben los seis— y el giro se quedaba donde estuviera,
    // así que uno acababa mirando desde donde mirara siempre. Y como el pueblo
    // uno está justo en ese centro, lo que se veía era siempre él.
    //
    // Lo que se mueve es el giro, no el foco: el ojo se pone en la dirección
    // en la que está tu pueblo, así que subís desde el tuyo y mirás al valle
    // por encima de él. El del medio no tiene dirección, y desde ése el giro
    // se queda como esté.
    final propio = math.sqrt(_town.cx * _town.cx + _town.cz * _town.cz);
    if (propio > 1) {
      _cam.yawTarget += angleDelta(
        _cam.yawTarget,
        math.atan2(_town.cx, _town.cz),
      );
    }

    // Y a la distancia que haga falta para que quepan todos, medida sobre la
    // proyección de verdad. El radio por dos coma cuatro era de cuando el
    // valle eran dos pueblos: con seis y el giro puesto, se queda corto o se
    // pasa según de dónde salgas.
    _cam.distanceTarget = clampD(
      _valleyDistance(far),
      20,
      OrbitCamera.maxDistance,
    );
    _cam.follow = false;
    _setAloft(true);
    _asked = true;
    _valleyAt = _cam.distanceTarget;
    _valleyFar = far;
    Sensory.instance.tick();
  }

  /// A qué distancia quedó la vista del valle. Ver [_diveIn].
  double _valleyAt = 0;

  /// Estar o no en el valle, y avisarlo. Si cambia en mitad de un
  /// dibujado —volver al pueblo puede pasar mientras se reconstruye la
  /// vista—, el aviso espera al final del fotograma: encender un botón ahí
  /// mismo sería reconstruir otra cosa a medio construir esta.
  void _setAloft(bool v) {
    _aloft = v;
    final n = widget.controller.aloftNow;
    if (n.value == v) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) n.value = _aloft;
      });
    } else {
      n.value = v;
    }
  }

  /// Acercar o alejar con los dedos o la rueda.
  ///
  /// En el valle, alejarse tiene tope: un poco más allá de donde se ven todos
  /// los pueblos. Más lejos no hay nada que mirar —los pueblos son puntos y
  /// las matas de la nieve, polvo— y era fácil perderse en el blanco.
  void _zoomBy(double factor) {
    _cam.zoomBy(factor);
    if (_aloft && _valleyAt > 0) {
      final tope = _valleyAt * _valleyRoom;
      if (_cam.distanceTarget > tope) _cam.distanceTarget = tope;
    }
  }

  /// Hasta dónde llegan los pueblos desde el centro del valle. Ver
  /// [_panByDrag].
  double _valleyFar = 0;

  /// Cuánto más que el encuadre del valle se deja alejar.
  static const double _valleyRoom = 1.3;

  /// Qué parte de esa distancia hay que acercarse para entrar a un pueblo.
  static const double _diveAt = 0.25;

  /// Acercarse mucho desde el valle es querer entrar a un pueblo: se entra.
  ///
  /// Al que está debajo de los dedos —o del puntero, con la rueda—, que es al
  /// que uno se estaba acercando, y con el mismo vuelo que tocar su cartel.
  /// Recién a un cuarto de la distancia del valle: acercarse para mirar
  /// mejor el valle sigue siendo mirar el valle. Con la mitad bastaban seis
  /// vueltas de rueda y uno entraba sin haberlo querido.
  void _diveIn(Offset focal) {
    if (!_aloft || _valleyAt <= 0) return;
    if (_cam.distanceTarget > _valleyAt * _diveAt) return;
    final size = context.size;
    if (size == null || size.isEmpty || _entries.isEmpty) return;
    final p = _cam.projector(size.width, size.height, _time);
    var mejor = -1;
    var cerca = double.infinity;
    for (var i = 0; i < _entries.length; i++) {
      final l = _entries[i].layout;
      final at = p.project(V3(l.cx, 0, l.cz));
      if (at == null) continue;
      final dx = at.x - focal.dx, dy = at.y - focal.dy;
      final d = dx * dx + dy * dy;
      if (d < cerca) {
        cerca = d;
        mejor = i;
      }
    }
    if (mejor < 0) return;
    Sensory.instance.tick();
    if (mejor == widget.store.active) {
      _frameTown();
    } else {
      // Bajar ya, sin esperar a que el pueblo nuevo encuadre: si no, el
      // siguiente fotograma del pellizco vuelve a pedir lo mismo.
      _landed();
      widget.onTownTapped(mejor);
    }
  }

  /// Desde dónde se ven los seis pueblos enteros. Se prueba sobre una cámara
  /// de mentira con los ángulos a los que va a llegar la de verdad, porque la
  /// de verdad todavía está donde estaba.
  double _valleyDistance(double far) {
    final size = context.size;
    if (size == null || size.isEmpty) return far * 2.4;
    final puntos = <V3>[];
    for (final e in _entries) {
      final r = e.layout.radius;
      for (final (dx, dz) in [
        (0.0, 0.0),
        (-r, 0.0),
        (r, 0.0),
        (0.0, -r),
        (0.0, r),
      ]) {
        puntos.add(V3(e.layout.cx + dx, 0, e.layout.cz + dz));
      }
    }
    final prueba = OrbitCamera()
      ..focusY = 2.0
      ..yaw = _cam.yawTarget
      ..pitch = 0.40;
    return prueba.distanceToFit(puntos, size.width, size.height);
  }

  /// The whole of this town, from its own plaza.
  void frameAll() {
    _touched();
    _cam.travelTarget = _town.cx;
    _cam.focusZTarget = _town.cz;
    _cam.focusYTarget = 1.8;
    _cam.pitchTarget = 0.52;
    // El radio por dos coma cuatro encuadraba el suelo que ocupa el pueblo y
    // nada más, así que valía mientras lo más alto midiera dos o tres. Con
    // cualquier cosa alta dentro —una catedral, un faro, un observatorio— «ver
    // todo el pueblo» dejaba la punta cortada, que es exactamente lo que el
    // botón promete que no pasa. Se mide sobre la proyección de verdad, con
    // las cumbres dentro.
    _cam.distanceTarget = clampD(_townDistance(), 9, 90);
    _cam.follow = false;
    _landed();
    Sensory.instance.tick();
  }

  /// Si se apartó tanto que lo que mira ya es el valle, decirlo — una vez.
  ///
  /// Se mira el objetivo y no dónde está la cámara: lo que cuenta es lo que se
  /// pidió, no lo que ya llegó, y así el vuelo arranca con el gesto y no medio
  /// segundo después. Y se rearma sólo al volver bien adentro, para que
  /// quedarse justo en el filo no dispare un vuelo por fotograma.
  void _watchTheHorizon() {
    if (_entries.length < 2 || _showcase != null) return;
    final far = _cam.distanceTarget;
    if (!_asked && !_aloft && far > _leaveAt) {
      _asked = true;
      widget.onFlewOut();
    } else if (_asked && !_aloft && far < _leaveAt * 0.8) {
      _asked = false;
    }
  }

  /// Desde dónde se ve este pueblo entero, cumbres incluidas.
  double _townDistance() {
    final size = context.size;
    if (size == null || size.isEmpty) return clampD(_town.radius * 2.4, 9, 90);
    final r = _town.radius;
    final puntos = <V3>[
      for (final (dx, dz) in [
        (0.0, 0.0),
        (-r, 0.0),
        (r, 0.0),
        (0.0, -r),
        (0.0, r),
      ])
        V3(_town.cx + dx, 0, _town.cz + dz),
      // Y lo que sobresale: la punta de cada edificio sobre su propio sitio.
      for (final b in _town.buildings)
        if (b.peakY > 0) V3(b.cx, b.peakY, b.cz),
    ];
    final prueba = OrbitCamera()
      ..travel = _town.cx
      ..focusZ = _town.cz
      ..focusY = 1.8
      ..yaw = _cam.yawTarget
      ..pitch = 0.52;
    return prueba.distanceToFit(puntos, size.width, size.height);
  }

  /// El hueco donde va a caer la siguiente, que es el que interesa mirar.
  ///
  /// El pueblo tiene siempre una pieza más que las puestas —la del fantasma—,
  /// así que el hueco que viene es el de índice [TownLayout.placed]. Antes
  /// este botón llevaba a la última puesta, y las dos cosas coinciden casi
  /// siempre menos cuando importa: al terminar un edificio, la siguiente
  /// empieza otro en la otra punta del pueblo, y lo que uno quiere ver es
  /// dónde va a caer y no dónde cayó.
  void lookAtNext() {
    final p = _town.pieceFor(_town.placed) ?? _town.pieceFor(_town.placed - 1);
    if (p != null) goTo(p.cx, p.cz);
  }

  void goTo(double x, double z) {
    _touched();
    _landed();
    _cam.travelTo(x);
    _cam.focusZTarget = z;
    _cam.follow = false;
  }

  /// Volver a estar en un pueblo: se arma otra vez el aviso de apartarse.
  ///
  /// Lo llama todo lo que baja la cámara a tierra. Sin esto, después de un
  /// vuelo el aviso se quedaba desarmado para siempre y apartarse en el pueblo
  /// siguiente no hacía nada.
  void _landed() {
    _setAloft(false);
    _asked = false;
  }

  // -------------------------------------------------------------- gestures

  double _lastScale = 1;

  double _lastRotation = 0;

  void _onScaleStart(ScaleStartDetails d) {
    _lastScale = 1;
    _lastRotation = 0;
    _touched();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    _touched();
    // Mover la cámara es decir «ya sé dónde estoy»: lo que hubiera puesto
    // encima —el cartel del pueblo al que se acaba de llegar— sobra desde ese
    // momento y no cuando se le acabe el tiempo.
    if (d.focalPointDelta.distanceSquared > 1 || d.scale != 1) {
      widget.onCameraMoved();
    }
    if (_aloft) {
      _freeCamera(d);
      return;
    }
    if (d.pointerCount >= 2) {
      final f = d.scale / (_lastScale == 0 ? 1 : _lastScale);
      _lastScale = d.scale;
      if (f.isFinite && f > 0) _zoomBy(1 / f);
      _travelByDrag(d.focalPointDelta);
      if (f > 1) _diveIn(d.localFocalPoint);
    } else {
      final dx = d.focalPointDelta.dx;
      final dy = d.focalPointDelta.dy;
      _cam.orbitBy(-dx * 0.0062, dy * 0.0048);
      _cam.follow = false;
    }
  }

  /// En el valle la cámara es libre: se la lleva a cualquier parte.
  ///
  /// Antes era la misma que en el pueblo —un dedo giraba alrededor del
  /// centro, que es donde está el primer pueblo, y dos la corrían en una sola
  /// dirección—, así que el valle se miraba siempre desde su medio. Ahora es
  /// como un mapa:
  ///
  ///  * **Un dedo, o arrastrar con el ratón**, lleva el suelo con el dedo: lo
  ///    que estaba debajo sigue debajo. Hacia cualquier lado.
  ///  * **Dos dedos**: pellizcar acerca y aleja, girarlos gira la vista, y
  ///    subirlos o bajarlos juntos inclina.
  ///  * **Con el ratón**, el botón derecho —o arrastrar con Mayúsculas o
  ///    Control apretados— gira e inclina, que es lo que hacía un dedo antes.
  void _freeCamera(ScaleUpdateDetails d) {
    // El botón derecho ya lo gira [_mouseOrbit]; si además corriera la vista,
    // el valle se iría de lado mientras gira.
    if (_rightDrag) return;
    final teclado = HardwareKeyboard.instance;
    if (d.pointerCount >= 2) {
      final f = d.scale / (_lastScale == 0 ? 1 : _lastScale);
      _lastScale = d.scale;
      if (f.isFinite && f > 0) _zoomBy(1 / f);
      final giro = d.rotation - _lastRotation;
      _lastRotation = d.rotation;
      _cam.orbitBy(-giro, d.focalPointDelta.dy * 0.0048);
      _cam.follow = false;
      if (f > 1) _diveIn(d.localFocalPoint);
    } else if (teclado.isShiftPressed || teclado.isControlPressed) {
      _cam.orbitBy(
        -d.focalPointDelta.dx * 0.0062,
        d.focalPointDelta.dy * 0.0048,
      );
      _cam.follow = false;
    } else {
      _panByDrag(d.focalPointDelta);
    }
  }

  /// Arrastrar el suelo del valle: el foco se corre al revés que el dedo,
  /// sobre el suelo y no sobre la pantalla, así que lo que estaba debajo del
  /// dedo sigue debajo. Sin salirse del valle: más allá de los pueblos no hay
  /// nada que buscar, y perderse en la nieve es fácil.
  void _panByDrag(Offset delta) {
    final size = context.size;
    if (size == null) return;
    final p = _cam.projector(size.width, size.height, _time);
    // Derecha de la pantalla y hacia el fondo, sobre el suelo.
    var rx = p.right.x, rz = p.right.z;
    var fx = p.forward.x, fz = p.forward.z;
    final rl = math.sqrt(rx * rx + rz * rz), fl = math.sqrt(fx * fx + fz * fz);
    if (rl < 0.01 || fl < 0.01) return;
    rx /= rl;
    rz /= rl;
    fx /= fl;
    fz /= fl;
    // Cuánto suelo hay en un píxel, en el foco. Hacia el fondo se estira
    // con la inclinación: mirado de canto, un píxel es más suelo.
    final metro = _cam.distance / p.focal;
    final hondo = metro / math.max(0.25, math.sin(_cam.pitch));
    var x = _cam.travelTarget - delta.dx * metro * rx + delta.dy * hondo * fx;
    var z = _cam.focusZTarget - delta.dx * metro * rz + delta.dy * hondo * fz;
    final lejos = math.sqrt(x * x + z * z), tope = _valleyFar + 20;
    if (lejos > tope) {
      x *= tope / lejos;
      z *= tope / lejos;
    }
    _cam.travelTarget = x;
    _cam.focusZTarget = z;
    _cam.follow = false;
  }

  /// El botón derecho del ratón, arrastrando: girar e inclinar el valle. Va
  /// por aquí y no por el gesto porque el gesto sólo escucha el izquierdo.
  bool _rightDrag = false;

  void _mouseOrbit(PointerMoveEvent e) {
    if (!_aloft || e.kind != PointerDeviceKind.mouse) return;
    if (e.buttons & kSecondaryMouseButton == 0) return;
    _touched();
    _cam.orbitBy(-e.delta.dx * 0.0062, e.delta.dy * 0.0048);
    _cam.follow = false;
  }

  /// Two-finger drag walks the camera along the wall, in whatever screen
  /// direction the wall happens to run right now.
  void _travelByDrag(Offset delta) {
    final size = context.size;
    if (size == null) return;
    final p = _cam.projector(size.width, size.height, _time);
    final ax = p.right.x;
    final ay = -p.up.x;
    final len = math.sqrt(ax * ax + ay * ay);
    if (len < 0.02) return;
    final along = (delta.dx * ax + delta.dy * ay) / len;
    final worldPerPixel = _cam.distance / (p.focal * len);
    _cam.travelBy(-along * worldPerPixel);
  }

  /// Cuándo se tocó la constelación, en el reloj de la escena.
  double? _skyTappedAt;

  /// El nombre de la constelación: tres segundos a la vista y casi uno
  /// deshaciéndose.
  double _skyLabel() {
    final at = _skyTappedAt;
    if (at == null) return 0;
    final t = _time - at;
    if (t < 0 || t > 3.8) return 0;
    if (t < 0.25) return t / 0.25;
    if (t < 3.0) return 1;
    return 1 - (t - 3.0) / 0.8;
  }

  void _onTapUp(TapUpDetails d) {
    final pos = d.localPosition;

    // El cielo primero. Es lo que menos veces está ahí y lo que más
    // deliberadamente se toca: nadie apunta a una constelación por accidente,
    // y si hay una figura encima de un tejado, se quiso la figura.
    for (final k in _hits.skies) {
      if (!k.rect.contains(pos)) continue;
      _skyTappedAt = _time;
      widget.onSkyTapped(k.id);
      return;
    }

    // Lo que se ve bajo el dedo: la última cara pintada en ese punto.
    final arriba = _hits.ownerAt(pos.dx, pos.dy);
    final casa = arriba != null && (arriba >= 0 || arriba == TouchMap.building);

    // El tablón, antes que las casas: es una cosa chica en medio de un pueblo
    // lleno de tejados, y quien le apunta le apuntó. Si dos tablones caen bajo
    // el dedo, el más cercano a donde aterrizó.
    //
    // Pero sólo si lo que se ve ahí no es una casa. El blanco del tablón es su
    // rectángulo, y el rectángulo sigue estando aunque una casa se le ponga
    // delante: tocar esa casa abría el tablón que tapa.
    ({int town, double away})? tablon;
    for (final b in casa ? const <BoardHit>[] : _hits.boards) {
      if (!b.rect.contains(pos)) continue;
      final dx = b.rect.center.dx - pos.dx, dy = b.rect.center.dy - pos.dy;
      final away = dx * dx + dy * dy;
      if (tablon == null || away < tablon.away) {
        tablon = (town: b.town, away: away);
      }
    }
    if (tablon != null) {
      Sensory.instance.tick();
      widget.onBoardTapped(tablon.town);
      return;
    }

    // Then the signs. From across the valley a sign is the only thing you can
    // read about a town, and reading it and tapping it should be the same
    // gesture as going there.
    for (final s in _hits.signs) {
      if (!s.rect.contains(pos)) continue;
      if (s.town == widget.store.active) {
        // Already yours: frame it properly instead of doing nothing.
        _frameTown();
        Sensory.instance.tick();
        return;
      }
      Sensory.instance.tick();
      widget.onTownTapped(s.town);
      return;
    }

    // La de adelante, no la más cercana al dedo.
    //
    // Antes se buscaba el centro más próximo al toque, y eso hacía las dos
    // cosas mal: el blanco era un círculo dentro de la pieza —más chico que
    // ella— y, mirando desde arriba, el centro de la de abajo podía caer más
    // cerca del dedo que el de la de encima. Ahora se mira quién ocupa ese
    // punto de la pantalla y, de ésos, cuál está más cerca del ojo. Una pieza
    // no se toca a través de otra.
    PickTarget? best;
    // Si lo que se ve es una pieza de este pueblo, es ésa y no hay que
    // adivinar con rectángulos.
    if (arriba != null && arriba >= 0) {
      for (final t in _hits.pieces) {
        if (t.brickIndex == arriba) best = t;
      }
    }
    if (best == null) {
      for (final t in _hits.pieces) {
        // Un pelo de holgura.
        if (!t.holds(pos.dx, pos.dy, 2)) continue;
        if (best == null || t.near < best.near) best = t;
      }
    }
    if (best == null) {
      if (_selectedPiece != null) setState(() => _selectedPiece = null);
      widget.onNothingTapped();
      return;
    }

    final brick = widget.store.pieceAt(best.brickIndex);
    if (brick == null) return;
    setState(() => _selectedPiece = brick.index);
    Sensory.instance.tick();
    widget.onStoneTapped(brick);
  }

  void setCharge(double v) {
    if ((_charge - v).abs() < 0.004) return;
    _charge = v;
    // Glide over to where the stone is going while the button is held, so the
    // landing is always in frame.
    if (v > 0.05) _followPlacement(widget.store.shownTotal);
  }

  void clearSelection() {
    if (_selectedPiece != null && mounted) {
      setState(() => _selectedPiece = null);
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    // Alguna noche hay una figura ahí arriba y otras no; la decide la propia
    // noche. Ya no hace falta tener un observatorio en pie para verla: el cielo
    // no se desbloquea, se mira.
    final night = nightOf(DateTime.now());
    final tonightIs = _palette.starAlpha > 0.35 ? tonight(night) : null;

    final scene = TownScene(
      placed: store.shownTotal,
      palette: _palette,
      camera: _cam,
      time: _time,
      hourOfDay: _hour,
      effects: _fx,
      fx: _placement,
      budget: _budget,
      towns: _entries,
      active: widget.store.active.clamp(0, _entries.length - 1),
      finished: _finished,
      finishedAge: _finishedAge,
      newborn: _newborn,
      newbornAge: _newbornAge,
      selectedBrick: _selectedPiece,
      charge: _charge,
      skyNight: night,
      tonight: tonightIs,
      skyLabel: _skyLabel(),
      founding: _founding,
      day: dayKey(DateTime.now()),
      cinematic: Appearance.instance.cinematic,
    );

    return Listener(
      onPointerDown: (e) => _rightDrag =
          e.kind == PointerDeviceKind.mouse &&
          e.buttons & kSecondaryMouseButton != 0,
      onPointerMove: _mouseOrbit,
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) {
          _zoomBy(1 + e.scrollDelta.dy * 0.0012);
          if (e.scrollDelta.dy < 0) _diveIn(e.localPosition);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onTapUp: _onTapUp,
        onDoubleTap: () {
          _cam.pitchTarget = _cam.pitchTarget > 0.9 ? 0.28 : 1.42;
          Sensory.instance.tick();
        },
        child: CustomPaint(
          painter: TownPainter(scene, _hits),
          size: Size.infinite,
          isComplex: true,
          willChange: true,
        ),
      ),
    );
  }
}
