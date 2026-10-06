import 'dart:ui';

import '../engine/town.dart' show BuildingKind;

/// What kind of place a town is.
///
/// Four habits must not feel like the same thing four times. The pieces are
/// laid the same way — one achievement, one piece, never moved — but the place
/// they build is not: its houses are taller or wider, its roofs are tile or
/// slate or thatch, its streets are tight or open, its walls are limewashed
/// white or ochre or grey stone, and its landmarks arrive
/// in a different order.
///
/// Characters are assigned by plot, not at random, so the six are always as
/// different from each other as the catalogue allows — and so a town never
/// changes character underneath somebody.
class TownCharacter {
  const TownCharacter({
    required this.region,
    required this.blurb,
    required this.suits,
    required this.symbol,
    required this.storey,
    required this.spread,
    required this.pitch,
    required this.roofMix,
    required this.wash,
    required this.washShare,
    required this.plotPitch,
    required this.order,
    this.wallThick = 0.0,
    this.windowGap = 1.0,
    this.gardens = 0.0,
    this.trees = 0.0,
    this.houseNames,
  });

  /// What this kind of place is called, and one line about it.
  final String region;
  final String blurb;

  /// Para qué clase de hábito pega, dicho como sugerencia y nada más: la
  /// comarca es sólo cómo se ve, y cualquier hábito puede vivir en cualquiera.
  /// Sale de cómo es el sitio, para que la relación se entienda sola.
  final String suits;

  /// The mark it is chosen by when a habit is founded. One of the same
  /// thirty-six the habits themselves wear, because they are the only marks
  /// this app knows how to draw.
  final String symbol;

  /// How tall a storey is here, and how wide a house sits. Northern towns pile
  /// their storeys up; southern ones spread out.
  final double storey;
  final double spread;

  /// How steep the roofs are. Snow country pitches steep; dry country does not.
  final double pitch;

  /// The share of tile, slate and thatch, in that order. Adds to one.
  final (double, double, double) roofMix;

  /// The limewash this town favours, and how many houses take it.
  final Color wash;
  final double washShare;

  /// How close together the plots are laid. Tight towns feel like a city;
  /// open ones feel like a village that grew.
  final double plotPitch;

  /// How thick the walls are, from nothing to as thick as they get.
  ///
  /// A wall has no thickness in this world — every house is a closed box — so
  /// thickness is read where a real one is read: at the openings. A thick wall
  /// makes a narrower window and sets it deep, so it is ringed by its own
  /// shadow; a thin one puts the glass almost flush. Nobody measures a wall,
  /// they look at a window and know.
  final double wallThick;

  /// How far apart the windows sit, as a multiple of the ordinary spacing.
  /// Above one is a frontier town that would rather have wall than window.
  final double windowGap;

  /// What this place puts on the ground beside a house: the share of houses
  /// with a kitchen garden, and the share with a tree over them.
  ///
  /// Neither is earned and neither is a piece. A garden is not an achievement,
  /// it is what a plot looks like in a place where people grow things, and
  /// charging an achievement for it would be charging for the scenery.
  final double gardens, trees;

  /// Cómo se llaman aquí las casas corrientes, cuando no se llaman como en
  /// todas partes.
  ///
  /// Lo que cambia de región en región no es sólo la forma, es la palabra —y
  /// la palabra es la mitad de lo que hace que un sitio se sienta otro sitio.
  /// Un sitio donde las casas fueran de otro tamaño y siguieran llamándose
  /// cobertizo y casona le estaría mintiendo a quien las mira.
  ///
  /// Lo que no cambia es el precio: un `shed` sigue costando dos piezas y
  /// sigue siendo el mismo para el plano, la crónica y lo que ya esté en pie.
  /// Esto es el rótulo, no el edificio. Hoy no lo usa ninguna de las seis, y
  /// está porque la séptima que se invente lo va a necesitar el primer día.
  final Map<BuildingKind, String>? houseNames;

  /// Seeds this town's own shuffle of the landmark catalogue, so no two towns
  /// meet it in the same order. Sin número: el catálogo crece.
  final int order;

  static const List<TownCharacter> all = [
    TownCharacter(
      region: 'Ribera',
      suits:
          'Para hábitos de calma y descanso: dormir mejor, meditar, tomar agua.',
      symbol: 'gota',
      blurb: 'Casas anchas y bajas, encaladas de blanco, casi todas de teja.',
      storey: 0.9,
      spread: 1.2,
      pitch: 0.8,
      roofMix: (0.72, 0.10, 0.18),
      wash: Color(0xFFF2E6D2),
      washShare: 0.86,
      plotPitch: 2.8,
      order: 0x1A7C,
      wallThick: 0.10,
      windowGap: 0.90,
      gardens: 0.30,
      trees: 0.10,
    ),
    TownCharacter(
      region: 'Sierra',
      suits:
          'Para los hábitos que cuestan esfuerzo físico y de verdad son difíciles: entrenar, correr, madrugar.',
      symbol: 'montana',
      blurb: 'Alta y apretada, de piedra gris y pizarra, con tejados agudos.',
      storey: 1.34,
      spread: 0.8,
      pitch: 1.3,
      roofMix: (0.12, 0.76, 0.12),
      wash: Color(0xFFB9B7AE),
      washShare: 0.8,
      plotPitch: 2.1,
      order: 0x33F1,
      wallThick: 0.65,
      windowGap: 1.15,
      gardens: 0.10,
      trees: 0.05,
    ),
    TownCharacter(
      region: 'Marca',
      suits:
          'Para dejar algo y aguantar: no fumar, menos pantalla, menos azúcar.',
      symbol: 'escudo',
      blurb: 'De frontera: muros gruesos, ocre, pocas ventanas y todo junto.',
      storey: 1.06,
      spread: 1.0,
      pitch: 0.92,
      roofMix: (0.52, 0.34, 0.14),
      wash: Color(0xFFD8A64C),
      washShare: 0.84,
      plotPitch: 2.2,
      order: 0x5E02,
      wallThick: 1.00,
      windowGap: 1.55,
      gardens: 0.08,
      trees: 0.04,
    ),
    TownCharacter(
      region: 'Valle',
      suits:
          'Para hábitos ligados a la naturaleza y la salud: comer sano, cocinar, caminar al aire libre.',
      symbol: 'espiga',
      blurb: 'Madera y paja, solares grandes y huerta en casi todas.',
      storey: 0.96,
      spread: 1.1,
      pitch: 1.2,
      roofMix: (0.18, 0.14, 0.68),
      wash: Color(0xFFC7B48C),
      washShare: 0.74,
      plotPitch: 3.6,
      order: 0x7B45,
      wallThick: 0.25,
      windowGap: 1.00,
      gardens: 1.00,
      trees: 0.34,
    ),
    TownCharacter(
      region: 'Costa',
      suits:
          'Para el orden y la claridad: ordenar la casa, las cuentas, planificar la semana.',
      symbol: 'ola',
      blurb: 'Cal y añil, tejados casi planos y mucho aire entre las casas.',
      storey: 0.8,
      spread: 1.1,
      pitch: 0.52,
      roofMix: (0.62, 0.24, 0.14),
      wash: Color(0xFF9EC0D2),
      washShare: 0.88,
      plotPitch: 3.05,
      order: 0x91C8,
      wallThick: 0.00,
      windowGap: 0.85,
      gardens: 0.16,
      trees: 0.08,
    ),
    TownCharacter(
      region: 'Robledal',
      suits:
          'Para lo que crece despacio, como un roble: leer, estudiar, escribir, aprender un instrumento.',
      symbol: 'arbol',
      blurb: 'Madera oscura bajo los robles, tejados de paja muy inclinados.',
      storey: 1.16,
      spread: 0.88,
      pitch: 1.75,
      roofMix: (0.10, 0.20, 0.70),
      wash: Color(0xFF9A7C55),
      washShare: 0.78,
      plotPitch: 2.75,
      order: 0xB30D,
      wallThick: 0.30,
      windowGap: 1.10,
      gardens: 0.40,
      trees: 0.88,
    ),
    // Las dos de abajo llegaron después, y van al final a propósito: la
    // comarca por defecto de cada solar del valle sale de esta lista por su
    // posición ([forSlot]), así que meterlas en medio le cambiaría la cara a
    // pueblos que ya existen.
    TownCharacter(
      region: 'Encrucijada',
      suits:
          'Para los vínculos: llamar a la familia, escribirle a un amigo, '
          'salir más, tener paciencia con los demás.',
      symbol: 'brujula',
      blurb:
          'Pueblo de camino: posadas, plazas anchas y casas de colores '
          'distintos.',
      storey: 1.02,
      spread: 1.15,
      pitch: 0.85,
      roofMix: (0.50, 0.26, 0.24),
      // Pocas casas con el mismo encalado: en un cruce de caminos cada una es
      // de quien vino de otro sitio.
      wash: Color(0xFFE2B49C),
      washShare: 0.46,
      plotPitch: 2.6,
      order: 0xD4A3,
      wallThick: 0.20,
      windowGap: 0.90,
      gardens: 0.18,
      trees: 0.16,
    ),
    TownCharacter(
      region: 'Alfar',
      suits:
          'Para lo creativo: dibujar, tocar música, escribir, fotografiar, lo '
          'que se hace con las manos.',
      symbol: 'olla',
      blurb: 'De artesanos: talleres y hornos, barro cocido y tejados rojos.',
      storey: 0.94,
      spread: 1.05,
      pitch: 0.70,
      roofMix: (0.86, 0.04, 0.10),
      wash: Color(0xFFD27A4E),
      washShare: 0.90,
      plotPitch: 2.5,
      order: 0xE817,
      wallThick: 0.35,
      windowGap: 1.00,
      gardens: 0.14,
      trees: 0.12,
    ),
  ];

  /// The one a plot would have been given before anybody was asked. Kept for
  /// towns founded when the valley chose for you.
  ///
  /// Sobre las seis primeras y no sobre la lista entera: las que se agregaron
  /// después no pueden cambiarle la comarca de fábrica a ningún solar.
  static TownCharacter forSlot(int slot) => all[slot.abs() % _deFabrica];
  static const int _deFabrica = 6;

  /// By its stable id. Anything unknown falls back to the first, so a save
  /// from a version that had a region this one does not still opens.
  static TownCharacter byOrder(int order) {
    for (final c in all) {
      if (c.order == order) return c;
    }
    return all.first;
  }
}
