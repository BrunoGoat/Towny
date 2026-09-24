import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/math3.dart';
import '../engine/palette.dart';

/// UI chrome derived from whatever the sky is doing right now, so the interface
/// belongs to the scene instead of sitting on top of it.
class UiTheme {
  UiTheme(this.palette) {
    // La luz que hay **detrás de la interfaz**, y ahí estaba el fallo.
    //
    // Los rótulos de arriba y los botones del costado viven sobre el techo del
    // cielo, `skyTop`. El horizonte —la banda clara de más abajo— es lo que
    // tienen detrás las casas, no ellos. Pero era el horizonte el que decidía
    // de qué color iba la interfaz, y a las siete y media de la tarde el
    // horizonte todavía es naranja claro mientras el techo ya es azul de
    // medianoche: la interfaz se pintaba en pardo de mediodía sobre un cielo
    // casi negro y desaparecía. Al amanecer, lo mismo al revés.
    //
    // Y el cielo **sin el abandono encima**: ver [Palette.skyClean]. La
    // ceniza de un pueblo dejado aclara el cielo, y mirando el aclarado la
    // interfaz creía que era de día a las diez de la noche.
    final luz = _luz(palette.skyClean);

    /// Cuánta noche hay ahí arriba, de cero a uno. Sólo para el matiz.
    night = clampD(1 - (luz - 0.16) / 0.40, 0, 1);

    // El paso de una tinta a la otra: **un salto, y en el punto exacto.**
    //
    // Esto se desvanecía de pardo a crema en un cuarto de hora de reloj, y a
    // mitad del desvanecido la tinta es un gris medio. Medido contra el cielo
    // de ese mismo minuto: **1,14 a 1** a las cinco y treinta y cinco de la
    // tarde. Uno a uno es texto invisible; 1,14 es lo mismo con otro nombre.
    // O sea que el arreglo suave costaba ocho minutos de rótulos borrados dos
    // veces al día, justo a la hora en que alguien mira la app al salir del
    // trabajo. Ningún degradado vale eso.
    //
    // Así que se salta. Y el sitio por donde saltar no se elige a ojo: es el
    // cielo en el que las dos tintas se leen **igual de bien**. Por encima de
    // él el pardo va mejor, por debajo el crema, y ahí mismo las dos van a
    // 3,47 a 1 — el mejor peor caso que hay, porque cualquier otro punto del
    // cielo le pide a una de las dos que aguante más allá de donde aguanta.
    // Medido sobre este mismo código: `luz` 0,4589, que con el reloj de
    // verano cae sobre las cinco y diez de la tarde.
    //
    // El salto se ve una vez al atardecer y otra al amanecer, y dura un
    // fotograma. Lo otro duraba ocho minutos.
    const cruce = 0.4589;
    final noche = luz < cruce;

    // Los paneles saltan con ella, en el mismo instante y no antes: ahora que
    // la tinta no pasa por el medio, no hay ningún momento malo del que haya
    // que adelantarse.
    dark = noche;

    // **Lo que sí cambia hora a hora es la tinta dentro de su propio lado.**
    // De día va del pardo frío de mediodía a uno más cálido y un punto más
    // claro según cae la tarde; de noche, del crema de vela del anochecer al
    // crema blanco de las tres de la mañana. Eso es lo que hace que la interfaz
    // sea de esta hora y no de una de dos; lo que no puede hacer es pasar por
    // el medio y quedarse.
    final pardo = Color.lerp(
      const Color(0xFF221D14),
      const Color(0xFF322718),
      clampD(night / 0.40, 0, 1),
    )!;
    final crema = Color.lerp(
      const Color(0xFFEFE2CE),
      const Color(0xFFF3EEE3),
      clampD((night - 0.45) / 0.55, 0, 1),
    )!;
    fg = noche ? crema : pardo;

    // Cerca del salto ninguna de las dos va holgada —3,47 a 1 es lo que hay—
    // así que el halo se refuerza durante los minutos de alrededor. Ya no
    // sostiene un gris imposible; sostiene una tinta buena sobre el cielo que
    // peor la trata.
    _cruce = clampD(1 - (luz - cruce).abs() / 0.045, 0, 1);
    fgSoft = fg.withValues(alpha: 0.62);
    fgFaint = fg.withValues(alpha: 0.34);
    // Deliberately faint. A panel here should read as a change in the air,
    // not as a card sitting on top of the scene.
    panel = dark
        ? const Color(0xFF14131A).withValues(alpha: 0.40)
        : const Color(0xFFFBF7ED).withValues(alpha: 0.42);
    // Still a change in the air, only more of it. What makes a sheet legible
    // is the blur behind it, not paint: at ninety-five per cent it was a card
    // laid over the town and the town might as well not have been there.
    panelStrong = dark
        ? const Color(0xFF14131A).withValues(alpha: 0.58)
        : const Color(0xFFFBF7ED).withValues(alpha: 0.64);
    stroke = fg.withValues(alpha: 0.07);
    accent = palette.accent;
  }

  final Palette palette;
  late final bool dark;

  /// Cuánta noche hay detrás de la interfaz: cero a mediodía, uno de
  /// madrugada, y todo lo de en medio en las dos horas de cada crepúsculo.
  late final double night;

  /// Cuánto de en medio está la tinta ahora mismo. Sólo para el halo.
  late final double _cruce;

  late final Color fg, fgSoft, fgFaint, panel, panelStrong, stroke, accent;

  /// Lo clara que es una franja de cielo, de cero a uno.
  static double _luz(Color c) => c.r * 0.3 + c.g * 0.55 + c.b * 0.15;

  TextStyle get label => TextStyle(
    color: fgSoft,
    fontSize: 9.5,
    letterSpacing: 2.4,
    fontWeight: FontWeight.w600,
  );

  /// La tinta de lo que va **sobre el prado**, que no es la de lo que va sobre
  /// el cielo.
  ///
  /// Toda la interfaz saca su tinta de `skyTop` —el techo del cielo— y eso es
  /// lo correcto para los rótulos de arriba y los botones del costado, que es
  /// lo que tienen detrás. Pero el botón de poner y la fila de hábitos viven
  /// abajo del todo, y lo que tienen detrás es el prado. A las cinco y media
  /// de la tarde el cielo todavía es claro, así que la tinta sale parda
  /// oscura, y parda oscura sobre un verde de pradera al treinta por ciento de
  /// opacidad es exactamente lo que se vio en un teléfono: no se lee nada.
  ///
  /// Un prado es verde medio o verde oscuro a cualquier hora del día, así que
  /// aquí no hay dos casos ni cruce que respetar: va tinta clara y un aliento
  /// oscuro detrás, siempre.
  ///
  /// **Y clara de verdad, no «la del lado claro».** El primer intento fue
  /// pedírsela a [SheetInk], que contesta la misma pregunta para las hojas; y
  /// [SheetInk] de noche escribe con [fg], que es la tinta que cruza de pardo
  /// a crema en un cuarto de hora. Medido: a las cinco y media larga de la
  /// tarde, en mitad de ese cruce, salía un gris medio —luminancia 0,26— que
  /// contra un prado de 0,13 va a uno coma siete a uno. Sobre el vidrio
  /// ahumado de una hoja ese gris se lee igual, porque el vidrio es mucho más
  /// oscuro que el prado; aquí no hay vidrio.
  ///
  /// El cruce existe porque el cielo cambia. El prado no.
  Color get grassInk =>
      Color.lerp(const Color(0xFFF3EEE3), palette.accent, 0.14)!;

  /// Y el aliento oscuro que la despega del prado. Oscuro a cualquier hora,
  /// por lo mismo.
  List<Shadow> get grassHalo => const [
    Shadow(color: Color(0x9E14130E), blurRadius: 10),
    Shadow(color: Color(0x6B14130E), blurRadius: 22),
  ];

  /// A soft halo so type can sit straight on the scene without a card behind
  /// it and still be legible over stone, grass or sky.
  List<Shadow> get halo => [
    Shadow(
      color: (dark ? Colors.black : const Color(0xFF3A3426)).withValues(
        alpha: (dark ? 0.55 : 0.30) * (1 + 0.8 * _cruce),
      ),
      blurRadius: 12 * (1 + 0.35 * _cruce),
    ),
  ];

  TextStyle get number => TextStyle(
    color: fg,
    fontSize: 30,
    height: 1.0,
    fontWeight: FontWeight.w200,
    letterSpacing: -0.8,
    fontFeatures: const [ui.FontFeature.tabularFigures()],
  );

  TextStyle get body => TextStyle(color: fg, fontSize: 14, height: 1.45);

  TextStyle get bodySoft =>
      TextStyle(color: fgSoft, fontSize: 13, height: 1.45);

  TextStyle get title => TextStyle(
    color: fg,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );
}

/// The scrim behind a sheet.
///
/// Light on purpose: the town is the thing, and a sheet that blacks it out is
/// a sheet that could have been any app's.
Color sheetScrim(bool dark) =>
    Colors.black.withValues(alpha: dark ? 0.34 : 0.24);

/// The one surface every sheet in the app is made of.
///
/// Its colour comes from the sky of the moment, so the same sheet is a
/// different colour at dusk and at noon, and what makes the type legible is
/// the blur rather than the paint.
class SheetSurface extends StatelessWidget {
  const SheetSurface({
    super.key,
    required this.theme,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.top = 28,
    this.all = false,
  });

  final UiTheme theme;
  final Widget child;
  final EdgeInsets padding;

  /// How round the top corners are.
  final double top;

  /// True for a sheet that floats rather than sitting on the bottom edge.
  final bool all;

  @override
  Widget build(BuildContext context) {
    final radius = all
        ? BorderRadius.circular(top)
        : BorderRadius.vertical(top: Radius.circular(top));
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: theme.panelStrong,
            borderRadius: radius,
            border: Border.all(color: theme.fg.withValues(alpha: 0.10)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A frosted panel used for every floating surface in the app.
/// La tinta de una hoja puesta sobre el pueblo: de qué color es el vidrio y
/// de qué color se escribe encima.
///
/// Vivía dentro de la hoja de hábitos, que es donde se encontró. Está aquí
/// porque la usan dos pantallas y **tienen que verse iguales**: una hoja
/// ahumada con letra crema y una tarjeta de papel blanco en la misma app son
/// dos apps.
///
/// De noche es siempre lo mismo —oscuro sobre oscuro, que es lo que funciona—
/// y de día es lo mismo también: vidrio **ahumado**. Se probaron quince
/// maneras de hacerlo claro —crema, prado, cielo, escarcha, miel, musgo,
/// pizarra y ocho vidrios de distinta transparencia— y ninguna sobrevivió a un
/// mediodía verde y brillante: una crema casi opaca sobre un prado no es aire
/// espesándose, es un papel puesto encima. Oscurecer separa mejor que aclarar,
/// que es justo lo que ya funcionaba a las once de la noche, y así la hoja se
/// ve igual a cualquier hora en vez de darse la vuelta a las siete de la tarde.
class SheetInk {
  const SheetInk({
    required this.tinte,
    required this.tapa,
    required this.bruma,
    required this.cuerpo,
    this.oscuro = false,
  });

  /// La de esta hora, que es la de siempre con dos números distintos.
  factory SheetInk.of(UiTheme t) {
    final p = t.palette;
    // De noche: oscuro sobre oscuro al noventa y cinco por ciento, que es el
    // número al que se llegó probándolo con un deslizador.
    if (t.dark) {
      return SheetInk(tinte: t.panelStrong, tapa: 0.95, bruma: 0, cuerpo: t.fg);
    }
    // Y de día, ahumado. La tinta va clara encima, y no blanca: crema con una
    // gota del color del pueblo. El blanco de papel sobre esto es lo único que
    // se sigue viendo de fuera.
    return SheetInk(
      tinte: Color.lerp(p.ink, Colors.black, 0.30)!,
      tapa: 0.72,
      bruma: 18,
      cuerpo: Color.lerp(const Color(0xFFF3EEE3), p.accent, 0.16)!,
      oscuro: true,
    );
  }

  /// De qué color está teñido el vidrio.
  final Color tinte;

  /// Y cuánto pinta: cero es un cristal limpio, uno es una pared.
  final double tapa;

  /// Cuánto desenfoca lo que queda debajo. En estos diez es lo que hace el
  /// trabajo, más que la pintura.
  final double bruma;

  /// La tinta de todo lo que se escribe encima.
  final Color cuerpo;

  /// Si el vidrio oscurece el pueblo en vez de aclararlo. Cambia el rojo del
  /// botón de borrar, que es lo único que no sale de [cuerpo].
  final bool oscuro;

  /// Lo mismo, apagado: para lo que acompaña y no es el nombre.
  Color get suave => cuerpo.withValues(alpha: 0.66);

  /// Y más apagado todavía, para lo que sólo rotula.
  Color get tenue => cuerpo.withValues(alpha: 0.46);

  /// El canto del vidrio, cuando hace falta dibujarlo.
  Color get canto => cuerpo.withValues(alpha: 0.18);

  /// El aliento que va detrás de las letras: el propio color del velo, soplado
  /// alrededor. El velo es casi transparente —es un vidrio, esa es la gracia—
  /// así que el texto cae encima de la plaza y se pierde entre una fuente y
  /// medio tejado. Esto espesa el velo **sólo donde hay letra**: no se lee como
  /// una sombra, se lee como que ahí el cristal está un poco más empañado.
  List<Shadow> get aliento => [
    Shadow(color: tinte.withValues(alpha: 0.95), blurRadius: 10),
    Shadow(color: tinte.withValues(alpha: 0.75), blurRadius: 22),
  ];
}

class Frosted extends StatelessWidget {
  const Frosted({
    super.key,
    required this.child,
    required this.theme,
    this.radius = 22,
    this.padding = const EdgeInsets.all(14),
    this.strong = false,
    this.onTap,
  });

  final Widget child;
  final UiTheme theme;
  final double radius;
  final EdgeInsets padding;
  final bool strong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: strong ? 30 : 18,
          sigmaY: strong ? 30 : 18,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: strong ? theme.panelStrong : theme.panel,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: theme.stroke),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

/// A camera control: just the glyph, with a breath of shade behind it so it
/// stays readable over stone or sky. No disc, no border.
class GhostButton extends StatefulWidget {
  const GhostButton({
    super.key,
    this.icon,
    this.glyph,
    required this.theme,
    required this.onTap,
    this.tooltip,
    this.dot,
  }) : assert(icon != null || glyph != null, 'un botón sin nada dentro');

  /// Un punto arriba a la derecha, de este color. Null es sin punto.
  ///
  /// Lo pone quien sabe si hay algo que mirar al otro lado; el botón sólo
  /// sabe dibujarlo. Va suelto y sin número: lo que dice es «hay algo nuevo»,
  /// y cuántas cosas nuevas hay se ve entrando.
  final Color? dot;

  final IconData? icon;

  /// Un dibujo propio en lugar de un icono de la tipografía, para cuando lo
  /// que hay al otro lado tiene una forma que ningún icono suelto se parece.
  /// Recibe el color, que cambia al apretar.
  final Widget Function(Color color)? glyph;
  final UiTheme theme;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final b = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            children: [
              Positioned.fill(child: Center(child: _dentro(t))),
              if (widget.dot != null)
                Positioned(
                  right: 7,
                  top: 7,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.dot,
                      shape: BoxShape.circle,
                      // Un anillo del color del cielo debajo, para que el punto
                      // se despegue del icono tenga detrás lo que tenga: sobre
                      // el prado de mediodía y sobre el cielo de noche.
                      boxShadow: [
                        BoxShadow(
                          color: (t.dark ? Colors.black : Colors.white)
                              .withValues(alpha: 0.5),
                          blurRadius: 3,
                          spreadRadius: 1.2,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return widget.tooltip == null
        ? b
        : Tooltip(message: widget.tooltip!, child: b);
  }

  Widget _dentro(UiTheme t) => widget.glyph != null
      ? widget.glyph!(t.fg.withValues(alpha: _down ? 0.95 : 0.62))
      : Icon(
          widget.icon,
          size: 20,
          color: t.fg.withValues(alpha: _down ? 0.95 : 0.62),
          shadows: t.halo,
        );
}
