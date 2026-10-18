import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../data/advice.dart';
import '../data/character.dart';
import '../data/doings.dart';
import '../engine/bsp.dart';
import '../engine/folk.dart';
import '../engine/folk_body.dart';
import '../engine/solid.dart';
import '../engine/town.dart';
import '../fx/sensory.dart';
import '../l10n/lang.dart';
import '../model/advice_book.dart';
import '../model/sage_talk.dart';
import '../model/store.dart';
import 'sage_scroll.dart';
import 'style.dart';

/// Cómo se visten las tarjetas y lo que dice el viejo: papel, como las hojas
/// del tablón — el mismo pergamino con su filete y la misma letra a mano, cada
/// hoja un poco torcida. Lo que dice él, en un globo de papel con la colita
/// hacia su boca. Se probaron también vidrio claro y un pergamino enrollado;
/// quedó éste porque es el que pertenece al pueblo.
class _Estilo {
  const _Estilo();

  Color get tinta => const Color(0xFF3B2F22);

  /// La explicación, en gris.
  Color get gris => const Color(0xFF3B2F22).withValues(alpha: 0.62);

  Color get papel => const Color(0xFFEFE4C6);

  /// El globo de lo que dice, un papel más claro.
  Color get globo => const Color(0xFFF6EEDA);

  TextStyle dicho(double size) => TextStyle(
    fontFamily: 'ArchitectsDaughter',
    fontSize: size * 0.95,
    height: 1.3,
    color: tinta,
    fontWeight: FontWeight.w600,
  );

  TextStyle habla(double size) => TextStyle(
    fontFamily: 'EBGaramond',
    fontSize: size,
    height: 1.35,
    color: tinta,
  );

  /// Lo que quiere decir: en la letra de los libros viejos, derecha y no
  /// cursiva —la cursiva es del dicho—, en tinta más clara.
  TextStyle get explica => TextStyle(
    fontFamily: 'EBGaramond',
    color: gris,
    fontSize: 17.5,
    height: 1.4,
  );

  /// Por qué lo dijo: más chico, en cursiva, como una nota al margen.
  TextStyle get motivo => TextStyle(
    fontFamily: 'EBGaramond',
    fontStyle: FontStyle.italic,
    color: tinta.withValues(alpha: 0.5),
    fontSize: 15,
    height: 1.35,
  );

  List<BoxShadow> get sombra => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.26),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];
}

/// El consejero, de cerca.
///
/// No es un menú con una lista: es el viejo —el mismo de la plaza, en tres
/// dimensiones y grande— abajo a la izquierda, diciéndote algo a su derecha
/// en un globo. Lo que te fue diciendo queda arriba, del más nuevo al más
/// viejo, y de cada cosa se ve sólo el dicho. Tocar una es pedirle que te la
/// explique.
///
/// Detrás sigue el valle: esto no es otra pantalla, es el viejo que se
/// acercó a hablarte.
///
/// La primera vez pregunta antes de hablar: si este pueblo es para sembrar
/// algo nuevo o para arrancar algo. Sin esa respuesta no sabe qué decir.
class SageScreen extends StatefulWidget {
  const SageScreen({
    super.key,
    required this.store,
    required this.theme,
    this.talk,
  });

  final Store store;
  final UiTheme theme;

  /// Una charla para empezar, en vez de la que toque: para probarlas desde
  /// los ajustes de desarrollo.
  final TalkStep? talk;

  /// Para probar desde los ajustes de desarrollo: un consejo cualquiera
  /// —[advice], o uno al azar— llegando como llega uno nuevo, sellado y para
  /// abrir tirando. No cuenta como dado ni como leído: al cerrarlo se va y el
  /// libro queda como estaba.
  static Route<void> trial({Advice? advice}) {
    final todos = [...dailyAdvice, ...eventAdvice];
    final consejo =
        advice ?? todos[DateTime.now().microsecondsSinceEpoch % todos.length];
    return PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) => Material(
        type: MaterialType.transparency,
        child: _Detalle(
          e: const _Estilo(),
          consejo: consejo,
          sealed: true,
          onClosed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }

  static Route<void> route({
    required Store store,
    required UiTheme theme,
    TalkStep? talk,
  }) => PageRouteBuilder<void>(
    opaque: false,
    // Un velo, pero que se note: el valle se sigue viendo, más apagado.
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 360),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) =>
        SageScreen(store: store, theme: theme, talk: talk),
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
      child: child,
    ),
  );

  @override
  State<SageScreen> createState() => _SageScreenState();
}

class _SageScreenState extends State<SageScreen> {
  final AdviceBook _libro = AdviceBook.instance;
  final _Estilo _e = const _Estilo();

  /// Dónde está la lista, para que el rollo leído vuele hasta ella.
  final GlobalKey _lista = GlobalKey();
  final ScrollController _desliza = ScrollController();

  /// Lo que dijo al contestar algo, si se acaba de contestar.
  String? _respuesta;

  /// Por qué globo de la presentación va, la primera vez.
  int _paso = 0;

  /// Si se presentó en esta visita: entonces la pregunta es la de siempre,
  /// y no la de «un pueblo nuevo…».
  bool _sePresento = false;

  /// Si se le dijo que todavía no: no vuelve a preguntar mientras se esté
  /// acá. Lo que tenía para dar sigue esperando.
  bool _espera = false;

  /// El consejo que se está mirando de cerca, o nulo; y si es uno que se
  /// está dando ahora, que al cerrarse va a la lista.
  Advice? _abierto;
  bool _dando = false;

  /// La charla de esta visita —un tropiezo, la identidad, la semana— por
  /// el globo en que va; nula si no hay o ya terminó. Se pide una vez, la
  /// primera vez que el viejo puede hablar de algo que no sea presentarse.
  late TalkStep? _charla = widget.talk;
  late bool _pidio = widget.talk != null;

  /// Pasar al globo siguiente de la charla, o terminarla.
  void _sigue(TalkStep? Function()? paso) {
    Sensory.instance.tick();
    final siguiente = paso?.call();
    setState(() => _charla = siguiente);
  }

  @override
  void dispose() {
    _desliza.dispose();
    super.dispose();
  }

  void _contestar(AdviceGoal g) {
    Sensory.instance.tick();
    final store = widget.store;
    _libro.setGoal(store.habit.id, g);
    _libro.visit(store.habits);
    setState(() {
      _respuesta = g == AdviceGoal.start
          ? SageLines.afterStart
          : SageLines.afterQuit;
    });
  }

  /// Sí: el rollo de lo que tenía para dar.
  void _dar(Advice a) {
    Sensory.instance.tick();
    setState(() {
      _abierto = a;
      _dando = true;
      _respuesta = null;
    });
  }

  void _todaviaNo() {
    Sensory.instance.tick();
    setState(() {
      _espera = true;
      _respuesta = SageLines.notYet;
    });
  }

  void _abrir(Advice a) {
    Sensory.instance.tick();
    setState(() {
      _abierto = a;
      _dando = false;
    });
  }

  /// Adónde va el rollo leído: arriba de la lista, donde va a quedar.
  Rect? _destino() {
    final caja = _lista.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null || !caja.hasSize) return null;
    if (_desliza.hasClients) _desliza.jumpTo(0);
    final arriba = caja.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      arriba.dx + _Lista.margen.left,
      arriba.dy + _Lista.margen.top,
      caja.size.width - _Lista.margen.horizontal,
      SageScroll.closed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    final pregunta = _libro.goalOf(widget.store.habit.id) == null;
    final leidos = _libro.read();
    final pendientes = _libro.pending();
    // Lo que dice ahora, en el globo, y lo que se le puede contestar. Los
    // consejos no van en el globo: van en su rollo.
    final String dice;
    var respuestas = <(String, VoidCallback)>[];
    VoidCallback? sigue;
    TalkInput? escribe;
    var sale = false;
    if (!_pidio && _libro.met && !pregunta) {
      _pidio = true;
      _charla = nextTalk(widget.store, _libro);
    }
    final intro = SageLines.intro;
    if (!_libro.met && _paso < intro.length) {
      // La primera vez se presenta, de a un globo, antes de preguntar nada.
      dice = intro[_paso];
      sigue = () => setState(() {
        _paso++;
        _sePresento = true;
        if (_paso >= intro.length) _libro.meet();
      });
    } else if (pregunta) {
      dice = _sePresento || !_libro.met
          ? SageLines.question
          : SageLines.questionAgain;
      respuestas = [
        (SageLines.answerStart, () => _contestar(AdviceGoal.start)),
        (SageLines.answerQuit, () => _contestar(AdviceGoal.quit)),
      ];
    } else if (_charla != null && _abierto == null) {
      // Lo suyo: una charla, de a un globo.
      final c = _charla!;
      dice = c.says;
      respuestas = [for (final o in c.options) (o.label, () => _sigue(o.then))];
      escribe = c.input;
      if (c.options.isEmpty && c.input == null) {
        sigue = () => _sigue(c.next);
      }
    } else if (_respuesta != null &&
        pendientes.isNotEmpty &&
        !_espera &&
        _abierto == null) {
      // Lo que contesta, en su globo; y al tocarlo, la pregunta del día.
      dice = _respuesta!;
      sigue = () => setState(() => _respuesta = null);
    } else if (pendientes.isNotEmpty && !_espera && _abierto == null) {
      dice = leidos.isEmpty || _libro.today() == pendientes.first
          ? SageLines.ready
          : SageLines.readyOther;
      respuestas = [
        (SageLines.yes, () => _dar(pendientes.first)),
        (SageLines.notNow, _todaviaNo),
      ];
    } else {
      // Ya no tiene nada más que decir: tocar el globo es despedirse, como
      // tocar el valle. Era una equis arriba a la derecha.
      dice = _respuesta ?? SageLines.nothingNew;
      sigue = () => Navigator.of(context).maybePop();
      sale = true;
    }
    final alto = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Lo de atrás: la penumbra, la luz que sale del viejo y el polvo
          // dorado que sube despacio.
          const Positioned.fill(child: IgnorePointer(child: _Ambiente())),
          // Tocar el valle es irse.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                  child: _Cabecera(cuantos: leidos.length),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: _lista,
                    child: _Lista(
                      e: e,
                      dichos: leidos,
                      controller: _desliza,
                      onTap: _abrir,
                    ),
                  ),
                ),
                // Más alto mientras hay charla: trae más respuestas, o un
                // renglón para escribir, y la lista puede esperar.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  height: _charla != null && _abierto == null
                      ? math.min(470, alto * 0.56)
                      : math.min(360, alto * 0.42),
                  child: _Habla(
                    e: e,
                    dice: _abierto != null && _dando ? '' : dice,
                    respuestas: _abierto != null ? const [] : respuestas,
                    onNext: _abierto != null ? null : sigue,
                    // Los tres puntos dicen que hay más; despedirse no lo es.
                    more: !sale,
                    escribe: _abierto != null || escribe == null
                        ? null
                        : (
                            escribe,
                            (texto) => _sigue(() => escribe!.then(texto)),
                            () => _sigue(escribe!.skip),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (_abierto != null)
            Positioned.fill(
              child: _Detalle(
                key: ValueKey(_abierto!.id),
                e: e,
                consejo: _abierto!,
                motivo: _libro.reasonOf(_abierto!)?.text,
                destino: _dando ? _destino : null,
                // Uno nuevo se abre a mano, y cuesta; uno que ya se leyó se
                // abre solo, como siempre.
                sealed: _dando,
                onClosed: () => setState(() {
                  if (_dando) _libro.markRead(_abierto!);
                  _abierto = null;
                  _dando = false;
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// El nombre de la pantalla, como en la portada de un libro viejo: EL
/// CONSEJERO en letra de libro, un filete con su estrella, y cuántos dichos
/// lleva guardados.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.cuantos});
  final int cuantos;

  static const Color _oroViejo = Color(0xFFE6CF98);

  @override
  Widget build(BuildContext context) {
    final filete = Container(
      height: 1,
      width: 26,
      color: _oroViejo.withValues(alpha: 0.5),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr('EL CONSEJERO', 'THE ADVISOR'),
          style: const TextStyle(
            fontFamily: 'EBGaramond',
            fontSize: 19,
            letterSpacing: 4.5,
            color: _oroViejo,
            shadows: [Shadow(color: Color(0xAA000000), blurRadius: 10)],
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            filete,
            const SizedBox(width: 6),
            Icon(
              Icons.auto_awesome,
              size: 10,
              color: _oroViejo.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 6),
            filete,
            const SizedBox(width: 10),
            if (cuantos > 0)
              Text(
                cuantos == 1
                    ? tr('un dicho guardado', 'one saying kept')
                    : tr('$cuantos dichos guardados', '$cuantos sayings kept'),
                style: TextStyle(
                  fontFamily: 'EBGaramond',
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: _oroViejo.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Un rollo de la lista entre sus dos varillas de madera, como el que llega
/// sellado: los rollos del viejo son todos del mismo taller.
class _ConVarillas extends StatelessWidget {
  const _ConVarillas({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(foregroundPainter: const _Varillas(), child: child);
}

class _Varillas extends CustomPainter {
  const _Varillas();

  @override
  void paint(Canvas c, Size s) {
    if (s.height < 8) return;
    _Frente.varilla(c, 3, 12, s.width - 12);
    _Frente.varilla(c, s.height - 3, 12, s.width - 12);
  }

  @override
  bool shouldRepaint(_Varillas old) => false;
}

/// Lo de atrás de la pantalla del viejo: la penumbra, una luz cálida que sale
/// de donde está él, y motas de polvo dorado subiendo despacio por el aire,
/// como en un cuarto con una vela. Siempre igual para el mismo instante: las
/// motas salen de su número, no de un dado.
class _Ambiente extends StatefulWidget {
  const _Ambiente();

  @override
  State<_Ambiente> createState() => _AmbienteState();
}

class _AmbienteState extends State<_Ambiente>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reloj = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 120),
  )..repeat();

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _reloj,
    builder: (_, _) =>
        CustomPaint(painter: _AmbientePainter(_reloj.value * 120)),
  );
}

class _AmbientePainter extends CustomPainter {
  _AmbientePainter(this.t);
  final double t;

  @override
  void paint(Canvas c, Size s) {
    final todo = Offset.zero & s;
    // La penumbra: más oscuro abajo y en los bordes.
    c.drawRect(
      todo,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x55000000), Color(0x22000000), Color(0x88000000)],
          stops: [0, 0.4, 1],
        ).createShader(todo),
    );
    c.drawRect(
      todo,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: const [Color(0x00000000), Color(0x66000000)],
        ).createShader(todo),
    );
    // La luz del viejo: abajo a la izquierda, donde está él, latiendo como
    // una vela.
    final late = 0.85 + 0.15 * math.sin(t * 1.3) * math.sin(t * 0.7 + 1);
    final foco = Offset(s.width * 0.22, s.height * 0.8);
    final radio = s.width * 0.75;
    c.drawCircle(
      foco,
      radio,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFC870).withValues(alpha: 0.28 * late),
            const Color(0x00FFC870),
          ],
        ).createShader(Rect.fromCircle(center: foco, radius: radio)),
    );
    // El polvo.
    for (var i = 0; i < 34; i++) {
      final x0 = hash01(i, 11) * s.width;
      final v = 9 + hash01(i, 12) * 16;
      final alto = s.height * 1.15;
      final y = s.height - ((t * v + hash01(i, 13) * alto) % alto);
      final x = x0 + math.sin(t * (0.3 + hash01(i, 14) * 0.4) + i) * 14;
      final brilla = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 1.7 + i * 2.1));
      final tam = 0.8 + hash01(i, 15) * 1.6;
      // Más visibles cerca de la luz.
      final cerca =
          1 -
          ((Offset(x, y) - foco).distance / (s.width * 1.3)).clamp(0.0, 1.0);
      final a = (0.15 + 0.6 * cerca) * brilla;
      c.drawCircle(
        Offset(x, y),
        tam * 2.8,
        Paint()..color = const Color(0xFFFFD98A).withValues(alpha: 0.10 * a),
      );
      c.drawCircle(
        Offset(x, y),
        tam,
        Paint()..color = const Color(0xFFFFEBC2).withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientePainter old) => old.t != t;
}

/// Lo que ya dijo y se leyó, el más nuevo arriba, cada cosa en su rollo.
class _Lista extends StatelessWidget {
  const _Lista({
    required this.e,
    required this.dichos,
    required this.controller,
    required this.onTap,
  });

  final _Estilo e;
  final List<(Advice, DateTime)> dichos;
  final ScrollController controller;
  final void Function(Advice) onTap;

  /// El margen de la lista: el rollo que llega volando va a este hueco.
  /// Ancho de lado: las varillas sobresalen del rollo con sus remates y
  /// tienen que caber.
  static const EdgeInsets margen = EdgeInsets.fromLTRB(32, 14, 32, 14);

  @override
  Widget build(BuildContext context) {
    if (dichos.isEmpty) return const SizedBox.expand();
    final lista = ListView.separated(
      controller: controller,
      padding: margen,
      itemCount: dichos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (context, i) {
        final (a, _) = dichos[i];
        final texto = Text(
          a.say,
          textAlign: TextAlign.center,
          style: e.habla(18).copyWith(fontStyle: FontStyle.italic),
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(a),
          // El de arriba se desenrolla al llegar: es el rollo que acaba de
          // aterrizar ahí, o el último que se dio.
          child: i == 0
              ? TweenAnimationBuilder<double>(
                  key: ValueKey(a.id),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, child) => _ConVarillas(
                    child: SageScroll(open: t, child: child!),
                  ),
                  child: texto,
                )
              : _ConVarillas(child: SageScroll(child: texto)),
        );
      },
    );
    return ShaderMask(
      // Lo de arriba se funde en lugar de cortarse en seco.
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white, Colors.white],
        stops: [0, 0.05, 1],
      ).createShader(r),
      blendMode: BlendMode.dstIn,
      child: lista,
    );
  }
}

/// El globo de lo que dice, con la colita hacia él.
class _Globo extends StatelessWidget {
  const _Globo({required this.e, required this.child});
  final _Estilo e;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _GloboPainter(e),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: child,
    ),
  );
}

class _GloboPainter extends CustomPainter {
  _GloboPainter(this.e);
  final _Estilo e;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 14.0;
    final cuerpo = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(r),
    );
    // La colita, a la izquierda y arriba, apuntando a la boca del viejo. Va
    // arriba porque el globo cuelga de arriba: lo de abajo crece con las
    // respuestas y la cola no puede moverse con ellas.
    final y = math.min(64.0, size.height - 34);
    final cola = Path()
      ..moveTo(0, y - 12)
      ..lineTo(-17, y + 14)
      ..lineTo(0, y + 12)
      ..close();
    final todo = Path.combine(
      PathOperation.union,
      Path()..addRRect(cuerpo),
      cola,
    );
    canvas.drawShadow(todo, Colors.black.withValues(alpha: 0.5), 8, false);
    // Papel viejo: más claro arriba, tostado abajo.
    canvas.drawPath(
      todo,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [e.globo, const Color(0xFFE9DCBB)],
        ).createShader(Offset.zero & size),
    );
    // El canto dorado, y un filete fino por dentro, como en un libro.
    canvas.drawPath(
      todo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFB8964F).withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      cuerpo.deflate(5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = e.tinta.withValues(alpha: 0.22),
    );
    // Un adorno en el medio del filete de arriba.
    final o = Offset(size.width / 2, 5);
    canvas.drawRect(
      Rect.fromCenter(center: o, width: 26, height: 4),
      Paint()..color = e.globo,
    );
    final rombo = Path()
      ..moveTo(o.dx, o.dy - 3.5)
      ..lineTo(o.dx + 4, o.dy)
      ..lineTo(o.dx, o.dy + 3.5)
      ..lineTo(o.dx - 4, o.dy)
      ..close();
    canvas.drawPath(rombo, Paint()..color = const Color(0xFFB8964F));
    for (final dx in [-9.0, 9.0]) {
      canvas.drawCircle(
        o + Offset(dx, 0),
        1.2,
        Paint()..color = const Color(0xFFB8964F),
      );
    }
  }

  @override
  bool shouldRepaint(_GloboPainter old) => false;
}

/// El viejo abajo a la izquierda, grande, y lo que dice a su derecha.
class _Habla extends StatelessWidget {
  const _Habla({
    required this.e,
    required this.dice,
    required this.respuestas,
    this.onNext,
    this.escribe,
    this.more = true,
  });

  final _Estilo e;
  final String dice;

  /// Si tocar el globo sigue hablando —y lleva sus tres puntos— o sólo
  /// despide.
  final bool more;

  /// Si lo que dice sigue en otro globo: tocar éste pasa al siguiente.
  final VoidCallback? onNext;

  /// Un renglón para contestar escribiendo: qué se pide, qué hacer con lo
  /// escrito y qué hacer con «ahora no».
  final (TalkInput, ValueChanged<String>, VoidCallback)? escribe;

  /// Lo que se le puede contestar, en hojitas debajo del globo.
  final List<(String, VoidCallback)> respuestas;

  @override
  Widget build(BuildContext context) {
    // Las respuestas, como dos hojitas más: el mismo papel, el mismo filete
    // y la misma letra que lo que te dice, un poco torcidas cada una para su
    // lado. Eran pastillas redondas con letra de sistema, y se leían como
    // botones de otra app pegados encima.
    // Con muchas, más bajitas: cinco del tamaño de dos no caben debajo del
    // globo.
    final compactas = respuestas.length > 3;
    Widget respuesta(int i, String texto, VoidCallback hacer) => _Respuesta(
      e: e,
      texto: texto,
      onTap: hacer,
      orden: i,
      compacta: compactas,
    );
    return LayoutBuilder(
      builder: (context, box) {
        // El viejo mide lo mismo haya o no charla: lo que crece en una
        // charla es el sitio de arriba, para el globo y sus respuestas.
        final alto = math.min(box.maxHeight, 360.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // El viejo, de cuerpo entero, ocupando la esquina.
            Positioned(
              left: -alto * 0.06,
              bottom: 0,
              width: alto * 0.62,
              height: alto,
              child: const IgnorePointer(child: SageFigure()),
            ),
            Positioned(
              left: alto * 0.52,
              right: 14,
              // Colgado de arriba, a la altura de su cara, y quieto: lo que
              // crece —las respuestas— crece hacia abajo. Iba pegado por abajo,
              // y al aparecer las respuestas el globo entero saltaba hacia
              // arriba de golpe.
              top: alto * 0.06,
              bottom: 0,
              // Y si no entra —un teléfono chico, la letra grande del
              // sistema—, se desliza en vez de salirse por abajo.
              child: SingleChildScrollView(
                clipBehavior: Clip.none,
                padding: const EdgeInsets.only(bottom: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  // Los dos, el que se va y el que llega, colgados del mismo
                  // sitio: centrados, uno más alto que otro se movía al cambiar.
                  layoutBuilder: (actual, anteriores) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...anteriores, ?actual],
                  ),
                  child: Column(
                    key: ValueKey(dice),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dice.isNotEmpty)
                        _Dicho(
                          e: e,
                          texto: dice,
                          onNext: onNext,
                          more: more,
                          respuestas: [
                            for (final (i, (texto, hacer))
                                in respuestas.indexed)
                              respuesta(i, texto, hacer),
                            if (escribe case (
                              final pide,
                              final listo,
                              final no,
                            ))
                              _Escribe(
                                e: e,
                                pide: pide,
                                onDone: listo,
                                onSkip: pide.skip == null ? null : no,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Una respuesta: una tira de papel con una flecha dorada al final, que entra
/// deslizándose cuando el viejo termina de hablar —cada una un poco después
/// de la anterior— y se hunde un poco al tocarla.
class _Respuesta extends StatefulWidget {
  const _Respuesta({
    required this.e,
    required this.texto,
    required this.onTap,
    required this.orden,
    this.compacta = false,
  });
  final _Estilo e;
  final String texto;
  final VoidCallback onTap;
  final int orden;
  final bool compacta;

  @override
  State<_Respuesta> createState() => _RespuestaState();
}

class _RespuestaState extends State<_Respuesta> {
  bool _apretado = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    const oro = Color(0xFFB8964F);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + widget.orden * 140),
      curve: Interval(
        widget.orden * 140 / (380 + widget.orden * 140),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(14 * (1 - t), 0),
          child: child,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: widget.compacta ? 6 : 10),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _apretado = true),
          onTapCancel: () => setState(() => _apretado = false),
          onTapUp: (_) {
            setState(() => _apretado = false);
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _apretado ? 0.96 : 1,
            duration: const Duration(milliseconds: 90),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                widget.compacta ? 5 : 9,
                14,
                widget.compacta ? 5 : 9,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [e.globo, const Color(0xFFE6D6AF)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: oro.withValues(alpha: 0.85)),
                boxShadow: e.sombra,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.texto,
                      style: e.habla(widget.compacta ? 16 : 17),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('›', style: e.habla(22).copyWith(color: oro, height: 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contestar escribiendo: un renglón en el mismo papel que las respuestas,
/// con su comienzo fijo delante —«Cuando…», «alguien…»— en oro, la flecha
/// para darlo por dicho, y un «ahora no» debajo, en pequeño.
class _Escribe extends StatefulWidget {
  const _Escribe({
    required this.e,
    required this.pide,
    required this.onDone,
    this.onSkip,
  });

  final _Estilo e;
  final TalkInput pide;
  final ValueChanged<String> onDone;
  final VoidCallback? onSkip;

  @override
  State<_Escribe> createState() => _EscribeState();
}

class _EscribeState extends State<_Escribe> {
  final TextEditingController _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _listo() {
    final t = _texto.text.trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    widget.onDone(t);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    const oro = Color(0xFFB8964F);
    final letra = e.habla(17);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(14 * (1 - t), 0),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [e.globo, const Color(0xFFE6D6AF)],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: oro.withValues(alpha: 0.85)),
              boxShadow: e.sombra,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // El comienzo fijo, aparte y en oro: dentro del campo, el
                // segundo renglón empezaba corrido debajo de él.
                if (widget.pide.prefix case final p?)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 80),
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      p,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: letra.copyWith(
                        color: oro,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _texto,
                    autofocus: true,
                    textAlign: TextAlign.start,
                    maxLength: 70,
                    minLines: 1,
                    maxLines: 3,
                    style: letra,
                    cursorColor: oro,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _listo(),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: widget.pide.hint,
                      hintStyle: letra.copyWith(
                        color: e.tinta.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _listo,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AnimatedOpacity(
                      opacity: _texto.text.trim().isEmpty ? 0.35 : 1,
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        '›',
                        style: e.habla(26).copyWith(color: oro, height: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.onSkip != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                FocusScope.of(context).unfocus();
                widget.onSkip!();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                child: Text(
                  tr('Ahora no', 'Not now'),
                  style: e
                      .habla(15)
                      .copyWith(
                        color: e.globo.withValues(alpha: 0.75),
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lo que dice, en su globo, escrito de a poco —como habla: una letra tras
/// otra— y con las respuestas debajo cuando termina. Tocar el globo mientras
/// escribe lo termina de una vez; tocarlo terminado pasa al siguiente, si lo
/// hay ([onNext]).
class _Dicho extends StatefulWidget {
  const _Dicho({
    required this.e,
    required this.texto,
    required this.respuestas,
    this.onNext,
    this.more = true,
  });

  final _Estilo e;
  final String texto;
  final List<Widget> respuestas;
  final VoidCallback? onNext;
  final bool more;

  @override
  State<_Dicho> createState() => _DichoState();
}

class _DichoState extends State<_Dicho> with SingleTickerProviderStateMixin {
  /// Cuántas letras por segundo: rápido para no hacer esperar, despacio
  /// para que se sienta que habla.
  static const double _letras = 48;

  late AnimationController _escribe = _nuevo();

  AnimationController _nuevo() => AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: (widget.texto.length / _letras * 1000).round().clamp(
        200,
        6000,
      ),
    ),
  )..forward();

  @override
  void didUpdateWidget(_Dicho old) {
    super.didUpdateWidget(old);
    if (old.texto != widget.texto) {
      _escribe.dispose();
      _escribe = _nuevo();
    }
  }

  @override
  void dispose() {
    _escribe.dispose();
    super.dispose();
  }

  void _toca() {
    if (_escribe.isAnimating) {
      _escribe.value = 1;
      return;
    }
    final sigue = widget.onNext;
    if (sigue != null) {
      Sensory.instance.tick();
      sigue();
    }
  }

  /// Lo que dice, con lo tuyo —lo que va entre «»— en cursiva y morado:
  /// cuando el viejo te devuelve tus palabras, tienen que verse tuyas. Las
  /// primeras [n] letras a la vista, y el resto transparente.
  static List<TextSpan> _citado(String texto, int n) {
    const tuyo = TextStyle(
      color: Color(0xFF6B3F8C),
      fontStyle: FontStyle.italic,
    );
    const nada = TextStyle(color: Colors.transparent);
    final trozos = <(String, bool)>[];
    var desde = 0;
    for (final m in RegExp('«[^»]*»').allMatches(texto)) {
      if (m.start > desde) trozos.add((texto.substring(desde, m.start), false));
      trozos.add((m.group(0)!, true));
      desde = m.end;
    }
    if (desde < texto.length) trozos.add((texto.substring(desde), false));
    final spans = <TextSpan>[];
    var quedan = n;
    for (final (t, cita) in trozos) {
      final ve = quedan.clamp(0, t.length);
      quedan -= ve;
      if (ve > 0) {
        spans.add(
          TextSpan(text: t.substring(0, ve), style: cita ? tuyo : null),
        );
      }
      if (ve < t.length) {
        spans.add(TextSpan(text: t.substring(ve), style: nada));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    return AnimatedBuilder(
      animation: _escribe,
      builder: (context, _) {
        final listo = _escribe.value >= 1;
        final n = (widget.texto.length * _escribe.value).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toca,
              child: _Globo(
                e: e,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Lo que falta escribir está, pero transparente: el
                    // globo tiene desde el principio el tamaño final y no
                    // crece a tirones.
                    Text.rich(
                      TextSpan(
                        style: e.habla(17),
                        children: _citado(widget.texto, n),
                      ),
                    ),
                    if (widget.onNext != null && widget.more)
                      AnimatedOpacity(
                        opacity: listo ? 1 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _Puntos(color: e.gris),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (listo) ...widget.respuestas,
          ],
        );
      },
    );
  }
}

/// Que hay más: tres puntos que aparecen de a uno y vuelven a empezar,
/// como quien todavía tiene algo que decir. Sin palabras, que valen en
/// cualquier idioma.
class _Puntos extends StatefulWidget {
  const _Puntos({required this.color});
  final Color color;

  @override
  State<_Puntos> createState() => _PuntosState();
}

class _PuntosState extends State<_Puntos> with SingleTickerProviderStateMixin {
  late final AnimationController _ciclo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ciclo,
    builder: (context, _) {
      final t = _ciclo.value;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(left: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Cada uno se enciende a su turno y quedan los tres hasta
                // que el ciclo vuelve a empezar.
                color: widget.color.withValues(
                  alpha:
                      widget.color.a *
                      smoothstep(0.12 + i * 0.22, 0.22 + i * 0.22, t) *
                      (1 - smoothstep(0.86, 0.98, t)),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Un consejo de cerca, en su rollo: el dicho, y debajo, un segundo
/// después, lo que quiere decir, y por qué lo dijo si fue por algo.
///
/// El segundo de espera es a propósito: primero se lee la frase sola, como si
/// la dijera él, y después llega la aclaración. Juntas de entrada, el ojo se
/// va a la explicación y el dicho se pierde.
///
/// Llega cerrado y se desenrolla. Al cerrarlo se vuelve a enrollar, y si es
/// uno que se está dando ahora ([destino]), vuela así, cerrado, hasta el
/// hueco de arriba de la lista, que es donde se queda.
///
/// **Uno nuevo ([sealed]) no se abre solo: se abre a mano, y cuesta.** Llega
/// cerrado, colgando de arriba y temblando, y hay que tirar de él hacia abajo
/// para desenrollarlo: la cuerda de abajo va con el dedo, con resistencia y a
/// su ritmo —tirar fuerte no lo abre antes—, la pantalla tiembla y el
/// teléfono vibra a golpes. Soltarlo antes lo vuelve a enrollar. Se abría con un toque y se
/// leía de pasada: lo que costó abrir se lee con otra atención. Los que ya se
/// leyeron se abren solos, como siempre.
class _Detalle extends StatefulWidget {
  const _Detalle({
    super.key,
    required this.e,
    required this.consejo,
    required this.onClosed,
    this.motivo,
    this.destino,
    this.sealed = false,
  });

  /// Si hay que abrirlo a mano. Ver la clase.
  final bool sealed;

  final _Estilo e;
  final Advice consejo;
  final String? motivo;

  /// Adónde vuela al cerrarse, en coordenadas de la pantalla; nulo si se
  /// enrolla y se va sin más.
  final Rect? Function()? destino;
  final VoidCallback onClosed;

  @override
  State<_Detalle> createState() => _DetalleState();
}

class _DetalleState extends State<_Detalle> with TickerProviderStateMixin {
  bool _explica = false;

  /// Lo que asoma cerrado antes de desenrollarse.
  static const double _asoma = 0.18;

  late final AnimationController _abre = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _vuela = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  bool _cerrando = false;
  Rect? _hasta;

  @override
  void initState() {
    super.initState();
    if (_sellado) {
      // Llega hasta asomar, cerrado, y ahí espera el dedo.
      _abre.animateTo(_asoma, duration: const Duration(milliseconds: 420));
      _tiempo.start();
    } else {
      _abre.forward();
      _luego(const Duration(milliseconds: 1900));
    }
  }

  /// La explicación llega un segundo después de que se pueda leer el dicho,
  /// que es cuando el rollo terminó de abrirse.
  void _luego(Duration cuando) {
    Future<void>.delayed(cuando, () {
      if (mounted) setState(() => _explica = true);
    });
  }

  @override
  void dispose() {
    _tiempo.dispose();
    _abre.dispose();
    _vuela.dispose();
    super.dispose();
  }

  // ---------------------------------------------------- abrirlo a mano

  /// Si todavía hay que abrirlo a mano.
  late bool _sellado = widget.sealed;

  /// Cuánto lleva desenrollado a mano, de cero a uno.
  double _tira = 0;

  /// Si el dedo está encima.
  bool _apretado = false;

  /// Hasta dónde lo pidió el dedo. El rollo va detrás, a su ritmo: ver
  /// [_paso].
  double _pedido = 0;

  /// Si el dedo que está encima bajó con el rollo todavía cerrado: al
  /// levantarlo no puede contar como un toque de cerrar.
  bool _bajoCerrado = false;

  /// Cuántos golpes de vibración lleva: uno por cada décimo de rollo.
  int _golpes = 0;

  /// Segundos, para el temblor y la flecha que invita a tirar.
  double _reloj = 0;
  Duration _antes = Duration.zero;
  late final Ticker _tiempo = createTicker(_paso);

  /// Lo que hay que arrastrar el dedo, en píxeles, para abrirlo entero sin
  /// resistencia; lo más rápido que se deja abrir, en rollos por segundo; y
  /// lo que tarda en volver a enrollarse si se suelta.
  static const double _recorrido = 330, _ritmo = 0.42, _vuelve = 0.9;

  void _paso(Duration ahora) {
    final dt = ((ahora - _antes).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _antes = ahora;
    _reloj += dt;
    final antes = _tira;
    if (_sellado) {
      if (_apretado) {
        // Va detrás del dedo y nunca más deprisa que [_ritmo]: tirar fuerte
        // no lo abre antes. Un rollo que lleva mucho cerrado cede de a poco.
        final falta = _pedido - _tira;
        _tira += falta.clamp(-dt / _vuelve, dt * _ritmo);
      } else {
        // Soltado, se vuelve a enrollar.
        _tira -= dt / _vuelve;
        _pedido = _tira;
      }
      _tira = _tira.clamp(0.0, 1.0);
      final paso = (_tira * 10).floor();
      if (_apretado && paso > _golpes) Sensory.instance.charge(_tira);
      _golpes = paso;
    }
    _efectos(dt, _tira - antes);
    if (_sellado && _tira >= 1) {
      // Abierto: un golpe, un estallido de luz, y de ahí en adelante es un
      // consejo abierto más.
      _sellado = false;
      _apretado = false;
      _estallido = 0;
      _estalla();
      Sensory.instance.epic();
      _abre.value = 1;
      _luego(const Duration(milliseconds: 1000));
    }
    // Abierto y sin nada volando, se para.
    if (!_sellado &&
        _chispas.isEmpty &&
        _trozos.isEmpty &&
        (_estallido ?? 9) > 1.6) {
      _tiempo.stop();
    }
    setState(() {});
  }

  // ------------------------------------------------- lo épico

  /// Dónde está el rollo en pantalla, relativo a la escena: de ahí salen las
  /// varillas, la luz y las chispas.
  final GlobalKey _rolloKey = GlobalKey();
  final GlobalKey _escenaKey = GlobalKey();

  Rect? _rollo() {
    final r = _rolloKey.currentContext?.findRenderObject() as RenderBox?;
    final e = _escenaKey.currentContext?.findRenderObject() as RenderBox?;
    if (r == null || e == null || !r.hasSize || !e.hasSize) return null;
    final arriba = e.globalToLocal(r.localToGlobal(Offset.zero));
    return arriba & r.size;
  }

  /// Si el lacre ya se rompió: al primer tirón.
  bool _roto = false;

  /// Segundos desde que se abrió del todo, para el estallido; nulo antes.
  double? _estallido;

  final List<_Chispa> _chispas = [];
  final List<_Chispa> _trozos = [];
  final math.Random _azar = math.Random(7);

  void _efectos(double dt, double avanzo) {
    final r = _rollo();
    if (_estallido != null) _estallido = _estallido! + dt;
    if (r != null) {
      // El lacre salta al primer tirón, en pedazos.
      if (!_roto && _tira > 0.015) {
        _roto = true;
        Sensory.instance.impact(strength: 0.25);
        final c = Offset(r.center.dx, r.top + SageScroll.closed / 2);
        for (var i = 0; i < 9; i++) {
          final a = _azar.nextDouble() * math.pi * 2;
          final v = 90 + _azar.nextDouble() * 200;
          _trozos.add(
            _Chispa(
              c,
              Offset(math.cos(a) * v, math.sin(a) * v - 120),
              0.9 + _azar.nextDouble() * 0.5,
              3 + _azar.nextDouble() * 4,
              giro: (_azar.nextDouble() - 0.5) * 18,
            ),
          );
        }
      }
      // Mientras se desenrolla, chispas que suben desde la varilla de abajo:
      // más cuanto más deprisa cede.
      if (_sellado && _apretado && avanzo > 0) {
        var n = avanzo * 160 + _azar.nextDouble() * 0.6;
        while (n >= 1 || _azar.nextDouble() < n) {
          n -= 1;
          _chispas.add(
            _Chispa(
              Offset(
                r.left + 12 + _azar.nextDouble() * (r.width - 24),
                r.bottom - 4,
              ),
              Offset(
                (_azar.nextDouble() - 0.5) * 40,
                -50 - _azar.nextDouble() * 90,
              ),
              0.8 + _azar.nextDouble() * 0.9,
              1.2 + _azar.nextDouble() * 2.2,
            ),
          );
          if (n <= 0) break;
        }
      }
    }
    for (final c in _chispas) {
      c.paso(dt, gravedad: -20, roce: 0.6);
    }
    for (final c in _trozos) {
      c.paso(dt, gravedad: 640, roce: 0.2);
    }
    _chispas.removeWhere((c) => c.edad >= c.vida);
    _trozos.removeWhere((c) => c.edad >= c.vida);
  }

  /// Abierto del todo: una lluvia de chispas desde el medio del rollo.
  void _estalla() {
    final r = _rollo();
    if (r == null) return;
    for (var i = 0; i < 60; i++) {
      final a = _azar.nextDouble() * math.pi * 2;
      final v = 140 + _azar.nextDouble() * 360;
      _chispas.add(
        _Chispa(
          r.center + Offset(math.cos(a), math.sin(a)) * (r.width * 0.2),
          Offset(math.cos(a) * v, math.sin(a) * v * 0.7),
          0.6 + _azar.nextDouble() * 0.9,
          1.5 + _azar.nextDouble() * 2.5,
        ),
      );
    }
  }

  void _baja() {
    // Un dedo que baja con el rollo ya abierto es uno nuevo: si toca, cierra.
    // El que lo abrió puede haberse ido arrastrando, sin toque que lo
    // consuma, y si no se olvidara aquí se comería el toque siguiente.
    _bajoCerrado = _sellado;
    if (!_sellado) return;
    _apretado = true;
    _pedido = _tira;
    Sensory.instance.press();
  }

  /// El dedo se mueve: hacia abajo desenrolla, hacia arriba enrolla. Cuesta
  /// más al principio —los primeros centímetros se resisten— y el dedo no
  /// puede adelantarse mucho al rollo: tiene que ir con él.
  void _tirar(double dy) {
    if (!_sellado || !_apretado) return;
    final cede = 0.45 + 0.75 * _tira;
    _pedido = (_pedido + dy / _recorrido * cede).clamp(0.0, _tira + 0.2);
  }

  void _sube() => _apretado = false;

  void _toque() {
    // El dedo que lo abrió no lo cierra al levantarse.
    if (_bajoCerrado) {
      _bajoCerrado = false;
      return;
    }
    if (_sellado) return;
    _cerrar();
  }

  Future<void> _cerrar() async {
    if (_cerrando) return;
    _cerrando = true;
    Sensory.instance.tick();
    // Se enrolla: hasta la tira con sus dos cuerdas juntas.
    await _abre.animateTo(
      _asoma,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
    );
    if (!mounted) return;
    final d = widget.destino?.call();
    final caja = context.findRenderObject() as RenderBox?;
    if (d != null && caja != null) {
      final arriba = caja.globalToLocal(d.topLeft);
      _hasta = arriba & d.size;
      await _vuela.forward();
    }
    if (mounted) widget.onClosed();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final motivo = widget.motivo;
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.consejo.say,
          textAlign: TextAlign.center,
          style: e.habla(25).copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 14),
        Text(
          '~  ·  ~',
          textAlign: TextAlign.center,
          style: TextStyle(color: e.gris, fontSize: 14),
        ),
        const SizedBox(height: 14),
        AnimatedOpacity(
          opacity: _explica ? 1 : 0,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.consejo.mean,
                textAlign: TextAlign.center,
                style: e.explica,
              ),
              if (motivo != null && motivo.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(motivo, textAlign: TextAlign.center, style: e.motivo),
              ],
            ],
          ),
        ),
      ],
    );
    return Listener(
      onPointerDown: (_) => _baja(),
      onPointerMove: (d) => _tirar(d.delta.dy),
      onPointerUp: (_) => _sube(),
      onPointerCancel: (_) => _sube(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toque,
        child: AnimatedBuilder(
          animation: Listenable.merge([_abre, _vuela]),
          builder: (context, _) {
            final a = _abre.value;
            final v = Curves.easeInOutCubic.transform(_vuela.value);
            // Al llegar asoma y se desenrolla; al irse, el velo se aclara
            // mientras vuela, pero el rollo no se desvanece: se va.
            final llega = _cerrando
                ? 1.0
                : Curves.easeOut.transform((a / _asoma).clamp(0, 1));
            // Tirando de él, lo abierto es lo que se tiró: sin curva, que el
            // borde de abajo vaya con el dedo.
            final abre = _sellado
                ? _tira
                : Curves.easeInOutCubic.transform(
                    ((a - _asoma) / (1 - _asoma)).clamp(0, 1),
                  );
            // Cerrado, tiembla apenas; mientras se lo abre, cada vez más.
            final tiembla = _sellado
                ? (_apretado ? 1.0 + 3.5 * _tira : 0.6 * (1 - _tira))
                : 0.0;
            final temblor = Offset(
              math.sin(_reloj * 53) * tiembla,
              math.cos(_reloj * 47) * tiembla * 0.6,
            );
            final velo = _cerrando ? 1 - v : llega;
            return ColoredBox(
              // El de un consejo nuevo, más oscuro: es un momento.
              color: Colors.black.withValues(
                alpha: (widget.sealed ? 0.62 : 0.30) * velo,
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final hasta = _hasta;
                  // El que se abre tirando cuelga de arriba: la cuerda de
                  // arriba se queda quieta y la de abajo baja con el dedo.
                  final arriba = box.maxHeight * 0.18;
                  if (hasta == null || v == 0) {
                    final rollo = Opacity(
                      opacity: llega,
                      child: Padding(
                        // El nuevo, más angosto: las varillas con sus
                        // remates sobresalen del rollo y tienen que caber.
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.sealed ? 34 : 16,
                        ),
                        child: SageScroll(
                          key: widget.sealed ? _rolloKey : null,
                          open: abre,
                          fromTop: widget.sealed,
                          padding: const EdgeInsets.fromLTRB(36, 34, 36, 34),
                          child: contenido,
                        ),
                      ),
                    );
                    if (!widget.sealed) return Center(child: rollo);
                    final rect = _rollo();
                    return Stack(
                      key: _escenaKey,
                      children: [
                        // Detrás: la luz que sale del rollo.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _Luz(
                                rect,
                                _tira,
                                _apretado,
                                _estallido,
                                _reloj,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: arriba,
                          child: Transform.translate(
                            offset: temblor,
                            child: Column(
                              children: [
                                rollo,
                                // El sitio de la piola que cuelga de la
                                // varilla de abajo. La dibuja [_Frente];
                                // aquí sólo se le guarda el hueco.
                                if (_sellado)
                                  const SizedBox(key: sageCordKey, height: 70),
                              ],
                            ),
                          ),
                        ),
                        // Delante: las varillas, el lacre, las chispas y el
                        // fogonazo.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _Frente(
                                rect?.shift(temblor),
                                piola: _sellado ? llega : 0,
                                tirando: _apretado,
                                tira: _tira,
                                reloj: _reloj,
                                roto: _roto,
                                chispas: _chispas,
                                trozos: _trozos,
                                estallido: _estallido,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  final desde = widget.sealed
                      ? Rect.fromLTWH(
                          34,
                          arriba,
                          box.maxWidth - 68,
                          SageScroll.closed,
                        )
                      : Rect.fromCenter(
                          center: box.biggest.center(Offset.zero),
                          width: box.maxWidth - 32,
                          height: SageScroll.closed,
                        );
                  final r = Rect.lerp(desde, hasta, v)!;
                  return Stack(
                    children: [
                      Positioned.fromRect(
                        rect: r,
                        child: const SageScroll(open: 0, child: SizedBox()),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Una chispa, o un trozo de lacre: algo que vuela un rato y se apaga.
class _Chispa {
  _Chispa(this.p, this.v, this.vida, this.tam, {this.giro = 0});
  Offset p;
  Offset v;
  final double vida;
  final double tam;
  final double giro;
  double edad = 0;

  void paso(double dt, {required double gravedad, required double roce}) {
    edad += dt;
    v = v * math.max(0, 1 - roce * dt) + Offset(0, gravedad * dt);
    p += v * dt;
  }

  /// Cuánto le queda, de uno a cero.
  double get queda => (1 - edad / vida).clamp(0.0, 1.0);
}

const Color _oro = Color(0xFFFFD27A);

/// El hueco de la piola bajo un consejo nuevo, mientras está sellado. Para
/// que los tests sepan si sigue cerrado.
const Key sageCordKey = ValueKey('sage-cord');

/// La luz que sale del rollo mientras se abre: un halo dorado detrás que
/// crece con lo abierto, una raya de luz en la boca por donde se desenrolla,
/// y al abrirse del todo, el fogonazo.
class _Luz extends CustomPainter {
  _Luz(this.rect, this.tira, this.tirando, this.estallido, this.reloj);
  final Rect? rect;
  final double tira;
  final bool tirando;
  final double? estallido;
  final double reloj;

  @override
  void paint(Canvas c, Size s) {
    final r = rect;
    if (r == null) return;
    final late = 0.85 + 0.15 * math.sin(reloj * 2.6);
    final fuego = estallido == null ? 0.0 : math.max(0.0, 1 - estallido! / 1.2);
    final halo = (0.10 + 0.45 * tira) * late + 0.5 * fuego;
    final radio = math.max(r.width * 0.75, r.height * 1.1) * (1 + 0.4 * fuego);
    c.drawCircle(
      r.center,
      radio,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _oro.withValues(alpha: halo.clamp(0.0, 1.0)),
            _oro.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: r.center, radius: radio)),
    );
    // La boca: por donde se está desenrollando sale luz.
    if (tirando && tira > 0) {
      final boca = Rect.fromCenter(
        center: r.bottomCenter,
        width: r.width * 1.1,
        height: 46,
      );
      c.drawOval(
        boca,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF1C9).withValues(alpha: 0.55 * late),
              _oro.withValues(alpha: 0),
            ],
          ).createShader(boca),
      );
    }
  }

  @override
  bool shouldRepaint(_Luz old) => true;
}

/// Lo que va delante del rollo: las varillas de madera, el lacre mientras no
/// se rompa, sus trozos, las chispas y el fogonazo con su onda.
class _Frente extends CustomPainter {
  _Frente(
    this.rect, {
    required this.piola,
    required this.tirando,
    required this.tira,
    required this.reloj,
    required this.roto,
    required this.chispas,
    required this.trozos,
    required this.estallido,
  });
  final Rect? rect;

  /// Cuánto se ve la piola: nada una vez abierto.
  final double piola;
  final bool tirando;
  final double tira;
  final double reloj;
  final bool roto;
  final List<_Chispa> chispas;
  final List<_Chispa> trozos;
  final double? estallido;

  static const _madera = Color(0xFF5B3A1E);
  static const _maderaClara = Color(0xFF8A5E33);
  static const _lacre = Color(0xFF8E1B1B);

  /// Una varilla de madera con sus remates, de [x0] a [x1] a la altura [y].
  /// La usan también los rollos de la lista, para que todos los rollos del
  /// viejo sean del mismo taller.
  static void varilla(Canvas c, double y, double x0, double x1) => _Frente(
    null,
    piola: 0,
    tirando: false,
    tira: 0,
    reloj: 0,
    roto: true,
    chispas: const [],
    trozos: const [],
    estallido: null,
  )._varilla(c, y, x0, x1);

  void _varilla(Canvas c, double y, double x0, double x1) {
    final barra = RRect.fromLTRBR(
      x0 - 10,
      y - 5,
      x1 + 10,
      y + 5,
      const Radius.circular(5),
    );
    c.drawRRect(
      barra.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    c.drawRRect(barra, Paint()..color = _madera);
    c.drawLine(
      Offset(x0 - 6, y - 2),
      Offset(x1 + 6, y - 2),
      Paint()
        ..color = _maderaClara
        ..strokeWidth = 1.5,
    );
    for (final x in [x0 - 14, x1 + 14]) {
      c.drawCircle(Offset(x, y), 8, Paint()..color = _madera);
      c.drawCircle(Offset(x - 2, y - 2), 3, Paint()..color = _maderaClara);
    }
  }

  /// La piola que cuelga del medio de la varilla de abajo, con su nudo y su
  /// borla: de donde se tira, aunque tirar valga desde cualquier sitio.
  ///
  /// Quieta, se mece y cada tanto da un tironcito hacia abajo, solo, como si
  /// alguien del otro lado la probara. Tirando, se tensa y se estira.
  void _piola(Canvas c, Offset desde) {
    // El tironcito: cada dos segundos y medio, un bajón corto que vuelve.
    final ciclo = (reloj % 2.5) / 2.5;
    final tiron = ciclo < 0.18 ? math.sin(ciclo / 0.18 * math.pi) : 0.0;
    final largo = tirando ? 58.0 + 10 * tira : 46.0 + 9 * tiron;
    final mece = tirando ? 0.0 : math.sin(reloj * 1.7) * 7 * (1 - tiron * 0.6);
    final punta = desde + Offset(mece, largo);
    // Floja, la cuerda hace panza hacia el lado contrario al vaivén; tensa,
    // va derecha.
    final panza = tirando ? 0.0 : -mece * 0.6;
    final medio = Offset(
      (desde.dx + punta.dx) / 2 + panza,
      (desde.dy + punta.dy) / 2,
    );
    final cuerda = Path()
      ..moveTo(desde.dx, desde.dy)
      ..quadraticBezierTo(medio.dx, medio.dy, punta.dx, punta.dy);
    final a = piola.clamp(0.0, 1.0);
    c.drawPath(
      cuerda,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tirando ? 2.6 : 3.0
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF6B4A26).withValues(alpha: a),
    );
    // El trenzado: rayitas claras a lo largo, que es lo que la hace cuerda
    // y no un alambre.
    final metrica = cuerda.computeMetrics().firstOrNull;
    if (metrica != null) {
      final raya = Paint()
        ..strokeWidth = 1.1
        ..color = const Color(0xFFB08A55).withValues(alpha: a);
      for (var d = 4.0; d < metrica.length - 2; d += 5) {
        final t = metrica.getTangentForOffset(d);
        if (t == null) continue;
        final n = Offset(-t.vector.dy, t.vector.dx);
        c.drawLine(
          t.position - n * 1.4 - t.vector * 1.2,
          t.position + n * 1.4 + t.vector * 1.2,
          raya,
        );
      }
    }
    // El nudo y la borla.
    c.drawCircle(
      punta,
      4.6,
      Paint()..color = const Color(0xFF5A3A1E).withValues(alpha: a),
    );
    final borla = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8E1B1B).withValues(alpha: a);
    for (var k = -2; k <= 2; k++) {
      final abre = k * 2.4 + (tirando ? 0 : mece * 0.15);
      c.drawLine(punta + Offset(k * 1.2, 3), punta + Offset(abre, 15), borla);
    }
  }

  @override
  void paint(Canvas c, Size s) {
    final r = rect;
    if (r != null) {
      if (piola > 0) _piola(c, Offset(r.center.dx, r.bottom - 1));
      _varilla(c, r.top + 3, r.left + 6, r.right - 6);
      _varilla(c, r.bottom - 3, r.left + 6, r.right - 6);
      if (!roto) {
        // El lacre, sobre la tira cerrada.
        final o = Offset(r.center.dx, r.top + r.height / 2);
        c.drawCircle(
          o + const Offset(0, 2),
          17,
          Paint()..color = Colors.black.withValues(alpha: 0.4),
        );
        c.drawCircle(o, 17, Paint()..color = _lacre);
        c.drawCircle(
          o,
          12,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0xFF5E0F0F),
        );
        final estrella = Path();
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4 - math.pi / 2;
          final rr = i.isEven ? 7.5 : 3.0;
          final q = o + Offset(math.cos(a) * rr, math.sin(a) * rr);
          i == 0 ? estrella.moveTo(q.dx, q.dy) : estrella.lineTo(q.dx, q.dy);
        }
        estrella.close();
        c.drawPath(estrella, Paint()..color = const Color(0xFFB8403A));
        c.drawCircle(
          o + const Offset(-6, -6),
          3.5,
          Paint()..color = Colors.white.withValues(alpha: 0.25),
        );
      }
    }
    for (final t in trozos) {
      final k = t.queda;
      c.save();
      c.translate(t.p.dx, t.p.dy);
      c.rotate(t.giro * t.edad);
      c.drawPath(
        Path()
          ..moveTo(-t.tam, -t.tam * 0.6)
          ..lineTo(t.tam * 0.9, -t.tam * 0.3)
          ..lineTo(t.tam * 0.4, t.tam * 0.8)
          ..close(),
        Paint()..color = _lacre.withValues(alpha: k),
      );
      c.restore();
    }
    for (final ch in chispas) {
      final k = ch.queda;
      c.drawCircle(
        ch.p,
        ch.tam * 2.6,
        Paint()..color = _oro.withValues(alpha: 0.18 * k),
      );
      c.drawCircle(
        ch.p,
        ch.tam,
        Paint()..color = const Color(0xFFFFF4D6).withValues(alpha: k),
      );
    }
    // El fogonazo y su onda.
    final e = estallido;
    if (e != null && e < 1.2 && r != null) {
      final k = 1 - e / 1.2;
      c.drawRect(
        Offset.zero & s,
        Paint()
          ..color = const Color(0xFFFFF1C9).withValues(alpha: 0.45 * k * k * k),
      );
      c.drawCircle(
        r.center,
        40 + e * 520,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * k
          ..color = _oro.withValues(alpha: 0.7 * k),
      );
    }
  }

  @override
  bool shouldRepaint(_Frente old) => true;
}

/// El viejo de la plaza, en tres dimensiones: las mismas cajas con las que
/// anda por el pueblo (`folkSolids`), puestas de pie, mirando un poco hacia
/// vos y respirando.
///
/// Las mismas y no un dibujo aparte: si algún día cambia cómo se ve en la
/// plaza, cambia acá solo.
class SageFigure extends StatefulWidget {
  const SageFigure({super.key});

  @override
  State<SageFigure> createState() => _SageFigureState();
}

class _SageFigureState extends State<SageFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reloj = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  /// El viejo de verdad: el de la plaza del primer pueblo.
  static final Townsfolk _sabio = Townsfolk.sage(
    TownLayout(0, TownCharacter.all.first),
  );

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _reloj,
    builder: (_, _) =>
        CustomPaint(painter: _FiguraPainter(_sabio, _reloj.value * 60)),
  );
}

class _FiguraPainter extends CustomPainter {
  _FiguraPainter(this.who, this.t);

  final Townsfolk who;

  /// Segundos.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Mirando un poco hacia la derecha, que es donde está lo que dice, y
    // girando apenas la cabeza con el aire.
    final at = FolkAt(
      0,
      0,
      0.45 + math.sin(t * 0.25) * 0.08,
      0,
      false,
      Doing.idle,
      t,
    );
    final solids = folkSolids(who, at, 1.0);
    // La cámara, un poco desde arriba y de frente.
    const ojo = V3(0.15, 0.72, 2.6);
    const mira = V3(0, 0.5, 0);
    final fwd = (mira - ojo).normalized;
    final right = fwd.cross(const V3(0, 1, 0)).normalized;
    final up = right.cross(fwd).normalized;
    Offset? crudo(V3 v) {
      final d = v - ojo;
      final z = d.dot(fwd);
      if (z <= 0.05) return null;
      return Offset(d.dot(right) / z, -d.dot(up) / z);
    }

    // **Se encuadra solo**: lo que ocupa la figura de verdad, escalado para
    // que entre de los pies a la coronilla en lo que le toca, apoyada abajo.
    // Con una lente puesta a mano salía cortada o perdida, según el teléfono.
    var x0 = double.infinity, x1 = -double.infinity;
    var y0 = double.infinity, y1 = -double.infinity;
    for (final s in solids) {
      for (final f in s.faces) {
        for (final v in f.v) {
          final q = crudo(v);
          if (q == null) continue;
          x0 = math.min(x0, q.dx);
          x1 = math.max(x1, q.dx);
          y0 = math.min(y0, q.dy);
          y1 = math.max(y1, q.dy);
        }
      }
    }
    if (!x0.isFinite) return;
    final escala = math.min(
      size.height * 0.94 / (y1 - y0),
      size.width * 0.96 / (x1 - x0),
    );
    final dx = size.width / 2 - (x0 + x1) / 2 * escala;
    final dy = size.height - y1 * escala - size.height * 0.02;
    Offset? proyectar(V3 v) {
      final q = crudo(v);
      return q == null ? null : Offset(q.dx * escala + dx, q.dy * escala + dy);
    }

    // La sombra en el suelo.
    final pie = proyectar(const V3(0, 0, 0));
    if (pie != null) {
      canvas.drawOval(
        Rect.fromCenter(
          center: pie,
          width: size.width * 0.62,
          height: size.width * 0.13,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    const luz = V3(-0.45, 0.8, 0.55);
    final l = luz.normalized;
    // Cara por cara y no caja por caja: el pelo es una caja que se mete en la
    // cabeza y cae por detrás, así que su medio queda más lejos que el de la
    // cabeza, se pintaba antes, y la coronilla le tapaba el pelo — de cerca
    // el viejo salía calvo. El árbol corta lo que se cruza y lo ordena bien.
    final caras = <Facet>[];
    BspTree.build([for (final s in solids) ...s.faces]).paint(ojo, caras.add);
    for (final f in caras) {
      final c = f.v.fold(V3.zero, (a, v) => a + v) * (1 / f.v.length);
      if ((c - ojo).dot(f.n) >= 0) continue; // de espaldas
      final pts = <Offset>[];
      for (final v in f.v) {
        final p = proyectar(v);
        if (p == null) break;
        pts.add(p);
      }
      if (pts.length != f.v.length) continue;
      final base = Color(f.tint ?? 0xFF888888);
      final k = (0.62 + 0.42 * math.max(0, f.n.dot(l))) * f.ao;
      final color = Color.fromARGB(
        255,
        (base.r * 255 * k).clamp(0, 255).round(),
        (base.g * 255 * k).clamp(0, 255).round(),
        (base.b * 255 * k).clamp(0, 255).round(),
      );
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_FiguraPainter old) => old.t != t;
}
