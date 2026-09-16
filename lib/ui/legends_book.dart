import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../model/habit.dart';
import '../model/piece.dart';
import 'papyrus.dart';
import 'style.dart';

/// El libro del atril: todas las leyendas escritas de un pueblo.
///
/// La bitácora ya existía dentro de una hoja de la app, con sus pestañas y su
/// lista que se desliza. Esto no es lo mismo con otra piel: es el sitio del
/// pueblo donde eso se lee. Hay un atril en la plaza, se toca, y lo que se
/// abre es un libro — dos páginas, y se pasa la hoja con el dedo.
///
/// Que sea un libro no es adorno. Una lista que se desliza no tiene fondo: se
/// tira del pulgar y la cosa sigue, y cien leyendas se leen igual que diez. Un
/// libro tiene páginas contadas y se sabe por dónde se va; y pasar la hoja es
/// un gesto que cuesta lo justo para que cada página se mire.
class LegendsBook extends StatefulWidget {
  const LegendsBook({super.key, required this.habit, required this.theme});

  final Habit habit;
  final UiTheme theme;

  static Route<void> route({required Habit habit, required UiTheme theme}) =>
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: const Color(0xCC0B0A08),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => LegendsBook(habit: habit, theme: theme),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      );

  @override
  State<LegendsBook> createState() => _LegendsBookState();
}

class _LegendsBookState extends State<LegendsBook>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  )..addStatusListener(_landed);

  /// Qué par de páginas está abierto. Se avanza de dos en dos, que es como se
  /// avanza en un libro.
  int _spread = 0;

  /// Hacia dónde va la hoja que está en el aire: `1` adelante, `-1` atrás,
  /// `0` si no hay ninguna.
  int _way = 0;

  /// Cuántas páginas tiene el libro ahora mismo. Lo dice la maquetación, que
  /// depende del alto de la página, así que no se sabe hasta pintar.
  int _pages = 2;

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  void _landed(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    setState(() {
      _spread += _way;
      _way = 0;
      _turn.value = 0;
    });
  }

  int get _spreads => math.max(1, (_pages / 2).ceil());

  bool get _canGoOn => _spread + 1 < _spreads;
  bool get _canGoBack => _spread > 0;

  void _go(int way) {
    if (_way != 0 || _turn.isAnimating) return;
    if (way > 0 && !_canGoOn) return;
    if (way < 0 && !_canGoBack) return;
    Sensory.instance.tick();
    setState(() => _way = way);
    _turn.forward(from: 0);
  }

  // El arrastre: la hoja sigue al dedo, y al soltarla cae del lado en el que
  // haya quedado. Medio ancho de página es el punto de no retorno, que es
  // donde está en un libro de verdad.
  void _drag(DragUpdateDetails d, double width) {
    if (_turn.isAnimating) return;
    if (_way == 0) {
      if (d.primaryDelta == null || d.primaryDelta!.abs() < 0.6) return;
      final want = d.primaryDelta! < 0 ? 1 : -1;
      if (want > 0 && !_canGoOn) return;
      if (want < 0 && !_canGoBack) return;
      setState(() => _way = want);
    }
    final half = math.max(width / 2, 1.0);
    _turn.value = (_turn.value - d.primaryDelta! * _way / half).clamp(0.0, 1.0);
  }

  void _drop() {
    if (_way == 0 || _turn.isAnimating) return;
    if (_turn.value > 0.42) {
      Sensory.instance.tick();
      _turn.forward();
    } else {
      _turn.reverse().whenComplete(() {
        if (mounted) setState(() => _way = 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final legends = [
      for (final p in widget.habit.pieces)
        if (p.hasLabel) p,
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // Tocar fuera del libro lo cierra, que es lo que hace todo lo demás
        // que se abre encima del pueblo.
        onTap: () => Navigator.of(context).maybePop(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              10,
              12,
              10,
              math.max(12, media.padding.bottom),
            ),
            child: Column(
              children: [
                _Head(habit: widget.habit, count: legends.length),
                const SizedBox(height: 10),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, box) => _book(box, legends),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _Foot(
                  spread: _spread,
                  spreads: _spreads,
                  theme: widget.theme,
                  onBack: _canGoBack ? () => _go(-1) : null,
                  onOn: _canGoOn ? () => _go(1) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _book(BoxConstraints box, List<Piece> legends) {
    // Un libro abierto es más ancho que alto; un teléfono es justo al revés.
    // Así que manda el ancho —el libro ocupa el que haya— y el alto es todo el
    // que quepa hasta que la página se vuelva una tira: a partir de dos veces
    // y media su ancho, una página deja de leerse como una página.
    const flaca = 2.5;
    final w = box.maxWidth;
    final pageW = w / 2;
    final h = math.min(box.maxHeight, pageW * flaca);
    final pages = _layOut(legends, pageW, h);
    if (pages.length != _pages) {
      // Una sola vez y después del fotograma: la cuenta de páginas sale de la
      // maquetación, y la maquetación necesita saber cuánto mide la página.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _pages = pages.length;
          if (_spread >= _spreads) _spread = _spreads - 1;
        });
      });
    }

    Widget leaf(int i) => _Page(
      key: ValueKey('p$i'),
      child: i >= 0 && i < pages.length ? pages[i] : const SizedBox.expand(),
    );

    // Debajo de la hoja que vuela está siempre el par al que se va a llegar,
    // del lado por el que se abre; del otro, el que se queda.
    final left = _way > 0 ? _spread * 2 : (_spread - 1) * 2;
    final right = _way < 0 ? _spread * 2 + 1 : (_spread + 1) * 2 + 1;

    return SizedBox(
      width: w,
      height: h,
      child: GestureDetector(
        onTap: () {},
        onHorizontalDragUpdate: (d) => _drag(d, pageW),
        onHorizontalDragEnd: (_) => _drop(),
        child: AnimatedBuilder(
          animation: _turn,
          builder: (context, _) => Stack(
            children: [
              // Las dos que están quietas.
              Positioned(
                left: 0,
                top: 0,
                width: pageW,
                height: h,
                child: leaf(_way == 0 ? _spread * 2 : left),
              ),
              Positioned(
                left: pageW,
                top: 0,
                width: pageW,
                height: h,
                child: leaf(_way == 0 ? _spread * 2 + 1 : right),
              ),
              if (_way != 0) _flying(pageW, h, pages),
              // El lomo: la sombra del pliegue, que es lo que hace que dos
              // rectángulos de papel se lean como un libro y no como dos
              // hojas pegadas.
              Positioned(
                left: pageW - 13,
                top: 0,
                width: 26,
                height: h,
                child: const IgnorePointer(child: _Gutter()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// La hoja que está en el aire, girando sobre el lomo.
  ///
  /// Es una sola hoja con dos caras: la que se estaba leyendo y la que se va a
  /// leer. Hasta la mitad del giro se ve la primera; pasada la mitad se ve la
  /// segunda, escrita al revés para que al terminar de darse la vuelta se lea
  /// derecha. Es exactamente lo que hace una hoja de papel.
  Widget _flying(double pageW, double h, List<Widget> pages) {
    final t = Curves.easeInOut.transform(_turn.value);
    final ahead = _way > 0;
    final front = ahead ? _spread * 2 + 1 : _spread * 2;
    final back = ahead ? _spread * 2 + 2 : _spread * 2 - 1;
    final past = t > 0.5;
    final shown = past ? back : front;
    final angle = (ahead ? -1 : 1) * t * math.pi;

    Widget face = _Page(
      key: ValueKey('f$shown'),
      child: shown >= 0 && shown < pages.length
          ? pages[shown]
          : const SizedBox.expand(),
    );
    if (past) {
      face = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..rotateY(math.pi),
        child: face,
      );
    }
    // Se oscurece según se pone de canto, que es lo que hace que el giro se
    // lea como volumen y no como una hoja que se encoge.
    final shade = math.sin(t * math.pi) * 0.34;

    return Positioned(
      left: ahead ? pageW : 0,
      top: 0,
      width: pageW,
      height: h,
      child: Transform(
        alignment: ahead ? Alignment.centerLeft : Alignment.centerRight,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0013)
          ..rotateY(angle),
        child: Stack(
          fit: StackFit.expand,
          children: [
            face,
            IgnorePointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: shade)),
            ),
          ],
        ),
      ),
    );
  }

  /// Reparte las leyendas en páginas del alto que haya.
  ///
  /// La primera es la portada. Después, tantas leyendas como quepan, y ni una
  /// partida por la mitad: una leyenda que siga en la página siguiente es una
  /// leyenda que hay que leer dos veces.
  ///
  /// Se **mide** cada una en vez de darle un alto de tanteo. Una leyenda de
  /// tres palabras y otra que ocupa dos renglones no abultan lo mismo, así que
  /// con un alto fijo o se desborda la página o queda media en blanco; y aquí
  /// las escribe el usuario, o sea que no hay manera de saberlo de antemano.
  List<Widget> _layOut(List<Piece> legends, double pageW, double pageH) {
    final room = pageH - _Page.padTop - _Page.padBottom;
    final out = <Widget>[_Cover(habit: widget.habit, count: legends.length)];

    if (legends.isEmpty) {
      out.add(const _Blank());
    } else {
      final width = pageW - 32;
      var from = 0, used = 0.0;
      for (var i = 0; i < legends.length; i++) {
        final tall = _Leaves.heightOf(legends[i], width);
        // Siempre entra al menos una, aunque sea más alta que la página: una
        // leyenda kilométrica se recorta, pero no deja una página vacía y se
        // va a la siguiente para recortarse igual.
        if (used > 0 && used + tall > room) {
          out.add(_Leaves(pieces: legends.sublist(from, i)));
          from = i;
          used = 0;
        }
        used += tall;
      }
      out.add(_Leaves(pieces: legends.sublist(from)));
    }
    // Un libro abierto tiene siempre dos páginas: si la cuenta sale impar, la
    // última es la guarda, que es lo que hay al final de cualquier libro.
    if (out.length.isOdd) out.add(const _Blank());
    return out;
  }
}

/// El papel de una página, con su grano y su borde.
class _Page extends StatelessWidget {
  const _Page({super.key, required this.child});

  static const double padTop = 34;
  static const double padBottom = 30;

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      boxShadow: [
        BoxShadow(color: Color(0x55000000), blurRadius: 12, spreadRadius: -2),
      ],
    ),
    child: ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: PapyrusPainter(seed: 0x51b0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, padTop, 16, padBottom),
            // Recortado, y no porque se espere que sobre: la cuenta se hace
            // midiendo, pero una página de papel no deja ver lo que se sale
            // de ella, y eso tiene que seguir siendo verdad pase lo que pase.
            child: ClipRect(child: child),
          ),
        ],
      ),
    ),
  );
}

/// La sombra del pliegue entre las dos páginas.
class _Gutter extends StatelessWidget {
  const _Gutter();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0x00000000), Color(0x4A2B1E0C), Color(0x00000000)],
        stops: [0.0, 0.5, 1.0],
      ),
    ),
  );
}

/// La portada: de qué pueblo es el libro y cuánto lleva escrito.
class _Cover extends StatelessWidget {
  const _Cover({required this.habit, required this.count});
  final Habit habit;
  final int count;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        'BITÁCORA',
        textAlign: TextAlign.center,
        style: Papyrus.body(
          12,
          w: FontWeight.w700,
        ).copyWith(letterSpacing: 3.2),
      ),
      const SizedBox(height: 14),
      const PapyrusRule(),
      const SizedBox(height: 14),
      Text(
        habit.name,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Papyrus.body(19, w: FontWeight.w700, c: Papyrus.rubric),
      ),
      const SizedBox(height: 18),
      Text(
        '${Papyrus.roman(habit.total)} piezas asentadas',
        textAlign: TextAlign.center,
        style: Papyrus.body(11.5, c: Papyrus.inkSoft),
      ),
      Text(
        count == 0
            ? 'ninguna con leyenda'
            : count == 1
            ? 'una lleva leyenda'
            : '${Papyrus.roman(count)} llevan leyenda',
        textAlign: TextAlign.center,
        style: Papyrus.body(11.5, c: Papyrus.inkFaint),
      ),
    ],
  );
}

/// Una página en blanco: la guarda del final, y lo que se ve cuando todavía
/// no se escribió nada.
class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Aquí no hay nada escrito\ntodavía.\n\nDespués de asentar una pieza,\ntocala y contale al pueblo\nqué fue.',
      textAlign: TextAlign.center,
      style: Papyrus.body(12, c: Papyrus.inkFaint),
    ),
  );
}

/// Las leyendas de una página.
///
/// Dos renglones cada una y siempre los mismos: arriba de qué pieza es y de
/// qué día, en pequeño; debajo lo que se escribió. Sin columnas ni sangrías,
/// porque media página de teléfono son ciento cuarenta píxeles y todo lo que
/// se reserve a la izquierda se lo quita al texto, que es lo único que
/// importa aquí.
class _Leaves extends StatelessWidget {
  const _Leaves({required this.pieces});
  final List<Piece> pieces;

  /// Lo que hay entre una leyenda y la siguiente: el aire y el filete.
  ///
  /// El filete va metido en una caja de este alto y no suelto, y no es manía:
  /// así lo que se mide y lo que se pinta son el mismo número por
  /// construcción. Suelto medía nueve donde la cuenta ponía uno.
  static const double _ruleH = 9;
  static const double _gap = 8 + _ruleH + 8;

  /// Cuántos renglones puede ocupar cada cosa. **Los mismos al medir y al
  /// pintar**, que es de donde salía el desbordamiento: la fecha se medía en
  /// un renglón y se pintaba en dos.
  static const int _dateLines = 2, _textLines = 3;

  /// La cabecera de una leyenda: qué pieza fue y cuándo.
  static String headOf(Piece p) =>
      '${Papyrus.roman(p.index + 1)} · '
      '${Papyrus.roman(p.placedAt.day)} de '
      '${Papyrus.months[p.placedAt.month - 1]} · '
      '${Papyrus.roman(p.placedAt.year)}';

  static TextStyle get _headStyle => Papyrus.body(9.5, c: Papyrus.inkFaint);
  static TextStyle get _textStyle => Papyrus.body(13);

  /// Cuánto ocupa esta leyenda en una página de [width] de ancho.
  ///
  /// Medida de verdad, con la misma letra, el mismo ancho y la misma cuenta de
  /// renglones con los que se va a pintar. Es la única manera de repartirlas
  /// sin que la última de cada página se salga por abajo: las escribe el
  /// usuario, así que no hay un alto de tanteo que valga para todas.
  static double heightOf(Piece p, double width) =>
      _measure(headOf(p), _headStyle, width, _dateLines) +
      2 +
      _measure(p.label ?? '', _textStyle, width, _textLines) +
      _gap;

  static double _measure(String text, TextStyle style, double width, int max) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: max,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(width, 1));
    return tp.height;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final p in pieces) ...[
        Text(
          headOf(p),
          maxLines: _dateLines,
          overflow: TextOverflow.ellipsis,
          style: _headStyle,
        ),
        const SizedBox(height: 2),
        Text(
          p.label!,
          maxLines: _textLines,
          overflow: TextOverflow.ellipsis,
          style: _textStyle,
        ),
        const SizedBox(height: 8),
        const SizedBox(height: _ruleH, child: PapyrusRule()),
        const SizedBox(height: 8),
      ],
    ],
  );
}

/// Lo que hay por encima del libro: de quién es y cómo se cierra.
class _Head extends StatelessWidget {
  const _Head({required this.habit, required this.count});
  final Habit habit;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EL ATRIL',
              style: TextStyle(
                color: Color(0xFFE6DCC4),
                fontSize: 10.5,
                letterSpacing: 2.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              habit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0x99E6DCC4), fontSize: 12.5),
            ),
          ],
        ),
      ),
      IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.close_rounded, color: Color(0xCCE6DCC4)),
        tooltip: 'Cerrar',
      ),
    ],
  );
}

/// Por dónde se va, y los dos botones para quien no descubra el gesto.
class _Foot extends StatelessWidget {
  const _Foot({
    required this.spread,
    required this.spreads,
    required this.theme,
    this.onBack,
    this.onOn,
  });

  final int spread, spreads;
  final UiTheme theme;
  final VoidCallback? onBack, onOn;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _Arrow(icon: Icons.chevron_left_rounded, onTap: onBack),
      const SizedBox(width: 14),
      SizedBox(
        width: 96,
        child: Text(
          '${spread + 1} / $spreads',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0x99E6DCC4),
            fontSize: 12,
            letterSpacing: 1.4,
          ),
        ),
      ),
      const SizedBox(width: 14),
      _Arrow(icon: Icons.chevron_right_rounded, onTap: onOn),
    ],
  );
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    icon: Icon(
      icon,
      color: onTap == null ? const Color(0x33E6DCC4) : const Color(0xCCE6DCC4),
    ),
  );
}
