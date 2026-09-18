import 'package:flutter/material.dart';

import '../engine/town.dart';
import '../model/appearance.dart';
import '../model/piece.dart';
import '../model/store.dart';
import 'habit_bar.dart';
import 'hold_button.dart';
import 'overlays.dart';
import 'style.dart';
import 'town_view.dart';

/// Lo que se pone encima del pueblo: la cabecera, la baraja de abajo y el
/// aviso de que estás mirando un pueblo que no es el tuyo todavía.
///
/// Tres widgets que sólo leen. No tocan el almacén, no abren hojas y no
/// deciden nada — les llega lo que hay que enseñar y un puñado de llamadas
/// para avisar de que alguien tocó algo. Estaban al final de `home_screen.dart`
/// detrás de las setecientas líneas de la pantalla, que es donde vive todo lo
/// contrario: los tiempos, el vuelo al valle, las hojas que se abren, los
/// avisos que hay que dar y cuándo.
///
/// Separarlas deja las dos cosas legibles por lo que son. Y la de abajo pasa a
/// poder mirarse sola: un test de diseño puede plantar una cabecera con un
/// nombre de hábito larguísimo en un teléfono estrecho sin levantar la app.

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.theme,
    required this.store,
    required this.onSettings,
  });

  final UiTheme theme;
  final Store store;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final habit = store.habit;
    final asleep = habit.resting;
    final decaying = store.isDecaying && !asleep;
    // Lo que sustituyó a la racha: de los días que contaban, en cuántos hubo
    // pieza. Un número que una mala semana baja un poco y no tira al suelo, y
    // que por lo tanto se puede mirar un día malo sin que duela mirarlo.
    final firme = store.consistency;
    final hoy = store.today;
    final ultima = store.lastPlacedAt;
    // Two doors, because there are two different things behind them: the
    // numbers open what you have done, and the gear opens what you can set.
    // One chevron meaning both was one of them hiding.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La cuenta no lleva a ninguna parte. Llevaba a una hoja con el pueblo,
        // los hitos y las leyendas, y lo del pueblo lo cuenta ya su tablón —que
        // es donde tiene que estar, escrito en un papel y no en una lista.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${store.total}',
                    style: t.number.copyWith(shadows: t.halo),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'PIEZAS',
                      style: t.label.copyWith(shadows: t.halo),
                    ),
                  ),
                  // Acá iba la racha. Ahora va cuántos de los días que
                  // contaban tienen pieza, que es lo mismo que preguntaba la
                  // racha contestado de una manera que admite un mal día. No
                  // se dice hasta que hay dos semanas de las que hablar: «1 de
                  // 1» el primer día no es una medida de nada.
                  if (firme.enough) ...[
                    const SizedBox(width: 14),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(
                        '${firme.done}/${firme.of} DÍAS',
                        style: t.label.copyWith(
                          shadows: t.halo,
                          color: t.fg.withValues(alpha: 0.44),
                        ),
                      ),
                    ),
                  ],
                  // Lo de hoy, al lado de la racha y con el mismo peso: son la
                  // misma clase de cosa —cuánto llevás— vista de cerca y de
                  // lejos. Cuando todavía no hay ninguna no se dice «0 HOY»:
                  // eso ya lo cuenta la línea de abajo diciendo que la última
                  // fue ayer, y mejor callado que con un cero en la cara.
                  if (hoy > 0) ...[
                    const SizedBox(width: 14),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(
                        '$hoy HOY',
                        style: t.label.copyWith(
                          shadows: t.halo,
                          color: t.fg.withValues(alpha: 0.44),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                asleep
                    ? 'El pueblo duerme · ${sleepUntil(habit.wakesAt!)}'
                    : decaying
                    // Lo mismo que decía antes, dicho sin contar los días que
                    // faltaste. La información útil es idéntica —está a
                    // oscuras, una pieza lo arregla— y la contabilidad de la
                    // culpa no hacía falta para darla.
                    ? 'Una pieza y vuelven las luces'
                    : store.nextEventLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: decaying
                      ? const Color(0xFFE0A055)
                      : t.fg.withValues(alpha: asleep ? 0.40 : 0.50),
                  fontSize: 12,
                  letterSpacing: 0.1,
                  shadows: t.halo,
                ),
              ),
              // Y cuándo fue la última, un escalón más floja: es el dato que
              // menos se busca de los cuatro y el que más veces contesta solo
              // la pregunta de si hoy ya se hizo o no.
              if (ultima != null) ...[
                const SizedBox(height: 2),
                Text(
                  'última pieza · ${StoneCard.formatWhen(ultima)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.fg.withValues(alpha: 0.34),
                    fontSize: 11,
                    letterSpacing: 0.1,
                    shadows: t.halo,
                  ),
                ),
              ],
            ],
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSettings,
          child: Padding(
            padding: const EdgeInsets.only(top: 2, left: 8, bottom: 8),
            child: Icon(
              Icons.settings_outlined,
              size: 21,
              color: t.fg.withValues(alpha: 0.44),
              shadows: t.halo,
            ),
          ),
        ),
      ],
    );
  }
}

/// Hasta cuándo duerme, dicho como se dice en voz alta.
String sleepUntil(DateTime until) {
  final dias = dayStart(until).difference(dayStart(DateTime.now())).inDays;
  if (dias <= 0) return 'despierta hoy';
  if (dias == 1) return 'despierta mañana';
  return 'despierta en $dias días';
}

class BottomDeck extends StatelessWidget {
  const BottomDeck({
    super.key,
    required this.theme,
    required this.wall,
    required this.onPlace,
    required this.placed,
    required this.plan,
    required this.store,
    required this.onSelect,
    required this.onManage,
    required this.onAdd,
  });

  final UiTheme theme;
  final TownViewController wall;
  final VoidCallback onPlace;
  final int placed;
  final TownPlan plan;
  final Store store;
  final void Function(int index) onSelect;
  final VoidCallback onManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            t.palette.ink.withValues(alpha: 0),
            t.palette.ink.withValues(alpha: t.dark ? 0.30 : 0.13),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HabitBar(
            store: store,
            theme: t,
            onSelect: onSelect,
            onManage: onManage,
            onAdd: onAdd,
          ),
          const SizedBox(height: 6),
          HoldToPlace(
            theme: t,
            onPlace: onPlace,
            onCharge: wall.setCharge,
            rapid: Appearance.instance.rapid,
          ),
        ],
      ),
    );
  }
}

/// Says, unmissably, that what you are looking at is not your wall.
class PreviewBanner extends StatelessWidget {
  const PreviewBanner({super.key, required this.theme, required this.store});
  final UiTheme theme;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: () => store.setPreview(null),
      child: SheetSurface(
        theme: t,
        all: true,
        top: 20,
        padding: const EdgeInsets.fromLTRB(15, 8, 11, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'VISTA DE ${store.shownTotal} PIEZAS',
              style: TextStyle(
                color: t.accent,
                fontSize: 10.5,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.close, size: 15, color: t.fgSoft),
          ],
        ),
      ),
    );
  }
}
