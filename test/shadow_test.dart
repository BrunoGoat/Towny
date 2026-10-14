import 'package:flutter_test/flutter_test.dart';
import 'package:towny/core/math3.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/cinema.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/town.dart';

void main() {
  test('la sombra que pasa por detrás de la cámara no desaparece', () {
    // Lo que se vio: al atardecer, con la cámara baja y el sol a la espalda
    // de la casa, su sombra larga llegaba hasta detrás del ojo y se dejaba
    // de pintar entera. Subiendo la vista un pelo, volvía de golpe.
    final pal = Palette.forMoment(18.6);
    final layout = TownLayout(6, TownCharacter.all.first, seed: 3);
    final l = pal.lightDir;
    // Una pieza alta, y la cámara metida dentro de su sombra, mirándola.
    final pc = layout.pieces.reduce((a, b) => a.y1 > b.y1 ? a : b);
    final sombraX = pc.cx - l.x / l.y * pc.y1 * 0.8;
    final sombraZ = pc.cz - l.z / l.y * pc.y1 * 0.8;
    final eye = V3(sombraX, 0.6, sombraZ);
    final forward = (V3(pc.cx, pc.y1 * 0.5, pc.cz) - eye).normalized;
    final right = forward.cross(const V3(0, 1, 0)).normalized;
    final up = right.cross(forward).normalized;
    final p = Projector(
      eye: eye,
      right: right,
      up: up,
      forward: forward,
      focal: 600,
      cx: 200,
      cy: 400,
    );
    final path = castShadowPath(p, pal, [(layout, 6, const [])]);
    final b = path.getBounds();
    expect(b.isEmpty, isFalse, reason: 'la sombra de delante no se pinta');
    // Y llega hasta debajo del borde de la pantalla (de 800 de alto): está a
    // los pies del que mira. Con el fallo, la de esta casa no se pintaba y
    // lo único a la vista eran las de las otras, a media pantalla.
    expect(b.bottom, greaterThan(1000));
  });
}
