/// Las tres cosas que un pueblo no deduce: el plan, la identidad y la regla.
///
/// Todo lo demás que el tablón dice de vos sale de las piezas —a qué hora caen,
/// qué días faltan, cuánto tardás en volver— y no hace falta escribirlo. Estas
/// tres no se pueden deducir de nada, porque no son observaciones: son
/// decisiones. A qué hora y en qué sitio vas a hacerlo; en quién te convierte;
/// y detrás de qué otra cosa va.
///
/// **Por qué existen.** Las tres son lo que separa un hábito que aguanta de una
/// buena intención, y ninguna de las tres cuesta nada de guardar:
///
///  * **El plan** («voy a leer a las 22, en la cama») convierte una intención en
///    una decisión ya tomada. Es lo más barato que se puede hacer para que algo
///    pase de verdad, y lo único que hay que hacer es escribirlo una vez.
///  * **La identidad** («alguien que lee todos los días») es lo que hace que el
///    hábito no se acabe al cumplir la meta. Cada pieza es un voto a favor de
///    esa frase, y este pueblo es el recuento.
///  * **La regla** («después de correr, estirar») le da al hábito nuevo el
///    recordatorio que no tiene: otro hábito que ya existe. El pueblo ya sabe
///    cuáles van juntos —está en el tablón— y esto es firmarlo.
///
/// Este fichero no escribe ninguna pantalla ni ninguna nota: sólo dice cómo se
/// leen las tres en voz alta y qué tan bien se están cumpliendo. Lo demás lo
/// hacen el tablón, la hoja del hábito y la primera vez.
library;

import 'dart:math' as math;

import 'habit.dart';
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

/// La identidad, dicha como la dice el pueblo.
///
/// «Este pueblo es de alguien que lee todos los días.» El sujeto lo pone el
/// pueblo y no vos: lo que se escribe es la mitad que habla de vos, y el pueblo
/// se encarga de ser la prueba. Se le quita el punto final si venía con uno,
/// que si no la frase acaba con dos.
String? identitySaid(Habit h) {
  final quien = _clean(h.identity);
  if (quien == null) return null;
  final sin = quien.endsWith('.')
      ? quien.substring(0, quien.length - 1).trimRight()
      : quien;
  if (sin.isEmpty) return null;
  return 'Este pueblo es de ${lowerName(sin)}.';
}

/// Cuántos días llevás siéndolo: los días con pieza, que son los votos.
int identityVotes(Habit h) => daysOf(h).length;

/// Un texto que puede venir vacío desde un archivo viejo o desde un campo que
/// alguien dejó en blanco.
String? _clean(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}
