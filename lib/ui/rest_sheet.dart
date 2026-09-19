import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../model/habit.dart';
import '../model/piece.dart';
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
  static const List<(int, String, String)> _spans = [
    (7, 'Una semana', 'un viaje, una gripe, una semana imposible'),
    (14, 'Dos semanas', 'unas vacaciones'),
    (30, 'Un mes', 'una mudanza, un examen, un mes de los otros'),
    (90, 'Tres meses', 'una temporada entera de tu vida'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
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
            Text('DORMIR EL PUEBLO', style: t.label),
            const SizedBox(height: 10),
            Text('¿Hasta cuándo?', style: t.title),
            const SizedBox(height: 6),
            Text(
              'Mientras duerme no se apaga, no pierde nada y no cuenta ningún '
              'día en contra. Podés volver antes cuando quieras: poner una '
              'pieza lo despierta.',
              style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _spans.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _span(t, _spans[i]),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _days == null
                    ? null
                    : () {
                        widget.onRest(
                          dayStart(
                            DateTime.now().add(Duration(days: _days! + 1)),
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent.withValues(alpha: 0.85),
                  foregroundColor: t.dark ? Colors.black : Colors.white,
                  disabledBackgroundColor: t.fg.withValues(alpha: 0.10),
                  disabledForegroundColor: t.fgFaint,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _days == null
                      ? 'Elegí cuánto'
                      : 'Que duerma ${_days == 1 ? 'un día' : '$_days días'}',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Esto no borra nada y no es lo mismo que eliminarlo.',
                style: t.bodySoft.copyWith(fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _span(UiTheme t, (int, String, String) span) {
    final chosen = _days == span.$1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sensory.instance.tick();
        setState(() => _days = span.$1);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: t.fg.withValues(alpha: chosen ? 0.10 : 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: chosen ? t.accent.withValues(alpha: 0.85) : t.stroke,
            width: chosen ? 1.6 : 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    span.$2,
                    style: t.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: chosen ? t.accent : t.fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(span.$3, style: t.bodySoft.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
            if (chosen) Icon(Icons.check, size: 18, color: t.accent),
          ],
        ),
      ),
    );
  }
}
