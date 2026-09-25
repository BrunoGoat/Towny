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
class ChoiceSheet extends StatelessWidget {
  const ChoiceSheet({
    super.key,
    required this.options,
    required this.place,
    required this.theme,
    required this.onPick,
  });

  final List<Landmark> options;
  final TownCharacter place;
  final UiTheme theme;

  /// Contestar. Tocar una obra **es** elegirla: la tarjeta se cierra y se
  /// empieza. No hay paso de confirmar, y no lo hay a propósito — señalar una
  /// y luego decir que sí es decir dos veces lo mismo, y de las dos la
  /// segunda no añade nada: lo que se elige es una de dos cosas dibujadas, no
  /// un formulario.
  final void Function(Landmark) onPick;

  /// Cerrar sin contestar se hace tocando fuera, que es como se cierra
  /// cualquier cosa que aparece en medio de la pantalla. Entonces deciden
  /// ellos, y de eso se encarga quien abrió la tarjeta: ella no tiene botón
  /// de irse.
  @override
  Widget build(BuildContext context) {
    final t = theme;
    final velo = SheetInk.of(t);
    final alto = MediaQuery.of(context).size.height;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 440, maxHeight: alto * 0.84),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: velo.bruma,
                sigmaY: velo.bruma,
              ),
              // **Material, aunque no se vea ninguno.** Un `showDialog` pone
              // lo suyo en el pasillo de rutas, fuera del `Scaffold`, y ahí
              // arriba no hay ningún `Material` del que heredar tipografía.
              // Flutter entonces escribe con su letra de emergencia: negrita
              // monoespaciada y subrayada en amarillo doble. Salía así en el
              // teléfono —toda la tarjeta subrayada de amarillo— mientras que
              // en el resto de la app no, porque el resto vive dentro de un
              // `Scaffold`. Transparente: no pinta nada, sólo pone letra.
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                  decoration: BoxDecoration(
                    color: velo.tinte.withValues(alpha: velo.tapa),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: velo.canto),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // La pregunta, y nada más que la pregunta. Tenía encima
                      // un rótulo —«EL PUEBLO PREGUNTA»— y debajo un párrafo
                      // explicando las reglas, y las dos cosas sobraban: lo
                      // que hay que hacer se ve.
                      //
                      // Y corta: «¿Qué levantamos ahora?» partía en dos
                      // renglones en un teléfono estrecho, y dos renglones de
                      // título encima de dos dibujos ocupan el sitio de los
                      // dibujos. Tres palabras caben siempre.
                      //
                      // Y encogida antes que partida: en un teléfono de 320
                      // puntos con la letra ancha del sistema no hay sitio ni
                      // para tres palabras, y un título medio punto más chico
                      // se lee igual — uno cortado con puntos suspensivos, no.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '¿Qué construir?',
                            maxLines: 1,
                            softWrap: false,
                            style: t.title.copyWith(
                              color: velo.cuerpo,
                              shadows: velo.aliento,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                                for (var i = 0; i < options.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 10),
                                  Expanded(
                                    child: _Option(
                                      mark: options[i],
                                      place: place,
                                      theme: t,
                                      ink: velo,
                                      onTap: () {
                                        Sensory.instance.tick();
                                        onPick(options[i]);
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ),
                                ],
                              ],
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
    required this.onTap,
  });

  final Landmark mark;
  final TownCharacter place;
  final UiTheme theme;
  final SheetInk ink;

  /// Tocar aquí es elegir esta obra. No hay estado de «señalada» porque no
  /// hay nada después que confirmar.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: ink.tinte.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ink.canto),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Más alto que ancho: casi todo lo que se ofrece aquí es una
            // torre, una nave o una tapia con algo dentro, y encuadrarlo en
            // un cuadrado deja aire arriba y abajo en vez de obra.
            AspectRatio(
              aspectRatio: 0.92,
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
                    color: ink.suave,
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
