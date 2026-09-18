import 'package:flutter/material.dart';

import '../engine/town.dart';
import '../model/habit.dart';
import '../model/reel.dart';
import 'reel_screen.dart';
import '../model/piece.dart';
import '../fx/sensory.dart';
import '../model/store.dart';
import 'papyrus.dart';
import 'style.dart';

/// Everything the wall has become: the numbers, the landmarks and the hundred
/// epics, found and unfound.
class JourneySheet extends StatefulWidget {
  const JourneySheet({
    super.key,
    required this.store,
    required this.theme,
    required this.onGoTo,
    required this.onOpenPiece,
  });

  final Store store;
  final UiTheme theme;

  /// Jumps the camera to a position along the wall.
  final void Function(double x, double z) onGoTo;

  /// Centre of each built landmark, keyed by the brick it started on.

  /// Abre la pieza en el pueblo: la cámara va hasta ella y sale su tarjeta,
  /// que es donde se lee y se escribe la leyenda. No hay otra pantalla para
  /// eso, y no la había que añadir.
  final void Function(Piece brick) onOpenPiece;

  @override
  State<JourneySheet> createState() => _JourneySheetState();
}

class _JourneySheetState extends State<JourneySheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) {
        return SheetSurface(
          theme: t,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.fgFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              _tabs(t),
              const SizedBox(height: 6),
              Expanded(
                child: switch (_tab) {
                  0 => _Summary(store: widget.store, theme: t),
                  1 => _TownMilestones(store: widget.store, theme: t),
                  _ => _Legends(
                    store: widget.store,
                    theme: t,
                    onGoTo: widget.onGoTo,
                    onEdit: widget.onOpenPiece,
                  ),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabs(UiTheme t) {
    final labels = const ['EL PUEBLO', 'HITOS', 'LEYENDAS'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final on = i == _tab;
        return GestureDetector(
          onTap: () {
            Sensory.instance.tick();
            setState(() => _tab = i);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: on ? t.fg.withValues(alpha: 0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: on ? t.stroke : Colors.transparent),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                color: on ? t.fg : t.fgFaint,
                fontSize: 10.5,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.store, required this.theme});
  final Store store;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final days = store.lastDays(35);
    final maxDay = days.fold<int>(1, (m, d) => d.count > m ? d.count : m);
    final integrity = store.integrity;
    final firme = store.consistency;
    final vuelta = store.comingBack;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 40),
      children: [
        Row(
          children: [
            _stat(t, '${store.total}', 'PIEZAS'),
            _stat(
              t,
              '${store.plan.finishedBuildings(store.total, store.habit.chronicle)}',
              'CASAS',
            ),
            // Acá iban la racha y la mejor racha. Las dos cifras que quedan en
            // su sitio son de otra clase: las primeras dos dicen cuánto
            // acumulaste, y éstas dicen cómo te comportás. Una racha no puede
            // decir eso, porque sólo sabe contar hacia arriba desde el último
            // fallo.
            _stat(
              t,
              firme.enough ? '${(firme.rate * 100).round()}%' : '—',
              'CONSTANCIA',
            ),
            // Y la única cifra de toda la app que mejora cuando fallás: pasar
            // de desaparecer un mes a desaparecer dos días es un progreso
            // enorme que ninguna racha sabe representar.
            _stat(t, vuelta == null ? '—' : '${vuelta}d', 'VUELTA'),
          ],
        ),
        if (Reel.worthIt(store.habits)) ...[
          const SizedBox(height: 22),
          _HowItWasMade(store: store, theme: t),
        ],
        const SizedBox(height: 26),
        Text('LO QUE LLEVA EN PIE', style: t.label),
        const SizedBox(height: 10),
        _TownBar(store: store, theme: t),
        const SizedBox(height: 26),
        Text('ESTADO DEL PUEBLO', style: t.label),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: integrity,
            minHeight: 7,
            backgroundColor: t.fg.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation(
              integrity > 0.85
                  ? const Color(0xFF6E9E86)
                  : (integrity > 0.5 ? t.accent : const Color(0xFFA8556A)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          store.habit.resting
              ? 'El pueblo duerme. No se apaga, no pierde nada y no cuenta '
                    'ningún día en contra hasta que despierte.'
              : integrity > 0.99
              ? 'Todas las ventanas encendidas. Cada día que sumás una pieza siguen así.'
              : integrity > 0.6
              ? 'Empiezan a apagarse ventanas. Una sola pieza las vuelve a encender todas.'
              // Sin contar los días de ausencia y sin la palabra «vacío». Lo
              // que hay que decirle a alguien que abre esto después de tres
              // semanas es que no hay nada que recuperar.
              : 'Están casi todas apagadas. Una sola pieza las enciende todas '
                    'otra vez: no se pierde nada de lo construido.',
          style: t.bodySoft,
        ),
        const SizedBox(height: 28),
        Text('ÚLTIMOS 35 DÍAS', style: t.label),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((d) {
              final h = d.count == 0 ? 3.0 : 6 + 44 * (d.count / maxDay);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.2),
                  child: Container(
                    height: h,
                    decoration: BoxDecoration(
                      color: d.count == 0
                          ? t.fg.withValues(alpha: 0.10)
                          : t.accent.withValues(
                              alpha: 0.45 + 0.55 * (d.count / maxDay),
                            ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 28),
        Text('LO QUE VIENE', style: t.label),
        const SizedBox(height: 10),
        Text(store.nextEventLabel, style: t.body),
        const SizedBox(height: 6),
        Text(
          'Una pieza es siempre un logro. Nunca un lote.',
          style: t.bodySoft.copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 26),
        // Dos conceptos nuevos donde había uno viejo que todo el mundo
        // entendía sin explicación. La racha se explicaba sola; esto no, y una
        // cifra que no se entiende es una cifra que se ignora.
        Text('LAS CIFRAS', style: t.label),
        const SizedBox(height: 10),
        Text(
          firme.enough
              ? 'Constancia es de los últimos ${firme.of} días que contaban, '
                    'en cuántos pusiste algo: ${firme.done}. No es una racha. '
                    'Un mal día la baja un poco y no la tira al suelo, que es '
                    'lo que pasa de verdad cuando alguien falla un día.'
              : 'La constancia sale a las dos semanas de uso: es de los '
                    'últimos 30 días que contaban, en cuántos pusiste algo.',
          style: t.bodySoft,
        ),
        const SizedBox(height: 8),
        Text(
          vuelta == null
              ? 'Vuelta es cuánto tardás en volver después de faltar. Aparece '
                    'en cuanto haya huecos de los que hablar — y es la única '
                    'cifra de acá que mejora cuando fallás.'
              : 'Vuelta es cuánto tardás en volver después de faltar: '
                    '${vuelta == 1 ? 'un día' : '$vuelta días'}. Es la que más '
                    'importa. No se trata de no fallar nunca; se trata de que '
                    'cada vez tardes menos en volver.',
          style: t.bodySoft,
        ),
      ],
    );
  }

  Widget _stat(UiTheme t, String value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: t.number),
        const SizedBox(height: 5),
        Text(label, style: t.label.copyWith(fontSize: 9, letterSpacing: 1.4)),
      ],
    ),
  );
}

/// How much of the town is standing, and what it is working on.
///
/// The wall has levels because it grows upward in bands; a town does not. What
/// it has instead is a count of finished buildings, which is the thing anybody
/// would actually say out loud about a town.
class _TownBar extends StatelessWidget {
  const _TownBar({required this.store, required this.theme});
  final Store store;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final built = store.plan.finishedBuildings(
      store.total,
      store.habit.chronicle,
    );
    final work = store.plan.underway(store.total, store.habit.chronicle);
    final left = work?.$2 ?? 0;
    final name = work?.$1 ?? '';
    final cost = left > 0 ? left : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$built', style: t.number.copyWith(fontSize: 26)),
            const SizedBox(width: 8),
            Text(
              built == 1 ? 'EDIFICIO EN PIE' : 'EDIFICIOS EN PIE',
              style: t.label,
            ),
          ],
        ),
        if (work != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1 - left / (cost + 0.0001),
              minHeight: 7,
              backgroundColor: t.fg.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(t.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            left == 1
                ? 'Una pieza más y $name queda en pie'
                : '$name · faltan $left piezas',
            style: t.bodySoft,
          ),
        ],
      ],
    );
  }
}

class _TownMilestones extends StatelessWidget {
  const _TownMilestones({required this.store, required this.theme});
  final Store store;
  final UiTheme theme;

  static const _icons = [
    Icons.water_drop_outlined,
    Icons.storefront_outlined,
    Icons.account_balance_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final placed = store.total;
    final rows = store.plan.landmarksAround(
      placed,
      chronicle: store.habit.chronicle,
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 40),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final (mark, first) = rows[i];
        final done = placed >= first + mark.cost;
        final active = placed > first && !done;
        final locked = placed <= first;
        final progress = active ? (placed - first) / mark.cost : 0.0;

        return Opacity(
          opacity: locked ? 0.45 : 1,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: t.fg.withValues(alpha: active ? 0.07 : 0.035),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? t.accent.withValues(alpha: 0.5) : t.stroke,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  locked ? Icons.lock_outline : _icons[mark.tier],
                  size: 26,
                  color: locked
                      ? t.fg.withValues(alpha: 0.34)
                      : (active ? t.accent : t.fg.withValues(alpha: 0.78)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // An unbuilt landmark keeps its name to itself: half of
                        // what a road ahead is worth is not knowing all of it.
                        locked ? 'Hito ${i + 1}' : mark.name,
                        style: t.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        done
                            ? 'En pie · ${_finishedOn(store, first + mark.cost - 1)}'
                            : active
                            ? 'En obra · ${placed - first} de ${mark.cost}'
                            : 'Empieza en la pieza ${first + 1}',
                        style: t.bodySoft.copyWith(fontSize: 11.5),
                      ),
                      if (active) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: t.fg.withValues(alpha: 0.10),
                            valueColor: AlwaysStoppedAnimation(t.accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The day a landmark was finished, read off the piece that finished it.
///
/// The town is already a calendar — every piece in it carries the day it was
/// laid — and this is the town saying so out loud.
String _finishedOn(Store store, int last) {
  final p = store.pieceAt(last);
  if (p == null) return 'En pie';
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final d = p.placedAt;
  final now = DateTime.now();
  final year = d.year == now.year ? '' : ' de ${d.year}';
  return 'terminado el ${d.day} de ${months[d.month - 1]}$year';
}

class _Legends extends StatelessWidget {
  const _Legends({
    required this.store,
    required this.theme,
    required this.onGoTo,
    required this.onEdit,
  });

  final Store store;
  final UiTheme theme;
  final void Function(double x, double z) onGoTo;
  final void Function(Piece brick) onEdit;

  @override
  Widget build(BuildContext context) {
    // Oldest first: a chronicle is read forwards, from the first stone to the
    // last, which is the whole point of it being a story.
    final items = store.labelled.reversed.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: CustomPaint(painter: PapyrusPainter())),
          Material(
            type: MaterialType.transparency,
            child: items.isEmpty ? _empty(context) : _log(context, items),
          ),
        ],
      ),
    );
  }

  Widget _heading() => Column(
    children: [
      const SizedBox(height: 26),
      Text(
        'BITÁCORA DEL PUEBLO',
        textAlign: TextAlign.center,
        style: Papyrus.body(
          13,
          w: FontWeight.w700,
          c: Papyrus.ink,
        ).copyWith(letterSpacing: 2.6),
      ),
      const SizedBox(height: 6),
      Text(
        '· ${Papyrus.roman(store.total)} ${'piezas asentadas'} ·',
        textAlign: TextAlign.center,
        style: Papyrus.body(
          11.5,
          c: Papyrus.inkFaint,
        ).copyWith(letterSpacing: 1.2),
      ),
      const SizedBox(height: 16),
      const PapyrusRule(),
      const SizedBox(height: 4),
    ],
  );

  Widget _empty(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
    children: [
      _heading(),
      const SizedBox(height: 24),
      Text(
        'Aquí no hay nada escrito todavía.',
        textAlign: TextAlign.center,
        style: Papyrus.body(16.5, w: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      Text(
        'Tocá cualquier parte del pueblo y dejale una leyenda: “Leí”, “Corrí”, lo que quieras. No hace falta —la pieza ya está puesta— pero lo que se escribe queda en esta bitácora, y dentro de un año esto va a ser una historia.',
        textAlign: TextAlign.center,
        style: Papyrus.body(14, c: Papyrus.inkSoft),
      ),
      const SizedBox(height: 26),
      const PapyrusRule(wide: true),
    ],
  );

  Widget _log(BuildContext context, List<Piece> items) {
    // Broken into months, each with its own illuminated heading.
    final rows = <Widget>[_heading()];
    String? month;
    for (var i = 0; i < items.length; i++) {
      final b = items[i];
      final m = Papyrus.monthHeading(b.placedAt);
      if (m != month) {
        month = m;
        rows.add(
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 18 : 26, bottom: 2),
            child: Text(
              m,
              style: Papyrus.body(
                10.5,
                w: FontWeight.w700,
                c: Papyrus.rubric,
              ).copyWith(letterSpacing: 2.0),
            ),
          ),
        );
        rows.add(const Divider(color: Papyrus.rule, height: 12));
      }
      rows.add(
        PapyrusEntry(
          brick: b,
          ordinal: i + 1,
          dropCap: i == 0,
          onGo: () {
            final piece = TownLayout(
              store.total,
              store.character,
              cx: Habit.centreOf(store.habit.slot).$1,
              cz: Habit.centreOf(store.habit.slot).$2,
              chronicle: store.habit.chronicle,
              seed: store.habit.townSeed,
            ).pieceFor(b.index);
            Navigator.of(context).pop();
            if (piece != null) onGoTo(piece.cx, piece.cz);
          },
          onEdit: () {
            Navigator.of(context).pop();
            onEdit(b);
          },
        ),
      );
    }
    rows
      ..add(const SizedBox(height: 22))
      ..add(const PapyrusRule(wide: true))
      ..add(const SizedBox(height: 10))
      ..add(
        Text(
          'Y el pueblo sigue creciendo.',
          textAlign: TextAlign.center,
          style: Papyrus.body(
            12.5,
            c: Papyrus.inkFaint,
          ).copyWith(fontStyle: FontStyle.italic),
        ),
      );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 30),
      children: rows,
    );
  }
}

/// El botón de ver cómo se hizo.
///
/// Aquí y no en la pantalla del pueblo, y no es lo mismo. En el pueblo sería
/// un botón más entre los de la cámara, y lo que hace no es mover la cámara:
/// es abrir la única pantalla de la app que mira hacia atrás. *El viaje* es
/// donde ya están las cifras de lo que llevás hecho, y esto es esas cifras
/// pero mirándolas.
///
/// No aparece hasta que hay algo que enseñar —doce piezas y una semana, que es
/// lo que dice [Reel.worthIt]—, y no aparece antes apagado ni con un candado.
/// Un botón que no se puede pulsar es una promesa cobrando intereses; hasta
/// que haya crónica, sencillamente no hay botón.
class _HowItWasMade extends StatelessWidget {
  const _HowItWasMade({required this.store, required this.theme});

  final Store store;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sensory.instance.tick();
        // El navegador se coge **antes** de cerrar la hoja: después de cerrarla
        // este contexto ya no cuelga de ningún sitio y pedirle un navegador es
        // un fallo en tiempo de ejecución.
        final nav = Navigator.of(context, rootNavigator: true);
        Navigator.of(context).pop();
        nav.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => ReelScreen(store: store),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.stroke),
          color: t.fg.withValues(alpha: 0.03),
        ),
        child: Row(
          children: [
            Icon(Icons.play_arrow_rounded, size: 21, color: t.fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver cómo se hizo',
                    style: t.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'El valle entero desde el primer día, en un minuto.',
                    style: t.bodySoft.copyWith(fontSize: 12),
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
