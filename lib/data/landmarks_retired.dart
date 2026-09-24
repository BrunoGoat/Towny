import '../engine/mason.dart';
import 'landmarks.dart';

/// Lo que el pueblo supo construir y ya no se le ofrece.
///
/// Cincuenta y tres obras que salieron del catálogo: casi todas eran el
/// mismo cobertizo con otro nombre —tejar, tinte, batán, tenada, majada— o un
/// mojón al que no había nada que mirarle. Un catálogo de ciento trece obras
/// de las que la mitad se confunden entre sí no es más rico que uno de
/// sesenta que se distinguen: es el mismo pueblo con más ruido.
///
/// **Pero las recetas se quedan aquí, y hay un motivo.** Un pueblo apunta en
/// su crónica lo que levantó, por su nombre, y esa anotación es para siempre:
/// si el nombre deja de significar algo, la obra que ya está en pie se
/// convierte en una casa corriente, cuesta otra cantidad de piezas, y todo lo
/// que se construyó después de ella se corre de sitio. Un pueblo que se
/// rehace solo cuando se actualiza la app no es el registro de nada.
///
/// Así que se retiran, que es distinto de borrarse: no se sortean, no se
/// ofrecen, no salen en la sala de exposición y no se cuentan. Sólo se
/// consultan cuando una crónica vieja las nombra, para volver a levantar
/// exactamente lo que ese pueblo levantó.
final List<Landmark> retiredLandmarks = [
  Landmark(
    'fuente',
    'Fuente de la plaza',
    7,
    0,
    'Cuatro caños y una plaza alrededor. Aquí es donde la gente se para a hablar.',
    (m) {
      m.water(2.3, 2.3);
      m.plinth(1.5, 1.5, 0.26);
      m.parapet(1.15, 1.15, 0.34);
      m.post(0.42, 0.8, at: 0.6);
      m.dome(0.6, 0.6, 0.36, at: 1.4);
      m.tree(0.95, 1.5, dx: 1.5, dz: 1.1);
      m.tree(0.9, 1.35, dx: -1.4, dz: -1.2);
    },
  ),
  Landmark(
    'horno',
    'Horno comunal',
    6,
    0,
    'Un solo fuego para todo el pueblo, encendido por turnos. Huele a pan desde tres calles.',
    (m) {
      m.plinth(2.0, 1.7, 0.24);
      m.floor(1.7, 1.4, 0.85);
      m.dome(1.5, 1.3, 0.7);
      m.chimney(0.3, 0.9, dx: 0.5);
      m.box(PieceKind.parapet, 0.9, 0.5, 0.3, dx: -1.05, at: 0);
      m.tree(0.8, 1.2, dx: 1.5, dz: -1.0);
    },
  ),
  Landmark(
    'fragua',
    'Fragua',
    7,
    0,
    'Golpes de martillo antes del amanecer. Todo lo que corta y todo lo que sujeta sale de aquí.',
    (m) {
      m.plinth(2.1, 1.8, 0.2);
      m.floor(1.8, 1.5, 1.0);
      m.roof(2.0, 1.7, 0.5);
      m.chimney(0.42, 1.3, dx: 0.55);
      m.post(0.16, 1.0, dx: -1.15, dz: 0.7);
      m.beam(0.7, 1.5, 0.14, dx: -1.15, at: 1.0);
      m.water(0.9, 0.9, dx: -1.1, dz: -0.7);
    },
  ),
  Landmark(
    'lavadero',
    'Lavadero',
    7,
    0,
    'Piedra inclinada y agua corriente. También el sitio donde se sabe todo lo que pasa.',
    (m) {
      m.water(2.6, 1.6, dz: 0.3);
      m.plinth(2.4, 0.5, 0.28, dz: -0.75);
      m.post(0.14, 1.1, dx: -0.95, dz: -0.75);
      m.post(0.14, 1.1, dx: 0.95, dz: -0.75);
      m.beam(2.2, 0.2, 0.14, dz: -0.75, at: 1.1);
      m.roof(2.5, 1.1, 0.4, dz: -0.5, at: 1.24);
      m.tree(0.9, 1.4, dx: -1.6, dz: 1.0);
    },
  ),
  Landmark(
    'abrevadero',
    'Abrevadero',
    6,
    0,
    'Los animales beben, y los que van de camino paran. Media posada por el precio de una piedra.',
    (m) {
      m.water(2.2, 0.9, dz: 0.2);
      m.plinth(2.4, 1.1, 0.3, dz: 0.2);
      m.post(0.2, 1.4, dx: -1.3, dz: -0.5);
      m.beam(0.6, 0.2, 0.16, dx: -1.3, at: 1.4);
      m.palisade(2.4, 0.8, dz: -0.9);
      m.tree(1.0, 1.7, dx: 1.4, dz: -0.9);
    },
  ),
  Landmark(
    'era',
    'Era de trillar',
    6,
    0,
    'Suelo duro y barrido, para separar el grano de la paja. Un año entero acaba aquí.',
    (m) {
      m.plinth(2.8, 2.8, 0.12);
      m.box(PieceKind.parapet, 3.0, 3.0, 0.16, at: 0);
      m.post(0.22, 1.1, dx: 0.0, dz: 0.0, at: 0.16);
      m.box(PieceKind.dormer, 1.1, 0.6, 0.5, dx: -1.0, dz: 1.0, at: 0.16);
      m.palisade(2.8, 0.55, dz: -1.5);
      m.tree(1.0, 1.6, dx: 1.6, dz: -1.2);
    },
  ),
  Landmark(
    'porqueriza',
    'Porqueriza',
    6,
    0,
    'Feo, sí. Pero es la carne de todo el invierno.',
    (m) {
      m.floor(1.6, 1.1, 0.75);
      m.roof(1.8, 1.3, 0.35);
      m.palisade(2.6, 0.7, dz: 1.4);
      m.palisade(2.6, 0.7, dx: -1.3, along: false);
      m.palisade(2.6, 0.7, dx: 1.3, along: false);
      m.water(0.8, 0.7, dz: 1.0);
    },
  ),
  Landmark(
    'lenera',
    'Leñera',
    6,
    0,
    'Leña apilada y seca. En enero esto vale más que la plata.',
    (m) {
      m.plinth(2.0, 1.3, 0.18);
      m.post(0.16, 1.1, dx: -0.85, dz: -0.5, at: 0.18);
      m.post(0.16, 1.1, dx: 0.85, dz: -0.5, at: 0.18);
      m.post(0.16, 1.1, dx: -0.85, dz: 0.5, at: 0.18);
      m.beam(2.0, 1.3, 0.14, at: 1.28);
      m.roof(2.2, 1.5, 0.45, at: 1.42);
    },
  ),
  Landmark(
    'carbonera',
    'Carbonera',
    7,
    0,
    'La madera arde tapada, días enteros, hasta volverse carbón. Paciencia hecha oficio.',
    (m) {
      m.plinth(2.4, 2.4, 0.14);
      m.dome(1.9, 1.9, 1.1);
      m.chimney(0.26, 0.5, dx: 0.05);
      m.box(PieceKind.parapet, 0.9, 0.6, 0.35, dx: -1.3, dz: 0.7, at: 0);
      m.post(0.16, 1.0, dx: 1.35, dz: -0.8);
      m.tree(1.0, 1.8, dx: -1.6, dz: -1.1);
      m.tree(0.9, 1.5, dx: 1.5, dz: 1.3);
    },
  ),
  Landmark(
    'tejar',
    'Tejar',
    7,
    0,
    'De aquí salen las tejas de todos los tejados que se ven desde aquí.',
    (m) {
      m.plinth(2.2, 1.9, 0.24);
      m.floor(1.8, 1.55, 0.95);
      m.dome(1.6, 1.4, 0.75);
      m.chimney(0.34, 1.0, dx: 0.42);
      m.field(2.2, 0.9, dz: -1.7);
      m.post(0.16, 1.0, dx: -1.4, dz: 0.6);
      m.beam(1.0, 1.6, 0.14, dx: -1.5, at: 1.0);
    },
  ),
  Landmark(
    'tinte',
    'Tinte',
    7,
    0,
    'Cubas de color y las manos manchadas por semanas. Que la ropa no sea siempre parda.',
    (m) {
      m.plinth(2.0, 1.7, 0.2);
      m.floor(1.7, 1.45, 1.05);
      m.roof(1.95, 1.7, 0.5);
      m.water(0.85, 0.85, dx: -1.35, dz: -0.6);
      m.water(0.85, 0.85, dx: -1.35, dz: 0.6);
      m.post(0.16, 1.5, dx: 1.35, dz: -0.6);
      m.beam(0.24, 1.5, 0.14, dx: 1.35, at: 1.5);
    },
  ),
  Landmark(
    'batan',
    'Batán',
    8,
    0,
    'Mazos de madera batiendo el paño hasta que aprieta. La lana se vuelve tela.',
    (m) {
      m.water(3.0, 1.0, dz: 1.3);
      m.plinth(2.0, 1.7, 0.28);
      m.floor(1.7, 1.45, 1.0);
      m.roof(1.95, 1.7, 0.5);
      m.wheel(1.1, dz: 1.1, along: true);
      m.post(0.16, 1.0, dx: -1.3, dz: -0.6);
      m.beam(0.9, 0.9, 0.14, dx: -1.3, dz: -0.6, at: 1.0);
      m.tree(0.9, 1.4, dx: 1.5, dz: -1.0);
    },
  ),
  Landmark(
    'picota',
    'Cepo y picota',
    6,
    0,
    'No es bonito. Pero un pueblo con leyes propias es un pueblo que ya se gobierna.',
    (m) {
      m.plinth(1.6, 1.6, 0.22);
      m.plinth(1.1, 1.1, 0.2);
      m.post(0.26, 2.0, at: 0.42);
      m.beam(0.9, 0.24, 0.2, at: 2.2);
      m.box(PieceKind.parapet, 0.6, 0.4, 0.4, dx: 1.0, dz: 0.5, at: 0);
      m.stair(1.0, 0.42, 0.6, dz: -1.0);
    },
  ),
  Landmark(
    'ermita',
    'Ermita',
    7,
    0,
    'Pequeña, apartada y siempre abierta. Para el que pasa y para el que no quiere compañía.',
    (m) {
      m.plinth(2.4, 1.8, 0.26);
      m.floor(2.0, 1.5, 1.2);
      m.roof(2.25, 1.75, 0.75, along: true);
      m.box(PieceKind.parapet, 0.7, 0.3, 0.55, at: 1.46);
      m.post(0.18, 0.4, at: 2.01);
      m.tree(1.1, 1.9, dx: -1.7, dz: 0.8);
      m.palisade(2.6, 0.5, dz: 1.4);
    },
  ),
  Landmark(
    'humilladero',
    'Humilladero',
    6,
    0,
    'Cuatro pilares y un tejado, en el cruce de caminos. Para arrodillarse al salir y al volver.',
    (m) {
      m.plinth(1.8, 1.8, 0.24);
      m.post(0.2, 1.5, dx: -0.65, dz: -0.65, at: 0.24);
      m.post(0.2, 1.5, dx: 0.65, dz: -0.65, at: 0.24);
      m.post(0.2, 1.5, dx: -0.65, dz: 0.65, at: 0.24);
      m.post(0.2, 1.5, dx: 0.65, dz: 0.65, at: 0.24);
      m.roof(2.0, 2.0, 0.7, at: 1.74);
    },
  ),
  Landmark(
    'osario',
    'Osario',
    7,
    0,
    'Los que levantaron esto siguen aquí. Un pueblo también se hace de eso.',
    (m) {
      m.plinth(2.0, 1.6, 0.3);
      m.floor(1.7, 1.3, 0.85);
      m.arcade(1.7, 0.75, 1.3, at: 1.15);
      m.roof(1.95, 1.55, 0.5, at: 1.9);
      m.spire(0.3, 0.3, 0.55, at: 2.15);
      m.tree(1.0, 1.8, dx: 1.5, dz: -0.9);
      m.palisade(2.4, 0.55, dz: 1.3);
    },
  ),
  Landmark(
    'mojon',
    'Mojón de piedra',
    6,
    0,
    'Hasta aquí llega el pueblo. Ahora hay un dentro y un fuera.',
    (m) {
      m.plinth(1.3, 1.3, 0.24);
      m.plinth(0.85, 0.85, 0.5);
      m.parapet(0.6, 0.6, 0.7);
      m.spire(0.55, 0.55, 0.5);
      m.box(PieceKind.parapet, 0.5, 0.35, 0.28, dx: 1.1, at: 0);
      m.tree(0.9, 1.5, dx: -1.4, dz: 0.9);
    },
  ),
  Landmark(
    'pasarela',
    'Puente de tablas',
    7,
    0,
    'Cuatro postes y unos tablones. El arroyo ya no decide quién cruza.',
    (m) {
      m.water(3.4, 1.5);
      m.post(0.2, 0.9, dx: -1.0, dz: -0.5);
      m.post(0.2, 0.9, dx: 1.0, dz: -0.5);
      m.post(0.2, 0.9, dx: -1.0, dz: 0.5);
      m.post(0.2, 0.9, dx: 1.0, dz: 0.5);
      m.beam(3.2, 1.3, 0.16, at: 0.9);
      m.palisade(3.2, 0.45, dz: 0.62, along: true);
    },
  ),
  Landmark(
    'vado',
    'Vado empedrado',
    7,
    0,
    'Piedras asentadas en el fondo. Se pasa a pie enjuto casi todo el año.',
    (m) {
      m.water(3.4, 1.8);
      m.plinth(3.2, 0.9, 0.14);
      m.box(PieceKind.parapet, 0.7, 0.7, 0.3, dx: -1.2, dz: 0.8, at: 0);
      m.box(PieceKind.parapet, 0.6, 0.6, 0.26, dx: 1.1, dz: -0.8, at: 0);
      m.post(0.18, 1.3, dx: -1.5, dz: -0.9);
      m.post(0.18, 1.3, dx: 1.5, dz: 0.9);
      m.tree(1.0, 1.7, dx: 1.6, dz: -1.3);
    },
  ),
  Landmark(
    'barca',
    'Barca de paso',
    8,
    0,
    'Una maroma de orilla a orilla. El río deja de ser una pared.',
    (m) {
      m.water(3.6, 2.0, dz: 0.6);
      m.plinth(1.8, 0.9, 0.26, dz: -1.1);
      m.post(0.18, 1.6, dx: -0.8, dz: -1.1);
      m.beam(1.8, 0.18, 0.14, dz: -1.1, at: 1.6);
      m.box(PieceKind.porch, 1.5, 0.6, 0.3, dz: 0.7, at: 0.02);
      m.post(0.14, 1.2, dz: 0.7, at: 0.32);
      m.outbuilding(1.2, 1.0, 0.85, 0.4, dx: 1.5, dz: -1.2);
    },
  ),
  Landmark(
    'tenada',
    'Tenada',
    6,
    0,
    'Techo sin paredes, para el ganado y para el que se moje.',
    (m) {
      m.plinth(2.4, 1.5, 0.16);
      m.post(0.18, 1.3, dx: -1.0, dz: -0.6, at: 0.16);
      m.post(0.18, 1.3, dx: 1.0, dz: -0.6, at: 0.16);
      m.post(0.18, 1.3, dx: -1.0, dz: 0.6, at: 0.16);
      m.beam(2.4, 1.5, 0.16, at: 1.46);
      m.roof(2.7, 1.8, 0.55, at: 1.62);
    },
  ),
  Landmark(
    'majada',
    'Majada',
    7,
    0,
    'Cerco, abrigo y agua. El rebaño puede quedarse fuera del pueblo.',
    (m) {
      m.palisade(3.0, 0.8, dz: -1.5);
      m.palisade(3.0, 0.8, dx: -1.5, along: false);
      m.palisade(3.0, 0.8, dx: 1.5, along: false);
      m.floor(1.5, 1.1, 0.8, dz: -0.9);
      m.roof(1.75, 1.35, 0.45, dz: -0.9);
      m.water(1.0, 0.8, dz: 0.9);
      m.tree(1.1, 1.9, dx: 1.6, dz: 1.4);
    },
  ),
  Landmark(
    'huertaCercada',
    'Huerta cercada',
    8,
    0,
    'Tres bancales cercados. Lo que se cena en agosto se planta en marzo.',
    (m) {
      m.field(2.6, 1.0, dz: -1.0);
      m.field(2.6, 1.0, dz: 0.0);
      m.field(2.6, 1.0, dz: 1.0);
      m.palisade(3.0, 0.65, dz: -1.6);
      m.palisade(3.0, 0.65, dz: 1.6);
      m.palisade(3.2, 0.65, dx: -1.5, along: false);
      m.tree(1.0, 1.7, dx: 1.7, dz: -1.2);
      m.water(0.9, 0.9, dx: 1.5, dz: 1.2);
    },
  ),
  Landmark(
    'molinoAgua',
    'Molino de agua',
    14,
    1,
    'La rueda gira sola día y noche. El río trabaja gratis.',
    (m) {
      m.water(4.4, 1.6, dz: 2.0);
      m.water(1.6, 2.4, dx: -2.0, dz: 0.6);
      m.plinth(2.6, 2.2, 0.42);
      m.floor(2.3, 1.9, 1.1);
      m.floor(2.2, 1.85, 0.95);
      m.roof(2.6, 2.25, 0.85);
      m.wheel(1.9, dz: 1.7, along: true);
      m.beam(0.5, 1.6, 0.22, dz: 1.3, at: 1.5);
      m.dormer(0.55, 0.5, dz: -0.5);
      m.chimney(0.32, 0.9, dx: 0.75);
      m.stair(1.0, 0.44, 0.8, dz: -1.5);
      m.field(2.8, 1.2, dz: -2.4);
      m.tree(1.1, 2.0, dx: 2.2, dz: -1.4);
      m.palisade(2.8, 0.6, dx: 2.0, along: false);
    },
  ),
  Landmark(
    'acena',
    'Aceña del río',
    13,
    1,
    'Dos ruedas dentro del cauce, sobre pilas de piedra. Muele aunque el verano baje el agua.',
    (m) {
      m.water(4.6, 3.0, dz: 0.8);
      m.post(0.34, 1.0, dx: -1.2, dz: 1.2);
      m.post(0.34, 1.0, dx: 1.2, dz: 1.2);
      m.plinth(2.8, 1.9, 0.35, dz: -0.4);
      m.floor(2.4, 1.6, 1.15, dz: -0.4);
      m.roof(2.75, 1.95, 0.8, dz: -0.4);
      m.wheel(1.7, dx: -1.9, along: false);
      m.wheel(1.7, dx: 1.9, along: false);
      m.beam(4.0, 0.3, 0.2, dz: 0.9, at: 1.0);
      m.dormer(0.55, 0.5, dz: -0.9);
      m.chimney(0.3, 0.85, dx: 0.6, dz: -0.4);
      m.stair(0.9, 0.42, 0.8, dz: -1.7);
      m.tree(1.1, 2.0, dx: -2.4, dz: -1.6);
    },
  ),
  Landmark(
    'noria',
    'Noria',
    13,
    1,
    'Cangilones subiendo agua del río a la huerta. El verano deja de dar miedo.',
    (m) {
      m.water(2.0, 3.6, dx: -1.4);
      m.plinth(2.2, 2.2, 0.4, dx: 0.6);
      m.post(0.36, 2.2, dx: -0.35, dz: -0.9, at: 0.4);
      m.post(0.36, 2.2, dx: -0.35, dz: 0.9, at: 0.4);
      m.wheel(2.6, dx: -0.35, along: false);
      m.beam(1.6, 2.2, 0.24, dx: 0.1, at: 2.6);
      m.arcade(3.0, 0.9, 0.5, dx: 1.6, along: false, at: 0.4);
      m.field(2.4, 1.2, dz: -2.2);
      m.field(2.4, 1.2, dz: 2.2);
      m.floor(1.1, 1.0, 0.8, dx: 1.9, dz: -1.2);
      m.roof(1.3, 1.2, 0.42, dx: 1.9, dz: -1.2);
      m.tree(1.0, 1.8, dx: 2.0, dz: 1.4);
      m.palisade(2.8, 0.6, dz: -2.9);
    },
  ),
  Landmark(
    'serreria',
    'Serrería',
    13,
    1,
    'La sierra corta sola con la fuerza del agua. Las vigas ya no vienen de fuera.',
    (m) {
      m.water(4.0, 1.4, dz: 1.9);
      m.plinth(2.8, 2.0, 0.3);
      m.floor(2.5, 1.75, 1.15);
      m.roof(2.9, 2.15, 0.8);
      m.wheel(1.5, dz: 1.6, along: true);
      m.post(0.2, 1.3, dx: -1.7, dz: -1.0);
      m.post(0.2, 1.3, dx: 1.7, dz: -1.0);
      m.beam(3.8, 1.2, 0.16, dz: -1.3, at: 1.3);
      m.roof(4.0, 1.5, 0.4, dz: -1.3, at: 1.46);
      m.chimney(0.28, 0.8, dx: 0.85);
      m.tree(1.2, 2.2, dx: -2.3, dz: 0.8);
      m.tree(1.0, 1.9, dx: 2.3, dz: -1.9);
      m.palisade(2.6, 0.6, dx: 2.1, along: false);
    },
  ),
  Landmark(
    'lagar',
    'Lagar y viñedo',
    14,
    1,
    'Cepas en línea y una prensa al fondo. Habrá vino propio, y habrá vendimia.',
    (m) {
      for (var i = 0; i < 4; i++) {
        m.palisade(3.4, 0.75, dz: -2.4 + i * 0.8);
      }
      m.field(3.4, 3.2, dz: -1.2);
      m.plinth(2.4, 1.9, 0.3, dz: 1.4);
      m.floor(2.1, 1.65, 1.1, dz: 1.4);
      m.roof(2.45, 2.0, 0.7, dz: 1.4);
      m.post(0.24, 1.6, dx: -1.5, dz: 1.4);
      m.beam(0.9, 1.7, 0.2, dx: -1.6, dz: 1.4, at: 1.6);
      m.chimney(0.28, 0.8, dx: 0.7, dz: 1.4);
      m.water(0.9, 0.9, dx: 1.6, dz: 2.2);
      m.tree(1.1, 1.9, dx: -2.2, dz: -2.4);
      m.dormer(0.55, 0.5, dz: 1.9);
    },
  ),
  Landmark(
    'tahona',
    'Tahona',
    11,
    1,
    'Amasan de noche para que haya pan de mañana. Nadie se acuerda de agradecerlo.',
    (m) {
      m.plinth(2.5, 2.0, 0.3);
      m.floor(2.2, 1.75, 1.15);
      m.floor(2.15, 1.7, 0.95);
      m.roof(2.55, 2.1, 0.75);
      m.dome(1.2, 1.1, 0.75, dx: -1.75, at: 0);
      m.box(
        PieceKind.chimney,
        0.24,
        0.24,
        0.45,
        dx: -1.75,
        ridge: true,
        at: 0.55,
      );
      m.chimney(0.3, 0.9, dx: 0.7);
      m.box(PieceKind.porch, 1.4, 0.5, 0.35, dz: 1.2, at: 1.0);
      m.dormer(0.6, 0.55, dz: 0.5);
      m.banner(0.7, dx: 1.1, dz: 1.1, at: 1.6);
      m.field(2.2, 0.9, dz: -1.9);
    },
  ),
  Landmark(
    'carniceria',
    'Carnicería',
    11,
    1,
    'Con tabla a la calle y peso vigilado por el concejo. La carne deja de ser cosa de fiesta.',
    (m) {
      m.plinth(2.4, 1.9, 0.3);
      m.floor(2.1, 1.65, 1.15);
      m.floor(2.05, 1.6, 0.9);
      m.roof(2.45, 2.0, 0.7);
      m.arcade(2.1, 0.9, 0.6, dz: 1.2, at: 0.3);
      m.beam(2.3, 0.6, 0.16, dz: 1.2, at: 1.2);
      m.roof(2.5, 0.9, 0.35, dz: 1.35, at: 1.36);
      m.chimney(0.28, 0.85, dx: -0.7);
      m.dormer(0.55, 0.5, dz: 0.4);
      m.water(0.9, 0.8, dx: 1.7, dz: -0.9);
      m.palisade(2.2, 0.6, dz: -1.6);
    },
  ),
  Landmark(
    'pescaderia',
    'Pescadería',
    12,
    1,
    'Del río a la piedra fría en una mañana. Los viernes tienen arreglo.',
    (m) {
      m.water(3.6, 1.6, dz: 1.9);
      m.plinth(2.4, 1.8, 0.34);
      m.floor(2.1, 1.55, 1.1);
      m.roof(2.45, 1.9, 0.7);
      m.arcade(2.1, 0.85, 0.55, dz: 1.05, at: 0.34);
      m.beam(2.3, 0.55, 0.15, dz: 1.05, at: 1.19);
      m.roof(2.5, 0.9, 0.32, dz: 1.2, at: 1.34);
      m.post(0.16, 1.0, dx: -1.5, dz: 1.9);
      m.post(0.16, 1.0, dx: 1.5, dz: 1.9);
      m.beam(3.2, 0.9, 0.14, dz: 1.9, at: 1.0);
      m.dormer(0.55, 0.5, dz: -0.4);
      m.tree(1.0, 1.8, dx: -2.0, dz: -1.2);
    },
  ),
  Landmark(
    'alhondiga',
    'Alhóndiga',
    14,
    1,
    'Se guarda el grano de todos y se vende al precio justo. Contra el hambre y contra el usurero.',
    (m) {
      m.plinth(3.2, 2.4, 0.34);
      m.floor(2.9, 2.1, 1.2);
      m.floor(2.85, 2.05, 1.05);
      m.floor(2.8, 2.0, 0.95);
      m.roof(3.25, 2.5, 0.9);
      m.arcade(2.9, 1.0, 0.55, dz: 1.25, at: 0.34);
      m.dormer(0.65, 0.6, dz: 0.8);
      m.dormer(0.65, 0.6, dz: -0.8);
      m.chimney(0.32, 0.9, dx: -1.0);
      m.chimney(0.28, 0.8, dx: 1.0);
      m.banner(1.0, dz: 1.4, at: 2.2);
      m.stair(1.5, 0.34, 0.7, dz: 1.7);
      m.box(PieceKind.parapet, 0.9, 0.6, 0.36, dx: -2.1, dz: 1.4, at: 0);
      m.tree(1.0, 1.9, dx: 2.2, dz: 1.5);
    },
  ),
  Landmark(
    'aduana',
    'Aduana',
    12,
    1,
    'Lo que entra paga. Poco elegante, pero es lo que paga todo lo demás.',
    (m) {
      m.plinth(3.0, 2.2, 0.36);
      m.floor(2.7, 1.95, 1.2);
      m.floor(2.65, 1.9, 1.0);
      m.roof(3.05, 2.3, 0.85);
      m.arcade(2.7, 1.0, 0.5, dz: 1.15, at: 0.36);
      m.dormer(0.6, 0.55, dz: 0.7);
      m.chimney(0.3, 0.9, dx: -0.9);
      m.banner(1.2, dz: 1.3, at: 2.0);
      m.post(0.24, 1.8, dx: -2.2, dz: 1.4);
      m.post(0.24, 1.8, dx: 2.2, dz: 1.4);
      m.beam(4.6, 0.28, 0.2, dz: 1.4, at: 1.8);
      m.stair(1.4, 0.36, 0.7, dz: 1.6);
    },
  ),
  Landmark(
    'canteros',
    'Gremio de canteros',
    13,
    1,
    'Los que saben cortar piedra ya no vienen de fuera: viven aquí.',
    (m) {
      m.plinth(2.8, 2.2, 0.36);
      m.floor(2.5, 1.95, 1.2);
      m.floor(2.45, 1.9, 1.0);
      m.parapet(2.75, 2.15, 0.32);
      m.roof(2.7, 2.1, 0.7);
      m.arcade(2.4, 0.95, 0.5, dz: 1.15, at: 0.36);
      m.box(PieceKind.plinth, 1.1, 1.1, 0.5, dx: -2.0, dz: -0.8, at: 0);
      m.box(PieceKind.plinth, 0.8, 0.8, 0.45, dx: -2.0, dz: 0.7, at: 0);
      m.post(0.5, 1.4, dx: 2.0, dz: -0.9);
      m.chimney(0.3, 0.9, dx: 0.8);
      m.banner(0.9, dz: 1.25, at: 2.2);
      m.stair(1.2, 0.36, 0.65, dz: 1.5);
      m.tree(1.0, 1.9, dx: 2.2, dz: 1.5);
    },
  ),
  Landmark(
    'herrador',
    'Casa del herrador',
    11,
    1,
    'Un caballo cojo no llega a ningún lado. Todo el camino pasa por esta puerta.',
    (m) {
      m.plinth(2.4, 1.9, 0.28);
      m.floor(2.1, 1.65, 1.1);
      m.floor(2.05, 1.6, 0.9);
      m.roof(2.45, 2.0, 0.7);
      m.chimney(0.4, 1.2, dx: -0.75);
      m.post(0.18, 1.2, dx: -1.6, dz: 1.2);
      m.post(0.18, 1.2, dx: 1.6, dz: 1.2);
      m.beam(3.4, 1.0, 0.16, dz: 1.2, at: 1.2);
      m.roof(3.5, 1.3, 0.4, dz: 1.25, at: 1.36);
      m.water(0.85, 0.85, dx: 1.7, dz: -0.8);
      m.palisade(2.4, 0.7, dz: -1.6);
    },
  ),
  Landmark(
    'cuadras',
    'Cuadras',
    12,
    1,
    'Cuadras y abrevadero. Los que van de paso ya pueden quedarse a dormir.',
    (m) {
      m.plinth(3.4, 2.0, 0.26);
      m.floor(3.1, 1.75, 1.05);
      m.roof(3.5, 2.15, 0.8);
      m.dormer(0.6, 0.55, dx: -1.0, dz: 0.5);
      m.dormer(0.6, 0.55, dx: 0.0, dz: 0.5);
      m.dormer(0.6, 0.55, dx: 1.0, dz: 0.5);
      m.palisade(3.4, 0.85, dz: -1.9);
      m.palisade(2.6, 0.85, dx: -1.9, along: false);
      m.palisade(2.6, 0.85, dx: 1.9, along: false);
      m.water(1.0, 0.8, dz: -1.4);
      m.field(3.0, 0.9, dz: -2.5);
      m.tree(1.1, 2.0, dx: 2.2, dz: 1.4);
    },
  ),
  Landmark(
    'posadaCamino',
    'Posada del camino',
    14,
    1,
    'Cama, cuadra y fuego. El pueblo empieza a estar en el mapa de alguien.',
    (m) {
      m.plinth(3.0, 2.3, 0.3);
      m.floor(2.7, 2.05, 1.15);
      m.floor(2.65, 2.0, 1.05);
      m.floor(2.6, 1.95, 0.95);
      m.roof(3.05, 2.4, 0.9);
      m.dormer(0.7, 0.6, dx: -0.8, dz: 0.8);
      m.dormer(0.7, 0.6, dx: 0.8, dz: 0.8);
      m.chimney(0.34, 1.0, dx: -1.1);
      m.chimney(0.3, 0.9, dx: 1.1);
      m.banner(1.0, dx: 1.2, dz: 1.35, at: 1.6);
      m.outbuilding(1.6, 1.3, 0.9, 0.5, dx: 2.3, dz: -0.8);
      m.water(0.9, 0.8, dx: -2.2, dz: 1.2);
      m.tree(1.1, 2.1, dx: -2.2, dz: -1.2);
    },
  ),
  Landmark(
    'leproseria',
    'Leprosería',
    12,
    1,
    'Apartada, con su cerco y su pozo. Cuidar a los que dan miedo dice más que una catedral.',
    (m) {
      m.palisade(3.6, 1.0, dz: -2.0);
      m.palisade(3.6, 1.0, dz: 2.0);
      m.palisade(4.0, 1.0, dx: -1.8, along: false);
      m.plinth(2.6, 2.0, 0.28, dx: 0.4);
      m.floor(2.3, 1.75, 1.05, dx: 0.4);
      m.roof(2.65, 2.1, 0.75, dx: 0.4);
      m.box(PieceKind.parapet, 0.6, 0.26, 0.5, dx: 0.4, at: 1.33);
      m.chimney(0.28, 0.85, dx: -0.4);
      m.water(1.0, 0.9, dx: -1.0, dz: 1.5);
      m.tree(1.1, 2.0, dx: 1.9, dz: -1.5);
      m.tree(1.0, 1.8, dx: 1.9, dz: 1.5);
      m.field(2.0, 0.9, dx: -0.6, dz: -1.5);
    },
  ),
  Landmark(
    'banos',
    'Baños',
    12,
    1,
    'Agua caliente bajo una cúpula. Un lujo, y de los que se notan.',
    (m) {
      m.plinth(3.0, 2.6, 0.34);
      m.floor(2.7, 2.3, 1.15);
      m.dome(2.5, 2.1, 1.0);
      m.dome(1.0, 1.0, 0.55, dx: -1.55, dz: -0.8, at: 0.34);
      m.dome(1.0, 1.0, 0.55, dx: -1.55, dz: 0.8, at: 0.34);
      m.chimney(0.28, 0.8, dx: 0.9);
      m.water(1.6, 1.6, dx: 2.2, dz: 0.6);
      m.arcade(2.0, 0.9, 0.5, dz: 1.4, at: 0.34);
      m.post(0.2, 1.3, dx: 1.6, dz: 1.6);
      m.beam(1.6, 0.24, 0.16, dx: 2.2, dz: 1.6, at: 1.3);
      m.tree(1.1, 2.0, dx: -2.2, dz: 1.4);
      m.stair(1.2, 0.34, 0.6, dz: 1.7);
    },
  ),
  Landmark(
    'palomarTorre',
    'Palomar torre',
    12,
    1,
    'Mil nidos en una torre. Palomas, abono y correo, todo en la misma piedra.',
    (m) {
      m.plinth(2.2, 2.2, 0.36);
      m.shaft(1.6, 4, 0.8, taper: 0.06);
      m.parapet(1.85, 1.85, 0.32);
      m.dome(1.6, 1.6, 0.9);
      m.dome(0.5, 0.5, 0.4, at: 4.78);
      m.arcade(1.4, 0.7, 0.4, dz: 0.85, at: 2.76);
      m.palisade(2.6, 0.6, dz: -1.5);
      m.tree(1.0, 1.8, dx: 1.8, dz: 1.3);
      m.field(2.2, 0.9, dz: 1.9);
    },
  ),
  Landmark(
    'reloj',
    'Torre del reloj',
    15,
    1,
    'La misma hora para todos. Parece poca cosa y lo cambia todo.',
    (m) {
      m.plinth(2.3, 2.3, 0.42);
      m.shaft(1.75, 6, 0.82);
      m.parapet(2.05, 2.05, 0.4);
      m.spire(1.8, 1.8, 1.5);
      m.dormer(0.6, 0.6, dz: -0.95, at: 4.2);
      m.stair(1.1, 0.42, 0.7, dz: 1.45);
      m.banner(1.0, at: 7.24);
      m.arcade(1.5, 0.8, 0.4, dz: 0.95, at: 4.9);
      m.outbuilding(1.2, 1.1, 0.9, 0.5, dx: 2.0, dz: -0.9);
    },
  ),
  Landmark(
    'puente',
    'Puente de piedra',
    15,
    1,
    'Arcos de piedra, y ya no importa cómo venga el río.',
    (m) {
      m.water(5.0, 2.6, dz: 0.2);
      m.plinth(1.0, 2.4, 0.7, dx: -1.6, dz: 0.2);
      m.plinth(1.0, 2.4, 0.7, dx: 0.0, dz: 0.2);
      m.plinth(1.0, 2.4, 0.7, dx: 1.6, dz: 0.2);
      m.arcade(4.6, 1.0, 2.2, dz: 0.2, along: true, at: 0.7);
      m.beam(5.0, 2.4, 0.28, dz: 0.2, at: 1.7);
      m.palisade(5.0, 0.55, dz: -0.95);
      m.palisade(5.0, 0.55, dz: 1.35);
      m.plinth(1.4, 1.4, 0.6, dx: -2.6, dz: 0.2);
      m.plinth(1.4, 1.4, 0.6, dx: 2.6, dz: 0.2);
      m.post(0.3, 1.6, dx: -2.6, dz: 0.2, at: 1.98);
      m.post(0.3, 1.6, dx: 2.6, dz: 0.2, at: 1.98);
      m.banner(0.8, dx: -2.6, dz: 0.2, at: 3.58);
      m.stair(1.4, 0.4, 0.8, dx: -3.2, dz: 0.2);
      m.tree(1.1, 2.0, dx: 2.6, dz: -1.8);
    },
  ),
  Landmark(
    'acueducto',
    'Acueducto',
    18,
    1,
    'Dos órdenes de arcos trayendo agua desde el monte. Se cruza el valle por encima.',
    (m) {
      for (var i = 0; i < 4; i++) {
        m.plinth(0.7, 1.2, 0.5, dx: -2.4 + i * 1.6);
      }
      for (var i = 0; i < 4; i++) {
        m.post(0.55, 2.0, dx: -2.4 + i * 1.6, at: 0.5);
      }
      m.arcade(5.4, 1.3, 1.1, at: 2.5, along: true);
      m.beam(5.6, 1.2, 0.3, at: 3.8);
      m.arcade(5.4, 0.9, 0.9, at: 4.1, along: true);
      m.beam(5.6, 1.0, 0.26, at: 5.0);
      m.box(PieceKind.parapet, 5.6, 0.24, 0.4, dz: -0.42, at: 5.26);
      m.box(PieceKind.parapet, 5.6, 0.24, 0.4, dz: 0.42, at: 5.26);
      m.water(5.2, 0.5, dz: 0.0);
      m.tree(1.1, 2.1, dx: -3.2, dz: 1.4);
      m.tree(1.0, 1.9, dx: 3.2, dz: -1.4);
      m.field(3.0, 1.0, dz: 2.0);
    },
  ),
  Landmark(
    'presa',
    'Presa y azud',
    13,
    1,
    'El agua se remansa y se reparte cuando hace falta. Domesticar un río es cosa seria.',
    (m) {
      m.water(4.6, 2.0, dz: -1.3);
      m.water(4.6, 1.4, dz: 1.4);
      m.plinth(4.4, 0.9, 0.9, dz: 0.2);
      m.parapet(4.6, 1.1, 0.4, dz: 0.2);
      m.post(0.4, 1.4, dx: -2.0, dz: 0.2, at: 1.3);
      m.post(0.4, 1.4, dx: 2.0, dz: 0.2, at: 1.3);
      m.beam(4.6, 0.3, 0.2, dz: 0.2, at: 2.7);
      m.outbuilding(1.4, 1.2, 0.95, 0.5, dx: 2.6, dz: -1.4);
      m.wheel(1.3, dx: -2.4, dz: 0.9, along: false);
      m.tree(1.1, 2.0, dx: -2.8, dz: -2.0);
      m.field(2.6, 1.0, dz: 2.5);
      m.palisade(3.0, 0.5, dz: 3.1);
    },
  ),
  Landmark(
    'embarcadero',
    'Embarcadero',
    12,
    1,
    'Postes hincados y una plataforma. Lo que llega por agua ya puede desembarcar.',
    (m) {
      m.water(5.0, 3.2, dz: 1.2);
      for (var i = 0; i < 4; i++) {
        m.post(0.22, 1.0, dx: -1.5 + i * 1.0, dz: 1.4);
      }
      m.beam(3.6, 1.4, 0.18, dz: 1.4, at: 1.0);
      m.post(0.26, 2.2, dx: -1.8, dz: 1.4, at: 1.18);
      m.banner(0.8, dx: -1.8, dz: 1.4, at: 3.38);
      m.plinth(2.2, 1.6, 0.34, dz: -1.1);
      m.floor(1.9, 1.35, 1.0, dz: -1.1);
      m.roof(2.15, 1.6, 0.55, dz: -1.1);
      m.tree(1.1, 2.0, dx: 2.4, dz: -1.6);
    },
  ),
  Landmark(
    'astillero',
    'Astillero',
    15,
    1,
    'Una quilla en la grada. Aquí se empieza a construir para irse lejos.',
    (m) {
      m.water(5.0, 2.2, dz: 2.0);
      m.plinth(3.6, 2.2, 0.3, dz: -0.4);
      m.post(0.24, 2.0, dx: -1.6, dz: -1.2);
      m.post(0.24, 2.0, dx: 1.6, dz: -1.2);
      m.post(0.24, 2.0, dx: -1.6, dz: 0.4);
      m.post(0.24, 2.0, dx: 1.6, dz: 0.4);
      m.beam(3.6, 2.0, 0.22, dz: -0.4, at: 2.0);
      m.roof(3.9, 2.4, 0.7, dz: -0.4, at: 2.22);
      m.box(PieceKind.porch, 2.4, 0.8, 0.45, dz: 0.9, at: 0.3);
      m.post(0.2, 1.5, dz: 0.9, at: 0.75);
      m.outbuilding(1.3, 1.1, 0.9, 0.5, dx: 2.4, dz: -1.4);
      m.beam(0.4, 3.0, 0.2, dx: -2.3, at: 0.9);
      m.tree(1.1, 2.1, dx: -2.6, dz: -1.8);
      m.palisade(3.0, 0.6, dz: -1.9);
    },
  ),
  Landmark(
    'cantera',
    'Cantera',
    13,
    1,
    'De este agujero salió media villa. La cicatriz que deja construir.',
    (m) {
      m.plinth(4.0, 3.0, 0.16);
      m.stair(2.4, 0.45, 0.8, dz: -1.0, along: true);
      m.stair(2.0, 0.45, 0.7, dz: -0.3, at: 0.45, along: true);
      m.stair(1.6, 0.45, 0.6, dz: 0.3, at: 0.9, along: true);
      m.box(PieceKind.plinth, 1.2, 1.2, 0.6, dx: -1.4, dz: 1.2, at: 0.16);
      m.box(PieceKind.plinth, 0.9, 0.9, 0.45, dx: 1.4, dz: 1.2, at: 0.16);
      m.box(PieceKind.plinth, 0.7, 0.7, 0.4, dx: 0.2, dz: 1.5, at: 0.16);
      m.post(0.24, 2.4, dx: -1.9, dz: -1.2);
      m.beam(1.6, 0.24, 0.2, dx: -1.4, dz: -1.2, at: 2.4);
      m.floor(1.3, 1.1, 0.9, dx: 2.2, dz: -1.4);
      m.roof(1.55, 1.35, 0.5, dx: 2.2, dz: -1.4);
      m.tree(1.0, 1.8, dx: -2.4, dz: 1.6);
      m.palisade(3.2, 0.6, dz: 2.0);
    },
  ),
  Landmark(
    'teneria',
    'Tenería',
    13,
    1,
    'Huele mal y está en las afueras por algo. Pero el cuero es cuero.',
    (m) {
      for (var i = 0; i < 3; i++) {
        m.water(1.2, 1.2, dx: -1.6 + i * 1.6, dz: 1.6);
      }
      m.plinth(3.2, 2.0, 0.3, dz: -0.6);
      m.floor(2.9, 1.75, 1.15, dz: -0.6);
      m.roof(3.25, 2.1, 0.8, dz: -0.6);
      m.chimney(0.32, 0.95, dx: -1.0, dz: -0.6);
      m.post(0.18, 1.6, dx: -1.9, dz: 1.6);
      m.post(0.18, 1.6, dx: 1.9, dz: 1.6);
      m.beam(4.0, 0.9, 0.16, dz: 1.6, at: 1.6);
      m.dormer(0.6, 0.55, dz: -0.2);
      m.palisade(3.4, 0.6, dz: 2.4);
      m.tree(1.0, 1.8, dx: 2.4, dz: -1.6);
    },
  ),
  Landmark(
    'dehesa',
    'Dehesa',
    13,
    1,
    'Encinas viejas y sombra. El ganado engorda solo y nadie lo apura.',
    (m) {
      m.palisade(4.4, 0.75, dz: -2.0);
      m.palisade(4.4, 0.75, dz: 2.0);
      m.palisade(4.0, 0.75, dx: -2.3, along: false);
      m.palisade(4.0, 0.75, dx: 2.3, along: false);
      m.tree(1.5, 2.6, dx: -1.4, dz: -1.0);
      m.tree(1.5, 2.4, dx: 1.3, dz: 0.9);
      m.tree(1.4, 2.2, dx: 0.1, dz: 1.4);
      m.tree(1.4, 2.3, dx: 1.6, dz: -1.3);
      m.water(1.4, 1.1, dx: -1.4, dz: 1.3);
      m.floor(1.3, 1.0, 0.85, dx: 1.9, dz: -1.9);
      m.roof(1.55, 1.25, 0.45, dx: 1.9, dz: -1.9);
      m.field(2.0, 0.9, dx: -1.6, dz: 2.5);
      m.post(0.2, 1.3, dx: 2.3, dz: 0.0);
    },
  ),
  Landmark(
    'motte',
    'Mota y empalizada',
    23,
    2,
    'Un cerro levantado a mano, una empalizada y una torre encima. Así empezaron todos los castillos.',
    (m) {
      m.water(6.6, 6.6);
      m.plinth(5.0, 5.0, 0.5);
      m.plinth(4.2, 4.2, 0.55);
      m.plinth(3.4, 3.4, 0.6);
      for (final s in [-1.0, 1.0]) {
        m.palisade(3.6, 1.1, dz: s * 1.75);
        m.palisade(3.6, 1.1, dx: s * 1.75, along: false);
      }
      m.shaft(2.2, 3, 0.95);
      m.parapet(2.5, 2.5, 0.45);
      m.roof(2.4, 2.4, 1.1);
      m.banner(1.1, at: 5.9);
      m.stair(1.4, 0.5, 1.0, dz: -2.6);
      m.stair(1.2, 0.55, 0.9, dz: -2.1, at: 0.5);
      m.stair(1.0, 0.6, 0.8, dz: -1.6, at: 1.05);
      m.box(PieceKind.floor, 1.4, 1.2, 0.9, dx: 2.6, dz: -2.2, at: 0);
      m.roof(1.65, 1.45, 0.5, dx: 2.6, dz: -2.2, at: 0.9);
      m.tree(1.2, 2.3, dx: -2.9, dz: -2.4);
      m.palisade(4.6, 0.9, dz: -3.2);
      m.banner(0.9, dx: -1.6, dz: -1.75, at: 1.65);
      m.banner(0.9, dx: 1.6, dz: -1.75, at: 1.65);
    },
  ),
  Landmark(
    'barbacana',
    'Barbacana',
    26,
    2,
    'Dos torres delante de la puerta, para que quien llegue lo piense.',
    (m) {
      m.water(6.0, 2.6, dz: 2.4);
      m.plinth(5.0, 3.0, 0.5);
      for (final s in [-1.0, 1.0]) {
        for (var i = 0; i < 5; i++) {
          m.box(
            PieceKind.floor,
            1.5,
            1.5,
            0.8,
            dx: s * 1.85,
            dz: 0.0,
            at: 0.5 + i * 0.8,
          );
        }
        m.box(PieceKind.parapet, 1.8, 1.8, 0.45, dx: s * 1.85, at: 4.5);
        m.spire(1.6, 1.6, 0.9, dx: s * 1.85, at: 4.95);
        m.banner(0.9, dx: s * 1.85, at: 5.85);
      }
      m.box(PieceKind.arcade, 1.8, 1.6, 2.4, at: 0.5);
      m.box(PieceKind.floor, 2.0, 1.6, 1.4, at: 2.9);
      m.box(PieceKind.parapet, 2.3, 1.9, 0.45, at: 4.3);
      m.beam(2.4, 1.2, 0.28, dz: 1.6, at: 0.4);
      m.stair(1.6, 0.5, 1.2, dz: 2.9);
      m.palisade(5.4, 1.0, dz: -1.7);
      m.tree(1.2, 2.2, dx: -3.2, dz: -1.4);
      m.tree(1.1, 2.0, dx: 3.2, dz: -1.4);
    },
  ),
  Landmark(
    'aljibe',
    'Aljibe mayor',
    24,
    2,
    'Bóvedas llenas de agua de lluvia. Un asedio o una sequía dejan de dar miedo.',
    (m) {
      m.plinth(4.6, 4.6, 0.4);
      m.water(3.4, 3.4, dx: 0, dz: 0);
      for (final s in [-1.0, 1.0]) {
        m.box(PieceKind.plinth, 4.4, 0.7, 0.8, dz: s * 1.85, at: 0.4);
        m.box(PieceKind.plinth, 0.7, 4.4, 0.8, dx: s * 1.85, at: 0.4);
        m.arcade(4.2, 1.2, 0.6, dz: s * 1.85, at: 1.2, along: true);
        m.arcade(4.2, 1.2, 0.6, dx: s * 1.85, at: 1.2, along: false);
        m.beam(4.6, 0.8, 0.22, dz: s * 1.85, at: 2.4);
        m.beam(0.8, 4.6, 0.22, dx: s * 1.85, at: 2.4);
        m.roof(4.8, 1.1, 0.5, dz: s * 1.9, at: 2.62, along: true);
        m.roof(1.1, 4.8, 0.5, dx: s * 1.9, at: 2.62, along: false);
      }
      m.plinth(1.0, 1.0, 0.5, dz: 2.6);
      m.parapet(0.8, 0.8, 0.4);
      m.post(0.16, 1.0, dx: -0.3, dz: 2.6, at: 0.9);
      m.post(0.16, 1.0, dx: 0.3, dz: 2.6, at: 0.9);
      m.roof(1.1, 0.9, 0.3, dz: 2.6, at: 1.9);
      m.tree(1.2, 2.2, dx: -2.9, dz: 2.6);
    },
  ),
  Landmark(
    'observatorio',
    'Observatorio',
    35,
    2,
    'Una torre con una cúpula que se abre. Desde esta noche el pueblo no sólo '
        'mira el suelo que pisa: hay alguien arriba anotando lo que pasa en el '
        'cielo, y lo que anota queda escrito para todo el valle.',
    (m) {
      m.plinth(4.6, 4.6, 0.42);
      m.stair(1.7, 0.42, 1.2, dz: -2.9);
      m.stair(1.7, 0.30, 0.9, dz: -3.8, at: -0.30);
      // La columnata de la terraza: ocho postes y el arquitrabe encima. Una
      // cúpula sobre un tambor pelado es un silo.
      for (final (dx, dz) in const [
        (-2.1, -2.1), (0.0, -2.1), (2.1, -2.1), (2.1, 0.0), //
        (2.1, 2.1), (0.0, 2.1), (-2.1, 2.1), (-2.1, 0.0),
      ]) {
        m.post(0.24, 1.7, dx: dx, dz: dz, at: 0.42);
      }
      for (final dz in const [-2.1, 2.1]) {
        m.beam(4.6, 0.3, 0.24, dz: dz, at: 2.12);
      }
      for (final dx in const [-2.1, 2.1]) {
        m.beam(0.3, 4.6, 0.24, dx: dx, at: 2.12);
      }
      // El tambor, que se estrecha al subir: una cúpula pesa, y una torre que
      // sube recta debajo de una parece un bidón.
      m.shaft(3.3, 16, 0.42, taper: 0.055);
      m.parapet(3.0, 3.0, 0.34);
      m.dome(2.6, 2.6, 1.5);
      // Y la mira asomando por la abertura, que es lo que dice que esto es un
      // observatorio y no una cúpula más.
      m.post(0.22, 1.2, dx: 0.4);
      m.beam(1.5, 0.28, 0.28, dx: 0.4);
    },
  ),
];
