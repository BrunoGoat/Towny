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
int? observedPerWeek(Habit h, {DateTime? at}) {
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
  return (on * 7 / span).round().clamp(1, 7);
}

/// Cada cuánto va: lo dicho si se dijo, si no lo que se ve, y si todavía no se
/// ve nada, todos los días — que es lo que la app suponía siempre.
int perWeekOf(Habit h, {DateTime? at}) =>
    h.perWeek ?? observedPerWeek(h, at: at) ?? 7;

/// Si ya toca preguntar por la frecuencia de este hábito.
///
/// Una vez en la vida del hábito: se apunta al preguntar, conteste lo que
/// conteste, igual que la pregunta de si seguimos. Cerrar la hoja también es
/// una respuesta —«ahora no»— y de ahí en adelante vale lo que se ve.
bool cadenceDue(Habit h, {DateTime? at}) {
  if (h.perWeek != null || h.cadenceAskedAt != null) return false;
  if (h.resting) return false;
  final now = at ?? DateTime.now();
  if (daysBetween(h.createdAt, now) < cadenceAskAfterDays) {
    return false;
  }
  return daysOf(h).length >= cadenceAskLeast;
}

/// Lo que se le cuenta a quien se le pregunta: cuántas piezas y en cuántos
/// días, en la primera semana o en la última, la que sea más reciente.
(int pieces, int days) lastWeekOf(Habit h, {DateTime? at}) {
  final today = dayStart(at ?? DateTime.now());
  final from = DateTime(today.year, today.month, today.day - 6);
  var pieces = 0;
  final set = <int>{};
  for (final p in h.pieces) {
    final d = dayStart(p.placedAt);
    if (d.isBefore(from) || d.isAfter(today)) continue;
    pieces++;
    set.add(dayKey(d));
  }
  return (pieces, set.length);
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
String cadenceSaid(int perWeek) => switch (perWeek) {
  7 => tr('todos los días', 'every day'),
  1 => tr('una vez por semana', 'once a week'),
  _ => tr('$perWeek veces por semana', '$perWeek times a week'),
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
/// Y lo que pasa de tu ritmo en una semana no cuenta para la siguiente. Quien
/// va una vez por semana y pone tres piezas un domingo lleva una semana, no
/// tres: lo que se demuestra es que se sostiene, no que se puede apretar.
class UnlockGoal {
  const UnlockGoal({
    required this.perWeek,
    required this.window,
    required this.need,
    required this.have,
    this.declared = false,
  });

  /// El ritmo contra el que se mide.
  final int perWeek;

  /// En cuántos días se puede juntar.
  final int window;

  /// Cuánto hace falta.
  final int need;

  /// Cuánto llevás, ya recortado a tu ritmo semana a semana.
  final int have;

  /// Si el ritmo lo dijiste vos. Si no, se mide como de todos los días.
  final bool declared;

  /// Cuántas veces se puede fallar por el camino y abrir igual.
  int get slack => perWeek * window ~/ 7 - need;

  bool get met => have >= need;
  double get progress => need <= 0 ? 1 : (have / need).clamp(0.0, 1.0);

  /// Qué parte de lo esperable hay que juntar.
  static const double share = 0.7;

  static UnlockGoal of(Habit h, {DateTime? at}) {
    final now = at ?? DateTime.now();
    // Lo dicho y no lo visto. Lo visto sale de las mismas piezas que se están
    // contando, así que pedir un setenta por ciento de tu propio ritmo lo
    // cumple cualquiera: el candado dejaría de ser un candado. Sin decir, vale
    // lo de siempre, todos los días.
    final f = h.perWeek ?? 7;
    final window = f >= 3 ? 14 : 28;
    final need = (share * f * window / 7 - 1e-9).ceil();
    final today = dayStart(now);
    final on = <int>{
      for (final p in h.pieces)
        if (!dayStart(p.placedAt).isAfter(today)) dayKey(dayStart(p.placedAt)),
    };
    var have = 0;
    // Semanas de siete días hacia atrás desde hoy, y en cada una como mucho tu
    // ritmo. Para quien va a diario esto es contar los días, igual que antes.
    for (var w = 0; w < window ~/ 7; w++) {
      var semana = 0;
      for (var i = 0; i < 7; i++) {
        // Por el calendario y no por horas: un día con cambio de hora no
        // mide veinticuatro.
        final d = DateTime(today.year, today.month, today.day - w * 7 - i);
        if (on.contains(dayKey(d))) semana++;
      }
      have += math.min(semana, f);
    }
    return UnlockGoal(
      perWeek: f,
      window: window,
      need: need,
      have: have,
      declared: h.perWeek != null,
    );
  }
}
