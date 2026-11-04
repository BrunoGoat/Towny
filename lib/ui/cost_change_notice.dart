import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../l10n/lang.dart';
import '../model/cost_changes.dart';
import 'sheet_glass.dart';
import 'style.dart';

/// El aviso de que alguna obra pasó a costar otra cantidad de piezas. Ver
/// `cost_changes.dart`.
class CostChangeNotice extends StatelessWidget {
  const CostChangeNotice({
    super.key,
    required this.changes,
    required this.theme,
  });

  final List<CostChange> changes;
  final UiTheme theme;

  static String _piezas(int n) =>
      tr(n == 1 ? '1 pieza' : '$n piezas', n == 1 ? '1 piece' : '$n pieces');

  /// Lo que se le dice, en dos líneas a lo sumo.
  static String summary(List<CostChange> c) {
    final favor = piecesInFavour(c), faltan = piecesOwed(c);
    final partes = <String>[
      if (favor > 0)
        tr(
          'Tenés ${_piezas(favor)} a favor: ya estaban puestas, y pasan '
              'solas a la obra que sigue.',
          'You have ${_piezas(favor)} in your favour: already placed, they '
              'move on to the next work by themselves.',
        ),
      if (faltan > 0)
        tr(
          'Las próximas ${_piezas(faltan)} completan lo que ahora les falta.',
          'Your next ${_piezas(faltan)} make up what they now need.',
        ),
    ];
    return partes.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final velo = SheetInk.of(t);
    final variosPueblos = changes.map((c) => c.town).toSet().length > 1;
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
                  tr('Cambiaron unas obras', 'Some works changed'),
                  textAlign: TextAlign.center,
                  style: t.title.copyWith(
                    color: velo.cuerpo,
                    shadows: velo.aliento,
                  ),
                ),
                const SizedBox(height: 14),
                for (final c in changes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${c.name}${variosPueblos ? ' (${c.town})' : ''}: '
                      '${tr('de ${c.before} a ${c.after} piezas', 'from ${c.before} to ${c.after} pieces')}',
                      textAlign: TextAlign.center,
                      style: t.bodySoft.copyWith(
                        fontSize: 14,
                        color: velo.cuerpo,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  summary(changes),
                  textAlign: TextAlign.center,
                  style: t.bodySoft.copyWith(
                    fontSize: 13,
                    height: 1.4,
                    color: velo.suave,
                  ),
                ),
                const SizedBox(height: 18),
                SheetAccent(
                  theme: t,
                  text: tr('Entendido', 'Got it'),
                  onTap: () {
                    Sensory.instance.tick();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
