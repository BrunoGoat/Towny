/// Los tropiezos: cuándo un pueblo se quedó sin piedra fuera de tu ritmo, y
/// qué se interpuso.
///
/// El resto de la app mira los huecos largos —la bienvenida al volver, la
/// pregunta de si seguimos— y deja pasar los cortos a propósito: un día sin
/// aparecer no necesita que nadie intervenga. Esto no interviene tampoco. No
/// avisa ni sale solo: el consejero tiene algo que hablar, enciende su punto,
/// y quien quiera va. Lo que pregunta no es por qué fallaste sino qué se
/// interpuso, que es una pregunta que se puede contestar sin culpa.
///
/// Y lo que sirve no es cada respuesta sino el patrón. A la tercera el viejo
/// puede decir que tus caídas vienen casi siempre del cansancio, o que caen
/// en lunes, y eso es algo que uno no ve desde dentro.
library;

import 'cadence.dart';
import 'habit.dart';
import 'piece.dart';
import 'rhythm.dart';

/// Lo que se interpuso. [skipped] es no haber querido contestar: cuenta como
/// preguntado, y no entra en los patrones.
enum Stumble { tired, forgot, tempted, mood, other, skipped }

/// Un tropiezo apuntado: el día que el pueblo se quedó sin piedra y la causa.
class StumbleEntry {
  const StumbleEntry(this.day, this.cause);

  final DateTime day;
  final Stumble cause;

  String encode() => '${day.millisecondsSinceEpoch}|${cause.name}';

  /// Un renglón roto se salta, como en el resto de lo que se guarda a mano.
  static StumbleEntry? parse(String line) {
    final cut = line.indexOf('|');
    if (cut <= 0) return null;
    final ms = int.tryParse(line.substring(0, cut));
    final cause = Stumble.values.where(
      (c) => c.name == line.substring(cut + 1),
    );
    if (ms == null || cause.isEmpty) return null;
    return StumbleEntry(DateTime.fromMillisecondsSinceEpoch(ms), cause.first);
  }
}

/// Los tropiezos de un hábito, ya leídos.
List<StumbleEntry> stumblesOf(Habit h) => [
  for (final line in h.stumbles) ?StumbleEntry.parse(line),
];

/// Con cuántos días con pieza como mínimo se pregunta. Con uno no hay ritmo
/// del que salirse.
const int stumbleLeast = 3;

/// El día que el pueblo salió de tu ritmo, si salió y todavía no se habló de
/// eso. Nulo casi siempre.
///
/// Contra lo tuyo ([expectedGap]): a quien va a diario le basta un día en
/// blanco, y a quien va dos veces por semana, cuatro. Hoy no cuenta —hoy
/// todavía está a tiempo—, ni los días dormidos. Y una vez por hueco: el
/// siguiente tropiezo empieza con la siguiente pieza.
DateTime? stumbleDue(Habit h, {DateTime? at}) {
  final now = at ?? DateTime.now();
  final last = h.lastPlacedAt;
  if (last == null || h.restAt(now) != null) return null;
  if (daysOf(h).length < stumbleLeast) return null;
  // Desde la última pieza, o desde que despertó si durmió después.
  var desde = dayStart(last);
  final woke = h.wokeAt;
  if (woke != null && woke.isAfter(last)) desde = dayStart(woke);
  final hoy = dayStart(now);
  final cabe = expectedGap(h);
  var blancos = 0;
  for (
    var d = DateTime(desde.year, desde.month, desde.day + 1);
    d.isBefore(hoy);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    if (h.restedOn(d)) continue;
    if (++blancos > cabe) {
      // Ya se habló de este hueco.
      for (final s in stumblesOf(h)) {
        if (dayStart(s.day).isAfter(desde)) return null;
      }
      return d;
    }
  }
  return null;
}

/// Lo que se repite en tus tropiezos, de todos los pueblos: la causa que más
/// sale y el día de la semana en que más caen. Cada una nula si no hay
/// bastante para decirlo.
///
/// Hacen falta tres contestados como poco, y que lo que se repite sea de
/// verdad lo que más se repite: la mitad de las veces para la causa, y dos
/// de cada cinco para el día —que hay siete días y cinco causas—.
({Stumble? cause, int? weekday}) stumblePattern(Iterable<Habit> habits) {
  final todos = [
    for (final h in habits)
      for (final s in stumblesOf(h))
        if (s.cause != Stumble.skipped) s,
  ];
  if (todos.length < 3) return (cause: null, weekday: null);
  final causas = <Stumble, int>{};
  final dias = <int, int>{};
  for (final s in todos) {
    if (s.cause != Stumble.other) {
      causas[s.cause] = (causas[s.cause] ?? 0) + 1;
    }
    dias[s.day.weekday] = (dias[s.day.weekday] ?? 0) + 1;
  }
  MapEntry<K, int>? mas<K>(Map<K, int> m) => m.entries.isEmpty
      ? null
      : m.entries.reduce((a, b) => b.value > a.value ? b : a);
  final c = mas(causas);
  final d = mas(dias);
  final n = todos.length;
  return (
    cause: c != null && c.value * 2 >= n ? c.key : null,
    weekday: d != null && d.value >= 2 && d.value * 5 >= n * 2 ? d.key : null,
  );
}
