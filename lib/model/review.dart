import 'habit.dart';
import 'piece.dart';
import 'pledge.dart';
import 'rhythm.dart';
import 'works_log.dart';

/// La cuenta de un mes o de un año.
///
/// Todo lo demás que esta app enseña es el presente: cuántas piezas llevás, qué
/// está en obra, si el pueblo está encendido. Eso sirve para hoy y no sirve para
/// nada más, porque lo que uno no sabe nunca de un hábito no es cómo va hoy
/// —eso se ve— sino **cómo fue el mes**. Y sin eso no hay manera de corregir:
/// se sigue haciendo lo mismo, mejor o peor, sin saber qué de lo que se hizo
/// funcionó.
///
/// Dos cadencias y las dos hacen falta. El mes es lo bastante corto para
/// acordarse de lo que pasó dentro y lo bastante largo para que una semana mala
/// no lo decida; el año es donde se ven las cosas que un mes no puede enseñar
/// —que los huecos son más cortos que en enero, que el pueblo tiene cuatro obras
/// que hace un año no existían—.
///
/// **No se guarda nada.** Como el calendario de las obras, sale de lo que ya
/// está escrito: las piezas llevan su fecha desde el primer día, la crónica dice
/// qué se levantó y cuándo, y las pausas están apuntadas. Por eso funciona hacia
/// atrás, en pueblos de hace años, y por eso no hay ninguna revisión que se
/// pueda perder.
class Review {
  const Review({
    required this.heading,
    required this.from,
    required this.to,
    required this.monthly,
    required this.open,
    required this.pieces,
    required this.days,
    required this.of,
    required this.gaps,
    required this.longest,
    required this.trailing,
    required this.works,
    required this.before,
    this.underway,
    this.identity,
    this.plan,
    this.planKept,
  });

  /// Cómo se llama esta cuenta: «ASÍ FUE MAYO», «ASÍ VA EL AÑO MMXXVI».
  final String heading;

  /// El tramo: desde el primer día, y hasta el primer día del siguiente —que es
  /// lo que hace que el último día del mes entre entero—.
  final DateTime from;
  final DateTime to;

  /// Un mes o un año. Lo lee la página para escribir el subtítulo, que en un
  /// mes lleva el mes y el año y en un año sólo el año.
  final bool monthly;

  /// Si el tramo todavía no ha acabado. Un mes en curso se cuenta hasta hoy, y
  /// se dice que va, no que fue.
  final bool open;

  /// Piezas puestas dentro del tramo.
  final int pieces;

  /// Días con pieza, y días que contaban: el tramo, menos lo que cae fuera de
  /// la vida del pueblo, menos los días que estuvo dormido, menos hoy mientras
  /// siga en blanco.
  final int days;
  final int of;

  /// Cuántas veces faltaste seguido dentro del tramo, y el hueco más largo.
  ///
  /// Sólo los huecos **cerrados**: faltar y volver. Los días en blanco con los
  /// que acaba el tramo no son un hueco todavía —no se sabe cuánto va a durar—
  /// y van aparte, en [trailing].
  final int gaps;
  final int longest;

  /// Los días en blanco con los que se acabó el tramo, sin volver.
  ///
  /// Van aparte por una razón que se notó al escribir la página: un pueblo con
  /// cinco piezas en marzo y nada desde entonces tenía cero huecos —el de siete
  /// meses nunca se cerró— y la página anunciaba muy seria que no había faltado
  /// un solo día. En un mes en curso esto es lo que llevás sin aparecer; en uno
  /// cerrado, cómo acabó.
  final int trailing;

  /// Las obras que se remataron dentro, en orden.
  final List<WorkSpan> works;

  /// Y la que quedó en obra al acabar el tramo, si quedó alguna.
  final WorkSpan? underway;

  /// Lo mismo del tramo anterior, para poder comparar. Nulo cuando no hay tramo
  /// anterior con nada dentro: un pueblo fundado este mes no tiene con qué
  /// compararse, y una comparación contra un mes en el que no existía sería una
  /// caída inventada.
  final Review? before;

  /// La frase del título, **si ya estaba ganado al acabar el tramo**.
  ///
  /// Nulo mientras no lo esté, y sin decir lo que falta: el título no se
  /// anuncia ni se cuenta hacia él en ninguna pantalla. Y al acabar el tramo y
  /// no hoy — la cuenta de abril del año pasado dice lo que el pueblo decía en
  /// abril del año pasado; si el título se ganó en junio, en la hoja de abril
  /// no está, porque reescribir el pasado para que quede mejor es la otra
  /// manera de mentir.
  final String? identity;

  /// El plan, y qué parte de las piezas del tramo cayó a su hora.
  final String? plan;
  final double? planKept;

  /// De los días que contaban, en cuántos hubo pieza.
  double get rate => of <= 0 ? 0 : days / of;

  /// Si hay bastante dentro para que la cuenta diga algo.
  ///
  /// Dos semanas de días contados, que es el mismo suelo que usa la constancia
  /// de la barra de arriba, y por lo mismo: «V de V días» la semana que fundaste
  /// el pueblo no es una medida de nada, y esta app prefiere callarse a inventar.
  /// Con tres días puestos por lo menos — un mes con una sola pieza no tiene
  /// hueco, ni ritmo, ni nada que comparar.
  bool get enough => of >= 14 && days >= 3;

  /// Cuántos días del tramo anterior cambió la cosa, en puntos de porcentaje.
  /// Nulo si no hay con qué comparar.
  int? get shift {
    final antes = before;
    if (antes == null || !antes.enough) return null;
    return ((rate - antes.rate) * 100).round();
  }

  /// La cuenta de un mes.
  static Review forMonth(Habit h, int year, int month, {DateTime? now}) => _of(
    h,
    DateTime(year, month, 1),
    DateTime(year, month + 1, 1),
    now: now,
    monthly: true,
  );

  /// La cuenta de un año.
  static Review forYear(Habit h, int year, {DateTime? now}) => _of(
    h,
    DateTime(year, 1, 1),
    DateTime(year + 1, 1, 1),
    now: now,
    monthly: false,
  );

  /// Las cuentas que valen la pena de este pueblo, en el orden en que se leen.
  ///
  /// Cuatro como mucho: este mes, el pasado, este año y el pasado. No una por
  /// mes desde que existe el pueblo — un libro con treinta páginas de cuentas
  /// es un libro que no se abre, y la cuenta de marzo del año pasado no se mira
  /// nunca. Lo que se mira es lo último cerrado y lo que va.
  ///
  /// El año en curso sólo sale cuando dice algo más que el mes en curso, o sea
  /// cuando el pueblo ya tenía piezas antes de este mes; y ninguna sale vacía.
  static List<Review> latest(Habit h, {DateTime? now}) {
    final hoy = now ?? DateTime.now();
    final out = <Review>[];
    void maybe(Review r) {
      if (r.enough) out.add(r);
    }

    final esteMes = forMonth(h, hoy.year, hoy.month, now: hoy);
    maybe(esteMes);
    final antes = DateTime(hoy.year, hoy.month - 1, 1);
    maybe(forMonth(h, antes.year, antes.month, now: hoy));
    // Si todo lo del año está en este mes, la página del año sería la misma
    // página escrita dos veces.
    final esteAno = forYear(h, hoy.year, now: hoy);
    if (esteAno.enough && esteAno.pieces > esteMes.pieces) out.add(esteAno);
    maybe(forYear(h, hoy.year - 1, now: hoy));
    return out;
  }

  static Review _of(
    Habit h,
    DateTime from,
    DateTime to, {
    required bool monthly,
    DateTime? now,
    bool withBefore = true,
  }) {
    final hoy = dayStart(now ?? DateTime.now());
    final abierto = to.isAfter(hoy);

    // Los días del tramo que de verdad contaban.
    var desde = from;
    var nace = dayStart(h.createdAt);
    final todos = daysOf(h);
    if (todos.isNotEmpty && todos.first.isBefore(nace)) nace = todos.first;
    if (nace.isAfter(desde)) desde = nace;
    var hasta = to.subtract(const Duration(days: 1));
    if (hasta.isAfter(hoy)) hasta = hoy;

    final conPieza = <int>{for (final d in todos) dayKey(d)};
    var dias = 0, contados = 0, huecos = 0, mayor = 0, corriendo = 0;
    var visto = false;
    for (var d = desde; !d.isAfter(hasta); d = d.add(const Duration(days: 1))) {
      final hubo = conPieza.contains(dayKey(d));
      if (hubo) {
        dias++;
        contados++;
        // Un hueco se cierra al volver, y sólo entonces cuenta: los días en
        // blanco del final del mes todavía no son un hueco, son un mes que no
        // ha acabado.
        if (corriendo > 0) {
          huecos++;
          if (corriendo > mayor) mayor = corriendo;
          corriendo = 0;
        }
        visto = true;
        continue;
      }
      if (h.restedOn(d)) continue;
      // Hoy en blanco no cuenta en contra: el día no ha terminado.
      if (d == hoy) continue;
      contados++;
      if (visto) corriendo++;
    }

    var piezas = 0;
    var aLaHora = 0;
    for (final p in h.pieces) {
      final at = p.placedAt;
      if (at.isBefore(from) || !at.isBefore(to)) continue;
      piezas++;
      final hora = h.vowHour;
      if (hora != null && hoursApart(at.hour, hora) <= 1) aLaHora++;
    }

    // Las obras: las que se remataron dentro, y la que estaba en pie a medias
    // al acabar el tramo.
    final obras = <WorkSpan>[];
    WorkSpan? enObra;
    for (final w in worksOf(h)) {
      final fin = w.ended;
      if (fin != null && !fin.isBefore(from) && fin.isBefore(to)) {
        obras.add(w);
      }
      if (w.began.isBefore(to) && (fin == null || !fin.isBefore(to))) {
        enObra = w;
      }
    }

    Review? anterior;
    if (withBefore) {
      final atras = monthly
          ? _of(
              h,
              DateTime(from.year, from.month - 1, 1),
              from,
              monthly: true,
              now: now,
              withBefore: false,
            )
          : _of(
              h,
              DateTime(from.year - 1, 1, 1),
              from,
              monthly: false,
              now: now,
              withBefore: false,
            );
      if (atras.enough) anterior = atras;
    }

    return Review(
      heading: _heading(from, monthly: monthly, open: abierto),
      from: from,
      to: to,
      monthly: monthly,
      open: abierto,
      pieces: piezas,
      days: dias,
      of: contados,
      gaps: huecos,
      longest: mayor,
      trailing: corriendo,
      works: obras,
      underway: enObra,
      before: anterior,
      identity: () {
        final gano = h.identityWonAt;
        return gano == null || dayStart(gano).isAfter(hasta)
            ? null
            : identitySaid(h);
      }(),
      plan: vowOf(h),
      planKept: h.vowHour == null || piezas < 5 ? null : aLaHora / piezas,
    );
  }

  /// «ASÍ FUE MAYO», «ASÍ VA ESTE MES», «ASÍ FUE EL AÑO MMXXV».
  ///
  /// El mes en curso se llama «este mes» y no por su nombre: quien lo lee está
  /// dentro de él, y decirle «así va mayo» le hace mirar la fecha para saber si
  /// es el suyo.
  static String _heading(
    DateTime from, {
    required bool monthly,
    required bool open,
  }) {
    if (monthly) {
      return open
          ? 'ASÍ VA ESTE MES'
          : 'ASÍ FUE ${_months[from.month - 1].toUpperCase()}';
    }
    return open ? 'ASÍ VA EL AÑO' : 'ASÍ FUE EL AÑO';
  }

  static const List<String> _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
}
