import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../l10n/dates.dart';
import '../l10n/lang.dart';
import '../model/habit.dart';
import '../model/piece.dart';
import 'sheet_glass.dart';
import 'style.dart';

/// Dormir un pueblo, y hasta cuándo.
///
/// Lo que hace falta para que la app sepa la diferencia entre «no estoy
/// pudiendo con esto ahora» y «ya no quiero que esto forme parte de mi vida»,
/// que son dos decisiones completamente distintas y que casi ninguna app
/// distingue. Un hábito que funcionaba perfecto en enero puede no tener ningún
/// sentido durante un viaje, un mes imposible o una mudanza; si las únicas dos
/// opciones son seguir o fallar, la app convierte circunstancias normales en
/// fracaso y acaba siendo una fuente de culpa.
///
/// Siempre con fecha de vuelta, nunca abierta. Una pausa sin final es abandono
/// con mejor nombre, y lo que se estaría guardando entonces sería la excusa y
/// no el plan. Se puede volver antes cuando se quiera —basta poner una pieza—
/// y volver antes no es hacer trampa: es volver.
class RestSheet extends StatefulWidget {
  const RestSheet({
    super.key,
    required this.habit,
    required this.theme,
    required this.onRest,
  });

  final Habit habit;
  final UiTheme theme;
  final void Function(DateTime until) onRest;

  @override
  State<RestSheet> createState() => _RestSheetState();
}

class _RestSheetState extends State<RestSheet> {
  /// Cuántos días, de los de la lista. Ninguno hasta que se toca uno: la hoja
  /// no llega con una respuesta puesta.
  int? _days;

  /// Los tramos que se ofrecen. Una semana porque es lo que dura un viaje
  /// corto; un mes porque es lo que dura una mudanza o un examen; y tres
  /// meses como techo, porque más allá de una estación lo honesto es
  /// preguntarse si esto sigue siendo tu hábito y no si está en pausa.
  static List<(int, String, String)> get _spans => [
    (
      7,
      tr('Una semana', 'One week'),
      tr(
        'un viaje, una gripe, una semana imposible',
        'a trip, the flu, an impossible week',
      ),
    ),
    (14, tr('Dos semanas', 'Two weeks'), tr('unas vacaciones', 'a holiday')),
    (
      30,
      tr('Un mes', 'One month'),
      tr(
        'una mudanza, un examen, un mes de los otros',
        'a move, an exam, one of those months',
      ),
    ),
    (
      90,
      tr('Tres meses', 'Three months'),
      tr('una temporada entera de tu vida', 'a whole season of your life'),
    ),
  ];

  /// El día en que despierta si se elige dormirlo [dias] días.
  static DateTime _wakeOn(int dias) =>
      dayStart(DateTime.now().add(Duration(days: dias + 1)));

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final velo = SheetInk.of(t);
    final dias = _days;
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
            // La luna del rótulo: lo que dice «dormir» sin palabras, en el
            // color del pueblo.
            Row(
              children: [
                Icon(Icons.bedtime_outlined, size: 14, color: t.accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    tr(
                      'DORMIR ${widget.habit.name.toUpperCase()}',
                      'PUT ${widget.habit.name.toUpperCase()} TO SLEEP',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.label.copyWith(color: velo.tenue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tr('¿Hasta cuándo?', 'Until when?'),
              style: t.title.copyWith(color: velo.cuerpo),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'Mientras duerme no cuenta ningún día en contra. Podés volver '
                    'antes cuando quieras: poner una pieza lo despierta.',
                'While it sleeps, no day counts against you. You can come back '
                    'earlier whenever you like: placing a piece wakes it up.',
              ),
              style: t.bodySoft.copyWith(
                fontSize: 12.5,
                height: 1.4,
                color: velo.suave,
              ),
            ),
            const SizedBox(height: 14),
            for (final span in _spans)
              SheetChoice(
                theme: t,
                velo: velo,
                on: dias == span.$1,
                title: span.$2,
                hint: span.$3,
                // El día en que vuelve, al lado: una pausa siempre tiene
                // fecha de vuelta, y verla es lo que la hace una pausa.
                trailing: Text(
                  dayMonthShort(_wakeOn(span.$1)),
                  style: t.bodySoft.copyWith(
                    fontSize: 12,
                    color: dias == span.$1 ? t.accent : velo.tenue,
                    fontWeight: dias == span.$1
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                onTap: () {
                  Sensory.instance.tick();
                  setState(() => _days = span.$1);
                },
              ),
            const SizedBox(height: 16),
            SheetAccent(
              theme: t,
              text: dias == null
                  ? tr('Elegí cuánto', 'Choose how long')
                  : tr(
                      'Que duerma hasta el ${dayMonth(_wakeOn(dias))}',
                      'Let it sleep until ${dayMonth(_wakeOn(dias))}',
                    ),
              onTap: dias == null
                  ? null
                  : () {
                      Sensory.instance.tick();
                      widget.onRest(_wakeOn(dias));
                      Navigator.of(context).pop();
                    },
            ),
            const SizedBox(height: 10),
            Text(
              tr(
                'Esto no borra nada y no es lo mismo que eliminarlo.',
                "This doesn't delete anything, and it isn't the same as "
                    'removing it.',
              ),
              textAlign: TextAlign.center,
              style: t.bodySoft.copyWith(
                fontSize: 11.5,
                height: 1.4,
                color: velo.tenue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
