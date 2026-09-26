import 'package:flutter/material.dart';

import '../data/landmarks.dart';
import '../fx/sensory.dart';
import '../model/works_log.dart';
import 'legend_card.dart';
import 'papyrus.dart';
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
    final a = '${s.began.day} de ${Papyrus.months[s.began.month - 1]}';
    final b = '${s.ended!.day} de ${Papyrus.months[s.ended!.month - 1]}';
    final d = s.days!;
    return 'del $a al $b · $d ${d == 1 ? 'día' : 'días'}';
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
                      'HITO $ordinal DEL PUEBLO',
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
                        fontFamily: Papyrus.serif,
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
                      'levantado con ${mark.cost} piezas tuyas',
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

/// Para qué fue una pieza, al tocarla.
///
/// La leyenda se escribe aquí mismo. Antes esto abría una hoja por debajo con
/// su título, su explicación y sus botones de guardar y cancelar: una pantalla
/// entera para una frase de sesenta letras que ya estaba en pantalla. Ahora el
/// texto se convierte en el campo y se escribe donde se lee.
///
/// Y no hay botón de guardar. Tocar fuera guarda, que es lo que iba a pasar de
/// todas formas.
class StoneCard extends StatefulWidget {
  const StoneCard({
    super.key,
    required this.theme,
    required this.when,
    required this.number,
    required this.label,
    required this.onWrite,
    required this.onWhen,
  });

  final UiTheme theme;
  final DateTime when;
  final int number;
  final String? label;

  /// La leyenda nueva. Vacía quiere decir que se borró.
  final void Function(String text) onWrite;

  /// La hora corregida.
  ///
  /// La app apunta la hora en que tocaste el botón, y ésa no siempre es la
  /// hora en que hiciste la cosa: se corre a las once de la noche lo que se
  /// hizo al levantarse, y el pueblo lo anota como una costumbre nocturna —el
  /// tablón se fija justo en eso. Se toca la fecha de la cabecera y se
  /// arregla.
  final void Function(DateTime when) onWhen;

  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

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
    final dias = hoy.difference(suyo).inDays;
    final hora =
        '${w.hour.toString().padLeft(2, '0')}:'
        '${w.minute.toString().padLeft(2, '0')}';
    if (dias == 0) return 'hoy $hora';
    if (dias == 1) return 'ayer $hora';
    final ano = w.year == ahora.year ? '' : ' ${w.year}';
    return '${w.day} ${_months[w.month - 1]}$ano $hora';
  }

  static String formatDate(DateTime w) =>
      '${w.day} ${_months[w.month - 1]} ${w.year} · '
      '${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}';

  @override
  State<StoneCard> createState() => _StoneCardState();
}

class _StoneCardState extends State<StoneCard> {
  late final TextEditingController _text = TextEditingController(
    text: widget.label ?? '',
  );
  final FocusNode _focus = FocusNode();
  bool _writing = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open() {
    if (_writing) return;
    Sensory.instance.tick();
    setState(() => _writing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  /// Corregir la hora. Sólo la hora: el día es el día en que se puso y eso no
  /// se discute — una pieza es el día que la ganaste.
  Future<void> _when() async {
    if (_writing) _close();
    Sensory.instance.tick();
    final t = widget.theme;
    final puesto = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.when),
      helpText: 'A QUÉ HORA FUE',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: (t.dark ? ColorScheme.dark() : ColorScheme.light())
              .copyWith(primary: t.accent, surface: t.panelStrong),
        ),
        child: child!,
      ),
    );
    if (puesto == null || !mounted) return;
    final w = widget.when;
    if (puesto.hour == w.hour && puesto.minute == w.minute) return;
    Sensory.instance.tick();
    widget.onWhen(DateTime(w.year, w.month, w.day, puesto.hour, puesto.minute));
  }

  void _close() {
    if (!_writing) return;
    final t = _text.text.trim();
    if (t != (widget.label ?? '')) {
      Sensory.instance.tick();
      widget.onWrite(t);
    }
    setState(() => _writing = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final has = widget.label != null && widget.label!.trim().isNotEmpty;
    return LegendCard(
      theme: t,
      onTap: _writing ? null : _open,
      header: 'PIEZA ${widget.number} · ${StoneCard.formatDate(widget.when)}',
      onTapHeader: _when,
      child: _writing
          ? TextField(
              controller: _text,
              focusNode: _focus,
              maxLength: 60,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _close(),
              onTapOutside: (_) => _close(),
              textCapitalization: TextCapitalization.sentences,
              cursorColor: t.accent,
              // El color va escrito aquí y no heredado. La tarjeta se lo pone
              // a su cuerpo con un DefaultTextStyle, que es lo que hace que la
              // leyenda ya escrita salga clara sobre el bloque oscuro de
              // noche; pero un campo de texto no lee eso: se mezcla contra el
              // tema de Material, que lo pintaba en negro. Así, escribiendo de
              // noche se escribía en negro y al guardar el mismo texto se
              // volvía blanco.
              style: TextStyle(
                fontSize: 13.5,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: t.fg,
              ),
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                contentPadding: EdgeInsets.zero,
                hintText: 'qué fue',
                // Y el hueco, de la misma tinta floja que «escribir una
                // leyenda»: es lo mismo que falta, visto un segundo después.
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  height: 1.25,
                  fontWeight: FontWeight.w400,
                  color: LegendCard.pending(t),
                ),
                border: InputBorder.none,
              ),
            )
          : Text(
              has ? widget.label! : 'escribir una leyenda',
              // Sin color cuando hay leyenda: lo pone la tarjeta. Cuando no la
              // hay, pardo flojo — es una frase que falta, no un aviso.
              style: TextStyle(
                fontSize: 13.5,
                height: 1.25,
                fontWeight: has ? FontWeight.w500 : FontWeight.w400,
                color: has ? null : LegendCard.pending(t),
              ),
            ),
    );
  }
}
