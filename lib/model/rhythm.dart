/// Cómo se lee un hábito: los días que cuentan, los huecos, y cuánto aguanta.
///
/// La capa de en medio entre las piezas guardadas y lo que el pueblo dice de
/// vos. Ninguna de estas funciones escribe una frase — devuelven números y
/// rachas de días— y son las mismas que usa el almacén para decidir cuándo
/// preguntarte si seguís ahí y cuándo dejar de contar los días de una pausa.
///
/// Estaban mezcladas con los ocho detectores que las consumen, y ahí no se
/// veía que fueran una capa: parecían funciones auxiliares de la de al lado.
/// Son el vocabulario con el que esta app mide la constancia, que es de lo que
/// va toda la app, y es lo que sustituyó a la racha.
library;

import 'habit.dart';
import 'piece.dart';

/// How far back a question about how you are doing is worth asking.
///
/// Half a year. A habit somebody kept beautifully in 2023 and dropped in 2024
/// would otherwise go on being described by 2023 for ever, and the board is
/// meant to say what is true of you now.
const int lookBack = 180;

// ----------------------------------------------------------------- the days

/// Every day this habit was touched at all, in order and without repeats.
List<DateTime> daysOf(Habit h) {
  final set = <int, DateTime>{};
  for (final p in h.pieces) {
    final d = dayStart(p.placedAt);
    set[dayKey(d)] = d;
  }
  final list = set.values.toList()..sort();
  return list;
}

/// Qué fue de un día del calendario.
///
/// Tres estados y no dos, porque un día dormido no es un día en blanco. Sin
/// esta distinción una pausa de tres semanas entra en todas las cuentas como
/// veintiún fallos, y el pueblo acaba anunciando muy serio que los martes son
/// tu día flojo porque pausaste tres martes.
enum Was {
  /// Hubo pieza.
  on,

  /// No hubo pieza, y contaba.
  off,

  /// El pueblo estaba dormido. No cuenta ni a favor ni en contra.
  asleep,
}

/// One entry per calendar day over that window, saying what became of it.
/// This is the grid every question about consistency is really asking about.
List<Was> gridOf(Habit h, DateTime now) {
  final days = daysOf(h);
  if (days.isEmpty) return const [];
  final today = dayStart(now);
  final edge = today.subtract(const Duration(days: lookBack));
  final first = days.first.isAfter(edge) ? days.first : edge;
  final span = today.difference(first).inDays;
  if (span < 0) return const [];
  final on = <int>{for (final d in days) dayKey(d)};
  return [
    for (var i = 0; i <= span; i++)
      () {
        final d = first.add(Duration(days: i));
        // Una pieza puesta durante una pausa cuenta igual. Volver antes de
        // tiempo no es hacer trampa, es volver — y si el día tiene pieza, lo
        // último que la app tiene que hacer es no contarla.
        if (on.contains(dayKey(d))) return Was.on;
        return h.restedOn(d) ? Was.asleep : Was.off;
      }(),
  ];
}

/// Los huecos de este hábito: cuántos días de los que contaban pasaron entre
/// una pieza y la siguiente.
///
/// Los días dormidos salen de la cuenta, así que una pausa de tres semanas en
/// medio de dos piezas seguidas no es un hueco de veintiún días: no es un
/// hueco. Es la diferencia entre no haber podido y no haber querido, que es
/// justo lo que la pausa existe para decir.
List<int> gapsOf(Habit h) {
  final days = daysOf(h);
  final out = <int>[];
  for (var i = 1; i < days.length; i++) {
    var missed = 0;
    for (
      var d = days[i - 1].add(const Duration(days: 1));
      d.isBefore(days[i]);
      d = d.add(const Duration(days: 1))
    ) {
      if (!h.restedOn(d)) missed++;
    }
    if (missed > 0) out.add(missed);
  }
  return out;
}

/// Cuánto tardás en volver, normalmente. Nulo mientras no haya faltado lo
/// bastante como para que la pregunta tenga respuesta.
///
/// Es la única cifra de esta app que mejora cuando fallás: alguien que pasó de
/// desaparecer treinta días a desaparecer cinco está progresando muchísimo, y
/// no hay ninguna racha que sepa decirlo.
int? typicalReturn(Habit h) {
  final gaps = gapsOf(h);
  if (gaps.length < 3) return null;
  final sorted = [...gaps]..sort();
  return sorted[sorted.length ~/ 2];
}

/// De los días que contaban, en cuántos hubo pieza.
///
/// Lo que sustituyó a la racha, y el cambio no es cosmético. Una racha hace
/// que el pasado pese demasiado: fallás hoy y parece que pasaste de cuarenta a
/// cero, cuando lo que pasó de verdad es que hiciste el hábito cuarenta días y
/// hoy no. Esto dice lo que pasó de verdad, y admite imperfección, que es
/// justamente lo que hace falta para medir algo sostenible.
class Consistency {
  const Consistency(this.done, this.of);

  /// Días con pieza.
  final int done;

  /// Días que contaban: la ventana, menos los días dormidos, menos los días
  /// anteriores al hábito, menos hoy si todavía está sin empezar.
  final int of;

  double get rate => of <= 0 ? 0 : done / of;

  /// Con menos de dos semanas de las que hablar, no se habla.
  ///
  /// Una consistencia de «1 de 1» el primer día no es una medida de nada, y
  /// esta app prefiere callarse a inventar.
  bool get enough => of >= 14;

  static const int window = 30;
}

/// La consistencia de este hábito sobre los últimos [Consistency.window] días.
///
/// Hoy no cuenta en contra mientras esté en blanco. El día no terminó, y
/// descontar por él a las nueve de la mañana es exactamente el castigo que
/// esto vino a quitar; en cuanto cae una pieza, cuenta.
Consistency consistencyOf(Habit h, {DateTime? at}) {
  final now = at ?? DateTime.now();
  final today = dayStart(now);
  final days = daysOf(h);
  if (days.isEmpty) return const Consistency(0, 0);

  var from = today.subtract(const Duration(days: Consistency.window - 1));
  // Ni antes de que existiera el hábito ni antes de su primera pieza: repartir
  // tus piezas entre días en los que no había dónde ponerlas es inventarse
  // fallos.
  var born = dayStart(h.createdAt);
  if (days.first.isBefore(born)) born = days.first;
  if (born.isAfter(from)) from = born;

  final on = <int>{for (final d in days) dayKey(d)};
  var done = 0, counted = 0;
  for (var d = from; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
    final hecho = on.contains(dayKey(d));
    if (hecho) {
      done++;
      counted++;
      continue;
    }
    if (h.restedOn(d)) continue;
    if (d == today) continue;
    counted++;
  }
  return Consistency(done, counted);
}

/// Un día por barra, de [from] a [today], contra el día más cargado.
List<double> dailyOf(Habit h, DateTime from, DateTime today) {
  final span = today.difference(from).inDays;
  if (span < 0) return const [];
  final counts = List<double>.filled(span + 1, 0);
  for (final p in h.pieces) {
    final at = dayStart(p.placedAt).difference(from).inDays;
    if (at >= 0 && at <= span) counts[at] += 1;
  }
  var top = 1.0;
  for (final c in counts) {
    if (c > top) top = c;
  }
  return [for (final c in counts) c / top];
}

/// The last [n] weeks as a strip, each week its own bar against the busiest.
List<double> weeksOf(Habit h, DateTime now, int n) {
  final counts = List<double>.filled(n, 0);
  final today = dayStart(now);
  for (final p in h.pieces) {
    final back = today.difference(dayStart(p.placedAt)).inDays;
    if (back < 0) continue;
    final week = back ~/ 7;
    if (week < n) counts[n - 1 - week] += 1;
  }
  var top = 1.0;
  for (final c in counts) {
    if (c > top) top = c;
  }
  return [for (final c in counts) c / top];
}
