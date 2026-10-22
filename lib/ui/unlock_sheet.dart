import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../model/cadence.dart';
import '../model/store.dart';
import 'habit_sigil.dart';
import 'sheet_glass.dart';
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
    final velo = SheetInk.of(t);
    final goal = store.unlockGoal;
    final left = goal.need - goal.have;
    // Con más de un pueblo, el siguiente pide que se sostengan todos a la
    // vez: se dice cómo va cada uno, y el que falta es el que manda.
    final varios = store.habits.length > 1;
    final siguiente = store.habits.length + 1;
    final chico = t.bodySoft.copyWith(
      fontSize: 12.5,
      height: 1.4,
      color: velo.suave,
    );
    return SheetGlass(
      velo: velo,
      radius: 28,
      bottom: false,
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        22 + MediaQuery.of(context).padding.bottom,
      ),
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
                  color: velo.cuerpo.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: t.accent),
                const SizedBox(width: 8),
                Text(
                  tr(
                    'EL ${townOrdinal(siguiente).$1.toUpperCase()} PUEBLO',
                    'THE ${townOrdinal(siguiente).$2.toUpperCase()} TOWN',
                  ),
                  style: t.label.copyWith(color: velo.tenue),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (varios) ...[
              Text(
                tr(
                  'Sostené los ${store.habits.length} a la vez.',
                  'Keep up all ${store.habits.length} at once.',
                ),
                style: t.title.copyWith(color: velo.cuerpo),
              ),
              const SizedBox(height: 16),
              for (final (h, g) in store.unlockGoals) ...[
                Row(
                  children: [
                    if (g.resting) ...[
                      const HabitSigil(symbol: 'moon', color: _luna, size: 15),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        h.name,
                        style: t.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: velo.cuerpo,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _state(g),
                      style: chico.copyWith(
                        color: g.resting
                            ? _luna
                            : (g.met ? t.accent : velo.suave),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _days(t, velo, g),
                const SizedBox(height: 14),
              ],
            ] else ...[
              Text(
                goal.resting
                    ? tr('Tu pueblo está en pausa.', 'Your town is resting.')
                    : left <= 1
                    ? tr(
                        'Te falta un día con pieza.',
                        'You need one more day with a piece.',
                      )
                    : tr(
                        'Te faltan $left días con pieza.',
                        'You need $left more days with a piece.',
                      ),
                style: t.title.copyWith(color: velo.cuerpo),
              ),
              const SizedBox(height: 16),
              _days(t, velo, goal),
              const SizedBox(height: 14),
            ],
            // Lo único que hace falta saber, y nada más: qué cuenta, y que no
            // es una racha.
            Text(_rule(goal, varios), style: chico),
            // Sin ritmo dicho se mide como de todos los días: quien va dos
            // veces por semana tiene que saber dónde se cambia.
            if (store.unlockGoals.any((e) => !e.$2.declared)) ...[
              const SizedBox(height: 6),
              Text(
                tr(
                  '¿No es diario? Cambiá su ritmo en la hoja del hábito.',
                  "Not daily? Change its pace in the habit's sheet.",
                ),
                style: chico,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Cómo va un pueblo, en dos o tres palabras.
  static String _state(UnlockGoal g) {
    if (g.resting) return tr('en pausa', 'resting');
    if (g.met) return tr('listo', 'done');
    final n = g.need - g.have;
    return n <= 1
        ? tr('falta 1 día', '1 day left')
        : tr('faltan $n días', '$n days left');
  }

  /// Qué cuenta, en una línea: los días con pieza, en qué ventana, y que no
  /// hace falta que sean seguidos. Con varios pueblos, cada uno a su ritmo.
  static String _rule(UnlockGoal g, bool varios) {
    if (varios) {
      return tr(
        'Cuentan los días con pieza de cada uno, a su ritmo. No hace falta '
            'que sean seguidos.',
        "Days with a piece count, each at its own pace. They don't have to "
            'be in a row.',
      );
    }
    if (g.perWeek >= 7) {
      return tr(
        '${g.need} días con pieza de los últimos ${g.window}. No hace falta '
            'que sean seguidos.',
        "${g.need} days with a piece out of the last ${g.window}. They don't "
            'have to be in a row.',
      );
    }
    return tr(
      '${g.need} días con pieza en ${g.window ~/ 7} semanas, hasta ${g.cap} '
          'por semana. No hace falta que sean seguidos.',
      "${g.need} days with a piece in ${g.window ~/ 7} weeks, up to ${g.cap} "
          "a week. They don't have to be in a row.",
    );
  }

  /// Los días que hacen falta, uno por casilla, con los ganados encendidos.
  ///
  /// Dibujado y no dicho: «6 de 10» es un dato y esto es una cuenta atrás que
  /// se ve llenarse, que es lo que hace que se quiera volver a mirar mañana.
  ///
  /// Dormido, la cuenta se pone del color de la luna: lo que llevaba sigue
  /// ahí, entero, pero quieto.
  Widget _days(UiTheme t, SheetInk velo, UnlockGoal g) => Row(
    children: [
      for (var i = 0; i < g.need; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: i < g.have
                    ? (g.resting ? _luna : t.accent).withValues(alpha: 0.85)
                    : (g.resting ? _luna : velo.cuerpo).withValues(
                        alpha: g.resting ? 0.18 : 0.14,
                      ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
    ],
  );

  /// El color de dormir: el de la luna, el mismo para la marca y la cuenta.
  static const Color _luna = Color(0xFF9FB8E6);
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
