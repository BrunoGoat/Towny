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
    ...(said.isEmpty
            ? guideNotices(h, firstTown: isFirstTown(h, valley))
            : said)
        .take(cabe),
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
/// El formato de cada renglón es `milisegundos|título`, o
/// `milisegundos|título\nrenglón` si lleva algo debajo, y uno roto se salta
/// en vez de tirar el tablón abajo.
List<Notice> myNotices(Habit h) {
  final out = <Notice>[];
  for (final line in h.notes) {
    if (out.length >= myNoticeCap) break;
    final corte = line.indexOf('|');
    if (corte <= 0) continue;
    final millis = int.tryParse(line.substring(0, corte));
    final cuerpo = line.substring(corte + 1);
    final salto = cuerpo.indexOf('\n');
    final texto = (salto < 0 ? cuerpo : cuerpo.substring(0, salto)).trim();
    final debajo = salto < 0 ? '' : cuerpo.substring(salto + 1).trim();
    if (millis == null || texto.isEmpty) continue;
    final cuando = _cuando(DateTime.fromMillisecondsSinceEpoch(millis));
    // Con renglón debajo se escribe como las del pueblo —titular, raya y
    // renglón—, y el día va en [Notice.more], que es lo que le dice al papel
    // que no la escriba de corrido. Sin renglón, de corrido y con el día.
    out.add(
      debajo.isEmpty
          ? Notice(NoticeKind.mine, texto, cuando)
          : Notice(NoticeKind.mine, texto, debajo, more: cuando),
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

/// Si [h] es el primer pueblo que se fundó del valle: ninguno de los demás
/// es más viejo que él. Sin valle que mirar, se da por primero.
bool isFirstTown(Habit h, List<Habit> valley) =>
    !valley.any((o) => o.id != h.id && o.createdAt.isBefore(h.createdAt));

/// Las hojas que explican el tablón, una por cosa.
///
/// Antes era una sola, y lo decía todo junto: una hoja con cinco
/// instrucciones se lee como un reglamento y se olvida entera. Después fueron
/// nueve, una por cosa, y eran demasiadas: llenaban el tablón entero de
/// instrucciones. Son cuatro, cada una con lo que va junto: qué es el tablón,
/// cómo se mira, cómo se clava lo tuyo y cómo se mueve.
///
/// En orden de lectura, y el orden importa: los huecos van de arriba abajo y
/// de izquierda a derecha, y al entrar sólo se ve la primera columna entera.
/// Ahí van la que presenta el tablón y la que dice que se corre a los lados,
/// que es lo que hace falta saber para ver las demás.
///
/// Se despegan solas en cuanto llega la primera nota con un dato tuyo.
///
/// Las cuatro, sólo en el primer pueblo ([firstTown]). En los que vienen
/// después ya se sabe cómo se usa un tablón —es el mismo— y queda nada más
/// la que lo presenta.
List<Notice> guideNotices(Habit h, {bool firstTown = true}) {
  Notice hoja(String es, String en, String esY, String enY) =>
      Notice(NoticeKind.guia, tr(es, en), tr(esY, enY));
  final despega = firstTown
      ? ('estas hojas se despegan solas', 'these sheets come down on their own')
      : ('esta hoja se despega sola', 'this sheet comes down on its own');
  final presenta = hoja(
    'Este es el tablón de anuncios de ${h.name}.',
    'This is the notice board for ${h.name}.',
    'Acá el pueblo va clavando lo que aprende de vos y te brinda '
        'información para ayudarte. Cuando aprenda algo, ${despega.$1}.',
    'Here the town pins what it learns about you and gives you '
        'information to help you. Once it learns something, ${despega.$2}.',
  );
  if (!firstTown) return [presenta];
  return [
    presenta,
    hoja(
      'Deslizá el dedo de costado para recorrer el tablón.',
      'Slide your finger sideways to move along the board.',
      'Tocá una hoja para leerla de cerca, y otra vez para devolverla. Las '
          'nuevas llevan una marca hasta que las leés.',
      'Tap a sheet to read it up close, and again to put it back. New ones '
          'carry a mark until you read them.',
    ),
    hoja(
      'Vos también podés clavar tus notas.',
      'You can pin your own notes too.',
      'Con «Clavar una nota», abajo. Para quitar una, abrila y tocá '
          '«Quitarla».',
      'With “Pin a note”, at the bottom. To remove one, open it and tap '
          '“Remove it”.',
    ),
    hoja(
      'Mantené el dedo sobre una hoja para moverla.',
      'Hold your finger on a sheet to move it.',
      'Llevala a otro hueco y soltala. Para volver al pueblo, tocá el cielo o '
          'el pasto.',
      'Carry it to another spot and let go. To go back to the town, tap the '
          'sky or the grass.',
    ),
  ];
}
