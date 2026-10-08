/// Las fechas, dichas en el idioma de ahora.
///
/// Estaban repartidas en cuatro listas de meses —una por pantalla—, y cada
/// una con su manera de juntar el día con el mes. Juntas aquí porque en
/// inglés no es sólo otra palabra: cambia el orden. «3 de mayo» es «May 3», y
/// «mayo de 2026» es «May 2026».
library;

import 'lang.dart';

const List<String> _mesesEs = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const List<String> _monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// El mes entero: «mayo», «May». De 1 a 12.
String monthName(int month) =>
    (inEnglish ? _monthsEn : _mesesEs)[(month - 1).clamp(0, 11)];

/// El mes en tres letras: «may», «May».
String monthShort(int month) => monthName(month).substring(0, 3);

/// «3 de mayo», «May 3».
String dayMonth(DateTime d) => inEnglish
    ? '${monthName(d.month)} ${d.day}'
    : '${d.day} de ${monthName(d.month)}';

/// «mayo de 2026», «May 2026».
String monthYear(DateTime d) => inEnglish
    ? '${monthName(d.month)} ${d.year}'
    : '${monthName(d.month)} de ${d.year}';

/// «3 de mayo de 2026», «May 3, 2026».
String fullDate(DateTime d) => inEnglish
    ? '${monthName(d.month)} ${d.day}, ${d.year}'
    : '${d.day} de ${monthName(d.month)} de ${d.year}';

/// «3 may», «May 3»: la fecha corta de las tarjetas.
String dayMonthShort(DateTime d) => inEnglish
    ? '${monthShort(d.month)} ${d.day}'
    : '${d.day} ${monthShort(d.month)}';
