import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/rng.dart';
import '../engine/palette.dart';

/// El vuelo al valle: subir por encima de las nubes y volver a bajar.
///
/// Ir del pueblo al valle era un salto: la cámara estaba a quince metros de tu
/// plaza y en el fotograma siguiente a doscientos, mirando a otra parte y con
/// otro giro. No importa cuánto se suavice el movimiento — a esa escala el ojo
/// no reconstruye el camino, sólo registra que el mundo cambió. Y el valle
/// dejaba de ser un sitio al que se va para ser una pantalla que se abre.
///
/// Esto es el camino. Se levanta el vuelo, la tierra se pierde de foco, un
/// banco de nubes sube y otro baja hasta cerrarse en medio, y cuando se abren
/// estás arriba. Lo caro se hace detrás de las nubes, que es donde se ha hecho
/// siempre en cualquier historia que valga.
class CloudFlight extends StatelessWidget {
  const CloudFlight({
    super.key,
    required this.t,
    required this.palette,
    this.seed = 0x5C1E,
  });

  /// Cero al despegar, uno al aterrizar. A la mitad la pantalla está tapada.
  final double t;

  /// La del momento: las nubes de las cuatro de la mañana no son blancas, y el
  /// sol de las siete de la tarde les da por un lado y no por el otro.
  final Palette palette;

  final int seed;

  /// Cuánto tapan las nubes ahora mismo: sube hasta uno a la mitad y baja.
  ///
  /// No es un triángulo sino una campana con los flancos estirados, porque lo
  /// que se está escondiendo es un instante —el corte— y lo que se quiere es
  /// que ese instante quede bien dentro del tapado, no rozándolo.
  static double coverOf(double t) {
    final x = (t.clamp(0.0, 1.0) * 2 - 1).abs();
    final k = 1 - x * x;
    return k * k;
  }

  @override
  Widget build(BuildContext context) {
    final cover = coverOf(t);
    if (cover <= 0.001) return const SizedBox.shrink();
    // El desenfoque no acompaña a las nubes: va por delante. La tierra se
    // pierde de foco antes de que la tape nada, que es lo que hace que el
    // corte se lea como altura y no como una cortina.
    //
    // Y se apaga en cuanto las nubes tapan del todo. Desenfocar la pantalla
    // entera es lo más caro que hay aquí, y justo en el tramo en que no se ve
    // nada de lo que hay debajo no cambia un solo píxel: sale gratis y se nota
    // en los fotogramas por segundo del único momento en que hay dos cosas
    // pesadas a la vez.
    final blur = math.sin(math.pi * t.clamp(0.0, 1.0)) * 16.0 * (1 - cover);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (blur > 0.4)
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: const SizedBox.expand(),
            ),
          CustomPaint(
            painter: _CloudPainter(t: t, palette: palette, seed: seed),
          ),
        ],
      ),
    );
  }
}

/// Los tres tonos de una nube: la panza, el cuerpo y la cara de arriba.
///
/// Tres y no cinco. Con cinco había volumen de sobra y también un contorno
/// oscuro alrededor de cada cúmulo, y eso no es una nube: es una ilustración de
/// una nube, con su línea de tinta. Tres tonos bastan para que se sepa dónde
/// está arriba, y quitando el más oscuro se va el contorno con él.
///
/// **Y los tres son pastel**: mezclados con mucho blanco, así que entre uno y
/// otro hay un paso y no un salto. Lo que hace que se lea el volumen es que los
/// tres estén ordenados, no que estén lejos.
///
/// Salen de la paleta de la hora y no de una lista de grises, que es lo que
/// hace que a las seis de la tarde tiren a miel y de madrugada sean apenas una
/// mancha más clara que la noche — que es lo que es una nube de noche.
class _Tones {
  _Tones(Palette p)
    : sombra = Color.lerp(p.skyHorizon, Colors.white, 0.60)!,
      medio = Color.lerp(p.skyHorizon, Colors.white, 0.80)!,
      // La cara de arriba lleva el color del sol, muy poco: es lo único que
      // dice de qué color es la luz de esta hora.
      luz = Color.lerp(
        Color.lerp(p.skyHorizon, Colors.white, 0.94)!,
        p.sun,
        p.isDaylight ? 0.14 : 0.06,
      )!;

  final Color sombra, medio, luz;
}

class _CloudPainter extends CustomPainter {
  _CloudPainter({required this.t, required this.palette, required this.seed});

  final double t;
  final Palette palette;
  final int seed;

  /// Cuántos cúmulos por canto. Seis es lo que hace falta para que el borde de
  /// un banco se lea como una hilera de nubes y no como una nube sola muy
  /// grande, que es lo que parecía con cuatro.
  static const int _puffs = 6;

  /// Cuántos lóbulos tiene un cúmulo. Ocho: con cinco la silueta salía
  /// triangular y con doce deja de haber silueta, es un círculo.
  static const int _lobes = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final cover = CloudFlight.coverOf(t);
    if (cover <= 0.001) return;

    final tone = _Tones(palette);
    // De qué lado le da la luz. El sol sale por el este y se pone por el
    // oeste, así que esto se da la vuelta a lo largo del día y las nubes de la
    // mañana están encendidas por el otro lado que las de la tarde.
    final hacia = Offset(palette.lightDir.x >= 0 ? 0.68 : -0.68, -0.73);

    final avance = t.clamp(0.0, 1.0);
    final hondo = size.height * 1.15;
    for (var banco = 0; banco < 2; banco++) {
      final sube = banco == 0;
      // Tres pantallas de recorrido: a t=0 y a t=1 el banco está entero fuera,
      // y el tapado sin rendijas va de t=0,3 a t=0,7.
      final centro =
          size.height * (sube ? 2.0 - 3.0 * avance : -1.0 + 3.0 * avance);
      final arriba = centro - hondo / 2, abajo = centro + hondo / 2;
      if (abajo < -size.height || arriba > size.height * 2) continue;

      _bank(canvas, size, arriba, abajo, tone, hacia, banco);
    }
  }

  /// Un banco: el macizo del medio y los cúmulos de sus dos cantos.
  ///
  /// **Macizo por dentro y con forma sólo en los cantos.** Empezó siendo una
  /// nube de cúmulos sueltos, y en una pantalla alta y estrecha eso no tapa: el
  /// cúmulo se mide contra el ancho —si no, no se lee como nube— y una pantalla
  /// de teléfono tiene el doble de alto que de ancho, así que entre hilera e
  /// hilera quedaban rendijas por las que se veía el mundo justo en el
  /// fotograma del corte. Relleno más cantos: el hondo sale gratis y la forma
  /// está donde se ve.
  void _bank(
    Canvas canvas,
    Size size,
    double arriba,
    double abajo,
    _Tones tone,
    Offset hacia,
    int banco,
  ) {
    final ancho = Rect.fromLTRB(-size.width, arriba, size.width * 2, abajo);
    // El macizo no es liso: va de la sombra de la panza al medio de la cara de
    // arriba. Liso, el fotograma en que tapa del todo es un rectángulo de
    // color, y lo que se quiere ahí es estar dentro de una nube.
    canvas.drawRect(
      ancho,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, arriba),
          Offset(0, abajo),
          [tone.luz, tone.medio, tone.sombra],
          [0.0, 0.48, 1.0],
        ),
    );
    // Y por dentro, masas grandes y flojas: lo que se ve al cruzar un banco de
    // nubes no es un color, son claros y oscuros pasando.
    for (var i = 0; i < 4; i++) {
      final s = hash32(seed, 0x11 + banco, i);
      final at = Offset(
        size.width * hashRange(-0.1, 1.1, s, 1),
        arriba + (abajo - arriba) * hashRange(0.05, 0.95, s, 2),
      );
      final r = size.width * hashRange(0.30, 0.55, s, 3);
      final claro = hash01(s, 4) < 0.5;
      _blob(
        canvas,
        at,
        r,
        s,
        (claro ? tone.luz : tone.sombra).withValues(alpha: 0.13),
      );
    }

    // Los cúmulos de los dos cantos, que son los que rompen la raya recta.
    // Los dos y no sólo el de delante: al entrar se ve uno y al salir el otro,
    // y un banco que sale dejando un filo recto es un telón.
    for (var canto = 0; canto < 2; canto++) {
      final y = canto == 0 ? arriba : abajo;
      if (y < -size.height * 0.5 || y > size.height * 1.5) continue;
      // El canto de arriba mira al cielo y el de abajo es la panza: al de
      // abajo la luz le llega de refilón, así que su brillo es mucho menor.
      final arriba0 = canto == 0;
      for (var i = 0; i < _puffs; i++) {
        final s = hash32(seed, banco * 2 + canto, i);
        final x = size.width * ((i + 0.5) / _puffs + hashJitter(0.08, s, 1));
        // Tamaños y alturas bien distintos: con todos iguales y en línea, la
        // hilera se lee como una cenefa y no como un banco de nubes.
        final r = size.width * hashRange(0.17, 0.38, s, 3);
        _cumulus(
          canvas,
          Offset(x, y + r * hashRange(-0.34, 0.16, s, 5) * (arriba0 ? 1 : -1)),
          r,
          s,
          tone,
          arriba0 ? hacia : Offset(hacia.dx, -hacia.dy * 0.35),
          arriba0,
        );
      }
      // Y unos jirones sueltos por delante, que es lo que tiene el borde de un
      // banco de verdad: no termina, se deshilacha.
      for (var i = 0; i < 3; i++) {
        final s = hash32(seed, 0x33 + banco * 2 + canto, i);
        final x = size.width * hashRange(0.0, 1.0, s, 1);
        final fuera = size.width * hashRange(0.10, 0.30, s, 2);
        final r = size.width * hashRange(0.07, 0.14, s, 3);
        _wisp(
          canvas,
          Offset(x, y + (arriba0 ? -fuera : fuera)),
          r,
          s,
          tone.medio.withValues(alpha: hashRange(0.5, 0.85, s, 4)),
        );
      }
    }
  }

  /// Un cúmulo con volumen: tres pasadas, de la panza a la cara de arriba.
  ///
  /// Cada pasada es el mismo racimo de lóbulos encogido y corrido hacia la luz,
  /// así que lo que queda es una cebolla de tres tonos con la cara clara arriba
  /// del lado del sol. Plano y sin degradados, como todo lo que dibuja esta
  /// app: el volumen sale de dónde está cada tono, no de un difuminado.
  ///
  /// **Ninguna pasada es más grande que la primera**, y eso es lo que quita el
  /// contorno. Antes había una pasada de sombra honda un cuatro por ciento más
  /// ancha que el cuerpo: asomaba por todo el borde y lo que se veía era una
  /// línea oscura alrededor de cada nube, o sea una ilustración a tinta.
  void _cumulus(
    Canvas canvas,
    Offset at,
    double r,
    int s,
    _Tones tone,
    Offset hacia,
    bool arriba,
  ) {
    // La panza no tiene cara de arriba: la luz le llega de refilón, así que se
    // queda en dos tonos.
    final capas = arriba
        ? const [(1.00, 0.00, 0), (0.84, 0.13, 1), (0.60, 0.29, 2)]
        : const [(1.00, 0.00, 0), (0.78, 0.15, 1)];
    final tonos = [tone.sombra, tone.medio, tone.luz];
    for (final (escala, corrido, cual) in capas) {
      _blob(
        canvas,
        at + hacia * (corrido * r),
        r * escala,
        s,
        tonos[cual],
        aplanar: arriba ? 0.66 : 0.78,
      );
    }
  }

  /// El racimo de lóbulos. Siempre el mismo para una semilla, así que las cinco
  /// pasadas encogen la *misma* nube y no cinco nubes distintas.
  void _blob(
    Canvas canvas,
    Offset at,
    double r,
    int s,
    Color color, {
    double aplanar = 0.66,
  }) {
    final path = Path();
    for (var k = 0; k < _lobes; k++) {
      final a = k * 2 * math.pi / _lobes + hashRange(0, 0.7, s, 10 + k);
      final d = r * hashRange(0.26, 0.54, s, 20 + k);
      path.addOval(
        Rect.fromCircle(
          center: at + Offset(math.cos(a) * d, math.sin(a) * d * aplanar),
          radius: r * hashRange(0.44, 0.70, s, 30 + k),
        ),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Un jirón: dos óvalos estirados. Lo que se deshilacha del borde.
  void _wisp(Canvas canvas, Offset at, double r, int s, Color color) {
    final path = Path();
    for (var k = 0; k < 2; k++) {
      path.addOval(
        Rect.fromCenter(
          center:
              at + Offset(r * (k == 0 ? -0.5 : 0.5), r * 0.12 * (k * 2 - 1)),
          width: r * hashRange(1.6, 2.6, s, 40 + k),
          height: r * hashRange(0.34, 0.6, s, 50 + k),
        ),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CloudPainter old) =>
      old.t != t || old.palette != palette || old.seed != seed;
}
