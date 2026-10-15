import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/math3.dart';
import '../data/advice.dart';
import '../data/character.dart';
import '../data/doings.dart';
import '../engine/folk.dart';
import '../engine/folk_body.dart';
import '../engine/town.dart';
import '../fx/sensory.dart';
import '../l10n/lang.dart';
import '../model/advice_book.dart';
import '../model/store.dart';
import 'style.dart';

/// Cómo se visten las tarjetas y lo que dice el viejo. Tres pruebas, para
/// elegir mirándolas.
enum SageLook {
  /// Hojitas de pergamino como las del tablón, un poco torcidas, con letra a
  /// mano; lo que dice, en un globo de papel.
  paper,

  /// Vidrio esmerilado claro y letra de libro, oscura.
  glass,

  /// Un solo pergamino con los dichos uno debajo del otro, como un libro de
  /// sabio; lo que dice, en un globo de papel.
  scroll,
}

/// Todo lo que cambia de un estilo a otro, en un solo sitio.
class _Estilo {
  const _Estilo(this.look);
  final SageLook look;

  Color get tinta => switch (look) {
    SageLook.paper => const Color(0xFF3B2F22),
    SageLook.glass => const Color(0xFF2B2722),
    SageLook.scroll => const Color(0xFF3A2C1C),
  };

  /// La explicación, en gris.
  Color get gris => switch (look) {
    SageLook.paper => const Color(0xFF3B2F22).withValues(alpha: 0.62),
    SageLook.glass => const Color(0xFF6B655C),
    SageLook.scroll => const Color(0xFF3A2C1C).withValues(alpha: 0.60),
  };

  Color get papel => switch (look) {
    SageLook.paper => const Color(0xFFEFE4C6),
    SageLook.glass => Colors.white.withValues(alpha: 0.80),
    SageLook.scroll => const Color(0xFFEBDCB3),
  };

  /// El globo de lo que dice: de papel en los dos de papel.
  Color get globo => switch (look) {
    SageLook.glass => Colors.white.withValues(alpha: 0.86),
    _ => const Color(0xFFF6EEDA),
  };

  TextStyle dicho(double size) => switch (look) {
    SageLook.paper => TextStyle(
      fontFamily: 'ArchitectsDaughter',
      fontSize: size * 0.95,
      height: 1.3,
      color: tinta,
      fontWeight: FontWeight.w600,
    ),
    SageLook.glass => TextStyle(
      fontFamily: 'EBGaramond',
      fontSize: size * 1.06,
      height: 1.28,
      color: tinta,
      fontWeight: FontWeight.w500,
    ),
    SageLook.scroll => TextStyle(
      fontFamily: 'EBGaramond',
      fontSize: size * 1.06,
      height: 1.3,
      fontStyle: FontStyle.italic,
      color: tinta,
    ),
  };

  TextStyle habla(double size) => switch (look) {
    SageLook.glass => TextStyle(
      fontFamily: 'EBGaramond',
      fontSize: size,
      height: 1.35,
      color: tinta,
    ),
    _ => TextStyle(
      fontFamily: 'EBGaramond',
      fontSize: size,
      height: 1.35,
      color: tinta,
    ),
  };

  TextStyle get explica => TextStyle(color: gris, fontSize: 15.5, height: 1.5);

  List<BoxShadow> get sombra => [
    BoxShadow(
      color: Colors.black.withValues(
        alpha: look == SageLook.glass ? 0.12 : 0.26,
      ),
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

  /// El estilo. Una variable y no una constante, para poder comparar los tres
  /// en capturas; cuando se elija uno, los otros se van.
  static SageLook look = SageLook.paper;

  static Route<void> route({required Store store, required UiTheme theme}) =>
      PageRouteBuilder<void>(
        opaque: false,
        // Apenas un velo: el valle se tiene que seguir viendo.
        barrierColor: Colors.black.withValues(alpha: 0.10),
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
  final _Estilo _e = _Estilo(SageScreen.look);

  /// Lo que no se había mirado al entrar: lleva su marca mientras se está
  /// acá, aunque entrar ya lo dé por visto.
  late final Set<String> _nuevos = {
    for (final (a, _) in _libro.unlocked())
      if (_libro.isNew(a)) a.id,
  };

  /// Lo que dijo al contestar la pregunta, si se acaba de contestar.
  String? _respuesta;

  /// El consejo que se está mirando de cerca, o nulo.
  Advice? _abierto;

  @override
  void initState() {
    super.initState();
    _libro.markAllSeen();
  }

  void _contestar(AdviceGoal g) {
    Sensory.instance.tick();
    final store = widget.store;
    _libro.setGoal(store.habit.id, g);
    final hoy = _libro.visit(store.habits);
    setState(() {
      _nuevos.addAll(hoy.map((a) => a.id));
      _respuesta = g == AdviceGoal.start
          ? SageLines.afterStart
          : SageLines.afterQuit;
    });
    _libro.markAllSeen();
  }

  void _abrir(Advice a) {
    Sensory.instance.tick();
    setState(() => _abierto = a);
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    final pregunta = _libro.goalOf(widget.store.habit.id) == null;
    final todo = _libro.unlocked();
    final hoy = _libro.today();
    // Lo que dice ahora, en el globo.
    final String dice;
    if (pregunta) {
      dice = todo.isEmpty
          ? '${SageLines.hello}\n\n${SageLines.question}'
          : SageLines.question;
    } else if (_respuesta != null) {
      dice = hoy == null ? _respuesta! : '${_respuesta!}\n\n«${hoy.say}»';
    } else if (hoy != null) {
      dice = '«${hoy.say}»';
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
                  child: _Lista(
                    e: e,
                    dichos: todo,
                    nuevos: _nuevos,
                    onTap: _abrir,
                  ),
                ),
                SizedBox(
                  height: math.min(360, alto * 0.42),
                  child: _Habla(
                    e: e,
                    dice: dice,
                    pregunta: pregunta,
                    onAnswer: _contestar,
                    onTap: !pregunta && hoy != null ? () => _abrir(hoy) : null,
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
                onClose: () => setState(() => _abierto = null),
              ),
            ),
        ],
      ),
    );
  }
}

/// Un fondo del estilo: papel con su filete, vidrio claro o pergamino.
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
  Widget build(BuildContext context) {
    final r = e.look == SageLook.glass ? 22.0 : 3.0;
    Widget caja = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: e.papel,
        borderRadius: BorderRadius.circular(r),
        boxShadow: e.sombra,
        border: e.look == SageLook.glass
            ? Border.all(color: Colors.white.withValues(alpha: 0.9))
            : null,
      ),
      child: e.look == SageLook.paper
          // El filete de dentro, como las hojas del tablón.
          ? DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: e.tinta.withValues(alpha: 0.16)),
              ),
              child: Padding(padding: const EdgeInsets.all(8), child: child),
            )
          : child,
    );
    if (e.look == SageLook.glass) {
      caja = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: caja,
        ),
      );
    }
    return caja;
  }
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

/// Lo que te dijo, el más nuevo arriba: cada cosa en su hoja, o todas en un
/// mismo pergamino.
class _Lista extends StatelessWidget {
  const _Lista({
    required this.e,
    required this.dichos,
    required this.nuevos,
    required this.onTap,
  });

  final _Estilo e;
  final List<(Advice, DateTime)> dichos;
  final Set<String> nuevos;
  final void Function(Advice) onTap;

  Widget _marca() => Container(
    width: 8,
    height: 8,
    margin: const EdgeInsets.only(left: 10, top: 6),
    decoration: const BoxDecoration(
      color: Color(0xFFC8742E),
      shape: BoxShape.circle,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (dichos.isEmpty) return const SizedBox.shrink();
    final Widget lista;
    if (e.look == SageLook.scroll) {
      lista = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: _Pergamino(
          e: e,
          child: Column(
            children: [
              for (var i = 0; i < dichos.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '~  ·  ~',
                      style: TextStyle(color: e.tinta.withValues(alpha: 0.35)),
                    ),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(dichos[i].$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            dichos[i].$1.say,
                            textAlign: TextAlign.center,
                            style: e.dicho(18),
                          ),
                        ),
                        if (nuevos.contains(dichos[i].$1.id)) _marca(),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      lista = ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        itemCount: dichos.length,
        separatorBuilder: (_, _) =>
            SizedBox(height: e.look == SageLook.paper ? 14 : 10),
        itemBuilder: (context, i) {
          final (a, _) = dichos[i];
          // Las hojas, un poco torcidas cada una para su lado, como
          // clavadas a mano.
          final giro = e.look == SageLook.paper
              ? ((a.id.hashCode % 7) - 3) * 0.0045
              : 0.0;
          return Transform.rotate(
            angle: giro,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(a),
              child: _Fondo(
                e: e,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(a.say, style: e.dicho(18))),
                    if (nuevos.contains(a.id)) _marca(),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
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

/// Un pergamino: el papel, más oscuro en los bordes, y los dos rollos.
class _Pergamino extends StatelessWidget {
  const _Pergamino({required this.e, required this.child});
  final _Estilo e;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget rollo() => Container(
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCDB07A), Color(0xFF9C7A46), Color(0xFFB8965E)],
        ),
        boxShadow: e.sombra,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        rollo(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFD9C18C),
                Color(0xFFEBDCB3),
                Color(0xFFEBDCB3),
                Color(0xFFD9C18C),
              ],
              stops: [0, 0.12, 0.88, 1],
            ),
            boxShadow: e.sombra,
          ),
          child: child,
        ),
        rollo(),
      ],
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
    final r = e.look == SageLook.glass ? 20.0 : 14.0;
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
  bool shouldRepaint(_GloboPainter old) => old.e.look != e.look;
}

/// El viejo abajo a la izquierda, grande, y lo que dice a su derecha.
class _Habla extends StatelessWidget {
  const _Habla({
    required this.e,
    required this.dice,
    required this.pregunta,
    required this.onAnswer,
    this.onTap,
  });

  final _Estilo e;
  final String dice;
  final bool pregunta;
  final void Function(AdviceGoal) onAnswer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget respuesta(String texto, AdviceGoal g) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onAnswer(g),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: e.globo,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: e.tinta.withValues(alpha: 0.35)),
            boxShadow: e.sombra,
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: e.tinta,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
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
            bottom: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              child: Column(
                key: ValueKey(dice),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: _Globo(
                      e: e,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dice, style: e.habla(17)),
                          if (onTap != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                tr(
                                  'Tocá para que te lo explique',
                                  'Tap to hear what he means',
                                ),
                                style: TextStyle(color: e.gris, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (pregunta) ...[
                    respuesta(SageLines.answerStart, AdviceGoal.start),
                    respuesta(SageLines.answerQuit, AdviceGoal.quit),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un consejo de cerca: el dicho, y debajo, un segundo después, lo que
/// quiere decir, en gris.
///
/// El segundo de espera es a propósito: primero se lee la frase sola, como si
/// te la dijera, y después llega la aclaración. Juntas de entrada, el ojo se
/// va a la explicación y el dicho se pierde.
class _Detalle extends StatefulWidget {
  const _Detalle({
    super.key,
    required this.e,
    required this.consejo,
    required this.onClose,
  });

  final _Estilo e;
  final Advice consejo;
  final VoidCallback onClose;

  @override
  State<_Detalle> createState() => _DetalleState();
}

class _DetalleState extends State<_Detalle> {
  bool _explica = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _explica = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.consejo.say, style: e.dicho(25)),
        const SizedBox(height: 18),
        AnimatedOpacity(
          opacity: _explica ? 1 : 0,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          child: Text(widget.consejo.mean, style: e.explica),
        ),
      ],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, a, child) => ColoredBox(
          color: Colors.black.withValues(alpha: 0.30 * a),
          child: Opacity(
            opacity: a,
            child: Transform.scale(scale: 0.94 + 0.06 * a, child: child),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: e.look == SageLook.scroll
                ? _Pergamino(e: e, child: contenido)
                : _Fondo(
                    e: e,
                    padding: const EdgeInsets.fromLTRB(26, 26, 26, 28),
                    child: contenido,
                  ),
          ),
        ),
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
