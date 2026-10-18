import 'package:flutter/material.dart';

import '../l10n/lang.dart';
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
    // Con más de un pueblo, el siguiente pide que se sostengan todos a la
    // vez: se dice cómo va cada uno, y el que falta es el que manda.
    final varios = store.habits.length > 1;
    final siguiente = store.habits.length + 1;
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
            Text(
              tr(
                'EL ${townOrdinal(siguiente).$1.toUpperCase()} PUEBLO',
                'THE ${townOrdinal(siguiente).$2.toUpperCase()} TOWN',
              ),
              style: t.label,
            ),
            const SizedBox(height: 10),
            if (varios) ...[
              Text(
                tr(
                  'Se abre cuando sostenés los ${store.habits.length} que tenés '
                      'a la vez, cada uno a su ritmo.',
                  'It opens when you keep up all ${store.habits.length} you have '
                      'at once, each at its own pace.',
                ),
                style: t.title,
              ),
              const SizedBox(height: 14),
              for (final (h, g) in store.unlockGoals) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        h.name,
                        style: t.body.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      g.met
                          ? tr('se sostiene', 'holding')
                          : (g.need - g.have <= 1
                                ? tr('falta 1 día', '1 day left')
                                : tr(
                                    'faltan ${g.need - g.have} días',
                                    '${g.need - g.have} days left',
                                  )),
                      style: t.bodySoft.copyWith(
                        fontSize: 12.5,
                        color: g.met ? t.accent : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _days(t, g.have, g.need),
                const SizedBox(height: 12),
              ],
            ] else ...[
              Text(
                left <= 1
                    ? tr(
                        'Te falta un día con pieza.',
                        'You need one more day with a piece.',
                      )
                    : tr(
                        'Te faltan $left días con pieza.',
                        'You need $left more days with a piece.',
                      ),
                style: t.title,
              ),
              const SizedBox(height: 6),
              Text(
                _rule(goal),
                style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              _days(t, done, goal.need),
            ],
            const SizedBox(height: 16),
            Text(
              // Lo importante de estas dos frases es que la segunda desarma la
              // primera: un candado que además castigue los fallos sería
              // exactamente la racha que esta app quitó de todas partes.
              tr(
                'No hace falta que sean seguidos. Podés fallar '
                    '${falla == 1 ? 'una vez' : '$falla veces'} por el camino y '
                    'la puerta se abre igual — acá no se miden rachas.',
                "They don't have to be in a row. You can miss "
                    '${falla == 1 ? 'once' : '$falla times'} along the way and '
                    "the door still opens — streaks aren't counted here.",
              ),
              style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.4),
            ),
            // Sin frecuencia dicha se mide como de todos los días, y quien va
            // dos veces por semana tiene que saber que eso se cambia.
            if (!goal.declared) ...[
              const SizedBox(height: 10),
              Text(
                tr(
                  '¿No es de todos los días? Decí cada cuánto va en la hoja del '
                      'hábito, y la cuenta se hace con eso.',
                  "Not an everyday habit? Say how often it goes in the habit's "
                      'sheet, and the count uses that.',
                ),
                style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              tr(
                'Y un pueblo ganado no se pierde nunca, pase lo que pase después.',
                'And a town once earned is never lost, whatever happens afterwards.',
              ),
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
    final intro = tr(
      'El valle abre su segundo solar cuando el primero se sostiene: ',
      'The valley opens its second plot when the first one holds: ',
    );
    if (g.perWeek >= 7) {
      return tr(
        '$intro${g.need} días con pieza de los últimos ${g.window}. '
            'Llevás ${g.have}.',
        '$intro${g.need} days with a piece out of the last ${g.window}. '
            'You have ${g.have}.',
      );
    }
    final semanas = g.window ~/ 7;
    return tr(
      '$intro${g.need} días con pieza en las últimas $semanas semanas, '
          'sin contar más de ${g.cap} por semana, porque dijiste que va '
          '${cadenceSaid(g.perWeek)}. Llevás ${g.have}.',
      '$intro${g.need} days with a piece in the last $semanas weeks, '
          'counting no more than ${g.cap} a week, because you said it '
          'goes ${cadenceSaid(g.perWeek)}. You have ${g.have}.',
    );
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

/// Cómo se dice el pueblo número [n] —el segundo, el tercero—, en castellano
/// delante de un nombre («tercer pueblo») y en inglés.
(String, String) townOrdinal(int n) => switch (n) {
  2 => ('segundo', 'second'),
  3 => ('tercer', 'third'),
  4 => ('cuarto', 'fourth'),
  5 => ('quinto', 'fifth'),
  6 => ('sexto', 'sixth'),
  _ => ('siguiente', 'next'),
};
