import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/math3.dart';
import '../data/advice.dart';
import '../data/character.dart';
import '../data/doings.dart';
import '../engine/folk.dart';
import '../engine/folk_body.dart';
import '../engine/town.dart';
import '../fx/sensory.dart';
import '../model/advice_book.dart';
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
  const SageScreen({super.key, required this.store, required this.theme});

  final Store store;
  final UiTheme theme;

  static Route<void> route({required Store store, required UiTheme theme}) =>
      PageRouteBuilder<void>(
        opaque: false,
        // Un velo, pero que se note: el valle se sigue viendo, más apagado.
        barrierColor: Colors.black.withValues(alpha: 0.32),
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => SageScreen(store: store, theme: theme),
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
    } else if (_respuesta != null) {
      dice = _respuesta!;
    } else {
      dice = SageLines.nothingNew;
    }
    final alto = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
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
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 10, 0),
                    child: _Redondo(
                      e: e,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: e.tinta,
                      ),
                    ),
                  ),
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
                SizedBox(
                  height: math.min(360, alto * 0.42),
                  child: _Habla(
                    e: e,
                    dice: _abierto != null && _dando ? '' : dice,
                    respuestas: _abierto != null ? const [] : respuestas,
                    onNext: _abierto != null ? null : sigue,
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

/// Una hoja de papel, con su filete por dentro como las del tablón.
class _Fondo extends StatelessWidget {
  const _Fondo({
    required this.e,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 15),
  });

  final _Estilo e;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: e.papel,
      borderRadius: BorderRadius.circular(3),
      boxShadow: e.sombra,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: e.tinta.withValues(alpha: 0.16)),
      ),
      child: Padding(padding: const EdgeInsets.all(8), child: child),
    ),
  );
}

/// El botón redondo de cerrar.
class _Redondo extends StatelessWidget {
  const _Redondo({required this.e, required this.child, required this.onTap});
  final _Estilo e;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: e.globo,
        shape: BoxShape.circle,
        boxShadow: e.sombra,
      ),
      child: child,
    ),
  );
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
  static const EdgeInsets margen = EdgeInsets.fromLTRB(18, 14, 18, 14);

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
                  builder: (_, t, child) => SageScroll(open: t, child: child!),
                  child: texto,
                )
              : SageScroll(child: texto),
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
    // La colita, abajo a la izquierda, apuntando hacia la boca del viejo.
    final cola = Path()
      ..moveTo(0, size.height - 46)
      ..lineTo(-16, size.height - 18)
      ..lineTo(0, size.height - 24)
      ..close();
    final todo = Path()
      ..addRRect(cuerpo)
      ..addPath(cola, Offset.zero);
    canvas.drawShadow(todo, Colors.black.withValues(alpha: 0.4), 6, false);
    canvas.drawPath(todo, Paint()..color = e.globo);
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
  });

  final _Estilo e;
  final String dice;

  /// Si lo que dice sigue en otro globo: tocar éste pasa al siguiente.
  final VoidCallback? onNext;

  /// Lo que se le puede contestar, en hojitas debajo del globo.
  final List<(String, VoidCallback)> respuestas;

  @override
  Widget build(BuildContext context) {
    // Las respuestas, como dos hojitas más: el mismo papel, el mismo filete
    // y la misma letra que lo que te dice, un poco torcidas cada una para su
    // lado. Eran pastillas redondas con letra de sistema, y se leían como
    // botones de otra app pegados encima.
    Widget respuesta(String texto, VoidCallback hacer, double giro) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Transform.rotate(
        angle: giro,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: hacer,
          child: _Fondo(
            e: e,
            padding: const EdgeInsets.all(5),
            child: Text(texto, style: e.dicho(17)),
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, box) => Stack(
        clipBehavior: Clip.none,
        children: [
          // El viejo, de cuerpo entero, ocupando la esquina.
          Positioned(
            left: -box.maxHeight * 0.06,
            bottom: 0,
            width: box.maxHeight * 0.62,
            height: box.maxHeight,
            child: const IgnorePointer(child: SageFigure()),
          ),
          Positioned(
            left: box.maxHeight * 0.52,
            right: 14,
            // A la altura de su cara, y no a sus pies: el globo sale de su
            // boca. Pegado abajo, una frase corta quedaba lejos de él, al
            // nivel del suelo.
            bottom: box.maxHeight * 0.40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
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
                      respuestas: [
                        for (final (i, (texto, hacer)) in respuestas.indexed)
                          respuesta(texto, hacer, i.isEven ? -0.012 : 0.010),
                      ],
                    ),
                ],
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
  });

  final _Estilo e;
  final String texto;
  final List<Widget> respuestas;
  final VoidCallback? onNext;

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
                        children: [
                          TextSpan(text: widget.texto.substring(0, n)),
                          TextSpan(
                            text: widget.texto.substring(n),
                            style: const TextStyle(color: Colors.transparent),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onNext != null)
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
class _Detalle extends StatefulWidget {
  const _Detalle({
    super.key,
    required this.e,
    required this.consejo,
    required this.onClosed,
    this.motivo,
    this.destino,
  });

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
  )..forward();
  late final AnimationController _vuela = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  bool _cerrando = false;
  Rect? _hasta;

  @override
  void initState() {
    super.initState();
    // La explicación llega un segundo después de que se pueda leer el
    // dicho, que es cuando el rollo terminó de abrirse.
    Future<void>.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _explica = true);
    });
  }

  @override
  void dispose() {
    _abre.dispose();
    _vuela.dispose();
    super.dispose();
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _cerrar,
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
          final abre = Curves.easeInOutCubic.transform(
            ((a - _asoma) / (1 - _asoma)).clamp(0, 1),
          );
          final velo = _cerrando ? 1 - v : llega;
          return ColoredBox(
            color: Colors.black.withValues(alpha: 0.30 * velo),
            child: LayoutBuilder(
              builder: (context, box) {
                final hasta = _hasta;
                if (hasta == null || v == 0) {
                  return Center(
                    child: Opacity(
                      opacity: llega,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SageScroll(
                          open: abre,
                          padding: const EdgeInsets.fromLTRB(36, 34, 36, 34),
                          child: contenido,
                        ),
                      ),
                    ),
                  );
                }
                final desde = Rect.fromCenter(
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
    );
  }
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
    for (final s in folkInPaintOrder(solids, ojo)) {
      for (final f in s.faces) {
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
  }

  @override
  bool shouldRepaint(_FiguraPainter old) => old.t != t;
}
