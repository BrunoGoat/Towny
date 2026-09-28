import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/character.dart';
import '../data/symbols.dart';
import '../engine/backdrop.dart';
import '../engine/camera.dart';
import '../engine/palette.dart';
import '../engine/scene.dart';
import '../engine/town.dart';
import '../fx/effects.dart';
import '../fx/sensory.dart';
import '../model/pledge.dart';
import 'habit_sigil.dart';
import 'plan_picker.dart';
import 'style.dart';

/// Lo que se ve la primera vez que se abre la app.
///
/// Seis pantallas, una pregunta en cada una, y al final un pueblo fundado.
///
/// **Por qué existe.** Sin esto, la primera vez que alguien abría Towny se
/// encontraba un prado vacío, un botón grande y un hábito de mentira llamado
/// «Mi hábito». Todo lo que hace a esta app distinta —que una pieza es un
/// logro, que no hay rachas, que las dos frases que escribís se guardan para el
/// día malo— estaba ahí desde el primer minuto y no lo contaba nadie. Se
/// descubría a los tres meses o no se descubría.
///
/// **Y por qué son seis pantallas y no una hoja con seis campos.** Un
/// formulario se contesta entero mirando los huecos que faltan por rellenar, y
/// las cuatro preguntas del final —cuándo y dónde, para qué, en quién te
/// convierte, qué es lo mínimo— no se contestan bien así: son lo único de toda
/// la app que se escribe para leerlo mucho después, y merecen que no haya nada
/// más en pantalla cuando se escriben.
///
/// Las cuatro se pueden saltar. Se guardaron para el día malo, y obligar a
/// escribirlas el día uno es la manera de que salgan mal. Ninguna se pierde por
/// haberla saltado: las cuatro están en la hoja del hábito para siempre, y el
/// pueblo pide el plan por su cuenta en cuanto sabe a qué hora aparecés.
class FirstRun extends StatefulWidget {
  const FirstRun({super.key, required this.onDone});

  /// Lo que se contestó, para que quien lo pidió funde el pueblo.
  ///
  /// Las cinco últimas son opcionales y llegan en nulo si se saltaron. El
  /// nombre y la marca no: sin ellas no hay pueblo.
  final void Function(
    String name,
    String symbol, {
    String? why,
    String? floor,
    int? vowHour,
    String? vowPlace,
    String? identity,
  })
  onDone;

  @override
  State<FirstRun> createState() => _FirstRunState();
}

class _FirstRunState extends State<FirstRun> with TickerProviderStateMixin {
  int _step = 0;
  String _symbol = habitSymbols.first;
  final _name = TextEditingController();
  final _why = TextEditingController();
  final _floor = TextEditingController();

  /// El plan: a qué hora y en qué sitio. La hora se toca, el sitio se escribe.
  ///
  /// La hora **no** viene puesta. El reloj se abre centrado en la de ahora
  /// —que casi siempre es la de la que se va a hablar— pero elegirla es un
  /// toque, porque un plan que la app rellenó sola no es una decisión de nadie
  /// y sería lo primero que el pueblo dice de vos sin que lo hayas dicho.
  int? _vowHour;
  final _place = TextEditingController();

  /// En quién te convierte. Sin el «alguien que»: eso lo pone el pueblo.
  final _identity = TextEditingController();

  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    _name.dispose();
    _why.dispose();
    _floor.dispose();
    _place.dispose();
    _identity.dispose();
    super.dispose();
  }

  void _go(int to) {
    Sensory.instance.tick();
    setState(() => _step = to);
    _in.forward(from: 0);
  }

  void _found() {
    Sensory.instance.tick();
    String? dicho(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    widget.onDone(
      _name.text.trim(),
      _symbol,
      why: dicho(_why),
      floor: dicho(_floor),
      vowHour: _vowHour,
      vowPlace: dicho(_place),
      identity: dicho(_identity),
    );
  }

  /// Saltarse el plan lo deja sin escribir del todo, hora incluida.
  ///
  /// Hace falta decirlo porque la hora se puede haber tocado y luego haberse
  /// decidido que no: «ahora no» quiere decir que no hay plan, y un plan a
  /// medias guardado por descuido saldría mañana en el tablón como si lo
  /// hubieras prometido.
  void _skipPlan() {
    _vowHour = null;
    _place.clear();
    _go(3);
  }

  /// La hora de verdad, para que el cielo de la primera pantalla sea el cielo
  /// que hay ahora mismo al otro lado de la ventana.
  double get _hour {
    final n = DateTime.now();
    return n.hour + n.minute / 60.0;
  }

  @override
  Widget build(BuildContext context) {
    final pal = Palette.forMoment(_hour, 1.0);
    final t = UiTheme(pal);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: pal.skyTop,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // El valle vacío de verdad, con el cielo de esta hora: es lo que se
          // va a llenar, así que tiene que estar ahí desde la primera palabra.
          CustomPaint(painter: _EmptyValley(pal)),
          SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              padding: EdgeInsets.only(bottom: bottom > 0 ? bottom * 0.45 : 0),
              child: FadeTransition(
                opacity: _in,
                child: SlideTransition(
                  position:
                      Tween(
                        begin: const Offset(0, 0.035),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(parent: _in, curve: Curves.easeOut),
                      ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                    child: switch (_step) {
                      0 => _welcome(t),
                      1 => _askName(t),
                      2 => _askPlan(t),
                      3 => _askWhy(t),
                      4 => _askWho(t),
                      _ => _askFloor(t),
                    },
                  ),
                ),
              ),
            ),
          ),
          // Por dónde va, abajo del todo y en voz muy baja. Cuatro puntos no
          // son una barra de progreso: son el tamaño de lo que falta, que acá
          // es lo único tranquilizador que se puede decir.
          if (_step > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 18 + MediaQuery.of(context).padding.bottom,
              child: _Dots(at: _step, of: 5, theme: t),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- las cuatro

  Widget _welcome(UiTheme t) => _Step(
    theme: t,
    title: 'Esto es un valle vacío.',
    lines: const [
      'Cada vez que cumplas, vas a poner una pieza.',
      'Las piezas levantan un pueblo, y el pueblo es lo que llevás hecho.',
      'Empecemos por uno.',
    ],
    next: 'Fundar mi pueblo',
    onNext: () => _go(1),
  );

  Widget _askName(UiTheme t) => _Step(
    theme: t,
    title: '¿Qué querés hacer?',
    lines: const ['Una cosa. La segunda se gana más adelante.'],
    next: 'Seguir',
    onNext: _name.text.trim().isEmpty ? null : () => _go(2),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Field(
          theme: t,
          controller: _name,
          hint: 'Leer, correr, no fumar…',
          big: true,
          max: 24,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 26),
        _Marks(
          theme: t,
          chosen: _symbol,
          onPick: (m) {
            Sensory.instance.tick();
            setState(() => _symbol = m);
          },
        ),
      ],
    ),
  );

  /// El plan: a qué hora y en qué sitio.
  ///
  /// La pregunta más barata de toda la pantalla y la que más cambia lo que pasa
  /// después. «Voy a leer» es una intención, y una intención se decide otra vez
  /// todos los días hasta el día en que no; «voy a leer a las 22, en la cama»
  /// está decidido, y lo único que queda es cumplirlo. El sitio no es un
  /// adorno: es de donde el hábito nuevo saca el recordatorio, porque la cama
  /// ya está ahí todas las noches sin que haya que acordarse de ella.
  ///
  /// La frase se ve escribiéndose debajo mientras se elige, y es lo único de
  /// las seis pantallas que se enseña armado: lo que se está contestando no son
  /// dos campos, es una frase, y verla entera es lo que hace que se lea como
  /// una promesa en vez de como un formulario.
  Widget _askPlan(UiTheme t) {
    final frase = vowLine(_name.text, _vowHour, _place.text);
    return _Step(
      theme: t,
      title: '¿Cuándo y dónde?',
      lines: const [
        'Una intención se vuelve a decidir todos los días. Un plan, no.',
        'Elegí la hora y escribí el sitio.',
      ],
      next: 'Seguir',
      skip: 'Ahora no',
      onSkip: _skipPlan,
      onNext: frase == null ? null : () => _go(3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HourReel(
            hour: _vowHour,
            onPick: (h) => setState(() => _vowHour = h),
            ink: t.fg.withValues(alpha: 0.78),
            accent: t.accent,
            plate: t.panelStrong,
            edge: t.fg.withValues(alpha: 0.18),
            shadows: t.halo,
          ),
          const SizedBox(height: 18),
          _Field(
            theme: t,
            controller: _place,
            hint: 'en la cama',
            max: 40,
            // Sin teclado de entrada: lo primero que hay que hacer acá es
            // tocar una hora, y un teclado abierto tapa medio reloj.
            focus: false,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 22),
          // La promesa, armándose. En ámbar y no en la tinta del texto: es lo
          // único de la pantalla que dijiste vos.
          SizedBox(
            height: 40,
            child: frase == null
                ? null
                : Text(
                    frase,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(
                      fontSize: 15,
                      height: 1.3,
                      color: t.accent,
                      shadows: t.halo,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _askWhy(UiTheme t) => _Step(
    theme: t,
    title: '¿Para qué lo querés?',
    lines: const [
      'Esto no se lee ningún día bueno.',
      'Sale el día que vuelvas después de un hueco largo, que es cuando hace '
          'falta y cuando ya no te acordás.',
    ],
    next: 'Seguir',
    skip: 'Ahora no',
    onSkip: () => _go(4),
    onNext: _why.text.trim().isEmpty ? null : () => _go(4),
    child: _Field(
      theme: t,
      controller: _why,
      hint: 'para dormir mejor',
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
  Widget _askWho(UiTheme t) => _Step(
    theme: t,
    title: '¿En quién te convierte?',
    lines: const [
      'No es lo mismo que para qué lo querés: eso se cumple algún día y esto no '
          'se cumple nunca.',
      'El pueblo lo va a decir así: «este pueblo es de alguien que lee todos '
          'los días».',
    ],
    next: 'Seguir',
    skip: 'Ahora no',
    onSkip: () => _go(5),
    onNext: _identity.text.trim().isEmpty ? null : () => _go(5),
    child: _Field(
      theme: t,
      controller: _identity,
      hint: 'alguien que lee todos los días',
      max: 60,
      onChanged: () => setState(() {}),
    ),
  );

  Widget _askFloor(UiTheme t) => _Step(
    theme: t,
    title: '¿Y qué es lo mínimo que cuenta?',
    lines: const [
      'Para el día en que no da para más.',
      'Una pieza no tiene tamaño: cinco minutos ponen la misma piedra que una '
          'hora.',
    ],
    next:
        'Fundar ${_name.text.trim().isEmpty ? 'el pueblo' : _name.text.trim()}',
    skip: 'Ahora no',
    onSkip: _found,
    onNext: _floor.text.trim().isEmpty ? null : _found,
    child: _Field(
      theme: t,
      controller: _floor,
      hint: 'una página',
      max: 60,
      onChanged: () => setState(() {}),
    ),
  );
}

/// El molde de las cuatro: mucho aire, un título, lo que haga falta decir, y
/// abajo la salida.
class _Step extends StatelessWidget {
  const _Step({
    required this.theme,
    required this.title,
    required this.lines,
    required this.next,
    required this.onNext,
    this.child,
    this.skip,
    this.onSkip,
  });

  final UiTheme theme;
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
    final t = theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Centrado y con desplazamiento si no cabe. Con `Spacer` a los dos
        // lados, la pantalla del nombre —que lleva campo y catorce marcas—
        // empujaba el título hasta meterlo dentro de las montañas, y en un
        // teléfono chico se salía por abajo sin avisar.
        Expanded(
          child: Align(
            // Un pelo por debajo del centro, a propósito: centrado del todo,
            // el título se apoyaba justo en la silueta de las cordilleras, que
            // es la única franja oscura de toda la pantalla. Aquí abajo el
            // fondo es el prado, que es liso y claro.
            alignment: const Alignment(0, 0.14),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(
                      fontSize: 25,
                      height: 1.28,
                      fontWeight: FontWeight.w600,
                      shadows: t.halo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final l in lines) ...[
                    Text(
                      l,
                      textAlign: TextAlign.center,
                      style: t.bodySoft.copyWith(
                        fontSize: 14,
                        height: 1.5,
                        shadows: t.halo,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (child != null) ...[const SizedBox(height: 30), child!],
                ],
              ),
            ),
          ),
        ),
        _Go(theme: t, text: next, onTap: onNext),
        if (skip != null) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: onSkip,
            child: Text(
              skip!,
              style: t.bodySoft.copyWith(fontSize: 13, shadows: t.halo),
            ),
          ),
        ] else
          const SizedBox(height: 40),
      ],
    );
  }
}

/// El botón de seguir. Apagado cuando todavía no hay nada que contestar, y
/// apagado de verdad —no escondido—: que se vea dónde está la salida antes de
/// poder usarla es la mitad de saber cuánto falta.
class _Go extends StatelessWidget {
  const _Go({required this.theme, required this.text, required this.onTap});

  final UiTheme theme;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final on = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: on ? 1 : 0.32,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: t.fg.withValues(alpha: on ? 0.10 : 0.04),
            border: Border.all(
              color: on ? t.fg.withValues(alpha: 0.30) : t.stroke,
            ),
          ),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              color: t.fg,
              fontSize: 12,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Donde se escribe. Centrado y sin caja, igual que en el resto de la app: lo
/// que se está escribiendo es el nombre de un sitio, no un campo de un alta.
class _Field extends StatelessWidget {
  const _Field({
    required this.theme,
    required this.controller,
    required this.hint,
    required this.max,
    required this.onChanged,
    this.big = false,
    this.focus = true,
  });

  final UiTheme theme;
  final TextEditingController controller;
  final String hint;
  final int max;
  final VoidCallback onChanged;
  final bool big;

  /// Si el teclado se abre solo al llegar. En la pantalla del plan no: lo
  /// primero de esa pantalla es tocar una hora, y el teclado tapa el reloj.
  final bool focus;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Column(
      children: [
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          autofocus: focus,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.sentences,
          maxLength: max,
          cursorColor: t.accent,
          style: t.body.copyWith(
            fontSize: big ? 27 : 18,
            height: 1.3,
            fontWeight: big ? FontWeight.w600 : FontWeight.w500,
            shadows: t.halo,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: t.bodySoft.copyWith(
              fontSize: big ? 22 : 17,
              color: t.fgFaint,
              shadows: t.halo,
            ),
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            border: InputBorder.none,
          ),
        ),
        Container(height: 1, color: t.stroke),
      ],
    );
  }
}

/// Las marcas, en dos filas y sin desplazamiento: se ven todas de una vez o no
/// se elige, se acepta la primera.
class _Marks extends StatelessWidget {
  const _Marks({
    required this.theme,
    required this.chosen,
    required this.onPick,
  });

  final UiTheme theme;
  final String chosen;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // Doce: dos filas justas de seis. Con catorce, la última fila eran dos
    // marcas sueltas en el medio, y una rejilla que no cierra se lee como que
    // falta algo.
    final cuantas = math.min(habitSymbols.length, 12);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final m in habitSymbols.take(cuantas))
          GestureDetector(
            onTap: () => onPick(m),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                // Cada marca sobre su propio plato, no directamente sobre el
                // prado. Una marca dibujada sobre la escena se pierde en cuanto
                // detrás pasa algo del mismo tono, y acá detrás hay un campo
                // entero que cambia de color con la hora.
                color: m == chosen
                    ? t.accent.withValues(alpha: 0.22)
                    : t.panelStrong,
                border: Border.all(
                  color: m == chosen ? t.accent : t.fg.withValues(alpha: 0.18),
                ),
              ),
              child: HabitSigil(
                symbol: m,
                color: m == chosen ? t.accent : t.fg.withValues(alpha: 0.78),
                size: 22,
              ),
            ),
          ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.at, required this.of, required this.theme});

  final int at, of;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 1; i <= of; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == at ? 16 : 5,
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: theme.fg.withValues(alpha: i == at ? 0.42 : 0.16),
          ),
        ),
    ],
  );
}

/// El prado vacío del fondo: el cielo de esta hora, el suelo y las cordilleras.
///
/// Es el mismo fondo que pinta el pueblo, sin el pueblo — que es exactamente
/// lo que hay antes de fundar. Salió gratis de haber sacado el fondo del
/// rasterizador a su propia clase.
class _EmptyValley extends CustomPainter {
  _EmptyValley(this.palette);
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final cam = OrbitCamera()
      ..yaw = 0.62
      ..pitch = 0.20
      ..distance = 46
      ..focusY = 2.4
      ..wallLength = 60;
    final scene = TownScene(
      placed: 0,
      palette: palette,
      camera: cam,
      integrity: 1,
      time: 0,
      hourOfDay: palette.hour,
      effects: EffectSystem(),
      labelledBricks: const {},
      towns: [
        TownEntry(
          layout: TownLayout(0, TownCharacter.all.first, seed: 1),
          name: '',
          symbol: habitSymbols.first,
          integrity: 1,
          placed: 0,
          founded: false,
        ),
      ],
      active: 0,
      labels: false,
      folk: false,
    );
    final p = cam.projector(size.width, size.height, 0);
    final y = horizonOf(p, size);
    final fondo = Backdrop(scene, []);
    fondo.drawSky(canvas, size, p, y);
    fondo.drawGround(canvas, size, y);
    fondo.drawRanges(canvas, p, size, y);
  }

  @override
  bool shouldRepaint(_EmptyValley old) => old.palette != palette;
}
