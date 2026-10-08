/// El plan dicho en inglés: cómo arranca la frase, la hora y el sitio. Ver
/// `lib/model/pledge.dart`, que tiene el castellano.
library;

/// Cómo empieza el plan. Con dos puntos y no con un verbo: los hábitos se
/// escriben como sustantivo —«Reading», «Gym»— y «I'm going to reading» no
/// se dice.
String vowLeadEn(String name) =>
    name.trim().isEmpty ? 'The plan:' : '${name.trim()}:';

/// Una hora del reloj: «9 am», «3 pm», «midnight», «noon».
String clockEn(int hour) {
  final h = hour % 24;
  if (h == 0) return 'midnight';
  if (h == 12) return 'noon';
  return h < 12 ? '$h am' : '${h - 12} pm';
}

/// La hora con su preposición: «at 10 pm».
String hourSaidEn(int hour) => 'at ${clockEn(hour)}';

/// El sitio con su preposición, sin repetirla si ya la trae: «bed» se lee
/// «in bed», y «at the gym» se queda como está.
String placeSaidEn(String place) {
  final t = place.trim();
  final bajo = t.toLowerCase();
  for (final p in const [
    'in ',
    'at ',
    'on ',
    'by ',
    'near ',
    'before ',
    'after ',
    'while ',
    'during ',
    'from ',
    'right ',
  ]) {
    if (bajo.startsWith(p)) return t;
  }
  return 'in $t';
}
