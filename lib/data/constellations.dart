/// Las constelaciones que se pueden ver desde el pueblo, y son de verdad.
///
/// Cada estrella lleva su ascensión recta y su declinación reales, en el
/// sistema J2000, que es el catálogo con el que trabaja cualquiera que apunte
/// un telescopio. No están «inspiradas en»: son las coordenadas, y por eso la
/// figura que sale en pantalla es la que se ve levantando la cabeza.
///
/// Lo que **no** hay aquí es una esfera celeste con tiempo sidéreo: esto es una
/// app de hábitos y no un planetario, y simular la rotación de la Tierra para
/// que Orión salga por el este a la hora que le toca sería un motor entero al
/// servicio de un detalle. Lo que se hace es más honesto y más barato: se toma
/// la forma real —los ángulos entre sus estrellas, que es lo que la hace
/// reconocible— y se cuelga entera de un sitio del cielo.
///
/// Cómo se conserva la forma: se calcula la dirección media del grupo y se
/// mide cada estrella contra ella en el plano tangente, en radianes al este y
/// al norte. Colgarla después en otro sitio del cielo es rehacer ese mismo
/// plano tangente allí. Como una constelación abarca entre diez y cuarenta
/// grados, la distorsión es la misma que tiene cualquier foto de ese trozo de
/// cielo — que es exactamente la que tiene la pantalla, porque la pantalla
/// también es una proyección gnomónica.
library;

import 'dart:math' as math;

import '../core/rng.dart';
import '../l10n/lang.dart';

/// Una estrella: dónde está y cuánto brilla.
class Star {
  const Star(this.ra, this.dec, this.mag);

  /// Ascensión recta, en horas. Declinación, en grados. J2000.
  final double ra, dec;

  /// Magnitud aparente. Al revés de lo que parece: cuanto más chica, más
  /// brilla — Sirio está en menos uno y media, y lo que se ve a ojo desnudo
  /// desde un pueblo sin luz llega a seis.
  final double mag;
}

/// Una figura: sus estrellas y qué se une con qué.
class Constellation {
  const Constellation(this.id, this.stars, this.lines);

  /// Nunca cambia: con él se elige la de cada noche y se guarda su forma.
  ///
  /// Tenían además nombre, nombre latino y una línea sobre cada una, de cuando
  /// se anotaban las que uno había visto. Dejaron de anotarse y con eso dejó
  /// de leerse todo lo demás; la figura en el cielo no necesita más que esto.
  final String id;

  /// Cómo se llama, para el rótulo chico que sale encima al tocarla.
  String get name {
    final (es, en) = constellationNames[id] ?? (id, id);
    return tr(es, en);
  }

  final List<Star> stars;

  /// Pares de índices en [stars]: los trazos de la figura.
  final List<int> lines;

  /// Dónde cae cada estrella respecto del centro del grupo, en radianes: al
  /// este la primera, al norte la segunda.
  ///
  /// Se calcula una vez y se guarda fuera de la clase, porque el catálogo es
  /// `const` —una constelación no cambia nunca y no tiene por qué ocupar un
  /// montón— y una clase con un campo que se rellena después no puede serlo.
  List<(double, double)> get shape => _shapes[id] ??= _measure();

  /// Cuánto se encoge la figura antes de colgarla del cielo.
  ///
  /// A tamaño real una constelación ocupa lo que ocupa de verdad —Escorpio son
  /// veinticinco grados de cielo— y en una pantalla de teléfono eso es la
  /// pantalla entera: la Osa Mayor salía de canto a canto por encima del
  /// pueblo, y entonces no es un detalle del cielo, es el fondo.
  ///
  /// A la mitad sigue siendo reconocible —los ángulos entre estrellas no
  /// cambian, sólo la escala— y vuelve a ser lo que tiene que ser: algo que
  /// hay ahí arriba si mirás, y que no se te impone si no mirás.
  ///
  /// Se aplica en [_measure], que es de donde salen [shape] y [spread] los
  /// dos, así que la altura a la que se cuelga se ajusta sola: una figura más
  /// chica cabe más abajo y no hay que tocar nada más.
  static const double skyScale = 0.5;

  /// Cuánto ocupa de lado a lado, en radianes. Para colgarla a una altura
  /// donde entre entera.
  double get spread => _spreads[id] ??= _measureSpread();

  static List<double> _unit(Star s) {
    final ra = s.ra * math.pi / 12.0;
    final dec = s.dec * math.pi / 180.0;
    final cd = math.cos(dec);
    return [cd * math.cos(ra), cd * math.sin(ra), math.sin(dec)];
  }

  List<(double, double)> _measure() {
    // La dirección media del grupo, normalizada.
    var mx = 0.0, my = 0.0, mz = 0.0;
    for (final s in stars) {
      final v = _unit(s);
      mx += v[0];
      my += v[1];
      mz += v[2];
    }
    final ln = math.sqrt(mx * mx + my * my + mz * mz);
    mx /= ln;
    my /= ln;
    mz /= ln;

    // Y una base local en ella: el este es perpendicular al eje del mundo, el
    // norte cierra el triedro. Es la misma base que usa cualquier carta
    // celeste, y por eso la figura sale con el norte arriba.
    var ex = -my, ey = mx, ez = 0.0;
    var el = math.sqrt(ex * ex + ey * ey);
    if (el < 1e-9) {
      // Justo en un polo: cualquier este vale, pero hay que elegir uno.
      ex = 1.0;
      ey = 0.0;
      el = 1.0;
    }
    ex /= el;
    ey /= el;
    final nx = my * ez - mz * ey;
    final ny = mz * ex - mx * ez;
    final nz = mx * ey - my * ex;

    return [
      for (final s in stars)
        () {
          final v = _unit(s);
          // Plano tangente: se divide por la componente hacia el centro, que
          // es lo que hace que esto sea gnomónico y no una deformación.
          final along = v[0] * mx + v[1] * my + v[2] * mz;
          final k = 1.0 / (along.abs() < 1e-6 ? 1e-6 : along);
          return (
            (v[0] * ex + v[1] * ey + v[2] * ez) * k * skyScale,
            (v[0] * nx + v[1] * ny + v[2] * nz) * k * skyScale,
          );
        }(),
    ];
  }

  double _measureSpread() {
    var x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
    for (final (x, y) in shape) {
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
    return math.max(x1 - x0, y1 - y0);
  }
}

/// Veinticinco, elegidas por ser las que cualquiera reconoce o ha oído
/// nombrar: las grandes figuras del norte y del sur y las del zodíaco que
/// tienen forma.
/// Los nombres, en castellano y en inglés.
const Map<String, (String, String)> constellationNames = {
  'orion': ('Orión', 'Orion'),
  'osamayor': ('Osa Mayor', 'Great Bear'),
  'casiopea': ('Casiopea', 'Cassiopeia'),
  'cruz': ('Cruz del Sur', 'Southern Cross'),
  'cisne': ('Cisne', 'Swan'),
  'escorpio': ('Escorpio', 'Scorpius'),
  'lira': ('Lira', 'Lyra'),
  'canmayor': ('Can Mayor', 'Great Dog'),
  'osamenor': ('Osa Menor', 'Little Bear'),
  'leo': ('Leo', 'Leo'),
  'geminis': ('Géminis', 'Gemini'),
  'tauro': ('Tauro', 'Taurus'),
  'pegaso': ('Pegaso', 'Pegasus'),
  'andromeda': ('Andrómeda', 'Andromeda'),
  'boyero': ('Boyero', 'Herdsman'),
  'aguila': ('Águila', 'Eagle'),
  'sagitario': ('Sagitario', 'Sagittarius'),
  'perseo': ('Perseo', 'Perseus'),
  'cochero': ('Cochero', 'Charioteer'),
  'virgo': ('Virgo', 'Virgo'),
  'corona': ('Corona Boreal', 'Northern Crown'),
  'dragon': ('Dragón', 'Dragon'),
  'hercules': ('Hércules', 'Hercules'),
  'aries': ('Aries', 'Aries'),
  'centauro': ('Centauro', 'Centaur'),
};

const List<Constellation> constellations = [
  Constellation(
    'orion',
    [
      Star(5.9195, 7.407, 0.5), // Betelgeuse
      Star(5.4188, 6.350, 1.6), // Bellatrix
      Star(5.5334, -0.299, 2.2), // Mintaka
      Star(5.6036, -1.202, 1.7), // Alnilam
      Star(5.6793, -1.943, 1.8), // Alnitak
      Star(5.7959, -9.670, 2.1), // Saiph
      Star(5.2423, -8.202, 0.1), // Rigel
    ],
    [0, 1, 1, 2, 2, 3, 3, 4, 4, 0, 4, 5, 5, 6, 6, 2],
  ),
  Constellation(
    'osamayor',
    [
      Star(11.0622, 61.751, 1.8), // Dubhe
      Star(11.0307, 56.383, 2.4), // Merak
      Star(11.8972, 53.695, 2.4), // Phecda
      Star(12.2571, 57.033, 3.3), // Megrez
      Star(12.9005, 55.960, 1.8), // Alioth
      Star(13.3988, 54.925, 2.2), // Mizar
      Star(13.7923, 49.313, 1.9), // Alkaid
    ],
    [0, 1, 1, 2, 2, 3, 3, 0, 3, 4, 4, 5, 5, 6],
  ),
  Constellation(
    'casiopea',
    [
      Star(0.1529, 59.150, 2.3), // Caph
      Star(0.6751, 56.537, 2.2), // Schedar
      Star(0.9451, 60.717, 2.5), // Gamma
      Star(1.4303, 60.235, 2.7), // Ruchbah
      Star(1.9067, 63.670, 3.4), // Segin
    ],
    [0, 1, 1, 2, 2, 3, 3, 4],
  ),
  Constellation(
    'cruz',
    [
      Star(12.4433, -63.099, 0.8), // Acrux
      Star(12.5194, -57.113, 1.6), // Gacrux
      Star(12.7953, -59.689, 1.3), // Mimosa
      Star(12.2524, -58.749, 2.8), // Delta
    ],
    [0, 1, 2, 3],
  ),
  Constellation(
    'cisne',
    [
      Star(20.6905, 45.280, 1.3), // Deneb
      Star(20.3705, 40.257, 2.2), // Sadr
      Star(19.5120, 27.960, 3.1), // Albireo
      Star(20.7702, 33.970, 2.5), // Gienah
      Star(19.7498, 45.131, 2.9), // Delta
    ],
    [0, 1, 1, 2, 1, 3, 1, 4],
  ),
  Constellation(
    'escorpio',
    [
      Star(16.0906, -19.805, 2.6), // Graffias
      Star(16.0055, -22.622, 2.3), // Dschubba
      Star(15.9888, -26.114, 2.9), // Pi
      Star(16.4901, -26.432, 1.1), // Antares
      Star(16.5983, -28.216, 2.8), // Tau
      Star(16.8361, -34.293, 2.3), // Epsilon
      Star(16.8721, -38.048, 3.0), // Mu
      Star(16.9119, -42.361, 3.6), // Zeta
      Star(17.2028, -43.239, 3.3), // Eta
      Star(17.6220, -42.998, 1.9), // Theta
      Star(17.7930, -40.127, 3.0), // Iota
      Star(17.7083, -39.030, 2.4), // Kappa
      Star(17.5601, -37.104, 1.6), // Shaula
      Star(17.5121, -37.296, 2.7), // Lesath
    ],
    [
      0, 1, 1, 2, 1, 3, 3, 4, 4, 5, 5, 6, 6, 7, //
      7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13,
    ],
  ),
  Constellation(
    'lira',
    [
      Star(18.6156, 38.784, 0.0), // Vega
      Star(18.7400, 39.670, 3.9), // Epsilon
      Star(18.7461, 37.605, 4.3), // Zeta
      Star(18.8347, 33.363, 3.5), // Sheliak
      Star(18.9824, 32.690, 3.2), // Sulafat
      Star(18.9089, 36.899, 4.2), // Delta
    ],
    [0, 1, 0, 2, 2, 3, 3, 4, 4, 5, 5, 2],
  ),
  Constellation(
    'canmayor',
    [
      Star(6.7525, -16.716, -1.5), // Sirio
      Star(6.3783, -17.956, 2.0), // Mirzam
      Star(7.0637, -15.633, 4.1), // Muliphein
      Star(7.1399, -26.393, 1.8), // Wezen
      Star(6.9770, -28.972, 1.5), // Adhara
      Star(7.4015, -29.303, 2.4), // Aludra
      Star(7.0288, -27.935, 3.5), // Sigma
    ],
    [0, 1, 0, 2, 2, 3, 3, 4, 4, 6, 6, 0, 3, 5],
  ),
  Constellation(
    'osamenor',
    [
      Star(2.5303, 89.264, 2.0), // Polar
      Star(17.5369, 86.586, 4.4), // Yildun
      Star(16.7662, 82.037, 4.2), // Epsilon
      Star(15.7343, 77.795, 4.3), // Zeta
      Star(16.2918, 75.755, 5.0), // Eta
      Star(15.3455, 71.834, 3.0), // Pherkad
      Star(14.8451, 74.156, 2.1), // Kochab
    ],
    [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 3],
  ),
  Constellation(
    'leo',
    [
      Star(10.1395, 11.967, 1.4), // Régulo
      Star(10.1222, 16.763, 3.5), // Eta
      Star(10.3329, 19.842, 2.0), // Algieba
      Star(10.2782, 23.417, 3.4), // Adhafera
      Star(9.8794, 26.007, 3.9), // Rasalas
      Star(9.7642, 23.774, 3.0), // Epsilon
      Star(11.2351, 20.524, 2.6), // Zosma
      Star(11.2373, 15.430, 3.3), // Chertan
      Star(11.8177, 14.572, 2.1), // Denébola
    ],
    [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 2, 6, 6, 8, 8, 7, 7, 0, 6, 7],
  ),
  Constellation(
    'geminis',
    [
      Star(7.5767, 31.888, 1.6), // Cástor
      Star(7.7553, 28.026, 1.1), // Pólux
      Star(6.6285, 16.399, 1.9), // Alhena
      Star(6.7322, 25.131, 3.0), // Mebsuta
      Star(6.3827, 22.514, 2.9), // Tejat
      Star(7.3354, 21.982, 3.5), // Wasat
      Star(7.0685, 20.570, 3.8), // Mekbuda
      Star(6.7548, 12.896, 3.4), // Alzirr
    ],
    [0, 1, 0, 3, 3, 4, 1, 5, 5, 6, 6, 2, 5, 7],
  ),
  Constellation(
    'tauro',
    [
      Star(4.5987, 16.509, 0.9), // Aldebarán
      Star(5.4382, 28.608, 1.7), // Elnath
      Star(5.6274, 21.143, 3.0), // Zeta
      Star(4.4777, 15.871, 3.4), // Theta
      Star(4.3299, 15.628, 3.7), // Gamma
      Star(4.3823, 17.543, 3.8), // Delta
      Star(4.4769, 19.180, 3.5), // Ain
      Star(3.7914, 24.105, 2.9), // Alcíone, en las Pléyades
    ],
    [0, 2, 0, 3, 3, 4, 4, 5, 5, 6, 6, 1, 4, 7],
  ),
  Constellation(
    'pegaso',
    [
      Star(23.0794, 15.205, 2.5), // Markab
      Star(23.0629, 28.083, 2.4), // Scheat
      Star(0.2206, 15.184, 2.8), // Algenib
      Star(0.1398, 29.091, 2.1), // Alpheratz
      Star(21.7364, 9.875, 2.4), // Enif
      Star(22.6910, 10.831, 3.4), // Homam
      Star(22.1700, 6.198, 3.5), // Biham
    ],
    [0, 1, 1, 3, 3, 2, 2, 0, 0, 5, 5, 6, 6, 4],
  ),
  Constellation(
    'andromeda',
    [
      Star(0.1398, 29.091, 2.1), // Alpheratz
      Star(1.1622, 35.621, 2.1), // Mirach
      Star(2.0650, 42.330, 2.1), // Almach
      Star(0.6555, 30.861, 3.3), // Delta
      Star(0.9458, 38.499, 3.9), // Mu
      Star(0.8302, 41.079, 4.5), // Nu
    ],
    [0, 3, 3, 1, 1, 2, 1, 4, 4, 5],
  ),
  Constellation(
    'boyero',
    [
      Star(14.2610, 19.182, -0.05), // Arturo
      Star(14.7498, 27.074, 2.4), // Izar
      Star(15.2584, 33.315, 3.5), // Delta
      Star(15.0324, 40.391, 3.5), // Nekkar
      Star(14.5347, 38.308, 3.0), // Seginus
      Star(14.5303, 30.371, 3.6), // Rho
      Star(13.9114, 18.398, 2.7), // Muphrid
    ],
    [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 0, 0, 6],
  ),
  Constellation(
    'aguila',
    [
      Star(19.8464, 8.868, 0.8), // Altair
      Star(19.7710, 10.613, 2.7), // Tarazed
      Star(19.9219, 6.407, 3.7), // Alshain
      Star(19.4249, 3.115, 3.4), // Delta
      Star(19.0902, 13.863, 3.0), // Zeta
      Star(20.1884, -0.821, 3.2), // Theta
      Star(19.1042, -4.883, 3.4), // Lambda
    ],
    [4, 1, 1, 0, 0, 2, 2, 5, 0, 3, 3, 6],
  ),
  Constellation(
    'sagitario',
    [
      Star(18.4029, -34.385, 1.8), // Kaus Australis
      Star(18.3499, -29.828, 2.7), // Kaus Media
      Star(18.4662, -25.422, 2.8), // Kaus Borealis
      Star(18.9211, -26.297, 2.1), // Nunki
      Star(18.7609, -26.991, 3.2), // Phi
      Star(19.1157, -27.671, 3.3), // Tau
      Star(19.0435, -29.880, 2.6), // Ascella
      Star(18.0968, -30.424, 3.0), // Alnasl
    ],
    [7, 0, 0, 1, 1, 7, 1, 2, 2, 4, 4, 1, 4, 6, 6, 0, 4, 3, 3, 5, 5, 6],
  ),
  Constellation(
    'perseo',
    [
      Star(3.4054, 49.861, 1.8), // Mirfak
      Star(3.1361, 40.956, 2.1), // Algol
      Star(3.7154, 47.788, 3.0), // Delta
      Star(3.9642, 40.010, 2.9), // Epsilon
      Star(3.0799, 53.506, 2.9), // Gamma
      Star(3.9022, 31.884, 2.9), // Zeta
      Star(2.8450, 55.896, 3.8), // Eta
    ],
    [5, 3, 3, 2, 2, 0, 0, 4, 4, 6, 0, 1],
  ),
  Constellation(
    'cochero',
    [
      Star(5.2782, 45.998, 0.1), // Capella
      Star(5.9921, 44.948, 1.9), // Menkalinan
      Star(5.9954, 37.213, 2.6), // Theta
      Star(5.4382, 28.608, 1.7), // Elnath, que comparte con Tauro
      Star(4.9498, 33.166, 2.7), // Hassaleh
      Star(5.0328, 43.823, 3.0), // Epsilon
    ],
    [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 0],
  ),
  Constellation(
    'virgo',
    [
      Star(13.4199, -11.161, 1.0), // Espiga
      Star(12.6943, -1.450, 2.7), // Porrima
      Star(13.0363, 10.959, 2.8), // Vindemiatrix
      Star(12.9267, 3.397, 3.4), // Delta
      Star(13.5783, -0.596, 3.4), // Zeta
      Star(11.8448, 1.765, 3.6), // Zavijava
      Star(12.3318, -0.667, 3.9), // Zaniah
    ],
    [5, 6, 6, 1, 1, 0, 1, 3, 3, 2, 0, 4, 4, 3],
  ),
  Constellation(
    'corona',
    [
      Star(15.5488, 31.359, 4.1), // Theta
      Star(15.4638, 29.106, 3.7), // Nusakan
      Star(15.5781, 26.715, 2.2), // Alphecca
      Star(15.7124, 26.296, 3.8), // Gamma
      Star(15.8263, 26.068, 4.6), // Delta
      Star(15.9597, 26.878, 4.2), // Epsilon
      Star(16.0238, 29.851, 5.0), // Iota
    ],
    [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6],
  ),
  Constellation(
    'dragon',
    [
      Star(17.9434, 51.489, 2.2), // Eltanin
      Star(17.5072, 52.301, 2.8), // Rastaban
      Star(17.5363, 55.184, 4.9), // Nu
      Star(17.8921, 56.873, 3.8), // Grumium
      Star(19.2093, 67.661, 3.1), // Altais
      Star(19.8028, 70.268, 3.8), // Epsilon
      Star(18.3509, 72.733, 3.6), // Chi
      Star(17.1465, 65.715, 3.2), // Zeta
      Star(16.3999, 61.514, 2.7), // Eta
      Star(16.0315, 58.565, 4.0), // Theta
      Star(15.4155, 58.966, 3.3), // Edasich
      Star(14.0731, 64.376, 3.7), // Thuban
    ],
    [0, 1, 1, 2, 2, 3, 3, 0, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11],
  ),
  Constellation(
    'hercules',
    [
      Star(17.0048, 30.926, 3.9), // Epsilon
      Star(16.6881, 31.603, 2.8), // Zeta
      Star(16.7149, 38.922, 3.5), // Eta
      Star(17.2508, 36.809, 3.2), // Pi
      Star(16.5037, 21.490, 2.8), // Kornephoros
      Star(17.2441, 14.390, 3.1), // Rasalgethi
      Star(17.2505, 24.839, 3.1), // Delta
      Star(17.7746, 27.720, 3.4), // Mu
      Star(17.9375, 37.251, 3.9), // Theta
      Star(17.6575, 46.006, 3.8), // Iota
    ],
    [0, 1, 1, 2, 2, 3, 3, 0, 1, 4, 0, 6, 6, 5, 6, 7, 3, 8, 8, 9],
  ),
  Constellation(
    'aries',
    [
      Star(2.1196, 23.463, 2.0), // Hamal
      Star(1.9107, 20.808, 2.6), // Sheratan
      Star(1.8922, 19.294, 3.9), // Mesarthim
      Star(2.8330, 27.260, 3.6), // 41 Arietis
    ],
    [3, 0, 0, 1, 1, 2],
  ),
  Constellation(
    'centauro',
    [
      Star(14.6600, -60.835, -0.1), // Alfa Centauri
      Star(14.0637, -60.373, 0.6), // Hadar
      Star(14.1114, -36.370, 2.1), // Menkent
      Star(13.6648, -53.466, 2.3), // Epsilon
      Star(13.9256, -47.288, 2.6), // Zeta
      Star(14.5918, -42.158, 2.3), // Eta
      Star(12.6918, -48.960, 2.2), // Gamma
      Star(12.1393, -50.722, 2.6), // Delta
      Star(13.3433, -36.712, 2.8), // Iota
    ],
    [0, 1, 1, 3, 3, 6, 6, 7, 3, 4, 4, 5, 5, 0, 4, 2, 2, 8],
  ),
];

/// Las formas ya medidas, por identificador. Ver arriba por qué no viven
/// dentro de su constelación.
final Map<String, List<(double, double)>> _shapes = {};
final Map<String, double> _spreads = {};

/// Cuelga la figura de un punto del cielo y dice dónde queda cada estrella.
///
/// Devuelve, por estrella y en el mismo orden, su azimut y su elevación.
/// Rehacer el plano tangente en el sitio nuevo es lo que conserva la forma:
/// los ángulos entre estrellas salen los mismos que arriba, y por eso la
/// figura sigue siendo reconocible por más que se la cuelgue del oeste en vez
/// del este.
List<(double, double)> hang(Constellation c, double az, double el) {
  final ce = math.cos(el), se = math.sin(el);
  final ca = math.cos(az), sa = math.sin(az);
  // El centro, y en él un este y un norte. Igual que arriba, pero en el marco
  // del mundo: la ye es la vertical.
  final mx = sa * ce, my = se, mz = ca * ce;
  final ex = ca, ez = -sa;
  final nx = my * ez, ny = mz * ex - mx * ez, nz = -my * ex;
  return [
    for (final (dx, dy) in c.shape)
      () {
        final x = mx + dx * ex + dy * nx;
        final y = my + dy * ny;
        final z = mz + dx * ez + dy * nz;
        final ln = math.sqrt(x * x + y * y + z * z);
        return (
          math.atan2(x / ln, z / ln),
          math.asin((y / ln).clamp(-1.0, 1.0)),
        );
      }(),
  ];
}

Constellation? constellationOf(String? id) {
  for (final c in constellations) {
    if (c.id == id) return c;
  }
  return null;
}

/// Qué noche es ésta, contada desde un día cualquiera y fijo.
///
/// La noche va de mediodía a mediodía y no de medianoche a medianoche: quien
/// mira el cielo a la una de la mañana está en la misma noche que a las once
/// de la anterior, y cambiarle la constelación en la mano por haber pasado las
/// doce sería una pequeña traición.
int nightOf(DateTime when) {
  final noon = when.subtract(const Duration(hours: 12));
  return DateTime(
        noon.year,
        noon.month,
        noon.day,
      ).difference(DateTime(2020)).inDays %
      1000000;
}

/// Cuál se ve esta noche, si es que se ve alguna.
///
/// **Puede no haber ninguna, y eso es la mitad del asunto.** Antes salía una
/// cada noche sin falta, se tocaba, se anotaba en un cuaderno y quedaba
/// registrada: ocho de ocho, con su lista y su cuenta. Eso es un sistema, y un
/// sistema pide que lo completes. Lo que quiere ser esto es el cielo: algunas
/// noches levantás la cabeza y está Orión ahí arriba, y otras no hay nada que
/// mirar. Lo que hace que valga la pena mirar es justamente que no siempre.
///
/// Tres de cada cinco noches, y siempre la misma para una misma noche —
/// quien salga a las nueve y vuelva a la una encuentra lo mismo—.
///
/// Las noches van de a cinco, y en cada tanda tres tienen figura: cuáles,
/// a suertes. Así no hay rachas largas de cielo vacío, y las que tienen
/// figura se cuentan: la que toca es la siguiente de la lista, con un paso de
/// siete —siete y veinticinco no comparten divisor— para que no salgan en el
/// orden en que están escritas. Con veinticinco, en un mes y medio salen
/// todas. A suertes puras, alguna se quedaba meses sin salir.
Constellation? tonight(int night) {
  final tanda = night ~/ 5, dentro = night % 5;
  // Las dos noches vacías de la tanda.
  final a = (hash01(tanda, 0x5C1E) * 5).floor() % 5;
  final b = (a + 1 + (hash01(tanda, 0x5C1F) * 4).floor() % 4) % 5;
  if (dentro == a || dentro == b) return null;
  var antes = 0;
  for (var k = 0; k < dentro; k++) {
    if (k != a && k != b) antes++;
  }
  final cuenta = tanda * 3 + antes;
  return constellations[(cuenta * 7) % constellations.length];
}
