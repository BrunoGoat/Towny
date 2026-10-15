import 'dart:math' as math;

import '../engine/board_plan.dart';
import '../engine/town.dart';
import '../l10n/lang.dart';
import 'findings.dart';
import 'habit.dart';
import 'notice.dart';
import 'piece.dart';

/// Lo que hay clavado en el tablón de un pueblo.
///
/// Una sola cuenta para las dos cosas que la necesitan: el tablón de cerca,
/// que las escribe, y el de la plaza, que enseña su silueta. Si fueran dos, el
/// tablón de lejos tendría cuatro papeles y el de cerca seis, y la única
/// manera de enterarse sería acercarse y contar.
///
/// Primero lo tuyo, y detrás lo que el pueblo sabe de vos. Y si de vos no
/// sabe nada todavía, las hojas que explican el tablón ([guideNotices]).
///
/// Nada más. Antes el pueblo clavaba también sus bandos —una cabra perdida,
/// un baile el sábado—, dos a cuatro cada día, y eran la mitad de las hojas:
/// enseñaban que no hacía falta leer el tablón, que es lo contrario de para
/// lo que existe. Un tablón con dos hojas dice «todavía te estoy conociendo»,
/// y eso también es verdad.
///
List<Notice> boardNotices(
  Habit h, {
  List<Habit> valley = const [],
  DateTime? at,
}) {
  final work = TownPlan.of(
    h.place,
    seed: h.townSeed,
  ).underway(h.total, h.chronicle);
  final said = noticesFor(
    h,
    others: valley,
    underway: work?.$1,
    left: work?.$2 ?? 0,
    at: at,
  );
  // Delante de todo, lo tuyo. Es tu tablón: lo que clavaste vos no lo puede
  // dejar fuera ninguna otra hoja. Si no cabe todo, lo que se recorta es lo
  // del pueblo, que seguirá ahí mañana. Una nota que clavaste y no aparece es
  // un tablón roto.
  final mias = myNotices(h);
  final cabe = math.max(0, BoardPlan.capacity - mias.length);
  return [
    ...mias,
    // Mientras el pueblo no sepa nada de vos, las hojas que explican el
    // tablón. Se van todas juntas con la primera nota de verdad, aunque ya
    // hayas clavado alguna tuya: lo que explican es lo que el pueblo va a
    // escribir.
    ...(said.isEmpty ? guideNotices(h) : said).take(cabe),
  ];
}

/// Cuántas notas tuyas caben clavadas a la vez.
///
/// El tablón es del pueblo tanto como tuyo: llenarlo entero de recordatorios
/// deja fuera lo que averiguó de vos, que es la mitad de para lo que existe.
/// Las que no caben no se pierden — siguen guardadas y vuelven a asomar en
/// cuanto quitás una.
const int myNoticeCap = 4;

/// Lo que clavaste vos, de lo más nuevo a lo más viejo.
///
/// El formato de cada renglón es `milisegundos|texto`, y uno roto se salta en
/// vez de tirar el tablón abajo.
List<Notice> myNotices(Habit h) {
  final out = <Notice>[];
  for (final line in h.notes) {
    if (out.length >= myNoticeCap) break;
    final corte = line.indexOf('|');
    if (corte <= 0) continue;
    final millis = int.tryParse(line.substring(0, corte));
    final texto = line.substring(corte + 1).trim();
    if (millis == null || texto.isEmpty) continue;
    out.add(
      Notice(
        NoticeKind.mine,
        texto,
        _cuando(DateTime.fromMillisecondsSinceEpoch(millis)),
      ),
    );
  }
  return out;
}

/// Desde cuándo está clavada. Va en el sitio de las cuentas, porque de una
/// nota tuya no hay cuentas que enseñar: lo único que el tablón sabe de ella
/// es el día que la clavaste.
String _cuando(DateTime at) {
  final dias = daysBetween(at, DateTime.now());
  if (dias <= 0) return tr('Clavada hoy.', 'Pinned today.');
  if (dias == 1) return tr('Clavada ayer.', 'Pinned yesterday.');
  if (dias < 30) {
    return tr('Clavada hace $dias días.', 'Pinned $dias days ago.');
  }
  final meses = (dias / 30).floor();
  return tr(
    'Clavada hace $meses ${meses == 1 ? 'mes' : 'meses'}.',
    'Pinned $meses ${meses == 1 ? 'month' : 'months'} ago.',
  );
}

/// Las hojas que explican el tablón, una por cosa.
///
/// Antes era una sola, y lo decía todo junto: qué es, que se toca para leer,
/// que se pueden clavar notas. Una hoja con cinco instrucciones se lee como
/// un reglamento y se olvida entera; cinco hojas con una cada una se leen
/// como un tablón, que además es justo lo que enseñan a usar. La primera
/// presenta el tablón, la última avisa de que se van.
///
/// En orden de lectura, y el orden importa: los huecos van de arriba abajo y
/// de izquierda a derecha, y al entrar sólo se ve la primera columna entera.
/// Ahí van la que presenta el tablón y la que dice que se corre a los lados,
/// que es lo que hace falta saber para ver todas las demás.
///
/// Se despegan solas en cuanto llega la primera nota con un dato tuyo.
List<Notice> guideNotices(Habit h) {
  Notice hoja(String es, String en, String esY, String enY) =>
      Notice(NoticeKind.guia, tr(es, en), tr(esY, enY));
  return [
    hoja(
      'Este es el tablón de anuncios de ${h.name}.',
      'This is the notice board for ${h.name}.',
      'Acá el pueblo va clavando lo que aprende de vos y te brinda '
          'información para ayudarte. Mientras todavía no sabe nada, estas '
          'hojas te cuentan cómo se usa.',
      'Here the town pins what it learns about you and gives you '
          'information to help you. While it still knows nothing, these '
          'sheets show you how it works.',
    ),
    hoja(
      'Deslizá el dedo de costado para recorrer el tablón.',
      'Slide your finger sideways to move along the board.',
      'Las hojas se clavan de izquierda a derecha, y no siempre entran todas '
          'en la pantalla.',
      'Sheets are pinned from left to right, and they don\'t always all fit '
          'on the screen.',
    ),
    hoja(
      'Tocá una hoja para leerla de cerca.',
      'Tap a sheet to read it up close.',
      'Para devolverla a su lugar, tocá otra vez.',
      'Tap again to put it back.',
    ),
    hoja(
      'Mantené el dedo sobre una hoja para despegarla.',
      'Hold your finger on a sheet to unpin it.',
      'Sin soltarla, llevala a otro hueco. El tablón se acuerda de dónde la '
          'dejaste, y así se ve también desde la plaza.',
      'Without letting go, carry it to another spot. The board remembers '
          'where you left it, and that is how it looks from the square too.',
    ),
    hoja(
      'Vos también podés clavar tus notas.',
      'You can pin your own notes too.',
      'Con «Clavar una nota», abajo. Van en un papel más claro y con tu letra, '
          'y entran hasta $myNoticeCap a la vez.',
      'With “Pin a note”, at the bottom. They go on lighter paper in your own '
          'hand, and up to $myNoticeCap fit at once.',
    ),
    hoja(
      'Para quitar una nota tuya, abrila.',
      'To remove one of your notes, open it.',
      'Al leerla de cerca aparece «Quitarla», abajo.',
      'Up close, “Remove it” appears at the bottom.',
    ),
    hoja(
      'Lo nuevo lleva una marca.',
      'New things carry a mark.',
      'Se apaga cuando leés la hoja de cerca: así sabés qué cambió desde la '
          'última vez.',
      'It goes out once you read the sheet up close, so you know what '
          'changed since last time.',
    ),
    hoja(
      'Para volver al pueblo, tocá el cielo o el pasto.',
      'To go back to the town, tap the sky or the grass.',
      'O juntá dos dedos sobre el tablón.',
      'Or pinch the board with two fingers.',
    ),
    hoja(
      'Estas hojas se van solas.',
      'These sheets leave on their own.',
      'Cuando el pueblo aprenda algo de vos, se despegan y le dejan el lugar a '
          'lo que averiguó.',
      'Once the town learns something about you, they come down and make room '
          'for what it found out.',
    ),
  ];
}
