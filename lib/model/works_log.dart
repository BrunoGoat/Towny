import '../engine/town.dart';
import 'habit.dart';
import 'piece.dart';

/// Cuándo se levantó cada obra de un pueblo.
///
/// La bitácora fecha cada pieza desde el primer día; las obras no estaban
/// fechadas, y son lo que uno recuerda. «Catedral, empezada el tres de mayo,
/// rematada el dos de julio, sesenta y un días» convierte el pueblo en un
/// calendario de la propia vida: se mira la colegiata y se sabe qué dos meses
/// fueron.
///
/// **No se guarda nada nuevo.** Sale de lo que ya está escrito: la crónica
/// dice en qué orden se construye, el plan dice en qué pieza empieza cada obra
/// y cuántas cuesta, y cada pieza lleva su fecha desde siempre. Por eso
/// funciona hacia atrás, en pueblos levantados hace un año por una versión de
/// la app que no sabía nada de esto.
class WorkSpan {
  const WorkSpan({
    required this.id,
    required this.name,
    required this.cost,
    required this.from,
    required this.began,
    this.ended,
  });

  /// El hito del catálogo.
  final String id;
  final String name;

  /// Lo que costó, en piezas.
  final int cost;

  /// La pieza con la que se empezó, contando desde cero.
  final int from;

  /// El día en que se puso la primera piedra.
  final DateTime began;

  /// El día en que se remató, o nulo si todavía está en obra.
  final DateTime? ended;

  bool get done => ended != null;

  /// Cuántos días naturales llevó, contando el primero y el último.
  ///
  /// Días y no piezas: una obra de veinte piezas puede llevar veinte días o
  /// tres meses, y lo que cuenta aquí es lo segundo. Por la misma razón se
  /// cuenta por días de calendario y no por horas — empezar un lunes por la
  /// noche y rematar el martes por la mañana son dos días, no uno.
  int daysUntil(DateTime when) =>
      dayStart(when).difference(dayStart(began)).inDays + 1;

  /// Los días que llevó, si está rematada.
  int? get days => ended == null ? null : daysUntil(ended!);
}

/// Las obras de [h], en el orden en que se levantaron.
///
/// Sólo los hitos: las casas, los corrales y los huertos son el pueblo
/// creciendo y no hacen época, y una lista con doscientas entradas de «casa»
/// entre dos catedrales no es un calendario, es un extracto bancario.
///
/// La última puede estar sin rematar, y entonces viene con [WorkSpan.ended] en
/// nulo. No se devuelve nada que no haya empezado: lo que el plan dice del
/// futuro es una previsión, y una previsión no tiene fecha.
List<WorkSpan> worksOf(Habit h) {
  final plan = TownPlan.of(h.place, seed: h.townSeed);
  final out = <WorkSpan>[];
  for (final w in plan.walk(h.chronicle)) {
    if (w.from >= h.pieces.length) break;
    if (w.landmark == null) continue;
    final last = w.from + w.cost - 1;
    out.add(
      WorkSpan(
        id: w.id,
        name: w.landmark!.name,
        cost: w.cost,
        from: w.from,
        began: h.pieces[w.from].placedAt,
        ended: last < h.pieces.length ? h.pieces[last].placedAt : null,
      ),
    );
  }
  return out;
}
