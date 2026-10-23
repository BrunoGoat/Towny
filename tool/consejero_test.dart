import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/advice.dart';
import 'package:towny/l10n/lang.dart';

/// Todo lo que dice el consejero, en castellano y numerado, para revisarlo
/// de una sentada:
///
///   flutter test tool/consejero_test.dart --dart-define=OUT=CONSEJERO.md
void main() {
  test('el consejero, en limpio', () {
    lang = Lang.es;
    const out = String.fromEnvironment('OUT', defaultValue: 'CONSEJERO.md');
    final b = StringBuffer('# Lo que dice el consejero\n\n');
    final siembra = pathFor(AdviceGoal.start);
    final arranca = pathFor(AdviceGoal.quit);
    var n = 0;
    b.writeln('## Los de todos los días\n');
    b.writeln(
      'Entre corchetes, para quién es y en qué lugar le llega: '
      '**E** a quien empieza un hábito, **D** a quien deja uno.\n',
    );
    final orden = [
      ...siembra,
      for (final id in arranca)
        if (!siembra.contains(id)) id,
    ];
    for (final id in orden) {
      final a = adviceById[id]!;
      final donde = [
        if (siembra.contains(id)) 'E${siembra.indexOf(id) + 1}',
        if (arranca.contains(id)) 'D${arranca.indexOf(id) + 1}',
      ].join(' · ');
      b.writeln('**${++n}.** «${a.sayEs}» [$donde]  ');
      b.writeln('${a.meanEs}\n');
    }
    final sueltos = dailyAdvice.where((a) => !orden.contains(a.id));
    if (sueltos.isNotEmpty) {
      b.writeln('### Escritos pero en ningún camino\n');
      for (final a in sueltos) {
        b.writeln('**${++n}.** «${a.sayEs}»  ');
        b.writeln('${a.meanEs}\n');
      }
    }
    b.writeln('## Los que llegan cuando pasa algo\n');
    for (final a in eventAdvice) {
      final quien = switch (a.goal) {
        AdviceGoal.start => ' · sólo a quien empieza',
        AdviceGoal.quit => ' · sólo a quien deja',
        null => '',
      };
      b.writeln('**${++n}.** «${a.sayEs}» [${_cuando[a.event]}$quien]  ');
      b.writeln('${a.meanEs}\n');
    }
    b.writeln('## Lo que dice fuera de los consejos\n');
    for (final (que, dice) in [
      for (final l in SageLines.intro) ('Al presentarse', l),
      ('La pregunta, en el primer pueblo', SageLines.question),
      ('La pregunta, en un pueblo nuevo', SageLines.questionAgain),
      ('Respuesta 1', SageLines.answerStart),
      ('Respuesta 2', SageLines.answerQuit),
      ('Si elegís empezar', SageLines.afterStart),
      ('Si elegís dejar', SageLines.afterQuit),
      ('Cuando ya dijo lo de hoy', SageLines.nothingNew),
      ('Antes de dar uno', SageLines.ready),
      ('Antes de dar otro más', SageLines.readyOther),
      ('Botón sí', SageLines.yes),
      ('Botón no', SageLines.notNow),
      ('Si le decís que todavía no', SageLines.notYet),
    ]) {
      b.writeln('**${++n}.** $que: «$dice»\n');
    }
    File(out).writeAsStringSync(b.toString());
  });
}

const _cuando = {
  AdviceEvent.firstPiece: 'la primera pieza',
  AdviceEvent.secondTown: 'al fundar el segundo pueblo',
  AdviceEvent.thirdTown: 'al fundar el tercero',
  AdviceEvent.week: 'siete días con pieza',
  AdviceEvent.month: 'treinta días con pieza',
  AdviceEvent.missedDay: 'un día sin pieza',
  AdviceEvent.comeback: 'al volver tras tres días o más',
  AdviceEvent.plan: 'al escribir hora o lugar en el tablón',
  AdviceEvent.ownNote: 'al clavar una nota tuya',
  AdviceEvent.rested: 'al poner a dormir el pueblo',
  AdviceEvent.hundred: 'cien piezas',
};
