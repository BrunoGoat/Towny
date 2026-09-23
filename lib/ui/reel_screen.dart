import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/math3.dart';
import '../data/constellations.dart';
import '../engine/camera.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../engine/scene.dart';
import '../engine/season.dart';
import '../engine/town.dart';
import '../engine/world.dart';
import '../fx/effects.dart';
import '../fx/sensory.dart';
import '../model/appearance.dart';
import '../model/habit.dart';
import '../model/reel.dart';
import '../model/store.dart';
import 'cloud_flight.dart';
import 'style.dart';

/// Cómo se hizo: el valle entero desde el prado vacío hasta hoy, de una
/// sentada y con la cámara dando la vuelta.
///
/// **Por qué existe.** La app promete que lo que hacés deja un sitio
/// construido, y hasta ahora esa promesa sólo se podía *leer* — en el libro del
/// atril, una línea por pieza. Leerla no es lo mismo que verla. Aquí el prado
/// está vacío, cae la primera, y sesenta segundos después está el pueblo que
/// tenés, con las estaciones pasando por encima.
///
/// **Y por qué es un botón y no un carril.** Un deslizador es una herramienta:
/// se usa para inspeccionar, se va y se vuelve, y el que lo mueve controla el
/// ritmo — que es exactamente lo que no puede controlar, porque el ritmo es la
/// mitad de lo que hay que contar. Esto se pulsa una vez y no se toca más.
///
/// Todo lo que se ve sale de lo que ya estaba: el mismo plano, el mismo
/// cortador de caras, el mismo cielo. Lo único que cambia es quién decide la
/// cuenta de piezas y la fecha, que aquí las decide [Reel] en vez del reloj.
/// Qué se está mirando, que decide cómo se mira.
enum ReelMode {
  /// El valle entero. La cámara va detrás de la pieza que cae y salta de un
  /// pueblo a otro, porque en un valle de varios pueblos están pasando cosas
  /// en tres sitios y girar alrededor de uno deja fuera del cuadro los otros
  /// dos.
  valley,

  /// Un pueblo solo. La cámara gira alrededor de su plaza mientras crece, que
  /// es lo que se puede hacer cuando no hay nada a lo que saltar.
  town,

  /// Lo que llegó del widget: como [valley], pero corta y sobre pueblos ya
  /// hechos.
  arrivals,
}

class ReelScreen extends StatefulWidget {
  /// El valle entero, que es lo que se ofrece por defecto.
  const ReelScreen({super.key, required this.store})
    : arrivals = null,
      mode = ReelMode.valley,
      only = -1;

  /// Un pueblo solo, el del hueco [habit].
  const ReelScreen.town({super.key, required this.store, required int habit})
    : arrivals = null,
      mode = ReelMode.town,
      only = habit;

  /// La corta: lo que se puso desde la pantalla de inicio y todavía no viste
  /// caer.
  ///
  /// Es esta misma pantalla mirando otra cosa. La crónica arranca del prado
  /// vacío y tarda un minuto en llegar a hoy; ésta arranca del pueblo tal como
  /// lo dejaste, le caen encima las que tocaste en el widget, y se acaba. Todo
  /// lo demás —la cámara, el cielo, el polvo, el golpe— es exactamente lo
  /// mismo, que es de lo que se trataba: lo que te perdiste por poner una
  /// pieza sin abrir la app es justo esto, y no hay dos versiones de esto.
  const ReelScreen.arrivals({
    super.key,
    required this.store,
    required List<ReelStep> pieces,
  }) : arrivals = pieces,
       mode = ReelMode.arrivals,
       only = -1;

  final Store store;

  final ReelMode mode;

  /// Qué pueblo, en [ReelMode.town]. En las otras dos, -1.
  final int only;

  /// Nulo en la crónica. En la corta, las piezas que hay que ver caer.
  final List<ReelStep>? arrivals;

  @override
  State<ReelScreen> createState() => ReelScreenState();
}

class ReelScreenState extends State<ReelScreen>
    with SingleTickerProviderStateMixin {
  /// Anulable, no `late final`: si no hay crónica esta pantalla se va sola sin
  /// llegar a arrancarlo, y `dispose` tiene que poder no encontrarlo.
  Ticker? _ticker;
  final OrbitCamera _cam = OrbitCamera();

  /// La cámara, para poder mirarla desde un test.
  ///
  /// Pública porque lo que hay que vigilar aquí no se ve en lo que la pantalla
  /// escribe: que el acercamiento **no vuelva atrás nunca**. Era un zoom que
  /// latía —se alejaba en cada ráfaga y volvía a acercarse en cada pausa— y de
  /// eso no avisa ningún `expect` sobre un texto.
  @visibleForTesting
  OrbitCamera get camera => _cam;
  final EffectSystem _fx = EffectSystem();

  /// Lo que el pintor deja marcado al pasar, para poder tocarlo. Aquí no se
  /// toca: se le pasa, él lo vacía y lo rellena.
  final TouchMap _hits = TouchMap();

  Reel? _reel;

  /// Un plano por hábito, **construido una sola vez**, entero.
  ///
  /// Éste es el truco que hace que esto vaya a sesenta por segundo. Lo obvio
  /// sería levantar el plano de cada cuenta —el de 5 piezas, el de 6, el de
  /// 7—, y es lo que hace el expositor: pero un plano de mil quinientas piezas
  /// tarda casi diez milisegundos en levantarse, y rehacerlo en cada fotograma
  /// se come el fotograma entero y parte del siguiente.
  ///
  /// No hace falta. `builtTown` ya recibe el plano por un lado y la cuenta por
  /// otro, y corta por donde se le diga; y el plano entero cortado por la
  /// pieza k es, pieza por pieza, el plano de k. Eso último no es una
  /// suposición: está escrito como test en `test/reel_test.dart`, porque si
  /// algún día dejara de ser verdad, lo que se vería aquí son casas saltando
  /// de sitio mientras crece el pueblo.
  final List<TownLayout> _plans = [];

  double _t = 0;
  Duration _last = Duration.zero;

  /// Cuántas piezas habían caído la última vez que se miró, para saber cuáles
  /// son nuevas y levantarles el polvo.
  int _done = 0;

  /// Y cuántas lleva cada pueblo, andando. Hace falta saber **cuál** de las
  /// suyas es cada una para preguntarle al plano dónde cae, y recontarlas
  /// desde el principio en cada aterrizaje es recorrer la lista entera mil
  /// quinientas veces por una nube de polvo.
  final List<int> _seen = [];

  /// A qué pueblo está mirando la cámara.
  int _look = 0;

  /// Dónde cayó la última pieza, y de qué pueblo era. Es el blanco al que va
  /// la cámara que persigue piezas.
  V3? _at;
  int _atTown = -1;

  /// Cuándo fue el último salto de un pueblo a otro.
  double _lastCut = -9;

  /// La altura a la que mira la cámara, sin contar la subida del final.
  double _fy = 1.2;

  /// El encuadre de cada pueblo, calculado una vez sobre el plano entero.
  final Map<int, (V3, double, double)> _frames = {};

  /// Cuándo sonó el último golpe. Con mil piezas caen treinta por segundo y
  /// treinta golpes por segundo no son un pueblo construyéndose, son una
  /// ametralladora.
  double _lastKnock = -9;

  /// El tamaño del lienzo, para saber desde dónde cabe lo que hay construido.
  Size? _size;

  /// Verdadero cuando ya cayó todo y toca mirar lo que quedó.
  bool _over = false;

  /// Por dónde va el vuelo de entrada, de medio a uno.
  ///
  /// Empieza en medio y no en cero porque medio es la niebla cerrada del todo:
  /// esta pantalla no despega de ningún sitio, aparece ya estando arriba. Lo
  /// que hay que enseñar es la mitad de vuelta, la de llegar.
  ///
  /// Antes esto era un rectángulo negro que se desvanecía, y un negro que
  /// aparece de la nada no es una transición: es una pantalla que se apagó. El
  /// valle ya tiene su manera de decir que cambiaste de sitio, y es la misma
  /// niebla que se cruza al alejarse a mirar el valle entero.
  double _flight = 0.5;

  /// Lo que tarda en abrirse. La mitad de un vuelo entero, que es lo que es.
  static final double _flightSpan = CloudFlight.span.inMilliseconds / 2000;

  /// Cuánto se ha subido el pueblo en el cuadro para dejarle sitio a la
  /// tarjeta del final. Entra despacio, con ella.
  double _lift = 0;

  /// Si ésta es la corta, la de lo que llegó del widget.
  bool get _short => widget.mode == ReelMode.arrivals;

  /// Si la cámara va detrás de las piezas en vez de girar sobre una plaza.
  bool get _chase => widget.mode != ReelMode.town;

  @override
  void initState() {
    super.initState();
    final habits = widget.store.habits;
    final llegadas = widget.arrivals;
    _reel = llegadas != null
        ? Reel.arrivals(habits, llegadas)
        : Reel.of(habits, only: widget.only);
    for (final h in habits) {
      _seen.add(0);
      final (cx, cz) = Habit.centreOf(h.slot);
      _plans.add(
        TownLayout(
          h.total,
          h.place,
          cx: cx,
          cz: cz,
          chronicle: h.chronicle,
          folk: h.folk,
          // Los tres de adorno y no los de verdad. Lo que el tablón sabe de vos
          // lo sabe *hoy*, así que clavarlo en el pueblo de hace ocho meses
          // sería enseñar un papel que ese día no estaba. Y desde la altura a
          // la que pasa la cámara lo único que se ve de un tablón es que hay
          // papeles, no cuáles.
          seed: h.townSeed,
        ),
      );
    }
    final r = _reel;
    if (r != null && r.steps.isNotEmpty) {
      _look = r.steps.first.habit;
      _atTown = _look;
      // Empieza mirando al sitio donde va a caer la primera, y no al medio del
      // valle: la entrada de una cinemática no puede ser un barrido buscando
      // dónde está lo que va a pasar.
      final (cx, cz) = Habit.centreOf(habits[_look].slot);
      _cam.travel = _cam.travelTarget = cx;
      _cam.focusZ = _cam.focusZTarget = cz;
    }
    // Cada pueblo empieza con lo que ya tenía puesto. En la crónica eso es
    // cero; en la corta es el pueblo entero menos lo que va a caer.
    if (r != null) {
      for (var i = 0; i < _seen.length && i < r.base.length; i++) {
        _seen[i] = r.base[i];
      }
    }
    // Desde bastante arriba cuando no hay nada que mirar todavía, y a la
    // altura de los tejados cuando el pueblo ya está hecho: en la corta lo que
    // hay delante desde el primer fotograma es un pueblo, no un prado.
    _cam.pitch = _cam.pitchTarget = _chase ? 0.46 : 0.62;
    _cam.yaw = _cam.yawTarget = 0.7;
    // De lejos, siempre. De aquí para adelante la distancia sólo baja.
    _cam.distance = _cam.distanceTarget = _chase ? _closeUp * 4.0 : 90;
    _fy = 1.2;
    _cam.focusY = _cam.focusYTarget = _fy;
    if (r == null) {
      // No hay crónica que enseñar. No debería llegarse acá —el botón no sale
      // hasta que la hay— pero una pantalla negra sin salida es la peor manera
      // posible de que un día eso deje de ser verdad.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }
    Sensory.instance.reel(short: _short);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    // Que la música de la crónica no sobreviva a la pantalla que la pidió.
    Sensory.instance.hushReel();
    super.dispose();
  }

  // ------------------------------------------------------------------ el paso

  void _tick(Duration elapsed) {
    final r = _reel;
    if (r == null) return;
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0005, 0.05);
    _last = elapsed;
    _t += dt;

    final m = r.at(_t, _plans.length);
    if (m.done > _done) {
      _landed(r, m, _t);
      _done = m.done;
    }
    if (_flight < 1) _flight = math.min(1.0, _flight + dt / _flightSpan);
    _fx.update(dt);
    _drive(dt, m);

    // Un respiro al final antes de la tarjeta: la última nota todavía suena y
    // el pueblo lleva siete segundos quieto. Tapar eso con texto sería cortar
    // la película en el plano que más importa.
    if (!_over && _t > r.seconds + 1.4) _over = true;
    if (_over) _lift += (1 - _lift) * (1 - math.exp(-dt * 1.0));
    setState(() {});
  }

  /// El polvo y el golpe de lo que acaba de caer.
  void _landed(Reel r, ReelMoment m, double now) {
    // Se recorren todas las nuevas, porque el contador de cada pueblo tiene que
    // quedar bien; pero sólo se les levanta polvo a las últimas. En una ráfaga
    // caen a puñados, y veinte nubes a la vez se gastan el sistema de
    // partículas entero en tapar el pueblo que se está mirando.
    final polvo = math.max(_done, m.done - 3);
    for (var i = _done; i < m.done; i++) {
      final paso = r.steps[i];
      if (paso.habit < 0 || paso.habit >= _plans.length) continue;
      final cual = _seen[paso.habit]++;
      if (i < polvo) continue;
      final pieza = _plans[paso.habit].pieceFor(cual);
      if (pieza == null) continue;
      _fx.impact(
        V3(pieza.cx, pieza.y0, pieza.cz),
        pieza.w * 0.7,
        strength: 0.75,
      );
      // Y adónde tiene que mirar la cámara a partir de ahora. Un poco por
      // encima de su base, no a su media altura: mirar al suelo deja la pieza
      // pegada al borde de arriba, y mirar al medio de un campanario sube la
      // cámara diez metros y esconde el pueblo debajo.
      // El `_aupa` no es un gusto: mirando justo a la pieza, el pueblo se
      // sienta en el tercio de arriba del cuadro y debajo queda media pantalla
      // de prado. El punto medio de una caja en el mundo no cae en el punto
      // medio de su dibujo cuando se la mira desde arriba en escorzo, así que
      // se apunta **por encima** de lo que se quiere ver centrado.
      _at = V3(
        pieza.cx,
        pieza.y0 + math.min((pieza.y1 - pieza.y0) * 0.5, 1.6) + _aupa,
        pieza.cz,
      );
      _atTown = paso.habit;
    }
    if (now - _lastKnock > 0.22) {
      _lastKnock = now;
      Sensory.instance.impact(strength: 0.55);
    }
  }

  // --------------------------------------------------------------- la cámara

  /// Entra y sale despacio: cero en los bordes, uno en medio.
  static double _ease(double p) {
    final t = p.clamp(0.0, 1.0);
    return math.sin(t * math.pi).clamp(0.0, 1.0) * 0.55 + 0.45;
  }

  static double _suave(double t) => t * t * (3 - 2 * t);

  /// Lo que gira por segundo, según lo que se esté mirando.
  ///
  /// Lo que se siente como «dar la vuelta al pueblo» es cuánto se mueve el
  /// punto de vista, no cuántos radianes por segundo: en una cinemática de
  /// cinco segundos, a la velocidad de la de un minuto, la cámara se desplaza
  /// un dedo.
  double get _spin => switch (widget.mode) {
    ReelMode.valley => 0.13,
    ReelMode.town => 0.185,
    ReelMode.arrivals => 0.30,
  };

  /// A qué distancia se para de acercarse la cámara que persigue piezas.
  ///
  /// Veintiséis. El primer número que se probó fue quince, y quince es
  /// **dentro**: un hito de tres alturas llena la pantalla entera y lo que se
  /// ve es una pared. Lo que esta cámara tiene que contestar no es «cómo es
  /// esta piedra» sino **dónde cayó**, y para eso hace falta que entren ella y
  /// la manzana a la que llega. Desde aquí una casa ocupa un cuarto del alto
  /// del cuadro y el hito más grande cabe entero.
  static const double _closeUp = 26.0;

  /// Qué parte de la reproducción tarda en llegar a ese tope.
  ///
  /// Un tercio. Lo que se pidió es que arranque lejos y **siempre** se vaya
  /// acercando hasta un límite, y que a partir de ahí sólo gire; no que se
  /// pase la reproducción entera acercándose, que sería un travelling
  /// infinito.
  static const double _approach = 0.30;

  /// Cuánto por encima de la pieza mira la cámara que las persigue.
  static const double _aupa = 2.6;

  /// Lo mínimo entre dos cortes de un pueblo a otro.
  ///
  /// En una ráfaga de dos pueblos a la vez, saltar en cuanto cambia el que
  /// pone es un montaje de medio segundo por plano: no da tiempo a leer
  /// ninguno de los dos.
  static const double _cutEvery = 0.9;

  void _drive(double dt, ReelMoment m) {
    // El giro es lo único que las tres hacen igual.
    _cam.yaw += _spin * _ease(m.progress) * dt;
    _cam.yawTarget = _cam.yaw;

    if (_chase) {
      _chaseDrive(dt, m);
    } else {
      _orbit(dt, m);
    }

    // Y la subida del final, para dejarle sitio a la tarjeta. Se hace bajando
    // el punto al que mira la cámara, que ahora sí funciona: cuando el
    // encuadre se recalculaba en cada fotograma, bajar el foco no movía nada
    // —el ajuste lo veía salirse por el techo y se alejaba hasta volver a
    // centrarlo—, y ahora el encuadre está fijo.
    _cam.focusY = _fy - _lift * 3.4;
    _cam.focusYTarget = _cam.focusY;

    _cam.reaches(-400, 400);
    _cam.wallLength = math.max(_cam.distance, 40);
  }

  /// La cámara de un pueblo: mira a su plaza y se va acercando.
  ///
  /// **Sin latido.** Antes el encuadre salía de lo que había construido en ese
  /// fotograma, así que crecía con cada pieza: la cámara se alejaba un poco en
  /// cada ráfaga y volvía a acercarse en cada pausa, y eso, visto seguido, es
  /// un zoom que respira. Ahora el encuadre se calcula **una vez y sobre el
  /// pueblo terminado**, y lo que se recorre es el camino de lejos a cerca, en
  /// una dirección sola.
  void _orbit(double dt, ReelMoment m) {
    final p = m.progress;
    // El picado: se empieza mirando el prado bastante desde arriba, que es
    // como se mira un sitio donde todavía no hay nada, y se va bajando a la
    // altura de los tejados a medida que hay tejados que mirar.
    final quiere = lerpD(0.60, 0.32, _suave((p * 1.6).clamp(0.0, 1.0)));
    _cam.pitch += (quiere - _cam.pitch) * (1 - math.exp(-dt * 1.1));
    _cam.pitchTarget = _cam.pitch;

    final marco = _frame();
    if (marco == null) return;
    final (centro, cerca, lejos) = marco;
    final lento = 1 - math.exp(-dt * 1.15);
    _cam.travel += (centro.x - _cam.travel) * lento;
    _cam.focusZ += (centro.z - _cam.focusZ) * lento;
    _fy += (centro.y - _fy) * lento;
    _cam.travelTarget = _cam.travel;
    _cam.focusZTarget = _cam.focusZ;

    // Y llega al tope **pronto**, en el primer tercio, no en el último
    // fotograma. Es lo que se pidió y además es lo que se ve mejor: el
    // encuadre de salida es el del pueblo terminado, así que acercarse
    // despacio deja la mitad de la cinemática con un pueblo pequeño en medio
    // del prado. Llegando pronto al tope, lo que pasa el resto del rato es que
    // el pueblo **crece hasta llenar el cuadro**, que es lo que se está
    // contando.
    _cam.distance = lerpD(lejos, cerca, _suave((p / 0.35).clamp(0.0, 1.0)));
    _cam.distanceTarget = _cam.distance;
  }

  /// La cámara del valle y la de las llegadas: detrás de la pieza que cae.
  ///
  /// Girar alrededor del pueblo entero enseña que el pueblo crece y esconde lo
  /// único que hay que ver, que es **dónde** cayó esta piedra. Y en un valle de
  /// varios pueblos es peor: están cayendo piezas en tres sitios y la cámara
  /// mira uno, así que la mitad de lo que pasa pasa fuera del cuadro.
  ///
  /// Así que la cámara va detrás de la última. Dentro de un pueblo, deslizando;
  /// de un pueblo a otro, **cortando** — están a ciento veinticuatro unidades
  /// unos de otros y cruzar eso en plano son tres segundos de prado vacío.
  void _chaseDrive(double dt, ReelMoment m) {
    // Más bajo que la de pueblo: lo que hay que ver es una piedra apoyándose,
    // y eso desde arriba es un tejado que cambia de color.
    final quiere = lerpD(
      0.46,
      0.26,
      _suave((m.progress * 2.4).clamp(0.0, 1.0)),
    );
    _cam.pitch += (quiere - _cam.pitch) * (1 - math.exp(-dt * 1.4));
    _cam.pitchTarget = _cam.pitch;

    // De lejos al tope, y ahí se queda. La cuenta es monótona por escrito, no
    // por costumbre: es lo que garantiza que no haya vuelta atrás.
    _cam.distance = lerpD(
      _closeUp * 4.0,
      _closeUp,
      _suave((m.progress / _approach).clamp(0.0, 1.0)),
    );
    _cam.distanceTarget = _cam.distance;

    final va = _at;
    if (va == null) return;
    if (_atTown != _look) {
      if (_t - _lastCut < _cutEvery) return;
      _look = _atTown;
      _lastCut = _t;
      _cam.travel = va.x;
      _cam.focusZ = va.z;
      _fy = va.y;
    } else {
      final k = 1 - math.exp(-dt * 3.2);
      _cam.travel += (va.x - _cam.travel) * k;
      _cam.focusZ += (va.z - _cam.focusZ) * k;
      _fy += (va.y - _fy) * k;
    }
    _cam.travelTarget = _cam.travel;
    _cam.focusZTarget = _cam.focusZ;
  }

  /// El encuadre de un pueblo de principio a fin: dónde mirar, y desde dónde
  /// al empezar y al acabar.
  ///
  /// Calculado una sola vez por pueblo, sobre el plano **entero**, y guardado.
  /// Es lo que hace que el acercamiento sea un camino y no una persecución de
  /// un blanco que se mueve.
  (V3, double, double)? _frame() {
    final ya = _frames[_look];
    if (ya != null) return ya;
    final size = _size;
    if (size == null || size.isEmpty) return null;
    if (_look < 0 || _look >= _plans.length) return null;
    final plan = _plans[_look];
    final caja = builtTown(plan, plan.pieces.length).bounds;
    if (caja == null) return null;

    // Un poco de prado alrededor: un pueblo pegado a los bordes de la pantalla
    // no se ve estar en ningún sitio.
    const aire = 1.8;
    final alto = caja.y1 - caja.y0;
    // Y mira un poco por debajo del centro. No es un ajuste de gusto: el punto
    // medio de una caja en el mundo no cae en el punto medio de su dibujo
    // cuando se la mira desde arriba en escorzo, y mirando al centro exacto el
    // pueblo se sienta al sesenta por ciento de la altura de la pantalla.
    final cy = (caja.y0 + caja.y1) / 2 - alto * 0.30;
    final centro = V3((caja.x0 + caja.x1) / 2, cy, (caja.z0 + caja.z1) / 2);

    final puntos = <V3>[
      for (final x in [caja.x0 - aire, caja.x1 + aire])
        for (final y in [caja.y0, caja.y1 + 1.0])
          for (final z in [caja.z0 - aire, caja.z1 + aire]) V3(x, y, z),
    ];
    final ojo = OrbitCamera()
      ..travel = centro.x
      ..focusY = centro.y
      ..focusZ = centro.z
      ..yaw = _cam.yaw
      ..pitch = 0.36
      ..distance = _cam.distance;
    final ajuste = ojo.distanceToFit(
      puntos,
      size.width,
      size.height,
      margin: 0.88,
    );
    // Apretado al final y holgado al principio: el camino entero de la
    // cinemática cabe entre estos dos números.
    //
    // Holgado quiere decir un tercio más lejos, no el doble. Con el doble —que
    // fue el primer intento— la mitad de la cinemática transcurre con el
    // pueblo del tamaño de una moneda en medio del prado: el encuadre de
    // salida es el del pueblo **terminado**, así que ya es de por sí ancho
    // para lo que hay puesto al principio.
    final hecho = (centro, ajuste * 0.78, ajuste * 1.5);
    _frames[_look] = hecho;
    return hecho;
  }

  // ------------------------------------------------------------------ pintar

  void _leave() {
    Sensory.instance.hushReel();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final r = _reel;
    if (r == null) return const SizedBox.shrink();
    final m = r.at(_t, _plans.length);

    // La luz del día que se está mirando, no la de hoy. De aquí sale que el
    // valle cambie de estación mientras crece, que es lo que más se nota de
    // todo esto y no costó nada: la fecha ya la lleva el reloj de la crónica.
    final season = Season.on(m.when, Appearance.instance.hemisphere);
    final hour = m.when.hour + m.when.minute / 60.0;
    // Entero, siempre. Lo que se está mirando es lo que construiste, y un
    // pueblo a media luz porque esta semana no viniste contaría otra cosa.
    final palette = Palette.forMoment(hour, 1.0, season: season);
    final theme = UiTheme(palette);
    final night = nightOf(m.when);

    final store = widget.store;
    final entries = <TownEntry>[
      for (var i = 0; i < _plans.length; i++)
        TownEntry(
          layout: _plans[i],
          name: store.habits[i].name,
          symbol: store.habits[i].symbol,
          integrity: 1.0,
          placed: m.counts[i],
        ),
    ];

    final scene = TownScene(
      placed: m.counts.isEmpty ? 0 : m.counts[0],
      palette: palette,
      camera: _cam,
      integrity: 1.0,
      time: _t,
      hourOfDay: hour,
      effects: _fx,
      labelledBricks: const {},
      towns: entries,
      active: 0,
      // Sin rótulos de hito ni nombres de pueblo. Sesenta segundos de cámara en
      // movimiento con carteles apareciendo y desapareciendo es una pantalla de
      // información; lo que hay que mirar es el sitio.
      labels: false,
      skyNight: night,
      tonight: palette.starAlpha > 0.35 ? tonight(night) : null,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _over ? _leave : null,
        child: LayoutBuilder(
          builder: (context, box) {
            _size = Size(box.maxWidth, box.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: TownPainter(scene, _hits),
                  size: Size.infinite,
                  isComplex: true,
                  willChange: true,
                ),
                // La llegada. La cinemática ya está corriendo por detrás
                // —la entrada del reloj dura más que esto—, así que cuando la
                // niebla se abre el valle lleva un momento ahí.
                if (_flight < 1)
                  IgnorePointer(
                    child: CloudFlight(t: _flight, palette: palette),
                  ),
                _Date(when: m.when, theme: theme, show: !_over && _t > 1.2),
                if (!_over)
                  Positioned(
                    right: 16,
                    bottom: 20 + MediaQuery.of(context).padding.bottom,
                    child: _Skip(theme: theme, onTap: _leave),
                  ),
                if (_over)
                  _Ending(
                    reel: r,
                    theme: theme,
                    onTap: _leave,
                    fromWidget: _short,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// La fecha que se está mirando, arriba y en voz baja.
///
/// Es lo que hace legible todo lo demás. Sin ella el valle cambia de verde a
/// blanco y vuelve a verde y parece un efecto; con ella, el que mira sabe que
/// acaba de pasar un invierno.
class _Date extends StatelessWidget {
  const _Date({required this.when, required this.theme, required this.show});

  final DateTime when;
  final UiTheme theme;
  final bool show;

  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 22,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 600),
          child: Center(
            child: Text(
              '${_meses[when.month - 1]} de ${when.year}'.toUpperCase(),
              style: TextStyle(
                color: theme.fgSoft,
                fontSize: 11.5,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(color: theme.panelStrong, blurRadius: 10)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Skip extends StatelessWidget {
  const _Skip({required this.theme, required this.onTap});

  final UiTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          'SALTAR',
          style: TextStyle(
            color: theme.fgFaint,
            fontSize: 11,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w500,
            shadows: [Shadow(color: theme.panelStrong, blurRadius: 10)],
          ),
        ),
      ),
    );
  }
}

/// Lo que queda escrito al acabar.
///
/// Tres datos y ninguno más: cuántas, desde cuándo y cuánto duró. No hay media
/// diaria, no hay mejor racha y no hay porcentaje — el pueblo que acaba de
/// quedarse quieto detrás ya dijo todo eso mucho mejor.
///
/// **Del mismo vidrio que las hojas de la app.** Era una tarjeta de papel
/// claro, que es lo que hace `Frosted` de día, y encima de un prado a mediodía
/// eso es un papel pegado a la pantalla — justo lo que se quitó de la hoja de
/// un hábito el día que se cambió por vidrio ahumado. Una app no puede tener
/// dos maneras de poner algo encima del pueblo.
class _Ending extends StatelessWidget {
  const _Ending({
    required this.reel,
    required this.theme,
    required this.onTap,
    this.fromWidget = false,
  });

  final Reel reel;
  final UiTheme theme;
  final VoidCallback onTap;

  /// La corta cuenta otra cosa. «Desde el 4 de marzo, son 312 días» es lo que
  /// se dice de un pueblo entero; de tres piezas puestas anoche desde la
  /// pantalla de inicio lo único que hay que decir es de dónde salieron.
  final bool fromWidget;

  static String _fecha(DateTime d) =>
      '${d.day} de ${_Date._meses[d.month - 1]} de ${d.year}';

  @override
  Widget build(BuildContext context) {
    final dias = reel.days + 1;
    final velo = SheetInk.of(theme);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: child,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            22 + MediaQuery.of(context).padding.bottom,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: velo.bruma,
                sigmaY: velo.bruma,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
                decoration: BoxDecoration(
                  color: velo.tinte.withValues(alpha: velo.tapa),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: velo.canto),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // El número y su palabra en la misma línea, apoyados por
                    // abajo. Apilados, la palabra quedaba flotando debajo de
                    // una cifra grande y la tarjeta empezaba con dos renglones
                    // para decir una cosa.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${reel.pieces}',
                          style: TextStyle(
                            color: velo.cuerpo,
                            fontSize: 38,
                            height: 1.0,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -1.5,
                            shadows: velo.aliento,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          reel.pieces == 1 ? 'pieza' : 'piezas',
                          style: TextStyle(
                            color: velo.suave,
                            fontSize: 13.5,
                            letterSpacing: 0.3,
                            shadows: velo.aliento,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(height: 1, color: velo.canto),
                    const SizedBox(height: 12),
                    if (fromWidget)
                      _Line(
                        left: 'puestas',
                        right: 'desde la pantalla de inicio',
                        ink: velo,
                      )
                    else ...[
                      _Line(left: 'desde', right: _fecha(reel.from), ink: velo),
                      const SizedBox(height: 7),
                      _Line(
                        left: 'son',
                        right: '$dias ${dias == 1 ? 'día' : 'días'}',
                        ink: velo,
                      ),
                    ],
                    const SizedBox(height: 4),
                    // El botón, ancho y con su propio toque: una línea de
                    // letras centrada en medio de una tarjeta que ya se toca
                    // entera no se lee como un botón, se lee como un pie.
                    InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            fromWidget ? 'AL VALLE' : 'VOLVER AL VALLE',
                            style: TextStyle(
                              color: theme.accent,
                              fontSize: 11.5,
                              letterSpacing: 2.4,
                              fontWeight: FontWeight.w600,
                              shadows: velo.aliento,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.left, required this.right, required this.ink});

  final String left, right;
  final SheetInk ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          left,
          style: TextStyle(
            color: ink.tenue,
            fontSize: 12.5,
            shadows: ink.aliento,
          ),
        ),
        Text(
          right,
          style: TextStyle(
            color: ink.suave,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            shadows: ink.aliento,
          ),
        ),
      ],
    );
  }
}
