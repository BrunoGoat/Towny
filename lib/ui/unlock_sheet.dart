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
            Text(
              varios
                  ? tr(
                      'Sostené los ${store.habits.length} a la vez.',
                      'Keep up all ${store.habits.length} at once.',
                    )
                  : goal.resting
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
                      fontWeight: g.met ? FontWeight.w700 : FontWeight.w500,
                      color: g.resting
                          ? _luna
                          : (g.met ? t.accent : velo.tenue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _days(t, velo, g),
              const SizedBox(height: 14),
            ],
            // Lo único que hace falta saber, y nada más: qué cuenta, y que no
            // es una racha.
            Text(_rule(varios), style: chico),
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

  /// Cómo va un pueblo: lo que lleva contra la meta. Dormido, lo mismo y
  /// que duerme.
  static String _state(UnlockGoal g) {
    final meta = UnlockGoal.goalPercent;
    if (g.resting) {
      return tr('${g.percent}% · en pausa', '${g.percent}% · resting');
    }
    return tr('${g.percent}% · meta $meta%', '${g.percent}% · goal $meta%');
  }

  /// Qué hace falta, en una línea: cada hábito al setenta por ciento de su
  /// ritmo. Dice solo que se puede fallar, sin hablar de rachas.
  static String _rule(bool varios) {
    final meta = UnlockGoal.goalPercent;
    return varios
        ? tr(
            'Mantené cada hábito al $meta% del ritmo que le marcaste para '
                'abrir el siguiente pueblo.',
            'Keep each habit at $meta% of the pace you set for it to open '
                'the next town.',
          )
        : tr(
            'Mantené tu hábito al $meta% del ritmo que le marcaste para '
                'abrir el siguiente pueblo.',
            'Keep your habit at $meta% of the pace you set for it to open '
                'the next town.',
          );
  }

  /// Los días que hacen falta, uno por casilla, con los ganados encendidos.
  ///
  /// Dibujado y no dicho: «6 de 10» es un dato y esto es una cuenta atrás que
  /// se ve llenarse, que es lo que hace que se quiera volver a mirar mañana.
  /// Desteñida mientras no llega a la meta, y del color del pueblo al llegar.
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
                    ? (g.resting ? _luna : t.accent).withValues(
                        alpha: g.met || g.resting ? 0.85 : 0.45,
                      )
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
