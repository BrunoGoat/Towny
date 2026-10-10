import 'package:flutter/material.dart';

import '../data/landmarks.dart';
import '../fx/sensory.dart';
import '../l10n/dates.dart';
import '../l10n/lang.dart';
import '../model/census.dart';
import '../model/piece.dart';
import '../model/works_log.dart';
import 'style.dart';

/// The card for a landmark the town has just finished.
///
/// It arrives every two or three weeks, which is the whole point: often enough
/// to be worth waiting for, rare enough that it is still an event. It says
/// what was built, what it means for the place, and what it cost you.
class TownLandmarkOverlay extends StatelessWidget {
  const TownLandmarkOverlay({
    super.key,
    required this.mark,
    required this.theme,
    required this.onDismiss,
    required this.ordinal,
    this.span,
  });

  final Landmark mark;
  final UiTheme theme;
  final VoidCallback onDismiss;
  final int ordinal;

  /// Cuándo se empezó y cuándo se remató, si se sabe.
  ///
  /// Es el momento en que esa fecha vale algo: la obra acaba de terminarse y
  /// lo que hay debajo de ella son dos meses de tu vida. Dicho aquí, el hito
  /// deja de ser un adorno del pueblo y pasa a ser una marca en el calendario.
  final WorkSpan? span;

  /// «del 3 de mayo al 2 de julio · 61 días»
  String? get _cuando {
    final s = span;
    if (s == null || !s.done) return null;
    final a = dayMonth(s.began);
    final b = dayMonth(s.ended!);
    final d = s.days!;
    return tr(
      'del $a al $b · $d ${d == 1 ? 'día' : 'días'}',
      '$a to $b · $d ${d == 1 ? 'day' : 'days'}',
    );
  }

  static const _icons = [
    Icons.water_drop_outlined,
    Icons.storefront_outlined,
    Icons.account_balance_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onDismiss,
      child: DecoratedBox(
        // Darkest at the bottom, clear at the top: the card sits low and the
        // thing it is about stays where you can see it turning.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.04),
              Colors.black.withValues(alpha: 0.30),
              Colors.black.withValues(alpha: 0.52),
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
        child: Align(
          alignment: const Alignment(0, 0.72),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 336),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Frosted(
                theme: t,
                strong: true,
                radius: 26,
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _icons[mark.tier],
                      size: 40,
                      color: t.fg.withValues(alpha: 0.88),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr('HITO $ordinal DEL PUEBLO', 'TOWN LANDMARK $ordinal'),
                      style: TextStyle(
                        color: t.accent,
                        fontSize: 10.5,
                        letterSpacing: 3.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      mark.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: t.fg,
                        fontSize: 24,
                        fontFamily: 'Chronicle',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      mark.blurb,
                      textAlign: TextAlign.center,
                      style: t.bodySoft.copyWith(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr(
                        'levantado con ${mark.cost} piezas tuyas',
                        'raised with ${mark.cost} of your pieces',
                      ),
                      style: TextStyle(
                        color: t.fgFaint,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (_cuando != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _cuando!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: t.fgFaint,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet line that slides in and leaves on its own.
class Whisper extends StatelessWidget {
  const Whisper({super.key, required this.message, required this.theme});

  final String message;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Frosted(
        theme: theme,
        radius: 30,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        // Casi todos los susurros son media línea, pero el de la vuelta no: es
        // el único que tiene algo que decir y lleva detrás, entre comillas, lo
        // que vos mismo escribiste el día que fundaste esto. Con un ancho
        // máximo cae en dos o tres renglones centrados en vez de estirarse de
        // canto a canto de la pantalla.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.fg.withValues(alpha: 0.9),
              fontSize: 12.5,
              letterSpacing: 0.4,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}

/// Una pieza, al tocarla: cuál es y cuándo se puso.
///
/// Tocar la fecha corrige la hora. Sólo la hora: el día es el día en que se
/// puso y eso no se discute — una pieza es el día que la ganaste.
class StoneCard extends StatelessWidget {
  const StoneCard({
    super.key,
    required this.theme,
    required this.when,
    required this.number,
    required this.onWhen,
  });

  final UiTheme theme;
  final DateTime when;
  final int number;

  /// La hora corregida.
  ///
  /// La app apunta la hora en que tocaste el botón, y ésa no siempre es la
  /// hora en que hiciste la cosa: se corre a las once de la noche lo que se
  /// hizo al levantarse, y el pueblo lo anota como una costumbre nocturna —el
  /// tablón se fija justo en eso. Se toca la fecha y se arregla.
  final void Function(DateTime when) onWhen;

  /// La misma fecha pero contada desde hoy: «hoy 21:44», «ayer 07:12»,
  /// «10 sep 12:23».
  ///
  /// Para la línea de arriba, donde lo que importa es hace cuánto y no el día
  /// exacto. Un «10 sep 21:44» cuando hoy es 10 de septiembre obliga a mirar el
  /// calendario para entender una cosa que se sabe sola.
  static String formatWhen(DateTime w, {DateTime? from}) {
    final ahora = from ?? DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final suyo = DateTime(w.year, w.month, w.day);
    final dias = daysBetween(suyo, hoy);
    final hora =
        '${w.hour.toString().padLeft(2, '0')}:'
        '${w.minute.toString().padLeft(2, '0')}';
    if (dias == 0) return tr('hoy $hora', 'today $hora');
    if (dias == 1) return tr('ayer $hora', 'yesterday $hora');
    final ano = w.year == ahora.year ? '' : ' ${w.year}';
    return '${dayMonthShort(w)}$ano $hora';
  }

  static String formatDate(DateTime w) =>
      '${dayMonthShort(w)} ${w.year} · '
      '${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}';

  Future<void> _when(BuildContext context) async {
    Sensory.instance.tick();
    final t = theme;
    final puesto = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(when),
      helpText: tr('A QUÉ HORA FUE', 'WHAT TIME WAS IT'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: (t.dark ? ColorScheme.dark() : ColorScheme.light())
              .copyWith(primary: t.accent, surface: t.panelStrong),
        ),
        child: child!,
      ),
    );
    if (puesto == null) return;
    if (puesto.hour == when.hour && puesto.minute == when.minute) return;
    Sensory.instance.tick();
    onWhen(
      DateTime(when.year, when.month, when.day, puesto.hour, puesto.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final rotulo = t.label.copyWith(fontSize: 8.5, letterSpacing: 1.2);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          color: Color.lerp(t.panelStrong, t.accent, t.dark ? 0.16 : 0.13),
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('PIEZA $number', 'PIECE $number'), style: rotulo),
              const SizedBox(height: 5),
              // La fecha lleva un relojito detrás: se puede corregir, y una
              // fecha que se toca tiene que verse distinta de una que no.
              GestureDetector(
                onTap: () => _when(context),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        formatDate(when),
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                          color: t.fg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: t.fg.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quién es el vecino que sigue la cámara: su nombre grande, y al lado, en
/// chico, a qué se dedica, desde cuándo vive en el pueblo y con qué casa
/// llegó.
///
/// Sin caja ni fondo: es texto puesto sobre el pueblo, debajo de la persona,
/// como el rótulo de una película. Lo que se está mirando es a ella, y un
/// recuadro oscuro encima tapaba justo eso. Lo único que lleva es una sombra
/// suave, para que se lea igual sobre el prado, la nieve o un tejado.
///
/// No tiene botón de cerrar: tocar cualquier otra cosa deja de seguirla, y
/// con eso se va.
class FolkPanel extends StatelessWidget {
  const FolkPanel({super.key, required this.theme, required this.card});

  final UiTheme theme;
  final FolkCard card;

  static String ordinal(int n) {
    if (!inEnglish) return '$n.ª';
    final dos = n % 100;
    final suf = dos >= 11 && dos <= 13
        ? 'th'
        : switch (n % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$n$suf';
  }

  @override
  Widget build(BuildContext context) {
    final c = card;
    // Blanco con sombra, a cualquier hora: es lo que se lee sobre todo lo que
    // puede haber detrás —prado, nieve, piedra, cielo de noche—.
    const sombra = [
      Shadow(color: Color(0x99000000), blurRadius: 10),
      Shadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
    ];
    final chico = TextStyle(
      fontSize: 12,
      height: 1.4,
      color: Colors.white.withValues(alpha: 0.88),
      shadows: sombra,
    );
    final born = c.born;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: 5,
          child: Text(
            c.name,
            maxLines: 2,
            // La letra de los títulos de la primera vez: de libro antiguo,
            // como los nombres de la gente del valle.
            style: const TextStyle(
              fontFamily: 'EBGaramond',
              fontSize: 40,
              height: 1.0,
              color: Colors.white,
              shadows: sombra,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Flexible(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c.trade,
                style: chico.copyWith(
                  color: Color.lerp(theme.accent, Colors.white, 0.25),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (born != null)
                Text(
                  tr(
                    'desde el ${dayMonthShort(born)} ${born.year}',
                    'since ${dayMonthShort(born)} ${born.year}',
                  ),
                  style: chico,
                ),
              Text(
                tr(
                  '${ordinal(c.house)} casa · ${c.houseName.toLowerCase()}',
                  '${ordinal(c.house)} house · ${c.houseName.toLowerCase()}',
                ),
                style: chico,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
