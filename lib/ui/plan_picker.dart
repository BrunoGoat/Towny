import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../fx/sensory.dart';
import '../l10n/lang.dart';
import '../model/pledge.dart';
import 'style.dart';

/// El reloj del plan: las veinticuatro horas en fila, y la que elegiste.
///
/// Se elige tocando y no escribiendo. Una hora escrita a mano pide un teclado
/// numérico, admite las 31:00 y hay que validarla; una hora tocada es una
/// decisión de un dedo y no puede estar mal. Y van en fila y no en rejilla
/// porque el día es una fila: la madrugada queda a la izquierda, la noche a la
/// derecha, y encontrar «las diez» es mirar donde estarían las diez.
///
/// Empieza puesto en la hora elegida —o en la de ahora mismo, si no hay
/// ninguna—, que casi siempre es la hora de la que se va a hablar: quien funda
/// un pueblo a las once de la noche suele estar contando lo que hace a las once
/// de la noche.
class HourReel extends StatefulWidget {
  const HourReel({
    super.key,
    required this.hour,
    required this.onPick,
    required this.ink,
    required this.accent,
    required this.plate,
    required this.edge,
    this.shadows,
  });

  /// La hora elegida, de 0 a 23, o nulo si todavía no hay ninguna.
  final int? hour;
  final ValueChanged<int> onPick;

  /// Los colores, de fuera: esto sale sobre el prado de la primera pantalla y
  /// sobre el vidrio de la hoja del hábito, que son dos sitios con dos tintas
  /// distintas, y el fallo de darle la del tema sería el de siempre —el icono
  /// que se lee en una pantalla y desaparece en la otra—.
  final Color ink;
  final Color accent;
  final Color plate;
  final Color edge;
  final List<Shadow>? shadows;

  @override
  State<HourReel> createState() => _HourReelState();
}

class _HourReelState extends State<HourReel> {
  static const double _w = 44;
  static const double _gap = 7;

  late final ScrollController _reel = ScrollController();

  @override
  void initState() {
    super.initState();
    // Centrada, no pegada al borde: una hora que aparece contra el canto
    // izquierdo parece la primera de la lista y no la elegida.
    final at = widget.hour ?? DateTime.now().hour;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_reel.hasClients) return;
      final ancho = _reel.position.viewportDimension;
      final quiere = (at + 0.5) * (_w + _gap) - ancho / 2;
      _reel.jumpTo(quiere.clamp(0.0, _reel.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _reel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView.builder(
      controller: _reel,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      itemCount: 24,
      itemBuilder: (_, h) {
        final elegida = h == widget.hour;
        return Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Sensory.instance.tick();
              widget.onPick(h);
            },
            child: Container(
              width: _w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: elegida
                    ? widget.accent.withValues(alpha: 0.22)
                    : widget.plate,
                border: Border.all(
                  color: elegida ? widget.accent : widget.edge,
                ),
              ),
              child: Text(
                // Dos cifras siempre. Con «7» y «17» en la misma fila, la fila
                // se lee como si le faltara algo.
                h.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: elegida ? widget.accent : widget.ink,
                  fontSize: 15,
                  fontWeight: elegida ? FontWeight.w600 : FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: widget.shadows,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Escribir el plan sin salir de donde estás.
///
/// Existe por el tablón. Cuando el pueblo ya sabe a qué hora aparecés y no hay
/// plan escrito, lo dice en un papel, y lo que hay que poder hacer entonces es
/// escribirlo ahí mismo: mandar a alguien a buscar la hoja del hábito para
/// contestar una cosa que el tablón acaba de preguntar es perder la única vez
/// que iba a contestarla.
///
/// Devuelve `(hora, sitio)` — con la hora en nulo si se quitó— o nulo si se
/// cerró sin guardar.
class PlanSheet extends StatefulWidget {
  const PlanSheet({
    super.key,
    required this.theme,
    required this.name,
    this.hour,
    this.place,
  });

  final UiTheme theme;

  /// El nombre del hábito, que va dentro de la frase.
  final String name;
  final int? hour;
  final String? place;

  @override
  State<PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<PlanSheet> {
  late int? _hour = widget.hour;
  late final TextEditingController _spot = TextEditingController(
    text: widget.place ?? '',
  );

  @override
  void dispose() {
    _spot.dispose();
    super.dispose();
  }

  void _keep() {
    Sensory.instance.tick();
    Navigator.of(context).pop((_hour, _spot.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final velo = SheetInk.of(t);
    final frase = vowLine(widget.name, _hour, _spot.text);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: velo.bruma, sigmaY: velo.bruma),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
            decoration: BoxDecoration(
              color: velo.tinte.withValues(alpha: velo.tapa),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(top: BorderSide(color: velo.canto)),
            ),
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
                const SizedBox(height: 18),
                HourReel(
                  hour: _hour,
                  onPick: (h) => setState(() => _hour = _hour == h ? null : h),
                  ink: velo.cuerpo.withValues(alpha: 0.82),
                  accent: t.accent,
                  plate: velo.tinte.withValues(alpha: 0.42),
                  edge: velo.cuerpo.withValues(alpha: 0.20),
                  shadows: velo.aliento,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _spot,
                  onChanged: (_) => setState(() {}),
                  maxLength: 40,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  style: t.body.copyWith(
                    fontSize: 16,
                    height: 1.3,
                    color: velo.cuerpo,
                  ),
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                    border: InputBorder.none,
                    hintText: tr('en la cama', 'in bed'),
                    hintStyle: t.body.copyWith(
                      fontSize: 16,
                      height: 1.3,
                      color: velo.cuerpo.withValues(alpha: 0.38),
                    ),
                  ),
                  onSubmitted: (_) => _keep(),
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: velo.canto),
                const SizedBox(height: 12),
                Text(
                  frase ??
                      tr(
                        'Elegí la hora y escribí el sitio.',
                        'Choose the time and write the place.',
                      ),
                  textAlign: TextAlign.center,
                  style: t.bodySoft.copyWith(
                    fontSize: 14,
                    height: 1.35,
                    color: frase == null ? velo.tenue : t.accent,
                  ),
                ),
                Row(
                  children: [
                    const Spacer(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: frase == null ? null : _keep,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 16,
                        ),
                        child: Text(
                          tr('DARLO POR HECHO', 'CALL IT DONE'),
                          style: TextStyle(
                            color: frase == null ? velo.tenue : t.accent,
                            fontSize: 11.5,
                            letterSpacing: 2.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
