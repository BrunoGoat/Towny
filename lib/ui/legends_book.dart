import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/rng.dart';

import '../fx/sensory.dart';
import '../model/habit.dart';
import '../model/piece.dart';
import '../model/works_log.dart';
import 'habit_sigil.dart';
import 'papyrus.dart';
import 'style.dart';
import 'works_calendar.dart';

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
    final pageW = (w - _tapa * 2) / 2;
    final h = math.min(box.maxHeight - _tapaY * 2, pageW * flaca);
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

    Widget leaf(int i) {
      final hay = i >= 0 && i < pages.length;
      return _Page(
        key: ValueKey('p$i'),
        head: hay ? pages[i].head : null,
        // La portada no lleva folio, como en cualquier libro.
        folio: hay && i > 0 ? i + 1 : null,
        left: i.isEven,
        child: hay ? pages[i].body : const SizedBox.expand(),
      );
    }

    // Debajo de la hoja que vuela está siempre el par al que se va a llegar,
    // del lado por el que se abre; del otro, el que se queda.
    final left = _way > 0 ? _spread * 2 : (_spread - 1) * 2;
    final right = _way < 0 ? _spread * 2 + 1 : (_spread + 1) * 2 + 1;

    return SizedBox(
      width: w,
      height: h + _tapaY * 2,
      child: GestureDetector(
        onTap: () {},
        onHorizontalDragUpdate: (d) => _drag(d, pageW),
        onHorizontalDragEnd: (_) => _drop(),
        child: AnimatedBuilder(
          animation: _turn,
          builder: (context, _) => Stack(
            children: [
              // Las tapas, el canto de las hojas y las cantoneras: todo lo que
              // hace que esto sea un libro y no dos hojas pegadas.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _Boards(
                      behind: _spread,
                      ahead: math.max(0, _spreads - _spread - 1),
                      pad: _tapa,
                      padY: _tapaY,
                    ),
                  ),
                ),
              ),
              // Las dos que están quietas.
              Positioned(
                left: _tapa,
                top: _tapaY,
                width: pageW,
                height: h,
                child: leaf(_way == 0 ? _spread * 2 : left),
              ),
              Positioned(
                left: _tapa + pageW,
                top: _tapaY,
                width: pageW,
                height: h,
                child: leaf(_way == 0 ? _spread * 2 + 1 : right),
              ),
              if (_way != 0) _flying(pageW, h, pages),
              // El lomo: la sombra del pliegue, que es lo que hace que dos
              // páginas se lean como un pliego y no como dos hojas sueltas.
              Positioned(
                left: _tapa + pageW - 15,
                top: _tapaY,
                width: 30,
                height: h,
                child: const IgnorePointer(child: _Gutter()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lo que asoma de tapa por los cuatro lados de las páginas.
  static const double _tapa = 15;
  static const double _tapaY = 11;

  /// La hoja que está en el aire, girando sobre el lomo.
  ///
  /// Es una sola hoja con dos caras: la que se estaba leyendo y la que se va a
  /// leer. Hasta la mitad del giro se ve la primera; pasada la mitad se ve la
  /// segunda, escrita al revés para que al terminar de darse la vuelta se lea
  /// derecha. Es exactamente lo que hace una hoja de papel.
  Widget _flying(double pageW, double h, List<_Sheet> pages) {
    final t = Curves.easeInOut.transform(_turn.value);
    final ahead = _way > 0;
    final front = ahead ? _spread * 2 + 1 : _spread * 2;
    final back = ahead ? _spread * 2 + 2 : _spread * 2 - 1;
    final past = t > 0.5;
    final shown = past ? back : front;
    // **El signo del giro es el que decide por dónde pasa la hoja.** Girar
    // media vuelta sobre el lomo lleva la hoja de un lado al otro con
    // cualquiera de los dos signos, porque el ancho va con el coseno; lo que
    // cambia es el seno, o sea la profundidad. Con el signo de antes el canto
    // libre se iba hacia dentro y la hoja pasaba **por detrás** del libro,
    // hundiéndose y saliendo del otro lado, que es algo que el papel no hace.
    // Así el canto se levanta hacia quien mira, pasa por delante y aterriza.
    final angle = (ahead ? 1 : -1) * t * math.pi;

    final hay = shown >= 0 && shown < pages.length;
    Widget face = _Page(
      // Con nombre fijo: es por donde la prueba agarra la hoja en el aire para
      // medir por qué lado del libro está pasando.
      key: const ValueKey('cara'),
      head: hay ? pages[shown].head : null,
      folio: hay && shown > 0 ? shown + 1 : null,
      left: shown.isEven,
      child: hay ? pages[shown].body : const SizedBox.expand(),
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
      left: _tapa + (ahead ? pageW : 0),
      top: _tapaY,
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
  List<_Sheet> _layOut(List<Piece> legends, double pageW, double pageH) {
    final room = pageH - _Page.padTop - _Page.padBottom;
    final out = <_Sheet>[
      _Sheet(_Cover(habit: widget.habit, count: legends.length)),
    ];

    // **Primero las obras, fechadas.** Es el resumen del pueblo: lo que se
    // levantó, cuándo se empezó y cuándo se remató. Va delante de las
    // leyendas porque son los años y las leyendas son los días, y en un libro
    // lo general va antes que lo particular.
    // Con una rematada por lo menos: un pueblo que todavía está levantando su
    // primera obra no tiene un calendario, tiene una barra empezada, y una
    // sección entera para eso es una sección vacía con adorno.
    final obras = worksOf(widget.habit);
    if (obras.any((o) => o.done)) {
      final hoy = DateTime.now();
      final caben = ((room - 30) / calendarLabelH).floor();
      for (final hoja in calendarPages(obras, fits: caben, today: hoy)) {
        out.add(
          _Sheet(
            WorksCalendar(page: hoja, today: hoy),
            head: 'LAS OBRAS',
          ),
        );
      }
    }

    if (legends.isEmpty) {
      out.add(const _Sheet(_Blank()));
    } else {
      final width = pageW - 32;
      var from = 0, used = 0.0;
      for (var i = 0; i < legends.length; i++) {
        final tall = _Leaves.heightOf(legends[i], width);
        // Siempre entra al menos una, aunque sea más alta que la página: una
        // leyenda kilométrica se recorta, pero no deja una página vacía y se
        // va a la siguiente para recortarse igual.
        if (used > 0 && used + tall > room) {
          out.add(
            _Sheet(_Leaves(pieces: legends.sublist(from, i)), head: 'LEYENDAS'),
          );
          from = i;
          used = 0;
        }
        used += tall;
      }
      out.add(_Sheet(_Leaves(pieces: legends.sublist(from)), head: 'LEYENDAS'));
    }
    // Un libro abierto tiene siempre dos páginas: si la cuenta sale impar, la
    // última es la guarda, que es lo que hay al final de cualquier libro.
    if (out.length.isOdd) out.add(const _Sheet(_Blank()));
    return out;
  }
}

/// Una página del libro: lo que lleva escrito y de qué sección es.
class _Sheet {
  const _Sheet(this.body, {this.head});
  final Widget body;

  /// El renglón de arriba. Nulo en la portada y en las guardas, que no son de
  /// ninguna sección.
  final String? head;
}

/// Las tapas del libro, y todo lo que se ve de él que no es papel.
///
/// **De dónde venía esto.** Las dos páginas se pintaban solas, flotando en el
/// medio de la pantalla: dos rectángulos de papel con un filo de sombra. Leía
/// como un escaneo, no como un libro — y en un pueblo castellano el sitio
/// donde se escribe lo que pasó es un códice, que es un objeto con cuerpo:
/// tablas forradas de cuero, cantoneras de latón para que las esquinas
/// aguanten, y el canto de las hojas asomando por fuera.
///
/// El canto además **dice por dónde vas**: las hojas se apilan a un lado y a
/// otro según lo leído y lo que queda, igual que en un libro de verdad, así
/// que la mano sabe si está al principio o al final sin leer el número.
class _Boards extends CustomPainter {
  const _Boards({
    required this.behind,
    required this.ahead,
    required this.pad,
    required this.padY,
  });

  /// Hojas a un lado y al otro, para el grueso del canto.
  final int behind, ahead;
  final double pad, padY;

  static const Color _cueroAlto = Color(0xFF5A422A);
  static const Color _cueroBajo = Color(0xFF382719);
  static const Color _canto = Color(0xFF2A1E12);
  static const Color _laton = Color(0xFFB5935A);
  static const Color _hoja = Color(0xFFE7D7B0);

  @override
  void paint(Canvas canvas, Size size) {
    final todo = Offset.zero & size;
    final tapa = RRect.fromRectAndRadius(todo, const Radius.circular(9));

    // La sombra: el libro está apoyado en algo, no pegado a la pantalla.
    canvas.drawRRect(
      tapa.shift(const Offset(0, 6)),
      Paint()
        ..color = const Color(0x77000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    canvas.drawRRect(
      tapa,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [_cueroAlto, _cueroBajo],
        ),
    );
    // El grano del cuero: rayas cortas y muy flojas, que a esta escala es todo
    // lo que se ve de una piel.
    canvas.save();
    canvas.clipRRect(tapa);
    for (var i = 0; i < 90; i++) {
      final y = hash01(0xb0, 1, i) * size.height;
      final x = hash01(0xb0, 2, i) * size.width;
      canvas.drawLine(
        Offset(x, y),
        Offset(
          x + 4 + hash01(0xb0, 3, i) * 14,
          y + hashJitter(1.2, 0xb0, 4, i),
        ),
        Paint()
          ..color = const Color(
            0xFF1C1309,
          ).withValues(alpha: 0.05 + hash01(0xb0, 5, i) * 0.06)
          ..strokeWidth = 0.8,
      );
    }
    canvas.restore();
    // Un filo claro arriba y otro oscuro abajo: el bisel de la tabla.
    canvas.drawRRect(
      tapa.deflate(1.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0x2ED8C39A),
    );
    canvas.drawRRect(
      tapa,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _canto,
    );

    // El hueco donde se asienta el bloque de hojas.
    final bloque = Rect.fromLTRB(
      pad - 5,
      padY - 4,
      size.width - pad + 5,
      size.height - padY + 4,
    );
    canvas.drawRect(
      bloque,
      Paint()
        ..color = const Color(0x552A1E12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // El canto de las hojas: las leídas a la izquierda, las que quedan a la
    // derecha. Se ve cuánto libro llevas sin contar nada.
    _fore(canvas, size, izquierda: true, hojas: behind);
    _fore(canvas, size, izquierda: false, hojas: ahead);
    // Y la cabeza y el pie del bloque, que también son canto.
    for (final y in [padY - 3.0, size.height - padY]) {
      canvas.drawRect(
        Rect.fromLTWH(pad - 3, y, size.width - (pad - 3) * 2, 3),
        Paint()..color = _hoja.withValues(alpha: 0.5),
      );
    }

    _cantonera(canvas, const Offset(0, 0), 1, 1);
    _cantonera(canvas, Offset(size.width, 0), -1, 1);
    _cantonera(canvas, Offset(0, size.height), 1, -1);
    _cantonera(canvas, Offset(size.width, size.height), -1, -1);
  }

  /// El montón de hojas asomando por un costado.
  void _fore(
    Canvas canvas,
    Size size, {
    required bool izquierda,
    required int hojas,
  }) {
    final n = 2 + math.min(8, hojas);
    final ancho = n * 1.3;
    final x0 = izquierda ? pad - ancho : size.width - pad;
    final r = Rect.fromLTWH(x0, padY - 2, ancho, size.height - padY * 2 + 4);
    canvas.drawRect(r, Paint()..color = _hoja.withValues(alpha: 0.62));
    for (var i = 0; i < n; i++) {
      final x = x0 + i * 1.3 + 0.6;
      canvas.drawLine(
        Offset(x, r.top + 1),
        Offset(x, r.bottom - 1),
        Paint()
          ..color = const Color(0xFF856B3F).withValues(alpha: 0.28)
          ..strokeWidth = 0.6,
      );
    }
  }

  /// Una cantonera de latón, que es lo que salva las esquinas de un libro que
  /// se abre todos los días.
  void _cantonera(Canvas canvas, Offset at, double dx, double dy) {
    const largo = 19.0, grueso = 6.0;
    final p = Path()
      ..moveTo(at.dx, at.dy + dy * largo)
      ..lineTo(at.dx, at.dy)
      ..lineTo(at.dx + dx * largo, at.dy)
      ..lineTo(at.dx + dx * largo, at.dy + dy * grueso)
      ..lineTo(at.dx + dx * grueso, at.dy + dy * grueso)
      ..lineTo(at.dx + dx * grueso, at.dy + dy * largo)
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..shader = ui.Gradient.linear(
          at,
          at + Offset(dx * largo, dy * largo),
          const [Color(0xFFD8BC84), _laton],
        ),
    );
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x88594322),
    );
    // El remache.
    canvas.drawCircle(
      at + Offset(dx * 11, dy * 3),
      1.5,
      Paint()..color = const Color(0xFF6E5427),
    );
  }

  @override
  bool shouldRepaint(_Boards old) => old.behind != behind || old.ahead != ahead;
}

/// El papel de una página, con su grano, su pauta y su folio.
class _Page extends StatelessWidget {
  const _Page({
    super.key,
    required this.child,
    this.head,
    this.folio,
    this.left = false,
  });

  static const double padTop = 34;
  static const double padBottom = 30;

  /// El renglón de arriba, en versalitas: de qué sección es esta página.
  final String? head;

  /// El número de la hoja, abajo y por la parte de fuera, como en un códice.
  final int? folio;
  final bool left;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
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
        if (head != null)
          Positioned(
            left: 16,
            right: 16,
            top: 13,
            child: Text(
              head!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Papyrus.body(
                7.5,
                c: Papyrus.inkFaint,
              ).copyWith(letterSpacing: 1.8),
            ),
          ),
        if (folio != null)
          Positioned(
            left: left ? 14 : null,
            right: left ? null : 14,
            bottom: 11,
            child: Text(
              Papyrus.roman(folio!),
              style: Papyrus.body(8, c: Papyrus.inkFaint),
            ),
          ),
        // El papel se curva al meterse en el pliegue, y por eso se oscurece
        // por dentro y se aclara en el canto de fuera. Sin esto las dos
        // páginas son dos planos y el libro no tiene volumen.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: left ? Alignment.centerRight : Alignment.centerLeft,
                  end: left ? Alignment.centerLeft : Alignment.centerRight,
                  colors: const [
                    Color(0x382B1E0C),
                    Color(0x0C2B1E0C),
                    Color(0x00000000),
                    Color(0x14000000),
                  ],
                  stops: const [0.0, 0.14, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
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
        colors: [Color(0x00000000), Color(0x5E2B1E0C), Color(0x00000000)],
        stops: [0.0, 0.5, 1.0],
      ),
    ),
  );
}

/// La portada: de qué pueblo es el libro, con su sello.
///
/// Era un título, una raya y dos cuentas. Ahora es una portada de verdad: el
/// sello del hábito dibujado en el medio, dentro de una orla, que es como se
/// marca un libro que es de alguien. El sello es el mismo que lleva el pueblo
/// en la barra de abajo, así que el libro se reconoce antes de leer el nombre.
class _Cover extends StatelessWidget {
  const _Cover({required this.habit, required this.count});
  final Habit habit;
  final int count;

  /// Encogida entera antes que desbordada: en una pantalla de trescientos
  /// veinte puntos la página mide poco más que la portada, y de las dos cosas
  /// que puede hacer una portada que no cabe —salirse por abajo o escribirse
  /// un punto más chica— sólo una sigue siendo una portada.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(width: box.maxWidth, child: _sheet()),
    ),
  );

  Widget _sheet() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        'BITÁCORA',
        textAlign: TextAlign.center,
        style: Papyrus.body(
          11,
          w: FontWeight.w700,
        ).copyWith(letterSpacing: 3.4),
      ),
      const SizedBox(height: 12),
      const PapyrusRule(),
      const SizedBox(height: 16),
      _Orla(
        child: HabitSigil(symbol: habit.symbol, color: Papyrus.ink, size: 34),
      ),
      const SizedBox(height: 16),
      Text(
        habit.name,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Papyrus.body(18, w: FontWeight.w700, c: Papyrus.rubric),
      ),
      const SizedBox(height: 14),
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
      const SizedBox(height: 16),
      Text(
        'fundado ${Papyrus.longDate(habit.createdAt)}',
        textAlign: TextAlign.center,
        style: Papyrus.body(9.5, c: Papyrus.inkFaint),
      ),
    ],
  );
}

/// La orla del sello: un cuadro girado con las esquinas rematadas, dibujado y
/// no compuesto con caracteres, por lo mismo que el filete.
class _Orla extends StatelessWidget {
  const _Orla({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 78,
    height: 78,
    child: CustomPaint(
      painter: const _OrlaPainter(),
      child: Center(child: child),
    ),
  );
}

class _OrlaPainter extends CustomPainter {
  const _OrlaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final linea = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = Papyrus.inkFaint;
    canvas.drawCircle(c, size.width / 2 - 2, linea);
    canvas.drawCircle(c, size.width / 2 - 5.5, linea..strokeWidth = 0.6);
    // Cuatro puntos en las cuartas, que es lo que hace que un círculo pelado
    // parezca un sello y no un borde.
    for (var i = 0; i < 4; i++) {
      final a = math.pi / 2 * i + math.pi / 4;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * (size.width / 2 - 3.7),
        1.6,
        Paint()..color = Papyrus.rubric,
      );
    }
  }

  @override
  bool shouldRepaint(_OrlaPainter old) => false;
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
