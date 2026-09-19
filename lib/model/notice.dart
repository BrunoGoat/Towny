/// Un papel clavado en el tablón, y de qué clase es.
///
/// Sólo el tipo. Lo escribe `findings.dart` y lo leen once ficheros más —el
/// tablón, el papel, la letra manuscrita, los bandos del pueblo, lo que ya se
/// ha leído—, y hasta ahora todos ellos importaban las mil cien líneas de
/// detectores para poder nombrarlo. Ninguno de los once necesita saber cómo se
/// averigua a qué hora del día ponés tus piezas; todos necesitan saber qué
/// campos tiene un papel.
library;

/// What kind of thing a notice is, so the board can put them in a sensible
/// order and give each one its own mark.
enum NoticeKind {
  /// What the town will have finished, and when.
  ahead,

  /// The hour of the day it nearly always happens at.
  hour,

  /// The day of the week that stands out, high or low.
  week,

  /// What one blank day does to the next.
  relapse,

  /// How long it takes to come back after a gap.
  comeback,

  /// Two habits that go together, or never do.
  pair,

  /// How long this has been going on.
  life,

  /// Lo que escribís una y otra vez en las leyendas.
  chore,

  /// Who is ahead in the valley.
  crown,

  /// Lo que el pueblo clava cuando no está hablando de vos: una cabra
  /// perdida, un baile el sábado. No sale de [noticesFor] —esto es lo que se
  /// sabe de alguien, y una cabra no se sabe de nadie— sino de
  /// `data/gossip.dart`, y lo pone el tablón.
  pueblo,

  /// Lo que clavás vos.
  ///
  /// Es la única clase de nota que la app no escribe. Las demás son lo que el
  /// pueblo averiguó de vos —y no se inventa ninguna sin cuentas detrás— o lo
  /// que el pueblo tiene clavado por su cuenta; ésta es tuya, dice lo que
  /// quieras, y no pretende ser verdad sobre nada.
  ///
  /// Por eso va en papel distinto y con otra letra: un tablón donde tus
  /// recordatorios se confunden con lo que el pueblo dedujo de tus horarios es
  /// un tablón en el que ya no se sabe quién habla.
  mine,
}

/// One thing the town noticed.
///
/// Every notice carries the numbers it rests on, and none is ever made without
/// enough behind it to be true. A claim with no evidence under it is a slogan,
/// and a town that flatters you is worth nothing: the whole point of watching
/// it is that it does not.
class Notice {
  const Notice(
    this.kind,
    this.said,
    this.because, {
    this.bars = const [],
    this.ticks = const [],
    this.mark = -1,
    this.span = 1,
    this.more,
  });

  final NoticeKind kind;

  /// One plain sentence.
  final String said;

  /// The counts it came from.
  final String because;

  /// The same evidence drawn, each value from 0 to 1. Read only when somebody
  /// takes the notice off the board to look at it properly — a claim is worth
  /// more when you can see the shape it was read off.
  final List<double> bars;

  /// What to write under the bars, where it is worth writing anything.
  final List<String> ticks;

  /// The bar the sentence is about, and how many it spans. -1 for none.
  final int mark;
  final int span;

  /// One more thing, for the same moment.
  final String? more;
}
