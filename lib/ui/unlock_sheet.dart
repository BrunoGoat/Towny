import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../l10n/lang.dart';
import '../model/cadence.dart';
import '../model/piece.dart';
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
class UnlockSheet extends StatefulWidget {
  const UnlockSheet({super.key, required this.store, required this.theme});

  final Store store;
  final UiTheme theme;

  @override
  State<UnlockSheet> createState() => _UnlockSheetState();

  /// Cómo va un pueblo: lo que lleva, en por ciento. Dormido, y que duerme.
  static String _state(UnlockGoal g) => g.resting
      ? tr('${g.percent}% · en pausa', '${g.percent}% · resting')
      : '${g.percent}%';

  /// El color de dormir: blanco de luna, el mismo para la marca y la cuenta.
  /// Blanco y no azul: de noche el acento de la app es azul, y un pueblo que
  /// llegó no se distinguía de uno dormido.
  static const Color _luna = Color(0xFFEEF1F7);
}

class _UnlockSheetState extends State<UnlockSheet> {
  /// El hábito abierto, por su posición: uno solo a la vez. Con un único
  /// pueblo, abierto de entrada: no hay otro que mirar.
  late int? _open = widget.store.habits.length == 1 ? 0 : null;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final t = widget.theme;
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
            for (final (i, (h, g)) in store.unlockGoals.indexed)
              _HabitLine(
                name: h.name,
                goal: g,
                theme: t,
                velo: velo,
                small: chico,
                open: _open == i,
                // Abrir uno cierra el que estaba abierto.
                onTap: () {
                  Sensory.instance.tick();
                  setState(() => _open = _open == i ? null : i);
                },
              ),
            // Lo único que hace falta saber, y nada más: qué cuenta, y que no
            // es una racha.
            Text(_rule(varios), style: chico),
            // Si alguno duerme, lo que lo frena es eso: se dice abajo, junto
            // a la regla, con la misma luna que lleva su nombre.
            if (store.unlockGoals.any((e) => e.$2.resting)) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: HabitSigil(
                      symbol: 'moon',
                      color: UnlockSheet._luna,
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      varios
                          ? tr(
                              'Y todos tienen que estar despiertos.',
                              'And all of them have to be awake.',
                            )
                          : tr(
                              'Y tiene que estar despierto.',
                              'And it has to be awake.',
                            ),
                      style: chico.copyWith(color: UnlockSheet._luna),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Qué hace falta: el setenta por ciento de su ritmo, y los días mínimos
  /// que pide su barra. Cuántos son, lo dice cada barra.
  static String _rule(bool varios) {
    final meta = UnlockGoal.goalPercent;
    return varios
        ? tr(
            'Mantené cada hábito al $meta% de su ritmo. Cuando completes los '
                'días mínimos de sus barras, se abre el siguiente pueblo.',
            'Keep each habit at $meta% of its pace. Once you complete the '
                'minimum days of their bars, the next town opens.',
          )
        : tr(
            'Mantené tu hábito al $meta% de su ritmo. Cuando completes los '
                'días mínimos de su barra, se abre el siguiente pueblo.',
            'Keep your habit at $meta% of its pace. Once you complete the '
                'minimum days of its bar, the next town opens.',
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
  ///
  /// La barra entera es el ritmo entero —todos los días que pide, el cien por
  /// cien— y la meta es una raya que la cruza en el setenta: se ve cuánto
  /// falta para pasarla sin leer ningún número.
  static Widget _days(UiTheme t, SheetInk velo, UnlockGoal g) {
    final total = g.expected;
    const gap = 4.0;
    return LayoutBuilder(
      builder: (context, c) {
        final celda = (c.maxWidth + gap) / total;
        return SizedBox(
          height: 20,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: 5,
                bottom: 5,
                child: Row(
                  children: [
                    for (var i = 0; i < total; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: i == total - 1 ? 0 : gap,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: i < g.have
                                  ? (g.resting ? UnlockSheet._luna : t.accent)
                                        .withValues(
                                          alpha: g.met || g.resting
                                              ? 0.85
                                              : 0.45,
                                        )
                                  : (g.resting
                                            ? UnlockSheet._luna
                                            : velo.cuerpo)
                                        .withValues(
                                          alpha: g.resting ? 0.18 : 0.14,
                                        ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // La meta: en el hueco entre la última casilla que hace falta
              // y la siguiente.
              if (g.need < total)
                Positioned(
                  left: celda * g.need - gap / 2 - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: g.met
                          ? t.accent
                          : velo.cuerpo.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
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

/// Un hábito en el candado: su nombre, cómo va y su barra. Tocándolo se
/// abre el detalle —los días que mira la cuenta, uno por uno, y cuánto
/// falta—, y tocándolo otra vez se cierra.
class _HabitLine extends StatelessWidget {
  const _HabitLine({
    required this.name,
    required this.goal,
    required this.theme,
    required this.velo,
    required this.small,
    required this.open,
    required this.onTap,
  });

  final String name;
  final UnlockGoal goal;
  final UiTheme theme;
  final SheetInk velo;
  final TextStyle small;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final g = goal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (g.resting) ...[
                  const HabitSigil(
                    symbol: 'moon',
                    color: UnlockSheet._luna,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    name,
                    style: t.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: velo.cuerpo,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  UnlockSheet._state(g),
                  style: small.copyWith(
                    fontWeight: g.met ? FontWeight.w700 : FontWeight.w500,
                    color: g.resting
                        ? UnlockSheet._luna
                        : (g.met ? t.accent : velo.tenue),
                  ),
                ),
                const SizedBox(width: 2),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: velo.tenue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _UnlockSheetState._days(t, velo, g),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: open
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _Detail(goal: g, theme: t, velo: velo),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// El detalle de un hábito: los días que mira la cuenta, por semanas, y tres
/// números — lo hecho, la meta y lo que falta.
///
/// Un día con pieza que cuenta va lleno; uno con pieza que no suma porque esa
/// semana ya iba por encima de su ritmo, sólo con borde; uno sin pieza,
/// apagado; y uno en pausa lleva la luna: pegada a su día se entiende sola.
class _Detail extends StatelessWidget {
  const _Detail({required this.goal, required this.theme, required this.velo});

  final UnlockGoal goal;
  final UiTheme theme;
  final SheetInk velo;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final g = goal;
    final hoy = g.calendar.isEmpty ? null : g.calendar.last.$1;
    // Por semanas de lunes a domingo: las casillas antes del primer día y
    // después de hoy quedan vacías.
    final celdas = <(DateTime, DayMark)?>[
      if (g.calendar.isNotEmpty)
        for (var i = 1; i < g.calendar.first.$1.weekday; i++) null,
      ...g.calendar,
    ];
    while (celdas.length % 7 != 0) {
      celdas.add(null);
    }
    final dias = inEnglish
        ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : const ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final rotulo = t.label.copyWith(
      color: velo.tenue,
      fontSize: 8.5,
      letterSpacing: 1.2,
    );

    Widget celda((DateTime, DayMark)? c) {
      if (c == null) return const SizedBox.shrink();
      final (dia, marca) = c;
      final esHoy = hoy != null && dayKey(dia) == dayKey(hoy);
      final acento = g.resting ? UnlockSheet._luna : t.accent;
      return Container(
        decoration: BoxDecoration(
          color: switch (marca) {
            DayMark.counted => acento.withValues(alpha: 0.85),
            DayMark.missed => velo.cuerpo.withValues(alpha: 0.10),
            DayMark.extra || DayMark.asleep || DayMark.unborn => null,
          },
          border: marca == DayMark.extra
              ? Border.all(color: acento.withValues(alpha: 0.85), width: 1.5)
              : esHoy
              ? Border.all(color: velo.cuerpo.withValues(alpha: 0.55))
              : null,
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.center,
        child: marca == DayMark.asleep
            ? const HabitSigil(
                symbol: 'moon',
                color: UnlockSheet._luna,
                size: 13,
              )
            : null,
      );
    }

    Widget numero(int n, String es, String en, {Color? color}) => Expanded(
      child: Column(
        children: [
          Text(
            '$n',
            style: t.title.copyWith(
              color: color ?? velo.cuerpo,
              fontSize: 16,
              height: 1.1,
            ),
          ),
          Text(tr(es, en), style: rotulo),
        ],
      ),
    );

    final faltan = math.max(0, g.need - g.have);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Contra qué ritmo se mide este. Sin elegir, todos los días: y es
        // acá, en el suyo, donde se dice dónde se cambia.
        Text(
          g.declared
              ? tr(
                  'Ritmo: ${cadenceSaid(g.perWeek)}',
                  'Pace: ${cadenceSaid(g.perWeek)}',
                )
              : tr(
                  'Ritmo: todos los días · cambialo en la hoja del hábito',
                  "Pace: every day · change it in the habit's sheet",
                ),
          style: t.bodySoft.copyWith(fontSize: 12, color: velo.suave),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final d in dias)
              Expanded(
                child: Center(child: Text(d, style: rotulo)),
              ),
          ],
        ),
        const SizedBox(height: 2),
        for (var f = 0; f < celdas.length; f += 7)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                for (var i = f; i < f + 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: AspectRatio(
                        aspectRatio: 3.4,
                        child: celda(celdas[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            numero(g.have, 'HECHOS', 'DONE'),
            numero(g.need, 'META', 'GOAL'),
            numero(
              faltan,
              'FALTAN',
              'TO GO',
              color: faltan == 0 ? t.accent : null,
            ),
          ],
        ),
      ],
    );
  }
}
