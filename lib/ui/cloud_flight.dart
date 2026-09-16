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

  /// La del momento: las nubes de las cuatro de la mañana no son blancas.
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
    final blur = math.sin(math.pi * t.clamp(0.0, 1.0)) * 16.0;
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

class _CloudPainter extends CustomPainter {
  _CloudPainter({required this.t, required this.palette, required this.seed});

  final double t;
  final Palette palette;
  final int seed;

  /// Cuántos cúmulos por banco. Ocho es lo que hace falta para que el borde de
  /// un banco se lea como una hilera de nubes y no como una nube sola muy
  /// grande, que es lo que parecía con cuatro.
  static const int _puffs = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final cover = CloudFlight.coverOf(t);
    if (cover <= 0.001) return;

    // El color de la nube sale del cielo de la hora, aclarado: una nube es el
    // cielo con el sol dentro. Así a las seis de la tarde son de color miel y
    // a las tres de la mañana son una mancha apenas más clara que la noche.
    final alta = Color.lerp(palette.skyTop, Colors.white, 0.72)!;
    final baja = Color.lerp(palette.skyHorizon, Colors.white, 0.58)!;

    // Los dos bancos: uno sube desde abajo y el otro baja desde arriba, y los
    // dos tienen su centro en mitad de la pantalla cuando t vale un medio. Ahí
    // es donde se esconde el corte, así que ahí es donde tienen que estar.
    //
    // **Un banco es macizo por dentro y sólo tiene forma en sus dos cantos.**
    // Empezó siendo una nube de cúmulos sueltos, y en una pantalla alta y
    // estrecha eso no tapa: el cúmulo se mide contra el ancho —si no, no se
    // lee como nube— y una pantalla de teléfono tiene el doble de alto que de
    // ancho, así que entre hilera e hilera quedaban rendijas por las que se
    // veía el mundo justo en el fotograma del corte. Relleno más cantos: el
    // hondo sale gratis y la forma está donde se ve.
    final avance = t.clamp(0.0, 1.0);
    final hondo = size.height * 1.15;
    for (var banco = 0; banco < 2; banco++) {
      final sube = banco == 0;
      // Dos coma seis pantallas de recorrido: a t=0 y a t=1 el banco está
      // entero fuera, y el tapado sin rendijas va de t=0,25 a t=0,75.
      final centro =
          size.height * (sube ? 2.0 - 3.0 * avance : -1.0 + 3.0 * avance);
      final color = sube ? baja : alta;
      final arriba = centro - hondo / 2, abajo = centro + hondo / 2;
      if (abajo < -size.height || arriba > size.height * 2) continue;

      canvas.drawRect(
        Rect.fromLTRB(-size.width, arriba, size.width * 2, abajo),
        Paint()..color = color,
      );
      // Y los cúmulos de los dos cantos, que son los que rompen la raya recta.
      // Los dos y no sólo el de delante: al entrar se ve uno y al salir el
      // otro, y un banco que sale dejando un filo recto es un telón.
      for (var canto = 0; canto < 2; canto++) {
        final y = canto == 0 ? arriba : abajo;
        if (y < -size.height * 0.4 || y > size.height * 1.4) continue;
        for (var i = 0; i < _puffs; i++) {
          final s = hash32(seed, banco * 2 + canto, i);
          final x = size.width * ((i + 0.5) / _puffs + hashJitter(0.07, s, 1));
          final r = size.width * hashRange(0.20, 0.32, s, 3);
          // Cada cúmulo con su tono, entre el del cielo alto y el del bajo.
          // Opacos y de tonos distintos, que es como un banco de nubes se lee
          // como un banco: con todos translúcidos del mismo color, lo que se
          // veía eran discos que se cruzaban, o sea pompas de jabón.
          final tono = Color.lerp(color, canto == 0 ? alta : baja, 0.55)!;
          _puff(canvas, Offset(x, y), r, s, tono);
        }
      }
    }

    // Y un velo general a la altura del cruce, que es el que garantiza que no
    // quede una rendija entre dos cúmulos justo en el fotograma del corte. Muy
    // corto: sólo existe donde las nubes ya tapan casi todo.
    final velo = ((cover - 0.94) / 0.06).clamp(0.0, 1.0);
    if (velo > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = alta.withValues(alpha: velo),
      );
    }
  }

  /// Un cúmulo: cinco lóbulos que se solapan, plano y sin degradado, como todo
  /// lo demás que dibuja esta app.
  void _puff(Canvas canvas, Offset at, double r, int s, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    for (var k = 0; k < 5; k++) {
      final a = k * 2 * math.pi / 5 + hashRange(0, 1.2, s, 10 + k);
      final d = r * hashRange(0.30, 0.52, s, 20 + k);
      path.addOval(
        Rect.fromCircle(
          center: at + Offset(math.cos(a) * d, math.sin(a) * d * 0.62),
          radius: r * hashRange(0.52, 0.78, s, 30 + k),
        ),
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CloudPainter old) =>
      old.t != t || old.palette != palette || old.seed != seed;
}
