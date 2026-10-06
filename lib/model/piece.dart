/// One achievement, one piece. The index is its permanent place in the town.
class Piece {
  const Piece({required this.index, required this.placedAt});

  final int index;
  final DateTime placedAt;

  /// La misma pieza, en otro sitio de la fila.
  ///
  /// Hace falta porque una pieza puede llegar **con retraso**: la que se puso
  /// desde el widget el sábado se entera la app el domingo, y si ese día ya se
  /// puso alguna en la app, la del sábado entra en medio. Lo que no puede es
  /// quedar con el número de otra, porque el número es su sitio en el pueblo.
  Piece withIndex(int at) => Piece(index: at, placedAt: placedAt);

  /// La misma pieza, puesta a otra hora.
  ///
  /// Se corrige, no se inventa: la app apunta la hora en que tocaste el botón,
  /// y esa no siempre es la hora en que hiciste la cosa. Se corre a las once
  /// de la noche lo que se hizo a las siete de la mañana, y el pueblo va y lo
  /// anota como una costumbre nocturna. El tablón se fija en eso.
  Piece withWhen(DateTime when) => Piece(index: index, placedAt: when);

  Map<String, dynamic> toJson() => {
    'i': index,
    't': placedAt.millisecondsSinceEpoch,
  };

  static Piece fromJson(Map<String, dynamic> j) => Piece(
    index: (j['i'] as num).toInt(),
    placedAt: DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
  );
}

/// A single day in the person's history, used by the small activity strip.
class DayTally {
  DayTally(this.day, this.count);
  final DateTime day;
  final int count;
}

int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// El mismo momento del reloj, [n] días de calendario después (o antes).
///
/// **No es sumar veinticuatro horas.** El día en que cambia la hora dura
/// veintitrés o veinticinco, y una cuenta de días hecha con `Duration` se corre
/// una hora cada vez que lo cruza: la medianoche pasa a ser la una o las once
/// de la noche del día anterior, y un día deja de contarse o se cuenta dos
/// veces. En un país con horario de verano eso pasa dos veces al año, dentro
/// de cualquier ventana de treinta días que lo cruce.
DateTime shiftDays(DateTime d, int n) => DateTime(
  d.year,
  d.month,
  d.day + n,
  d.hour,
  d.minute,
  d.second,
  d.millisecond,
  d.microsecond,
);

/// Cuántos días de calendario van de [a] a [b]: del lunes al miércoles son
/// dos, a cualquier hora y aunque en medio haya cambiado la hora. Ver
/// [shiftDays].
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
