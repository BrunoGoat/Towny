import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/math3.dart';
import '../data/character.dart';
import '../data/symbols.dart';
import '../engine/camera.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../engine/scene.dart';
import '../engine/town.dart';
import '../fx/effects.dart';
import '../fx/sensory.dart';
import '../l10n/lang.dart';
import '../model/appearance.dart';
import '../model/pledge.dart';
import '../model/store.dart';
import 'habit_sigil.dart';
import 'town_portrait.dart';

/// Lo que se ve la primera vez que se abre la app.
///
/// Cinco pantallas, una pregunta en cada una, y al final un pueblo fundado.
///
/// **Por qué existe.** Sin esto, la primera vez que alguien abría Towny se
/// encontraba un prado vacío, un botón grande y un hábito de mentira llamado
/// «Mi hábito». Todo lo que hace a esta app distinta —que una pieza es un
/// logro, que no hay rachas, que las dos frases que escribís se guardan para el
/// día malo— estaba ahí desde el primer minuto y no lo contaba nadie. Se
/// descubría a los tres meses o no se descubría.
///
/// **Y por qué son pantallas y no una hoja con campos.** Un formulario se
/// contesta entero mirando los huecos que faltan por rellenar, y las dos
/// preguntas del final —para qué y en quién te convierte— no se contestan bien
/// así: son lo único de toda la app que se escribe para leerlo mucho después,
/// y merecen que no haya nada más en pantalla cuando se escriben.
///
/// **Y por qué sólo esas dos.** Se preguntaba además cuándo y dónde, y qué es
/// lo mínimo que cuenta. Es lo que recomienda cualquier libro de hábitos, y
/// convertía el primer minuto en una declaración de intenciones con hora y
/// sitio — lo contrario de lo que hacía bien esta app, que es que no se sienta
/// como una lista de cosas por cumplir. El primer día se habla de lo que
/// querés; lo práctico lo propone el pueblo después, cuando ya tiene algo que
/// enseñarte: a la semana pregunta cada cuánto va, y cuando ve a qué hora
/// aparecés, te la ofrece para darla por dicha.
///
/// **El fondo es el valle de verdad, y está vivo.** Lo pinta el mismo pintor
/// que el pueblo, con el cielo de esta hora: nubes que pasan, estrellas que
/// titilan, pájaros de día. Con cada respuesta la cámara baja un poco más
/// hacia el claro donde va a estar el pueblo, y al fundar se zambulle hasta la
/// toma en la que el pueblo arranca ([HandoffShot]) — así que el paso de estas
/// preguntas al pueblo no es un corte: es la misma cámara que sigue bajando
/// mientras sube la plaza.
///
/// **Y los colores no dependen de la hora.** Las preguntas van en una tarjeta
/// de vidrio oscuro con letra crema y dorado: al mediodía y a medianoche se
/// leen igual, que no pasaba escribiendo directamente sobre el prado.
class FirstRun extends StatefulWidget {
  const FirstRun({super.key, required this.onDone, this.next, this.onCancel});

  /// Si esto no es la primera vez sino el pueblo siguiente: lo que ya hay en
  /// el valle. Nulo la primera vez. Ver [NextTown].
  final NextTown? next;

  /// Volver sin fundar. Sólo existe para el pueblo siguiente: la primera vez
  /// no hay adónde volver.
  final VoidCallback? onCancel;

  /// Lo que se contestó, para que quien lo pidió funde el pueblo.
  ///
  /// Las dos últimas son opcionales y llegan en nulo si se saltaron. El
  /// nombre y la marca no: sin ellas no hay pueblo. Llega cuando la cámara ya
  /// terminó de bajar, que es cuando el pueblo tiene que tomar el relevo.
  final void Function(
    String name,
    String symbol, {
    required int character,
    String? why,
    String? identity,
  })
  onDone;

  /// Lo que tarda la bajada final, de la última pregunta al pueblo.
  static const Duration leaving = Duration(milliseconds: 1500);

  @override
  State<FirstRun> createState() => _FirstRunState();
}

/// Lo que hace la app con lo que se contestó en la primera vez.
///
/// Devuelve si fundó algo. **Un ensayo no funda nada**: si la primera vez se
/// abrió desde ajustes para mirarla ([Appearance.rehearsing]), se vuelve al
/// valle tal como estaba, con su nombre, su marca y su comarca.
///
/// Si no, se le pone todo al hábito en blanco con el que arranca el valle en
/// vez de crear uno: ese hueco ya existe y ya tiene su solar. La comarca
/// primero, porque sólo se puede elegir mientras el pueblo no tiene ninguna
/// pieza.
Future<bool> foundFirstTown(
  Store store,
  String name,
  String symbol, {
  required int character,
  String? why,
  String? identity,
}) async {
  if (Appearance.instance.rehearsing) {
    await Appearance.instance.setOnboarded();
    return false;
  }
  store.settle(0, character);
  store.renameHabit(
    0,
    name: name.isEmpty ? tr('Mi hábito', 'My habit') : name,
    symbol: symbol,
  );
  store.describeHabit(0, why: why);
  store.pledgeHabit(0, identity: identity);
  store.justFounded = true;
  await Appearance.instance.setOnboarded();
  return true;
}

/// Lo que ya hay en el valle cuando se funda el pueblo siguiente.
///
/// **Fundar el segundo pueblo es un antes y un después**, y se tiene que
/// sentir así. Era tocar el «+» y rellenar la misma hoja con la que se cambia
/// el nombre de un hábito: un formulario, para la única cosa de la app que se
/// gana sosteniendo otra durante semanas. Ahora es esta misma pantalla —el
/// valle, las preguntas, la cámara bajando— con una bienvenida propia que dice
/// qué se ganó y por qué.
class NextTown {
  const NextTown({required this.towns});

  /// Los pueblos que ya hay: su nombre, su marca, sus piezas y su comarca.
  final List<({String name, String symbol, int pieces, int character})> towns;

  /// El número del pueblo que se va a fundar: dos para el segundo.
  int get ordinal => towns.length + 1;

  /// «segundo», «tercer»… para decirlo con palabras y no con un número.
  String get ordinalWord => switch (ordinal) {
    2 => tr('segundo', 'second'),
    3 => tr('tercer', 'third'),
    4 => tr('cuarto', 'fourth'),
    5 => tr('quinto', 'fifth'),
    6 => tr('sexto', 'sixth'),
    _ => tr('nuevo', 'new'),
  };

  int get pieces => towns.fold(0, (a, t) => a + t.pieces);
}

/// Los colores de la primera vez. Fijos y no de la hora, ver [FirstRun].
class _Ink {
  const _Ink._();

  static const glass = Color(0xFF14110D);
  static const cream = Color(0xFFF6EFE1);
  static const gold = Color(0xFFEBC07A);
  static const goldDeep = Color(0xFFD1904A);
  static const onGold = Color(0xFF261B0F);

  static Color soft([double a = 0.72]) => cream.withValues(alpha: a);

  static const serif = 'EBGaramond';
}

class _FirstRunState extends State<FirstRun> with TickerProviderStateMixin {
  int _step = 0;
  String _symbol = habitSymbols.first;

  /// La comarca del pueblo. Sólo cambia cómo se ve.
  ///
  /// Para el pueblo siguiente arranca en una que el valle todavía no tenga:
  /// dos pueblos iguales uno al lado del otro se leen como uno solo.
  late int _place = () {
    final ya = {for (final t in widget.next?.towns ?? const []) t.character};
    for (final c in TownCharacter.all) {
      if (!ya.contains(c.order)) return c.order;
    }
    return TownCharacter.forSlot(0).order;
  }();
  final _name = TextEditingController();
  final _why = TextEditingController();

  /// En quién te convierte, sin el «alguien» del principio: ése va escrito
  /// fijo delante del campo, y se le pega al guardar.
  final _identity = TextEditingController();

  /// Ya se contestó todo y la cámara está bajando al pueblo.
  bool _leaving = false;

  /// Se crea al empezar y no la primera vez que se usa. Perezoso, una pantalla
  /// que se cerraba sin llegar a fundar lo creaba por primera vez dentro de su
  /// propio `dispose`, que es justo cuando ya no puede pedir su reloj.
  late final AnimationController _leave;

  @override
  void initState() {
    super.initState();
    _leave = AnimationController(vsync: this, duration: FirstRun.leaving);
  }

  @override
  void dispose() {
    _leave.dispose();
    _name.dispose();
    _why.dispose();
    _identity.dispose();
    super.dispose();
  }

  void _go(int to) {
    Sensory.instance.tick();
    setState(() => _step = to);
  }

  Future<void> _found() async {
    if (_leaving) return;
    Sensory.instance.tick();
    FocusScope.of(context).unfocus();
    setState(() => _leaving = true);
    await _leave.forward();
    if (!mounted) return;
    String? dicho(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    widget.onDone(
      _name.text.trim(),
      _symbol,
      character: _place,
      why: dicho(_why),
      identity: identityWhole(_identity.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final teclado = mq.viewInsets.bottom;
    final nombre = _name.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF9FB6D8),
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // El valle, vivo. Va en su propio widget con su propio reloj para
          // que pintar sesenta cuadros por segundo no reconstruya los campos
          // de texto.
          _Valley(stage: _step, leaving: _leaving),
          // Dos veladuras: arriba, para que la marca se lea sobre un cielo de
          // mediodía; abajo, para que la tarjeta se apoye en algo.
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 900),
              opacity: _leaving ? 0 : 1,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0x59000000),
                    ],
                    stops: [0.0, 0.30, 0.50, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // La marca, sólo en la bienvenida.
          Positioned(
            left: 0,
            right: 0,
            top: mq.padding.top + mq.size.height * 0.09,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _step == 0 && !_leaving ? 1 : 0,
                child: widget.next == null
                    ? const _Wordmark()
                    : _Milestone(next: widget.next!),
              ),
            ),
          ),
          // Mientras baja la cámara, el nombre del pueblo que se funda.
          if (_leaving)
            Center(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _leave,
                  builder: (_, _) => _FoundingName(
                    name: nombre.isEmpty
                        ? tr('Tu pueblo', 'Your town')
                        : nombre,
                    t: _leave.value,
                  ),
                ),
              ),
            ),
          // La tarjeta, abajo, subiendo con el teclado.
          AnimatedPadding(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: teclado),
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 560),
                  curve: Curves.easeInCubic,
                  offset: _leaving ? const Offset(0, 0.35) : Offset.zero,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 420),
                    opacity: _leaving ? 0 : 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 520,
                          maxHeight: math.max(
                            240,
                            mq.size.height - teclado - mq.padding.top - 40,
                          ),
                        ),
                        child: _Card(step: _step, child: _content()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lo que va dentro de la tarjeta, y cómo se cambia de una pregunta a otra:
  /// la vieja se va hacia la izquierda y la nueva entra por la derecha, y la
  /// tarjeta cambia de alto sin saltos.
  Widget _content() => AnimatedSize(
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
    alignment: Alignment.bottomCenter,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.bottomCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, a) {
        final entra = child.key == ValueKey(_step);
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: Offset(entra ? 0.10 : -0.10, 0),
              end: Offset.zero,
            ).animate(a),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: switch (_step) {
          0 => _welcome(),
          1 => _askName(),
          2 => _askPlace(),
          3 => _askWhy(),
          _ => _askWho(),
        },
      ),
    ),
  );

  // ------------------------------------------------------------ las pantallas

  Widget _welcome() {
    final next = widget.next;
    return next == null ? _welcomeFirst() : _welcomeNext(next);
  }

  /// La bienvenida del pueblo siguiente: lo que se ganó, y con qué.
  ///
  /// Dice el número que importa —las piezas que lo abrieron— y el nombre de lo
  /// que las puso, porque lo que se celebra no es la puerta sino lo que la
  /// abrió. Y la salida está a la vista: un pueblo nuevo se funda cuando hay
  /// ganas, no porque la app lo ofreció.
  Widget _welcomeNext(NextTown next) {
    final uno = next.towns.length == 1;
    final primero = next.towns.first;
    return _Step(
      over: tr('El valle se abre', 'The valley opens'),
      title: tr(
        'Te ganaste tu ${next.ordinalWord} pueblo.',
        'You earned your ${next.ordinalWord} town.',
      ),
      lines: [
        uno
            ? tr(
                '«${primero.name}» lleva ${primero.pieces} '
                    '${primero.pieces == 1 ? 'pieza' : 'piezas'} y ya se '
                    'sostiene solo. Eso es lo que abrió esta puerta.',
                '"${primero.name}" has ${primero.pieces} '
                    '${primero.pieces == 1 ? 'piece' : 'pieces'} and it '
                    'stands on its own now. That is what opened this door.',
              )
            : tr(
                'Llevás ${next.pieces} piezas entre tus ${next.towns.length} '
                    'pueblos, y se sostienen. Eso es lo que abrió esta puerta.',
                'You have ${next.pieces} pieces across your '
                    '${next.towns.length} towns, and they hold. That is what '
                    'opened this door.',
              ),
        tr(
          'Un pueblo nuevo es un hábito nuevo, y empieza igual que el '
              'primero: de a una pieza.',
          'A new town is a new habit, and it starts just like the first one: '
              'one piece at a time.',
        ),
      ],
      next: tr(
        'Fundar mi ${next.ordinalWord} pueblo',
        'Found my ${next.ordinalWord} town',
      ),
      onNext: () => _go(1),
      skip: tr('Ahora no', 'Not now'),
      onSkip: widget.onCancel,
    );
  }

  Widget _welcomeFirst() => _Step(
    title: tr('Esto es un valle vacío.', 'This is an empty valley.'),
    lines: [
      tr(
        'Cada vez que cumplas, vas a poner una pieza. Las piezas levantan un '
            'pueblo, y el pueblo es lo que llevás hecho.',
        'Every time you keep your habit, you place a piece. The pieces raise '
            'a town, and the town is what you have done.',
      ),
      tr('Empecemos por uno.', "Let's start with one."),
    ],
    next: tr('Fundar mi pueblo', 'Found my town'),
    onNext: () => _go(1),
  );

  Widget _askName() => _Step(
    // La marca arriba y grande, como en la hoja del hábito: es la cara del
    // pueblo, y se elige mirándola, no adivinándola en un botón de veinte
    // píxeles.
    top: _BigMark(symbol: _symbol),
    over: tr('Tu hábito', 'Your habit'),
    title: tr(
      '¿Qué hábito querés desarrollar?',
      'What habit do you want to build?',
    ),
    lines: const [],
    next: tr('Siguiente', 'Next'),
    onNext: _name.text.trim().isEmpty ? null : () => _go(2),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Field(
          controller: _name,
          hint: tr('Leer, correr, no fumar…', 'Reading, running, not smoking…'),
          big: true,
          max: 24,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 18),
        _Marks(
          chosen: _symbol,
          onPick: (m) {
            Sensory.instance.tick();
            setState(() => _symbol = m);
          },
        ),
      ],
    ),
  );

  /// La comarca: qué clase de pueblo se levanta.
  ///
  /// Se elegía sola —siempre Ribera, la del primer solar— y es una de las
  /// cosas que más cambian cómo se ve el valle. Se dice claro que es sólo eso:
  /// nadie tiene que pensar que una comarca hace el hábito más fácil.
  Widget _askPlace() {
    final ch = TownCharacter.byOrder(_place);
    return _Step(
      over: tr('Tu pueblo', 'Your town'),
      title: tr('¿Qué clase de pueblo?', 'What kind of town?'),
      lines: [
        tr(
          'Es sólo cómo se ve: cambia las casas y los tejados, no cómo '
              'funciona nada.',
          "It's only how it looks: it changes the houses and the roofs, not "
              'how anything works.',
        ),
      ],
      next: tr('Siguiente', 'Next'),
      onNext: () => _go(3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Places(
            chosen: _place,
            onPick: (o) {
              Sensory.instance.tick();
              setState(() => _place = o);
            },
          ),
          const SizedBox(height: 16),
          // El mismo pueblo de cien piezas, levantado en la comarca elegida:
          // se elige mirando cómo queda, no imaginándolo por la descripción.
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: CustomPaint(
                painter: TownPortrait(
                  place: ch,
                  palette: Palette.forMoment(11),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // El nombre se revela acá, grande, con lo que es y para qué pega:
          // los botones son sólo el sello, y lo que dice cada uno se lee al
          // tocarlo.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Column(
              key: ValueKey(ch.order),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ch.region,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: _Ink.serif,
                    fontSize: 28,
                    height: 1.1,
                    color: _Ink.gold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ch.blurb,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: _Ink.soft(0.82),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ch.suits,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: _Ink.soft(0.60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _askWhy() => _Step(
    over: tr('El motivo', 'The reason'),
    title: tr('¿Para qué querés ese hábito?', 'Why do you want this habit?'),
    lines: [
      tr(
        'Para que tengas claro por qué lo mantenés.',
        "So it's clear to you why you keep it.",
      ),
    ],
    next: tr('Siguiente', 'Next'),
    skip: tr('Ahora no', 'Not now'),
    onSkip: () => _go(4),
    onNext: _why.text.trim().isEmpty ? null : () => _go(4),
    child: _Field(
      controller: _why,
      hint: tr('para dormir mejor', 'to sleep better'),
      max: 60,
      onChanged: () => setState(() {}),
    ),
  );

  /// En quién te convierte.
  ///
  /// Parece la misma pregunta que la anterior y es la contraria. «Para qué lo
  /// querés» mira hacia adelante, a una cosa que todavía no pasó; esto mira a
  /// quién sos hoy si lo hacés. La diferencia importa porque un para qué se
  /// cumple —se duerme mejor, se corre la carrera— y el día que se cumple el
  /// hábito se queda sin motivo. Esto no se cumple nunca: se es o no se es, y
  /// cada pieza es un voto.
  ///
  /// Se escribe sin el sujeto, y se dice cómo va a quedar, porque lo que el
  /// pueblo hace con esta línea es ponérsela él: al final es el pueblo el que
  /// dice de quién es.
  Widget _askWho() => _Step(
    over: tr('Quién sos', 'Who you are'),
    title: tr(
      '¿En quién te convierte tener ese hábito?',
      'Who does this habit turn you into?',
    ),
    lines: [
      tr(
        'Qué buscás ser una vez que consigas el hábito: ¿alguien sabio? '
            '¿Alguien sano? ¿Alguien más inteligente?',
        'What you want to be once the habit is yours: someone wise? '
            'Someone healthy? Someone sharper?',
      ),
    ],
    next: _name.text.trim().isEmpty
        ? tr('Fundar el pueblo', 'Found the town')
        : tr('Fundar ${_name.text.trim()}', 'Found ${_name.text.trim()}'),
    skip: tr('Ahora no', 'Not now'),
    onSkip: _found,
    onNext: _identity.text.trim().isEmpty ? null : _found,
    child: _Field(
      controller: _identity,
      // El «alguien» va escrito delante y no se borra: así se ve que lo que
      // falta es el resto de la frase —sabio, que lee todos los días, que
      // puede con todo— y no una frase entera.
      prefix: identityPrefix,
      hint: tr('que lee todos los días', 'who reads every day'),
      max: 60,
      onChanged: () => setState(() {}),
    ),
  );
}

// ----------------------------------------------------------------- el valle

/// Dónde mira la cámara en cada pregunta: cada vez un poco más cerca del claro
/// y un poco más de lado, hasta la toma en la que el pueblo arranca.
class _Pose {
  const _Pose(this.yaw, this.pitch, this.distance, this.focusY);

  final double yaw, pitch, distance, focusY;

  static const stages = [
    _Pose(0.22, 0.020, 66, 3.4),
    _Pose(0.32, 0.032, 58, 3.1),
    _Pose(0.40, 0.043, 50, 2.8),
    _Pose(0.47, 0.055, 43, 2.5),
    _Pose(0.54, 0.070, 37, 2.2),
  ];

  static const handoff = _Pose(
    HandoffShot.yaw,
    HandoffShot.pitch,
    HandoffShot.distance,
    HandoffShot.focusY,
  );

  static _Pose lerp(_Pose a, _Pose b, double t) => _Pose(
    a.yaw + (b.yaw - a.yaw) * t,
    a.pitch + (b.pitch - a.pitch) * t,
    a.distance + (b.distance - a.distance) * t,
    a.focusY + (b.focusY - a.focusY) * t,
  );
}

/// El valle vacío, pintado por el mismo pintor que el pueblo y con su propio
/// reloj.
class _Valley extends StatefulWidget {
  const _Valley({required this.stage, required this.leaving});

  final int stage;
  final bool leaving;

  @override
  State<_Valley> createState() => _ValleyState();
}

class _ValleyState extends State<_Valley> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;

  final _cam = OrbitCamera()..wallLength = 60;
  final _hits = TouchMap();
  final _fx = EffectSystem();

  /// El tramo de cámara en curso: de dónde sale, adónde va, y por dónde va.
  _Pose _from = _Pose.stages.first;
  _Pose _to = _Pose.stages.first;
  double _t = 1;
  double _span = 1.6;

  /// Cuánto se mece la cámara sola. Se apaga al bajar al pueblo, porque la
  /// toma de llegada tiene que ser exacta.
  double _sway = 1;

  /// Lo que corren las motas: se aceleran al fundar.
  double _rush = 0;

  /// El pueblo del claro, que todavía no existe. Nada de él se pinta; está
  /// para que el pintor tenga dónde apoyar el valle.
  static final _empty = TownEntry(
    layout: TownLayout(0, TownCharacter.all.first, seed: 1),
    name: '',
    symbol: habitSymbols.first,
    placed: 0,
    founded: false,
  );

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(_Valley old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) {
      _aim(_Pose.handoff, FirstRun.leaving.inMilliseconds / 1000 * 0.96);
    } else if (widget.stage != old.stage && !widget.leaving) {
      _aim(_Pose.stages[widget.stage.clamp(0, _Pose.stages.length - 1)], 1.6);
    }
  }

  void _aim(_Pose to, double seconds) {
    _from = _pose;
    _to = to;
    _t = 0;
    _span = seconds;
  }

  _Pose get _pose =>
      _Pose.lerp(_from, _to, Curves.easeInOutCubic.transform(_t));

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _time += dt;
    if (_t < 1) _t = math.min(1, _t + dt / _span);
    if (widget.leaving) {
      _sway = math.max(0, _sway - dt / 0.9);
      _rush = math.min(1, _rush + dt / 0.6);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = Appearance.instance;
    final hora = a.hourNow;
    final pal = Palette.forMoment(hora, season: a.season);
    final pose = _pose;
    // Un vaivén lento, de lado a lado y un poco de altura: el valle respira.
    final vaiven = math.sin(_time * 0.22) * 0.035 * _sway;
    final sube = (0.5 + 0.5 * math.sin(_time * 0.17 + 1.3)) * 0.008 * _sway;
    _cam
      ..travel = 0
      ..focusZ = 0
      ..yaw = pose.yaw + vaiven
      ..pitch = pose.pitch + sube
      ..distance = pose.distance
      ..focusY = pose.focusY;
    final scene = TownScene(
      placed: 0,
      palette: pal,
      camera: _cam,
      time: _time,
      hourOfDay: hora,
      effects: _fx,
      towns: [_empty],
      active: 0,
      labels: false,
      folk: false,
      ghost: false,
    );
    final noche = 1 - clampD(pal.daylight * 1.6, 0, 1);
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: TownPainter(scene, _hits),
          isComplex: true,
          willChange: true,
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _Motes(time: _time, night: noche, rush: _rush),
          ),
        ),
      ],
    );
  }
}

/// Lo que flota en el aire: polen de día, luciérnagas de noche.
///
/// Poca cosa y lenta, a propósito: tiene que notarse que el valle está vivo
/// sin que haya nada que mirar en lugar de la pregunta. Al fundar se aceleran
/// hacia arriba, que es lo único de la bajada que no hace la cámara.
class _Motes extends CustomPainter {
  _Motes({required this.time, required this.night, required this.rush});

  final double time;

  /// De cero (mediodía) a uno (noche cerrada).
  final double night;

  /// De cero a uno, lo que se aceleran al fundar.
  final double rush;

  static const int _count = 30;
  static final List<List<double>> _seeds = () {
    final r = math.Random(7);
    return [
      for (var i = 0; i < _count; i++)
        [for (var k = 0; k < 5; k++) r.nextDouble()],
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final dia = const Color(0xFFFFF6E2);
    final luz = const Color(0xFFF4E7A1);
    final c = Color.lerp(dia, luz, night)!;
    final paint = Paint();
    for (final s in _seeds) {
      final speed = (0.012 + s[1] * 0.02) * (1 + rush * 5);
      final y = (1.05 - ((time * speed + s[2]) % 1.1)) * size.height;
      final x =
          (s[0] + math.sin(time * (0.2 + s[3] * 0.3) + s[4] * 6) * 0.03) *
          size.width;
      final tw = 0.5 + 0.5 * math.sin(time * (0.8 + s[3] * 1.4) + s[4] * 9);
      final r = 1.1 + s[3] * 1.6 + night * 0.8;
      final alpha =
          (0.08 + 0.16 * tw) * (1 - night) + (0.25 + 0.65 * tw * tw) * night;
      if (night > 0.3) {
        paint
          ..color = c.withValues(alpha: alpha * 0.28 * night)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(Offset(x, y), r * 3.2, paint);
      }
      paint
        ..color = c.withValues(alpha: alpha)
        ..maskFilter = null;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_Motes old) =>
      old.time != time || old.night != night || old.rush != rush;
}

// ------------------------------------------------------------------ la marca

/// El nombre de la app sobre el cielo de la bienvenida.
/// Lo de arriba en la bienvenida del pueblo siguiente: los pueblos que ya
/// hay, uno al lado del otro, y el hueco del que viene, encendiéndose.
///
/// Entran de a uno, y el hueco nuevo al final, con un pulso que no se apaga:
/// es lo que se ganó, y tiene que verse esperando.
class _Milestone extends StatefulWidget {
  const _Milestone({required this.next});

  final NextTown next;

  @override
  State<_Milestone> createState() => _MilestoneState();
}

class _MilestoneState extends State<_Milestone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    _t.forward().whenComplete(() {
      if (mounted) _t.repeat(min: 0.75, max: 1.0, reverse: true);
    });
    // El sonido de los hitos: esto es uno.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Sensory.instance.milestone();
    });
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  static const _sombra = [Shadow(color: Color(0x73000000), blurRadius: 22)];

  @override
  Widget build(BuildContext context) {
    final towns = widget.next.towns;
    final n = towns.length + 1;
    return AnimatedBuilder(
      animation: _t,
      builder: (_, _) {
        final v = _t.value;
        // Cada pueblo entra en su tramo de los primeros dos tercios.
        double entra(int i) =>
            Curves.easeOutBack.transform(clampD((v * 1.5 - i * 0.18), 0, 1));
        final nuevo = Curves.easeOutCubic.transform(
          clampD((v - 0.55) / 0.3, 0, 1),
        );
        final pulso = v > 0.75 ? (v - 0.75) / 0.25 : 0.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < towns.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Transform.scale(
                    scale: entra(i),
                    child: _ring(
                      HabitSigil(
                        symbol: towns[i].symbol,
                        color: _Ink.cream,
                        size: 24,
                      ),
                      borde: _Ink.cream.withValues(alpha: 0.45),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Opacity(
                  opacity: nuevo,
                  child: Transform.scale(
                    scale: 0.8 + 0.2 * nuevo + 0.06 * pulso,
                    child: _ring(
                      const Icon(Icons.add, color: _Ink.gold, size: 26),
                      borde: _Ink.gold,
                      halo: 0.35 + 0.4 * pulso,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Opacity(
              opacity: nuevo,
              child: Text(
                tr('PUEBLO ${_roman(n)}', 'TOWN ${_roman(n)}'),
                style: const TextStyle(
                  fontFamily: _Ink.serif,
                  fontSize: 40,
                  height: 1.0,
                  letterSpacing: 2,
                  color: _Ink.cream,
                  shadows: _sombra,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _ring(Widget child, {required Color borde, double halo = 0}) =>
      Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _Ink.glass.withValues(alpha: 0.55),
          border: Border.all(color: borde, width: 1.5),
          boxShadow: halo > 0
              ? [
                  BoxShadow(
                    color: _Ink.gold.withValues(alpha: halo),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: child,
      );

  static String _roman(int n) => const [
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
  ][(n - 1).clamp(0, 7)];
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  static const _sombra = [
    Shadow(color: Color(0x73000000), blurRadius: 22),
    Shadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Towny',
        style: TextStyle(
          fontFamily: _Ink.serif,
          fontSize: 58,
          height: 1.0,
          color: _Ink.cream,
          letterSpacing: 0.5,
          shadows: _sombra,
        ),
      ),
      SizedBox(height: 10),
      Text(
        tr('UN PUEBLO PARA CADA HÁBITO', 'A TOWN FOR EVERY HABIT'),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 3.2,
          fontWeight: FontWeight.w600,
          color: _Ink.cream,
          shadows: _sombra,
        ),
      ),
    ],
  );
}

/// El nombre del pueblo mientras la cámara baja: entra, se queda un momento y
/// se va antes de que llegue el pueblo, que trae su propio cartel.
class _FoundingName extends StatelessWidget {
  const _FoundingName({required this.name, required this.t});

  final String name;
  final double t;

  @override
  Widget build(BuildContext context) {
    final entra = Curves.easeOutCubic.transform(clampD((t - 0.12) / 0.3, 0, 1));
    final sale = Curves.easeInCubic.transform(clampD((t - 0.72) / 0.26, 0, 1));
    final a = entra * (1 - sale);
    const sombra = [Shadow(color: Color(0x80000000), blurRadius: 24)];
    return Opacity(
      opacity: a,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - entra) - 16 * sale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('SE FUNDA', 'FOUNDING'),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 3.4,
                fontWeight: FontWeight.w600,
                color: _Ink.gold.withValues(alpha: 0.95),
                shadows: sombra,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _Ink.serif,
                fontSize: 46,
                height: 1.05,
                color: _Ink.cream,
                shadows: sombra,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- la tarjeta

/// El vidrio donde van las preguntas, con el recorrido arriba.
class _Card extends StatelessWidget {
  const _Card({required this.step, required this.child});

  final int step;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(30),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _Ink.glass.withValues(alpha: 0.54),
              _Ink.glass.withValues(alpha: 0.70),
            ],
          ),
          border: Border.all(color: _Ink.cream.withValues(alpha: 0.10)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Progress(at: step),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

/// Por dónde va: cuatro tramos que se llenan de dorado. En la bienvenida no se
/// ve — ahí todavía no empezó nada — pero ocupa su sitio, para que la
/// tarjeta no dé un salto al empezar.
class _Progress extends StatelessWidget {
  const _Progress({required this.at});

  final int at;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 400),
    opacity: at == 0 ? 0 : 1,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          for (var i = 1; i <= 4; i++) ...[
            if (i > 1) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _Ink.cream.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  widthFactor: i <= at ? 1 : 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _Ink.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// El molde de cada pregunta: el rótulo, el título en serif, lo que haga
/// falta decir, la respuesta y la salida. Cada cosa entra un poco después de
/// la anterior.
class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.lines,
    required this.next,
    required this.onNext,
    this.top,
    this.over,
    this.child,
    this.skip,
    this.onSkip,
  });

  /// Lo que va arriba de todo, centrado: la marca, en la pregunta del nombre.
  final Widget? top;
  final String? over;
  final String title;
  final List<String> lines;
  final String next;

  /// Nulo apaga el botón: no se puede seguir sin contestar.
  final VoidCallback? onNext;
  final Widget? child;
  final String? skip;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    var orden = 0;
    Widget rise(Widget w) => _Rise(order: orden++, child: w);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (top != null) ...[
          rise(Center(child: top!)),
          const SizedBox(height: 14),
        ],
        if (over != null) ...[
          rise(
            Text(
              over!.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w600,
                color: _Ink.gold,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        rise(
          Text(
            title,
            style: const TextStyle(
              fontFamily: _Ink.serif,
              fontSize: 31,
              height: 1.12,
              color: _Ink.cream,
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final l in lines) ...[
          rise(
            Text(
              l,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: _Ink.soft(0.70),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (child != null) ...[const SizedBox(height: 16), rise(child!)],
        const SizedBox(height: 22),
        rise(_Go(text: next, onTap: onNext)),
        SizedBox(
          height: skip == null ? 10 : 44,
          child: skip == null
              ? null
              : TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(foregroundColor: _Ink.soft(0.62)),
                  child: Text(
                    skip!,
                    style: TextStyle(fontSize: 13.5, color: _Ink.soft(0.62)),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Entrar subiendo un poco, tarde según el turno.
class _Rise extends StatelessWidget {
  const _Rise({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final desde = math.min(0.55, order * 0.11);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + order * 60),
      curve: Interval(desde, 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

/// El botón de seguir. Dorado cuando se puede, y apagado de verdad —no
/// escondido— cuando todavía no hay nada que contestar: que se vea dónde está
/// la salida antes de poder usarla es la mitad de saber cuánto falta.
class _Go extends StatefulWidget {
  const _Go({required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  State<_Go> createState() => _GoState();
}

class _GoState extends State<_Go> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: on ? (_) => setState(() => _down = false) : null,
      onTapCancel: on ? () => setState(() => _down = false) : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _down ? 0.97 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: on
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_Ink.gold, _Ink.goldDeep],
                  )
                : null,
            color: on ? null : _Ink.cream.withValues(alpha: 0.07),
            border: Border.all(
              color: on
                  ? const Color(0x33FFFFFF)
                  : _Ink.cream.withValues(alpha: 0.10),
            ),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: _Ink.gold.withValues(alpha: 0.18),
                      blurRadius: 26,
                    ),
                  ]
                : const [],
          ),
          child: Text(
            widget.text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: on ? _Ink.onGold : _Ink.soft(0.34),
              fontSize: 12.5,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Donde se escribe: un vidrio un punto más claro que la tarjeta, que se
/// enciende en dorado mientras se escribe.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.max,
    required this.onChanged,
    this.big = false,
    this.prefix,
  });

  final TextEditingController controller;
  final String hint;

  /// Una palabra fija delante de lo que se escribe, que no se puede borrar.
  final String? prefix;
  final int max;
  final VoidCallback onChanged;
  final bool big;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      autofocus: true,
      textAlign: prefix == null ? TextAlign.center : TextAlign.start,
      textCapitalization: TextCapitalization.sentences,
      maxLength: max,
      cursorColor: _Ink.gold,
      style: TextStyle(
        fontFamily: big ? _Ink.serif : null,
        fontSize: big ? 26 : 17,
        height: 1.3,
        color: _Ink.cream,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: big ? _Ink.serif : null,
          fontSize: big ? 24 : 16,
          color: _Ink.soft(0.32),
        ),
        counterText: '',
        // Como icono y no como `prefixText`: el texto de prefijo sólo se ve con
        // el campo enfocado o escrito, y esto tiene que leerse antes.
        prefixIcon: prefix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 16, right: 6),
                child: Text(
                  prefix!,
                  style: TextStyle(
                    fontSize: big ? 26 : 17,
                    height: 1.3,
                    color: _Ink.gold,
                  ),
                ),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: _Ink.cream.withValues(alpha: 0.06),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: big ? 14 : 16,
        ),
        enabledBorder: borde(_Ink.cream.withValues(alpha: 0.12)),
        focusedBorder: borde(_Ink.gold.withValues(alpha: 0.85), 1.4),
        border: borde(_Ink.cream.withValues(alpha: 0.12)),
      ),
    );
  }
}

/// La marca elegida, grande y arriba: la cara del pueblo.
class _BigMark extends StatelessWidget {
  const _BigMark({required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context) => Container(
    width: 92,
    height: 92,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _Ink.gold.withValues(alpha: 0.12),
      border: Border.all(color: _Ink.gold.withValues(alpha: 0.55), width: 1.4),
    ),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (c, a) => ScaleTransition(
        scale: Tween(begin: 0.7, end: 1.0).animate(a),
        child: FadeTransition(opacity: a, child: c),
      ),
      child: HabitSigil(
        key: ValueKey(symbol),
        symbol: symbol,
        color: _Ink.gold,
        size: 50,
      ),
    ),
  );
}

/// Todas las marcas, en dos filas que se deslizan de lado.
///
/// Eran doce fijas, y las otras cincuenta y tantas sólo se podían elegir
/// después, editando. Dos filas y no una rejilla entera: la tarjeta tiene que
/// dejar ver el valle, y el teclado ya se come media pantalla.
class _Marks extends StatelessWidget {
  const _Marks({required this.chosen, required this.onPick});

  final String chosen;
  final void Function(String) onPick;

  // Cuarenta y ocho de paso a propósito: en un teléfono de 390 entran seis
  // columnas y media, y la media que asoma es lo que dice que hay más.
  static const double _tile = 40, _gap = 8;
  static const int _rows = 2;

  @override
  Widget build(BuildContext context) {
    final columnas = (habitSymbols.length + _rows - 1) ~/ _rows;
    return SizedBox(
      height: _rows * _tile + (_rows - 1) * _gap,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: columnas,
        itemBuilder: (_, col) => Padding(
          padding: EdgeInsets.only(right: col == columnas - 1 ? 0 : _gap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < _rows; row++)
                Padding(
                  padding: EdgeInsets.only(top: row == 0 ? 0 : _gap),
                  child: _tileAt(col * _rows + row),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tileAt(int at) {
    if (at >= habitSymbols.length) {
      return const SizedBox(width: _tile, height: _tile);
    }
    final m = habitSymbols[at];
    final elegida = m == chosen;
    return GestureDetector(
      onTap: () => onPick(m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: _tile,
        height: _tile,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: elegida
              ? _Ink.gold.withValues(alpha: 0.20)
              : _Ink.cream.withValues(alpha: 0.06),
          border: Border.all(
            color: elegida ? _Ink.gold : _Ink.cream.withValues(alpha: 0.12),
            width: elegida ? 1.4 : 1,
          ),
        ),
        child: HabitSigil(
          symbol: m,
          color: elegida ? _Ink.gold : _Ink.soft(0.80),
          size: 20,
        ),
      ),
    );
  }
}

/// Las comarcas, cada una con su sello y nada más, en dos filas parejas.
///
/// Filas parejas y no un `Wrap` centrado: con los nombres dentro, seis botones
/// de anchos distintos caían en tres, dos y uno, que se leía como un embudo.
/// Dos filas de la mitad cada una —tres y tres con seis, cuatro y cuatro con
/// ocho—, y los sellos se achican si no entran, en vez de partir otra fila.
class _Places extends StatelessWidget {
  const _Places({required this.chosen, required this.onPick});

  final int chosen;
  final void Function(int order) onPick;

  static const double _gap = 14, _max = 64;

  @override
  Widget build(BuildContext context) {
    final todas = TownCharacter.all;
    final porFila = (todas.length + 1) ~/ 2;
    return LayoutBuilder(
      builder: (_, box) {
        final lado = math.min(
          _max,
          (box.maxWidth - _gap * (porFila - 1)) / porFila,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < todas.length; i += porFila) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final c in todas.skip(i).take(porFila)) ...[
                    if (c != todas[i]) const SizedBox(width: _gap),
                    _sello(c, lado),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _sello(TownCharacter c, double lado) {
    final elegida = c.order == chosen;
    return Semantics(
      button: true,
      selected: elegida,
      label: c.region,
      child: GestureDetector(
        onTap: () => onPick(c.order),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: lado,
          height: lado,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: elegida
                ? _Ink.gold.withValues(alpha: 0.20)
                : _Ink.cream.withValues(alpha: 0.06),
            border: Border.all(
              color: elegida ? _Ink.gold : _Ink.cream.withValues(alpha: 0.12),
              width: elegida ? 1.6 : 1,
            ),
          ),
          child: HabitSigil(
            symbol: c.symbol,
            color: elegida ? _Ink.gold : _Ink.soft(0.80),
            size: lado * 0.44,
          ),
        ),
      ),
    );
  }
}
