import 'dart:math' as math;

import '../l10n/dates.dart';
import '../l10n/en_pledge.dart';
import '../l10n/lang.dart';
import 'habit.dart';
import 'notice.dart';
import 'piece.dart';
import 'pledge.dart';
import 'rhythm.dart';

/// Everything worth pinning up about one habit, in the order it should be read.
///
/// [others] are the town's neighbours in the valley, for the notices that only
/// exist when there is more than one habit. [underway] and [left] are what the
/// town is building right now, which is what turns a rate into a date.
List<Notice> noticesFor(
  Habit h, {
  List<Habit> others = const [],
  String? underway,
  int left = 0,
  DateTime? at,
}) {
  final now = at ?? DateTime.now();
  final out = <Notice>[];
  void add(Notice? n) {
    if (n != null) out.add(n);
  }

  // What is coming first, then the two things you decided —quién sos y el
  // plan—, then who you are on a normal week, then the two hard ones
  // — and those two in that order, because "un fallo se lleva al siguiente"
  // read on its own is worth much less than read next to "y volvés a los dos
  // días".
  add(ahead(h, underway, left, now));
  // El título, que o está ganado o no existe. Cuando aparece va arriba del
  // todo, porque es la noticia más grande que un pueblo puede dar de vos.
  add(whoYouAre(h, now));
  // El plan habla de la hora, así que cuando sale, la nota del horario sobra:
  // dirían lo mismo con dos papeles, y uno de los dos sin la mitad que importa.
  final elPlan = planned(h);
  add(elPlan);
  if (elPlan == null || elPlan.bars.isEmpty) add(peakHour(h));
  add(standoutDay(h, now));
  add(pairing(h, others, now));
  add(relapse(h, now));
  add(comeback(h));
  add(crownOf(h, others));
  add(lifetime(h, now));
  return out;
}

// -------------------------------------------------------------- the notices

/// A rate turned into a date: what the town is building, and when it lands.
///
/// The one notice that looks forward, and the only one that has any business
/// doing so, because it says exactly what it is doing — carrying on at the
/// pace so far — instead of pretending to know the future.
///
/// El ritmo se mide desde que existe el hábito y no siempre sobre treinta
/// días. Dividir entre treinta cuando el pueblo tiene cuatro es repartir tus
/// piezas entre veintiséis días en los que no había dónde ponerlas: nueve
/// piezas en cuatro días salían a 0,3 al día en vez de 2,25, y una casa a la
/// que le faltaban tres quedaba en pie dentro de diez días en vez de dentro
/// de dos. Cuanto más nuevo el pueblo, peor la cuenta, que es justo cuando
/// más se mira.
Notice? ahead(Habit h, String? what, int left, DateTime now) {
  if (what == null || left <= 0) return null;
  final today = dayStart(now);

  // Desde cuándo hay hábito. Lo antes de las dos cosas: normalmente el día que
  // se fundó, pero unas piezas anteriores a su propia fecha de creación —datos
  // traídos de otra parte— no pueden dar una ventana negativa.
  var nace = dayStart(h.createdAt);
  if (h.pieces.isNotEmpty) {
    final primera = dayStart(h.pieces.first.placedAt);
    if (primera.isBefore(nace)) nace = primera;
  }
  final desde = nace.isAfter(shiftDays(today, -29))
      ? nace
      : shiftDays(today, -29);

  var recent = 0;
  for (final p in h.pieces) {
    if (!dayStart(p.placedAt).isBefore(desde)) recent++;
  }
  if (recent < 8) return null;

  // Los días dormidos no cuentan para el ritmo. Con ellos dentro, pausar dos
  // semanas te deja el pueblo terminándose un mes más tarde por haber tenido
  // el buen juicio de pausarlo, que es justo al revés de lo que hace falta.
  var ventana = daysBetween(desde, today) + 1;
  for (var d = desde; !d.isAfter(today); d = shiftDays(d, 1)) {
    if (h.restedOn(d)) ventana--;
  }
  if (ventana < 1) return null;

  // Un día de piezas no es un ritmo, es un día. Tres es lo menos que puede
  // llamarse ritmo, así que por debajo de ahí la cuenta se reparte entre tres
  // y una tarde entera de golpe no promete el pueblo para mañana. El reparto
  // es sólo para la cuenta: los días que se cuentan son los que hubo, porque
  // decir «llevás ocho en tres días» el primer día sería inventarse dos.
  final perDay = recent / math.max(3, ventana);
  final days = (left / perDay).ceil();
  if (days > 400) return null; // too far off to mean anything
  final when = shiftDays(today, days);

  // Las barras enseñan lo mismo que usó la cuenta. Con doce semanas en un
  // pueblo de cuatro días, once salían vacías y la que sobrevivía se llevaba
  // las nueve piezas: el dibujo decía «todo de una vez» cuando habían sido
  // cuatro días seguidos.
  final porDias = ventana <= 28;
  return Notice(
    NoticeKind.ahead,
    days <= 1
        ? tr(
            'A este ritmo, $what queda en pie mañana.',
            'At this pace, $what stands tomorrow.',
          )
        : tr(
            'A este ritmo, $what queda en pie el ${_date(when)}'
                '${when.year == now.year ? '' : ' de ${when.year}'}.',
            'At this pace, $what stands on ${_date(when)}'
                '${when.year == now.year ? '' : ', ${when.year}'}.',
          ),
    tr(
      'Le faltan $left ${_pieces(left)}, y llevás $recent en '
          '${ventana == 1 ? 'un día' : '$ventana días'}.',
      'It needs $left more ${_pieces(left)}, and you have placed $recent in '
          '${ventana == 1 ? 'one day' : '$ventana days'}.',
    ),
    bars: porDias ? dailyOf(h, desde, today) : weeksOf(h, now, 12),
    mark: porDias ? daysBetween(desde, today) : 11,
    more: porDias
        ? tr(
            'La fecha sale del ritmo desde que empezaste y de nada más. Si '
                'apretás se adelanta, y si aflojás se va. Las barras son esos '
                'mismos días, uno cada una.',
            'The date comes from your pace since you started and nothing '
                'else. Push and it comes sooner; ease off and it slips away. '
                'The bars are those same days, one each.',
          )
        : tr(
            'La fecha sale del ritmo del último mes y de nada más. Si apretás '
                'se adelanta, y si aflojás se va. Las barras son las últimas '
                'doce semanas, una por semana.',
            "The date comes from the last month's pace and nothing else. Push "
                'and it comes sooner; ease off and it slips away. The bars are '
                'the last twelve weeks, one per week.',
          ),
  );
}

// --------------------------------------------------- las que dijiste vos

/// El plan: a qué hora y en qué sitio dijiste que lo ibas a hacer.
///
/// Es la única nota del tablón que no es una observación. Las otras nueve salen
/// de tus piezas y no se pueden discutir; ésta la escribiste vos, y lo que el
/// pueblo hace con ella es lo único que puede hacer: enseñártela y decirte si
/// se está cumpliendo.
///
/// Tres papeles distintos según lo que haya:
///
///  * **Sin plan y con costumbre.** El pueblo ya sabe a qué hora aparecés, y
///    lo cuenta como lo que es: algo que ya hacés. No se propone ninguna hora
///    inventada, se propone la tuya, y decir dónde es un «si querés» — el plan
///    ya no se pide al fundar, así que ésta es la única vez que sale, y no
///    puede sonar a tarea pendiente.
///  * **Con plan que ya no es el tuyo.** Dijiste a las diez y aparecés a las
///    siete. El papel lo dice sin regañar, porque no hay nada que regañar: el
///    plan viejo es el que está mal.
///  * **Con plan.** La frase entera, y qué parte de las piezas cae en su hora.
Notice? planned(Habit h) {
  final dicho = vowOf(h);
  final uso = habitualHour(h);

  if (dicho == null) {
    if (uso == null) return null;
    return Notice(
      NoticeKind.plan,
      tr(
        'Casi siempre ${hourSaid(uso.$1)}.',
        'Almost always ${hourSaid(uso.$1)}.',
      ),
      tr(
        'Ahí caen el ${_pct(uso.$2)} de tus piezas. Si querés, contale al '
            'pueblo dónde, y queda dicho.',
        '${_pct(uso.$2)} of your pieces land there. If you like, tell the '
            "town where, and it's settled.",
      ),
      bars: _clockBars(h),
      ticks: _clockTicks,
      mark: uso.$1,
      more: tr(
        'No es una tarea: ya lo hacés. Decirlo con hora y sitio —«leer a las '
            '22, en la cama»— lo deja decidido, y lo decidido no hay que '
            'volver a pensarlo cada día. Las barras son las veinticuatro horas '
            'del día, y la marcada es la tuya.',
        "It isn't a chore: you already do it. Saying it with a time and a "
            'place — "reading at 10 pm, in bed" — makes it decided, and what '
            "is decided doesn't need rethinking every day. The bars are the "
            "day's twenty-four hours, and the marked one is yours.",
      ),
    );
  }

  final hora = h.vowHour;
  final cumple = planKept(h);
  final desvio = planDrift(h);
  // Tres horas de diferencia no es despistarse: es otro momento del día. Por
  // debajo de eso el plan sigue siendo el tuyo y no hay nada que avisar.
  if (hora != null &&
      uso != null &&
      cumple != null &&
      desvio != null &&
      desvio >= 3) {
    return Notice(
      NoticeKind.plan,
      tr(
        'El plan dice ${hourSaid(hora)} y aparecés ${hourSaid(uso.$1)}.',
        'The plan says ${hourSaid(hora)} and you show up ${hourSaid(uso.$1)}.',
      ),
      tr(
        '«$dicho» El ${_pct(cumple)} de tus ${h.total} ${_pieces(h.total)} '
            'cae a la hora del plan.',
        '"$dicho" ${_pct(cumple)} of your ${h.total} ${_pieces(h.total)} land '
            "at the plan's time.",
      ),
      bars: _clockBars(h),
      ticks: _clockTicks,
      mark: uso.$1,
      more: tr(
        'Cambiar el plan no es rendirse. Un plan que ya no es el tuyo no te '
            'ahorra ninguna decisión, y el que sí lo es te la ahorra todos los '
            'días: se cambia en la hoja del hábito, y no pasa nada más. Las '
            'barras son las veinticuatro horas del día, y la marcada es la '
            'hora a la que de verdad aparecés.',
        "Changing the plan isn't giving up. A plan that's no longer yours "
            "doesn't save you any decision, and one that is saves you one "
            "every day: you change it in the habit's sheet, and nothing else "
            "happens. The bars are the day's twenty-four hours, and the marked "
            'one is the hour you really show up.',
      ),
    );
  }

  return Notice(
    NoticeKind.plan,
    dicho,
    cumple == null
        ? tr(
            'Lo escribiste vos. El pueblo lo tiene clavado para que no haya '
                'que acordarse de decidirlo otra vez.',
            'You wrote it. The town keeps it pinned so you never have to '
                'remember to decide it again.',
          )
        : tr(
            'Se cumple el ${_pct(cumple)} de las veces: ésa es la parte de tus '
                '${h.total} ${_pieces(h.total)} que cae a esa hora.',
            "It holds ${_pct(cumple)} of the time: that's the share of your "
                '${h.total} ${_pieces(h.total)} that land at that hour.',
          ),
    bars: hora == null ? const [] : _clockBars(h),
    ticks: hora == null ? const [] : _clockTicks,
    mark: hora ?? -1,
    more: hora == null
        ? null
        : tr(
            'Las veinticuatro horas del día, y en cada una cuántas piezas '
                'pusiste. La marcada es la que dice el plan.',
            "The day's twenty-four hours, and how many pieces you placed in "
                'each. The marked one is what the plan says.',
          ),
  );
}

/// En quién te convierte esto. **Sólo el día que el pueblo ya puede decirlo.**
///
/// El título no se escribe, se gana, y hasta que se gana **no hay nada**: ni el
/// día que fundás el pueblo, ni a los dos meses, ni un papel diciendo cuánto
/// falta. Escribirlo el primer día y que el tablón lo anunciara esa misma tarde
/// sería la única mentira de todo el tablón —las otras nueve notas salen de lo
/// que hiciste y ésta saldría de lo que te gustaría—, y una barra de progreso
/// hacia el título sería la misma app de siempre: una cosa que te persigue con
/// lo que te falta.
///
/// Así que el pueblo mira en silencio **cada cuánto lo hacés de verdad** —nadie
/// declara su ritmo, se le ve— y si lo cumplís trece semanas al noventa por
/// ciento, un día aparece este papel y no lo estabas esperando. Es la única
/// cosa de esta app que llega sin avisar, y por eso vale.
Notice? whoYouAre(Habit h, DateTime now) {
  final dicho = identitySaid(h);
  final gano = h.identityWonAt;
  if (dicho == null || gano == null) return null;
  return Notice(
    NoticeKind.who,
    dicho,
    tr(
      'El pueblo te llama así desde el ${_date(gano)}, cuando llevabas trece '
          'semanas sin bajar de tu ritmo.',
      'The town has called you this since ${_date(gano)}, when you had gone '
          'thirteen weeks without dropping below your pace.',
    ),
    bars: identityStanding(h, at: now)?.weeks ?? const [],
    more: tr(
      'Lo escribiste el día que fundaste esto y el pueblo se lo tomó en '
          'serio: no lo dijo hasta que fue verdad. No es una meta —una meta se '
          'cumple y entonces el hábito deja de tener para qué—; esto no se '
          'cumple nunca, se es o no se es. Y ya no se pierde: un mal mes no te '
          'quita lo que fuiste tres meses. Las barras son las últimas trece '
          'semanas, por si querés ver cómo vas.',
      'You wrote it the day you founded this, and the town took it '
          "seriously: it didn't say it until it was true. It isn't a goal — a "
          'goal gets reached and then the habit has nothing left to be for; '
          "this is never reached, you either are it or you aren't. And it "
          "can't be lost now: one bad month doesn't take away what you were "
          'for three. The bars are the last thirteen weeks, in case you want '
          "to see how you're doing.",
    ),
  );
}

/// Las veinticuatro horas del día en barras, contra la hora más cargada.
///
/// Dos notas las enseñan —el horario y el plan— y es la misma evidencia: qué
/// parte del día es la tuya. Vive aquí para que no haya dos maneras de
/// dibujarla que puedan dejar de coincidir.
List<double> _clockBars(Habit h) {
  final byHour = List<int>.filled(24, 0);
  for (final p in h.pieces) {
    byHour[p.placedAt.hour]++;
  }
  var top = 1;
  for (final c in byHour) {
    if (c > top) top = c;
  }
  return [for (final c in byHour) c / top];
}

/// Los pies del reloj: sólo las cuatro que orientan.
const List<String> _clockTicks = [
  '0',
  '',
  '',
  '',
  '',
  '',
  '6',
  '',
  '',
  '',
  '',
  '',
  '12',
  '',
  '',
  '',
  '',
  '',
  '18',
  '',
  '',
  '',
  '',
  '',
];

/// What one blank day does to the next.
///
/// The most useful thing in here, because it turns "un día no pasa nada" into
/// a number that is yours: for most people a miss really does drag the next
/// day with it, and seeing by how much is worth more than being told not to
/// miss.
Notice? relapse(Habit h, DateTime now) {
  final grid = gridOf(h, now);
  if (grid.length < 30) return null;
  // Los días dormidos no son días en blanco, y el día siguiente a uno tampoco
  // es «el día después de fallar»: nadie falló. Salen de las dos cuentas.
  var counted = 0, misses = 0, after = 0, afterMiss = 0;
  for (var i = 0; i < grid.length; i++) {
    if (grid[i] == Was.asleep) continue;
    counted++;
    if (grid[i] == Was.off) misses++;
    if (i == 0 || grid[i - 1] != Was.off) continue;
    afterMiss++;
    if (grid[i] == Was.off) after++;
  }
  if (counted < 30 || misses < 6 || afterMiss < 5) return null;
  final base = misses / counted;
  final then = after / afterMiss;
  if ((then - base).abs() < 0.12) return null;
  return Notice(
    NoticeKind.relapse,
    then > base
        ? tr(
            'Un día en blanco se lleva al siguiente.',
            'One blank day drags the next one with it.',
          )
        : tr(
            'Un fallo no te tumba: volvés antes de lo normal.',
            "A miss doesn't knock you down: you come back sooner than usual.",
          ),
    tr(
      'Después de faltar un día, faltás el ${_pct(then)} de las veces. '
          'Un día cualquiera, el ${_pct(base)}.',
      'After missing a day, you miss ${_pct(then)} of the time. '
          'On any other day, ${_pct(base)}.',
    ),
    bars: [then, base],
    ticks: [
      tr('tras un fallo', 'after a miss'),
      tr('un día cualquiera', 'any day'),
    ],
    mark: 0,
    more: then > base
        ? tr(
            'De los últimos ${grid.length} días, ${grid.length - misses} con '
                'pieza. Es la diferencia entre las dos barras lo que dice '
                'algo: el día de después de faltar no es un día cualquiera '
                'para vos.',
            'Of the last ${grid.length} days, ${grid.length - misses} had a '
                'piece. It is the gap between the two bars that says '
                "something: the day after a miss isn't just any day for you.",
          )
        : tr(
            'De los últimos ${grid.length} días, ${grid.length - misses} con '
                'pieza. Faltar te empuja a volver, que es lo contrario de lo '
                'que le pasa a casi todo el mundo.',
            'Of the last ${grid.length} days, ${grid.length - misses} had a '
                'piece. Missing pushes you to come back, which is the '
                'opposite of what happens to almost everyone.',
          ),
  );
}

/// The stretch of the day it nearly always happens in.
///
/// The window is grown, not fixed: somebody who always lays a piece at ten
/// past eight is told "a las 8", and somebody who does it any time between
/// breakfast and lunch is told the whole stretch. A fixed three-hour band
/// would flatten both into the same sentence and be wrong about each.
Notice? peakHour(Habit h) {
  if (h.pieces.length < 20) return null;
  final byHour = List<int>.filled(24, 0);
  for (final p in h.pieces) {
    byHour[p.placedAt.hour]++;
  }
  final n = h.pieces.length;
  for (var width = 1; width <= 5; width++) {
    var at = 0, best = -1;
    for (var s = 0; s < 24; s++) {
      var sum = 0;
      for (var k = 0; k < width; k++) {
        sum += byHour[(s + k) % 24];
      }
      if (sum > best) {
        best = sum;
        at = s;
      }
    }
    // "Casi siempre" has to mean casi siempre: seven in ten inside a fifth of
    // the day is an hour somebody keeps, and anything looser is a sentence
    // that hides a third of the truth to sound tidier.
    if (best / n < 0.7) continue;
    final end = (at + width) % 24;
    return Notice(
      NoticeKind.hour,
      width == 1
          ? tr(
              'Casi siempre a las $at${_partOfDay(at)}.',
              'Almost always at ${clockEn(at)}.',
            )
          : tr(
              'Casi siempre entre las $at y las $end${_partOfDay(at)}.',
              'Almost always between ${clockEn(at)} and ${clockEn(end)}.',
            ),
      tr(
        'Ahí caen el ${_pct(best / n)} de tus piezas.',
        '${_pct(best / n)} of your pieces land there.',
      ),
      bars: _clockBars(h),
      ticks: _clockTicks,
      mark: at,
      span: width,
      more: tr(
        'Las veinticuatro horas del día, y en cada una cuántas piezas '
            'pusiste. Un hábito con hora propia se ve de un vistazo; uno que '
            'cae donde puede, también.',
        "The day's twenty-four hours, and how many pieces you placed in each. "
            'A habit with its own hour shows at a glance; so does one that '
            'lands wherever it can.',
      ),
    );
  }
  return null;
}

/// The day of the week that stands out, whichever way it stands out.
///
/// Measured against how many of that weekday have actually gone by since the
/// first piece, not against the other days' totals: eight Mondays and five
/// Sundays are not the same denominator.
Notice? standoutDay(Habit h, DateTime now) {
  final all = daysOf(h);
  if (all.isEmpty) return null;
  final today = dayStart(now);
  final edge = shiftDays(today, -lookBack);
  final first = all.first.isAfter(edge) ? all.first : edge;
  final days = [
    for (final d in all)
      if (!d.isBefore(first)) d,
  ];
  if (days.isEmpty) return null;
  final span = daysBetween(first, today);
  if (span < 27) return null;
  // Cuántos de cada día de la semana pasaron de verdad — y los que el pueblo
  // durmió no pasaron. Contarlos sería reprocharte tres martes que estabas de
  // viaje, que es exactamente la clase de cuenta que una pausa viene a evitar.
  final hit = List<int>.filled(8, 0);
  for (final d in days) {
    hit[d.weekday]++;
  }
  // Cuántos de cada día de la semana pasaron de verdad — y los que el pueblo
  // durmió no pasaron. Contarlos sería reprocharte tres martes que estabas de
  // viaje, que es exactamente la clase de cuenta que una pausa viene a evitar.
  // Un día dormido en el que pusiste pieza igual sí cuenta: está en [hit], y
  // dejarlo fuera de aquí daría un día de la semana cumplido más veces de las
  // que existió.
  final on = <int>{for (final d in days) dayKey(d)};
  final seen = List<int>.filled(8, 0);
  for (var i = 0; i <= span; i++) {
    final d = shiftDays(first, i);
    if (h.restedOn(d) && !on.contains(dayKey(d))) continue;
    seen[d.weekday]++;
  }
  for (var w = 1; w <= 7; w++) {
    if (seen[w] < 4) return null;
  }
  var high = 1, low = 1;
  for (var w = 2; w <= 7; w++) {
    if (hit[w] / seen[w] > hit[high] / seen[high]) high = w;
    if (hit[w] / seen[w] < hit[low] / seen[low]) low = w;
  }
  double rest(int w) {
    var a = 0, b = 0;
    for (var k = 1; k <= 7; k++) {
      if (k == w) continue;
      a += hit[k];
      b += seen[k];
    }
    return b == 0 ? 0 : a / b;
  }

  final upGap = hit[high] / seen[high] - rest(high);
  final downGap = rest(low) - hit[low] / seen[low];
  if (math.max(upGap, downGap) < 0.18) return null;
  final week = [for (var w = 1; w <= 7; w++) hit[w] / seen[w]];
  final initials = inEnglish
      ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
      : const ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  final more = tr(
    'Cada barra es un día de la semana, y lo alta que está es la parte de '
        'esos días en los que pusiste algo. Medido contra cuántos '
        '${_weekday(high)} y cuántos ${_weekday(low)} han pasado de verdad, '
        'no contra los totales de los otros días.',
    'Each bar is a day of the week, and its height is the share of those '
        'days on which you placed something. Measured against how many '
        '${_weekday(high)} and how many ${_weekday(low)} have really gone '
        "by, not against the other days' totals.",
  );
  if (upGap >= downGap) {
    return Notice(
      NoticeKind.week,
      tr(
        'Los ${_weekday(high)} son tu día fuerte.',
        '${_weekday(high)} are your strong day.',
      ),
      tr(
        'Cumplís el ${_pct(hit[high] / seen[high])} de los ${_weekday(high)}, '
            'contra el ${_pct(rest(high))} del resto de la semana.',
        'You keep it on ${_pct(hit[high] / seen[high])} of '
            '${_weekday(high)}, against ${_pct(rest(high))} for the rest of '
            'the week.',
      ),
      bars: week,
      ticks: initials,
      mark: high - 1,
      more: more,
    );
  }
  return Notice(
    NoticeKind.week,
    tr('Los ${_weekday(low)} casi nunca.', '${_weekday(low)}, almost never.'),
    tr(
      'Cumplís el ${_pct(hit[low] / seen[low])} de los ${_weekday(low)}, '
          'contra el ${_pct(rest(low))} del resto de la semana.',
      'You keep it on ${_pct(hit[low] / seen[low])} of ${_weekday(low)}, '
          'against ${_pct(rest(low))} for the rest of the week.',
    ),
    bars: week,
    ticks: initials,
    mark: low - 1,
    more: more,
  );
}

/// How long a gap usually lasts, and the worst one ever climbed out of.
Notice? comeback(Habit h) {
  final days = daysOf(h);
  if (days.length < 6) return null;
  // En el orden en que pasaron, que es lo que hace falta para saber si estás
  // volviendo antes que antes. Ordenados van aparte.
  final gaps = gapsOf(h);
  if (gaps.length < 4) return null;
  final trend = _returningFaster(gaps);
  final sorted = [...gaps]..sort();
  final mid = sorted[sorted.length ~/ 2];
  final worst = sorted.last;
  // How many gaps of each length: one, two, three… and everything from six up
  // in the last bar, because past a week the exact number stops mattering.
  final tally = List<double>.filled(6, 0);
  for (final g in gaps) {
    tally[(g - 1).clamp(0, 5)] += 1;
  }
  var top = 1.0;
  for (final c in tally) {
    if (c > top) top = c;
  }
  return Notice(
    NoticeKind.comeback,
    // Si estás volviendo más rápido que antes, eso es lo que hay que decir y
    // no la mediana. Es lo único que esta app mide que mejora cuando fallás:
    // alguien que pasó de desaparecer un mes a desaparecer dos días progresó
    // muchísimo, y ninguna racha sabe decirlo — para una racha las dos cosas
    // son «racha rota» y se acabó.
    trend != null
        ? tr(
            'Cada vez tardás menos en volver.',
            'You take less and less time to come back.',
          )
        : mid == 1
        ? tr(
            'Cuando faltás, volvés al día siguiente.',
            'When you miss, you come back the next day.',
          )
        : tr(
            'Cuando faltás, solés volver a los $mid días.',
            'When you miss, you usually come back after $mid days.',
          ),
    trend != null
        ? tr(
            'Tus primeros huecos duraban ${_days(trend.$1)}. Los últimos, '
                '${_days(trend.$2)}.',
            'Your first gaps lasted ${_days(trend.$1)}. The latest ones, '
                '${_days(trend.$2)}.',
          )
        : worst == 1
        ? tr(
            'Nunca has estado más de un día fuera.',
            "You've never been away for more than a day.",
          )
        : tr(
            'El hueco más largo que remontaste fue de $worst días.',
            'The longest gap you climbed out of was $worst days.',
          ),
    bars: [for (final c in tally) c / top],
    ticks: const ['1', '2', '3', '4', '5', '6+'],
    mark: (mid - 1).clamp(0, 5),
    more: tr(
      'Cada barra es cuántas veces estuviste fuera ese número de días. '
          '${gaps.length} huecos en total, y volviste de todos: el pueblo '
          'sigue en pie. No se trata de no fallar nunca, se trata de volver '
          '— y esto es lo único de acá que mejora cuando fallás.',
      'Each bar is how many times you were away for that many days. '
          '${gaps.length} gaps in all, and you came back from every one: the '
          "town still stands. It isn't about never missing, it's about "
          'coming back — and this is the only thing here that gets better '
          'when you miss.',
    ),
  );
}

/// Si los últimos huecos son más cortos que los primeros, y de cuánto a
/// cuánto. Nulo si no hay bastante diferencia como para decir nada.
///
/// La mitad contra la mitad, por la media: con pocos huecos una mediana no se
/// mueve —tres huecos de 1, 1 y 30 dan mediana uno igual que 1, 1 y 2— y lo
/// que se está buscando es precisamente si los largos se acabaron.
(double, double)? _returningFaster(List<int> gaps) {
  if (gaps.length < 6) return null;
  final half = gaps.length ~/ 2;
  var early = 0.0, late = 0.0;
  for (var i = 0; i < half; i++) {
    early += gaps[i];
  }
  for (var i = gaps.length - half; i < gaps.length; i++) {
    late += gaps[i];
  }
  early /= half;
  late /= half;
  // Un día entero menos y al menos una cuarta parte: sin las dos cosas, pasar
  // de 1,4 a 1,1 se anunciaría como una mejora y no es nada.
  if (early - late < 1.0 || late > early * 0.75) return null;
  return (early, late);
}

/// Un número de días que puede no ser entero, dicho como se dice en voz alta.
String _days(double v) {
  final r = (v * 10).round() / 10;
  if (r == 1.0) return tr('un día', 'one day');
  final txt = r == r.roundToDouble()
      ? r.round().toString()
      : inEnglish
      ? r.toStringAsFixed(1)
      : r.toStringAsFixed(1).replaceAll('.', ',');
  return tr('$txt días', '$txt days');
}

/// Two habits that turn up together, or never do.
///
/// Stated as the two odds side by side rather than as one number, because
/// "el 78% de las veces, contra el 41%" is a thing anybody can check against
/// their own week, and a correlation coefficient is not.
Notice? pairing(Habit h, List<Habit> others, DateTime now) {
  Notice? best;
  var bestGap = 0.20;
  for (final o in others) {
    if (o.id == h.id) continue;
    // El otro primero: «Correr arrastra a Leer» en el tablón de Leer habla de
    // Leer, que es de quien es el tablón. Y con dos hábitos que caen siempre el
    // mismo día las dos direcciones empatan, así que el orden decide.
    //
    // Es una observación y nada más. Se podía firmar como regla —«después de
    // correr, leer»— y ya no: que dos hábitos van juntos lo ve el pueblo, no
    // hace falta declararlo.
    for (final pair in [(o, h), (h, o)]) {
      final n = _pairing(pair.$1, pair.$2, now);
      if (n == null) continue;
      if (n.$2 > bestGap) {
        bestGap = n.$2;
        best = n.$1;
      }
    }
  }
  return best;
}

(Notice, double)? _pairing(Habit a, Habit b, DateTime now) {
  final da = daysOf(a), db = daysOf(b);
  if (da.isEmpty || db.isEmpty) return null;
  final from = da.first.isAfter(db.first) ? da.first : db.first;
  final today = dayStart(now);
  final span = daysBetween(from, today);
  if (span < 20) return null;
  final onA = <int>{for (final d in da) dayKey(d)};
  final onB = <int>{for (final d in db) dayKey(d)};
  var withA = 0, bothOn = 0, withoutA = 0, bOnly = 0;
  for (var i = 0; i <= span; i++) {
    final day = shiftDays(from, i);
    final k = dayKey(day);
    // Un día en que cualquiera de los dos dormía no dice nada de si van
    // juntos: uno de los dos no estaba jugando.
    if ((a.restedOn(day) && !onA.contains(k)) ||
        (b.restedOn(day) && !onB.contains(k))) {
      continue;
    }
    if (onA.contains(k)) {
      withA++;
      if (onB.contains(k)) bothOn++;
    } else {
      withoutA++;
      if (onB.contains(k)) bOnly++;
    }
  }
  if (withA < 6 || withoutA < 6) return null;
  final near = bothOn / withA;
  final far = bOnly / withoutA;
  final gap = (near - far).abs();
  if (gap < 0.20) return null;
  final said = near > far
      ? tr(
          '${a.name} arrastra a ${b.name}.',
          '${a.name} pulls ${b.name} along.',
        )
      : tr(
          '${a.name} y ${b.name} casi nunca el mismo día.',
          '${a.name} and ${b.name} almost never on the same day.',
        );
  return (
    Notice(
      NoticeKind.pair,
      said,
      tr(
        'Los días de ${a.name}, ${b.name} aparece el ${_pct(near)} de las '
            'veces. El resto de los días, el ${_pct(far)}.',
        'On ${a.name} days, ${b.name} shows up ${_pct(near)} of the time. '
            'On the other days, ${_pct(far)}.',
      ),
      bars: [near, far],
      ticks: [
        tr('con ${a.name}', 'with ${a.name}'),
        tr('sin ${a.name}', 'without ${a.name}'),
      ],
      mark: 0,
      more: tr(
        'Contado sobre los ${withA + withoutA} días desde que existen los '
            'dos y ninguno dormía: '
            '$withA con ${a.name} y $withoutA sin. Dos barras iguales serían '
            'dos hábitos que no se enteran el uno del otro.',
        'Counted over the ${withA + withoutA} days since both have existed '
            'and neither was asleep: '
            '$withA with ${a.name} and $withoutA without. Two equal bars '
            "would be two habits that don't notice each other.",
      ),
    ),
    gap,
  );
}

/// How long this has been going on, which is the one number nobody can argue
/// with and the only one worth being proud of on its own.
Notice? lifetime(Habit h, DateTime now) {
  final days = daysOf(h);
  if (days.length < 25) return null;
  return Notice(
    NoticeKind.life,
    tr('${days.length} días de tu vida.', '${days.length} days of your life.'),
    tr(
      'Desde el ${_date(days.first)} de ${days.first.year}. '
          '${h.total} ${_pieces(h.total)} en total.',
      'Since ${_date(days.first)}, ${days.first.year}. '
          '${h.total} ${_pieces(h.total)} in all.',
    ),
    bars: weeksOf(h, now, 26),
    more: tr(
      'Medio año, semana a semana. No hay nada que interpretar acá: es '
          'sólo lo que hiciste, y es bastante.',
      "Half a year, week by week. There's nothing to interpret here: it's "
          "just what you did, and it's plenty.",
    ),
  );
}

/// Who is ahead in the valley.
///
/// The only competition this app has any business running: everybody is racing
/// the same thing — one achievement at a time — and having several towns in
/// sight of each other is what makes that visible at all. Said plainly, with
/// the gap, and never with a word of encouragement stuck on the end.
Notice? crownOf(Habit h, List<Habit> all) {
  final live = [
    for (final o in all)
      if (o.total > 0) o,
  ];
  if (live.length < 2) return null;
  live.sort((a, b) {
    final c = b.total.compareTo(a.total);
    return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
  });
  final me = live.indexWhere((o) => o.id == h.id);
  if (me < 0) return null;
  final top = live.first;
  final bars = [for (final o in live) o.total / top.total];
  final ticks = [for (final o in live) o.name];
  if (me == 0) {
    final next = live[1];
    final by = top.total - next.total;
    return Notice(
      NoticeKind.crown,
      tr(
        '${h.name} lleva la corona del valle.',
        "${h.name} wears the valley's crown.",
      ),
      by == 0
          ? tr(
              'Empatado con ${next.name}, a ${top.total} ${_pieces(top.total)}.',
              'Tied with ${next.name}, at ${top.total} ${_pieces(top.total)}.',
            )
          : tr(
              '${top.total} ${_pieces(top.total)}, $by más que ${next.name}.',
              '${top.total} ${_pieces(top.total)}, $by more than ${next.name}.',
            ),
      bars: bars,
      ticks: ticks,
      mark: 0,
      more: tr(
        'La corona es del pueblo más grande del valle y se ve desde los '
            'otros. No hace nada: sólo está ahí.',
        'The crown belongs to the biggest town in the valley, and it can be '
            "seen from the others. It doesn't do anything: it's just there.",
      ),
    );
  }
  final by = top.total - live[me].total;
  return Notice(
    NoticeKind.crown,
    tr('La corona la tiene ${top.name}.', '${top.name} has the crown.'),
    by == 1
        ? tr('Por una sola pieza.', 'By a single piece.')
        : tr(
            'Por $by piezas: ${top.name} va ${top.total} y ${h.name} va '
                '${live[me].total}.',
            'By $by pieces: ${top.name} is at ${top.total} and ${h.name} is '
                'at ${live[me].total}.',
          ),
    bars: bars,
    ticks: ticks,
    mark: 0,
    more: tr(
      'Cambia de cabeza el día que otro pueblo lo alcanza, y no hace falta '
          'nada más para quitársela que seguir poniendo piezas.',
      'It changes hands the day another town catches up, and nothing more '
          'is needed to take it than to keep placing pieces.',
    ),
  );
}

// ------------------------------------------------------------------- saying

const List<String> _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábados',
  'domingos',
];

String _weekday(int w) =>
    inEnglish ? weekdaysEn(w) : _weekdays[(w - 1).clamp(0, 6)];

String _date(DateTime d) => dayMonth(d);

String _pieces(int n) => n == 1 ? tr('pieza', 'piece') : tr('piezas', 'pieces');

String _pct(double v) => '${(v * 100).round()}%';

String _partOfDay(int hour) {
  if (hour >= 5 && hour < 12) return ' de la mañana';
  if (hour >= 12 && hour < 20) return ' de la tarde';
  return ' de la noche';
}
