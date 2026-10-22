/// Cada cuánto va un hábito: lo que dijiste, y lo que se ve.
///
/// Hasta que existió esto la app suponía que todo hábito es de todos los días.
/// No lo decía en ningún sitio, pero lo suponía en todas partes: el candado
/// del segundo pueblo pedía diez días de catorce, y quien corre dos veces por
/// semana no llegaba nunca aunque no hubiera faltado a ninguna.
///
/// Dos fuentes, y ninguna se pregunta el primer día. Al fundar un pueblo sólo
/// se habla de para qué y de en quién te convierte; la frecuencia la pregunta
/// el pueblo al cumplir la primera semana, cuando ya tiene algo que enseñarte
/// —«pusiste nueve piezas en cinco días»— y la respuesta viene marcada con lo
/// que se ve. Si nunca se contesta, vale lo que se ve.
library;

import 'dart:math' as math;

import '../l10n/lang.dart';
import 'habit.dart';
import 'piece.dart';
import 'rhythm.dart';

/// A partir de cuántos días de vida se pregunta por la frecuencia.
///
/// Una semana, porque es lo mínimo que tiene forma de semana: un hábito de los
/// domingos no se ve en cinco días, y uno diario ya se nota de sobra en siete.
const int cadenceAskAfterDays = 7;

/// Y con cuántos días con pieza como mínimo.
///
/// Con uno solo no hay nada que enseñar: «pusiste una pieza en un día» no es
/// algo sobre lo que se pueda preguntar nada.
const int cadenceAskLeast = 2;

/// Cuántos días por semana se ve que va, de 1 a 7. Nulo si no hay bastante.
///
/// Los días con pieza de las últimas cuatro semanas —o desde que existe, si es
/// más nuevo—, llevados a una semana. Hace falta una semana entera de vida
/// como poco: con tres días, uno solo con pieza serían dos por semana, y no se
/// sabe nada.
int? observedPerWeek(Habit h, {DateTime? at}) =>
    observedRate(h, at: at)?.round().clamp(1, 7);

/// Lo mismo sin redondear: cuántas veces por semana, con decimales. Es lo que
/// sabe distinguir «cada dos días» de «tres veces por semana».
double? observedRate(Habit h, {DateTime? at}) {
  final today = dayStart(at ?? DateTime.now());
  final days = daysOf(h);
  if (days.isEmpty) return null;
  var born = dayStart(h.createdAt);
  if (days.first.isBefore(born)) born = days.first;
  var from = DateTime(today.year, today.month, today.day - 27);
  if (born.isAfter(from)) from = born;
  var span = 0, on = 0;
  final set = <int>{for (final d in days) dayKey(d)};
  for (
    var d = from;
    !d.isAfter(today);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    final hecho = set.contains(dayKey(d));
    // Lo dormido no cuenta para ningún lado, y hoy sólo si ya tiene pieza: el
    // día no terminó.
    if (!hecho && (h.restedOn(d) || d == today)) continue;
    span++;
    if (hecho) on++;
  }
  if (span < cadenceAskAfterDays || on == 0) return null;
  return on * 7 / span;
}

/// Las respuestas posibles, en veces por semana.
///
/// No siete botones que dicen casi lo mismo —«seis por semana» y «cinco por
/// semana» son la misma respuesta para el pueblo, y de «todos los días» a
/// «una vez» había siete casi iguales y ninguna otra cosa—, sino cinco
/// maneras distintas de llevar un hábito: a diario, en días sueltos de la
/// semana —y ahí sí, cuántos—, en días alternos, una vez por semana y cada
/// dos semanas.
const double everyOtherDay = 3.5, everyOtherWeek = 0.5;

/// Cuántos días por semana se pueden decir en «algunos días por semana».
const List<int> someDaysAWeek = [2, 3, 4, 5, 6];

/// Todas las frecuencias que se pueden decir.
const List<double> cadenceChoices = [
  7,
  6,
  5,
  4,
  everyOtherDay,
  3,
  2,
  1,
  everyOtherWeek,
];

/// La que más se parece a lo que se ve: la que viene marcada.
double nearestCadence(double rate) {
  var mejor = cadenceChoices.first;
  for (final c in cadenceChoices) {
    if ((c - rate).abs() < (mejor - rate).abs() - 1e-9) mejor = c;
  }
  return mejor;
}

/// Cada cuánto va: lo dicho si se dijo, si no lo que se ve, y si todavía no se
/// ve nada, todos los días — que es lo que la app suponía siempre.
double perWeekOf(Habit h, {DateTime? at}) =>
    h.perWeek ?? observedPerWeek(h, at: at)?.toDouble() ?? 7;

/// Si ya toca preguntar por la frecuencia de este hábito.
///
/// Hasta que se conteste. Antes se preguntaba una vez y cerrar era contestar,
/// y una pregunta que llega en mal momento se cierra sin leer: ahora se
/// presenta primero —«contanos más de tu hábito», con un «ahora no»— y quien
/// dice que ahora no la vuelve a ver al día siguiente.
bool cadenceDue(Habit h, {DateTime? at}) {
  if (h.perWeek != null || h.cadenceAskedAt != null) return false;
  if (h.resting) return false;
  final now = at ?? DateTime.now();
  final luego = h.cadenceLaterAt;
  if (luego != null && !dayStart(now).isAfter(dayStart(luego))) return false;
  if (daysBetween(h.createdAt, now) < cadenceAskAfterDays) {
    return false;
  }
  return daysOf(h).length >= cadenceAskLeast;
}

/// Lo que se le cuenta a quien se le pregunta: cuántas piezas puso y en
/// cuántos días desde que empezó.
///
/// Los días **desde que empezó**, no los días con pieza. «Cuatro piezas en
/// cuatro días» parecía decir que fue a diario, cuando eran cuatro de siete:
/// el dato que hace pensar en el ritmo es el hueco, y contando sólo los días
/// con pieza el hueco no aparece nunca.
(int pieces, int days) sinceStartOf(Habit h, {DateTime? at}) {
  final today = dayStart(at ?? DateTime.now());
  var born = dayStart(h.createdAt);
  var pieces = 0;
  for (final p in h.pieces) {
    final d = dayStart(p.placedAt);
    if (d.isAfter(today)) continue;
    pieces++;
    if (d.isBefore(born)) born = d;
  }
  return (pieces, math.max(1, daysBetween(born, today)));
}

/// Cuántos días en blanco caben entre dos piezas sin salirse de lo tuyo.
///
/// Lo más largo de dos cosas: lo que dijiste —dos veces por semana son tres
/// días en blanco entre una y otra— y lo que se ve que hacés. Lo más largo y no
/// lo más corto, porque esto decide cuándo el pueblo se preocupa, y
/// preocuparse de más es lo que hace que una app se desinstale.
int expectedGap(Habit h) {
  final dicho = h.perWeek;
  final visto = typicalReturn(h);
  final porDicho = dicho == null ? 0 : (7 / dicho).round() - 1;
  return math.max(porDicho, visto ?? 0);
}

/// La frecuencia dicha con palabras, como la dice el pueblo.
String cadenceSaid(double perWeek) => switch (perWeek) {
  >= 7 => tr('todos los días', 'every day'),
  everyOtherDay => tr('cada dos días', 'every other day'),
  1 => tr('una vez por semana', 'once a week'),
  everyOtherWeek => tr('cada dos semanas', 'every other week'),
  _ => tr(
    '${perWeek.round()} veces por semana',
    '${perWeek.round()} times a week',
  ),
};

// ------------------------------------------------------------------ el candado

/// Lo que pide el valle para abrir el segundo solar, medido contra el ritmo de
/// un hábito.
///
/// La regla de siempre —diez días con pieza de los últimos catorce— es un
/// setenta por ciento de lo esperable para quien va a diario, con cuatro
/// faltas de margen. Esto es lo mismo para cualquier ritmo: un setenta por
/// ciento de lo que dijiste, en una ventana de dos semanas; o de cuatro si es
/// una o dos veces por semana, porque dos piezas en dos semanas no demuestran
/// nada de nadie.
///
/// Y lo que pasa de tu ritmo en siete días seguidos no cuenta. Quien va una
/// vez por semana y pone tres piezas un domingo lleva una semana, no tres: lo
/// que se demuestra es que se sostiene, no que se puede apretar.
/// Cómo quedó un día dentro de la cuenta del candado.
enum DayMark {
  /// Con pieza, y cuenta.
  counted,

  /// Con pieza, pero esa semana ya iba por encima de su ritmo: no suma.
  extra,

  /// Despierto y sin pieza.
  missed,

  /// En pausa y sin pieza: la cuenta se lo salta.
  asleep,

  /// Antes de que el pueblo existiera.
  unborn,
}

class UnlockGoal {
  const UnlockGoal({
    required this.perWeek,
    required this.window,
    required this.need,
    required this.have,
    this.declared = false,
    this.resting = false,
    this.restDays = 0,
    this.calendar = const [],
    double? expectedFull,
    double? expectedLived,
  }) : expectedFull = expectedFull ?? perWeek * window / 7,
       expectedLived = expectedLived ?? expectedFull ?? perWeek * window / 7;

  /// El ritmo contra el que se mide, en veces por semana.
  final double perWeek;

  /// Cuántas valen como mucho en una semana: el ritmo, hacia arriba. Quien va
  /// cada dos días tiene semanas de tres y semanas de cuatro.
  int get cap => perWeek.ceil();

  /// En cuántos días se puede juntar.
  final int window;

  /// Cuánto hace falta.
  final int need;

  /// Cuánto llevás, ya recortado a tu ritmo semana a semana.
  final int have;

  /// Si el ritmo lo dijiste vos. Si no, se mide como de todos los días.
  final bool declared;

  /// Si el pueblo está en pausa ahora. No pierde nada por eso —lo que lleva
  /// queda guardado—, pero mientras duerme no abre la puerta: el siguiente
  /// pueblo se gana sosteniendo todos los que hay, y uno dormido no se está
  /// sosteniendo. Si no, alcanzaría con pausar todos menos uno para abrir el
  /// valle entero.
  final bool resting;

  /// Cuántos días en pausa se saltó la cuenta para llegar a [window] días
  /// despiertos.
  final int restDays;

  /// Los días que mira la cuenta, del más viejo a hoy, y cómo quedó cada
  /// uno: para enseñarlos, no para contar.
  final List<(DateTime, DayMark)> calendar;

  /// Cuántos días con pieza pide la ventana entera, cada día con el ritmo
  /// que tenía: el cien por cien, del que [need] es el setenta.
  final double expectedFull;

  /// Lo mismo, contando sólo los días en que el pueblo ya existía: contra
  /// esto se dice el porcentaje, para que un pueblo nuevo no arranque
  /// castigado por los días en que no estaba.
  final double expectedLived;

  /// Cuántas veces se puede fallar por el camino y abrir igual.
  int get slack => (perWeek * window / 7 + 1e-9).floor() - need;

  bool get met => !resting && have >= need;
  double get progress => need <= 0 ? 1 : (have / need).clamp(0.0, 1.0);

  /// Qué parte de lo esperable lleva, en por ciento: los días con pieza
  /// contra los que pide su ritmo en la ventana.
  ///
  /// Redondeado de manera que no contradiga a [met] —hace falta llegar a
  /// [need], que es el setenta por ciento hacia arriba—: llegado nunca dice
  /// menos que la meta, y sin llegar nunca dice la meta.
  int get percent {
    final p = expectedLived <= 0
        ? 0
        : (100 * have / expectedLived).round().clamp(0, 100);
    final meta = goalPercent;
    // Llegado, nunca menos que la meta. Sin llegar con la ventana entera
    // vivida, nunca la meta. Un pueblo más nuevo que la ventana puede ir por
    // encima —va bien— y todavía no llegar: le faltan días, no ganas.
    if (have >= need) return math.max(p, meta);
    if (!young) return math.min(p, meta - 1);
    return p;
  }

  /// Si el pueblo es más nuevo que la ventana: tiene días de antes de
  /// fundarse dentro de la cuenta.
  bool get young => expectedLived < expectedFull - 1e-9;

  /// Si va al ritmo de la meta, haya llegado o no: lo que pinta la cuenta.
  bool get onTrack => !resting && percent >= goalPercent;

  /// Cuántos días con pieza pide su ritmo entero en la ventana: el cien por
  /// cien, del que [need] es el setenta.
  int get expected => math.max(need, expectedFull.round());

  /// La meta, en por ciento: [share].
  static int get goalPercent => (share * 100).round();

  /// Qué parte de lo esperable hay que juntar.
  static const double share = 0.7;

  static UnlockGoal of(Habit h, {DateTime? at}) {
    final now = at ?? DateTime.now();
    // Lo dicho y no lo visto. Lo visto sale de las mismas piezas que se están
    // contando, así que pedir un setenta por ciento de tu propio ritmo lo
    // cumple cualquiera: el candado dejaría de ser un candado. Sin decir, vale
    // lo de siempre, todos los días.
    final f = h.perWeek ?? 7.0;
    final window = f >= 3 ? 14 : 28;
    final today = dayStart(now);
    final born = dayStart(h.createdAt);
    // **La ventana cuenta días despiertos.** Un día en pausa sin pieza no
    // cuenta ni a favor ni en contra: la ventana se corre hacia atrás para
    // saltarlo. Pausar una semana y volver a los dos días no tira lo que se
    // llevaba —esos dos días no existen para la cuenta—, que es para lo que
    // está la pausa. Con un tope de un año, para que una pausa eterna no haga
    // buscar para siempre.
    final conPieza = {for (final p in h.pieces) dayKey(dayStart(p.placedAt))};
    var desde = today;
    var despiertos = 0;
    var dormidos = 0;
    for (var i = 0; despiertos < window && i < window + 366; i++) {
      final d = DateTime(today.year, today.month, today.day - i);
      if (!d.isBefore(born) && h.restedOn(d) && !conPieza.contains(dayKey(d))) {
        dormidos++;
      } else {
        despiertos++;
      }
      desde = d;
    }
    // **Cada día con el ritmo que tenía** ([Habit.paceOn]). Lo que se pide es
    // la suma: bajar el ritmo hoy alivia de hoy en adelante, no hacia atrás.
    // Los días de antes de fundar el pueblo cuentan para lo que se pide —la
    // puerta pide la ventana entera— pero no para el porcentaje.
    var pide = 0.0;
    var vivido = 0.0;
    for (
      var d = desde;
      !d.isAfter(today);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      final nacido = !d.isBefore(born);
      if (nacido && h.restedOn(d) && !conPieza.contains(dayKey(d))) continue;
      final r = h.paceOn(nacido ? d : born) / 7;
      pide += r;
      if (nacido) vivido += r;
    }
    final need = (share * pide - 1e-9).ceil();
    // Los días con pieza dentro de la ventana, de más viejo a más nuevo.
    final dias = <DateTime>[];
    final vistos = <int>{};
    for (final p in h.pieces) {
      final d = dayStart(p.placedAt);
      if (d.isBefore(desde) || d.isAfter(today)) continue;
      if (vistos.add(dayKey(d))) dias.add(d);
    }
    dias.sort();
    // **Como mucho tu ritmo en cualquier tramo de siete días, y no en semanas
    // contadas desde hoy.** Se contaba por semanas hacia atrás desde hoy, y
    // como el corte entre semana y semana se corría cada día, las mismas
    // piezas podían quedar mejor repartidas mañana que hoy: la puerta se abría
    // al cambiar de día sin haber puesto nada. Así no depende de dónde caen
    // los cortes: se quedan los días que se pueden quedar sin pasarse del
    // ritmo en ninguna semana —de más viejo a más nuevo, que es la manera de
    // quedarse con más—, y la cuenta sólo sube al poner una pieza. Con los
    // días que pasan, como mucho baja. El tope es el ritmo de ese día.
    final quedan = <DateTime>[];
    for (final d in dias) {
      var enSemana = 0;
      for (final q in quedan) {
        if (daysBetween(q, d) < 7) enSemana++;
      }
      if (enSemana < h.paceOn(d).ceil()) quedan.add(d);
    }
    final have = quedan.length;
    final cuentan = {for (final d in quedan) dayKey(d)};
    final calendar = <(DateTime, DayMark)>[
      for (
        var d = desde;
        !d.isAfter(today);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        (
          d,
          d.isBefore(born)
              ? DayMark.unborn
              : cuentan.contains(dayKey(d))
              ? DayMark.counted
              : conPieza.contains(dayKey(d))
              ? DayMark.extra
              : h.restedOn(d)
              ? DayMark.asleep
              : DayMark.missed,
        ),
    ];
    return UnlockGoal(
      perWeek: f,
      window: window,
      need: need,
      have: have,
      declared: h.perWeek != null,
      resting: h.restAt(now) != null,
      restDays: dormidos,
      calendar: calendar,
      expectedFull: pide,
      expectedLived: vivido,
    );
  }
}
