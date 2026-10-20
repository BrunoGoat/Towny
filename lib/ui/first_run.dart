import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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
import '../sync/account.dart';
import 'habit_sigil.dart';

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
  const FirstRun({
    super.key,
    required this.onDone,
    this.next,
    this.onCancel,
    this.account,
    this.onSignedIn,
    this.accountOnly = false,
  });

  /// Lo que hay que hacer apenas se entra, antes de seguir: ponerse de acuerdo
  /// con la nube. Mientras tanto el botón dice que está entrando. Si trae un
  /// valle que ya existía, quien lo pidió se encarga de saltar las preguntas.
  final Future<void> Function()? onSignedIn;

  /// Sólo la cuenta, sin las preguntas: para entrar desde ajustes con el valle
  /// ya fundado. Al entrar, o al seguir sin cuenta, se llama a [onCancel].
  final bool accountOnly;

  /// Con qué se entra a la cuenta, antes de la bienvenida. Nulo, no se pide:
  /// el pueblo siguiente ya está dentro, y los tests van directo al valle.
  ///
  /// **Antes de todo y no al final**, porque es lo único que puede traer un
  /// valle que ya existe: quien cambió de teléfono no tiene que contestar las
  /// preguntas de un pueblo que ya fundó.
  final Account? account;

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

  static Color soft([double a = 0.72]) => cream.withValues(alpha: a);

  static const serif = 'EBGaramond';

  /// La sombra de todo lo que se escribe sobre el valle. Sin caja detrás, lo
  /// que hace que se lea sobre el cielo o el prado es esto.
  static const shadow = [
    Shadow(color: Color(0xA6000000), blurRadius: 14),
    Shadow(color: Color(0x73000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// El fondo de los botones redondos: un poco de noche, para que el sello se
  /// lea sobre lo que haya detrás.
  static const disc = Color(0x40000000);

  /// Lo que salió mal: cálido y no rojo, que no es una alarma.
  static const warn = Color(0xFFF2A88E);
}

/// Por dónde va la entrada a la cuenta, antes de la bienvenida.
enum _Entry { email, code }

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

  /// En qué parte de la entrada a la cuenta, o nulo si ya se entró (o no hay
  /// que entrar). Mientras no es nulo, el valle sigue en la bienvenida.
  late _Entry? _entry = widget.account != null && widget.next == null
      ? _Entry.email
      : null;
  final _email = TextEditingController();
  final _code = TextEditingController();

  /// Esperando a la cuenta: el botón se apaga para no pedir dos veces.
  bool _busy = false;

  /// Lo que salió mal en el último intento, dicho debajo del campo.
  String? _problem;

  /// Mirando el pueblo de muestra de la comarca con la interfaz escondida.
  bool _exploring = false;

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
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Si el último paso fue hacia atrás: la animación va al revés.
  bool _backward = false;

  /// Lo que el dedo arrastró la pregunta desde el borde izquierdo, en el
  /// gesto de volver. La pregunta lo sigue, y al soltar vuelve a su sitio si
  /// no pasó de un tercio de la pantalla.
  double _swipe = 0;

  /// Si desde aquí se puede volver: lo que dice si el gesto hace algo.
  bool get _canBack =>
      !_leaving &&
      (_exploring ||
          _step > 0 ||
          _entry == _Entry.code ||
          widget.onCancel != null);

  /// Lo que hay en la tarjeta ahora: la entrada a la cuenta o la pregunta.
  Object get _stage => _entry ?? _step;

  void _go(int to) {
    Sensory.instance.tick();
    setState(() {
      _backward = to < _step;
      _step = to;
      _exploring = false;
    });
  }

  /// Lo que hace «atrás» —el botón del teléfono, el del navegador, el gesto,
  /// o la flecha de arriba—: dejar de recorrer el pueblo de muestra si se lo
  /// está recorriendo, volver a la pregunta anterior si la hay, y en la
  /// bienvenida del pueblo siguiente volver al valle, que es dejar la
  /// fundación para después. La primera vez, en la bienvenida, no hay adónde
  /// volver.
  void _back() {
    if (_leaving) return;
    if (_exploring) {
      _explore(false);
    } else if (_entry == _Entry.code) {
      FocusScope.of(context).unfocus();
      _enter(_Entry.email, backward: true);
    } else if (_entry != null) {
      if (widget.accountOnly) widget.onCancel?.call();
    } else if (_step > 0) {
      FocusScope.of(context).unfocus();
      _go(_step - 1);
    } else {
      widget.onCancel?.call();
    }
  }

  void _explore(bool on) {
    Sensory.instance.tick();
    if (on) FocusScope.of(context).unfocus();
    setState(() => _exploring = on);
  }

  // ------------------------------------------------------------- la cuenta

  bool get _emailOk =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  void _enter(_Entry? to, {bool backward = false}) {
    Sensory.instance.tick();
    setState(() {
      _backward = backward;
      _entry = to;
      _problem = null;
    });
  }

  /// Ya está: con cuenta o sin ella. Desde ajustes se vuelve al valle; la
  /// primera vez siguen las preguntas.
  void _entered() {
    if (widget.accountOnly) {
      Sensory.instance.tick();
      widget.onCancel?.call();
    } else {
      _enter(null);
    }
  }

  Future<void> _sendCode() async {
    if (_busy || !_emailOk) return;
    Sensory.instance.tick();
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await widget.account!.sendCode(_email.text.trim());
      if (!mounted) return;
      _code.clear();
      _busy = false;
      _enter(_Entry.code);
    } on TooSoon {
      // El de hace un momento sigue sirviendo: se va a escribirlo.
      if (!mounted) return;
      _code.clear();
      _busy = false;
      _enter(_Entry.code);
      setState(
        () => _problem = tr(
          'Ya te mandamos uno hace un momento: usá ese. Si no llegó, mirá en '
              'Spam o esperá un minuto y pedí otro.',
          "We sent you one a moment ago: use that one. If it didn't arrive, "
              'check Spam or wait a minute and ask for another.',
        ),
      );
    } on AccountRefused catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = tr(
          'No se pudo mandar el código. La nube dice: «${e.reason}»',
          "The code couldn't be sent. The cloud says: \"${e.reason}\"",
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = tr(
          'No se pudo mandar el código. Revisá la conexión y probá otra vez.',
          "The code couldn't be sent. Check your connection and try again.",
        );
      });
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (_busy || code.length != 6) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    String? problema;
    try {
      final ok = await widget.account!.verify(_email.text.trim(), code);
      if (ok) {
        if (!mounted) return;
        FocusScope.of(context).unfocus();
        // Todavía «entrando»: lo que haya en la nube baja antes de seguir,
        // y si había un valle, ya no hacen falta las preguntas.
        await widget.onSignedIn?.call();
        if (!mounted) return;
        _busy = false;
        _entered();
        return;
      }
      problema = tr(
        'Ese código no es. Revisalo y probá otra vez.',
        "That's not the code. Check it and try again.",
      );
    } catch (_) {
      problema = tr(
        'No se pudo comprobar el código. Revisá la conexión.',
        "The code couldn't be checked. Check your connection.",
      );
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = problema;
    });
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF9FB6D8),
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // El valle, vivo. Va en su propio widget con su propio reloj para
            // que pintar sesenta cuadros por segundo no reconstruya los campos
            // de texto.
            _Valley(
              stage: _step,
              leaving: _leaving,
              name: _name.text,
              symbol: _symbol,
              place: _place,
              exploring: _exploring,
              onExplore: () => _explore(true),
            ),
            // Dos veladuras: arriba, para que la marca se lea sobre un cielo de
            // mediodía; abajo, para que la tarjeta se apoye en algo.
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 900),
                opacity: _leaving || _exploring ? 0 : 1,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33000000),
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0x8C0B0906),
                        Color(0xC70B0906),
                      ],
                      stops: [0.0, 0.26, 0.40, 0.70, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // La vuelta atrás, a la vista: no todo el mundo sabe que el botón
            // del teléfono o del navegador también vuelve.
            if ((_step > 0 || _entry == _Entry.code) &&
                !_leaving &&
                !_exploring)
              Positioned(
                left: 6,
                top: mq.padding.top + 6,
                child: IconButton(
                  onPressed: _back,
                  tooltip: tr('Volver', 'Back'),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: _Ink.cream,
                    shadows: _Ink.shadow,
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
                child: Transform.translate(
                  offset: Offset(_swipe, 0),
                  child: Opacity(
                    opacity: (1 - _swipe / (mq.size.width * 0.8)).clamp(
                      0.0,
                      1.0,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 560),
                        curve: Curves.easeInCubic,
                        offset: _leaving ? const Offset(0, 0.35) : Offset.zero,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 420),
                          opacity: _leaving || _exploring ? 0 : 1,
                          child: IgnorePointer(
                            ignoring: _exploring,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: 520,
                                  maxHeight: math.max(
                                    240,
                                    mq.size.height -
                                        teclado -
                                        mq.padding.top -
                                        40,
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
                ),
              ),
            ),
            // El gesto de volver del teléfono: deslizar desde el borde
            // izquierdo hacia la derecha. En la web el navegador no siempre
            // lo da —sin página de antes, el gesto se va del sitio o no hace
            // nada—, así que se atiende aquí, en una franja del borde.
            if (_canBack)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 28,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (d) =>
                      setState(() => _swipe = math.max(0, _swipe + d.delta.dx)),
                  onHorizontalDragEnd: (d) {
                    final lejos =
                        _swipe > mq.size.width / 3 ||
                        (d.primaryVelocity ?? 0) > 700;
                    setState(() => _swipe = 0);
                    if (lejos) _back();
                  },
                  onHorizontalDragCancel: () => setState(() => _swipe = 0),
                ),
              ),
            // Explorando: sólo el nombre de la comarca, cómo se mueve la cámara,
            // y la vuelta.
            if (_exploring)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                builder: (_, v, c) => Opacity(opacity: v, child: c),
                child: _ExploreBar(
                  region: TownCharacter.byOrder(_place).region,
                  onBack: () => _explore(false),
                ),
              ),
          ],
        ),
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
      // Lo contestado **sube y se desvanece**, hacia el claro donde queda
      // escrito, y la pregunta nueva sale de abajo. De lado se leía como
      // pasar páginas de un formulario; hacia arriba se lee como entregar la
      // respuesta.
      //
      // Y hacia atrás, al revés: lo de ahora baja y se va, y la pregunta de
      // antes vuelve desde arriba, de donde se había ido.
      transitionBuilder: (child, a) {
        final entra = child.key == ValueKey(_stage);
        final dy = _backward ? (entra ? -0.22 : 0.08) : (entra ? 0.08 : -0.22);
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: Offset(0, dy), end: Offset.zero).animate(a),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_stage),
        child: switch (_stage) {
          _Entry.email => _signIn(),
          _Entry.code => _signInCode(),
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

  /// Entrar a la cuenta: el correo.
  ///
  /// Se dice para qué antes de pedir nada —que el valle no se pierde— porque
  /// un correo pedido sin motivo, en la primera pantalla de una app, se lee
  /// como una lista de suscripción. Y se puede seguir sin cuenta: la app
  /// entera funciona sin ella, sólo que lo hecho vive en este teléfono.
  ///
  /// Cuando llegue Google, va acá como otra salida debajo de la del correo.
  Widget _signIn() => _Step(
    over: tr('Tu cuenta', 'Your account'),
    title: tr('Guardá tu valle.', 'Keep your valley safe.'),
    lines: [
      tr(
        'Con tu correo, tus pueblos se guardan en la nube y no se pierden '
            'aunque cambies de teléfono.',
        'With your email, your towns are kept in the cloud and are never '
            'lost, even if you change phones.',
      ),
    ],
    next: _busy
        ? tr('Mandando…', 'Sending…')
        : tr('Mandarme el código', 'Send me the code'),
    onNext: _emailOk && !_busy ? _sendCode : null,
    skip: widget.accountOnly
        ? tr('Ahora no', 'Not now')
        : tr('Seguir sin cuenta', 'Continue without an account'),
    onSkip: _busy ? null : _entered,
    child: _Problem(
      problem: _problem,
      child: _Field(
        controller: _email,
        hint: tr('tu@correo.com', 'you@email.com'),
        max: 120,
        kind: _FieldKind.email,
        // Sin teclado de entrada: lo primero que se ve es el valle y lo
        // que dice la tarjeta, no media pantalla de letras.
        autofocus: false,
        onChanged: () => setState(() => _problem = null),
      ),
    ),
  );

  /// Entrar a la cuenta: el código que llegó.
  ///
  /// Con los seis números se comprueba solo, sin tener que tocar nada más.
  Widget _signInCode() => _Step(
    over: tr('Tu cuenta', 'Your account'),
    title: tr('Revisá tu correo.', 'Check your email.'),
    lines: [
      tr(
        'Te mandamos un código de seis números a ${_email.text.trim()}.',
        'We sent a six-digit code to ${_email.text.trim()}.',
      ),
    ],
    next: _busy ? tr('Entrando…', 'Signing in…') : tr('Entrar', 'Sign in'),
    onNext: _code.text.trim().length == 6 && !_busy ? _verify : null,
    skip: tr('Usar otro correo', 'Use another email'),
    onSkip: _busy ? null : _back,
    child: _Problem(
      problem: _problem,
      child: _Field(
        controller: _code,
        hint: '000000',
        max: 6,
        big: true,
        kind: _FieldKind.code,
        onChanged: () {
          setState(() => _problem = null);
          if (_code.text.trim().length == 6) _verify();
        },
      ),
    ),
  );

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
    // La marca y el nombre se eligen aquí, y al confirmar suben al claro y
    // quedan puestos en un cartel: ver [_ClearingSign].
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
          hint: tr('Leer, correr, no fumar…', 'Reading, running, yoga…'),
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
      // Sin explicación: el pueblo de muestra está arriba, y lo que es se ve.
      lines: const [],
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
                    shadows: _Ink.shadow,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ch.blurb,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: _Ink.soft(0.90),
                    shadows: _Ink.shadow,
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
                    color: _Ink.soft(0.74),
                    shadows: _Ink.shadow,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: () => _explore(true),
              style: TextButton.styleFrom(foregroundColor: _Ink.gold),
              icon: const Icon(
                Icons.threesixty,
                size: 18,
                shadows: _Ink.shadow,
              ),
              label: Text(
                tr('Recorrer este pueblo', 'Walk around this town'),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  shadows: _Ink.shadow,
                ),
              ),
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

/// Dónde mira la cámara en cada pregunta.
///
/// La bienvenida, desde lejos, con el valle entero y vacío. Después baja al
/// claro, y lo deja **arriba** de la pantalla: abajo van las preguntas, y lo
/// que pasa en el claro —el cartel con el nombre, el pueblo de la comarca— se
/// tiene que ver mientras se contesta. Eso es [lead]: cuánto se adelanta hacia
/// la cámara el punto al que mira, que es lo que sube el claro en la pantalla.
class _Pose {
  const _Pose(
    this.yaw,
    this.pitch,
    this.distance,
    this.focusY, [
    this.lead = 0,
  ]);

  final double yaw, pitch, distance, focusY, lead;

  static const stages = [
    _Pose(0.22, 0.020, 66, 3.4),
    _Pose(0.34, 0.200, 30, 1.2, 12.0),
    _Pose(0.46, 0.420, 54, 0.6, 50.0),
    _Pose(0.54, 0.230, 30, 1.2, 11.5),
    _Pose(0.60, 0.240, 29, 1.4, 11.0),
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
    a.lead + (b.lead - a.lead) * t,
  );
}

/// El valle vacío, pintado por el mismo pintor que el pueblo y con su propio
/// reloj.
class _Valley extends StatefulWidget {
  const _Valley({
    required this.stage,
    required this.leaving,
    required this.name,
    required this.symbol,
    required this.place,
    this.exploring = false,
    this.onExplore,
  });

  /// Tocar el pueblo de muestra: lo mismo que «Recorrer este pueblo».
  final VoidCallback? onExplore;

  final int stage;
  final bool leaving;

  /// Con la interfaz escondida, mirando el pueblo de muestra: el dedo gira la
  /// cámara, la acerca y la mueve. Al volver, la cámara vuelve sola a su toma.
  final bool exploring;

  /// Lo que se va contestando, que es lo que el valle enseña: el nombre y la
  /// marca en un cartel sobre el claro, y la comarca levantada detrás.
  final String name;
  final String symbol;
  final int place;

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

  /// La comarca que enseña ahora el pueblo de muestra, y el cambio a otra:
  /// de cero a uno mientras se cambia, uno quieto. **Un cambio y no un
  /// corte**: el pueblo de antes se desvanece, la cámara toma aire y las
  /// motas se arremolinan, y el nuevo aparece en la mitad del camino. Un
  /// pueblo entero cambiando de golpe en un fotograma era lo único de esta
  /// pantalla que no tenía ceremonia.
  late int _shown = widget.place;
  double _swap = 1;

  /// Cuánto lleva en la pregunta de ahora, y cuándo quedó puesto el cartel.
  double _age = 0;
  double? _settledAt;

  /// Lo que el dedo le movió a la cámara mientras se exploraba: el giro, la
  /// inclinación, lo cerca, y el desplazamiento por el suelo. Vuelve a cero
  /// solo al dejar de explorar. [_explore] es cuánto se está explorando, de
  /// cero a uno, para que entrar y salir sean un planeo y no un corte.
  double _yawOff = 0, _pitchOff = 0, _zoom = 1, _panX = 0, _panZ = 0;

  /// **A dónde va** cada uno de esos, que el dedo mueve; la cámara los sigue
  /// con un planeo, al mismo ritmo que la del valle ([OrbitCamera.step]).
  /// Moviendo la cámara directamente con el dedo, sin planeo, se sentía
  /// quieta y de cartón: se paraba en seco en cuanto se levantaba el dedo.
  double _yawT = 0, _pitchT = 0, _zoomT = 1, _panXT = 0, _panZT = 0;

  /// Toma de recorrer: más cerca, más baja y mirando al pueblo de frente,
  /// como se lo mira en el valle, y no desde la altura de la pregunta.
  static const _walk = _Pose(0.46, 0.30, 30, 1.0);
  double _explore = 0, _lastScale = 1;

  /// Cuánto se ve el pueblo de muestra de la comarca: entra al llegar a esa
  /// pregunta y se va al dejarla, fundiéndose. Y cuánto se ve el cartel.
  double _preview = 0, _sign = 0;

  /// Cuánto se ha ido el cartel arriba de todo, de cero a uno. En la pregunta
  /// de la comarca el claro lo ocupa el pueblo de muestra, y el cartel no se
  /// va: sube y se queda arriba mientras se elige, y al seguir vuelve a bajar
  /// a su sitio sobre el claro.
  double _lift = 0;

  /// El pueblo de muestra de cada comarca, hecho una vez. Trescientas piezas:
  /// un pueblo hecho y derecho, con sus hitos, que es lo que se quiere mirar
  /// para elegir — y explorar, con [_Valley.exploring].
  static final Map<int, TownEntry> _previews = {};

  static TownEntry _previewOf(int place) => _previews[place] ??= TownEntry(
    layout: TownLayout(300, TownCharacter.byOrder(place), seed: 1),
    name: '',
    symbol: habitSymbols.first,
    placed: 300,
  );

  /// El pueblo del claro, que todavía no existe. Nada de él se pinta; está
  /// para que el pintor tenga dónde apoyar el valle.
  ///
  /// Un pelo desplazado del centro a propósito: el pueblo de muestra está en
  /// el mismo claro, y los pueblos levantados se guardan por sitio y comarca.
  /// En el mismo sitio y con la misma comarca, cada fotograma uno echaba al
  /// otro de la caché y se volvían a levantar los dos.
  static final _empty = TownEntry(
    layout: TownLayout(0, TownCharacter.all.first, cz: -0.01, seed: 1),
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
    if (widget.stage != old.stage) _age = 0;
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
    double toward(double v, bool on, double seconds) =>
        on ? math.min(1, v + dt / seconds) : math.max(0, v - dt / seconds);
    _age += dt;
    if (_swap >= 1 && widget.place != _shown) _swap = 0;
    if (_swap < 1) {
      final antes = _swap;
      _swap = math.min(1, _swap + dt / 0.9);
      // A mitad del cambio, con el de antes ya ido, se pone el nuevo: el que
      // esté elegido entonces, aunque se haya tocado otro por el camino.
      if (antes < 0.42 && _swap >= 0.42) _shown = widget.place;
    }
    // El cartel queda puesto al confirmar el nombre, no mientras se escribe:
    // escrito a la vez en el campo y sobre el claro, se leía dos veces.
    final puesto = widget.stage >= 2 && !widget.leaving;
    if (puesto) _settledAt ??= _time;
    // Si se volvió atrás a cambiar el nombre, al confirmarlo otra vez se
    // vuelve a poner con su destello.
    if (!puesto && _sign <= 0) _settledAt = null;
    // Y el pueblo de muestra espera a que el cartel termine de ponerse: los
    // dos a la vez se tapaban el uno al otro.
    _preview = toward(
      _preview,
      widget.stage == 2 && _age > 1.5 && !widget.leaving,
      0.9,
    );
    _explore = toward(_explore, widget.exploring, 0.6);
    if (!widget.exploring) {
      final k = 1 - math.exp(-dt * 3.5);
      _yawT = 0;
      _pitchT = 0;
      _zoomT = 1;
      _panXT = 0;
      _panZT = 0;
      _yawOff -= _yawOff * k;
      _pitchOff -= _pitchOff * k;
      _zoom += (1 - _zoom) * k;
      _panX -= _panX * k;
      _panZ -= _panZ * k;
    } else {
      final k = 1 - math.exp(-dt * 7.5);
      _yawOff += (_yawT - _yawOff) * k;
      _pitchOff += (_pitchT - _pitchOff) * k;
      _zoom += (_zoomT - _zoom) * k;
      _panX += (_panXT - _panX) * k;
      _panZ += (_panZT - _panZ) * k;
    }
    _sign = toward(_sign, puesto, 0.45);
    _lift = toward(_lift, widget.stage == 2 && !widget.leaving, 0.7);
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
    // Un vaivén lento, de lado a lado y un poco de altura: el valle respira.
    final vaiven = math.sin(_time * 0.22) * 0.035 * _sway;
    final sube = (0.5 + 0.5 * math.sin(_time * 0.17 + 1.3)) * 0.008 * _sway;
    final mira = Curves.easeInOutCubic.transform(_explore);
    final base = _Pose.lerp(_pose, _walk, mira);
    final yaw = base.yaw + vaiven * (1 - mira) + _yawOff;
    // Explorando, el pueblo va al centro: ya no hay preguntas que esquivar.
    final lead = base.lead;
    _cam
      ..travel = math.sin(yaw) * lead + _panX
      ..focusZ = math.cos(yaw) * lead + _panZ
      ..yaw = yaw
      ..pitch = clampD(base.pitch + sube + _pitchOff, 0.05, 1.35)
      ..distance =
          base.distance *
          _zoom *
          (1 + 0.05 * math.sin(math.pi * _swap.clamp(0.0, 1.0)))
      ..focusY = base.focusY;
    TownScene scene(TownEntry town) => TownScene(
      placed: town.placed,
      palette: pal,
      camera: _cam,
      time: _time,
      hourOfDay: hora,
      effects: _fx,
      towns: [town],
      active: 0,
      labels: false,
      folk: false,
      ghost: false,
    );
    final noche = 1 - clampD(pal.daylight * 1.6, 0, 1);
    // Durante el cambio de comarca, la muestra se va y vuelve.
    final cambio = _swap >= 1
        ? 1.0
        : _swap < 0.42
        ? 1 - Curves.easeInCubic.transform(_swap / 0.42)
        : Curves.easeOutCubic.transform((_swap - 0.42) / 0.58);
    final vista = Curves.easeInOutCubic.transform(_preview);
    final muestra = vista * cambio;
    return LayoutBuilder(
      builder: (_, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        // En la comarca, tocar el pueblo de muestra es ponerse a recorrerlo.
        onTap: widget.stage == 2 && !widget.exploring && _preview > 0.5
            ? widget.onExplore
            : null,
        onScaleStart: widget.exploring ? (_) => _lastScale = 1 : null,
        onScaleUpdate: widget.exploring ? _onScale : null,
        // Y al soltar sigue un poco, con el impulso que llevaba el dedo.
        onScaleEnd: widget.exploring
            ? (d) => _yawT -= d.velocity.pixelsPerSecond.dx * 0.0062 * 0.18
            : null,
        child: _scene(box, scene, noche, muestra, vista),
      ),
    );
  }

  /// Un dedo gira la cámara alrededor del pueblo; dos la acercan y la mueven.
  void _onScale(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      final f = d.scale / (_lastScale == 0 ? 1 : _lastScale);
      _lastScale = d.scale;
      if (f.isFinite && f > 0) _zoomT = clampD(_zoomT / f, 0.30, 1.8);
      // Lo que se arrastra con dos dedos es el suelo: se mueve con el dedo.
      final yaw = _cam.yaw;
      final k = _cam.distance / 700;
      final dx = d.focalPointDelta.dx * k, dy = d.focalPointDelta.dy * k;
      _panXT += -dx * math.cos(yaw) - dy * math.sin(yaw);
      _panZT += dx * math.sin(yaw) - dy * math.cos(yaw);
      final lejos = math.sqrt(_panXT * _panXT + _panZT * _panZT);
      if (lejos > 18) {
        _panXT *= 18 / lejos;
        _panZT *= 18 / lejos;
      }
    } else {
      _yawT -= d.focalPointDelta.dx * 0.0062;
      // Lo mismo que la cámara del valle: entre casi a ras y casi cenital.
      _pitchT = clampD(
        _pitchT + d.focalPointDelta.dy * 0.0048,
        0.05 - _walk.pitch,
        1.30 - _walk.pitch,
      );
    }
  }

  Widget _scene(
    BoxConstraints box,
    TownScene Function(TownEntry) scene,
    double noche,
    double muestra,
    double vista,
  ) {
    final cartel = _sign > 0.001
        ? _cam
              .projector(box.maxWidth, box.maxHeight, 0)
              .project(const V3(0, 1.6, 0))
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: TownPainter(scene(_empty), _hits),
          isComplex: true,
          willChange: true,
        ),
        // El pueblo de la comarca elegida, levantado en el mismo claro y
        // con la misma cámara: se elige mirando cómo queda de verdad, en
        // el valle, y no en una ventanita. Se funde para entrar y para
        // irse, que es lo que dice que es una muestra y no el pueblo.
        if (muestra > 0.01)
          Opacity(
            opacity: muestra,
            child: CustomPaint(
              painter: TownPainter(scene(_previewOf(_shown)), TouchMap()),
              isComplex: true,
              willChange: true,
            ),
          ),
        IgnorePointer(
          child: CustomPaint(
            painter: _Motes(
              time: _time,
              night: noche,
              // Y en el cambio de comarca se arremolinan un momento.
              rush: math.max(
                _rush,
                _swap < 1 ? 0.5 * math.sin(math.pi * _swap) : 0.0,
              ),
            ),
          ),
        ),
        if (cartel != null)
          Positioned(
            left: 0,
            right: 0,
            // Sobre el claro, o arriba de todo mientras se elige la comarca.
            top: lerpD(
              cartel.y - 74,
              MediaQuery.of(context).padding.top + 18,
              Curves.easeInOutCubic.transform(_lift),
            ),
            child: IgnorePointer(
              child: Opacity(
                // Al recorrer el pueblo, arriba va el nombre de la comarca.
                opacity:
                    Curves.easeOut.transform(_sign) *
                    (1 - Curves.easeInOutCubic.transform(_explore)),
                child: Transform.translate(
                  offset: Offset(
                    (cartel.x - box.maxWidth / 2) *
                        (1 - Curves.easeInOutCubic.transform(_lift)),
                    10 * (1 - _sign),
                  ),
                  child: _ClearingSign(
                    name: widget.name.trim(),
                    symbol: widget.symbol,
                    settle: _settledAt == null
                        ? 1
                        : clampD((_time - _settledAt!) / 1.6, 0, 1),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Lo que queda a la vista mientras se recorre el pueblo de muestra: arriba
/// el nombre de la comarca y cómo se mueve la cámara, abajo la vuelta a la
/// pregunta.
class _ExploreBar extends StatelessWidget {
  const _ExploreBar({required this.region, required this.onBack});

  final String region;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: mq.padding.top + 28,
          child: Column(
            children: [
              Text(
                region,
                style: const TextStyle(
                  fontFamily: _Ink.serif,
                  fontSize: 34,
                  color: _Ink.cream,
                  shadows: _Ink.shadow,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  'Arrastrá para girar · dos dedos para acercar y mover',
                  'Drag to turn · two fingers to zoom and move',
                ),
                style: TextStyle(
                  fontSize: 12.5,
                  color: _Ink.soft(0.85),
                  shadows: _Ink.shadow,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: mq.padding.bottom + 28,
          child: Center(
            child: SizedBox(
              width: 220,
              child: _Go(text: tr('Volver', 'Back'), onTap: onBack),
            ),
          ),
        ),
      ],
    );
  }
}

/// El cartel sobre el claro: la marca y el nombre del pueblo que se va a
/// fundar ahí. Se escribe solo mientras se escribe el nombre, que es lo que
/// hace que la pregunta se sienta como poner un nombre a un sitio y no como
/// rellenar un campo.
class _ClearingSign extends StatelessWidget {
  const _ClearingSign({
    required this.name,
    required this.symbol,
    required this.settle,
  });

  final String name;
  final String symbol;

  /// De cero a uno, cómo va quedando puesto: llega grande y se asienta, con
  /// un destello dorado que se apaga. Es lo que dice «esto ya es así».
  final double settle;

  @override
  Widget build(BuildContext context) {
    final asienta = Curves.easeOutCubic.transform(settle);
    final brillo = math.sin(math.pi * settle).clamp(0.0, 1.0);
    return Transform.scale(
      scale: 1 + 0.35 * (1 - asienta),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // El destello: una luz redonda detrás, que crece y se apaga.
          IgnorePointer(
            child: Container(
              width: 60 + 140 * asienta,
              height: 60 + 140 * asienta,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _Ink.gold.withValues(alpha: 0.20 * brillo),
                    _Ink.gold.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HabitSigil(symbol: symbol, color: _Ink.gold, size: 30),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _Ink.serif,
                  fontSize: 28,
                  height: 1.05,
                  color: Color.lerp(_Ink.cream, _Ink.gold, brillo * 0.45),
                  shadows: _Ink.shadow,
                ),
              ),
            ],
          ),
        ],
      ),
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

  /// **Sin caja.** Era un vidrio oscuro con borde, el mismo en cada pregunta,
  /// y cinco cajas iguales seguidas se leen como un formulario, no como
  /// fundar un pueblo. Ahora la pregunta va escrita sobre el valle, con la
  /// veladura de abajo y la sombra de las letras para que se lea, y el valle
  /// se ve entero detrás.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
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
    this.over,
    this.child,
    this.skip,
    this.onSkip,
  });

  final String? over;
  final String title;
  final List<String> lines;
  final String next;

  /// Nulo apaga el botón: no se puede seguir sin contestar.
  final VoidCallback? onNext;
  final Widget? child;
  final String? skip;
  final VoidCallback? onSkip;

  /// Lo que tarda en escribirse cada letra de la pregunta.
  static const int _perLetter = 26;

  @override
  Widget build(BuildContext context) {
    // **La pregunta se dice, no se muestra.** Se escribe letra a letra, como
    // si alguien la estuviera diciendo, y lo demás —la explicación, el campo,
    // el botón— llega cuando termina. Es lo que da el tono de un rito y no de
    // un formulario: primero la pregunta, sola, y después dónde contestarla.
    final dicha = Duration(milliseconds: title.length * _perLetter);
    var orden = 0;
    Widget rise(Widget w) => _Rise(order: orden++, after: dicha, child: w);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (over != null) ...[
          rise(
            Text(
              over!.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w600,
                color: _Ink.gold,
                shadows: _Ink.shadow,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        _Typed(
          text: title,
          duration: dicha,
          style: const TextStyle(
            fontFamily: _Ink.serif,
            fontSize: 34,
            height: 1.1,
            color: _Ink.cream,
            shadows: _Ink.shadow,
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
                color: _Ink.soft(0.86),
                shadows: _Ink.shadow,
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
                    style: TextStyle(
                      fontSize: 13.5,
                      color: _Ink.soft(0.78),
                      shadows: _Ink.shadow,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Entrar subiendo un poco, tarde según el turno, y después de [after].
class _Rise extends StatelessWidget {
  const _Rise({
    required this.order,
    required this.child,
    this.after = Duration.zero,
  });

  final int order;
  final Widget child;
  final Duration after;

  @override
  Widget build(BuildContext context) {
    final propia = 520 + order * 60;
    final espera = after.inMilliseconds;
    final total = espera + propia;
    final desde = (espera + math.min(0.55, order * 0.11) * propia) / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(desde, 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

/// Un texto que se escribe letra a letra.
///
/// Lo que falta por escribir está ahí desde el principio, pero transparente:
/// así el texto ocupa desde el primer momento lo que va a ocupar, y nada de
/// lo de debajo se mueve mientras se escribe.
class _Typed extends StatelessWidget {
  const _Typed({
    required this.text,
    required this.duration,
    required this.style,
  });

  final String text;
  final Duration duration;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: duration,
    builder: (_, v, _) {
      final n = (text.length * v).round().clamp(0, text.length);
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: text.substring(0, n)),
            TextSpan(
              text: text.substring(n),
              style: const TextStyle(color: Color(0x00000000), shadows: []),
            ),
          ],
        ),
        style: style,
      );
    },
  );
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
          height: 50,
          alignment: Alignment.center,
          // Una píldora de borde dorado y no un bloque de oro: sin caja
          // alrededor, un botón macizo era lo único pesado de la pantalla.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: on ? _Ink.gold.withValues(alpha: 0.16) : _Ink.disc,
            border: Border.all(
              color: on ? _Ink.gold : _Ink.cream.withValues(alpha: 0.22),
              width: on ? 1.4 : 1,
            ),
          ),
          child: Text(
            widget.text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: on ? _Ink.gold : _Ink.soft(0.40),
              fontSize: 12.5,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
              shadows: _Ink.shadow,
            ),
          ),
        ),
      ),
    );
  }
}

/// Donde se escribe: una raya, nada más, que se enciende en dorado mientras
/// se escribe. Una caja dentro de lo que ya no es una caja volvía a ser un
/// formulario.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.max,
    required this.onChanged,
    this.big = false,
    this.prefix,
    this.kind = _FieldKind.words,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final _FieldKind kind;
  final bool autofocus;
  final String hint;

  /// Una palabra fija delante de lo que se escribe, que no se puede borrar.
  final String? prefix;
  final int max;
  final VoidCallback onChanged;
  final bool big;

  @override
  Widget build(BuildContext context) {
    UnderlineInputBorder borde(Color c, [double w = 1]) => UnderlineInputBorder(
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      autofocus: autofocus,
      textAlign: prefix == null ? TextAlign.center : TextAlign.start,
      textCapitalization: kind == _FieldKind.words
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      keyboardType: switch (kind) {
        _FieldKind.words => TextInputType.text,
        _FieldKind.email => TextInputType.emailAddress,
        _FieldKind.code => TextInputType.number,
      },
      autocorrect: kind == _FieldKind.words,
      enableSuggestions: kind == _FieldKind.words,
      autofillHints: switch (kind) {
        _FieldKind.words => null,
        _FieldKind.email => const [AutofillHints.email],
        _FieldKind.code => const [AutofillHints.oneTimeCode],
      },
      inputFormatters: kind == _FieldKind.code
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      maxLength: max,
      cursorColor: _Ink.gold,
      style: TextStyle(
        fontFamily: big ? _Ink.serif : null,
        fontSize: big ? 30 : 18,
        height: 1.3,
        // El código, con aire entre los números: se lee de a uno, como se
        // copia del correo.
        letterSpacing: kind == _FieldKind.code ? 10 : null,
        color: _Ink.cream,
        shadows: _Ink.shadow,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: big ? _Ink.serif : null,
          fontSize: big ? 26 : 17,
          letterSpacing: kind == _FieldKind.code ? 10 : null,
          color: _Ink.soft(0.42),
          shadows: _Ink.shadow,
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
                    fontSize: big ? 30 : 18,
                    height: 1.3,
                    color: _Ink.gold,
                    shadows: _Ink.shadow,
                  ),
                ),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 4,
          vertical: big ? 10 : 12,
        ),
        enabledBorder: borde(_Ink.cream.withValues(alpha: 0.40)),
        focusedBorder: borde(_Ink.gold, 1.6),
        border: borde(_Ink.cream.withValues(alpha: 0.40)),
      ),
    );
  }
}

/// Qué se escribe en un [_Field]: cambia el teclado y lo que se corrige.
enum _FieldKind { words, email, code }

/// Lo que salió mal, dicho debajo de donde se escribe. Ocupa su sitio sólo
/// cuando hay algo que decir.
class _Problem extends StatelessWidget {
  const _Problem({required this.problem, required this.child});

  final String? problem;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      child,
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: problem == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  problem!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: _Ink.warn,
                    shadows: _Ink.shadow,
                  ),
                ),
              ),
      ),
    ],
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

  static const double _gap = 8;
  static const int _rows = 2;

  /// **Siempre con una marca cortada por la mitad al final.** Antes la
  /// medida era fija —cuarenta de lado— y se suponía que en un teléfono de
  /// 390 asomaba media; en otros anchos entraban siete enteras justas, y
  /// siete enteras se leen como que no hay más. Ahora se mide el ancho y se
  /// elige el tamaño para que entren tantas y media: la media que asoma es
  /// la que dice que se puede deslizar.
  static double _tileFor(double ancho) {
    const ideal = 44.0;
    final enteras = math.max(
      3,
      ((ancho + _gap) / (ideal + _gap) - 0.5).round(),
    );
    return (ancho - enteras * _gap) / (enteras + 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final columnas = (habitSymbols.length + _rows - 1) ~/ _rows;
    return LayoutBuilder(
      builder: (_, box) {
        final tile = _tileFor(box.maxWidth);
        return SizedBox(
          height: _rows * tile + (_rows - 1) * _gap,
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
                      child: _tileAt(col * _rows + row, tile),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tileAt(int at, double tile) {
    if (at >= habitSymbols.length) {
      return SizedBox(width: tile, height: tile);
    }
    final m = habitSymbols[at];
    final elegida = m == chosen;
    return GestureDetector(
      onTap: () => onPick(m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: tile,
        height: tile,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: elegida ? _Ink.gold.withValues(alpha: 0.24) : _Ink.disc,
          border: Border.all(
            color: elegida ? _Ink.gold : _Ink.cream.withValues(alpha: 0.22),
            width: elegida ? 1.4 : 1,
          ),
        ),
        child: HabitSigil(
          symbol: m,
          color: elegida ? _Ink.gold : _Ink.soft(0.80),
          size: tile * 0.48,
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

  static const double _gap = 14, _max = 52;

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
            color: elegida ? _Ink.gold.withValues(alpha: 0.24) : _Ink.disc,
            border: Border.all(
              color: elegida ? _Ink.gold : _Ink.cream.withValues(alpha: 0.22),
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
