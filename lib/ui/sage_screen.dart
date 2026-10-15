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

/// El consejero, de cerca.
///
/// No es un menú con una lista: es el viejo —el mismo de la plaza, en tres
/// dimensiones y grande— abajo a la izquierda, diciéndote algo a su derecha.
/// Lo que te fue diciendo queda arriba, cada cosa en su tarjeta, del más
/// nuevo al más viejo, y de cada una se ve sólo el dicho. Tocar una es
/// pedirle que te la explique.
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
        // Apenas un velo: el valle se tiene que seguir viendo.
        barrierColor: Colors.black.withValues(alpha: 0.12),
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
    final t = widget.theme;
    final velo = SheetInk.of(t);
    final pregunta = _libro.goalOf(widget.store.habit.id) == null;
    final todo = _libro.unlocked();
    final hoy = _libro.today();
    // Lo que dice ahora, a su derecha.
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
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: _Vidrio(
                      velo: velo,
                      radius: 22,
                      padding: EdgeInsets.zero,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: velo.suave,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _Lista(
                    velo: velo,
                    dichos: todo,
                    nuevos: _nuevos,
                    onTap: _abrir,
                  ),
                ),
                SizedBox(
                  height: math.min(360, alto * 0.42),
                  child: _Habla(
                    velo: velo,
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
                velo: velo,
                consejo: _abierto!,
                onClose: () => setState(() => _abierto = null),
              ),
            ),
        ],
      ),
    );
  }
}

/// Un vidrio ahumado, del mismo que las hojas de la app: lo que se apoya
/// sobre el valle sin taparlo.
class _Vidrio extends StatelessWidget {
  const _Vidrio({
    required this.velo,
    required this.child,
    this.radius = 18,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 14),
    this.onTap,
  });

  final SheetInk velo;
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final caja = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: math.max(velo.bruma, 14),
          sigmaY: math.max(velo.bruma, 14),
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: velo.tinte.withValues(alpha: math.min(velo.tapa, 0.78)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: velo.canto),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return caja;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: caja,
    );
  }
}

/// Lo que te dijo, cada cosa en su tarjeta, el más nuevo arriba.
class _Lista extends StatelessWidget {
  const _Lista({
    required this.velo,
    required this.dichos,
    required this.nuevos,
    required this.onTap,
  });

  final SheetInk velo;
  final List<(Advice, DateTime)> dichos;
  final Set<String> nuevos;
  final void Function(Advice) onTap;

  @override
  Widget build(BuildContext context) {
    if (dichos.isEmpty) return const SizedBox.shrink();
    return ShaderMask(
      // Las de arriba se funden en lugar de cortarse en seco.
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white, Colors.white],
        stops: [0, 0.06, 1],
      ).createShader(r),
      blendMode: BlendMode.dstIn,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        itemCount: dichos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (a, _) = dichos[i];
          final nuevo = nuevos.contains(a.id);
          return _Vidrio(
            velo: velo,
            onTap: () => onTap(a),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    a.say,
                    style: TextStyle(
                      fontFamily: 'EBGaramond',
                      fontSize: 18.5,
                      height: 1.3,
                      fontStyle: FontStyle.italic,
                      color: velo.cuerpo,
                    ),
                  ),
                ),
                if (nuevo)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 7),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: velo.cuerpo,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// El viejo abajo a la izquierda, grande, y lo que dice a su derecha.
class _Habla extends StatelessWidget {
  const _Habla({
    required this.velo,
    required this.dice,
    required this.pregunta,
    required this.onAnswer,
    this.onTap,
  });

  final SheetInk velo;
  final String dice;
  final bool pregunta;
  final void Function(AdviceGoal) onAnswer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget respuesta(String texto, AdviceGoal g) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _Vidrio(
        velo: velo,
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        onTap: () => onAnswer(g),
        child: Text(
          texto,
          style: TextStyle(color: velo.cuerpo, fontSize: 13.5),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, box) => Stack(
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
            left: box.maxHeight * 0.50,
            right: 14,
            bottom: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              child: Column(
                key: ValueKey(dice),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Vidrio(
                    velo: velo,
                    onTap: onTap,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dice,
                          style: TextStyle(
                            fontFamily: 'EBGaramond',
                            fontSize: 17,
                            height: 1.35,
                            color: velo.cuerpo,
                          ),
                        ),
                        if (onTap != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              tr(
                                'Tocá para que te lo explique',
                                'Tap to hear what he means',
                              ),
                              style: TextStyle(color: velo.tenue, fontSize: 12),
                            ),
                          ),
                      ],
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
    required this.velo,
    required this.consejo,
    required this.onClose,
  });

  final SheetInk velo;
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
    final velo = widget.velo;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, a, child) => ColoredBox(
          color: Colors.black.withValues(alpha: 0.35 * a),
          child: Opacity(
            opacity: a,
            child: Transform.scale(scale: 0.94 + 0.06 * a, child: child),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Vidrio(
              velo: velo,
              radius: 24,
              padding: const EdgeInsets.fromLTRB(26, 28, 26, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.consejo.say,
                    style: TextStyle(
                      fontFamily: 'EBGaramond',
                      fontSize: 26,
                      height: 1.28,
                      fontStyle: FontStyle.italic,
                      color: velo.cuerpo,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedOpacity(
                    opacity: _explica ? 1 : 0,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                    child: Text(
                      widget.consejo.mean,
                      style: TextStyle(
                        color: velo.tenue,
                        fontSize: 15.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
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
