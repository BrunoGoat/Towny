import 'dart:math' as math;

import '../core/math3.dart';
import 'town.dart';

/// Hasta dónde se puede alejar la cámara de [target], mirándolo desde
/// [yaw] y [pitch], sin que el ojo quede dentro de algo construido ni con
/// una pared entre él y lo que mira. Como mucho [want], y nunca menos de
/// [atLeast].
///
/// Es para la cámara que sigue a alguien por el pueblo: se pone a cinco
/// metros, por encima de los tejados, y en un pueblo con casas de tres pisos
/// eso a veces era dentro de un tejado —se veía el pueblo desde el desván—.
/// Ahora se acerca lo justo para que entre ella y la persona no haya nada.
///
/// Las cajas son las de cada pieza puesta, un poco infladas [margin] para
/// que el ojo no quede rozando una pared; el rayo sale de [target] y se
/// queda con lo primero que toca. Lo que ya contiene a la persona —con el
/// margen, la pared en la que se apoya— no cuenta.
double clearDistance(
  TownLayout layout,
  int placed,
  V3 target,
  double yaw,
  double pitch,
  double want, {
  double atLeast = 1.4,
  double margin = 0.15,
}) {
  final cp = math.cos(pitch);
  final dx = math.sin(yaw) * cp, dy = math.sin(pitch), dz = math.cos(yaw) * cp;
  var mejor = want + margin;
  final n = math.min(placed, layout.pieces.length);
  final lejos = want + 3;
  for (var i = 0; i < n; i++) {
    final p = layout.pieces[i];
    // Lo que queda lejos de la persona no puede estar en medio.
    if ((p.cx - target.x).abs() > lejos + p.w ||
        (p.cz - target.z).abs() > lejos + p.d) {
      continue;
    }
    final t = _entra(
      target,
      dx,
      dy,
      dz,
      p.x0 - margin,
      p.y0 - margin,
      p.z0 - margin,
      p.x1 + margin,
      p.y1 + margin,
      p.z1 + margin,
    );
    if (t != null && t > 1e-6 && t < mejor) mejor = t;
  }
  return clampD(mejor - margin, atLeast, want);
}

/// Dónde entra en la caja el rayo que sale de [o] hacia (dx, dy, dz), o nulo
/// si no la toca hacia delante.
double? _entra(
  V3 o,
  double dx,
  double dy,
  double dz,
  double x0,
  double y0,
  double z0,
  double x1,
  double y1,
  double z1,
) {
  var t0 = 0.0, t1 = double.infinity;
  for (final (oo, d, lo, hi) in [
    (o.x, dx, x0, x1),
    (o.y, dy, y0, y1),
    (o.z, dz, z0, z1),
  ]) {
    if (d.abs() < 1e-9) {
      if (oo < lo || oo > hi) return null;
      continue;
    }
    var a = (lo - oo) / d, b = (hi - oo) / d;
    if (a > b) (a, b) = (b, a);
    if (a > t0) t0 = a;
    if (b < t1) t1 = b;
    if (t0 > t1) return null;
  }
  return t0;
}
