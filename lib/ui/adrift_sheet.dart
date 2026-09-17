import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../model/habit.dart';
import 'style.dart';

/// La segunda vez —y la última— que esta app te pregunta algo.
///
/// La otra es [ChoiceSheet], cuando toca empezar una obra grande, y las dos
/// funcionan por lo mismo: son raras. Una app de hábitos llena de preguntas es
/// una app que se cierra, así que si va a haber dos en toda su vida, las dos
/// tienen que valer la pena.
///
/// Ésta vale la pena porque distingue dos cosas que casi ninguna app
/// distingue. Cuatro días en blanco seguidos no son cuatro incumplimientos:
/// probablemente sean alguien desenganchándose. Y ésos se tratan distinto —
/// después de un día no hace falta que nadie intervenga; después de cuatro
/// puede ser justo el momento en que se pasa de «fallé» a «ya fue», que es la
/// única cosa de la que no se vuelve.
///
/// No acusa, no cuenta los días que faltaste y no dice que fallaste. Lo que
/// hace es abrir la posibilidad de que el problema no seas vos: que el hábito
/// esté mal planteado, o que éste no sea su mes. Las cuatro salidas son las
/// cuatro respuestas honestas a eso, y la app las trata a las cuatro como
/// respuestas correctas.
class AdriftSheet extends StatelessWidget {
  const AdriftSheet({
    super.key,
    required this.habit,
    required this.theme,
    required this.days,
    required this.onKeep,
    required this.onShrink,
    required this.onRest,
    required this.onDrop,
  });

  final Habit habit;
  final UiTheme theme;

  /// Cuántos días lleva el pueblo sin recibir una pieza.
  final int days;

  /// Seguimos igual. No pasa nada más: la hoja se va y no vuelve hasta el
  /// hueco siguiente.
  final VoidCallback onKeep;

  /// Hacerlo más chico: abre la hoja del hábito para reescribir lo mínimo que
  /// cuenta.
  final VoidCallback onShrink;

  /// Dormirlo una temporada, con fecha de vuelta.
  final VoidCallback onRest;

  /// Ya no lo quiero. Pasa por la misma confirmación de siempre.
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // Lo que escribiste vos, que es lo único de esta hoja que no es de la app.
    // El motivo primero: es más fuerte que el mínimo y es lo que de verdad se
    // olvida. Si no hay ninguno de los dos, la hoja se queda en la pregunta,
    // que ya se sostiene sola.
    final suyo = habit.why ?? habit.floor;
    final esMotivo = habit.why != null;

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
            Text('EL PUEBLO PREGUNTA', style: t.label),
            const SizedBox(height: 10),
            // La pregunta dice cuánto hace, no cuántas veces fallaste. Es el
            // mismo dato contado como lo contaría alguien que se alegra de
            // verte y no como lo contaría un registro de asistencia.
            Text(
              'Hace $days días que ${habit.name} no recibe una pieza.',
              style: t.title,
            ),
            const SizedBox(height: 6),
            Text(
              '¿Seguimos intentando, o lo cambiamos? Las cuatro respuestas '
              'valen. A lo mejor el problema no sos vos.',
              style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.4),
            ),
            if (suyo != null) ...[
              const SizedBox(height: 14),
              _yours(t, suyo, esMotivo),
            ],
            const SizedBox(height: 18),
            _Way(
              theme: t,
              icon: Icons.play_arrow_rounded,
              said: 'Seguimos',
              why: 'No cambia nada. El pueblo te espera donde está.',
              accent: true,
              onTap: () {
                Navigator.of(context).pop();
                onKeep();
              },
            ),
            const SizedBox(height: 10),
            _Way(
              theme: t,
              icon: Icons.compress,
              said: 'Hacerlo más chico',
              why: habit.floor == null
                  ? 'Escribí lo mínimo que todavía cuenta como una pieza. '
                        'Cinco minutos no son treinta, y no son cero.'
                  : 'Cambiá lo mínimo que cuenta. Si «${habit.floor}» se '
                        'volvió mucho, es que era mucho.',
              onTap: () {
                Navigator.of(context).pop();
                onShrink();
              },
            ),
            const SizedBox(height: 10),
            _Way(
              theme: t,
              icon: Icons.bedtime_outlined,
              said: 'Pausarlo',
              why:
                  'El pueblo duerme con las luces encendidas y no cuenta '
                  'ningún día en contra. Elegís hasta cuándo.',
              onTap: () {
                Navigator.of(context).pop();
                onRest();
              },
            ),
            const SizedBox(height: 10),
            _Way(
              theme: t,
              icon: Icons.close,
              said: 'Ya no lo quiero',
              why:
                  'Dejar de intentarlo también es una decisión, y es '
                  'distinta de no estar pudiendo ahora.',
              onTap: () {
                Navigator.of(context).pop();
                onDrop();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Lo que escribiste vos el día que fundaste esto, entre comillas y en otro
  /// papel — igual que en el tablón, donde lo tuyo nunca se confunde con lo
  /// que dedujo el pueblo.
  Widget _yours(UiTheme t, String said, bool esMotivo) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: t.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: t.accent.withValues(alpha: 0.28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          esMotivo ? 'LO ESCRIBISTE VOS' : 'LO MÍNIMO QUE CUENTA, DIJISTE',
          style: t.label.copyWith(fontSize: 9, letterSpacing: 1.6),
        ),
        const SizedBox(height: 6),
        Text('«$said»', style: t.body.copyWith(fontSize: 13.5, height: 1.4)),
      ],
    ),
  );
}

/// Una de las cuatro salidas. Todas del mismo tamaño y con el mismo peso: la
/// hoja no empuja hacia ninguna, porque no sabe cuál es la buena.
class _Way extends StatelessWidget {
  const _Way({
    required this.theme,
    required this.icon,
    required this.said,
    required this.why,
    required this.onTap,
    this.accent = false,
  });

  final UiTheme theme;
  final IconData icon;
  final String said;
  final String why;
  final VoidCallback onTap;

  /// La primera va marcada, y no porque sea la recomendada: es la que deja
  /// todo como está, y una hoja que aparece sola tiene que tener a la vista la
  /// salida que no cambia nada.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sensory.instance.tick();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: t.fg.withValues(alpha: accent ? 0.09 : 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent ? t.accent.withValues(alpha: 0.7) : t.stroke,
            width: accent ? 1.4 : 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 19,
              color: accent ? t.accent : t.fg.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    said,
                    style: t.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: accent ? t.accent : t.fg,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    why,
                    style: t.bodySoft.copyWith(fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
