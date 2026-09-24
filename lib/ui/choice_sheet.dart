import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/math3.dart';
import '../data/character.dart';
import '../data/landmarks.dart';
import '../engine/camera.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../engine/scene.dart';
import '../engine/tones.dart';
import '../engine/town.dart';
import '../fx/effects.dart';
import '../fx/sensory.dart';
import 'style.dart';

/// La única vez que esta app te pregunta algo.
///
/// Todo lo demás pasa solo: las casas salen del hash del pueblo, los hitos del
/// orden que le tocó al fundarlo, y no hay nada que decidir en ninguna
/// pantalla. Está bien que sea así — un botón y ninguna elección es la mitad
/// de lo que la hace descansada, y una app de hábitos llena de menús es una
/// app que se abandona.
///
/// Pero cada varias semanas, cuando toca empezar una obra grande, el pueblo
/// levanta la vista y pregunta. Dos obras sorteadas de entre las que le tocan
/// pronto; la que dejás no se pierde del catálogo, pero tampoco es la de la
/// próxima vez — puede volver a salir y puede que no. Eso es lo que hace que
/// sea una pregunta y no un orden: con la regla vieja las dos se construían
/// igual, una detrás de la otra, y elegir no decidía nada.
///
/// Y se puede cerrar sin contestar. Entonces deciden ellos, que es lo que
/// hacían antes de que se pudiera elegir.
class ChoiceSheet extends StatefulWidget {
  const ChoiceSheet({
    super.key,
    required this.options,
    required this.place,
    required this.theme,
    required this.onPick,
    required this.onLeave,
  });

  final List<Landmark> options;
  final TownCharacter place;
  final UiTheme theme;
  final void Function(Landmark) onPick;

  /// Cerrar sin contestar. No es «luego lo pregunto otra vez»: es que deciden
  /// ellos, ahora, lo que habrían decidido solos.
  final VoidCallback onLeave;

  @override
  State<ChoiceSheet> createState() => _ChoiceSheetState();
}

class _ChoiceSheetState extends State<ChoiceSheet> {
  /// Cuál está señalada. Ninguna hasta que se toca una: la hoja no llega con
  /// una respuesta ya puesta, porque entonces la de al lado tendría que
  /// ganarle a algo y no es lo que pasa — las dos empiezan iguales.
  int? _at;

  void _tap(int i) {
    Sensory.instance.tick();
    setState(() => _at = i);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final velo = SheetInk.of(t);
    final alto = MediaQuery.of(context).size.height;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420, maxHeight: alto * 0.84),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: velo.bruma,
                sigmaY: velo.bruma,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                decoration: BoxDecoration(
                  color: velo.tinte.withValues(alpha: velo.tapa),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: velo.canto),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // La pregunta, y nada más que la pregunta. Tenía encima un
                    // rótulo —«EL PUEBLO PREGUNTA»— y debajo un párrafo
                    // explicando las reglas, y las dos cosas sobraban: lo que
                    // hay que hacer se ve, y las reglas ya no son las que ese
                    // párrafo contaba.
                    Text(
                      '¿Qué levantamos ahora?',
                      style: t.title.copyWith(
                        color: velo.cuerpo,
                        shadows: velo.aliento,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Flexible(
                      child: SingleChildScrollView(
                        // Las dos columnas, de la misma altura aunque una
                        // tenga el doble de texto. Sin esto, la del hito de
                        // nombre corto acaba a media tarjeta y la otra sigue
                        // hasta abajo, y lo que se lee es que una de las dos
                        // importa menos.
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (
                                var i = 0;
                                i < widget.options.length;
                                i++
                              ) ...[
                                if (i > 0) const SizedBox(width: 12),
                                Expanded(
                                  child: _Option(
                                    mark: widget.options[i],
                                    place: widget.place,
                                    theme: t,
                                    ink: velo,
                                    chosen: _at == i,
                                    onTap: () => _tap(i),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(height: 1, color: velo.canto),
                    // La respuesta, en una palabra. Era un botón ámbar del
                    // ancho de la tarjeta, que encima de dos retratos es lo
                    // único que se mira.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _at == null
                          ? null
                          : () {
                              widget.onPick(widget.options[_at!]);
                              Navigator.of(context).pop();
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            _at == null ? 'ELEGÍ UNA' : 'QUE EMPIECEN',
                            style: TextStyle(
                              color: _at == null ? velo.tenue : t.accent,
                              fontSize: 11.5,
                              letterSpacing: 2.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        widget.onLeave();
                        Navigator.of(context).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Center(
                          child: Text(
                            'Que decidan ellos',
                            style: t.bodySoft.copyWith(
                              fontSize: 12.5,
                              color: velo.tenue,
                            ),
                          ),
                        ),
                      ),
                    ),
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

/// Una de las dos, con la obra dibujada **en grande y arriba**.
///
/// Dibujada y no descrita: son ciento y pico obras y sus nombres no siempre
/// dicen mucho —«atarazana», «lonja»— y lo que se está decidiendo es qué
/// quiere uno ver en su valle, que es una cosa que se decide mirando. Sale del
/// mismo render que el pueblo, con el mismo sol de ahora mismo.
///
/// En columna y no en fila: el retrato era una miniatura de ochenta y dos
/// píxeles al lado de un párrafo, o sea un icono. Puesto arriba y del ancho de
/// su columna mide el doble, y a ese tamaño ya se distingue una ermita de una
/// atalaya, que es de lo que iba la pregunta.
class _Option extends StatelessWidget {
  const _Option({
    required this.mark,
    required this.place,
    required this.theme,
    required this.ink,
    required this.chosen,
    required this.onTap,
  });

  final Landmark mark;
  final TownCharacter place;
  final UiTheme theme;
  final SheetInk ink;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: chosen
              ? t.accent.withValues(alpha: 0.12)
              : ink.tinte.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: chosen ? t.accent.withValues(alpha: 0.85) : ink.canto,
            width: chosen ? 1.6 : 1,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: CustomPaint(
                  painter: WorkPortrait(
                    mark: mark,
                    place: place,
                    palette: t.palette,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              mark.name,
              style: t.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.2,
                color: ink.cuerpo,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  '${mark.cost}',
                  style: t.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: chosen ? t.accent : ink.suave,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  mark.cost == 1 ? 'pieza' : 'piezas',
                  style: t.bodySoft.copyWith(fontSize: 11, color: ink.tenue),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              mark.blurb,
              style: t.bodySoft.copyWith(
                fontSize: 11.5,
                height: 1.35,
                color: ink.suave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El retrato de una obra terminada, en la región de este pueblo.
///
/// El mismo motor que pinta el valle, encuadrado a ojo de pájaro sobre un
/// trozo de prado. Sin cielo y sin sierra: a ochenta píxeles, un cielo entero
/// es una banda de color que no dice nada y le roba sitio a lo que sí.
class WorkPortrait extends CustomPainter {
  WorkPortrait({
    required this.mark,
    required this.place,
    required this.palette,
  });

  final Landmark mark;
  final TownCharacter place;
  final Palette palette;

  /// Desde dónde se mira una obra para que entre entera en un cuadrado de
  /// [size].
  ///
  /// Aparte y pública para poder exigirle en un test que la obra entre de
  /// verdad. Lo tenía calculado a ojo con el radio y lo estaba fijando sobre
  /// los valores de la cámara en vez de sobre sus objetivos —que `snap()`
  /// copia por encima—, así que ni el encuadre ni el giro eran los que yo
  /// creía y el castillo salía cortado por la mitad. Ninguna de las dos cosas
  /// se ve leyendo el código: se ven mirando el retrato, o midiéndolo.
  static OrbitCamera frame(TownLayout layout, Size size) {
    var top = 1.0;
    final esquinas = <V3>[];
    for (final p in layout.pieces) {
      if (p.y1 > top) top = p.y1;
      esquinas
        ..add(V3(p.x0, p.y0, p.z0))
        ..add(V3(p.x1, p.y1, p.z1))
        ..add(V3(p.x0, p.y1, p.z1))
        ..add(V3(p.x1, p.y0, p.z0));
    }
    final cam = OrbitCamera()
      ..yawTarget = 0.62
      ..pitchTarget = 0.42
      ..focusYTarget = top * 0.44;
    cam.snap();
    // Medido sobre la proyección de verdad y no a ojo con el radio: un
    // castillo mide cuatro veces lo que una fuente, y con una regla al tanteo
    // se cortaban justo las obras que más ganas dan de ver. El margen deja un
    // dedo de aire alrededor.
    cam.distanceTarget = clampD(
      cam.distanceToFit(esquinas, size.width, size.height, margin: 0.80),
      4,
      120,
    );
    cam.snap();
    return cam;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final layout = TownLayout.showcase(
      place,
      landmark: mark,
      placed: mark.cost,
    );
    final cam = frame(layout, size);

    canvas.drawRect(Offset.zero & size, Paint()..color = meadowTone(palette));
    TownPainter(
      TownScene(
        placed: mark.cost,
        palette: palette,
        camera: cam,
        integrity: 1,
        time: 0,
        hourOfDay: palette.hour,
        effects: EffectSystem(),
        labelledBricks: const {},
        budget: 4000,
        towns: [
          TownEntry(
            layout: layout,
            name: mark.name,
            symbol: place.symbol,
            integrity: 1,
            placed: mark.cost,
          ),
        ],
        active: 0,
        labels: false,
      ),
      // Un retrato no se toca, así que el mapa que sale no lo lee nadie.
      TouchMap(),
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(WorkPortrait old) =>
      old.mark.id != mark.id ||
      old.place.order != place.order ||
      old.palette.hour != palette.hour;
}
