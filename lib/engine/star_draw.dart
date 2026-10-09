import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'shooting_star.dart';

/// Dónde cae en pantalla un punto del cielo. Lo pone quien llama, porque la
/// cuenta del cielo es del pintor de la escena y el valle y el tablón arman su
/// proyector cada uno por su cuenta.
typedef SkyAim = Offset? Function(double az, double el);

/// Cómo se pinta una fugaz.
///
/// Aparte del pintor del valle porque el tablón de la plaza dibuja su propio
/// cielo y quiere exactamente esto mismo. Cuando eran dos copias, mejorar la
/// del valle dejaba la del tablón como estaba.
///
/// Son dos cosas, y en dos sitios distintos del orden de pintado: [sky] va con
/// el cielo, detrás del pueblo; [land] va al final del todo, porque es luz que
/// cae sobre lo que ya está pintado.
class StarDraw {
  const StarDraw._();

  /// El color de la luz. Frío y con algo de verde, como el de una fugaz de
  /// verdad: el blanco puro sobre un cielo azul de noche no se lee como luz,
  /// se lee como un agujero en la imagen.
  static const Color core = Color(0xFFF2F8FF);
  static const Color halo = Color(0xFFA9CBFF);
  static const Color far = Color(0xFF6E93E8);

  /// La estrella: su estela, su cabeza y el destello de la cabeza.
  static void sky(
    Canvas canvas,
    Size size,
    SkyAim aim,
    double horizonY,
    ShootingStar star,
    double nightAlpha,
  ) {
    final glow = star.glow * nightAlpha;
    if (glow <= 0.012) return;

    Offset? en(double k) {
      final a = star.aim(k);
      return a == null ? null : aim(a.$1, a.$2);
    }

    // La estela arrastra casi un tercio del vuelo: sobre cinco segundos son
    // más de un segundo de cola, y eso es lo que la hace grande. Con la cola
    // corta de antes, lo que cruzaba era un punto.
    const cola = 0.30;
    final chispa = size.shortestSide;

    final head = en(star.u);

    // **La estela es un solo trazo**, una cinta que se afina hacia atrás, y no
    // una fila de rayas. Estuvo hecha de veintiséis tramos con la punta
    // redonda, sumando luz: donde se pisaban dos puntas había el doble de luz,
    // y la cola se veía como una ristra de perlas. Eso, más un halo
    // desenfocado por encima de todo, era lo que la hacía parecer una imagen
    // chica estirada: no tenía ni un borde nítido.
    if (head != null) {
      const pasos = 28;
      final puntos = <Offset>[];
      for (var i = 0; i <= pasos; i++) {
        final p = en(star.u - cola * i / pasos);
        if (p == null) break;
        puntos.add(p);
      }
      if (puntos.length >= 3) {
        final fin = puntos.last;
        // Un halo ancho y apenas difuso, y encima el filo: borde encendido
        // dentro de algo blando, que es lo que se lee como luz.
        for (final (ancho, desenfoque, alfa, color) in [
          (0.030 * chispa, 2.5, 0.30, halo),
          (0.010 * chispa, 0.0, 0.95, core),
        ]) {
          final cinta = _cinta(puntos, ancho);
          canvas.drawPath(
            cinta,
            Paint()
              ..blendMode = BlendMode.plus
              ..isAntiAlias = true
              ..maskFilter = desenfoque > 0
                  ? ui.MaskFilter.blur(ui.BlurStyle.normal, desenfoque)
                  : null
              ..shader = ui.Gradient.linear(
                head,
                fin,
                [
                  color.withValues(alpha: (glow * alfa).clamp(0.0, 1.0)),
                  color.withValues(alpha: (glow * alfa * 0.45).clamp(0.0, 1.0)),
                  color.withValues(alpha: 0),
                ],
                const [0.0, 0.35, 1.0],
              ),
          );
        }
      }
    }

    // Las chispas que se van soltando por el camino. Son lo que separa una
    // raya de luz de algo que se está deshaciendo mientras cae.
    for (var i = 1; i <= 7; i++) {
      final k = i / 8;
      final at = en(star.u - cola * k * 0.92);
      if (at == null || at.dy > horizonY) continue;
      final j = (star.id * 31 + i) % 7;
      final lado = Offset(
        math.sin(j * 1.7 + star.u * 2.2) * chispa * 0.012 * k,
        math.cos(j * 2.3 + star.u * 1.7) * chispa * 0.012 * k,
      );
      canvas.drawCircle(
        at + lado,
        chispa * 0.0028 * (1 - k) + 0.4,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = core.withValues(
            alpha: (glow * 0.8 * (1 - k) * (1 - k)).clamp(0.0, 1.0),
          ),
      );
    }

    if (head == null || head.dy > horizonY) return;

    // El resplandor de la cabeza, más corto y más cerrado que antes: era de
    // un séptimo de la pantalla y se comía la estrella.
    final r = chispa * 0.09;
    canvas.drawCircle(
      head,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          head,
          r,
          [
            core.withValues(alpha: 0.42 * glow),
            halo.withValues(alpha: 0.14 * glow),
            far.withValues(alpha: 0.0),
          ],
          const [0.0, 0.22, 1.0],
        ),
    );

    // El destello: cuatro puntas largas y cuatro cortas en diagonal, afiladas
    // y nítidas, que se apagan hacia la punta. Gira despacio mientras cae.
    _sparkle(canvas, head, chispa * 0.090, star.spin, glow);
    _sparkle(canvas, head, chispa * 0.042, star.spin + math.pi / 4, glow * 0.7);

    // Y el núcleo: un disco blanco de borde limpio con un brillo corto
    // alrededor. Es el punto donde se apoya la vista.
    final brillo = chispa * 0.024;
    canvas.drawCircle(
      head,
      brillo,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          head,
          brillo,
          [
            Colors.white.withValues(alpha: (0.9 * glow).clamp(0.0, 1.0)),
            core.withValues(alpha: (0.35 * glow).clamp(0.0, 1.0)),
            core.withValues(alpha: 0),
          ],
          const [0.0, 0.35, 1.0],
        ),
    );
    canvas.drawCircle(
      head,
      chispa * 0.0075,
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white.withValues(alpha: glow.clamp(0.0, 1.0)),
    );
  }

  /// Una cinta que sigue [puntos] y se afina de [ancho] en el primero a nada
  /// en el último.
  static Path _cinta(List<Offset> puntos, double ancho) {
    final n = puntos.length;
    final izq = <Offset>[], der = <Offset>[];
    for (var i = 0; i < n; i++) {
      final antes = puntos[i == 0 ? 0 : i - 1];
      final despues = puntos[i == n - 1 ? n - 1 : i + 1];
      var d = despues - antes;
      final largo = d.distance;
      d = largo < 1e-6 ? const Offset(1, 0) : d / largo;
      final normal = Offset(-d.dy, d.dx);
      final k = 1 - i / (n - 1);
      final a = ancho / 2 * math.pow(k, 1.2).toDouble();
      izq.add(puntos[i] + normal * a);
      der.add(puntos[i] - normal * a);
    }
    final p = Path()..moveTo(izq.first.dx, izq.first.dy);
    for (final q in izq.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    for (final q in der.reversed) {
      p.lineTo(q.dx, q.dy);
    }
    // La cabeza redonda, para que la cinta no acabe en un corte recto.
    p
      ..close()
      ..addOval(Rect.fromCircle(center: puntos.first, radius: ancho / 2));
    return p;
  }

  /// Cuatro puntas afiladas del largo [len], nítidas, que se apagan hacia
  /// afuera.
  static void _sparkle(
    Canvas canvas,
    Offset at,
    double len,
    double spin,
    double glow,
  ) {
    if (glow <= 0.01) return;
    final ancho = len * 0.07;
    final p = Path();
    for (var i = 0; i < 4; i++) {
      final a = spin + i * math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      final lado = Offset(-dir.dy, dir.dx) * ancho;
      p
        ..moveTo(at.dx + lado.dx, at.dy + lado.dy)
        ..lineTo(at.dx + dir.dx * len, at.dy + dir.dy * len)
        ..lineTo(at.dx - lado.dx, at.dy - lado.dy)
        ..close();
    }
    canvas.drawPath(
      p,
      Paint()
        ..blendMode = BlendMode.plus
        ..isAntiAlias = true
        ..shader = ui.Gradient.radial(
          at,
          len,
          [
            Colors.white.withValues(alpha: (0.95 * glow).clamp(0.0, 1.0)),
            core.withValues(alpha: (0.55 * glow).clamp(0.0, 1.0)),
            halo.withValues(alpha: 0),
          ],
          const [0.0, 0.35, 1.0],
        ),
    );
  }

  /// La luz que echa sobre el pueblo y las montañas.
  ///
  /// No es realista y no pretende serlo: una fugaz de verdad no ilumina nada.
  /// Es luz que barre, que viene de donde viene ella y se mueve con ella, y
  /// está para que uno levante la vista. Sin esto, lo que pasa en el cielo
  /// pasa sólo en el cielo, y mirando al pueblo no te enterás nunca.
  ///
  /// Va después que ella y dura más: cuando la estrella ya se apagó, esto
  /// sigue medio segundo abriéndose y perdiéndose, que es lo que deja la
  /// sensación de que algo pasó.
  static void land(
    Canvas canvas,
    Size size,
    SkyAim aim,
    ShootingStar star,
    double nightAlpha,
  ) {
    final k = star.light * nightAlpha;
    if (k < 0.015) return;
    // Cuando la cabeza ya se apagó, la luz se queda donde estaba y se abre:
    // seguirla hasta el final la sacaría de la pantalla justo mientras se
    // desvanece, y lo que tiene que hacer es deshacerse donde uno la vio.
    final donde = star.aim(math.min(star.u, 0.90));
    if (donde == null) return;
    final at = aim(donde.$1, donde.$2);
    if (at == null) return;

    // Un levantón parejo de toda la escena, flojo: es lo que alcanza a las
    // cordilleras del fondo, que están demasiado lejos del foco para que las
    // toque el degradado.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = far.withValues(alpha: (0.085 * k).clamp(0.0, 1.0)),
    );

    // Y el barrido, desde donde está ella. El pueblo se enciende por el lado
    // que le toca y no entero y por igual, que sería un flash.
    final abre = 0.88 + 0.80 * (1 - star.light);
    final r = size.longestSide * abre;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.plus
        // Cae deprisa y luego despacio. Con la caída suave de antes, el prado
        // entero subía por igual y lo que se veía era niebla, no luz: la luz
        // se lee porque hay diferencia entre lo que alcanza y lo que no.
        ..shader = ui.Gradient.radial(
          at,
          r,
          [
            core.withValues(alpha: (0.46 * k).clamp(0.0, 1.0)),
            halo.withValues(alpha: (0.17 * k).clamp(0.0, 1.0)),
            far.withValues(alpha: (0.045 * k).clamp(0.0, 1.0)),
            const Color(0x00000000),
          ],
          const [0.0, 0.12, 0.38, 1.0],
        ),
    );
  }
}
