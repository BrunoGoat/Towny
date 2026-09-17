import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/pacing.dart';
import '../fx/sensory.dart';
import '../model/habit.dart';
import '../model/store.dart';
import 'habit_sigil.dart';
import 'style.dart';

/// The row of habits, right above the button.
///
/// Every habit is a symbol you chose and a town of your own. Tapping one takes
/// you there. It sits where the thumb already is, because switching between
/// habits is the second most common thing anybody does here — the first being
/// laying a piece.
///
/// It used to be a row of bordered pills with a count in each, and it ate a
/// whole band across the bottom of a screen whose entire job is to show you a
/// town. Now it is what it always was underneath: a line of marks, one lit.
/// No frames, no plates, no numbers competing with the one already at the top
/// of the screen — the current town is the one in the accent colour with a dot
/// under it, and that is the whole of what this has to say. Each mark is small
/// and the thing you tap is not: the hit area stays a full thumb wide.
class HabitBar extends StatelessWidget {
  const HabitBar({
    super.key,
    required this.store,
    required this.theme,
    required this.onSelect,
    required this.onManage,
    required this.onAdd,
  });

  final Store store;
  final UiTheme theme;
  final void Function(int index) onSelect;

  /// Tapping the habit you are already on: edit this one.
  final VoidCallback onManage;

  /// Tapping the plus: found a new one. Not the same thing at all.
  final VoidCallback onAdd;

  /// What the whole row costs in height. A quarter of what the pills did.
  static const double height = 38;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final locked = !store.unlocked && store.habits.length < Habit.maxSlots;
    // Cuánto lleva andado hacia el segundo pueblo, y si vale la pena
    // enseñarlo. El primer día no: un candado en la cara de alguien que
    // todavía no puso su primera piedra es la app pidiéndole que se apure. En
    // cuanto hay algo hecho, el anillo aparece y ya no se va.
    final ganados = locked ? store.unlockProgress : 0;
    final avisa = locked && ganados > 0;
    if (store.habits.length <= 1 && !store.canAddHabit && !avisa) {
      return const SizedBox.shrink();
    }

    final crown = store.leader;

    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          for (var i = 0; i < store.habits.length; i++)
            _Mark(
              habit: store.habits[i],
              lit: Store.integrityOf(store.habits[i]),
              on: i == store.active,
              crowned: i == crown,
              theme: t,
              onTap: () {
                if (i == store.active) {
                  onManage();
                } else {
                  Sensory.instance.tick();
                  onSelect(i);
                }
              },
            ),
          _AddMark(
            theme: t,
            onTap: onAdd,
            enabled: store.canAddHabit,
            locked: avisa,
            progress: ganados / Pacing.unlockDays,
          ),
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({
    required this.habit,
    required this.lit,
    required this.on,
    required this.crowned,
    required this.theme,
    required this.onTap,
  });

  final Habit habit;
  final double lit;
  final bool on;

  /// The most pieces in the valley. A whole competition in one small mark.
  final bool crowned;
  final UiTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // Dimmed when the habit has been left: the row of symbols is itself a
    // small readout of how every habit is going.
    final ink = (on ? t.accent : t.fg).withValues(
      alpha: on ? 1.0 : 0.30 + 0.34 * lit,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 46,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    scale: on ? 1.0 : 0.88,
                    child: HabitSigil(
                      symbol: habit.symbol,
                      color: ink,
                      size: 21,
                    ),
                  ),
                  if (crowned)
                    Positioned(
                      top: -6,
                      right: -1,
                      child: CustomPaint(
                        size: const Size(11, 9),
                        painter: _CrownMark(
                          const Color(0xFFE8B84B).withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  // Un pueblo dormido no se apaga, así que sin esto se ve
                  // exactamente igual que uno al día — que es cierto en cuanto
                  // a que no ha perdido nada, y confuso en cuanto a por qué no
                  // se está apagando. La luna lo dice en el sitio donde ya se
                  // dice todo lo demás de cada pueblo.
                  if (habit.resting)
                    Positioned(
                      bottom: -3,
                      right: -2,
                      child: Icon(
                        Icons.bedtime,
                        size: 9,
                        color: (on ? t.accent : t.fg).withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // The one dot that says which town you are standing in.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: on ? 14 : 3,
              height: 3,
              decoration: BoxDecoration(
                color: on
                    ? t.accent.withValues(alpha: 0.9)
                    : t.fg.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El más: fundar otro pueblo, o ver cuánto falta para poder.
///
/// Cuando está cerrado no se esconde, y ésa es toda la idea. Un candado
/// invisible no es una promesa, es una ausencia: nadie echa de menos lo que no
/// sabe que existe. Con el anillo ahí, el segundo pueblo es una cosa que se ve
/// llegar mientras se usa la app, y eso —la curiosidad, las ganas de ver qué
/// hay— es una razón para volver mañana que no depende de acordarse de nada.
class _AddMark extends StatelessWidget {
  const _AddMark({
    required this.theme,
    required this.onTap,
    required this.enabled,
    required this.locked,
    required this.progress,
  });
  final UiTheme theme;
  final VoidCallback onTap;
  final bool enabled;

  /// Cerrado por el candado, que no es lo mismo que cerrado porque el valle
  /// esté lleno: lo primero se abre solo y lo segundo no se abre nunca.
  final bool locked;

  /// De cero a uno, lo que lleva andado hacia el segundo pueblo.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // El cerrado también se puede tocar: es la única manera de enterarse de
      // qué es lo que falta. Un botón apagado que no contesta cuando se aprieta
      // parece un fallo de la app.
      onTap: enabled || locked ? onTap : null,
      child: SizedBox(
        width: 46,
        child: Center(
          child: locked
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CustomPaint(
                    painter: _UnlockRing(
                      progress,
                      t.accent.withValues(alpha: 0.75),
                      t.fg.withValues(alpha: 0.14),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add,
                        size: 12,
                        color: t.fg.withValues(alpha: 0.34),
                        shadows: t.halo,
                      ),
                    ),
                  ),
                )
              : Icon(
                  Icons.add,
                  size: 18,
                  color: t.fg.withValues(alpha: enabled ? 0.42 : 0.16),
                  shadows: t.halo,
                ),
        ),
      ),
    );
  }
}

/// El anillo que se va cerrando alrededor del más.
///
/// El mismo gesto que el anillo del botón de poner una pieza, que también se
/// cierra: en esta app, una cosa que se completa se dibuja así y no con una
/// barra. Arranca arriba y gira como un reloj.
class _UnlockRing extends CustomPainter {
  const _UnlockRing(this.progress, this.on, this.off);
  final double progress;
  final Color on;
  final Color off;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(1.4), 0, math.pi * 2, false, p..color = off);
    if (progress <= 0) return;
    canvas.drawArc(
      rect.deflate(1.4),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      p..color = on,
    );
  }

  @override
  bool shouldRepaint(_UnlockRing old) =>
      old.progress != progress || old.on != on;
}

/// The valley's crown, small enough to sit over a mark.
class _CrownMark extends CustomPainter {
  const _CrownMark(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      HabitSigils.crown(canvas, Offset.zero & size, color);

  @override
  bool shouldRepaint(_CrownMark old) => old.color != color;
}
