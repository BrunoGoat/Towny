import 'dart:math' as math;

import '../engine/mason.dart';

/// One landmark: a thing the town builds that marks an era rather than a week.
///
/// A landmark is a recipe, not a model. Everything here is written in the
/// mason's vocabulary, which is why there can be a hundred of them instead of
/// four — and why a new one is a dozen lines rather than a new renderer.
class Landmark {
  Landmark(this.id, this.name, this.cost, this.tier, this.blurb, this.build);

  /// Stable identity. Never reuse one: it is what a saved town remembers.
  final String id;

  final String name;

  /// One line, said once, the day it is finished. A landmark arrives every two
  /// or three weeks: it is worth having something to say about it.
  final String blurb;

  /// How many achievements it takes to finish.
  final int cost;

  /// How grand it is: 0 is a well or a pigsty, 2 is a cathedral. The town
  /// builds small things early and grand things once it has grown into them.
  final int tier;

  final void Function(Mason m) build;

  /// How much room the town keeps clear around this landmark.
  ///
  /// Fixed per tier, deliberately, rather than measured from the recipe. The
  /// spacing decides where every later building goes, so if it moved when a
  /// recipe was edited then widening a mill's sails would shuffle the whole
  /// town — and a town that rearranges itself when the app updates is not a
  /// record of anything. Tiers never change; recipes may.
  double get room => const [2.6, 4.0, 6.4][tier];

  /// How far the recipe actually reaches from its own middle, measured by
  /// building it once. Used for framing the camera and for the test that keeps
  /// a recipe inside the room its tier is given — never for the layout.
  double get reach => _reach ??= _measure();
  double? _reach;

  double _measure() {
    final m = Mason(0, 0, 0x5EED, true);
    build(m);
    var r = 0.0;
    for (final s in m.finish(cost)) {
      final far = math.max(s.cx.abs() + s.w / 2, s.cz.abs() + s.d / 2);
      if (far > r) r = far;
    }
    return r;
  }
}

/// Everything the town knows how to build.
///
/// The order here is not the order they are built in — [LandmarkPlan] shuffles
/// within each tier — so entries can be appended freely without moving anything
/// that is already standing in somebody's town.
final List<Landmark> landmarks = [
  // ------------------------------------------------------------------ tier 0
  // The small works: a day's walk apart in a real village, a week apart here.
  Landmark(
    'pozo',
    'Pozo del concejo',
    6,
    0,
    'Ya no hay que bajar al río. Un pueblo empieza cuando tiene agua propia.',
    (m) {
      m.plinth(1.2, 1.2, 0.22);
      m.parapet(0.95, 0.95, 0.55);
      m.post(0.14, 1.05, dx: -0.38, at: 0.77);
      m.post(0.14, 1.05, dx: 0.38, at: 0.77);
      m.beam(0.95, 0.18, 0.12, at: 1.82);
      m.roof(1.25, 1.0, 0.34, at: 1.94);
    },
  ),

  Landmark(
    'cruz',
    'Cruz de término',
    6,
    0,
    'Marca dónde termina el pueblo. Que haya que marcarlo ya dice bastante.',
    (m) {
      m.plinth(1.4, 1.4, 0.2);
      m.plinth(1.0, 1.0, 0.2);
      m.plinth(0.7, 0.7, 0.2);
      m.post(0.24, 1.5, at: 0.6);
      m.beam(0.8, 0.2, 0.18, at: 1.75);
      m.post(0.2, 0.35, at: 2.1);
    },
  ),

  Landmark(
    'palomar',
    'Palomar',
    6,
    0,
    'Palomas para la mesa y para las cartas. Las dos cosas hacían falta.',
    (m) {
      m.plinth(1.6, 1.6, 0.24);
      m.floor(1.25, 1.25, 1.0);
      m.floor(1.15, 1.15, 0.9);
      m.parapet(1.35, 1.35, 0.24);
      m.dome(1.2, 1.2, 0.62);
      m.tree(0.85, 1.3, dx: 1.3, dz: 1.1);
    },
  ),

  Landmark(
    'colmenar',
    'Colmenar',
    6,
    0,
    'Miel, cera para las velas y, con suerte, nadie picado.',
    (m) {
      m.palisade(2.6, 0.7, dz: -1.2);
      m.palisade(2.6, 0.7, dz: 1.2);
      for (var i = 0; i < 3; i++) {
        m.dome(0.42, 0.42, 0.4, dx: -0.75 + i * 0.75, dz: -0.35, at: 0);
      }
      m.tree(1.0, 1.6, dx: 1.4, dz: 0.8);
    },
  ),

  Landmark(
    'huerto',
    'Huerto del cura',
    6,
    0,
    'Cuatro bancales y un cerco. Lo que se come el cura y lo que reparte.',
    (m) {
      m.field(2.4, 1.2, dz: -0.7);
      m.field(2.4, 1.2, dz: 0.7);
      m.palisade(2.8, 0.6, dz: -1.4);
      m.palisade(2.8, 0.6, dz: 1.4);
      m.tree(1.0, 1.6, dx: -1.5);
      m.tree(0.95, 1.5, dx: 1.5);
    },
  ),

  Landmark(
    'pajar',
    'Pajar',
    6,
    0,
    'La paja del verano, para el invierno. Guardar es una manera de tener fe.',
    (m) {
      m.plinth(2.3, 1.8, 0.2);
      m.floor(2.0, 1.55, 1.15);
      m.roof(2.35, 1.9, 0.85);
      m.dormer(0.5, 0.45, dz: 0.35);
      m.field(2.0, 0.9, dz: -1.6);
      m.palisade(2.4, 0.6, dz: -2.1);
    },
  ),

  Landmark(
    'corral',
    'Corral',
    6,
    0,
    'Un cerco de estacas y ya nadie se pierde por la noche.',
    (m) {
      m.palisade(3.0, 0.9, dz: -1.5);
      m.palisade(3.0, 0.9, dz: 1.5);
      m.palisade(3.0, 0.9, dx: -1.5, along: false);
      m.palisade(3.0, 0.9, dx: 1.5, along: false);
      m.floor(1.2, 1.0, 0.85, dx: -0.8, dz: -0.8);
      m.roof(1.4, 1.2, 0.4, dx: -0.8, dz: -0.8);
    },
  ),

  Landmark(
    'gallinero',
    'Gallinero',
    5,
    0,
    'Huevos todos los días. La costumbre más antigua que hay.',
    (m) {
      m.plinth(1.5, 1.2, 0.3);
      m.floor(1.25, 1.0, 0.7);
      m.roof(1.45, 1.2, 0.4);
      m.palisade(2.2, 0.6, dz: 1.2);
      m.palisade(2.2, 0.6, dx: 1.1, along: false);
    },
  ),

  Landmark(
    'alfar',
    'Alfarería',
    7,
    0,
    'Barro, torno y horno. Todo lo que contiene algo en este pueblo nació en esta rueda.',
    (m) {
      m.plinth(2.1, 1.8, 0.2);
      m.floor(1.75, 1.5, 1.0);
      m.roof(2.0, 1.75, 0.55);
      m.dome(1.0, 1.0, 0.8, dx: 1.45, at: 0);
      m.box(PieceKind.chimney, 0.22, 0.22, 0.4, dx: 1.45, ridge: true, at: 0.6);
      m.water(0.9, 0.9, dx: -1.4, dz: 0.8);
      m.post(0.16, 0.9, dx: -1.4, dz: -0.7);
    },
  ),

  Landmark(
    'camposanto',
    'Camposanto',
    8,
    0,
    'Tapia, cipreses y una cruz. A partir de hoy hay gente que se quedó.',
    (m) {
      m.palisade(3.0, 0.75, dz: -1.5);
      m.palisade(3.0, 0.75, dz: 1.5);
      m.palisade(3.0, 0.75, dx: -1.5, along: false);
      m.palisade(3.0, 0.75, dx: 1.5, along: false);
      m.plinth(0.9, 0.9, 0.22, dz: -0.3);
      m.post(0.2, 1.3, dz: -0.3, at: 0.22);
      m.beam(0.7, 0.18, 0.16, dz: -0.3, at: 1.4);
      m.tree(1.2, 2.4, dx: 0.9, dz: 0.9);
    },
  ),

  Landmark(
    'atalaya',
    'Atalaya',
    8,
    0,
    'Se ve venir a quien viene. Dormir tranquilo también se construye.',
    (m) {
      m.plinth(1.7, 1.7, 0.32);
      m.shaft(1.3, 4, 0.8);
      m.parapet(1.55, 1.55, 0.4);
      m.spire(1.3, 1.3, 0.8);
      m.banner(0.9, at: 4.72);
    },
  ),

  Landmark(
    'almenara',
    'Almenara',
    9,
    0,
    'Un fuego arriba, y en una hora lo sabe todo el valle.',
    (m) {
      m.plinth(1.9, 1.9, 0.3);
      m.stair(1.0, 0.5, 0.9, dz: -1.2);
      m.shaft(1.4, 3, 0.85);
      m.parapet(1.7, 1.7, 0.42);
      m.box(PieceKind.chimney, 0.8, 0.8, 0.5);
      m.banner(1.0, at: 3.70);
      m.palisade(2.6, 0.6, dz: 1.4);
    },
  ),

  // ------------------------------------------------------------------ tier 1
  // The works of a town that has stopped being a hamlet.
  Landmark(
    'molinoViento',
    'Molino de viento',
    17,
    1,
    'Aspas contra el poniente y trigo alrededor. El pueblo ya muele su propio pan.',
    (m) {
      m.field(3.2, 1.4, dz: -2.2);
      m.field(3.2, 1.4, dz: 2.2);
      m.field(1.4, 2.6, dx: -2.4);
      m.plinth(2.3, 2.3, 0.4);
      m.shaft(1.85, 5, 0.72, taper: 0.09);
      m.parapet(1.9, 1.9, 0.3);
      m.spire(1.75, 1.75, 1.0);
      m.sails(3.8, dz: -1.25, at: 4.15);
      m.stair(0.9, 0.4, 0.8, dz: 1.5);
      m.outbuilding(1.2, 1.0, 0.8, 0.45, dx: 2.0, dz: 1.4);
      m.palisade(3.0, 0.6, dz: -3.0);
      m.tree(1.0, 1.8, dx: 2.4, dz: -1.6);
    },
  ),

  Landmark(
    'almazara',
    'Almazara y olivar',
    14,
    1,
    'Olivos viejos y una viga que aprieta. Aceite para la mesa y para las lámparas.',
    (m) {
      m.plinth(2.7, 2.1, 0.3, dz: 1.0);
      m.floor(2.4, 1.85, 1.15, dz: 1.0);
      m.roof(2.75, 2.2, 0.75, dz: 1.0);
      m.chimney(0.3, 0.85, dx: 0.8, dz: 1.0);
      m.plinth(1.5, 1.5, 0.3, dx: -1.9, dz: 1.0);
      m.post(0.3, 1.5, dx: -1.9, dz: 1.0, at: 0.3);
      m.beam(1.5, 0.25, 0.2, dx: -1.9, dz: 1.0, at: 1.8);
      m.tree(1.3, 1.9, dx: -1.6, dz: -1.6);
      m.tree(1.3, 1.8, dx: 0.0, dz: -1.9);
      m.tree(1.3, 2.0, dx: 1.6, dz: -1.5);
      m.tree(1.2, 1.7, dx: -2.4, dz: -0.2);
      m.tree(1.2, 1.8, dx: 2.4, dz: -0.4);
      m.field(3.6, 1.2, dz: -2.7);
      m.dormer(0.55, 0.5, dz: 1.5);
    },
  ),

  Landmark(
    'cerveceria',
    'Cervecería',
    12,
    1,
    'Cebada, agua y tiempo. Y un sitio donde acaba el día.',
    (m) {
      m.plinth(2.6, 2.1, 0.3);
      m.floor(2.3, 1.85, 1.15);
      m.floor(2.25, 1.8, 0.95);
      m.roof(2.65, 2.2, 0.8);
      m.dome(1.1, 1.1, 0.85, dx: 1.75, at: 0);
      m.box(
        PieceKind.chimney,
        0.26,
        0.26,
        0.5,
        dx: 1.75,
        ridge: true,
        at: 0.65,
      );
      m.chimney(0.34, 1.0, dx: -0.7);
      m.dormer(0.6, 0.55, dz: 0.5);
      m.water(1.0, 1.0, dx: -1.9, dz: 0.9);
      m.post(0.2, 1.1, dx: -1.9, dz: -0.9);
      m.beam(0.8, 0.8, 0.14, dx: -1.9, dz: -0.9, at: 1.1);
      m.field(2.4, 1.0, dz: -2.0);
    },
  ),

  Landmark(
    'mercado',
    'Mercado cubierto',
    14,
    1,
    'Un techo, unas arcadas y un día fijo a la semana. Aquí empieza a haber dinero.',
    (m) {
      m.plinth(3.6, 2.8, 0.28);
      m.arcade(3.4, 1.5, 2.6, rise: true);
      m.beam(3.5, 2.7, 0.22);
      m.floor(3.2, 2.5, 0.95);
      m.roof(3.7, 3.0, 0.95);
      m.dormer(0.7, 0.6, dz: 0.9);
      m.dormer(0.7, 0.6, dz: -0.9);
      m.chimney(0.3, 0.85, dx: 1.2);
      m.banner(1.1, dx: -1.5, dz: 1.3, at: 1.7);
      m.banner(1.1, dx: 1.5, dz: 1.3, at: 1.7);
      m.box(PieceKind.parapet, 0.8, 0.8, 0.3, dx: -2.3, dz: 1.5, at: 0);
      m.post(0.2, 1.4, dx: -2.3, dz: 1.5, at: 0.3);
      m.stair(1.4, 0.28, 0.7, dz: 1.7);
      m.tree(1.1, 2.0, dx: 2.4, dz: -1.4);
    },
  ),

  Landmark(
    'salinas',
    'Salinas',
    15,
    1,
    'Charcas cuadradas y sol. La sal es lo que hace que el invierno se pueda comer.',
    (m) {
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 2; j++) {
          m.water(1.5, 1.5, dx: -1.7 + i * 1.7, dz: -0.9 + j * 1.8);
        }
      }
      m.palisade(3.4, 0.4, dz: -2.0);
      m.palisade(3.4, 0.4, dz: 2.0);
      m.plinth(1.6, 1.3, 0.34, dx: 2.4, dz: -1.2);
      m.floor(1.35, 1.1, 0.85, dx: 2.4, dz: -1.2);
      m.roof(1.6, 1.35, 0.45, dx: 2.4, dz: -1.2);
      m.dome(1.0, 1.0, 0.9, dx: 2.4, dz: 1.2, at: 0);
      m.post(0.16, 1.2, dx: -2.6, dz: 0.0);
      m.beam(0.6, 3.0, 0.14, dx: -2.6, at: 1.2);
      m.box(PieceKind.parapet, 3.4, 0.3, 0.22, dz: 0.0, at: 0);
    },
  ),

  Landmark(
    'ceca',
    'Casa de la moneda',
    14,
    1,
    'Moneda propia, con la marca del pueblo. Pocos sitios llegan a esto.',
    (m) {
      m.plinth(3.0, 2.3, 0.4);
      m.floor(2.7, 2.0, 1.2);
      m.floor(2.65, 1.95, 1.05);
      m.parapet(2.95, 2.25, 0.35);
      m.roof(2.9, 2.2, 0.7);
      m.chimney(0.34, 1.0, dx: -0.9);
      m.chimney(0.3, 0.9, dx: 0.9);
      m.arcade(2.6, 0.9, 0.45, dz: 1.2, at: 0.4);
      m.palisade(3.2, 0.9, dz: -1.6);
      m.palisade(3.2, 0.9, dx: -1.9, along: false);
      m.palisade(3.2, 0.9, dx: 1.9, along: false);
      m.banner(1.0, dx: -1.0, dz: 1.3, at: 2.1);
      m.banner(1.0, dx: 1.0, dz: 1.3, at: 2.1);
      m.stair(1.3, 0.4, 0.7, dz: 1.6);
    },
  ),

  Landmark(
    'tejedores',
    'Gremio de tejedores',
    13,
    1,
    'Telares en la planta alta y un gremio que fija el precio. El oficio se defiende junto.',
    (m) {
      m.plinth(2.8, 2.2, 0.32);
      m.floor(2.5, 1.95, 1.15);
      m.floor(2.45, 1.9, 1.05);
      m.floor(2.4, 1.85, 0.95);
      m.roof(2.85, 2.3, 0.85);
      m.dormer(0.7, 0.62, dz: 0.85);
      m.dormer(0.7, 0.62, dz: -0.85);
      m.chimney(0.3, 0.9, dx: -0.9);
      m.banner(1.0, dz: 1.25, at: 2.4);
      m.post(0.16, 1.6, dx: -1.8, dz: 1.4);
      m.post(0.16, 1.6, dx: 1.8, dz: 1.4);
      m.beam(3.8, 0.9, 0.14, dz: 1.4, at: 1.6);
      m.field(2.4, 0.9, dz: -1.9);
    },
  ),

  Landmark(
    'hospederia',
    'Hospital de peregrinos',
    15,
    1,
    'Camas para los que van de paso rezando. Se les da lo que haga falta y no se pregunta.',
    (m) {
      m.plinth(3.4, 2.4, 0.34);
      m.floor(3.1, 2.15, 1.2);
      m.floor(3.05, 2.1, 1.05);
      m.roof(3.45, 2.5, 0.9);
      m.arcade(3.0, 1.05, 0.6, dz: 1.25, at: 0.34);
      m.beam(3.2, 0.65, 0.18, dz: 1.25, at: 1.39);
      m.roof(3.4, 1.0, 0.4, dz: 1.35, at: 1.57);
      m.dormer(0.7, 0.6, dx: -1.0, dz: 0.8);
      m.dormer(0.7, 0.6, dx: 1.0, dz: 0.8);
      m.chimney(0.32, 0.95, dx: -1.2);
      m.box(PieceKind.parapet, 0.7, 0.3, 0.55, at: 2.59);
      m.post(0.18, 0.4, at: 3.14);
      m.water(1.0, 1.0, dx: -2.4, dz: -1.0);
      m.tree(1.2, 2.2, dx: 2.4, dz: -1.2);
      m.palisade(3.0, 0.6, dz: -1.9);
    },
  ),

  Landmark(
    'botica',
    'Botica',
    11,
    1,
    'Frascos, hierbas y un libro. Empieza a haber remedio para algunas cosas.',
    (m) {
      m.plinth(2.3, 1.9, 0.3);
      m.floor(2.0, 1.65, 1.1);
      m.floor(1.95, 1.6, 1.0);
      m.floor(1.9, 1.55, 0.9);
      m.roof(2.35, 2.0, 0.75);
      m.dormer(0.6, 0.55, dz: 0.7);
      m.banner(0.8, dx: 0.8, dz: 1.05, at: 1.5);
      m.chimney(0.28, 0.85, dx: -0.6);
      m.field(1.8, 0.8, dz: -1.6);
      m.tree(0.9, 1.6, dx: 1.6, dz: -1.2);
      m.palisade(2.0, 0.55, dz: -2.1);
    },
  ),

  Landmark(
    'escuela',
    'Escuela de gramática',
    13,
    1,
    'Latín y cuentas para quien quiera. A partir de hoy se puede salir de aquí sabiendo.',
    (m) {
      m.plinth(3.0, 2.2, 0.34);
      m.floor(2.7, 1.95, 1.2);
      m.floor(2.65, 1.9, 1.05);
      m.roof(3.05, 2.3, 0.85);
      m.arcade(2.6, 1.0, 0.55, dz: 1.15, at: 0.34);
      m.beam(2.8, 0.6, 0.16, dz: 1.15, at: 1.34);
      m.dormer(0.65, 0.6, dx: -0.8, dz: 0.75);
      m.dormer(0.65, 0.6, dx: 0.8, dz: 0.75);
      m.chimney(0.3, 0.9, dx: -1.0);
      m.box(PieceKind.parapet, 0.6, 0.5, 0.45, at: 2.59);
      m.banner(0.8, at: 3.04);
      m.tree(1.2, 2.2, dx: -2.2, dz: 1.3);
      m.stair(1.3, 0.34, 0.65, dz: 1.55);
    },
  ),

  Landmark(
    'escribania',
    'Escribanía',
    12,
    1,
    'Alguien que sabe escribir lo que se acuerda. Las palabras dejan de perderse.',
    (m) {
      m.plinth(2.5, 2.0, 0.32);
      m.floor(2.2, 1.75, 1.15);
      m.floor(2.15, 1.7, 1.05);
      m.floor(2.1, 1.65, 0.95);
      m.roof(2.55, 2.05, 0.8);
      m.dormer(0.6, 0.55, dz: 0.75);
      m.chimney(0.3, 0.9, dx: -0.7);
      m.chimney(0.26, 0.8, dx: 0.7);
      m.banner(0.9, dz: 1.1, at: 2.2);
      m.arcade(2.1, 0.9, 0.45, dz: 1.0, at: 0.32);
      m.tree(1.0, 1.9, dx: 1.8, dz: 1.2);
      m.stair(1.1, 0.32, 0.6, dz: 1.4);
    },
  ),

  Landmark(
    'capilla',
    'Capilla',
    12,
    1,
    'Campana propia. Ahora las horas del pueblo las marca el pueblo.',
    (m) {
      m.plinth(2.4, 3.2, 0.34);
      m.floor(2.1, 2.9, 1.35);
      m.roof(2.45, 3.25, 1.0, along: false);
      m.box(PieceKind.floor, 1.0, 1.0, 2.6, dz: -2.1, ridge: true, at: 0);
      m.box(PieceKind.parapet, 1.2, 1.2, 0.3, dz: -2.1, ridge: true, at: 2.6);
      m.spire(1.05, 1.05, 1.0, dz: -2.1, at: 2.9);
      m.box(PieceKind.parapet, 0.6, 0.26, 0.5, at: 1.69);
      m.arcade(2.0, 0.9, 0.4, dz: 1.5, at: 0.34);
      m.tree(1.2, 2.3, dx: 1.9, dz: 1.4);
      m.palisade(2.6, 0.55, dx: -1.7, along: false);
      m.stair(1.2, 0.34, 0.6, dz: 1.85);
      m.banner(0.7, dz: -2.1, at: 3.75);
    },
  ),

  Landmark(
    'campanario',
    'Campanario exento',
    13,
    1,
    'Suelto, alto, y se oye desde las eras. Para la misa, para el fuego y para el peligro.',
    (m) {
      m.plinth(2.2, 2.2, 0.42);
      m.shaft(1.7, 5, 0.85, taper: 0.07);
      m.arcade(1.5, 0.9, 1.5, rise: true);
      m.parapet(1.95, 1.95, 0.4);
      m.spire(1.7, 1.7, 1.3);
      m.stair(1.0, 0.42, 0.75, dz: 1.3);
      m.banner(0.9, at: 7.1);
      m.tree(1.1, 2.1, dx: 1.9, dz: 1.4);
      m.palisade(2.4, 0.5, dz: -1.5);
    },
  ),

  Landmark(
    'claustro',
    'Claustro',
    18,
    1,
    'Cuatro galerías, un pozo y silencio en medio. El sitio más quieto que hay.',
    (m) {
      m.plinth(4.0, 4.0, 0.26);
      for (final s in [-1.0, 1.0]) {
        m.arcade(3.6, 1.15, 0.7, dz: s * 1.55, at: 0.26, along: true);
        m.arcade(3.6, 1.15, 0.7, dx: s * 1.55, at: 0.26, along: false);
      }
      for (final s in [-1.0, 1.0]) {
        m.beam(3.9, 0.8, 0.18, dz: s * 1.55, at: 1.41);
        m.beam(0.8, 3.9, 0.18, dx: s * 1.55, at: 1.41);
      }
      for (final s in [-1.0, 1.0]) {
        m.roof(4.1, 1.1, 0.5, dz: s * 1.6, at: 1.59, along: true);
        m.roof(1.1, 4.1, 0.5, dx: s * 1.6, at: 1.59, along: false);
      }
      m.water(1.2, 1.2);
      m.plinth(0.8, 0.8, 0.3);
      m.tree(1.0, 1.7, dx: -0.9, dz: 0.9);
      m.tree(1.0, 1.6, dx: 0.9, dz: -0.9);
      m.field(1.0, 1.0, dx: 0.9, dz: 0.9);
    },
  ),

  Landmark(
    'refectorio',
    'Refectorio',
    13,
    1,
    'Una mesa larga y todos comiendo a la vez. Muchas cosas se arreglan así.',
    (m) {
      m.plinth(3.8, 2.4, 0.34);
      m.floor(3.5, 2.1, 1.45);
      m.roof(3.85, 2.5, 1.0);
      m.arcade(3.4, 1.1, 0.55, dz: 1.2, at: 0.34);
      m.dormer(0.7, 0.62, dx: -1.2, dz: 0.8);
      m.dormer(0.7, 0.62, dx: 0.0, dz: 0.8);
      m.dormer(0.7, 0.62, dx: 1.2, dz: 0.8);
      m.chimney(0.34, 1.0, dx: -1.5);
      m.box(PieceKind.parapet, 0.6, 0.26, 0.5, at: 1.79);
      m.field(2.6, 1.0, dz: -1.9);
      m.tree(1.1, 2.0, dx: -2.5, dz: 1.3);
      m.tree(1.1, 1.9, dx: 2.5, dz: 1.3);
      m.stair(1.4, 0.34, 0.65, dz: 1.6);
    },
  ),

  Landmark(
    'bodega',
    'Bodega',
    12,
    1,
    'Bóveda fresca bajo tierra. El vino ya puede esperar unos años.',
    (m) {
      m.plinth(3.2, 2.2, 0.26);
      m.arcade(3.0, 1.2, 2.0, rise: true);
      m.beam(3.1, 2.1, 0.2);
      m.floor(2.9, 1.95, 0.9);
      m.roof(3.25, 2.3, 0.8);
      m.stair(1.4, 0.26, 0.7, dz: 1.45);
      m.dormer(0.65, 0.6, dz: 0.7);
      m.chimney(0.28, 0.85, dx: 1.0);
      for (var i = 0; i < 3; i++) {
        m.palisade(2.8, 0.7, dz: -1.7 - i * 0.55);
      }
      m.tree(1.0, 1.8, dx: 2.2, dz: 1.3);
    },
  ),

  Landmark(
    'silos',
    'Silos de grano',
    13,
    1,
    'Tres cilindros llenos hasta arriba. Un mal año deja de ser una catástrofe.',
    (m) {
      m.plinth(3.6, 2.2, 0.3);
      for (var i = 0; i < 3; i++) {
        m.box(
          PieceKind.floor,
          1.0,
          1.0,
          1.8,
          dx: -1.15 + i * 1.15,
          dz: -0.2,
          ridge: true,
          at: 0.3,
        );
      }
      for (var i = 0; i < 3; i++) {
        m.dome(1.05, 1.05, 0.75, dx: -1.15 + i * 1.15, dz: -0.2, at: 2.1);
      }
      m.outbuilding(1.5, 1.2, 1.0, 0.5, dz: 1.3);
      m.beam(3.4, 0.3, 0.2, dz: 0.55, at: 1.6);
      m.field(3.0, 1.0, dz: -1.6);
      m.palisade(3.4, 0.6, dz: -2.2);
      m.stair(1.0, 0.3, 0.6, dz: 2.1);
    },
  ),

  Landmark(
    'faro',
    'Faro',
    17,
    1,
    'Un fuego encendido toda la noche para gente que no conocés.',
    (m) {
      m.water(4.2, 2.0, dz: 2.6);
      m.plinth(2.8, 2.8, 0.5);
      m.plinth(2.2, 2.2, 0.4);
      m.shaft(1.7, 6, 0.85, taper: 0.1);
      m.parapet(1.7, 1.7, 0.42);
      m.arcade(1.2, 0.85, 1.2, rise: true);
      m.dome(1.4, 1.4, 0.7);
      m.banner(0.9);
      m.stair(1.1, 0.5, 0.8, dz: 1.7);
      m.outbuilding(1.3, 1.1, 0.9, 0.5, dx: 2.2, dz: -1.2);
      m.post(0.2, 1.4, dx: -1.9, dz: 1.9);
    },
  ),

  Landmark(
    'herreriaMayor',
    'Herrería mayor',
    13,
    1,
    'Tres fraguas trabajando a la vez. Rejas, herramienta y, si hace falta, armas.',
    (m) {
      m.plinth(3.2, 2.3, 0.3);
      m.floor(2.9, 2.05, 1.25);
      m.roof(3.25, 2.4, 0.85);
      m.chimney(0.5, 1.6, dx: -1.0);
      m.chimney(0.42, 1.3, dx: 0.3);
      m.chimney(0.36, 1.1, dx: 1.1);
      m.arcade(2.8, 1.0, 0.5, dz: 1.2, at: 0.3);
      m.water(1.0, 0.9, dx: -2.2, dz: 0.9);
      m.post(0.2, 1.4, dx: 2.2, dz: 1.2);
      m.beam(1.4, 1.2, 0.16, dx: 2.2, dz: 1.2, at: 1.4);
      m.box(PieceKind.plinth, 0.9, 0.9, 0.5, dx: 2.2, dz: -1.2, at: 0);
      m.palisade(3.0, 0.7, dz: -1.7);
      m.stair(1.4, 0.3, 0.6, dz: 1.5);
    },
  ),

  Landmark(
    'horca',
    'Campo de la horca',
    11,
    1,
    'Está en lo alto para que se vea de lejos. La justicia también se enseña.',
    (m) {
      m.plinth(2.6, 2.6, 0.2);
      m.plinth(1.6, 1.6, 0.24);
      m.post(0.3, 2.6, dx: -0.55, at: 0.44);
      m.post(0.3, 2.6, dx: 0.55, at: 0.44);
      m.beam(1.5, 0.3, 0.26, at: 3.04);
      m.stair(1.2, 0.44, 0.7, dz: -1.1);
      m.palisade(2.8, 0.7, dz: -1.6);
      m.palisade(2.8, 0.7, dz: 1.6);
      m.tree(1.2, 2.4, dx: 2.0, dz: -1.4);
      m.post(0.24, 1.4, dx: 1.9, dz: 1.2);
      m.field(2.4, 0.9, dz: 2.2);
    },
  ),

  Landmark(
    'palenque',
    'Palenque de torneos',
    16,
    1,
    'Liza cercada y estandartes. Un día al año esto se llena de gente de fuera.',
    (m) {
      m.field(5.0, 3.0);
      for (final s in [-1.0, 1.0]) {
        m.palisade(5.0, 0.9, dz: s * 1.7);
        m.palisade(3.4, 0.9, dx: s * 2.6, along: false);
      }
      m.plinth(2.4, 1.2, 0.5, dz: -1.9);
      m.arcade(2.2, 0.9, 1.0, dz: -1.9, at: 0.5, along: true);
      m.beam(2.5, 1.3, 0.2, dz: -1.9, at: 1.4);
      m.roof(2.7, 1.5, 0.5, dz: -1.9, at: 1.6);
      for (var i = 0; i < 4; i++) {
        m.banner(1.6, dx: -2.4 + i * 1.6, dz: 1.8, at: 0.9);
      }
      m.post(0.22, 0.9, dx: -2.4, dz: 1.8);
      m.post(0.22, 0.9, dx: 2.4, dz: 1.8);
      m.tree(1.1, 2.1, dx: -3.0, dz: -1.9);
    },
  ),

  Landmark(
    'huertoMonjes',
    'Huerto de los monjes',
    16,
    1,
    'Bancales medidos, agua en medio y todo por su nombre en latín.',
    (m) {
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 2; j++) {
          m.field(1.5, 1.4, dx: -1.7 + i * 1.7, dz: -0.85 + j * 1.7);
        }
      }
      m.palisade(4.0, 0.7, dz: -1.9);
      m.palisade(4.0, 0.7, dz: 1.9);
      m.palisade(3.8, 0.7, dx: -2.1, along: false);
      m.palisade(3.8, 0.7, dx: 2.1, along: false);
      m.water(1.0, 1.0);
      m.plinth(0.7, 0.7, 0.3);
      m.tree(1.1, 1.9, dx: -1.7, dz: -1.5);
      m.tree(1.1, 1.8, dx: 1.7, dz: 1.5);
      m.floor(1.2, 1.0, 0.85, dx: 2.6, dz: -1.4);
      m.roof(1.45, 1.25, 0.45, dx: 2.6, dz: -1.4);
    },
  ),

  Landmark(
    'vinedo',
    'Viñedo del cabildo',
    14,
    1,
    'Hileras hasta donde llega la vista. El vino de aquí ya tiene nombre.',
    (m) {
      for (var i = 0; i < 6; i++) {
        m.palisade(4.2, 0.8, dz: -2.2 + i * 0.9);
      }
      m.field(4.2, 4.6);
      m.plinth(1.6, 1.4, 0.3, dx: 2.6, dz: -1.4);
      m.floor(1.35, 1.15, 0.9, dx: 2.6, dz: -1.4);
      m.roof(1.6, 1.4, 0.45, dx: 2.6, dz: -1.4);
      m.water(1.0, 1.0, dx: 2.6, dz: 1.4);
      m.post(0.2, 1.6, dx: -2.6, dz: 2.0);
      m.banner(0.8, dx: -2.6, dz: 2.0, at: 1.6);
      m.tree(1.1, 2.0, dx: -2.6, dz: -2.2);
    },
  ),

  Landmark(
    'colmenarMayor',
    'Colmenar mayor',
    12,
    1,
    'Filas de colmenas y un guarda. La miel deja de ser un capricho.',
    (m) {
      m.palisade(4.0, 0.8, dz: -1.7);
      m.palisade(4.0, 0.8, dz: 1.7);
      m.palisade(3.4, 0.8, dx: -2.1, along: false);
      for (var i = 0; i < 4; i++) {
        m.dome(0.5, 0.5, 0.45, dx: -1.5 + i * 1.0, dz: -0.6, at: 0);
      }
      for (var i = 0; i < 3; i++) {
        m.dome(0.5, 0.5, 0.45, dx: -1.0 + i * 1.0, dz: 0.6, at: 0);
      }
      m.floor(1.2, 1.0, 0.85, dx: 2.4, dz: 0.8);
      m.roof(1.45, 1.25, 0.45, dx: 2.4, dz: 0.8);
    },
  ),

  // ------------------------------------------------------------------ tier 2
  // The works a town only attempts once it is sure of itself.
  Landmark(
    'castillo',
    'Castillo',
    45,
    2,
    'Cuatro torres, foso y una torre del homenaje en medio. A partir de hoy nadie entra si no se le abre.',
    (m) {
      m.water(7.0, 7.0);
      m.plinth(5.6, 5.6, 0.5);
      // Four corner towers, each built up its own side of the courtyard.
      for (final sx in [-1.0, 1.0]) {
        for (final sz in [-1.0, 1.0]) {
          for (var i = 0; i < 4; i++) {
            m.box(
              PieceKind.floor,
              1.5,
              1.5,
              0.85,
              dx: sx * 2.1,
              dz: sz * 2.1,
              at: 0.5 + i * 0.85,
            );
          }
          m.box(
            PieceKind.parapet,
            1.75,
            1.75,
            0.4,
            dx: sx * 2.1,
            dz: sz * 2.1,
            at: 3.9,
          );
          m.spire(1.55, 1.55, 0.9, dx: sx * 2.1, dz: sz * 2.1, at: 4.3);
        }
      }
      // The curtain wall between them.
      for (final s in [-1.0, 1.0]) {
        m.box(PieceKind.floor, 2.7, 0.9, 2.6, dz: s * 2.1, at: 0.5);
        m.box(PieceKind.parapet, 2.7, 1.1, 0.42, dz: s * 2.1, at: 3.1);
        m.box(PieceKind.floor, 0.9, 2.7, 2.6, dx: s * 2.1, at: 0.5);
        m.box(PieceKind.parapet, 1.1, 2.7, 0.42, dx: s * 2.1, at: 3.1);
      }
      // The keep in the middle of the courtyard.
      m.box(PieceKind.floor, 2.6, 2.6, 1.2, at: 0.5);
      m.box(PieceKind.floor, 2.5, 2.5, 1.1, at: 1.7);
      m.box(PieceKind.floor, 2.45, 2.45, 1.05, at: 2.8);
      m.box(PieceKind.parapet, 2.8, 2.8, 0.45, at: 3.85);
      m.spire(2.5, 2.5, 1.4, at: 4.3);
      m.banner(1.2, at: 5.7);
      m.box(PieceKind.porch, 1.2, 0.6, 1.3, dz: 2.75, at: 0.5);
      m.beam(3.0, 1.4, 0.3, dz: 3.6, at: 0.4);
      m.stair(1.4, 0.4, 1.2, dz: 4.4);
      m.banner(1.0, dx: -1.0, dz: 2.1, at: 3.52);
      m.banner(1.0, dx: 1.0, dz: 2.1, at: 3.52);
    },
  ),

  Landmark(
    'homenaje',
    'Torre del homenaje',
    24,
    2,
    'La torre última. Si cae todo lo demás, aquí se aguanta.',
    (m) {
      m.plinth(4.0, 4.0, 0.6);
      m.plinth(3.4, 3.4, 0.5);
      m.shaft(2.9, 8, 0.9);
      m.parapet(3.3, 3.3, 0.5);
      for (final sx in [-1.0, 1.0]) {
        for (final sz in [-1.0, 1.0]) {
          m.box(
            PieceKind.parapet,
            0.8,
            0.8,
            0.7,
            dx: sx * 1.4,
            dz: sz * 1.4,
            at: 8.7,
          );
        }
      }
      m.spire(2.8, 2.8, 1.5);
      m.banner(1.2);
      m.stair(1.6, 1.1, 1.4, dz: 2.6);
      m.arcade(2.4, 1.0, 0.5, dz: 1.55, at: 6.4);
      m.palisade(4.4, 1.0, dz: -2.5);
      m.palisade(4.4, 1.0, dx: -2.5, along: false);
      m.palisade(4.4, 1.0, dx: 2.5, along: false);
      m.water(5.2, 1.6, dz: 3.2);
      m.tree(1.2, 2.2, dx: -2.8, dz: 2.4);
    },
  ),

  Landmark(
    'puertaVilla',
    // Dos menos y no una: su puerta estaba escrita dentro del bucle que
    // levanta los dos torreones, así que eran dos puertas y son dos logros.
    'Puerta de la villa',
    21,
    2,
    'Ya se puede cerrar el pueblo por la noche. Un dentro de verdad.',
    (m) {
      m.plinth(5.2, 2.6, 0.45);
      for (final s in [-1.0, 1.0]) {
        for (var i = 0; i < 4; i++) {
          m.box(
            PieceKind.floor,
            1.6,
            2.2,
            0.9,
            dx: s * 1.9,
            at: 0.45 + i * 0.9,
          );
        }
        m.box(PieceKind.parapet, 1.9, 2.5, 0.45, dx: s * 1.9, at: 4.05);
        m.roof(1.75, 2.35, 0.9, dx: s * 1.9, at: 4.5);
      }
      m.box(PieceKind.arcade, 2.2, 2.2, 3.0, at: 0.45);
      m.box(PieceKind.floor, 2.2, 2.0, 1.1, at: 3.45);
      m.box(PieceKind.parapet, 2.5, 2.3, 0.45, at: 4.55);
      m.banner(1.1, dx: -0.7, at: 5.0);
      m.banner(1.1, dx: 0.7, at: 5.0);
      m.box(PieceKind.parapet, 3.0, 0.5, 1.6, dz: -1.5, at: 0.45);
      m.box(PieceKind.parapet, 3.0, 0.5, 1.6, dz: 1.5, at: 0.45);
      m.stair(1.4, 0.45, 1.0, dz: 1.9);
    },
  ),

  Landmark(
    'muralla',
    'Lienzo de muralla',
    23,
    2,
    'Un lienzo con adarve y almenas. Se camina por encima del propio pueblo.',
    (m) {
      m.plinth(6.0, 1.6, 0.4);
      for (var i = 0; i < 5; i++) {
        m.box(PieceKind.floor, 1.15, 1.2, 2.2, dx: -2.4 + i * 1.2, at: 0.4);
      }
      m.box(PieceKind.parapet, 6.0, 1.5, 0.5, at: 2.6);
      for (var i = 0; i < 7; i++) {
        m.box(
          PieceKind.parapet,
          0.55,
          1.5,
          0.45,
          dx: -2.55 + i * 0.85,
          at: 3.1,
        );
      }
      m.box(PieceKind.floor, 1.7, 1.7, 3.4, dx: -2.8, at: 0.4);
      m.box(PieceKind.parapet, 2.0, 2.0, 0.5, dx: -2.8, at: 3.8);
      m.spire(1.8, 1.8, 1.0, dx: -2.8, at: 4.3);
      m.box(PieceKind.floor, 1.7, 1.7, 3.4, dx: 2.8, at: 0.4);
      m.box(PieceKind.parapet, 2.0, 2.0, 0.5, dx: 2.8, at: 3.8);
      m.spire(1.8, 1.8, 1.0, dx: 2.8, at: 4.3);
      m.banner(0.9, dx: -2.8, at: 5.3);
      m.water(6.4, 1.2, dz: -1.6);
      m.stair(1.2, 0.4, 1.0, dz: 1.3);
    },
  ),

  Landmark(
    'alcazar',
    'Alcázar',
    31,
    2,
    'Palacio y fortaleza a la vez. Quien manda vive donde se defiende.',
    (m) {
      m.plinth(5.4, 4.4, 0.55);
      m.plinth(4.8, 3.9, 0.45);
      for (final s in [-1.0, 1.0]) {
        for (var i = 0; i < 5; i++) {
          m.box(
            PieceKind.floor,
            1.4,
            1.4,
            0.85,
            dx: s * 1.8,
            dz: -1.3,
            at: 1.0 + i * 0.85,
          );
        }
        m.box(
          PieceKind.parapet,
          1.65,
          1.65,
          0.42,
          dx: s * 1.8,
          dz: -1.3,
          at: 5.25,
        );
        m.spire(1.45, 1.45, 0.95, dx: s * 1.8, dz: -1.3, at: 5.67);
      }
      m.box(PieceKind.floor, 4.2, 2.4, 1.3, dz: 0.5, at: 1.0);
      m.box(PieceKind.floor, 4.1, 2.35, 1.2, dz: 0.5, at: 2.3);
      m.box(PieceKind.floor, 4.0, 2.3, 1.1, dz: 0.5, at: 3.5);
      m.roof(4.4, 2.7, 1.0, dz: 0.5, at: 4.6, along: true);
      m.box(PieceKind.dormer, 0.8, 0.7, 0.65, dx: -1.2, dz: 1.1, at: 4.6);
      m.box(PieceKind.dormer, 0.8, 0.7, 0.65, dx: 1.2, dz: 1.1, at: 4.6);
      m.arcade(3.8, 1.2, 0.6, dz: 1.75, at: 1.0, along: true);
      m.stair(1.8, 1.0, 1.4, dz: 2.7);
      m.banner(1.1, dz: 0.5, at: 5.6);
      m.chimney(0.4, 1.1, dx: -1.6, dz: 0.5);
      m.chimney(0.36, 1.0, dx: 1.6, dz: 0.5);
      m.water(6.0, 1.4, dz: -2.9);
      m.tree(1.3, 2.4, dx: -3.0, dz: 1.8);
      m.tree(1.2, 2.2, dx: 3.0, dz: 1.8);
      m.palisade(5.6, 0.9, dz: 3.3);
    },
  ),

  Landmark(
    'palacio',
    'Palacio del señor',
    24,
    2,
    'Galería de arcos, torres a los lados y jardín detrás. Aquí ya no se construye sólo por necesidad.',
    (m) {
      m.plinth(5.0, 3.4, 0.5);
      m.arcade(4.6, 1.4, 3.0, rise: true);
      m.beam(4.8, 3.2, 0.26);
      m.box(PieceKind.floor, 4.4, 3.0, 1.25, at: 2.16);
      m.box(PieceKind.floor, 4.35, 2.95, 1.15, at: 3.41);
      m.box(PieceKind.parapet, 4.7, 3.3, 0.42, at: 4.56);
      m.roof(4.6, 3.2, 1.0, at: 4.98, along: true);
      for (final s in [-1.0, 1.0]) {
        m.box(PieceKind.floor, 1.3, 1.3, 5.4, dx: s * 2.6, dz: -1.5, at: 0.5);
        m.box(
          PieceKind.parapet,
          1.55,
          1.55,
          0.42,
          dx: s * 2.6,
          dz: -1.5,
          at: 5.9,
        );
        m.spire(1.35, 1.35, 1.1, dx: s * 2.6, dz: -1.5, at: 6.32);
        m.banner(0.9, dx: s * 2.6, dz: -1.5, at: 7.42);
        m.box(PieceKind.dormer, 0.8, 0.7, 0.6, dx: s * 1.3, dz: 1.2, at: 4.98);
      }
      m.chimney(0.4, 1.2, dx: -0.8);
      m.chimney(0.36, 1.1, dx: 0.8);
      m.stair(2.0, 0.5, 1.4, dz: 2.4);
      m.water(2.2, 2.2, dz: 3.4);
      m.tree(1.3, 2.4, dx: -2.6, dz: 3.0);
      m.tree(1.3, 2.3, dx: 2.6, dz: 3.0);
      m.field(4.4, 1.2, dz: 4.6);
    },
  ),

  Landmark(
    'concejo',
    'Casa del concejo',
    21,
    2,
    'Balcón sobre la plaza y campana propia. Las decisiones se toman aquí, y en voz alta.',
    (m) {
      m.plinth(4.6, 3.0, 0.45);
      m.arcade(4.2, 1.35, 2.6, rise: true);
      m.beam(4.4, 2.8, 0.24);
      m.box(PieceKind.floor, 4.0, 2.6, 1.25, at: 2.04);
      m.box(PieceKind.floor, 3.95, 2.55, 1.1, at: 3.29);
      m.roof(4.35, 3.0, 1.0, at: 4.39, along: true);
      m.box(PieceKind.dormer, 0.8, 0.7, 0.65, dx: -1.2, dz: 1.0, at: 4.39);
      m.box(PieceKind.dormer, 0.8, 0.7, 0.65, dx: 1.2, dz: 1.0, at: 4.39);
      m.box(PieceKind.floor, 1.2, 1.2, 6.2, dz: -1.9, at: 0);
      m.box(PieceKind.parapet, 1.45, 1.45, 0.4, dz: -1.9, at: 6.2);
      m.spire(1.25, 1.25, 1.2, dz: -1.9, at: 6.6);
      m.banner(1.0, dz: -1.9, at: 7.8);
      m.box(PieceKind.dormer, 0.55, 0.16, 0.55, dz: -2.55, at: 4.95);
      m.chimney(0.38, 1.1, dx: -1.5);
      m.chimney(0.34, 1.0, dx: 1.5);
      m.stair(2.0, 0.45, 1.2, dz: 1.9);
      m.banner(1.0, dx: -1.6, dz: 1.5, at: 2.3);
      m.banner(1.0, dx: 1.6, dz: 1.5, at: 2.3);
      m.tree(1.2, 2.2, dx: -3.0, dz: 1.6);
      m.tree(1.2, 2.1, dx: 3.0, dz: 1.6);
      m.box(
        PieceKind.plinth,
        0.9,
        0.9,
        0.3,
        dx: 2.6,
        dz: -1.6,
        ridge: true,
        at: 0,
      );
    },
  ),

  Landmark(
    'lonja',
    'Lonja de mercaderes',
    21,
    2,
    'Bajo estos arcos se cierran los tratos. Media comarca viene a este suelo.',
    (m) {
      m.plinth(5.0, 3.6, 0.4);
      m.arcade(4.6, 1.6, 3.2, rise: true);
      m.beam(4.8, 3.4, 0.28);
      m.box(PieceKind.floor, 4.4, 3.2, 1.4, at: 2.28);
      m.box(PieceKind.parapet, 4.75, 3.5, 0.45, at: 3.68);
      m.roof(4.6, 3.4, 1.1, at: 4.13, along: true);
      for (final s in [-1.0, 1.0]) {
        m.box(PieceKind.floor, 1.2, 1.2, 4.6, dx: s * 2.5, dz: -1.7, at: 0.4);
        m.box(
          PieceKind.parapet,
          1.45,
          1.45,
          0.4,
          dx: s * 2.5,
          dz: -1.7,
          at: 5.0,
        );
        m.spire(1.25, 1.25, 1.0, dx: s * 2.5, dz: -1.7, at: 5.4);
        m.box(PieceKind.dormer, 0.8, 0.7, 0.6, dx: s * 1.3, dz: 1.2, at: 4.13);
        m.banner(1.0, dx: s * 1.8, dz: 1.8, at: 2.0);
      }
      m.stair(2.2, 0.4, 1.2, dz: 2.3);
      m.chimney(0.36, 1.1, dx: -1.0);
      m.box(
        PieceKind.plinth,
        1.0,
        1.0,
        0.3,
        dx: 3.0,
        dz: 1.8,
        ridge: true,
        at: 0,
      );
      m.post(0.3, 1.3, dx: 3.0, dz: 1.8, at: 0.3);
      m.tree(1.2, 2.2, dx: -3.2, dz: 1.8);
    },
  ),

  Landmark(
    'iglesia',
    'Iglesia',
    22,
    2,
    'Nave, dos naves laterales y campanario. El edificio donde cabe el pueblo entero.',
    (m) {
      m.plinth(3.2, 5.0, 0.4);
      m.box(PieceKind.floor, 2.8, 4.6, 1.9, at: 0.4);
      m.roof(3.2, 5.0, 1.3, at: 2.3, along: false);
      for (final s in [-1.0, 1.0]) {
        m.box(PieceKind.floor, 1.0, 4.0, 1.1, dx: s * 1.9, at: 0.4);
        m.roof(1.2, 4.2, 0.55, dx: s * 1.9, at: 1.5, along: false);
        m.arcade(3.6, 0.95, 0.5, dx: s * 1.9, along: false, at: 0.4);
      }
      m.box(PieceKind.floor, 1.6, 1.6, 5.4, dz: -3.0, at: 0);
      m.box(PieceKind.parapet, 1.85, 1.85, 0.4, dz: -3.0, at: 5.4);
      m.spire(1.65, 1.65, 1.8, dz: -3.0, at: 5.8);
      m.banner(0.9, dz: -3.0, at: 7.6);
      m.box(PieceKind.dormer, 0.6, 0.18, 0.6, dz: -3.85, at: 4.0);
      m.box(PieceKind.floor, 1.6, 1.2, 1.5, dz: 2.8, at: 0.4);
      m.roof(1.8, 1.4, 0.7, dz: 2.8, at: 1.9, along: true);
      m.stair(1.6, 0.4, 0.9, dz: 3.6);
      m.box(
        PieceKind.plinth,
        0.8,
        0.8,
        0.3,
        dx: 2.9,
        dz: 1.4,
        ridge: true,
        at: 0,
      );
      m.post(0.24, 1.4, dx: 2.9, dz: 1.4, at: 0.3);
      m.tree(1.3, 2.6, dx: -2.9, dz: 1.6);
      m.tree(1.2, 2.3, dx: 2.9, dz: -1.4);
      m.palisade(4.6, 0.6, dx: -2.9, along: false);
    },
  ),

  Landmark(
    'catedral',
    'Catedral',
    36,
    2,
    'Dos torres al poniente, cimborrio y contrafuertes. Se empieza sabiendo que la terminan otros.',
    (m) {
      m.plinth(4.0, 6.4, 0.5);
      m.box(PieceKind.floor, 3.5, 5.9, 2.4, at: 0.5);
      m.box(PieceKind.floor, 3.45, 5.85, 1.1, at: 2.9);
      m.roof(3.9, 6.3, 1.5, at: 4.0, along: false);
      for (final s in [-1.0, 1.0]) {
        m.box(PieceKind.floor, 1.3, 5.2, 1.5, dx: s * 2.4, at: 0.5);
        m.roof(1.5, 5.4, 0.7, dx: s * 2.4, at: 2.0, along: false);
        m.arcade(4.8, 1.2, 0.6, dx: s * 2.4, along: false, at: 0.5);
        m.arcade(4.8, 0.9, 0.5, dx: s * 1.6, along: false, at: 2.9);
        for (var i = 0; i < 3; i++) {
          m.box(
            PieceKind.parapet,
            0.4,
            0.4,
            1.4,
            dx: s * 3.15,
            dz: -1.6 + i * 1.6,
            at: 2.0,
          );
        }
        // The pair of west towers.
        m.box(PieceKind.floor, 1.7, 1.7, 6.4, dx: s * 1.5, dz: -3.9, at: 0);
        m.box(
          PieceKind.parapet,
          1.95,
          1.95,
          0.45,
          dx: s * 1.5,
          dz: -3.9,
          at: 6.4,
        );
        m.spire(1.75, 1.75, 2.2, dx: s * 1.5, dz: -3.9, at: 6.85);
        m.banner(0.9, dx: s * 1.5, dz: -3.9, at: 9.05);
        m.box(
          PieceKind.dormer,
          0.55,
          0.18,
          0.55,
          dx: s * 1.5,
          dz: -4.75,
          at: 4.7,
        );
      }
      m.box(PieceKind.floor, 1.4, 1.4, 1.6, at: 5.5);
      m.spire(1.3, 1.3, 2.4, at: 7.1);
      m.box(PieceKind.floor, 2.0, 1.6, 2.0, dz: 3.6, at: 0.5);
      m.roof(2.2, 1.8, 0.9, dz: 3.6, at: 2.5, along: true);
      m.box(PieceKind.arcade, 1.6, 0.6, 2.2, dz: -3.05, at: 0.5);
      m.stair(2.4, 0.5, 1.1, dz: 4.6);
      m.box(
        PieceKind.plinth,
        0.9,
        0.9,
        0.34,
        dx: 3.4,
        dz: 2.0,
        ridge: true,
        at: 0,
      );
      m.tree(1.3, 2.6, dx: -3.6, dz: 2.2);
    },
  ),

  Landmark(
    'monasterio',
    'Monasterio',
    28,
    2,
    'Iglesia, claustro y huerto. Un pueblo pequeño dentro del pueblo.',
    (m) {
      // The church along one side, the cloister beside it.
      m.plinth(2.6, 5.4, 0.4, dx: -1.9);
      m.box(PieceKind.floor, 2.3, 5.0, 1.9, dx: -1.9, at: 0.4);
      m.roof(2.6, 5.4, 1.2, dx: -1.9, at: 2.3, along: false);
      m.box(PieceKind.floor, 1.3, 1.3, 4.6, dx: -1.9, dz: -3.3, at: 0);
      m.box(PieceKind.parapet, 1.55, 1.55, 0.4, dx: -1.9, dz: -3.3, at: 4.6);
      m.spire(1.35, 1.35, 1.5, dx: -1.9, dz: -3.3, at: 5.0);
      m.banner(0.8, dx: -1.9, dz: -3.3, at: 6.5);
      m.plinth(4.4, 4.4, 0.26, dx: 1.9);
      for (final s in [-1.0, 1.0]) {
        m.arcade(4.0, 1.15, 0.7, dx: 1.9, dz: s * 1.75, at: 0.26, along: true);
        m.arcade(4.0, 1.15, 0.7, dx: 1.9 + s * 1.75, at: 0.26, along: false);
        m.beam(4.3, 0.8, 0.18, dx: 1.9, dz: s * 1.75, at: 1.41);
        m.beam(0.8, 4.3, 0.18, dx: 1.9 + s * 1.75, at: 1.41);
        m.roof(4.5, 1.1, 0.5, dx: 1.9, dz: s * 1.75, at: 1.59, along: true);
        m.roof(1.1, 4.5, 0.5, dx: 1.9 + s * 1.75, at: 1.59, along: false);
      }
      m.water(1.1, 1.1, dx: 1.9);
      m.plinth(0.7, 0.7, 0.3, dx: 1.9);
      m.tree(1.0, 1.7, dx: 1.0, dz: 0.9);
      m.field(1.1, 1.1, dx: 2.8, dz: -0.9);
      m.field(3.6, 1.2, dz: 4.0);
      m.palisade(7.0, 0.8, dz: 4.8);
      m.tree(1.2, 2.2, dx: -3.6, dz: 2.6);
      m.stair(1.4, 0.4, 0.8, dx: -1.9, dz: 3.4);
    },
  ),

  Landmark(
    'abadia',
    'Abadía',
    25,
    2,
    'Nave, torres gemelas y una comunidad que reza a horas fijas desde antes que amanezca.',
    (m) {
      m.plinth(3.4, 5.6, 0.45);
      m.box(PieceKind.floor, 3.0, 5.2, 2.1, at: 0.45);
      m.roof(3.4, 5.6, 1.4, at: 2.55, along: false);
      for (final s in [-1.0, 1.0]) {
        m.box(PieceKind.floor, 1.1, 4.4, 1.2, dx: s * 2.05, at: 0.45);
        m.roof(1.3, 4.6, 0.6, dx: s * 2.05, at: 1.65, along: false);
        m.arcade(4.0, 1.0, 0.55, dx: s * 2.05, along: false, at: 0.45);
        m.box(PieceKind.floor, 1.4, 1.4, 4.8, dx: s * 1.1, dz: -3.4, at: 0);
        m.box(
          PieceKind.parapet,
          1.65,
          1.65,
          0.4,
          dx: s * 1.1,
          dz: -3.4,
          at: 4.8,
        );
        m.spire(1.45, 1.45, 1.6, dx: s * 1.1, dz: -3.4, at: 5.2);
      }
      m.box(PieceKind.floor, 1.2, 1.2, 1.3, at: 3.95);
      m.spire(1.1, 1.1, 1.9, at: 5.25);
      m.box(PieceKind.floor, 3.0, 1.6, 1.4, dz: 3.5, at: 0.45);
      m.roof(3.2, 1.8, 0.8, dz: 3.5, at: 1.85, along: true);
      m.chimney(0.34, 1.0, dx: 1.0, dz: 3.5);
      m.stair(1.8, 0.45, 1.0, dz: 4.4);
      m.field(3.0, 1.2, dz: 5.4);
      m.tree(1.3, 2.5, dx: -3.2, dz: 2.4);
      m.tree(1.2, 2.3, dx: 3.2, dz: 2.4);
      m.palisade(5.0, 0.7, dz: 6.1);
    },
  ),

  Landmark(
    'colegiata',
    'Colegiata',
    22,
    2,
    'No es catedral porque no hay obispo. Por lo demás, lo es.',
    (m) {
      m.plinth(3.2, 5.2, 0.42);
      m.box(PieceKind.floor, 2.85, 4.8, 2.2, at: 0.42);
      m.roof(3.2, 5.2, 1.3, at: 2.62, along: false);
      for (final s in [-1.0, 1.0]) {
        m.box(PieceKind.floor, 1.05, 4.2, 1.3, dx: s * 1.95, at: 0.42);
        m.roof(1.25, 4.4, 0.6, dx: s * 1.95, at: 1.72, along: false);
        m.arcade(3.8, 1.05, 0.5, dx: s * 1.95, along: false, at: 0.42);
        m.box(PieceKind.dormer, 0.6, 0.5, 0.5, dx: s * 0.9, dz: 1.2, at: 2.62);
      }
      m.box(PieceKind.floor, 1.7, 1.7, 5.6, dz: -3.1, at: 0.42);
      m.arcade(1.4, 0.9, 0.4, dz: -3.95, at: 4.6);
      m.box(PieceKind.parapet, 1.95, 1.95, 0.42, dz: -3.1, at: 6.02);
      m.spire(1.75, 1.75, 1.9, dz: -3.1, at: 6.44);
      m.banner(0.9, dz: -3.1, at: 8.34);
      m.box(PieceKind.floor, 1.8, 1.4, 1.6, dz: 2.9, at: 0.42);
      m.roof(2.0, 1.6, 0.75, dz: 2.9, at: 2.02, along: true);
      m.stair(1.7, 0.42, 0.95, dz: 3.7);
      m.plinth(0.85, 0.85, 0.32, dx: 2.9, dz: 1.6);
      m.post(0.24, 1.3, dx: 2.9, dz: 1.6, at: 0.32);
      m.tree(1.3, 2.5, dx: -2.9, dz: 1.8);
    },
  ),

  Landmark(
    'sinagoga',
    'Sinagoga',
    20,
    2,
    'El pueblo tiene sitio para más de una manera de rezar.',
    (m) {
      m.plinth(3.4, 4.2, 0.44);
      m.box(PieceKind.floor, 3.0, 3.8, 2.3, at: 0.44);
      m.box(PieceKind.floor, 2.95, 3.75, 1.0, at: 2.74);
      m.roof(3.35, 4.15, 1.1, at: 3.74, along: false);
      m.arcade(3.4, 1.2, 0.55, dz: 2.0, at: 0.44);
      m.beam(3.6, 0.65, 0.2, dz: 2.0, at: 1.64);
      m.roof(3.8, 1.0, 0.45, dz: 2.1, at: 1.84, along: true);
      for (final s in [-1.0, 1.0]) {
        m.box(PieceKind.floor, 0.9, 0.9, 4.4, dx: s * 1.75, dz: -1.8, at: 0.44);
        m.box(
          PieceKind.parapet,
          1.1,
          1.1,
          0.35,
          dx: s * 1.75,
          dz: -1.8,
          at: 4.84,
        );
        m.dome(0.95, 0.95, 0.7, dx: s * 1.75, dz: -1.8, at: 5.19);
        m.box(PieceKind.dormer, 0.55, 0.5, 0.5, dx: s * 0.9, dz: 0.9, at: 3.74);
      }
      m.stair(1.6, 0.44, 0.9, dz: 2.8);
      m.tree(1.2, 2.3, dx: -2.9, dz: 1.6);
      m.tree(1.2, 2.2, dx: 2.9, dz: 1.6);
      m.water(1.0, 1.0, dz: -2.6);
      m.palisade(4.0, 0.6, dz: -3.2);
    },
  ),

  Landmark(
    'mezquita',
    'Mezquita',
    21,
    2,
    'Cúpula, alminar y patio con agua. La misma villa, otra voz.',
    (m) {
      m.plinth(4.4, 4.4, 0.42);
      m.box(PieceKind.floor, 4.0, 4.0, 2.0, at: 0.42);
      m.dome(3.6, 3.6, 1.6, at: 2.42);
      m.dome(1.3, 1.3, 0.8, dx: -1.3, dz: -1.3, at: 2.42);
      m.dome(1.3, 1.3, 0.8, dx: 1.3, dz: -1.3, at: 2.42);
      m.dome(1.3, 1.3, 0.8, dx: -1.3, dz: 1.3, at: 2.42);
      m.dome(1.3, 1.3, 0.8, dx: 1.3, dz: 1.3, at: 2.42);
      m.box(PieceKind.floor, 1.0, 1.0, 6.2, dx: -2.7, dz: -2.0, at: 0);
      m.arcade(0.8, 0.8, 0.8, dx: -2.7, dz: -2.0, at: 5.0);
      m.box(PieceKind.parapet, 1.25, 1.25, 0.34, dx: -2.7, dz: -2.0, at: 6.2);
      m.dome(1.05, 1.05, 0.8, dx: -2.7, dz: -2.0, at: 6.54);
      m.banner(0.8, dx: -2.7, dz: -2.0, at: 7.34);
      m.arcade(4.0, 1.3, 0.6, dz: 2.4, at: 0.42, along: true);
      m.beam(4.2, 0.7, 0.22, dz: 2.4, at: 1.72);
      m.roof(4.4, 1.1, 0.5, dz: 2.5, at: 1.94, along: true);
      m.water(1.6, 1.6, dz: 3.6);
      m.plinth(1.0, 1.0, 0.3, dz: 3.6);
      m.stair(1.8, 0.42, 0.9, dz: 3.0);
      m.tree(1.2, 2.2, dx: -3.0, dz: 2.6);
      m.tree(1.2, 2.1, dx: 3.0, dz: 2.6);
      m.palisade(5.0, 0.7, dz: 4.4);
    },
  ),

  Landmark(
    'baptisterio',
    'Baptisterio',
    18,
    2,
    'Octógono con una pila en medio. Aquí entra la gente al pueblo por primera vez.',
    (m) {
      m.plinth(3.6, 3.6, 0.5);
      m.plinth(3.2, 3.2, 0.4);
      m.box(PieceKind.floor, 2.9, 2.9, 1.4, at: 0.9);
      m.arcade(2.7, 1.0, 2.7, at: 2.3, rise: true);
      m.box(PieceKind.floor, 2.85, 2.85, 0.9, at: 3.3);
      m.box(PieceKind.parapet, 3.1, 3.1, 0.35, at: 4.2);
      m.dome(2.8, 2.8, 1.6, at: 4.55);
      m.dome(0.7, 0.7, 0.5, at: 6.15);
      m.banner(0.8, at: 6.65);
      for (final s in [-1.0, 1.0]) {
        m.box(
          PieceKind.parapet,
          0.5,
          0.5,
          1.2,
          dx: s * 1.35,
          dz: -1.35,
          at: 3.3,
        );
        m.box(
          PieceKind.parapet,
          0.5,
          0.5,
          1.2,
          dx: s * 1.35,
          dz: 1.35,
          at: 3.3,
        );
      }
      m.box(PieceKind.arcade, 1.2, 0.6, 1.6, dz: 1.75, at: 0.9);
      m.stair(1.6, 0.9, 1.0, dz: 2.5);
      m.water(1.4, 1.4, dz: 3.4);
      m.tree(1.2, 2.3, dx: -2.6, dz: 2.2);
      m.tree(1.2, 2.2, dx: 2.6, dz: 2.2);
    },
  ),

  Landmark(
    'hospitalMayor',
    'Hospital mayor',
    22,
    2,
    'Salas largas y camas de verdad. Estar enfermo deja de ser estar solo.',
    (m) {
      m.plinth(5.2, 3.4, 0.44);
      m.box(PieceKind.floor, 4.8, 3.05, 1.35, at: 0.44);
      m.box(PieceKind.floor, 4.75, 3.0, 1.2, at: 1.79);
      m.roof(5.15, 3.45, 1.1, at: 2.99, along: true);
      m.arcade(4.6, 1.2, 0.65, dz: 1.75, at: 0.44, along: true);
      m.beam(4.8, 0.7, 0.2, dz: 1.75, at: 1.64);
      m.roof(5.0, 1.1, 0.5, dz: 1.85, at: 1.84, along: true);
      for (var i = 0; i < 4; i++) {
        m.box(
          PieceKind.dormer,
          0.75,
          0.65,
          0.6,
          dx: -1.8 + i * 1.2,
          dz: 1.2,
          at: 2.99,
        );
      }
      m.chimney(0.38, 1.1, dx: -2.0);
      m.chimney(0.34, 1.0, dx: 2.0);
      m.box(PieceKind.floor, 1.4, 1.4, 4.6, dx: -3.0, dz: -0.8, at: 0);
      m.box(PieceKind.parapet, 1.65, 1.65, 0.4, dx: -3.0, dz: -0.8, at: 4.6);
      m.spire(1.45, 1.45, 1.4, dx: -3.0, dz: -0.8, at: 5.0);
      m.banner(0.9, dx: -3.0, dz: -0.8, at: 6.4);
      m.box(PieceKind.parapet, 0.7, 0.3, 0.55, at: 4.09);
      m.stair(2.0, 0.44, 1.0, dz: 2.4);
      m.water(1.2, 1.2, dx: 3.2, dz: 1.8);
      m.field(3.0, 1.2, dz: -2.6);
      m.tree(1.2, 2.3, dx: -3.4, dz: 2.4);
    },
  ),

  Landmark(
    'universidad',
    'Universidad',
    29,
    2,
    'Claustro, aulas y libros encadenados. Gente que viene de lejos sólo a leer.',
    (m) {
      m.plinth(5.0, 5.0, 0.4);
      for (final s in [-1.0, 1.0]) {
        m.arcade(4.6, 1.4, 0.8, dz: s * 1.9, at: 0.4, along: true);
        m.arcade(4.6, 1.4, 0.8, dx: s * 1.9, at: 0.4, along: false);
        m.beam(4.8, 0.9, 0.22, dz: s * 1.9, at: 1.8);
        m.beam(0.9, 4.8, 0.22, dx: s * 1.9, at: 1.8);
        m.box(PieceKind.floor, 4.8, 0.9, 1.2, dz: s * 1.9, at: 2.02);
        m.box(PieceKind.floor, 0.9, 4.8, 1.2, dx: s * 1.9, at: 2.02);
        m.roof(5.0, 1.2, 0.6, dz: s * 1.95, at: 3.22, along: true);
        m.roof(1.2, 5.0, 0.6, dx: s * 1.95, at: 3.22, along: false);
        m.box(
          PieceKind.dormer,
          0.7,
          0.6,
          0.55,
          dx: s * 1.2,
          dz: 1.95,
          at: 3.22,
        );
      }
      m.box(PieceKind.floor, 1.5, 1.5, 5.0, dx: -2.6, dz: -2.6, at: 0.4);
      m.box(PieceKind.parapet, 1.75, 1.75, 0.4, dx: -2.6, dz: -2.6, at: 5.4);
      m.spire(1.55, 1.55, 1.5, dx: -2.6, dz: -2.6, at: 5.8);
      m.banner(0.9, dx: -2.6, dz: -2.6, at: 7.3);
      m.box(PieceKind.arcade, 1.4, 0.9, 2.0, dz: 2.4, at: 0.4);
      m.stair(1.8, 0.4, 1.0, dz: 3.0);
      m.tree(1.1, 1.9, dx: -0.9, dz: 0.9);
      m.tree(1.1, 1.8, dx: 0.9, dz: -0.9);
      m.water(1.1, 1.1);
      m.plinth(0.7, 0.7, 0.3);
    },
  ),

  Landmark(
    'biblioteca',
    'Biblioteca',
    20,
    2,
    'Estanterías hasta el techo. Lo que sabía uno ya lo pueden saber todos.',
    (m) {
      m.plinth(4.4, 3.0, 0.5);
      m.plinth(4.0, 2.7, 0.4);
      m.arcade(3.7, 1.3, 0.6, dz: 1.15, at: 0.9, along: true);
      m.box(PieceKind.floor, 3.7, 2.4, 1.5, at: 0.9);
      m.box(PieceKind.floor, 3.65, 2.35, 1.3, at: 2.4);
      m.box(PieceKind.parapet, 4.0, 2.7, 0.42, at: 3.7);
      m.roof(3.85, 2.6, 0.95, at: 4.12, along: true);
      for (final s in [-1.0, 1.0]) {
        m.box(
          PieceKind.parapet,
          0.55,
          0.55,
          1.0,
          dx: s * 1.7,
          dz: -1.05,
          at: 3.7,
        );
        m.box(
          PieceKind.parapet,
          0.55,
          0.55,
          1.0,
          dx: s * 1.7,
          dz: 1.05,
          at: 3.7,
        );
        m.box(
          PieceKind.dormer,
          0.7,
          0.6,
          0.55,
          dx: s * 1.1,
          dz: 0.95,
          at: 4.12,
        );
      }
      m.chimney(0.34, 1.0, dx: -0.6);
      m.stair(1.8, 0.9, 1.1, dz: 2.1);
      m.banner(1.0, dx: -1.4, dz: 1.4, at: 2.2);
      m.banner(1.0, dx: 1.4, dz: 1.4, at: 2.2);
      m.tree(1.2, 2.3, dx: -2.9, dz: 1.6);
      m.tree(1.2, 2.2, dx: 2.9, dz: 1.6);
      m.field(3.0, 1.0, dz: -2.2);
    },
  ),

  Landmark(
    'teatro',
    'Corral de misterios',
    24,
    2,
    'Corredores, un tablado y bancos. Una vez al año el pueblo se cuenta a sí mismo.',
    (m) {
      m.plinth(4.6, 4.2, 0.3);
      for (final s in [-1.0, 1.0]) {
        m.box(PieceKind.floor, 0.9, 3.6, 1.1, dx: s * 1.8, at: 0.3);
        m.arcade(3.4, 1.0, 0.5, dx: s * 1.8, along: false, at: 1.4);
        m.beam(1.1, 3.6, 0.2, dx: s * 1.8, at: 2.4);
        m.box(PieceKind.floor, 1.0, 3.6, 1.0, dx: s * 1.8, at: 2.6);
        m.roof(1.2, 3.8, 0.5, dx: s * 1.8, at: 3.6, along: false);
        m.banner(1.0, dx: s * 1.8, dz: -1.6, at: 4.1);
      }
      m.box(PieceKind.floor, 3.0, 0.9, 1.1, dz: -1.7, at: 0.3);
      m.arcade(2.8, 1.0, 0.5, dz: -1.7, at: 1.4, along: true);
      m.beam(3.2, 1.1, 0.2, dz: -1.7, at: 2.4);
      m.roof(3.4, 1.3, 0.5, dz: -1.7, at: 2.6, along: true);
      m.box(PieceKind.porch, 2.4, 1.2, 0.8, dz: 1.2, at: 0.3);
      m.post(0.2, 1.6, dx: -1.0, dz: 1.7, at: 1.1);
      m.post(0.2, 1.6, dx: 1.0, dz: 1.7, at: 1.1);
      m.beam(2.6, 0.3, 0.18, dz: 1.7, at: 2.7);
      m.roof(2.8, 1.5, 0.5, dz: 1.4, at: 2.88, along: true);
      m.stair(1.6, 0.3, 0.8, dz: 2.4);
      m.tree(1.2, 2.2, dx: -3.0, dz: 2.2);
    },
  ),

  Landmark(
    'coso',
    'Coso y graderío',
    26,
    2,
    'Ruedo de arena y graderío de piedra. Cabe el pueblo entero mirando lo mismo.',
    (m) {
      m.plinth(5.6, 5.6, 0.24);
      m.field(3.6, 3.6);
      for (final s in [-1.0, 1.0]) {
        m.box(PieceKind.plinth, 5.2, 0.9, 0.7, dz: s * 2.15, at: 0.24);
        m.box(PieceKind.plinth, 0.9, 5.2, 0.7, dx: s * 2.15, at: 0.24);
        m.arcade(5.0, 1.1, 0.7, dz: s * 2.15, at: 0.94, along: true);
        m.arcade(5.0, 1.1, 0.7, dx: s * 2.15, at: 0.94, along: false);
        m.beam(5.4, 1.0, 0.2, dz: s * 2.15, at: 2.04);
        m.beam(1.0, 5.4, 0.2, dx: s * 2.15, at: 2.04);
        m.roof(5.6, 1.3, 0.5, dz: s * 2.2, at: 2.24, along: true);
        m.roof(1.3, 5.6, 0.5, dx: s * 2.2, at: 2.24, along: false);
        m.banner(1.2, dx: s * 2.4, dz: -2.4, at: 2.24);
        m.banner(1.2, dx: s * 2.4, dz: 2.4, at: 2.24);
      }
      m.box(PieceKind.arcade, 1.4, 1.0, 1.6, dz: -2.15, at: 0.24);
      m.stair(1.6, 0.24, 0.9, dz: 3.0);
      m.tree(1.2, 2.3, dx: -3.4, dz: 3.0);
      m.tree(1.2, 2.2, dx: 3.4, dz: 3.0);
    },
  ),

  Landmark(
    'jardin',
    'Jardín del palacio',
    26,
    2,
    'Setos, agua en medio y un banco a la sombra. Lo primero que se hace sin que sirva para nada.',
    (m) {
      m.plinth(5.4, 5.4, 0.18);
      m.water(2.4, 2.4);
      m.plinth(1.2, 1.2, 0.3);
      m.post(0.4, 0.7, at: 0.3);
      m.dome(0.6, 0.6, 0.4, at: 1.0);
      for (final sx in [-1.0, 1.0]) {
        for (final sz in [-1.0, 1.0]) {
          m.field(1.5, 1.5, dx: sx * 1.8, dz: sz * 1.8);
          m.tree(1.1, 1.9, dx: sx * 1.8, dz: sz * 1.8);
          m.palisade(1.7, 0.45, dx: sx * 1.8, dz: sz * 2.7);
        }
      }
      for (final s in [-1.0, 1.0]) {
        m.palisade(5.4, 0.7, dz: s * 2.9);
        m.palisade(5.4, 0.7, dx: s * 2.9, along: false);
      }
      m.plinth(1.4, 1.0, 0.4, dz: -2.6);
      m.post(0.22, 1.6, dx: -0.5, dz: -2.6, at: 0.4);
      m.post(0.22, 1.6, dx: 0.5, dz: -2.6, at: 0.4);
      m.beam(1.5, 1.0, 0.16, dz: -2.6, at: 2.0);
      m.roof(1.7, 1.2, 0.5, dz: -2.6, at: 2.16);
    },
  ),

  Landmark(
    'arcoVilla',
    'Arco de la villa',
    20,
    2,
    'Un arco por el que no hace falta pasar. Está para decir que se llegó.',
    (m) {
      m.plinth(4.6, 2.0, 0.5);
      for (final s in [-1.0, 1.0]) {
        m.box(PieceKind.floor, 1.2, 1.7, 3.2, dx: s * 1.65, at: 0.5);
        m.box(PieceKind.parapet, 1.4, 1.9, 0.4, dx: s * 1.65, at: 3.7);
        m.box(
          PieceKind.parapet,
          0.4,
          0.4,
          0.9,
          dx: s * 1.65,
          dz: -0.6,
          at: 4.1,
        );
        m.box(PieceKind.parapet, 0.4, 0.4, 0.9, dx: s * 1.65, dz: 0.6, at: 4.1);
      }
      m.box(PieceKind.arcade, 2.1, 1.7, 2.6, at: 0.5);
      m.beam(4.6, 1.9, 0.3, at: 3.1);
      m.box(PieceKind.floor, 3.4, 1.6, 1.1, at: 3.4);
      m.box(PieceKind.parapet, 3.7, 1.9, 0.4, at: 4.5);
      m.banner(1.2, dx: -1.0, at: 4.9);
      m.banner(1.2, dx: 1.0, at: 4.9);
      m.box(PieceKind.dormer, 1.0, 0.2, 0.7, dz: -0.9, at: 3.6);
      m.box(
        PieceKind.plinth,
        0.8,
        0.8,
        0.3,
        dx: -2.9,
        dz: 1.0,
        ridge: true,
        at: 0,
      );
      m.box(
        PieceKind.plinth,
        0.8,
        0.8,
        0.3,
        dx: 2.9,
        dz: 1.0,
        ridge: true,
        at: 0,
      );
      m.stair(2.0, 0.5, 1.0, dz: 1.4);
      m.tree(1.2, 2.2, dx: -3.2, dz: -1.4);
    },
  ),

  Landmark(
    'panteon',
    'Panteón de los fundadores',
    18,
    2,
    'Cúpula sobre los que empezaron todo esto. La primera piedra la puso alguien.',
    (m) {
      m.plinth(4.0, 4.0, 0.55);
      m.plinth(3.5, 3.5, 0.45);
      m.arcade(3.2, 1.3, 3.2, at: 1.0, rise: true);
      m.beam(3.6, 3.6, 0.26, at: 2.3);
      m.box(PieceKind.floor, 3.1, 3.1, 1.1, at: 2.56);
      m.box(PieceKind.parapet, 3.4, 3.4, 0.38, at: 3.66);
      m.dome(3.1, 3.1, 1.8, at: 4.04);
      m.dome(0.8, 0.8, 0.55, at: 5.84);
      m.post(0.24, 0.6, at: 6.39);
      for (final s in [-1.0, 1.0]) {
        m.box(
          PieceKind.parapet,
          0.45,
          0.45,
          1.0,
          dx: s * 1.5,
          dz: -1.5,
          at: 3.66,
        );
        m.box(
          PieceKind.parapet,
          0.45,
          0.45,
          1.0,
          dx: s * 1.5,
          dz: 1.5,
          at: 3.66,
        );
      }
      m.stair(1.8, 1.0, 1.1, dz: 2.6);
      m.tree(1.3, 2.6, dx: -2.8, dz: 2.4);
      m.tree(1.3, 2.5, dx: 2.8, dz: 2.4);
      m.palisade(4.4, 0.6, dz: 3.4);
      m.box(
        PieceKind.plinth,
        0.7,
        0.7,
        0.28,
        dx: -2.6,
        dz: -1.8,
        ridge: true,
        at: 0,
      );
    },
  ),
];
