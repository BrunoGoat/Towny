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
/// Esto es el camino: se levanta el vuelo, la tierra se pierde de foco, se
/// cierra la niebla, y cuando se abre estás arriba. Lo caro se hace detrás de
/// las nubes, que es donde se ha hecho siempre en cualquier historia que valga.
///
/// **Niebla, y sólo niebla.** Llegaron a estar hechas las diez —cúmulos
/// cerrándose, cortinas, un ojo, un remolino, cirros, algodón, ventisca, un
/// picado, un aguacero— y se eligió ésta, así que las otras nueve se fueron con
/// su selector. Es la más callada y la única que no dibuja una sola nube: lo
/// que hace el trabajo es el desenfoque, y las manchas de debajo sólo evitan
/// que sea un color plano. Un viaje de ochocientos milisegundos que se hace
/// veinte veces al día no quiere una coreografía; quiere desaparecer.
class CloudFlight extends StatelessWidget {
  const CloudFlight({
    super.key,
    required this.t,
    required this.palette,
    this.seed = 0x5C1E,
  });

  /// Cero al despegar, uno al aterrizar. A la mitad la pantalla está tapada.
  final double t;

  /// La del momento: la niebla de las cuatro de la mañana no es blanca, y la
  /// de las siete de la tarde tira a miel.
  final Palette palette;

  final int seed;

  /// Cuánto dura el vuelo entero.
  ///
  /// Empezó en un segundo y medio, que es lo que dura un viaje bien contado la
  /// primera vez y una espera todas las demás — y esto se hace cada vez que uno
  /// quiere comparar dos hábitos, o sea muchas. Con esto sigue habiendo
  /// despegue, niebla y llegada, y quedan de sobra los milisegundos tapados que
  /// hacen falta para esconder el corte.
  static const Duration span = Duration(milliseconds: 820);

  /// Cuánto tapa la niebla ahora mismo: sube hasta uno a la mitad y baja.
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
    // El desenfoque no acompaña a la niebla: va por delante. La tierra se
    // pierde de foco antes de que la tape nada, que es lo que hace que el corte
    // se lea como altura y no como una cortina. En este vuelo además es el que
    // más hace: sin silueta que mirar, lo que dice que se está subiendo es que
    // el suelo deja de tener bordes.
    //
    // Y se apaga en cuanto tapa del todo. Desenfocar la pantalla entera es lo
    // más caro que hay aquí, y justo en el tramo en que no se ve nada de lo que
    // hay debajo no cambia un solo píxel: sale gratis y se nota en los
    // fotogramas por segundo del único momento en que hay dos cosas pesadas a
    // la vez.
    final blur = math.sin(math.pi * t.clamp(0.0, 1.0)) * 26.0 * (1 - cover);
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
            painter: _FogPainter(t: t, palette: palette, seed: seed),
          ),
        ],
      ),
    );
  }
}

/// Los tres tonos de la niebla: la panza, el cuerpo y la cara de arriba.
///
/// Tres y no cinco. Con cinco había volumen de sobra y también un contorno
/// oscuro alrededor de cada masa, y eso no es una nube: es una ilustración de
/// una nube, con su línea de tinta.
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
      luz = Color.lerp(
        Color.lerp(p.skyHorizon, Colors.white, 0.94)!,
        p.sun,
        p.isDaylight ? 0.14 : 0.06,
      )!;

  final Color sombra, medio, luz;
}

class _FogPainter extends CustomPainter {
  _FogPainter({required this.t, required this.palette, required this.seed});

  final double t;
  final Palette palette;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final cover = CloudFlight.coverOf(t);
    if (cover <= 0.001) return;
    final tone = _Tones(palette);
    final avance = t.clamp(0.0, 1.0);

    // El velo llega a opaco **antes** de que el tapado llegue a uno. El corte
    // de cámara no es un fotograma: es un tramo, porque ni la animación cae
    // justo en la mitad ni el ojo perdona una rendija que se abre medio
    // parpadeo antes de tiempo.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = tone.medio.withValues(alpha: math.min(1.0, cover * 1.4)),
    );

    // Y por debajo, masas grandes y flojas que van pasando: lo que se ve al
    // cruzar un banco de niebla no es un color, son claros y oscuros.
    for (var i = 0; i < 6; i++) {
      final s = hash32(seed, 0x71, i);
      final deriva = size.width * hashRange(-0.5, 0.5, s, 5) * avance;
      _blob(
        canvas,
        Offset(
          size.width * hashRange(-0.2, 1.2, s, 1) + deriva,
          size.height * hashRange(-0.1, 1.1, s, 2),
        ),
        size.width * hashRange(0.5, 0.95, s, 3),
        s,
        (hash01(s, 4) < 0.5 ? tone.luz : tone.sombra).withValues(
          alpha: cover * 0.30,
        ),
      );
    }
  }

  /// Un racimo de lóbulos. Siempre el mismo para una semilla, así que la masa
  /// que deriva es la misma masa y no una nueva cada fotograma.
  void _blob(Canvas canvas, Offset at, double r, int s, Color color) {
    const lobes = 6;
    final path = Path();
    for (var k = 0; k < lobes; k++) {
      final a = k * 2 * math.pi / lobes + hashRange(0, 0.7, s, 10 + k);
      final d = r * hashRange(0.26, 0.54, s, 20 + k);
      path.addOval(
        Rect.fromCircle(
          center: at + Offset(math.cos(a) * d, math.sin(a) * d * 0.55),
          radius: r * hashRange(0.44, 0.70, s, 30 + k),
        ),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FogPainter old) =>
      old.t != t || old.palette != palette || old.seed != seed;
}
