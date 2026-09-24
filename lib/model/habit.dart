import 'dart:math' as math;

import '../core/rng.dart';
import '../data/character.dart';
import '../data/symbols.dart';
import 'piece.dart';

/// One habit, and the town it is building.
///
/// The app's whole premise is that one achievement is one piece. This is the
/// thing that says *which* achievement: a name you wrote, a symbol you chose,
/// and a plot of the valley that is only ever this habit's. Two habits are two
/// towns you can see at the same time, which is the only honest way to answer
/// "how am I doing with reading versus running".
class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.symbol,
    required this.slot,
    required this.createdAt,
    int? character,
    this.why,
    this.floor,
    this.askedAt,
    this.nudgedAt,
    this.nudgesIgnored = 0,
    List<Piece>? pieces,
    List<String>? chronicle,
    List<String>? folk,
    List<String>? notes,
    List<String>? rests,
  }) : character = character ?? TownCharacter.forSlot(slot).order,
       pieces = pieces ?? [],
       chronicle = chronicle ?? [],
       folk = folk ?? [],
       notes = notes ?? [],
       rests = rests ?? [];

  /// Never reused and never changed: it is what a saved town is filed under.
  final String id;

  String name;

  /// Which drawn mark this habit wears: an id from [habitSymbols], never a
  /// font character. It stands over the town in the wide view, which is how
  /// four towns are told apart from far enough away to see all of them.
  String symbol;

  /// Where in the valley this habit's town stands. Assigned when the habit is
  /// made and kept for good, so adding a fifth habit never moves the first
  /// four — the same promise the pieces themselves get.
  final int slot;

  final DateTime createdAt;

  /// Para qué querés esto. Una línea, tuya, escrita el día que se funda.
  ///
  /// Correr, leer o estudiar son acciones, y casi nadie las quiere por sí
  /// mismas: las quiere porque representan otra cosa. Mientras hay entusiasmo
  /// no hace falta acordarse de cuál era; el problema llega semanas después,
  /// cuando la cosa se vuelve aburrida, y ahí recuperar el motivo vale más que
  /// cualquier premio.
  ///
  /// Por eso no se enseña en un día bueno. Está en la hoja del hábito para
  /// quien vaya a buscarlo, y sale solo en los dos momentos en que sirve: al
  /// volver de un hueco largo y cuando el pueblo pregunta si seguimos.
  String? why;

  /// Qué es lo más chico que todavía cuenta como una pieza.
  ///
  /// Esta app no necesita una versión mini de cada hábito, porque su pieza ya
  /// no tiene tamaño: leer treinta minutos y leer cinco ponen exactamente la
  /// misma piedra. Lo que sí hace falta es que eso esté dicho, con tus
  /// palabras, antes del día malo — porque el día malo la distancia entre
  /// «hacerlo» y «no hacerlo» se mide contra lo que uno cree que hay que
  /// hacer, y si eso son treinta minutos la alternativa es cero.
  ///
  /// Se lee en los mismos dos momentos que [why]. Escribirlo es opcional.
  String? floor;

  /// What kind of place this habit builds, chosen the day it was founded.
  ///
  /// Never changed afterwards, and there is no way to: the character decides
  /// how wide the plots are and in what order the catalogue arrives,
  /// so changing it would move pieces that were laid years ago. The one
  /// promise this app makes is that a piece stays where it was put.
  final int character;

  TownCharacter get place => TownCharacter.byOrder(character);

  /// La semilla de este pueblo: lo que hace que no se parezca a ningún otro.
  ///
  /// Sale del identificador, que se escribe el día que se funda el hábito y no
  /// se vuelve a tocar nunca — así que esto tampoco cambia, ni al renombrar el
  /// hábito, ni al moverlo de ranura, ni al exportar y volver a importar.
  ///
  /// No se guarda en ningún sitio a propósito: un campo nuevo tendría que
  /// valer algo para los pueblos que ya existen, y ese algo sería el mismo
  /// para todos, que es exactamente lo que había que arreglar.
  int get townSeed => hashText(id);

  final List<Piece> pieces;

  /// Qué fue cada edificio de este pueblo, en orden y escrito el día que se
  /// empezó.
  ///
  /// Es lo que hace que el catálogo pueda crecer. Sin esto, el orden de las
  /// obras se recalculaba entero en cada arranque a partir del catálogo, así
  /// que añadir un hito le cambiaba las casas a un pueblo de treinta piezas.
  /// Con esto, lo que ya se empezó está escrito y no se vuelve a decidir; lo
  /// que se decide es sólo lo que todavía no empezó, y ahí sí entra lo nuevo.
  final List<String> chronicle;

  /// Quién vive en este pueblo: una línea por vecino, escrita el día que se
  /// remató su casa y no tocada nunca más.
  ///
  /// Es lo mismo que hace [chronicle] con las obras, y por la misma razón. La
  /// diferencia es que una obra se puede volver a decidir mientras no se haya
  /// empezado, y una persona no: en cuanto existe, existe con ese nombre y esa
  /// cara. Ver [Villager].
  final List<String> folk;

  /// Lo que clavaste vos en el tablón: una línea por nota, `milisegundos|texto`.
  ///
  /// La más nueva primero, que es como se clava en un tablón de verdad — lo
  /// último que alguien escribió queda encima de lo de la semana pasada.
  final List<String> notes;

  /// Cuándo estuvo dormido este pueblo, `desde|hasta` en milisegundos y del
  /// más viejo al más nuevo. Ver [Rest].
  ///
  /// Una lista de tramos y no un interruptor, porque lo que cuenta los días
  /// —el deterioro, la consistencia, todo lo que el tablón averigua— necesita
  /// saber *cuándo* estuviste en pausa y no sólo si lo estás ahora. Sin eso,
  /// tres semanas de pausa se leen como un hueco de tres semanas y el pueblo
  /// acaba anunciando muy serio que los martes son tu día flojo porque
  /// pausaste tres martes.
  final List<String> rests;

  /// Cuándo fue la última vez que el pueblo preguntó si seguimos.
  ///
  /// Se guarda para que pregunte una sola vez por hueco. Si alguien cerró la
  /// hoja y siguió sin aparecer tres semanas más, no hay nada nuevo que
  /// preguntar: la pregunta ya está hecha y insistir sería lo que hace
  /// cualquier otra app —avisar todos los días de lo mismo— que es la manera
  /// más rápida de que se desinstale.
  DateTime? askedAt;

  /// Cuándo salió el último aviso al teléfono por este hábito.
  ///
  /// Lo mismo que [askedAt] y por lo mismo: un aviso caduca cuando vuelve a
  /// caer una pieza, porque entonces empieza un hueco nuevo. Mientras no
  /// caiga, el hueco ya tiene su aviso dado y no hay nada más que decir.
  DateTime? nudgedAt;

  /// Cuántos avisos seguidos no trajeron ninguna pieza.
  ///
  /// Es lo que hace que las notificaciones se callen solas. Si tres seguidos
  /// no sirvieron de nada, el cuarto tampoco va a servir: lo único que
  /// consigue insistir es que se desinstale la app, y eso es peor que no hacer
  /// el hábito. Se pone a cero en cuanto cae una pieza.
  int nudgesIgnored;

  /// Los tramos, ya leídos. Un renglón roto se salta.
  Iterable<Rest> get sleeps sync* {
    for (final line in rests) {
      final r = Rest.parse(line);
      if (r != null) yield r;
    }
  }

  /// El tramo que cubre ese momento, si lo hay.
  Rest? restAt(DateTime when) {
    for (final r in sleeps) {
      if (r.covers(when)) return r;
    }
    return null;
  }

  /// Si el pueblo está dormido ahora mismo.
  bool get resting => restAt(DateTime.now()) != null;

  /// Cuándo despierta, si está dormido.
  DateTime? get wakesAt => restAt(DateTime.now())?.until;

  /// Si estuvo dormido ese día del calendario.
  bool restedOn(DateTime day) {
    for (final r in sleeps) {
      if (r.coversDay(day)) return true;
    }
    return false;
  }

  /// Cuándo acabó la última pausa que ya acabó, o nulo si nunca durmió.
  ///
  /// Es desde donde se cuenta el abandono al despertar: un pueblo que vuelve
  /// de dormir vuelve sin deuda, con su día y medio de gracia entero, y no
  /// arrastrando las tres semanas que estuvo en pausa.
  DateTime? get wokeAt {
    DateTime? last;
    final now = DateTime.now();
    for (final r in sleeps) {
      if (r.until.isAfter(now)) continue;
      if (last == null || r.until.isAfter(last)) last = r.until;
    }
    return last;
  }

  int get total => pieces.length;

  DateTime? get lastPlacedAt => pieces.isEmpty ? null : pieces.last.placedAt;

  /// The most towns the valley holds. Six is as many as can be told apart at a
  /// glance, and a person with seven habits has a different problem.
  static const int maxSlots = 6;

  /// Where a slot's town stands. Slot zero is the middle of the valley — el
  /// primer hábito es la capital— y los demás lo rodean.
  ///
  /// El anillo mide ciento veinticuatro. Medía setenta y ocho, y setenta y
  /// ocho era poco: el pueblo del centro y uno del anillo se tocan en cuanto
  /// la suma de sus radios pasa del anillo, y un Valle de ochocientas piezas
  /// ya mide cuarenta y uno. Dos Valles de ochocientas no cabían, y eso era
  /// así desde el principio: el comentario que había aquí decía que dos
  /// pueblos de treinta mil logros seguirían sin tocarse, y no era verdad ni
  /// de lejos.
  ///
  /// Ciento veinticuatro es holgado a propósito. Le sobra sitio a los seis que
  /// hay —a los que les llega con la mitad— y le da margen a lo que se
  /// invente después, que casi seguro sea más grande que un Valle. Lo que se
  /// paga por ensancharlo es la vista del valle: seis pueblos chicos quedan
  /// más perdidos en el prado, y por eso tampoco conviene pasarse.
  ///
  /// Nada de esto está guardado: la posición sale del número de hueco, así que
  /// ensanchar el anillo no le mueve una piedra a ningún pueblo, sólo los
  /// separa.
  static (double, double) centreOf(int slot) {
    if (slot <= 0) return (0.0, 0.0);
    const ring = 124.0;
    final k = (slot - 1) % (maxSlots - 1);
    final a = -math.pi / 2 + k * 2 * math.pi / (maxSlots - 1);
    return (math.cos(a) * ring, math.sin(a) * ring);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'n': name,
    's': symbol,
    'slot': slot,
    'ch': character,
    'c': createdAt.millisecondsSinceEpoch,
    'p': pieces.map((p) => p.toJson()).toList(),
    'w': chronicle,
    'f': folk,
    'm': notes,
    if (why != null && why!.isNotEmpty) 'y': why,
    if (floor != null && floor!.isNotEmpty) 'q': floor,
    if (rests.isNotEmpty) 'r': rests,
    if (askedAt != null) 'k': askedAt!.millisecondsSinceEpoch,
    if (nudgedAt != null) 'g': nudgedAt!.millisecondsSinceEpoch,
    if (nudgesIgnored > 0) 'gi': nudgesIgnored,
  };

  static Habit fromJson(Map<String, dynamic> j) {
    final list =
        ((j['p'] as List?) ?? [])
            .map((e) => Piece.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    // A town is built in order and nothing else about a piece matters, so a
    // save with gaps in it is renumbered rather than refused.
    for (var i = 0; i < list.length; i++) {
      if (list[i].index != i) {
        list[i] = Piece(
          index: i,
          placedAt: list[i].placedAt,
          label: list[i].label,
        );
      }
    }
    return Habit(
      id: j['id'] as String? ?? 'h0',
      name: j['n'] as String? ?? 'Mi hábito',
      // Older saves hold an emoji here. They are read back as the mark that
      // means the same thing, so nobody's habit changes what it is about.
      symbol: resolveHabitSymbol(j['s'] as String?),
      slot: (j['slot'] as num?)?.toInt() ?? 0,
      // Una copia vieja no la trae: se rellena al cargar, a partir del
      // catálogo de hoy, y desde entonces queda escrita.
      chronicle: [for (final e in (j['w'] as List?) ?? []) e.toString()],
      // Una copia vieja tampoco lo trae: se rellena al cargar con las fechas
      // de las piezas que remataron cada casa, así que nadie pierde su
      // cumpleaños por haber empezado a usar la app antes de que existiera.
      folk: [for (final e in (j['f'] as List?) ?? []) e.toString()],
      notes: [for (final e in (j['m'] as List?) ?? []) e.toString()],
      // Tres cosas que una copia vieja no trae y que valen lo mismo vacías: un
      // hábito sin motivo escrito es un hábito sin motivo escrito, y un pueblo
      // que nunca durmió no tiene tramos. Nadie pierde nada por venir de antes.
      why: (j['y'] as String?)?.trim(),
      floor: (j['q'] as String?)?.trim(),
      rests: [for (final e in (j['r'] as List?) ?? []) e.toString()],
      askedAt: (j['k'] as num?) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((j['k'] as num).toInt()),
      // A save from before towns could be chosen keeps the one its plot was
      // given, so nobody's town changes shape under them.
      character: (j['ch'] as num?)?.toInt(),
      nudgedAt: (j['g'] as num?) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((j['g'] as num).toInt()),
      nudgesIgnored: (j['gi'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (j['c'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      pieces: list,
    );
  }
}

/// Un tramo en el que un hábito estuvo dormido a propósito.
///
/// La diferencia entre «no estoy pudiendo con esto ahora» y «ya no quiero que
/// esto forme parte de mi vida» es la diferencia entre dos decisiones
/// completamente distintas, y una app que sólo sabe seguir o fallar convierte
/// un viaje, una mudanza o un mes malo en un fracaso. Esto es lo que le falta
/// para saber la diferencia.
///
/// Siempre lleva fecha de vuelta. Una pausa sin final es abandono con mejor
/// nombre, y lo que se estaría guardando entonces es la excusa y no el plan.
class Rest {
  const Rest(this.from, this.until);

  final DateTime from;

  /// Cuándo despierta. Volver antes la recorta hasta el día que volviste, así
  /// que esto es siempre lo que de verdad duró.
  final DateTime until;

  bool covers(DateTime when) => !when.isBefore(from) && when.isBefore(until);

  /// Si el pueblo estuvo dormido ese día del calendario.
  ///
  /// Se mira el mediodía y no la medianoche. Una pausa que empieza a las dos
  /// de la tarde deja media jornada despierta, y discutir de qué lado cae ese
  /// día es discutir por nada: el mediodía parte la diferencia y es una regla
  /// que se puede decir en una línea.
  bool coversDay(DateTime day) =>
      covers(DateTime(day.year, day.month, day.day, 12));

  String encode() =>
      '${from.millisecondsSinceEpoch}|${until.millisecondsSinceEpoch}';

  /// Un renglón roto no tira el hábito abajo: se salta, como una nota del
  /// tablón sin fecha.
  static Rest? parse(String line) {
    final cut = line.indexOf('|');
    if (cut <= 0) return null;
    final a = int.tryParse(line.substring(0, cut));
    final b = int.tryParse(line.substring(cut + 1));
    if (a == null || b == null || b <= a) return null;
    return Rest(
      DateTime.fromMillisecondsSinceEpoch(a),
      DateTime.fromMillisecondsSinceEpoch(b),
    );
  }
}
