import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../l10n/lang.dart';
import '../model/cadence.dart';
import '../model/habit.dart';
import 'style.dart';

/// La primera semana: cada cuánto va esto.
///
/// No se pregunta al fundar. El primer día la respuesta es un deseo —todo el
/// mundo va a leer todos los días el día que empieza a leer— y lo que se
/// escribe entonces se convierte en la vara con la que se mide todo lo demás.
/// A la semana ya hay algo que enseñar, así que se enseña primero y se
/// pregunta después: «pusiste nueve piezas en cinco días».
///
/// Viene marcada con lo que se ve, y contestar es un toque. No es una meta ni
/// se enseña como una: sirve para que el pueblo no confunda un hábito de los
/// domingos con uno diario que se está dejando.
class CadenceSheet extends StatefulWidget {
  const CadenceSheet({
    super.key,
    required this.habit,
    required this.theme,
    required this.onPick,
    this.first = true,
  });

  final Habit habit;
  final UiTheme theme;

  /// Lo elegido, de 1 a 7.
  final ValueChanged<int> onPick;

  /// La pregunta de la primera semana, o la misma hoja abierta a mano desde la
  /// hoja del hábito. La segunda no cuenta la semana: ya no es la primera.
  final bool first;

  @override
  State<CadenceSheet> createState() => _CadenceSheetState();
}

class _CadenceSheetState extends State<CadenceSheet> {
  late int _pick = widget.habit.perWeek ?? observedPerWeek(widget.habit) ?? 7;

  static const _choices = [7, 6, 5, 4, 3, 2, 1];

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final h = widget.habit;
    final (piezas, dias) = lastWeekOf(h);
    return Frosted(
      theme: t,
      strong: true,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
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
              widget.first
                  ? tr('LA PRIMERA SEMANA', 'THE FIRST WEEK')
                  : tr('CADA CUÁNTO', 'HOW OFTEN'),
              style: t.label,
            ),
            const SizedBox(height: 10),
            Text(
              widget.first
                  ? tr(
                      'Esta semana pusiste $piezas '
                          '${piezas == 1 ? 'pieza' : 'piezas'} en $dias '
                          '${dias == 1 ? 'día' : 'días'}.',
                      'This week you placed $piezas '
                          '${piezas == 1 ? 'piece' : 'pieces'} on $dias '
                          '${dias == 1 ? 'day' : 'days'}.',
                    )
                  : tr(
                      '¿Cada cuánto va ${h.name}?',
                      'How often does ${h.name} happen?',
                    ),
              style: t.title,
            ),
            const SizedBox(height: 6),
            Text(
              widget.first
                  ? tr(
                      '¿${h.name} es de todos los días, o de algunos días por '
                          'semana? Viene marcado lo que se ve.',
                      'Is ${h.name} an everyday thing, or a few days a week? '
                          'What it looks like so far is already marked.',
                    )
                  : tr(
                      'No es una meta. Es para que el pueblo sepa cuándo un '
                          'hueco es un hueco.',
                      "It isn't a goal. It's so the town knows when a gap is "
                          'really a gap.',
                    ),
              style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in _choices)
                  _Chip(
                    theme: t,
                    text: n == 7
                        ? tr('Todos los días', 'Every day')
                        : tr('$n por semana', '$n a week'),
                    chosen: n == _pick,
                    onTap: () {
                      Sensory.instance.tick();
                      setState(() => _pick = n);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent.withValues(alpha: 0.85),
                  foregroundColor: t.dark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Sensory.instance.tick();
                  Navigator.of(context).pop();
                  widget.onPick(_pick);
                },
                child: Text(
                  tr('Es ${cadenceSaid(_pick)}', "It's ${cadenceSaid(_pick)}"),
                ),
              ),
            ),
            if (widget.first) ...[
              const SizedBox(height: 10),
              Text(
                tr(
                  'Se cambia cuando quieras en la hoja del hábito.',
                  "You can change it whenever you like in the habit's sheet.",
                ),
                textAlign: TextAlign.center,
                style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.theme,
    required this.text,
    required this.chosen,
    required this.onTap,
  });

  final UiTheme theme;
  final String text;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: chosen
              ? t.accent.withValues(alpha: 0.18)
              : t.fg.withValues(alpha: 0.04),
          border: Border.all(
            color: chosen ? t.accent.withValues(alpha: 0.8) : t.stroke,
            width: chosen ? 1.4 : 1,
          ),
        ),
        child: Text(
          text,
          style: t.body.copyWith(
            fontSize: 13,
            color: chosen ? t.accent : t.fg,
            fontWeight: chosen ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
