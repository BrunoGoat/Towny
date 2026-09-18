import 'dart:math' as math;
import 'dart:ui';

import '../core/math3.dart';
import '../core/rng.dart';
import 'palette.dart';
import 'season.dart';
import 'solid.dart';

/// De qué color va cada cosa que no es una pared.
///
/// El prado, la hoja de un árbol, la nieve de un tejado y el lavado de lo que
/// está lejos. Todo son funciones puras de la paleta, la estación y la
/// distancia — entra un color y una hora, sale un color — y por eso estaban
/// desperdigadas como métodos estáticos dentro de las tres mil cuatrocientas
/// líneas del pintor, donde nadie iba a encontrarlas.
///
/// Que estén juntas no es orden por el orden. Son las cuatro cuentas que
/// deciden de qué color se ve un valle a cada hora de cada mes, se leen unas
/// contra otras —la nieve tiene que casar con el prado que hay debajo, y la
/// hoja con la nieve— y separadas por mil líneas de rasterizador esa lectura no
/// la hacía nadie. También son las únicas del pintor que se pueden probar sin
/// pintar: un test les pasa una paleta y mira el color que sale, que es lo que
/// hacen `ground_test`, `season_test` y `skyline_test`.

/// Three ranges of hills standing all the way round the horizon.
///
/// They are drawn as a ring centred on wherever the camera is looking, but
/// their shape is sampled from world position, so walking along the wall
/// reveals new country instead of dragging the same skyline along.
/// The three mountain ranges on the skyline.
///
/// Three things had to be true at once, and the old version got none of them
/// right once the camera left its usual place:
///
///  * The ring has to be centred on the *camera*, not on the point it is
///    looking at. Zoomed all the way out the eye sits a hundred units from
///    that point, which put it almost on top of the nearest range — half the
///    country ended up behind the viewer, and the half in front reared up
///    across the whole screen.
///  * The shape has to be sampled somewhere that does not move when you
///    merely orbit, or the skyline swims as you turn. So the geometry follows
///    the eye and the height follows the stretch of wall being looked at:
///    walking the wall still reveals new country, turning on the spot does
///    not.
///  * Every strip has to be a closed shape. Whenever a point fell behind the
///    near plane the old loop handed Skia an open path, which closes itself
///    with a straight line back to the start — that is where the huge wedges
///    across the view came from. Now only the arc actually in front of the
///    camera is walked at all, and each strip is closed by construction.
/// El verde del prado a esta hora. Uno solo: ver `_drawGround`.
///
/// The town stands in a meadow, and a meadow is a meadow at midnight too.
///
/// The green used to be applied only in daylight, so after dark the field
/// fell back to the bare ground colour — a neutral blue-black, and the same
/// blue-black the hills behind it are made of. Field and skyline became one
/// dark shape with a line through it. At night it takes a deep blue-green
/// instead: dark enough to be night, green enough to still be grass.
///
/// Blended by how much of a day it is rather than by whether the sun is up,
/// because the second of those changes colour in a single frame.
Color meadowTone(Palette pal) {
  final day = pal.daylight;
  // El verde de siempre, sin año: el año entra una sola vez, más abajo.
  // Entrando aquí también, se aplicaba dos veces —una con el peso de la
  // mezcla y otra entera— y el otoño salía rojo ladrillo en vez de ocre.
  final green = Color.lerp(
    const Color(0xFF204D53),
    grassOfYear(Season.none),
    day,
  )!;
  var prado = Color.lerp(pal.ground, green, 0.32 + 0.115 * day)!;
  // El año otra vez, ahora sobre la mezcla ya hecha.
  //
  // Hace falta las dos veces. El verde entra en la mezcla pesando poco menos
  // de la mitad —el resto es el tono del suelo de esa hora, que no sabe nada
  // del año—, así que teñir sólo el verde dejaba septiembre y junio casi del
  // mismo color.
  //
  // Pero **multiplicando y no mezclando**. Mezclar con el verde de la
  // estación es mezclar con un color de mediodía: a las dos de la mañana el
  // prado se aclaraba un tercio hacia un verde de mediodía y la noche dejaba
  // de ser noche. Multiplicar por lo que la estación le hizo al verde mueve
  // el tono y deja la luz en paz — y con el año apagado la razón es uno y
  // esto no hace absolutamente nada, que es la otra mitad de por qué así.
  prado = tintedLike(prado, grassOfYear(Season.none), grassOfYear(pal.season));
  // Y encima, la nieve. Va después de todo lo demás porque tapa: un prado
  // nevado no es un prado de otro color, es un prado que no se ve.
  //
  // Sin el factor del día: la nieve de noche se ve, y bastante —es lo único
  // que hay claro en un paisaje oscuro—. El tono ya sigue a la luz de la
  // hora, así que de noche sale azulada sola.
  //
  // Y no la misma nieve que los tejados, sino algo más apagada: un prado
  // nevado se mira de canto y un tejado de frente, así que el prado devuelve
  // menos luz. Con la misma de los dos, el suelo salía exactamente del gris
  // de la bruma y el horizonte desaparecía — el valle entero era una sola
  // mancha pálida sin línea que separase la tierra del cielo.
  final manto = Color.lerp(snowTone(pal), pal.ground, 0.22)!;
  return Color.lerp(prado, manto, pal.season.snow * 0.66)!;
}

/// Mueve [c] lo mismo que [from] se movió hasta [to].
///
/// Por razón y no por mezcla, así que lo oscuro sigue oscuro: lo que cambia
/// es de qué color es, no cuánta luz le está dando. Si [from] y [to] son el
/// mismo color, esto devuelve [c] intacto.
Color tintedLike(Color c, Color from, Color to) {
  double r(double a, double b) => b <= 0.004 ? 1.0 : clampD(a / b, 0.35, 2.2);
  return Color.from(
    alpha: c.a,
    red: clampD(c.r * r(to.r, from.r), 0, 1),
    green: clampD(c.g * r(to.g, from.g), 0, 1),
    blue: clampD(c.b * r(to.b, from.b), 0, 1),
  );
}

/// De qué color está el pasto en esta época del año.
///
/// Cuatro tonos y una mezcla, y el orden es el del año: el verde ácido de
/// la hierba nueva en primavera, el verde cansado y algo seco del final del
/// verano, el pajizo del otoño, y el pardo apagado del invierno bajo el
/// cual asoma la nieve.
///
/// Se parte del verde de siempre —el que tenía la app antes de que hubiera
/// estaciones— y se tira de él hacia cada lado, en vez de escribir cuatro
/// colores nuevos. Así el prado de un día de verano es exactamente el de
/// siempre y no hay ninguna captura vieja que deje de valer.
Color grassOfYear(Season s) {
  const verano = Color(0xFF749445);
  var c = verano;
  //
  // Los tres tonos están cerca del verde de partida a propósito. El prado no
  // se tiñe mezclando sino por razón entre este color y el de verano, y una
  // razón grande en un solo canal es un valle marciano: con un ocre subido
  // para el otoño, el rojo salía multiplicado por uno y medio y el pueblo
  // quedaba plantado en Marte. Lo que se busca es el giro, no el color.
  // La primavera es **más verde**, no sólo más clara. El primer tono que le
  // puse subía el rojo y el verde por igual, así que el prado de marzo salía
  // igual que el de junio con más luz —y a ojo, el mismo prado.
  c = Color.lerp(c, const Color(0xFF6FB83C), s.spring * 0.85)!;
  c = Color.lerp(c, const Color(0xFF95873F), s.autumn * 0.80)!;
  // Por `bare` y no por `winter`, que es la diferencia entre un prado de
  // marzo verde y uno pardo. `winter` vale medio en **los dos** equinoccios
  // —es el eje coseno del año—, así que tirando de él, a la primavera le
  // caía encima medio invierno y se comía justo el verde que la hace
  // primavera. `bare` es cero hasta bien entrado el invierno, que es cuando
  // el pasto se seca de verdad, y además es el mismo número con el que se
  // cae la hoja: la tierra y los árboles se apagan juntos, como pasa.
  c = Color.lerp(c, const Color(0xFF7B7358), s.bare * 0.75)!;
  return c;
}

/// La nieve no es blanca: es del color de la luz que le está dando.
///
/// Blanco puro de mediodía es una mancha de papel pegada al paisaje, y de
/// noche es un agujero. Tirando del blanco hacia el sol y hacia el cielo de
/// la hora, la nieve del amanecer sale rosada y la de la noche azul, que es
/// lo que hace la nieve de verdad y lo que la mete dentro de la escena.
Color snowTone(Palette pal) {
  final luz = Color.lerp(pal.sun, pal.skyLight, 0.45)!;
  // De noche se hunde más en la luz de la hora que de día. Una nieve casi
  // blanca en un paisaje nocturno es un agujero recortado: lo único que se
  // ve, y encima plano.
  return Color.lerp(
    const Color(0xFFEDF1F5),
    luz,
    0.30 + 0.40 * (1 - pal.daylight),
  )!;
}

// ------------------------------------------------------------------ town

/// Haze by real distance rather than by distance along one axis.
///
/// The wall runs east to west, so fading it by how far it is along x is
/// close enough. A town spreads in both directions, and fading it by x alone
/// leaves the north end of a street crisp and the west end of it lost.
Color hazeAt(Color c, Projector p, double x, double z, Palette pal) {
  final dx = x - p.eye.x, dz = z - p.eye.z;
  final dist = math.sqrt(dx * dx + dz * dz);
  // The town is meant to be looked at, not squinted through: it keeps most
  // of its colour all the way to the far side of the valley.
  // Capped: from across the valley a town must still be a town and not a
  // smudge the colour of the grass. Distance says "further away", never
  // "gone".
  final t = 1 - math.exp(-dist * 0.0040);
  if (t < 0.004) return c;
  return Color.lerp(c, pal.haze, math.min(t * 0.5, 0.30))!;
}

/// De qué color está una hoja en esta época del año.
///
/// Cada árbol se dora un poco antes o un poco después que su vecino —el
/// mismo `hash` que ya le daba su verde le da ahora su calendario—, porque
/// un bosque entero que cambia de color el mismo día es un bosque pintado.
///
/// Primero el oro y después la rama, en ese orden y no a la vez: un roble
/// pelado en mitad de su mejor semana es un roble que se saltó la parte
/// bonita. Y no hace falta geometría nueva para el invierno — a esta
/// distancia, un árbol sin hoja es un árbol del color del tronco.
Color leafOfYear(Color base, int seed, Season year) {
  final suyo = 0.78 + hash01(seed, 23) * 0.44;
  final oro = clampD(year.autumn * suyo, 0, 1);
  final pelado = clampD(year.bare * suyo, 0, 1);
  var c = Color.lerp(
    base,
    Color.lerp(
      const Color(0xFFC08A35),
      const Color(0xFF9C4A2C),
      hash01(seed, 29),
    )!,
    oro * 0.82,
  )!;
  return Color.lerp(c, const Color(0xFF5A4635), pelado * 0.88)!;
}

/// La nieve que se le queda encima a una cara.
///
/// No hay geometría nueva y no hace falta ninguna: la nieve se posa en lo
/// que mira hacia arriba y no en lo que mira de lado, así que basta con la
/// normal de la cara. Un faldón de tejado la coge casi entera, un adarve y
/// un basamento entera del todo, un muro nada, y lo que mira al suelo
/// tampoco. Eso es exactamente lo que hace la nieve.
///
/// Va sobre el albedo y no sobre el color ya iluminado, que es la diferencia
/// entre nieve y pintura blanca: así el faldón que da al sol brilla y el de
/// la otra vertiente queda en penumbra azulada, con la misma luz que todo
/// lo demás.
///
/// Y no cuaja del todo: queda algo de tejado asomando, que es lo que hace
/// que se lea «tejado con nieve» y no «bloque blanco».
Color snowed(Color albedo, V3 n, Palette pal, [Surface? on]) {
  if (on == Surface.cloth) return albedo;
  final snow = pal.season.snow;
  if (snow < 0.004) return albedo;
  final up = n.y;
  if (up <= 0.02) return albedo;
  // Lo tumbado que está, con el borde suavizado para que un tejado muy
  // empinado se quede a medias en vez de aparecer nevado de golpe.
  final lies = smoothstep(0.10, 0.72, up);
  return Color.lerp(albedo, snowTone(pal), snow * lies * 0.88)!;
}

bool darkSky(Palette pal) {
  final c = pal.skyHorizon;
  return (c.r * 0.3 + c.g * 0.55 + c.b * 0.15) < 0.45;
}

/// What one range is painted with: the colour of its body, and the colour
/// its foot fades to where it meets the horizon.
///
/// Near ranges are the pale ones and far ranges are dark. That is what makes
/// three of them read as three: the eye takes the darkest band as the one
/// furthest back, and stacks the rest in front of it. It used to be the
/// other way round — the far range got the most haze and came out lightest,
/// which put the back of the world in front of everything else.
(Color body, Color foot) rangeTone(Palette pal, int li, int of) {
  // One for the range at your feet, zero for the one at the edge of the
  // world. Every choice below hangs off this and nothing else, so «which way
  // round are they?» is one line rather than three index sums.
  final near01 = of <= 1 ? 1.0 : (of - 1 - li) / (of - 1);
  // What a hill is made of at this hour, before distance touches it.
  final hill = Color.lerp(pal.groundFar, pal.haze, 0.38)!;
  // And then distance simply darkens it — toward black, not toward another
  // colour out of the palette. Which of two palette colours is the lighter
  // one changes with the hour: at night the far ground is lighter than the
  // near ground and the haze sits between them, so a rule written as a blend
  // of those came out in a different order at four in the morning than at
  // noon. Toward black it holds at every hour by construction.
  // Y de noche, la de más cerca se oscurece aparte.
  //
  // La regla de arriba oscurece con la distancia, que es lo que hace la
  // perspectiva aérea de día: lo lejano se lava contra el cielo. De noche
  // pasa lo contrario —lo cercano es una silueta negra contra un cielo que
  // todavía tiene algo de luz— y como la bruma y el suelo lejano son casi el
  // color del cielo a esa hora, la cordillera de delante se quedaba sin
  // oscurecer nada y desaparecía dentro del cielo. Justo la que más cerca
  // está y más debería recortarse.
  // De noche se oscurecen todas, sin juntarse entre ellas.
  //
  // De día manda la perspectiva aérea: lo lejano se lava contra el cielo y lo
  // cercano se queda con su color, así que la de delante no necesita nada. De
  // noche pasa lo contrario —lo cercano es una silueta contra un cielo que
  // todavía tiene algo de luz— y como a esa hora la bruma y el suelo lejano
  // son casi el color del cielo, la de delante se quedaba sin oscurecer nada
  // y desaparecía dentro de él. Justo la que más cerca está.
  //
  // Oscurecer sólo a la de delante la dejaba pegada a la del fondo, que es
  // otra manera de perder una cordillera. Lo que se hace es correr el tramo
  // entero: de noche va de un cincuenta y dos a un ochenta por ciento en vez
  // de un cero a un cincuenta y cuatro. Así se separan del cielo, siguen
  // separándose entre ellas, y la de delante sigue sin confundirse con el
  // prado —que a esa hora también es oscuro—, que son las tres cosas a la
  // vez y por eso los números salen de barrer las veinticuatro horas y no de
  // elegirlos a ojo. Con el tramo viejo, la de delante quedaba a dos
  // centésimas de luz del cielo: literalmente invisible.
  final noche = 1 - pal.daylight;
  final lejos = 1 - near01;
  var body = Color.lerp(
    hill,
    const Color(0xFF000000),
    lerpD(0.54 * lejos, 0.52 + 0.28 * lejos, noche),
  )!;
  // En invierno las cumbres se ven blancas desde el valle, y empiezan a
  // verse antes que la nieve de abajo: arriba hace más frío. Se aclara la
  // sierra entera y no sólo su borde —a esta distancia una cordillera es una
  // silueta plana— y con menos fuerza cuanto más lejos está, porque lo que
  // está lejos lo tapa la bruma y no la nieve.
  final alto = clampD(pal.season.winter * 1.45 - 0.30, 0.0, 1.0);
  if (alto > 0.004) {
    body = Color.lerp(
      body,
      snowTone(pal),
      alto * (0.22 + 0.26 * near01) * (0.35 + 0.65 * pal.daylight),
    )!;
  }
  return (body, Color.lerp(body, pal.haze, 0.30 + 0.15 * near01)!);
}
