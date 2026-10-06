/// Las dos cosas que un pueblo no deduce: el plan y la identidad.
///
/// Todo lo demás que el tablón dice de vos sale de las piezas —a qué hora caen,
/// qué días faltan, cuánto tardás en volver— y no hace falta escribirlo. Estas
/// dos no se pueden deducir de nada, porque no son observaciones: son
/// decisiones. A qué hora y en qué sitio vas a hacerlo, y en quién te convierte.
///
/// **Por qué existen.** Las dos son lo que separa un hábito que aguanta de una
/// buena intención, y ninguna de las dos cuesta nada de guardar:
///
///  * **El plan** («voy a leer a las 22, en la cama») convierte una intención en
///    una decisión ya tomada. Es lo más barato que se puede hacer para que algo
///    pase de verdad, y lo único que hay que hacer es escribirlo una vez.
///  * **La identidad** («alguien que lee todos los días») es lo que hace que el
///    hábito no se acabe al cumplir la meta. Cada pieza es un voto a favor de
///    esa frase, y este pueblo es el recuento — pero el pueblo no lo dice hasta
///    que sea verdad: es un título y se gana. Ver [identityStanding].
///
/// Hubo una tercera, la regla («después de correr, estirar»), y ya no se firma:
/// que dos hábitos van juntos es algo que el tablón ve y dice, no algo que haya
/// que declarar. Lo que queda de ella es [Habit.afterId], que se lee de las
/// copias viejas y nada más.
///
/// Este fichero no escribe ninguna pantalla ni ninguna nota: sólo dice cómo se
/// leen las dos en voz alta y qué tan bien se están cumpliendo. Lo demás lo
/// hacen el tablón, la hoja del hábito y la primera vez.
library;

import 'dart:math' as math;

import 'habit.dart';
import 'piece.dart';
import 'rhythm.dart';

/// El plan, dicho entero: «Voy a leer a las 22, en la cama.»
///
/// Nulo si no hay nada escrito. Con media mitad vale: una hora sin sitio y un
/// sitio sin hora siguen siendo mejores que nada, y obligar a las dos cosas
/// sería el formulario que esta app no tiene.
String? vowOf(Habit h) => vowLine(h.name, h.vowHour, h.vowPlace);

/// Lo mismo, con las piezas sueltas.
///
/// Existe aparte porque la frase hace falta **antes** de que haya hábito: al
/// fundar el pueblo se ve escribiéndose mientras se elige la hora, y ahí
/// todavía no hay nada guardado de lo que sacarla.
String? vowLine(String name, int? hour, String? place) {
  final sitio = _clean(place);
  if (hour == null && sitio == null) return null;
  final que = 'Voy a ${lowerName(name.trim().isEmpty ? 'hacerlo' : name)}';
  if (hour == null) return '$que, ${placeSaid(sitio!)}.';
  if (sitio == null) return '$que ${hourSaid(hour)}.';
  return '$que ${hourSaid(hour)}, ${placeSaid(sitio)}.';
}

/// Una hora del reloj, dicha como se dice en voz alta.
///
/// Las tres de la tarde son «las 15» en un plan escrito y nadie habla así, pero
/// tampoco hace falta la vuelta entera: lo que tiene que quedar claro es que no
/// es de madrugada. Las dos que no se dicen con número —medianoche y mediodía—
/// van por su nombre, que es como las llama cualquiera.
String hourSaid(int hour) {
  final h = hour % 24;
  return switch (h) {
    0 => 'a medianoche',
    1 => 'a la 1 de la madrugada',
    12 => 'al mediodía',
    _ when h < 6 => 'a las $h de la madrugada',
    _ when h < 12 => 'a las $h de la mañana',
    _ when h < 21 => 'a las $h de la tarde',
    _ => 'a las $h de la noche',
  };
}

/// El sitio con su preposición, sin repetirla si ya la trae.
///
/// Se escribe «la cama» y se lee «en la cama»; pero quien escribe «de camino al
/// trabajo» o «en la cocina» no tiene por qué salir con un «en» de más delante.
String placeSaid(String place) {
  final t = place.trim();
  final bajo = t.toLowerCase();
  for (final p in const [
    'en ',
    'a ',
    'al ',
    'de ',
    'del ',
    'sobre ',
    'junto ',
    'antes ',
    'después ',
    'mientras ',
    'camino ',
    'nada más ',
  ]) {
    if (bajo.startsWith(p)) return t;
  }
  return 'en $t';
}

/// El nombre del hábito dentro de una frase: «Leer» → «leer».
///
/// Sólo la primera letra, y sólo si la segunda no es mayúscula: un hábito que
/// se llama «GYM» o «TDAH» no se escribe «gYM» ni «tDAH».
String lowerName(String name) {
  final t = name.trim();
  if (t.isEmpty) return t;
  if (t.length > 1 &&
      t[1] == t[1].toUpperCase() &&
      t[1] != t[1].toLowerCase()) {
    return t;
  }
  return t[0].toLowerCase() + t.substring(1);
}

/// La hora a la que de verdad aparecés, y qué parte de las piezas caen ahí.
///
/// La ventana es de tres horas y no de una: nadie hace nada a la misma hora
/// clavada, y «casi siempre a las diez» tiene que seguir siendo verdad para
/// quien unos días empieza a las nueve y media y otros a las once. Se devuelve
/// la hora del medio de la mejor ventana, que es la que se dice en voz alta.
///
/// Nulo mientras no haya bastante. [least] piezas es lo menos con lo que se
/// puede hablar de una costumbre, y por debajo de la mitad dentro de la ventana
/// no hay costumbre de la que hablar: hay un hábito que cae donde puede, y a
/// ése no se le propone ninguna hora.
(int hour, double share)? habitualHour(Habit h, {int least = 12}) {
  if (h.pieces.length < least) return null;
  final byHour = List<int>.filled(24, 0);
  for (final p in h.pieces) {
    byHour[p.placedAt.hour]++;
  }
  var at = 0, best = -1;
  for (var s = 0; s < 24; s++) {
    final sum = byHour[s] + byHour[(s + 1) % 24] + byHour[(s + 2) % 24];
    if (sum > best) {
      best = sum;
      at = s;
    }
  }
  final share = best / h.pieces.length;
  if (share < 0.5) return null;
  // La hora que se dice es la más llena de las tres, y no la del medio. Con la
  // del medio, un hábito que cae siempre clavado a las 22 se anunciaba a las 21
  // —porque la primera ventana que llega al máximo es la que empieza a las 20—
  // y el plan que se proponía era una hora antes que el hábito.
  var hora = at;
  for (var k = 1; k < 3; k++) {
    if (byHour[(at + k) % 24] > byHour[hora]) hora = (at + k) % 24;
  }
  return (hora, share);
}

/// Cuántas horas hay entre el plan y la costumbre, por el lado corto del reloj.
///
/// Nulo si no hay plan con hora o no hay costumbre todavía. Cero quiere decir
/// que lo que escribiste es exactamente lo que hacés.
int? planDrift(Habit h) {
  final dicho = h.vowHour;
  final uso = habitualHour(h);
  if (dicho == null || uso == null) return null;
  return hoursApart(dicho, uso.$1);
}

/// La distancia entre dos horas del reloj, que da la vuelta: de las 23 a la 1
/// hay dos horas, no veintidós.
int hoursApart(int a, int b) {
  final d = (a - b).abs() % 24;
  return math.min(d, 24 - d);
}

/// Qué parte de tus piezas caen dentro de la hora del plan, contando una hora
/// para cada lado.
///
/// Nulo si no hay hora escrita o hay demasiado poco puesto. Es la única de las
/// tres frases que se puede comprobar: una identidad no se cumple ni se
/// incumple, y una regla se mide con los dos hábitos a la vez.
double? planKept(Habit h, {int least = 12}) {
  final dicho = h.vowHour;
  if (dicho == null || h.pieces.length < least) return null;
  var dentro = 0;
  for (final p in h.pieces) {
    if (hoursApart(p.placedAt.hour, dicho) <= 1) dentro++;
  }
  return dentro / h.pieces.length;
}

/// Lo que va en el campo después del «alguien» fijo: «sabio», «que lee todos
/// los días». Lo que se guarda es la frase entera, así que al abrir un hábito
/// se le quita el «alguien» del principio para no escribirlo dos veces.
String identityTail(String? whole) {
  final t = (whole ?? '').trim();
  final m = RegExp(r'^alguien(\s+|$)', caseSensitive: false).firstMatch(t);
  return m == null ? t : t.substring(m.end).trim();
}

/// Y al revés: lo escrito después del «alguien», con el «alguien» pegado
/// delante. Nulo si no se escribió nada. Si alguien lo escribe igual —«alguien
/// sabio» en el campo—, no sale «alguien alguien sabio».
String? identityWhole(String tail) {
  final resto = identityTail(tail);
  return resto.isEmpty ? null : 'alguien $resto';
}

/// Lo que escribiste que querés ser, limpio y en minúscula: «alguien sabio».
String? identityWanted(Habit h) {
  final quien = _clean(h.identity);
  if (quien == null) return null;
  final sin = quien.endsWith('.')
      ? quien.substring(0, quien.length - 1).trimRight()
      : quien;
  return sin.isEmpty ? null : lowerName(sin);
}

/// La identidad, dicha como la dice el pueblo.
///
/// «Este pueblo es de alguien que lee todos los días.» El sujeto lo pone el
/// pueblo y no vos: lo que se escribe es la mitad que habla de vos, y el pueblo
/// se encarga de ser la prueba.
String? identitySaid(Habit h) {
  final quien = identityWanted(h);
  return quien == null ? null : 'Este pueblo es de $quien.';
}

// ------------------------------------------------------- el título, ganado

/// Cuánto hay que aguantar para que el pueblo te llame así: trece semanas.
///
/// Tres meses, que es el tramo más corto en el que una manera de vivir se
/// distingue de una racha de buena suerte. Y en semanas enteras y no en días
/// sueltos, porque el ritmo de un hábito se mide por semanas: quien corre tres
/// veces por semana no falla el martes, corre el miércoles.
const int identityWeeks = 13;

/// Y con cuánto: el noventa por ciento **de tu propio ritmo**, no de los siete
/// días. El pueblo primero averigua cada cuánto lo hacés de verdad, y el título
/// se gana cumpliendo eso, que es lo único que se puede prometer.
const double identityBar = 0.9;

/// Cómo va el título: cada cuánto hacés esto, cuánto lo estás cumpliendo, y si
/// el pueblo ya puede llamarte así.
///
/// **El título no se escribe, se gana.** Escribir «alguien sabio» el día que se
/// funda el pueblo y que el tablón lo anuncie esa misma tarde es exactamente lo
/// que esta app no hace: todavía no hiciste nada. Lo que se escribe es lo que
/// querés ser; lo que el pueblo dice de vos tiene que venir de lo que hiciste,
/// como todo lo demás del tablón.
class IdentityStanding {
  const IdentityStanding({
    required this.wanted,
    required this.said,
    required this.rhythm,
    required this.kept,
    required this.weeks,
    required this.done,
  });

  /// «alguien sabio», y la frase entera del pueblo.
  final String wanted;
  final String said;

  /// Cada cuánto se hace esto de verdad: días por semana, de 1 a 7. Sale de lo
  /// que hacés y no de lo que dijiste — nadie declara su ritmo, se le ve.
  final int rhythm;

  /// Qué parte de ese ritmo estás cumpliendo, de 0 a 1, contando cada semana
  /// por separado: una semana heroica no compensa una semana en blanco.
  final double kept;

  /// Semana a semana, lo mismo, de la más vieja a la más nueva. Es la prueba
  /// dibujada: dónde se cayó y dónde se aguantó.
  final List<double> weeks;

  /// Cuántas de las trece semanas llevás contadas. Las semanas dormidas no
  /// cuentan: una pausa retrasa el título, no lo rompe.
  final int done;

  /// Las que faltan para poder mirar el título siquiera.
  int get missing => math.max(0, identityWeeks - done);

  /// Si el pueblo ya te llama así.
  bool get earned => missing == 0 && kept >= identityBar;

  /// Cuántos días de los noventa y uno llevás. Para decirlo en días, que es
  /// como se cuenta la espera en voz alta.
  int get days => done * 7;
}

/// El título de [h] a fecha de [at], o nulo si no escribiste ninguno.
///
/// Se calcula sobre las últimas [identityWeeks] semanas cerradas hacia atrás
/// desde hoy. Cada semana pide lo que pide tu ritmo —descontando los días en que
/// el pueblo dormía— y aporta como mucho eso: así, cinco piezas en un domingo no
/// tapan una semana entera sin aparecer.
///
/// El ritmo sale de esas mismas semanas, por la mediana: dos semanas malas no
/// bajan el listón, que sería premiar el bajón, y dos semanas heroicas tampoco
/// lo suben hasta hacerlo imposible.
IdentityStanding? identityStanding(Habit h, {DateTime? at}) {
  final wanted = identityWanted(h);
  final said = identitySaid(h);
  if (wanted == null || said == null) return null;

  final hoy = dayStart(at ?? DateTime.now());
  final conPieza = <int>{for (final d in daysOf(h)) dayKey(d)};
  var nace = dayStart(h.createdAt);
  final dias = daysOf(h);
  if (dias.isNotEmpty && dias.first.isBefore(nace)) nace = dias.first;

  // Cada semana: cuántos días contaban —despiertos y dentro de la vida del
  // pueblo— y en cuántos hubo pieza.
  final hechos = <int>[], contaban = <int>[];
  for (var w = identityWeeks - 1; w >= 0; w--) {
    final desde = shiftDays(hoy, -(7 * w + 6));
    // Una semana en la que el pueblo todavía no existía no es una semana suya:
    // sin esto, un pueblo fundado hace ochenta y cinco días tenía ya sus trece
    // casillas —la más vieja a medias— y el título llegaba casi una semana
    // antes de las trece semanas.
    if (desde.isBefore(nace)) continue;
    var pieza = 0, cuentan = 0;
    for (var i = 0; i < 7; i++) {
      final d = shiftDays(desde, i);
      if (d.isBefore(nace) || d.isAfter(hoy)) continue;
      final hubo = conPieza.contains(dayKey(d));
      if (!hubo && h.restedOn(d)) continue;
      cuentan++;
      if (hubo) pieza++;
    }
    hechos.add(pieza);
    contaban.add(cuentan);
  }

  // El ritmo contra el que se mide: **el que dijiste**, si lo dijiste.
  //
  // Desde que el pueblo pregunta cada cuánto vas a la semana de fundarlo
  // —ver `model/cadence.dart`— hay una respuesta tuya, y un título se gana
  // contra lo que te pediste. Medirse contra el propio promedio lo cumple
  // cualquiera: quien va cayendo de cinco días a dos sigue al cien por cien
  // de su ritmo todo el camino, y eso no puede ser un título.
  //
  // Quien no contestó —o traía el hábito de antes de que se preguntara— se
  // mide contra lo que se le ve, por la mediana de las semanas enteras que
  // hubo. Una semana a medias —la primera de un pueblo recién fundado, o una
  // con pausa dentro— no dice cada cuánto lo hacés, así que no vota.
  var rhythm = h.perWeek ?? 0;
  if (rhythm <= 0) {
    final llenas = <int>[
      for (var i = 0; i < hechos.length; i++)
        if (contaban[i] >= 7) hechos[i],
    ];
    if (llenas.isEmpty) return null;
    llenas.sort();
    rhythm = llenas[llenas.length ~/ 2];
  }
  rhythm = rhythm.clamp(1, 7);

  // Y el cumplimiento, semana a semana y con tope.
  final semanas = <double>[];
  var pide = 0.0, cumple = 0.0;
  for (var i = 0; i < hechos.length; i++) {
    if (contaban[i] == 0) continue; // semana dormida entera: no cuenta
    final espera = math.max(1.0, rhythm * contaban[i] / 7);
    final hizo = math.min(hechos[i].toDouble(), espera);
    semanas.add(hizo / espera);
    pide += espera;
    cumple += hizo;
  }
  if (semanas.isEmpty) return null;
  return IdentityStanding(
    wanted: wanted,
    said: said,
    rhythm: rhythm,
    kept: pide <= 0 ? 0 : cumple / pide,
    weeks: semanas,
    done: semanas.length,
  );
}

/// El ritmo dicho en voz alta: «cinco días de cada siete», «todos los días».
String rhythmSaid(int perWeek) => switch (perWeek) {
  >= 7 => 'todos los días',
  1 => 'un día por semana',
  _ => '$perWeek días de cada siete',
};

/// Un texto que puede venir vacío desde un archivo viejo o desde un campo que
/// alguien dejó en blanco.
String? _clean(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}
