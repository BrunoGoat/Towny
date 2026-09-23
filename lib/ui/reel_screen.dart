import 'dart:math' as math;

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
class ReelScreen extends StatefulWidget {
  const ReelScreen({super.key, required this.store}) : arrivals = null;

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
  }) : arrivals = pieces;

  final Store store;

  /// Nulo en la crónica. En la corta, las piezas que hay que ver caer.
  final List<ReelStep>? arrivals;

  @override
  State<ReelScreen> createState() => _ReelScreenState();
}

class _ReelScreenState extends State<ReelScreen>
    with SingleTickerProviderStateMixin {
  /// Anulable, no `late final`: si no hay crónica esta pantalla se va sola sin
  /// llegar a arrancarlo, y `dispose` tiene que poder no encontrarlo.
  Ticker? _ticker;
  final OrbitCamera _cam = OrbitCamera();
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

  /// Dónde está pasando algo. Sube cuando cae una pieza en ese pueblo y baja
  /// solo, así que dice «acá es donde hay que mirar ahora».
  final List<double> _heat = [];

  /// Y a cuál está mirando la cámara. Se cambia de pueblo por un margen ancho,
  /// nunca por ir empatados: en un valle donde caen piezas en dos pueblos casi
  /// a la vez, seguir al que va ganando por poco es una cámara que da bandazos.
  int _look = 0;

  /// Cuándo sonó el último golpe. Con mil piezas caen treinta por segundo y
  /// treinta golpes por segundo no son un pueblo construyéndose, son una
  /// ametralladora.
  double _lastKnock = -9;

  /// El tamaño del lienzo, para saber desde dónde cabe lo que hay construido.
  Size? _size;

  /// Verdadero cuando ya cayó todo y toca mirar lo que quedó.
  bool _over = false;

  /// Cuánto se ha subido el pueblo en el cuadro para dejarle sitio a la
  /// tarjeta del final. Entra despacio, con ella.
  double _lift = 0;

  /// Si ésta es la corta, la de lo que llegó del widget.
  bool get _short => widget.arrivals != null;

  /// Si la corta ya encuadró el pueblo de un salto.
  ///
  /// La crónica puede permitirse llegar al encuadre despacio: empieza mirando
  /// un prado vacío y tiene un minuto para acercarse. La corta empieza con el
  /// pueblo entero delante y dura once segundos — si entra con la misma
  /// aproximación mansa, los primeros cuatro se van en un pueblo diminuto en
  /// medio de la pantalla y las piezas caen antes de que se le vea la cara.
  /// Así que el primer fotograma se planta donde toca y a partir de ahí ya se
  /// mueve como la otra.
  bool _snapped = false;

  @override
  void initState() {
    super.initState();
    final habits = widget.store.habits;
    final llegadas = widget.arrivals;
    _reel = llegadas == null
        ? Reel.of(habits)
        : Reel.arrivals(habits, llegadas);
    for (final h in habits) {
      _seen.add(0);
      _heat.add(0);
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
    if (r != null && r.steps.isNotEmpty) _look = r.steps.first.habit;
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
    _cam.pitch = _cam.pitchTarget = _short ? 0.44 : 0.62;
    _cam.yaw = _cam.yawTarget = 0.7;
    _cam.distance = _cam.distanceTarget = 26;
    _cam.focusY = _cam.focusYTarget = 1.2;
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
      _heat[paso.habit] += 1.0;
      if (i < polvo) continue;
      final pieza = _plans[paso.habit].pieceFor(cual);
      if (pieza == null) continue;
      _fx.impact(
        V3(pieza.cx, pieza.y0, pieza.cz),
        pieza.w * 0.7,
        strength: 0.75,
      );
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

  void _drive(double dt, ReelMoment m) {
    final p = m.progress;

    // El giro. Una vuelta y media larga en todo el minuto, arrancando y
    // parando despacio — una cámara que gira a velocidad fija delata que es
    // un bucle de código y no una cámara.
    //
    // En la corta va más del doble de rápido, y no es un capricho: lo que se
    // siente como «dar la vuelta al pueblo» es cuánto se mueve el punto de
    // vista, no cuántos radianes por segundo. En once segundos, a la
    // velocidad de la crónica, la cámara se desplaza un dedo.
    _cam.yaw += (_short ? 0.40 : 0.185) * _ease(p) * dt;
    _cam.yawTarget = _cam.yaw;

    // El picado. Se empieza mirando el prado bastante desde arriba, que es
    // como se mira un sitio donde todavía no hay nada, y se va bajando a la
    // altura de los tejados a medida que hay tejados que mirar.
    final quiere = _short
        ? lerpD(0.44, 0.30, _suave((p * 1.6).clamp(0.0, 1.0)))
        : lerpD(0.60, 0.32, _suave((p * 1.6).clamp(0.0, 1.0)));
    _cam.pitch += (quiere - _cam.pitch) * (1 - math.exp(-dt * 1.1));
    _cam.pitchTarget = _cam.pitch;

    // Adónde mira. **Al pueblo en el que están cayendo piezas**, no al valle.
    //
    // Encuadrar el valle entero fue lo primero que probé y se ve fatal: los
    // pueblos están a ciento veinticuatro unidades unos de otros y miden ocho
    // de ancho, así que caber los dos quiere decir estar a doscientos cincuenta
    // de distancia, y lo que se ve son dos motas a los lados de una pantalla
    // llena de prado. Lo que hay que mirar de un valle de dos pueblos no es el
    // valle: es el pueblo donde está pasando algo, con el otro asomando al
    // fondo cuando la vuelta de la cámara lo trae.
    //
    // Y cambiar de uno a otro por su cuenta resultó ser lo mejor que hace esta
    // pantalla: el día que empezaste el segundo hábito, la cámara cruza el
    // valle. Eso no hubo que escribirlo, sale de seguir a las piezas.
    final calor = 1 - math.exp(-dt / 2.6);
    for (var i = 0; i < _heat.length; i++) {
      _heat[i] -= _heat[i] * calor;
    }
    for (var i = 0; i < _heat.length; i++) {
      if (i == _look || m.counts[i] <= 0) continue;
      if (_heat[i] > _heat[_look] * 1.7 + 0.4) _look = i;
    }

    final caja = _built(m);
    if (caja != null) {
      final (centro, puntos) = caja;
      final plantar = _short && !_snapped;
      final lento = plantar ? 1.0 : 1 - math.exp(-dt * 1.15);
      _cam.travel += (centro.x - _cam.travel) * lento;
      _cam.focusZ += (centro.z - _cam.focusZ) * lento;
      _cam.focusY += (centro.y - _cam.focusY) * lento;
      _cam.travelTarget = _cam.travel;
      _cam.focusZTarget = _cam.focusZ;
      _cam.focusYTarget = _cam.focusY;

      final size = _size;
      if (size != null && !size.isEmpty) {
        final ojo = OrbitCamera()
          ..travel = _cam.travel
          ..focusY = _cam.focusY
          ..focusZ = _cam.focusZ
          ..yaw = _cam.yaw
          ..pitch = _cam.pitch
          ..distance = _cam.distance;
        final quiere = ojo.distanceToFit(
          puntos,
          size.width,
          size.height,
          // Apretado. Con 0,80 el pueblo ocupaba menos de la mitad del ancho y
          // el resto era prado: un plano general de un sitio del que no hay
          // nada que contar alrededor.
          margin: 0.90,
        );
        // Y el acercamiento, que en la corta va más vivo por lo mismo que el
        // giro: once segundos no dan para una aproximación de minuto.
        _cam.distance +=
            (quiere - _cam.distance) *
            (plantar ? 1.0 : (1 - math.exp(-dt * (_short ? 2.4 : 0.9))));
        _cam.distanceTarget = _cam.distance;
        if (plantar) _snapped = true;
      }
    }
    _cam.reaches(-400, 400);
    _cam.wallLength = math.max(_cam.distance, 40);
  }

  static double _suave(double t) => t * t * (3 - 2 * t);

  /// El centro y las esquinas de lo que está levantado en el pueblo que se
  /// está mirando.
  ///
  /// Sale de `builtTown`, que es la misma llamada que va a hacer el pintor
  /// dentro de un momento para dibujarlo: está cacheada, así que preguntarle
  /// dónde llega el pueblo no cuesta nada aparte de leerlo. Y es **lo
  /// construido**, no el plano entero: encuadrar desde el primer segundo el
  /// pueblo que va a haber dentro de un minuto deja la cámara plantada
  /// mirando cómo aparecen cosas diminutas en el medio del cuadro.
  (V3, List<V3>)? _built(ReelMoment m) {
    final puntos = <V3>[];
    final n = _look < m.counts.length ? m.counts[_look] : 0;
    if (n <= 0) return null;
    final b = builtTown(
      _plans[_look],
      math.min(n, _plans[_look].pieces.length),
    );
    final caja = b.bounds;
    if (caja == null) return null;
    final x0 = caja.x0, y0 = caja.y0, z0 = caja.z0;
    final x1 = caja.x1, y1 = caja.y1, z1 = caja.z1;
    // Un poco de prado alrededor: un pueblo pegado a los bordes de la pantalla
    // no se ve estar en ningún sitio.
    //
    // Menos en la corta, y no por gusto. Lo que se está mirando ahí no es un
    // pueblo entero creciendo: son tres piezas cayendo sobre un pueblo que ya
    // estaba, y una piedra vista desde donde cabe todo el valle es un píxel
    // que cambia de color. Se entra más cerca.
    final aire = _short ? 1.0 : 1.8;

    // Y sitio por debajo para la tarjeta del final, que es lo único en toda la
    // pantalla que tapa algo — y lo que taparía es justo lo que se ha tardado
    // un minuto en levantar.
    //
    // Hecho ensanchando la caja hacia abajo, y no bajando el punto al que mira
    // la cámara, que fue lo primero que probé y **no hace nada**: el encuadre
    // se calcula para que la caja entera quepa, así que bajar el foco deja el
    // pueblo más arriba respecto de él, el ajuste lo ve salirse por el techo, y
    // aleja la cámara hasta volver a centrarlo. Sale un pueblo más pequeño en
    // el mismo sitio. Ensanchando la caja, en cambio, lo que se reserva es el
    // hueco, y el pueblo sube de verdad a la mitad de arriba.
    //
    // Y un poco de ese hueco **siempre**, no sólo al final. Medido sobre los
    // fotogramas: mirando al centro exacto de la caja, el pueblo se sienta al
    // sesenta y dos por ciento de la altura de la pantalla y no al cincuenta.
    // No es un fallo de cuentas, es la perspectiva — el punto medio de una
    // caja en el mundo no cae en el punto medio de su dibujo cuando se la mira
    // desde arriba en escorzo — y se corrige aquí, que es donde se ve.
    // Y su tarjeta también es más corta —dos líneas en vez de cuatro—, así
    // que el hueco que hay que reservarle debajo es menos.
    final hondo = _short
        ? (y1 - y0) * 0.20 + 0.5 + _lift * ((y1 - y0) * 1.1 + 3.0)
        : (y1 - y0) * 0.45 + 0.8 + _lift * ((y1 - y0) * 1.5 + 4.0);

    for (final x in [x0 - aire, x1 + aire]) {
      for (final y in [y0 - hondo, y1 + 1.0]) {
        for (final z in [z0 - aire, z1 + aire]) {
          puntos.add(V3(x, y, z));
        }
      }
    }
    // Y mira al medio de esa caja, que es lo que la deja encuadrada lo más
    // apretada posible: si el foco no está en su centro, el ajuste tiene que
    // alejarse hasta que quepa el lado que sobresale más.
    return (
      V3((x0 + x1) / 2, (y0 - hondo + y1 + 1.0) / 2, (z0 + z1) / 2),
      puntos,
    );
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
                // La entrada y la salida en negro. Sin ellas la cinemática
                // empieza de un corte, que es lo que hace que una pantalla
                // parezca una pantalla y no una película.
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _t < 0.9 ? 1 : 0,
                    duration: const Duration(milliseconds: 900),
                    child: Container(color: Colors.black),
                  ),
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
          child: Frosted(
            theme: theme,
            strong: true,
            radius: 26,
            padding: const EdgeInsets.fromLTRB(22, 17, 22, 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${reel.pieces}',
                  style: TextStyle(
                    color: theme.fg,
                    fontSize: 34,
                    height: 1.0,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reel.pieces == 1 ? 'pieza' : 'piezas',
                  style: TextStyle(
                    color: theme.fgSoft,
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: theme.stroke),
                const SizedBox(height: 11),
                if (fromWidget)
                  _Line(
                    left: 'puestas',
                    right: 'desde la pantalla de inicio',
                    theme: theme,
                  )
                else ...[
                  _Line(left: 'desde', right: _fecha(reel.from), theme: theme),
                  const SizedBox(height: 7),
                  _Line(
                    left: 'son',
                    right: '$dias ${dias == 1 ? 'día' : 'días'}',
                    theme: theme,
                  ),
                ],
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      fromWidget ? 'AL VALLE' : 'VOLVER AL VALLE',
                      style: TextStyle(
                        color: theme.fg,
                        fontSize: 11.5,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.left, required this.right, required this.theme});

  final String left, right;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: TextStyle(color: theme.fgFaint, fontSize: 12.5)),
        Text(
          right,
          style: TextStyle(
            color: theme.fgSoft,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
