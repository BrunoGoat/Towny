import 'dart:math' as math;

import '../core/rng.dart';
import '../data/gossip.dart';
import '../engine/board_plan.dart';
import '../engine/town.dart';
import 'findings.dart';
import 'habit.dart';
import 'notice.dart';
import 'piece.dart';
import 'rhythm.dart';

/// Lo que hay clavado en el tablón de un pueblo.
///
/// Una sola cuenta para las dos cosas que la necesitan: el tablón de cerca,
/// que las escribe, y el de la plaza, que enseña su silueta. Si fueran dos, el
/// tablón de lejos tendría cuatro papeles y el de cerca seis, y la única
/// manera de enterarse sería acercarse y contar.
///
/// Primero lo que el pueblo sabe de vos, y detrás lo que el pueblo tiene
/// clavado por su cuenta. Nunca al revés: un bando sobre una cabra perdida no
/// puede ser lo primero que se lee de tu propio tablón. Y si de vos no sabe
/// nada todavía, se dice que está vacío y se clavan unos cuantos bandos más,
/// que es lo que tendría un tablón de plaza el primer día.
List<Notice> boardNotices(
  Habit h, {
  List<Habit> valley = const [],
  DateTime? at,
}) {
  final now = at ?? DateTime.now();
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
  // Cuántos bandos toca clavar hoy: entre dos y cuatro, sorteado por la fecha
  // y por el pueblo. Que sea distinto cada día es lo que hace que el tablón
  // tenga días con más vida del pueblo y días con menos.
  final quiere = 2 + hashInt(3, dayKey(dayStart(now)), h.slot, 61);
  // Pero lo que el pueblo sabe de vos va primero y no se recorta nunca: si hay
  // ocho notas de verdad, caben dos bandos y se clavan dos. Un bando sobre una
  // cabra no puede dejar fuera lo que el tablón averiguó.
  // Y delante de todo, lo tuyo. Es tu tablón: lo que clavaste vos no lo puede
  // dejar fuera ni una nota del pueblo ni un bando sobre una cabra.
  //
  // Y el tablón tiene un tope de hojas: si entre lo tuyo y lo que averiguó no
  // caben, lo que se recorta es lo del pueblo, que seguirá ahí mañana. Una
  // nota que clavaste y no aparece es un tablón roto.
  final mias = myNotices(h);
  final vacio = said.isEmpty && mias.isEmpty;
  final paraNotas = math.max(
    0,
    BoardPlan.capacity - mias.length - (vacio ? 1 : 0),
  );
  final suyas = said.take(paraNotas).toList();
  final hueco =
      BoardPlan.capacity - mias.length - suyas.length - (vacio ? 1 : 0);
  final cuantos = quiere.clamp(0, math.max(0, hueco)).toInt();
  return [
    ...mias,
    if (vacio) emptyNotice(h),
    ...suyas,
    ...villageNotices(now, town: h.slot, count: cuantos),
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
  final dias = dayStart(DateTime.now()).difference(dayStart(at)).inDays;
  if (dias <= 0) return 'Clavada hoy.';
  if (dias == 1) return 'Clavada ayer.';
  if (dias < 30) return 'Clavada hace $dias días.';
  final meses = (dias / 30).floor();
  return 'Clavada hace $meses ${meses == 1 ? 'mes' : 'meses'}.';
}

/// La hoja que se clava cuando de vos no se sabe nada.
///
/// Va clavada como cualquier otra porque es lo que sería en la plaza: nadie
/// deja el hueco en blanco, se clava un papel avisando.
Notice emptyNotice(Habit h) {
  final days = daysOf(h).length;
  return Notice(
    NoticeKind.life,
    'El tablón está vacío.',
    days == 0
        ? 'Todavía no hay nada que contar. Poné la primera pieza.'
        : 'Llevás $days ${days == 1 ? 'día' : 'días'}. El pueblo prefiere '
              'callarse a inventar: cuando tenga bastante para estar seguro '
              'de algo, lo escribe acá.',
  );
}
