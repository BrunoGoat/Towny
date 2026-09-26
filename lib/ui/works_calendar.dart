import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/works_log.dart';
import 'papyrus.dart';

/// El calendario de las obras: una página, un tramo de meses.
///
/// La bitácora cuenta los días uno por uno y eso está bien para acordarse de
/// un día; para acordarse de un año hace falta verlo entero de una vez. Aquí
/// el tiempo baja por la página —los meses, uno debajo de otro— y cada obra es
/// una barra que empieza donde se puso la primera piedra y acaba donde se
/// remató. Lo que se lee de un vistazo no es cuánto costó cada una sino
/// **cuánto duró**, y dónde están los huecos: los meses en que el pueblo
/// creció en casas y no hizo época.
class CalendarPage {
  const CalendarPage({
    required this.from,
    required this.to,
    required this.spans,
  });

  /// El primer día del primer mes que se enseña.
  final DateTime from;

  /// El primer día del mes **siguiente** al último que se enseña, que es lo
  /// que hace que el último mes salga entero y no cortado por su día 1.
  final DateTime to;

  final List<WorkSpan> spans;

  String get heading => 'AÑO ${Papyrus.roman(from.year)}';

  /// «de marzo a junio», o «marzo» si no hay más que uno.
  String get months {
    final a = Papyrus.months[from.month - 1];
    final last = DateTime(to.year, to.month - 1, 1);
    final b = Papyrus.months[last.month - 1];
    if (a == b && from.year == last.year) return a;
    return 'de $a a $b';
  }
}

/// Reparte las obras en páginas de calendario.
///
/// Una por año mientras quepan, porque el año es la unidad en la que la gente
/// se acuerda de las cosas. Cuando un año trae más obras de las que caben
/// escritas —y caben las que caben, que depende del alto de la página— se
/// parte en tandas, y cada tanda enseña sólo los meses que abarca. Partir por
/// meses en vez de por mitades fijas evita la página con una sola obra arriba
/// y once meses vacíos debajo.
List<CalendarPage> calendarPages(
  List<WorkSpan> spans, {
  required int fits,
  required DateTime today,
}) {
  final out = <CalendarPage>[];
  final cabe = math.max(1, fits);
  final years = <int, List<WorkSpan>>{};
  for (final s in spans) {
    years.putIfAbsent(s.began.year, () => []).add(s);
  }
  final orden = years.keys.toList()..sort();
  for (final y in orden) {
    final todas = years[y]!;
    for (var i = 0; i < todas.length; i += cabe) {
      final tanda = todas.sublist(i, math.min(i + cabe, todas.length));
      final first = tanda.first.began;
      var last = tanda.last.ended ?? today;
      if (last.isBefore(tanda.last.began)) last = tanda.last.began;
      out.add(
        CalendarPage(
          from: DateTime(first.year, first.month, 1),
          to: DateTime(last.year, last.month + 1, 1),
          spans: tanda,
        ),
      );
    }
  }
  return out;
}

/// Lo que ocupa escrita una obra en el margen del calendario. Sirve para
/// repartir las páginas antes de pintarlas.
const double calendarLabelH = 34;

/// Dibuja un tramo del calendario.
class WorksCalendar extends StatelessWidget {
  const WorksCalendar({super.key, required this.page, required this.today});

  final CalendarPage page;
  final DateTime today;

  /// La página, contada en voz alta.
  String get dicho => [
    for (final s in page.spans)
      s.done
          ? '${s.name}, del ${s.began.day} de '
                '${Papyrus.months[s.began.month - 1]} al ${s.ended!.day} de '
                '${Papyrus.months[s.ended!.month - 1]}, ${s.days} '
                '${s.days == 1 ? 'día' : 'días'}.'
          : '${s.name}, empezada el ${s.began.day} de '
                '${Papyrus.months[s.began.month - 1]}, en obra.',
  ].join(' ');

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        page.heading,
        textAlign: TextAlign.center,
        style: Papyrus.body(
          10,
          w: FontWeight.w700,
          c: Papyrus.rubric,
        ).copyWith(letterSpacing: 2.2),
      ),
      Text(
        page.months,
        textAlign: TextAlign.center,
        style: Papyrus.body(9.5, c: Papyrus.inkFaint),
      ),
      const SizedBox(height: 6),
      Expanded(
        // Lo que va dentro está dibujado, no escrito: son barras contra una
        // regla de meses, y eso no se compone con widgets. Pero una página
        // que sólo existe pintada no la puede leer nadie que no vea, así que
        // va también en palabras, que es de donde la lee el lector de
        // pantalla —y de donde la leen las pruebas—.
        child: Semantics(
          label: dicho,
          child: CustomPaint(
            painter: _CalendarPainter(page: page, today: today),
            size: Size.infinite,
          ),
        ),
      ),
    ],
  );
}

class _CalendarPainter extends CustomPainter {
  const _CalendarPainter({required this.page, required this.today});

  final CalendarPage page;
  final DateTime today;

  /// El ancho de la columna de los meses, y dónde cae la cinta del tiempo.
  static const double _monthW = 26;
  static const double _axis = _monthW + 7;
  static const double _barW = 7;
  static const double _labelX = _axis + 11;

  @override
  void paint(Canvas canvas, Size size) {
    final total = page.to.difference(page.from).inMinutes.toDouble();
    if (total <= 0) return;
    const top = 2.0;
    final bottom = size.height - 2;
    double y(DateTime d) {
      final k = d.difference(page.from).inMinutes / total;
      return top + k.clamp(0.0, 1.0) * (bottom - top);
    }

    // Los meses: una banda por cada uno, un filete que la abre y su nombre
    // dentro. Es la regla contra la que se leen las barras, y sin ella esto
    // sería una lista con adornos en vez de un calendario. Las bandas van
    // alternadas y muy flojas: lo justo para que el ojo vea los escalones del
    // año sin que el papel parezca rayado.
    final filete = Paint()
      ..color = Papyrus.rule
      ..strokeWidth = 0.7;
    var par = false;
    for (
      var m = page.from;
      m.isBefore(page.to);
      m = DateTime(m.year, m.month + 1, 1)
    ) {
      final at = y(m);
      final hasta = y(DateTime(m.year, m.month + 1, 1));
      if (par) {
        canvas.drawRect(
          Rect.fromLTRB(0, at, size.width, hasta),
          Paint()..color = const Color(0x0C795E33),
        );
      }
      par = !par;
      canvas.drawLine(Offset(0, at), Offset(size.width, at), filete);
      _write(
        canvas,
        Papyrus.months[m.month - 1].substring(0, 3).toUpperCase(),
        Papyrus.body(8, c: Papyrus.inkFaint).copyWith(letterSpacing: 1.1),
        Offset(0, at + 2),
        _monthW,
      );
    }

    // La cinta del tiempo, que es lo que hace que un hueco entre dos obras se
    // vea como un hueco y no como una página mal maquetada.
    canvas.drawLine(
      Offset(_axis, top),
      Offset(_axis, bottom),
      Paint()
        ..color = Papyrus.rule
        ..strokeWidth = 1.2,
    );

    var libre = top;
    for (final s in page.spans) {
      final y0 = y(s.began);
      final y1 = math.max(y0 + 3, y(s.ended ?? today));
      final enObra = !s.done;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(_axis - _barW / 2, y0, _axis + _barW / 2, y1),
          const Radius.circular(3),
        ),
        Paint()..color = enObra ? Papyrus.rubric : Papyrus.ink,
      );
      // Los dos cantos, que son las dos fechas: el día que se empezó y el día
      // que se remató, marcados contra la regla de los meses.
      final canto = Paint()
        ..color = Papyrus.inkSoft
        ..strokeWidth = 0.8;
      canvas.drawLine(
        Offset(_axis - _barW, y0),
        Offset(_axis + _barW, y0),
        canto,
      );
      if (s.done) {
        canvas.drawLine(
          Offset(_axis - _barW, y1),
          Offset(_axis + _barW, y1),
          canto,
        );
      }

      // El nombre, a la altura de su barra y sin pisar al anterior. Cuando hay
      // que bajarlo, una guía lo ata a su barra.
      final at = math.max(libre, y0 - 3);
      final ancho = size.width - _labelX;
      if (at > bottom - 10) continue;
      final alto = _write(
        canvas,
        s.name,
        Papyrus.body(10.5, w: FontWeight.w600),
        Offset(_labelX, at),
        ancho,
        lines: 1,
      );
      final alto2 = _write(
        canvas,
        _detail(s),
        Papyrus.body(8.5, c: Papyrus.inkFaint),
        Offset(_labelX, at + alto),
        ancho,
        lines: 2,
      );
      if (at > y0 + 1) {
        canvas.drawLine(
          Offset(_axis + _barW / 2 + 1, y0),
          Offset(_labelX - 3, at + 5),
          Paint()
            ..color = Papyrus.rule
            ..strokeWidth = 0.6,
        );
      }
      libre = at + alto + alto2 + 5;
    }
  }

  /// «del IV de marzo al XXI de abril · XV días», recortado a lo que quepa.
  String _detail(WorkSpan s) {
    final a =
        '${Papyrus.roman(s.began.day)} '
        '${Papyrus.months[s.began.month - 1].substring(0, 3)}';
    if (!s.done) return 'desde el $a · en obra';
    final b =
        '${Papyrus.roman(s.ended!.day)} '
        '${Papyrus.months[s.ended!.month - 1].substring(0, 3)}';
    final d = s.days!;
    return '$a – $b · ${Papyrus.roman(d)} ${d == 1 ? 'día' : 'días'}';
  }

  /// Escribe [text] y devuelve lo que ocupó de alto.
  double _write(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at,
    double width, {
    int lines = 1,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: lines,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(width, 1));
    tp.paint(canvas, at);
    return tp.height;
  }

  @override
  bool shouldRepaint(_CalendarPainter old) =>
      old.page != page || old.today != today;
}
