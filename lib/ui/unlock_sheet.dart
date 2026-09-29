import 'package:flutter/material.dart';

import '../model/cadence.dart';
import '../model/store.dart';
import 'style.dart';

/// Lo que hay detrás del candado, y cuánto falta.
///
/// El valle empieza con un solo pueblo. No es una limitación técnica ni una
/// versión de pago: es que sobreestimar cuánto cambio se puede sostener es lo
/// que hace casi todo el mundo el primer día. Cuando hay ganas es facilísimo
/// pensar «ahora sí» y querer arreglar diez cosas a la vez, y ninguna de esas
/// diez es mala idea — lo que pasa es que cada una cuesta un poco de atención,
/// de decisión y de seguimiento, y esa cuenta se paga toda junta la primera
/// semana mala.
///
/// Un valle que se abre solo es una lista de deseos. Uno que se abre cuando lo
/// anterior se sostiene dice otra cosa, y es la cosa que hay que decir:
/// primero aprendí a mantener una, ahora estoy listo para otra.
class UnlockSheet extends StatelessWidget {
  const UnlockSheet({super.key, required this.store, required this.theme});

  final Store store;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final goal = store.unlockGoal;
    final done = goal.have;
    final left = goal.need - done;
    final falla = goal.slack;
    return Frosted(
      theme: t,
      strong: true,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: t.fg.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('EL SEGUNDO PUEBLO', style: t.label),
            const SizedBox(height: 10),
            Text(
              left <= 1
                  ? 'Te falta un día con pieza.'
                  : 'Te faltan $left días con pieza.',
              style: t.title,
            ),
            const SizedBox(height: 6),
            Text(
              _rule(goal),
              style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            _days(t, done, goal.need),
            const SizedBox(height: 16),
            Text(
              // Lo importante de estas dos frases es que la segunda desarma la
              // primera: un candado que además castigue los fallos sería
              // exactamente la racha que esta app quitó de todas partes.
              'No hace falta que sean seguidos. Podés fallar '
              '${falla == 1 ? 'una vez' : '$falla veces'} por el camino y la '
              'puerta se abre igual — acá no se miden rachas.',
              style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.4),
            ),
            // Sin frecuencia dicha se mide como de todos los días, y quien va
            // dos veces por semana tiene que saber que eso se cambia.
            if (!goal.declared) ...[
              const SizedBox(height: 10),
              Text(
                '¿No es de todos los días? Decí cada cuánto va en la hoja del '
                'hábito, y la cuenta se hace con eso.',
                style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Y una vez abierta no se cierra nunca, pase lo que pase después.',
              style: t.bodySoft.copyWith(
                fontSize: 12.5,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lo que pide el valle, dicho contra el ritmo del hábito.
  ///
  /// Para quien va a diario es la frase de siempre. Para los demás se dice el
  /// ritmo primero, porque la cifra sola —«tres días en cuatro semanas»— sin
  /// él parece un error de la app.
  static String _rule(UnlockGoal g) {
    const intro =
        'El valle abre su segundo solar cuando el primero se sostiene: ';
    if (g.perWeek >= 7) {
      return '$intro${g.need} días con pieza de los últimos ${g.window}. '
          'Llevás ${g.have}.';
    }
    final semanas = g.window ~/ 7;
    return '$intro${g.need} días con pieza en las últimas $semanas semanas, '
        'sin contar más de ${g.perWeek} por semana, porque dijiste que va '
        '${cadenceSaid(g.perWeek)}. Llevás ${g.have}.';
  }

  /// Los días que hacen falta, uno por casilla, con los ganados encendidos.
  ///
  /// Dibujado y no dicho: «6 de 10» es un dato y esto es una cuenta atrás que
  /// se ve llenarse, que es lo que hace que se quiera volver a mirar mañana.
  Widget _days(UiTheme t, int done, int need) => Row(
    children: [
      for (var i = 0; i < need; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: i < done
                    ? t.accent.withValues(alpha: 0.8)
                    : t.fg.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
    ],
  );
}
