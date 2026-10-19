import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../l10n/lang.dart';
import '../model/cadence.dart';
import '../model/habit.dart';
import 'sheet_glass.dart';
import 'style.dart';

/// El aviso antes de la pregunta: «contanos más de tu hábito».
///
/// La pregunta de la primera semana salía sola, de golpe, al abrir la app, y
/// una hoja que sube sin que nadie la pida se cierra sin leer. Así que antes
/// se avisa, en el medio y en pequeño, y se puede decir que ahora no: entonces
/// se vuelve a avisar al día siguiente. Devuelve `true` si se quiere seguir.
class CadenceIntro extends StatelessWidget {
  const CadenceIntro({super.key, required this.habit, required this.theme});

  final Habit habit;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final velo = SheetInk.of(t);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SheetGlass(
            velo: velo,
            radius: 26,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  habit.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(
                    color: velo.tenue,
                    shadows: velo.aliento,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tr('Contanos más de tu hábito', 'Tell us more about it'),
                  textAlign: TextAlign.center,
                  style: t.title.copyWith(
                    color: velo.cuerpo,
                    shadows: velo.aliento,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'Ya pasó una semana. Con una pregunta, el pueblo entiende '
                        'tu ritmo y no se preocupa de más.',
                    'A week has gone by. One question, and the town learns '
                        'your rhythm and stops worrying for nothing.',
                  ),
                  textAlign: TextAlign.center,
                  style: t.bodySoft.copyWith(
                    fontSize: 13,
                    height: 1.4,
                    color: velo.suave,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: velo.suave,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () {
                          Sensory.instance.tick();
                          Navigator.of(context).pop(false);
                        },
                        child: Text(tr('Ahora no', 'Not now')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SheetAccent(
                        theme: t,
                        text: tr('Continuar', 'Continue'),
                        onTap: () {
                          Sensory.instance.tick();
                          Navigator.of(context).pop(true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cada cuánto va esto.
///
/// No se pregunta al fundar. El primer día la respuesta es un deseo —todo el
/// mundo va a leer todos los días el día que empieza a leer— y lo que se
/// escribe entonces se convierte en la vara con la que se mide todo lo demás.
/// A la semana ya hay algo que enseñar, así que se enseña primero y se
/// pregunta después: «en siete días pusiste cuatro piezas».
///
/// **Cinco maneras, no siete números.** Antes eran siete botones —de «todos
/// los días» a «una vez por semana»— que decían casi lo mismo y nada más:
/// ni cada dos días ni cada dos semanas. Ahora son las maneras distintas de
/// llevar un hábito, una por renglón, y los días sueltos de la semana se
/// eligen dentro del suyo.
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

  /// Lo elegido, en veces por semana: uno de [cadenceChoices].
  final ValueChanged<double> onPick;

  /// La pregunta del pueblo, o la misma hoja abierta a mano desde la hoja del
  /// hábito. La segunda no cuenta lo hecho: ya se contestó una vez.
  final bool first;

  @override
  State<CadenceSheet> createState() => _CadenceSheetState();
}

/// Los renglones, cada uno una manera de llevar un hábito.
enum _Way { daily, someDays, everyOther, weekly, fortnightly }

class _CadenceSheetState extends State<CadenceSheet> {
  late double _pick =
      widget.habit.perWeek ?? nearestCadence(observedRate(widget.habit) ?? 7);

  /// Cuántos días, si es de algunos días por semana. Se recuerda aunque se
  /// marque otro renglón, para que volver no lo pierda.
  late int _some = switch (_pick) {
    >= 2 && <= 6 when _pick != everyOtherDay => _pick.round(),
    _ => (observedRate(widget.habit) ?? 3).round().clamp(2, 6),
  };

  _Way get _way => switch (_pick) {
    >= 7 => _Way.daily,
    everyOtherDay => _Way.everyOther,
    1 => _Way.weekly,
    everyOtherWeek => _Way.fortnightly,
    _ => _Way.someDays,
  };

  void _choose(double v) {
    Sensory.instance.tick();
    setState(() => _pick = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final h = widget.habit;
    final velo = SheetInk.of(t);
    final (piezas, dias) = sinceStartOf(h);
    final pz = piezas == 1 ? tr('pieza', 'piece') : tr('piezas', 'pieces');
    final ds = dias == 1 ? tr('día', 'day') : tr('días', 'days');
    return SheetGlass(
      velo: velo,
      radius: 28,
      bottom: false,
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        18 + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Text(
              widget.first
                  ? tr('TU RITMO', 'YOUR RHYTHM')
                  : tr('CADA CUÁNTO', 'HOW OFTEN'),
              style: t.label.copyWith(color: velo.tenue),
            ),
            const SizedBox(height: 10),
            Text(
              widget.first
                  ? tr(
                      'En $dias $ds pusiste $piezas $pz.',
                      'In $dias $ds you placed $piezas $pz.',
                    )
                  : tr(
                      '¿Cada cuánto va ${h.name}?',
                      'How often does ${h.name} happen?',
                    ),
              style: t.title.copyWith(color: velo.cuerpo),
            ),
            const SizedBox(height: 6),
            Text(
              widget.first
                  ? tr(
                      '¿Cada cuánto va ${h.name}? Viene marcado lo que se ve.',
                      'How often does ${h.name} happen? What it looks like '
                          'so far is already marked.',
                    )
                  : tr(
                      'No es una meta. Es para que el pueblo sepa cuándo un '
                          'hueco es un hueco.',
                      "It isn't a goal. It's so the town knows when a gap is "
                          'really a gap.',
                    ),
              style: t.bodySoft.copyWith(
                fontSize: 12.5,
                height: 1.4,
                color: velo.suave,
              ),
            ),
            const SizedBox(height: 14),
            SheetChoice(
              theme: t,
              velo: velo,
              on: _way == _Way.daily,
              title: tr('Todos los días', 'Every day'),
              hint: tr(
                'Un día sin pieza ya es un hueco.',
                'A day without a piece is already a gap.',
              ),
              onTap: () => _choose(7),
            ),
            SheetChoice(
              theme: t,
              velo: velo,
              on: _way == _Way.someDays,
              title: tr('Algunos días por semana', 'Some days a week'),
              hint: tr(
                'Los que toquen, sin día fijo.',
                'Whichever days fit, no set day.',
              ),
              trailing: _Count(
                theme: t,
                velo: velo,
                value: _some,
                lit: _way == _Way.someDays,
                onPick: (n) {
                  _some = n;
                  _choose(n.toDouble());
                },
              ),
              onTap: () => _choose(_some.toDouble()),
            ),
            SheetChoice(
              theme: t,
              velo: velo,
              on: _way == _Way.everyOther,
              title: tr('Cada dos días', 'Every other day'),
              hint: tr('Un día sí y otro no.', 'One day on, one day off.'),
              onTap: () => _choose(everyOtherDay),
            ),
            SheetChoice(
              theme: t,
              velo: velo,
              on: _way == _Way.weekly,
              title: tr('Una vez por semana', 'Once a week'),
              hint: tr(
                'Un día fijo, o el que se pueda.',
                'A set day, or whichever one works.',
              ),
              onTap: () => _choose(1),
            ),
            SheetChoice(
              theme: t,
              velo: velo,
              on: _way == _Way.fortnightly,
              title: tr('Cada dos semanas', 'Every other week'),
              hint: tr(
                'De vez en cuando, pero sin perderlo.',
                'Now and then, without letting it go.',
              ),
              onTap: () => _choose(everyOtherWeek),
            ),
            const SizedBox(height: 16),
            SheetAccent(
              theme: t,
              text: tr(
                'Es ${cadenceSaid(_pick)}',
                "It's ${cadenceSaid(_pick)}",
              ),
              onTap: () {
                Sensory.instance.tick();
                Navigator.of(context).pop();
                widget.onPick(_pick);
              },
            ),
            if (widget.first) ...[
              const SizedBox(height: 10),
              Text(
                tr(
                  'Se cambia cuando quieras en la hoja del hábito.',
                  "You can change it whenever you like in the habit's sheet.",
                ),
                textAlign: TextAlign.center,
                style: t.bodySoft.copyWith(
                  fontSize: 11.5,
                  height: 1.4,
                  color: velo.tenue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cuántos días, dentro del renglón de algunos días por semana: un número
/// con su flecha, y tocarlo despliega del dos al seis.
class _Count extends StatelessWidget {
  const _Count({
    required this.theme,
    required this.velo,
    required this.value,
    required this.lit,
    required this.onPick,
  });

  final UiTheme theme;
  final SheetInk velo;
  final int value;
  final bool lit;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return PopupMenuButton<int>(
      tooltip: '',
      initialValue: value,
      onSelected: onPick,
      position: PopupMenuPosition.under,
      color: Color.lerp(velo.tinte, Colors.black, 0.25),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: velo.canto),
      ),
      itemBuilder: (_) => [
        for (final n in someDaysAWeek)
          PopupMenuItem<int>(
            value: n,
            height: 40,
            child: Text(
              tr('$n por semana', '$n a week'),
              style: t.body.copyWith(
                fontSize: 14,
                color: n == value ? t.accent : velo.cuerpo,
                fontWeight: n == value ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        decoration: BoxDecoration(
          color: velo.tinte.withValues(alpha: lit ? 0.55 : 0.30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('$value', '$value'),
              style: t.body.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: lit ? t.accent : velo.cuerpo,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: lit ? t.accent : velo.suave,
            ),
          ],
        ),
      ),
    );
  }
}
