import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/constellations.dart';
import '../data/landmarks.dart';
import '../data/pacing.dart';
import '../engine/camera.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../engine/scene.dart';
import '../engine/shooting_star.dart';
import '../engine/solids.dart';
import '../engine/town.dart';
import '../fx/effects.dart';
import '../fx/sensory.dart';
import '../model/appearance.dart';
import '../model/board.dart';
import '../model/board_slots.dart';
import '../model/habit.dart';
import '../model/piece.dart';
import '../model/store.dart';

/// Handle the surrounding UI uses to drive the wall.
class TownViewController {
  _TownViewState? _state;

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

  /// Lleva la cámara hasta una pieza concreta, para abrirla desde la bitácora.
  void lookAtPiece(int index) => _state?.lookAtPiece(index);

  /// Lleva la cámara al hueco donde va a caer la que viene.
  void lookAtNext() => _state?.lookAtNext();
  double get travel => _state?._cam.travelTarget ?? 0;

  /// How wide the town in front of you reaches, for framing.
  double get townRadius => _state?._town.radius ?? 8;
  Palette? get palette => _state?._palette;
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
    required this.onLecternTapped,
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

  /// Un toque en el aire. Cerrar la leyenda que estuviera abierta es lo mismo
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

  /// Y el atril de la plaza, que es donde se leen las leyendas de ese pueblo.
  final void Function(int index) onLecternTapped;

  final void Function(String message) onWhisper;
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

  /// A landmark being shown off: the camera turns slowly around it.
  int? _showcase;
  double _showcaseAge = 0;

  double _displayIntegrity = 1;

  /// Segundos que le quedan a las luces para volver despacio. Ver
  /// [_welcomeBack].
  double _relightSlow = 0;
  int? _selectedPiece;
  double _charge = 0;

  static const int _budgetOverride = int.fromEnvironment(
    'BUDGET',
    defaultValue: -1,
  );

  /// How many pieces are worth drawing. Given away when the frame gets long
  /// and won back when it does not, so an old phone shows a smaller town
  /// rather than a stuttering one.
  int _budget = _budgetOverride > 0 ? _budgetOverride : 15000;
  double _frameAvg = 16;

  late Palette _palette;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _palette = _buildPalette();
    _rebuildLayout();
    _displayIntegrity = widget.store.integrity;
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
    _ticker = createTicker(_tick)..start();
    widget.store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPaletteChanged(_palette);
    });
  }

  /// One town's layout, kept between frames unless its own count moved.
  TownLayout _layoutOf(Habit h, int? override) {
    final n = override ?? h.total;
    final key = '${h.id}:$n';
    final had = _valley[key];
    if (had != null) return had;
    // Only ever one layout per habit in flight: the old one is dropped the
    // moment its count changes.
    _valley.removeWhere((k, _) => k.startsWith('${h.id}:'));
    final (cx, cz) = Habit.centreOf(h.slot);
    final said = boardNotices(h, valley: widget.store.habits);
    final made = TownLayout(
      n,
      h.place,
      cx: cx,
      cz: cz,
      chronicle: h.chronicle,
      // La misma lista que guarda el hábito, no una copia: lo que se apunte
      // justo debajo lo tiene que ver el plano sin volver a construirlo.
      folk: h.folk,
      // En qué huecos de su tablón hay papel. Sale de las mismas dos cuentas
      // que lo clavan al acercarse —qué hay que decir, y dónde quedó clavado
      // cada papel—, así que la silueta que se ve desde el valle es la de lo
      // que hay de verdad y en su sitio. Se calcula una vez por pueblo y sólo
      // se rehace cuando le cambia la cuenta de piezas, que es cuando puede
      // cambiar lo que el pueblo sabe.
      notices: BoardSlots.instance.assign(
        h.id,
        said,
        slots: NoticeBoard.capacity,
      ),
      seed: h.townSeed,
    );
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
    _cam.distanceTarget = clampD(_town.radius * 1.9, 9.0, 60.0);
    _cam.yawTarget = 0.62;
    _cam.pitchTarget = 0.46;
    _cam.wallLength = _townReach;
    _tellCameraTheWorld();
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    widget.controller._state = null;
    _ticker.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    final store = widget.store;
    if (store.shownTotal != _layoutFor || store.habit.slot != _slotFor) {
      _rebuildLayout();
    }
  }

  void _rebuildLayout() {
    final store = widget.store;
    final wasSlot = _slotFor;
    // Whoever has laid the most wears the crown, and everybody else can see it
    // from their own plaza.
    final crown = store.leader;

    _entries = [
      for (var i = 0; i < store.habits.length; i++)
        _entryFor(store, store.habits[i], i == crown),
    ];
    _town = _entries[store.active.clamp(0, _entries.length - 1)].layout;
    _layoutFor = store.shownTotal;
    _slotFor = store.habit.slot;
    _cam.wallLength = _townReach;
    _tellCameraTheWorld();

    // Moving to another habit is moving to another town: take the camera
    // there rather than leaving it hanging over an empty valley.
    if (wasSlot != _slotFor) {
      _frameTown();
      _fx.clear();
      _placement = null;
      _finished = null;
      _showcase = null;
    }
  }

  TownEntry _entryFor(Store store, Habit h, bool crowned) {
    final mine = h.id == store.habit.id;
    return TownEntry(
      layout: _layoutOf(h, mine ? store.shownTotal : null),
      name: h.name,
      symbol: h.symbol,
      integrity: Store.integrityOf(h),
      placed: mine ? store.shownTotal : h.total,
      crowned: crowned,
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
    if (Appearance.instance.fakeHour) return Appearance.instance.fakeHourAt;
    final now = DateTime.now();
    return now.hour + now.minute / 60.0;
  }

  Palette _buildPalette() => Palette.forMoment(
    _hour,
    _displayIntegrity,
    season: Appearance.instance.season,
  );

  // ------------------------------------------------------------------ tick

  void _tick(Duration elapsed) {
    final dtRaw = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final dt = dtRaw.clamp(0.0005, 0.05);
    _time += dt;
    if (widget.store.justFounded && _founding >= 1.0) {
      _founding = 0.0;
      widget.store.justFounded = false;
      // La cámara mira el claro desde cerca: lo que va a pasar pasa ahí, y de
      // lejos una plaza subiendo del suelo son tres píxeles moviéndose.
      _frameTown();
      _cam.distanceTarget = 11.0;
      _cam.pitchTarget = 0.30;
    }
    if (_founding < 1.0) {
      _founding = math.min(1.0, _founding + dt / 1.7);
      if (_founding >= 1.0) _frameTown();
    }

    if (_budgetOverride <= 0) {
      _frameAvg = _frameAvg * 0.92 + dtRaw * 1000 * 0.08;
      if (_frameAvg > 21 && _budget > 4000) {
        _budget -= 260;
      } else if (_frameAvg < 13 && _budget < 22000) {
        _budget += 150;
      }
    }

    _cam.step(dt);
    _watchTheHorizon();
    _fx.update(dt);
    if (_finished != null) {
      _finishedAge += dt;
      if (_finishedAge > 2.6) _finished = null;
    }
    _turnAround(dt);

    final p = _placement;
    if (p != null) {
      final wasLanded = p.landed;
      p.update(dt);
      if (!wasLanded && p.landed) _onImpact(p);
      if (p.done) _placement = null;
    }

    final target = widget.store.integrity;
    // Normalmente esto alcanza al objetivo en menos de un segundo, que es lo
    // que hace falta para que apagarse y encenderse no se vean como un salto.
    // Volver de un pueblo a oscuras es la excepción: ahí se frena a propósito,
    // para que las luces tarden en volver lo que tarda en mirarse.
    final ritmo = _relightSlow > 0 ? 0.55 : 1.4;
    _displayIntegrity +=
        (target - _displayIntegrity) * (1 - math.exp(-dt * ritmo));
    if (_relightSlow > 0) {
      _relightSlow -= dt;
      if (_relightSlow <= 0) _relightSlow = 0;
    }

    _spawnAmbient(dt);

    Sensory.instance.music(_hour, dt, _displayIntegrity);
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
    if (pal.skyTop != antes.skyTop ||
        pal.skyHorizon != antes.skyHorizon ||
        pal.accent != antes.accent) {
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
  void _touched() => _idleFor = 0;

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
      // Todas las chimeneas de un pueblo sano echan humo, y se van apagando
      // según pasan los días sin que nadie ponga una pieza. Un pueblo sin humo
      // encima es la manera más legible de decir que aquí no ha venido nadie.
      //
      // Antes se apagaba además un tercio largo de ellas a suertes —«no todos
      // los hogares están encendidos», que en un pueblo grande es verdad y se
      // ve bien—, pero un pueblo empieza con dos casas: una chimenea humeando
      // al lado de otra que no no se lee como que ahí no han encendido, se lee
      // como que ésa está rota.
      final lit = _displayIntegrity * _displayIntegrity;
      if (hash01(piece.seed, 91) > lit) continue;
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
    final wasDecaying = store.integrity < 0.995;
    final before = store.integrity;
    store.setPreview(null);
    final result = store.placePiece();
    _selectedPiece = null;
    _followPlacement(result.piece.index);
    if (wasDecaying) _displayIntegrity = before;
    _pendingResult = result;
    // In the town a piece is set down, not dropped from a crane: from high up
    // it reads as a bug, and the anticipation is in the shadow closing under
    // it rather than in the height it falls from.
    _placement = PlacementFx(result.piece.index, dropHeight: 2.3);
    widget.onPlaced(result.piece);
    setState(() {});
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
        widget.onWhisper('${building.name} en pie');
      }
    }
    if (result != null && result.relit) _welcomeBack(result, town, done);
    // Y si ésta fue la pieza que abrió el valle, se dice. Pasa una sola vez en
    // la vida de un valle, y si no se dijera nadie se enteraría: el anillo del
    // más se cierra y ya está, que es muy poco para lo que acaba de pasar.
    if (result != null && result.unlocked) {
      _fx.celebrate(V3(town.cx, 0, town.cz), 2.0, count: 46);
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) Sensory.instance.milestone();
      });
      widget.onWhisper(
        'El valle abre un segundo solar. Ya podés fundar otro pueblo.',
      );
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
  /// Así que la celebración crece con lo apagado que estaba: volver desde el
  /// doce por ciento tiene que sentirse como rematar un hito, porque
  /// psicológicamente es más que eso. Alguien que vuelve después de veinte
  /// días está demostrando que el abandono no era definitivo, y eso vale más
  /// que cualquier racha que pudiera haber conservado.
  void _welcomeBack(PlaceResult result, TownLayout town, bool finished) {
    // Cero cuando apenas se había apagado, uno cuando estaba en el suelo.
    final hondo = clampD(
      (1.0 - result.relitFrom) / (1.0 - Pacing.minIntegrity),
      0.0,
      1.0,
    );
    // Las luces vuelven despacio y no de un fundido. La integridad ya sube
    // sola hacia su objetivo; lo que se hace acá es frenar esa subida para que
    // dé tiempo a verla, y sólo cuando había algo que ver — estirar un dos por
    // ciento durante dos segundos se lee como un tirón, no como una vuelta.
    _relightSlow = hondo > 0.25 ? 2.6 : 0.0;

    // Una vuelta de verdad se oye. Es el sonido de reparar, que ya existía
    // para esto exactamente y no se usaba en el único sitio donde significa
    // algo.
    if (hondo > 0.25) {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) Sensory.instance.repair();
      });
    }

    // Y se ve. Chispas desde la plaza, tantas como oscuro estaba, y la cámara
    // se aparta para que se vea encenderse el pueblo entero en vez de la
    // piedra que acabás de poner.
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
          ? 'El pueblo despierta antes de tiempo.'
          : hondo > 0.6
          ? 'Volviste. El pueblo entero vuelve a encenderse.'
          : 'El pueblo vuelve a encenderse',
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
    _aloft = true;
    _asked = true;
    Sensory.instance.tick();
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

  /// Looks at a spot on the valley floor, for the map and the landmark list.
  void lookAtPiece(int index) {
    final p = _town.pieceFor(index);
    if (p != null) goTo(p.cx, p.cz);
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
    _aloft = false;
    _asked = false;
  }

  // -------------------------------------------------------------- gestures

  double _lastScale = 1;

  void _onScaleStart(ScaleStartDetails d) {
    _lastScale = 1;
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
    if (d.pointerCount >= 2) {
      final f = d.scale / (_lastScale == 0 ? 1 : _lastScale);
      _lastScale = d.scale;
      if (f.isFinite && f > 0) _cam.zoomBy(1 / f);
      _travelByDrag(d.focalPointDelta);
    } else {
      final dx = d.focalPointDelta.dx;
      final dy = d.focalPointDelta.dy;
      _cam.orbitBy(-dx * 0.0062, dy * 0.0048);
      _cam.follow = false;
    }
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

  void _onTapUp(TapUpDetails d) {
    final pos = d.localPosition;

    // El cielo primero. Es lo que menos veces está ahí y lo que más
    // deliberadamente se toca: nadie apunta a una constelación por accidente,
    // y si hay una figura encima de un tejado, se quiso la figura.
    for (final k in _hits.skies) {
      if (!k.rect.contains(pos)) continue;
      widget.onSkyTapped(k.id);
      return;
    }

    // The board comes first: it is a small thing standing in the middle of a
    // town full of houses, and anybody aiming at it meant it.
    for (final b in _hits.boards) {
      if (!b.rect.contains(pos)) continue;
      Sensory.instance.tick();
      widget.onBoardTapped(b.town);
      return;
    }

    // Y el atril, que está al lado y es igual de pequeño.
    for (final a in _hits.lecterns) {
      if (!a.rect.contains(pos)) continue;
      Sensory.instance.tick();
      widget.onLecternTapped(a.town);
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
    for (final t in _hits.pieces) {
      // Un pelo de holgura, y algo más si lleva leyenda: lo que ya tiene algo
      // escrito es lo que alguien vuelve a buscar.
      if (!t.holds(pos.dx, pos.dy, t.labelled ? 6 : 2)) continue;
      if (best == null || t.near < best.near) best = t;
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
      integrity: _displayIntegrity,
      time: _time,
      hourOfDay: _hour,
      effects: _fx,
      labelledBricks: {
        for (final p in store.pieces)
          if (p.hasLabel) p.index,
      },
      fx: _placement,
      budget: _budget,
      towns: _entries,
      active: widget.store.active.clamp(0, _entries.length - 1),
      finished: _finished,
      finishedAge: _finishedAge,
      selectedBrick: _selectedPiece,
      charge: _charge,
      skyNight: night,
      tonight: tonightIs,
      founding: _founding,
    );

    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) {
          _cam.zoomBy(1 + e.scrollDelta.dy * 0.0012);
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
