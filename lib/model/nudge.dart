import 'habit.dart';
import 'piece.dart';
import 'rhythm.dart';

/// Lo que el pueblo te diría si hoy hiciera falta decirte algo, y cuándo.
///
/// Todo el diseño de las notificaciones está acá, y no hay una sola línea de
/// plataforma: entra el estado de tus hábitos y una fecha, sale una decisión.
/// Eso es a propósito — lo único que puede salir mal de verdad en una
/// notificación es **cuándo** llega y **qué** dice, y las dos cosas se pueden
/// probar sin teléfono.
///
/// ## La regla de la que sale todo
///
/// Una notificación de una app de hábitos es, casi siempre, una app pidiendo
/// atención para sí misma. Ésta sólo se permite hablar cuando tiene algo que
/// vos no sabés, y se calla el resto del tiempo — que es el resto del tiempo.
///
/// De ahí salen cuatro decisiones, y cada una tiene su por qué:
///
/// **No hay recordatorio diario.** Un aviso a las nueve todos los días no
/// contiene ninguna información: el día que lo ibas a hacer sobra, y el día
/// que no, es alguien dándote un codazo. Lo que esta app puede saber y vos no
/// es que **llevás más de lo tuyo sin aparecer**, y eso sólo se sabe midiendo
/// tu propio ritmo.
///
/// **El umbral es tuyo, no del calendario.** Quien pone piezas a diario está
/// tarde al segundo día; quien las pone tres veces por semana no está tarde el
/// jueves, y decirle que sí es el error que comete cualquier app que trate
/// todos los días en blanco como incumplimientos. Sale de
/// [Consistency], que ya mide cada cuánto aparecés y ya descuenta los días
/// dormidos.
///
/// **Como mucho dos por hueco**, y la segunda semanas después. La primera
/// cuando te retrasás; la segunda sólo si el hueco se hace largo de verdad, y
/// ésa no habla del hábito sino de que no se perdió nada. Nunca una al día.
///
/// **Y se calla sola.** Si tres avisos seguidos no traen ninguna pieza, este
/// hábito deja de avisar durante tres semanas. Es la parte que ninguna app de
/// hábitos tiene y la que más falta hace: si no está funcionando, insistir no
/// lo arregla — lo único que consigue es que desinstales la app, que es peor
/// que no hacer el hábito.
///
/// ## Y qué dice
///
/// El día malo no se gana con una frase que escribió un diseñador. Se gana,
/// si se gana, con **lo que escribiste vos el día que lo empezaste**: por qué
/// lo querías, y qué es lo mínimo que cuenta. Esas dos frases existen desde
/// hace tiempo en la app y hasta ahora sólo se leían dentro. Éste es el otro
/// momento para el que se guardaron, y probablemente el bueno.
///
/// Lo que no dice, nunca: cuántos días llevás sin aparecer, nada que se parezca
/// a una racha, ninguna pregunta retórica, ningún signo de exclamación.
class Nudge {
  const Nudge({
    required this.habitId,
    required this.at,
    required this.title,
    required this.body,
    required this.kind,
  });

  /// De qué hábito habla.
  final String habitId;

  /// Cuándo tiene que sonar. La app no corre de fondo: esto se programa por
  /// adelantado y se vuelve a programar cada vez que se abre o cae una pieza.
  final DateTime at;

  final String title;
  final String body;
  final NudgeKind kind;
}

/// De qué clase es lo que hay que decir. Tres, y se diferencian en el tono
/// mucho más que en el contenido.
enum NudgeKind {
  /// Te retrasaste de tu propio ritmo y el pueblo todavía está entero.
  late,

  /// Y acá es donde se leen tus palabras: llevás lo bastante como para que el
  /// pueblo esté perdiendo luz, que es el día para el que las escribiste.
  words,

  /// Un hueco largo de verdad. Éste no habla del hábito: habla de que no se
  /// perdió nada, porque lo que frena a quien vuelve después de un mes no es
  /// la pereza, es pensar que hay que empezar de cero.
  back,
}

/// Las reglas de cuánto puede hablar. Todas en un sitio para poder discutirlas
/// de una vez en vez de perseguirlas por el código.
class NudgeRules {
  const NudgeRules._();

  /// Cuántas veces lo suyo tiene que caber en el hueco para que sea un retraso.
  ///
  /// Uno coma ocho, y no dos: con dos, quien aparece a diario no oiría nada
  /// hasta el tercer día, y para ésa el segundo ya es raro.
  static const double lateAt = 1.8;

  /// Y el suelo y el techo de ese umbral, en días.
  ///
  /// El suelo en dos porque un día en blanco no necesita que intervenga nadie
  /// —eso es la vida— y el techo en diez porque más allá el aviso llega tarde
  /// para lo único que sirve, que es cortar un hueco antes de que se vuelva un
  /// abandono.
  static const int lateFloor = 2;
  static const int lateCeiling = 10;

  /// Cuándo se manda el segundo y último del hueco: el de volver.
  static const int backAt = 21;

  /// Días que tienen que pasar entre dos avisos cualesquiera, de cualquier
  /// hábito. Sin esto, un valle de seis pueblos son seis codazos.
  static const int apart = 3;

  /// Cuánto tiene de margen un aviso para que la pieza que venga detrás cuente
  /// como suya. Cuarenta y ocho horas: más que eso ya no es el aviso, es la
  /// persona.
  static const int answerWindow = 48;

  /// Avisos que no sirvieron de nada, seguidos, que hacen que este hábito se
  /// calle.
  static const int giveUpAfter = 3;

  /// Y cuánto se calla entonces.
  static const int silenceDays = 21;

  /// La franja en la que se puede sonar. Nunca de madrugada, y nunca tan
  /// tarde que lo único que se pueda hacer con el aviso sea sentirse mal.
  static const int earliest = 8;
  static const int latest = 21;
}

/// El próximo aviso que habría que programar, o nulo — que es lo normal.
///
/// [now] es cuándo se está decidiendo. [lastAny] es cuándo sonó el último
/// aviso de cualquier hábito, para que no se pisen entre ellos.
Nudge? planNudge(List<Habit> habits, DateTime now, {DateTime? lastAny}) {
  Nudge? mejor;
  for (final h in habits) {
    final n = _forHabit(h, now, lastAny);
    if (n == null) continue;
    if (mejor == null || n.at.isBefore(mejor.at)) mejor = n;
  }
  return mejor;
}

/// Cada cuántos días aparecés, según los últimos treinta que contaban.
///
/// Uno quiere decir a diario; dos coma tres, unas tres veces por semana. Nulo
/// mientras no haya historia suficiente para decir nada — con diez días de
/// hábito, cualquier número que salga de acá es una invención.
double? cadenceOf(Habit h, {DateTime? at}) {
  // Con menos de esto no hay ritmo que medir, hay una corazonada. Son días con
  // pieza, no días de calendario: alguien que usó la app tres días y
  // desapareció un mes tiene un mes de ventana y no tiene ninguna historia.
  final dias = daysOf(h);
  if (dias.length < minHistory) return null;
  final c = consistencyOf(h, at: at);
  if (c.enough && c.done > 0) return c.of / c.done;

  // Y el caso que hacía falta escribir aparte: **ni una sola pieza en los
  // últimos treinta días**. Ahí no hay ritmo reciente que medir, y es
  // precisamente a quien lleva un mes fuera — la persona a la que más sentido
  // tiene escribirle. Se mide entonces sobre el tramo en el que sí usó la app.
  //
  // Dividir sin mirar daba infinito, y redondear infinito revienta. Lo
  // encontró un test antes que un teléfono.
  final span = dias.last.difference(dias.first).inDays + 1;
  return span / dias.length;
}

/// Días con pieza que hacen falta antes de que esto abra la boca por primera
/// vez. Dos semanas de uso de verdad, que es también cuando la app empieza a
/// hablar de constancia en el resto de las pantallas.
const int minHistory = 14;

/// A partir de cuántos días sin pieza este hábito va tarde **para vos**.
int lateAfter(Habit h, {DateTime? at}) {
  final cada = cadenceOf(h, at: at) ?? 1.0;
  return (cada * NudgeRules.lateAt).round().clamp(
    NudgeRules.lateFloor,
    NudgeRules.lateCeiling,
  );
}

/// La hora a la que sueles poner piezas, para no avisar a deshora.
///
/// La mediana de las últimas cuarenta, que es bastante para que un par de
/// noches raras no la muevan. Si no hay historia, las siete de la tarde.
int usualHour(Habit h) {
  final horas = [for (final p in h.pieces.reversed.take(40)) p.placedAt.hour]
    ..sort();
  if (horas.length < 5) return 19;
  return horas[horas.length ~/ 2].clamp(NudgeRules.earliest, NudgeRules.latest);
}

Nudge? _forHabit(Habit h, DateTime now, DateTime? lastAny) {
  // Un pueblo dormido no avisa. Ésa es la mitad del sentido de poder pausar:
  // si la pausa siguiera mandando recordatorios no sería una pausa.
  //
  // Contra [now] y no contra `h.resting`, que mira el reloj de verdad. Acá se
  // está decidiendo qué programar para dentro de unos días, así que preguntar
  // por el ahora de la pared contestaría por el día equivocado — y una pausa
  // que empieza mañana dejaría pasar el aviso de mañana.
  if (h.restAt(now) != null) return null;
  final last = h.lastPlacedAt;
  if (last == null) return null;

  // Sin ritmo medido no hay retraso que detectar, y adivinarlo es justo lo que
  // esta app no hace. Los primeros quince días no avisa nunca.
  if (cadenceOf(h, at: now) == null) return null;

  // Se calló por no funcionar. Vuelve sola pasadas tres semanas contadas desde
  // la última pieza, que es el único reloj que sigue corriendo cuando no hay
  // avisos que contar.
  final callado = h.nudgedAt;
  if (h.nudgesIgnored >= NudgeRules.giveUpAfter &&
      now.difference(last).inDays < NudgeRules.silenceDays) {
    return null;
  }

  final idle = dayStart(now).difference(dayStart(last)).inDays;
  final tarde = lateAfter(h, at: now);

  // Cuál de los dos toca. Ya avisado en este hueco quiere decir que el aviso
  // de retraso está gastado; lo único que queda es el de volver, y ése sólo
  // cuando el hueco se hace largo de verdad.
  final yaAvisado = callado != null && callado.isAfter(last);
  final NudgeKind kind;
  final int desde;
  if (!yaAvisado) {
    if (idle < tarde) return null;
    // Con el pueblo ya perdiendo luz es el día para el que se guardaron tus
    // palabras. Sin ellas escritas, el aviso lo da el propio pueblo.
    kind = (idle >= tarde * 2 && (h.why != null || h.floor != null))
        ? NudgeKind.words
        : NudgeKind.late;
    desde = tarde;
  } else {
    // ¿Cuál de los dos fue el que ya salió? No hace falta guardarlo: se lee de
    // cuántos días de hueco había cuando salió. Si salió pasado el umbral del
    // de volver, era ése, y este hueco ya gastó los dos que le tocan.
    final hueco = dayStart(callado).difference(dayStart(last)).inDays;
    if (hueco >= NudgeRules.backAt) return null;
    // Y si fue el de retraso, el segundo sólo cuando el hueco se hace largo de
    // verdad. El de retraso salió como mucho al día diez, así que entre los dos
    // hay once días largos por construcción.
    if (idle < NudgeRules.backAt) return null;
    kind = NudgeKind.back;
    desde = NudgeRules.backAt;
  }

  var at = _atHour(dayStart(last).add(Duration(days: desde)), usualHour(h));
  // Lo que ya pasó no se programa: si el umbral cayó ayer, suena hoy a su hora.
  while (at.isBefore(now)) {
    at = _atHour(at.add(const Duration(days: 1)), usualHour(h));
  }
  // Y no pegado al anterior, sea del hábito que sea.
  if (lastAny != null) {
    final libre = lastAny.add(const Duration(days: NudgeRules.apart));
    while (at.isBefore(libre)) {
      at = _atHour(at.add(const Duration(days: 1)), usualHour(h));
    }
  }

  return Nudge(
    habitId: h.id,
    at: at,
    title: h.name,
    body: _say(h, kind),
    kind: kind,
  );
}

DateTime _atHour(DateTime day, int hour) =>
    DateTime(day.year, day.month, day.day, hour);

/// Lo que se lee en el teléfono.
String _say(Habit h, NudgeKind kind) {
  switch (kind) {
    case NudgeKind.late:
      return 'Tu pueblo sigue en pie y hace unos días que no cae una pieza.';
    case NudgeKind.words:
      // Tus palabras, entrecomilladas y sin nada alrededor. El «escribiste» no
      // está de adorno: lo que hace que esto no sea una frase motivacional es
      // que se sepa de quién es la frase.
      final why = h.why?.trim();
      final floor = h.floor?.trim();
      if (why != null && why.isNotEmpty && floor != null && floor.isNotEmpty) {
        return 'Escribiste: «$why».\nY que lo mínimo que cuenta es «$floor».';
      }
      if (why != null && why.isNotEmpty) {
        return 'Escribiste que lo querías «$why».';
      }
      return 'Lo mínimo que cuenta, dijiste, es «$floor».';
    case NudgeKind.back:
      // Ni un número de días, ni una disculpa que pedir. Lo que frena a quien
      // vuelve es creer que hay que empezar de cero.
      return 'Tu pueblo sigue entero, con todo lo que construiste. '
          'Una sola pieza lo enciende otra vez.';
  }
}

/// Apunta que este aviso salió. Quién lo contesta y cómo se cuenta está en
/// [nudgeAnswered].
void nudgeSent(Habit h, DateTime when) => h.nudgedAt = when;

/// Y que cayó una pieza. Es la única respuesta que esto acepta.
///
/// **Si contestó de verdad o no, lo decide el reloj.** Una pieza dos días
/// después del aviso es el aviso funcionando; una pieza tres semanas después
/// es alguien que volvió por su cuenta, y contarla como un acierto sería la
/// manera de que la app nunca se entere de que sus avisos no sirven para nada.
///
/// Por eso acá se sube la cuenta además de bajarla: es lo que hace que un
/// hábito al que nunca le funcionan los avisos acabe callándose solo, en vez de
/// seguir insistiendo para siempre porque cada tanto la persona aparece.
void nudgeAnswered(Habit h, DateTime when) {
  final aviso = h.nudgedAt;
  if (aviso == null) return;
  final dentro =
      when.isAfter(aviso) &&
      when.difference(aviso).inHours <= NudgeRules.answerWindow;
  h.nudgesIgnored = dentro ? 0 : h.nudgesIgnored + 1;
  // El aviso ya está contestado de una manera o de otra: que no se vuelva a
  // contar cuando caiga la pieza siguiente.
  h.nudgedAt = null;
}

/// Los próximos avisos, no sólo el siguiente.
///
/// Hace falta porque la app no corre de fondo: lo que no quede programado
/// antes de cerrarla, no va a sonar. Y justamente la persona a la que más le
/// serviría el aviso de volver es la que lleva semanas sin abrirla, así que
/// programar sólo el primero dejaría fuera el único que importa de verdad.
///
/// Se calcula sobre **una copia** de los hábitos: planear el segundo exige
/// hacer como si el primero ya hubiera salido, y eso escribe en el hábito.
/// Hacerlo sobre los de verdad sería dar por dichos avisos que todavía no ha
/// oído nadie.
List<Nudge> planAhead(
  List<Habit> habits,
  DateTime now, {
  int upto = 3,
  DateTime? lastAny,
}) {
  final copia = [for (final h in habits) Habit.fromJson(h.toJson())];
  final out = <Nudge>[];
  var ultimo = lastAny;
  for (var i = 0; i < upto; i++) {
    final n = planNudge(copia, i == 0 ? now : out.last.at, lastAny: ultimo);
    if (n == null) break;
    out.add(n);
    nudgeSent(copia.firstWhere((h) => h.id == n.habitId), n.at);
    ultimo = n.at;
  }
  return out;
}
