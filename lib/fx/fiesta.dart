import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../l10n/lang.dart';
import '../model/appearance.dart';
import 'sensory.dart';

/// **La fiesta del valle completo**: lo que pasa el día que todos los
/// pueblos despiertos tienen a la vez su pieza.
///
/// Hay quince maneras de celebrarlo, para elegir una mirándolas en la app
/// (Ajustes → Desarrollo → *La fiesta del valle*). Van de lo mínimo —una
/// fila de cuentas, una luz que pasa— a lo grande —fuegos, una aurora, la
/// fiesta mayor con su título—, y cada una tiene lo suyo: su frase, su
/// sonido y su manera de mirar el valle.
///
/// Todas son **funciones del tiempo**: nada guarda partículas ni estado de un
/// cuadro al siguiente. Lo que se ve a los 2,4 segundos sale de los 2,4
/// segundos y de los pueblos, y nada más. Así se puede mirar cualquier
/// instante sin reproducir los anteriores, y dos pintores —el del mundo y el
/// de la interfaz— van siempre al compás sin hablarse.
enum FiestaKind {
  chispas,
  campanas,
  cuentas,
  luz,
  sello,
  banderines,
  petalos,
  hilo,
  palomas,
  farolillos,
  constelacion,
  arcoiris,
  fuegos,
  aurora,
  mayor,
  globos,
  fugaces,
  luciernagas,
  faros,
  pregon,
  cronica,
  mapa,
  floracion,
  musica,
  hogueras,
  pompas,
  fuentes,
  foto,
  confeti,
  ronda,
}

/// Cuánto ocupa una fiesta: para ordenarlas en la lista y nada más.
enum FiestaSize { minimal, medium, grand }

/// Cómo se mira el valle mientras dura.
enum FiestaCamera {
  /// Se queda donde estaba: la fiesta es de la interfaz.
  stay,

  /// Sube a mirar el valle entero.
  valley,

  /// Sube al valle con la cámara más baja, para que entre el cielo.
  sky,

  /// Sube al valle y le da una vuelta lenta.
  orbit,

  /// Va de pueblo en pueblo a media distancia, detrás de lo que pasa (las
  /// campanas, el hilo), y al final se aparta para que se vea todo.
  follow,

  /// Visita cada pueblo de cerca, uno por uno, y al final sube al valle.
  tour,
}

class FiestaInfo {
  const FiestaInfo({
    required this.es,
    required this.en,
    required this.aboutEs,
    required this.aboutEn,
    required this.size,
    required this.camera,
    required this.seconds,
    this.lineEs,
    this.lineEn,
    this.lineAt = 0.6,
    this.perTown = 0,
    this.reach = 0.8,
  });

  final String es, en;
  final String aboutEs, aboutEn;
  final FiestaSize size;
  final FiestaCamera camera;

  /// Cuánto se acerca la vista del valle, contra la distancia a la que
  /// entran todos los pueblos enteros. Menos de uno es más cerca: los de los
  /// bordes quedan cortados, y a cambio los pueblos se ven y no son puntos.
  final double reach;

  /// Lo que dura con dos pueblos. Ver [perTown].
  final double seconds;

  /// Lo que se alarga por cada pueblo de más, en las que van de uno en uno.
  final double perTown;

  /// La frase de abajo, si la lleva. Nula en las que ya dicen lo suyo
  /// dentro del dibujo (el sello, la fiesta mayor).
  final String? lineEs, lineEn;
  final double lineAt;

  String get name => tr(es, en);
  String get about => tr(aboutEs, aboutEn);
  String? get line => lineEs == null ? null : tr(lineEs!, lineEn!);

  double secondsFor(int towns) => seconds + perTown * math.max(0, towns - 2);
}

const Map<FiestaKind, FiestaInfo> fiestaInfo = {
  FiestaKind.chispas: FiestaInfo(
    es: 'Chispas de oro',
    en: 'Golden sparks',
    aboutEs:
        'La cámara sube al valle y de cada plaza sale una fuente de chispas '
        'doradas, una detrás de otra.',
    aboutEn:
        'The camera rises to the valley and a fountain of golden sparks '
        'comes out of every plaza, one after another.',
    size: FiestaSize.medium,
    camera: FiestaCamera.valley,
    reach: 0.7,
    seconds: 5.0,
    perTown: 0.25,
    lineEs: 'Hoy cayó una pieza en todos los pueblos.',
    lineEn: 'Every town got its piece today.',
  ),
  FiestaKind.campanas: FiestaInfo(
    es: 'Campanadas',
    en: 'Bells',
    aboutEs:
        'Cada pueblo toca su campana, de uno en uno y cada uno en su nota, y '
        'el sonido se ve como un anillo que se abre en la plaza. Al final, '
        'todas juntas.',
    aboutEn:
        'Each town rings its bell, one at a time and each in its own note, '
        'and the sound shows as a ring opening in the plaza. At the end, all '
        'of them together.',
    size: FiestaSize.minimal,
    camera: FiestaCamera.valley,
    reach: 0.75,
    seconds: 4.6,
    perTown: 0.55,
    lineEs: 'Suenan las campanas de todo el valle.',
    lineEn: 'The bells ring across the whole valley.',
    lineAt: 0.9,
  ),
  FiestaKind.cuentas: FiestaInfo(
    es: 'Las cuentas',
    en: 'The beads',
    aboutEs:
        'Sin mover nada: una fila de cuentas, una por pueblo y con su marca. '
        'Están todas llenas menos la tuya, que se llena con un clic, y se '
        'juntan en una sola.',
    aboutEn:
        'Nothing moves: a row of beads, one per town and with its mark. They '
        'are all full but yours, which fills with a click, and they come '
        'together into one.',
    size: FiestaSize.minimal,
    camera: FiestaCamera.stay,
    seconds: 5.2,
  ),
  FiestaKind.luz: FiestaInfo(
    es: 'Luz de oro',
    en: 'Golden light',
    aboutEs:
        'Lo más callado: una luz cálida cruza la pantalla como un sol que '
        'asoma, y una frase. Nada se mueve de su sitio.',
    aboutEn:
        'The quietest one: a warm light crosses the screen like the sun '
        'coming out, and a line. Nothing moves from its place.',
    size: FiestaSize.minimal,
    camera: FiestaCamera.stay,
    seconds: 5.5,
    lineEs: 'Hoy el valle entero tiene lo suyo.',
    lineEn: 'Today the whole valley has its share.',
    lineAt: 1.0,
  ),
  FiestaKind.sello: FiestaInfo(
    es: 'El sello del día',
    en: 'The seal of the day',
    aboutEs:
        'Cae un sello de lacre en el medio de la pantalla, con un golpe: las '
        'marcas de todos los pueblos alrededor y la fecha en el centro.',
    aboutEn:
        'A wax seal falls in the middle of the screen with a thud: the marks '
        'of every town around the edge and the date in the middle.',
    size: FiestaSize.medium,
    camera: FiestaCamera.stay,
    seconds: 5.0,
  ),
  FiestaKind.banderines: FiestaInfo(
    es: 'Banderines',
    en: 'Bunting',
    aboutEs:
        'Bajan del borde de arriba dos guirnaldas de banderines de colores, '
        'como en las fiestas de pueblo, y se mecen un rato. En la primera, '
        'una bandera por pueblo con su marca.',
    aboutEn:
        'Two strings of coloured bunting drop from the top edge, like at a '
        'village fair, and sway for a while. On the first, one flag per town '
        'with its mark.',
    size: FiestaSize.medium,
    camera: FiestaCamera.stay,
    seconds: 6.5,
    lineEs: 'Hoy hay fiesta en el valle.',
    lineEn: "There's a fair in the valley today.",
    lineAt: 0.8,
  ),
  FiestaKind.petalos: FiestaInfo(
    es: 'Pétalos',
    en: 'Petals',
    aboutEs:
        'Una lluvia lenta de pétalos que cruza toda la pantalla, girando con '
        'el aire, sobre el pueblo que estás mirando.',
    aboutEn:
        'A slow shower of petals across the whole screen, turning in the '
        "air, over the town you're looking at.",
    size: FiestaSize.medium,
    camera: FiestaCamera.stay,
    seconds: 7.0,
    lineEs: 'Todo el valle, hoy.',
    lineEn: 'The whole valley, today.',
    lineAt: 1.2,
  ),
  FiestaKind.hilo: FiestaInfo(
    es: 'El hilo de oro',
    en: 'The golden thread',
    aboutEs:
        'Un hilo de luz sale de tu pueblo y va pasando por todos, de plaza en '
        'plaza, con una nota en cada una, hasta cerrar el valle.',
    aboutEn:
        'A thread of light leaves your town and passes through all of them, '
        'plaza to plaza, with a note at each one, until the valley is tied '
        'together.',
    size: FiestaSize.medium,
    camera: FiestaCamera.follow,
    seconds: 4.3,
    perTown: 0.75,
    lineEs: 'Un hilo que pasa por todos los pueblos.',
    lineEn: 'One thread through every town.',
    lineAt: 1.0,
  ),
  FiestaKind.palomas: FiestaInfo(
    es: 'Palomas',
    en: 'Doves',
    aboutEs:
        'De cada plaza levanta vuelo una bandada de palomas blancas; se '
        'juntan sobre el valle, dan una vuelta y se van.',
    aboutEn:
        'A flock of white doves takes off from every plaza; they come '
        'together over the valley, wheel round once and fly away.',
    size: FiestaSize.medium,
    camera: FiestaCamera.sky,
    seconds: 7.0,
    lineEs: 'Las palomas llevan la noticia a todos los pueblos.',
    lineEn: 'The doves carry the news to every town.',
    lineAt: 1.2,
  ),
  FiestaKind.farolillos: FiestaInfo(
    es: 'Farolillos',
    en: 'Lanterns',
    aboutEs:
        'El cielo se apaga un poco y de cada pueblo suben farolillos de papel '
        'encendidos, meciéndose despacio hasta perderse.',
    aboutEn:
        'The sky dims a little and lit paper lanterns rise from every town, '
        'swaying slowly until they are gone.',
    size: FiestaSize.grand,
    camera: FiestaCamera.sky,
    seconds: 8.0,
    lineEs: 'Un farol por cada pueblo.',
    lineEn: 'A lantern for every town.',
    lineAt: 1.4,
  ),
  FiestaKind.constelacion: FiestaInfo(
    es: 'La constelación',
    en: 'The constellation',
    aboutEs:
        'De cada plaza sube una luz al cielo y se queda como estrella. Se unen '
        'con líneas finas y el valle queda dibujado arriba, como una '
        'constelación.',
    aboutEn:
        'A light rises from every plaza into the sky and stays as a star. '
        'Fine lines join them and the valley is drawn up there, like a '
        'constellation.',
    size: FiestaSize.medium,
    camera: FiestaCamera.sky,
    seconds: 7.5,
    lineEs: 'Hoy el valle tiene su constelación.',
    lineEn: 'Today the valley has its own constellation.',
    lineAt: 3.0,
  ),
  FiestaKind.arcoiris: FiestaInfo(
    es: 'Arcoíris',
    en: 'Rainbow',
    aboutEs:
        'Un arcoíris se dibuja de punta a punta del valle, del primer pueblo '
        'al último, y se desvanece despacio.',
    aboutEn:
        'A rainbow draws itself from one end of the valley to the other, '
        'first town to last, and slowly fades.',
    size: FiestaSize.grand,
    camera: FiestaCamera.sky,
    seconds: 7.0,
    lineEs: 'De punta a punta del valle.',
    lineEn: 'From one end of the valley to the other.',
    lineAt: 1.6,
  ),
  FiestaKind.fuegos: FiestaInfo(
    es: 'Fuegos artificiales',
    en: 'Fireworks',
    aboutEs:
        'Cae la noche un momento y cada pueblo tira sus cohetes, cada uno de '
        'su color; al final, todos a la vez.',
    aboutEn:
        'Night falls for a moment and each town sends up its rockets, each in '
        'its own colour; at the end, all at once.',
    size: FiestaSize.grand,
    camera: FiestaCamera.sky,
    seconds: 8.5,
    perTown: 0.35,
    lineEs: '¡Fiesta en todo el valle!',
    lineEn: 'A fair across the whole valley!',
    lineAt: 1.2,
  ),
  FiestaKind.aurora: FiestaInfo(
    es: 'Aurora',
    en: 'Aurora',
    aboutEs:
        'El cielo se oscurece y sobre el valle se abre una aurora de cortinas '
        'verdes y violetas que ondean y se apagan.',
    aboutEn:
        'The sky darkens and over the valley an aurora opens, green and '
        'violet curtains that ripple and fade.',
    size: FiestaSize.grand,
    camera: FiestaCamera.sky,
    seconds: 8.5,
    lineEs: 'Ni el cielo se lo quiso perder.',
    lineEn: "Not even the sky wanted to miss it.",
    lineAt: 2.0,
  ),
  FiestaKind.mayor: FiestaInfo(
    es: 'La fiesta mayor',
    en: 'The grand fair',
    aboutEs:
        'Como una película: entran dos franjas negras, la cámara da una vuelta '
        'lenta al valle, suena un pasacalle, sale el título con la fecha y '
        'cierran los fuegos de todos los pueblos.',
    aboutEn:
        'Like a film: two black bars come in, the camera slowly circles the '
        'valley, a little street tune plays, the title comes up with the date '
        'and every town closes with fireworks.',
    size: FiestaSize.grand,
    camera: FiestaCamera.orbit,
    seconds: 10.0,
  ),
  FiestaKind.globos: FiestaInfo(
    es: 'Globos',
    en: 'Balloons',
    aboutEs:
        'De cada plaza se escapa un puñado de globos de colores, con su hilo '
        'colgando, que suben meciéndose hasta perderse en el cielo.',
    aboutEn:
        'A handful of coloured balloons slip away from every plaza, strings '
        'dangling, and rise swaying until they are lost in the sky.',
    size: FiestaSize.medium,
    camera: FiestaCamera.sky,
    seconds: 7.5,
    lineEs: 'Se escapan los globos de todas las plazas.',
    lineEn: 'Balloons slip away from every plaza.',
    lineAt: 1.2,
  ),
  FiestaKind.fugaces: FiestaInfo(
    es: 'Estrellas fugaces',
    en: 'Shooting stars',
    aboutEs:
        'Se hace de noche un momento y cruzan el cielo estrellas fugaces, una '
        'por cada pueblo.',
    aboutEn:
        'Night falls for a moment and shooting stars cross the sky, one for '
        'every town.',
    size: FiestaSize.medium,
    camera: FiestaCamera.sky,
    seconds: 4.8,
    perTown: 0.55,
    lineEs: 'Una estrella por cada pueblo. Pedí algo.',
    lineEn: 'A star for every town. Make a wish.',
    lineAt: 1.6,
  ),
  FiestaKind.luciernagas: FiestaInfo(
    es: 'Luciérnagas',
    en: 'Fireflies',
    aboutEs:
        'Cae la tarde y de los campos de cada pueblo salen luciérnagas que '
        'parpadean despacio y se van apagando.',
    aboutEn:
        'Dusk falls and fireflies rise from the fields of every town, '
        'blinking slowly and fading out.',
    size: FiestaSize.minimal,
    camera: FiestaCamera.valley,
    reach: 0.7,
    seconds: 7.5,
    lineEs: 'Hasta las luciérnagas salieron a ver.',
    lineEn: 'Even the fireflies came out to see.',
    lineAt: 1.8,
  ),
  FiestaKind.faros: FiestaInfo(
    es: 'Faros',
    en: 'Beacons',
    aboutEs:
        'Cada pueblo enciende una columna de luz que sube de su plaza al '
        'cielo, de uno en uno, y al final laten todas juntas.',
    aboutEn:
        'Each town lights a column of light rising from its plaza into the '
        'sky, one at a time, and at the end they all pulse together.',
    size: FiestaSize.grand,
    camera: FiestaCamera.sky,
    seconds: 6.5,
    perTown: 0.45,
    lineEs: 'Cada pueblo enciende su luz.',
    lineEn: 'Every town lights its beacon.',
    lineAt: 1.0,
  ),
  FiestaKind.pregon: FiestaInfo(
    es: 'El pregón',
    en: 'The proclamation',
    aboutEs:
        'Suenan las trompetas y baja un pergamino que se desenrolla: el pregón '
        'del día, con el nombre y la marca de cada pueblo.',
    aboutEn:
        'Trumpets sound and a scroll comes down and unrolls: the day\'s '
        'proclamation, with the name and mark of every town.',
    size: FiestaSize.medium,
    camera: FiestaCamera.stay,
    seconds: 6.8,
  ),
  FiestaKind.cronica: FiestaInfo(
    es: 'La crónica',
    en: 'The chronicle',
    aboutEs:
        'Lo más sobrio: sobre el pueblo se escribe a mano, con tinta, una sola '
        'línea, como quien la anota en la crónica del valle.',
    aboutEn:
        'The most understated: a single line is handwritten in ink over the '
        'town, as if being entered in the valley chronicle.',
    size: FiestaSize.minimal,
    camera: FiestaCamera.stay,
    seconds: 6.0,
  ),
  FiestaKind.mapa: FiestaInfo(
    es: 'El mapa del valle',
    en: 'The valley map',
    aboutEs:
        'El valle se vuelve un mapa antiguo: tinta que dibuja los caminos '
        'entre los pueblos, un círculo en cada uno, la rosa de los vientos y '
        'la fecha en una cartela.',
    aboutEn:
        'The valley turns into an old map: ink drawing the roads between the '
        'towns, a circle round each one, the compass rose and the date in a '
        'cartouche.',
    size: FiestaSize.medium,
    camera: FiestaCamera.valley,
    reach: 0.85,
    seconds: 7.5,
  ),
  FiestaKind.floracion: FiestaInfo(
    es: 'Floración',
    en: 'Bloom',
    aboutEs:
        'Alrededor de cada plaza se abre un anillo de flores, pueblo por '
        'pueblo, cada uno con su nota.',
    aboutEn:
        'A ring of flowers opens around every plaza, town by town, each with '
        'its note.',
    size: FiestaSize.minimal,
    camera: FiestaCamera.valley,
    reach: 0.7,
    seconds: 6.5,
    perTown: 0.35,
    lineEs: 'El valle florece.',
    lineEn: 'The valley blooms.',
    lineAt: 1.2,
  ),
  FiestaKind.musica: FiestaInfo(
    es: 'La música',
    en: 'The music',
    aboutEs:
        'Suena un pasacalle y de cada plaza suben notas de música que se '
        'mecen al compás.',
    aboutEn:
        'A street tune plays and musical notes rise from every plaza, '
        'swaying in time.',
    size: FiestaSize.medium,
    camera: FiestaCamera.valley,
    reach: 0.7,
    seconds: 7.5,
    lineEs: 'Suena música en todas las plazas.',
    lineEn: 'Music in every plaza.',
    lineAt: 1.0,
  ),
  FiestaKind.hogueras: FiestaInfo(
    es: 'Hogueras',
    en: 'Bonfires',
    aboutEs:
        'Cae la noche y en cada plaza se enciende una hoguera, como en San '
        'Juan, con las brasas subiendo al cielo.',
    aboutEn:
        'Night falls and a bonfire is lit in every plaza, like on Midsummer '
        'night, embers rising into the sky.',
    size: FiestaSize.grand,
    camera: FiestaCamera.sky,
    reach: 0.75,
    seconds: 8.0,
    lineEs: 'Hogueras en todas las plazas.',
    lineEn: 'Bonfires in every plaza.',
    lineAt: 1.4,
  ),
  FiestaKind.pompas: FiestaInfo(
    es: 'Pompas de jabón',
    en: 'Soap bubbles',
    aboutEs:
        'De cada plaza salen pompas de jabón irisadas que flotan sobre el '
        'pueblo y revientan sin hacer ruido.',
    aboutEn:
        'Iridescent soap bubbles drift up from every plaza, float over the '
        'town and pop without a sound.',
    size: FiestaSize.medium,
    camera: FiestaCamera.valley,
    reach: 0.7,
    seconds: 7.0,
    lineEs: 'Hoy hasta el aire juega.',
    lineEn: 'Today even the air is playing.',
    lineAt: 1.4,
  ),
  FiestaKind.fuentes: FiestaInfo(
    es: 'Las fuentes',
    en: 'The fountains',
    aboutEs:
        'Las fuentes de todas las plazas tiran un chorro alto a la vez, y el '
        'agua cae brillando al sol.',
    aboutEn:
        'The fountains in every plaza shoot a tall jet at once, and the water '
        'falls glittering in the sun.',
    size: FiestaSize.medium,
    camera: FiestaCamera.valley,
    reach: 0.7,
    seconds: 6.0,
    lineEs: 'Las fuentes de todo el valle, a la vez.',
    lineEn: 'Every fountain in the valley, all at once.',
    lineAt: 1.0,
  ),
  FiestaKind.foto: FiestaInfo(
    es: 'La foto del día',
    en: 'The photo of the day',
    aboutEs:
        'La cámara sube al valle, salta el flash y el valle queda en una foto '
        'con su borde blanco y la fecha escrita a mano. Se queda un rato y se '
        'va.',
    aboutEn:
        'The camera rises to the valley, the flash goes off and the valley is '
        'kept in a photo with its white border and the date written by hand. '
        'It stays a moment and goes.',
    size: FiestaSize.medium,
    camera: FiestaCamera.sky,
    reach: 0.8,
    seconds: 6.5,
  ),
  FiestaKind.confeti: FiestaInfo(
    es: 'Confeti',
    en: 'Confetti',
    aboutEs:
        'Dos tiros de confeti desde las esquinas de abajo, papelitos de '
        'colores que suben, giran y caen sobre el pueblo.',
    aboutEn:
        'Two bursts of confetti from the bottom corners, coloured scraps that '
        'fly up, spin and fall over the town.',
    size: FiestaSize.medium,
    camera: FiestaCamera.stay,
    seconds: 5.5,
    lineEs: '¡Todos los pueblos, hoy!',
    lineEn: 'Every town, today!',
    lineAt: 0.5,
  ),
  FiestaKind.ronda: FiestaInfo(
    es: 'La ronda',
    en: 'The round',
    aboutEs:
        'Un paseo: la cámara visita cada pueblo de cerca, uno por uno; en cada '
        'plaza se enciende una luz y suena una nota. Al final sube a mirar el '
        'valle entero.',
    aboutEn:
        'A stroll: the camera visits each town up close, one by one; a light '
        'comes on in each plaza and a note sounds. At the end it rises to see '
        'the whole valley.',
    size: FiestaSize.grand,
    camera: FiestaCamera.tour,
    reach: 0.9,
    seconds: 2 * Fiesta.rondaStep + 2.6,
    perTown: Fiesta.rondaStep,
    lineEs: 'Una vuelta por todos los pueblos.',
    lineEn: 'A round of every town.',
    lineAt: 0.4,
  ),
};

/// Un pueblo, para la fiesta: dónde está y qué marca lleva.
class FiestaTown {
  const FiestaTown({
    required this.x,
    required this.z,
    required this.radius,
    required this.symbol,
    required this.name,
  });

  final double x, z, radius;
  final String symbol, name;
}

/// Una fiesta en marcha.
class FiestaShow {
  FiestaShow(this.kind, this.towns, this.active, this.day)
    : _clock = Stopwatch()..start();

  final FiestaKind kind;
  final List<FiestaTown> towns;

  /// Cuál es el tuyo: el que acaba de recibir la pieza que faltaba.
  final int active;

  /// El día que se celebra, para el sello y el título.
  final DateTime day;

  final Stopwatch _clock;

  FiestaInfo get info => fiestaInfo[kind]!;
  double get t {
    final pasos = steps;
    if (pasos == null || pasos.isEmpty) return _clock.elapsedMicroseconds / 1e6;
    final i = int.tryParse(Uri.base.fragment) ?? 0;
    return pasos[i.clamp(0, pasos.length - 1)];
  }

  /// Sólo para mirarla desde el navegador (ver `FIESTA_URL`): en vez de
  /// correr, la fiesta se queda quieta en uno de estos instantes, el que dice
  /// el número después del `#` de la dirección, para poder sacarle una foto
  /// exacta a cada uno.
  List<double>? steps;
  double get length => kind == FiestaKind.hilo
      ? Fiesta.hiloReach(towns.length - 1, towns.length) + 2.6
      : info.secondsFor(towns.length);
  bool get over => steps == null && t >= length;

  /// El orden en que se recorre el valle: desde el tuyo, siempre al más
  /// cercano que falta. Es el del hilo y el de las campanas.
  late final List<int> path = () {
    final n = towns.length;
    if (n == 0) return const <int>[];
    final quedan = {for (var i = 0; i < n; i++) i}..remove(active);
    final orden = [active.clamp(0, n - 1)];
    while (quedan.isNotEmpty) {
      final a = towns[orden.last];
      var mejor = quedan.first;
      var d = double.infinity;
      for (final j in quedan) {
        final b = towns[j];
        final dd = (a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z);
        if (dd < d) {
          d = dd;
          mejor = j;
        }
      }
      orden.add(mejor);
      quedan.remove(mejor);
    }
    return orden;
  }();

  /// El centro del valle y lo ancho que es, para que lo que se dibuja sobre
  /// él tenga su tamaño y no el de un pueblo.
  late final (double, double, double) valley = () {
    if (towns.isEmpty) return (0.0, 0.0, 30.0);
    var sx = 0.0, sz = 0.0;
    for (final t in towns) {
      sx += t.x;
      sz += t.z;
    }
    final cx = sx / towns.length, cz = sz / towns.length;
    var span = 0.0;
    for (final a in towns) {
      span = math.max(span, a.radius * 4);
      for (final b in towns) {
        span = math.max(
          span,
          math.sqrt((a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z)),
        );
      }
    }
    return (cx, cz, math.max(span, 24.0));
  }();
}

/// La que está en marcha y la que está elegida.
class Fiesta extends ChangeNotifier {
  Fiesta._();
  static final Fiesta instance = Fiesta._();

  FiestaShow? _show;

  /// La foto del valle, para la fiesta de la foto: la saca la pantalla de
  /// inicio en el momento del flash, que es la que tiene el pueblo delante.
  ui.Image? photo;

  void keepPhoto(ui.Image img) {
    photo?.dispose();
    photo = img;
    notifyListeners();
  }

  /// La que está en marcha, o nula. Se apaga sola al terminar.
  FiestaShow? get show {
    final s = _show;
    if (s != null && s.over) {
      _show = null;
      scheduleMicrotask(notifyListeners);
      return null;
    }
    return s;
  }

  /// La elegida: la que sale el día que pasa de verdad.
  FiestaKind get chosen {
    final id = Appearance.instance.fiesta;
    for (final k in FiestaKind.values) {
      if (k.name == id) return k;
    }
    return FiestaKind.chispas;
  }

  Future<void> choose(FiestaKind k) => Appearance.instance.setFiesta(k.name);

  /// Pide un ensayo: la vista del pueblo lo oye y la pone en marcha, porque
  /// es ella la que sabe dónde está cada pueblo y mueve la cámara.
  final ValueNotifier<(FiestaKind, int)?> rehearsal = ValueNotifier(null);
  int _ensayos = 0;

  void rehearse(FiestaKind k) => rehearsal.value = (k, ++_ensayos);

  /// Empezarla. La llama la vista del pueblo, que ya movió la cámara.
  FiestaShow start(
    FiestaKind kind,
    List<FiestaTown> towns,
    int active, {
    DateTime? day,
  }) {
    final s = FiestaShow(kind, towns, active, day ?? DateTime.now());
    photo?.dispose();
    photo = null;
    if (const bool.fromEnvironment('FIESTA_URL')) {
      final q = Uri.base.queryParameters['pasos'];
      if (q != null) {
        s.steps = [for (final x in q.split(',')) double.tryParse(x) ?? 0];
      }
    }
    _show = s;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _score(s);
    notifyListeners();
    return s;
  }

  final List<Timer> _timers = [];

  void _at(double seconds, void Function() f) {
    _timers.add(
      Timer(Duration(milliseconds: (seconds * 1000).round()), () {
        if (identical(_show, null)) return;
        f();
      }),
    );
  }

  /// Lo que suena, y cuándo. Va con el dibujo al décimo de segundo: los
  /// tiempos de acá son los mismos que usan los pintores.
  void _score(FiestaShow s) {
    final n = s.towns.length;
    final snd = Sensory.instance;
    switch (s.kind) {
      case FiestaKind.chispas:
        _at(0.45, snd.milestone);
      case FiestaKind.campanas:
        for (var i = 0; i < n; i++) {
          _at(campanaAt(i), () => snd.fiesta('fiesta_campana${i % 8}'));
        }
        _at(campanaAt(n) + 0.15, () => snd.fiesta('fiesta_campanas'));
      case FiestaKind.cuentas:
        _at(cuentaFill, () => snd.fiesta('fiesta_cuenta'));
        _at(cuentaJoin + 0.35, () => snd.fiesta('fiesta_cuenta_fin'));
      case FiestaKind.luz:
        _at(0.0, () => snd.fiesta('fiesta_luz'));
      case FiestaKind.sello:
        _at(selloLands - 0.02, () => snd.fiesta('fiesta_sello'));
      case FiestaKind.banderines:
        _at(0.1, () => snd.fiesta('fiesta_pasacalle'));
      case FiestaKind.petalos:
        _at(0.0, () => snd.fiesta('fiesta_brisa'));
      case FiestaKind.hilo:
        for (var i = 0; i < n; i++) {
          _at(hiloReach(i, n), () => snd.fiesta('fiesta_nota${i % 8}'));
        }
        _at(hiloReach(n - 1, n) + 0.5, () => snd.fiesta('fiesta_campanas'));
      case FiestaKind.palomas:
        _at(0.2, () => snd.fiesta('fiesta_aleteo'));
      case FiestaKind.farolillos:
        _at(0.0, () => snd.fiesta('fiesta_luz'));
      case FiestaKind.constelacion:
        for (var i = 0; i < n; i++) {
          _at(
            estrellaAt(i) + estrellaRise,
            () => snd.fiesta('fiesta_nota${(i + 3) % 8}'),
          );
        }
        _at(estrellaAt(n - 1) + estrellaRise + 0.6, () => snd.star());
      case FiestaKind.arcoiris:
        _at(0.2, () => snd.fiesta('fiesta_arpa'));
      case FiestaKind.fuegos:
        for (final c in cohetes(s)) {
          _at(c.at, () => snd.fiesta('fiesta_silbido'));
          _at(c.at + c.rise, () => snd.fiesta('fiesta_cohete'));
        }
      case FiestaKind.aurora:
        _at(0.0, () => snd.fiesta('fiesta_aurora'));
      case FiestaKind.mayor:
        _at(0.3, () => snd.fiesta('fiesta_pasacalle'));
        _at(mayorTitle, snd.milestone);
        for (final c in cohetes(s)) {
          _at(c.at, () => snd.fiesta('fiesta_silbido'));
          _at(c.at + c.rise, () => snd.fiesta('fiesta_cohete'));
        }
      case FiestaKind.globos:
        _at(0.3, () => snd.fiesta('fiesta_brisa'));
      case FiestaKind.fugaces:
        for (var i = 0; i < n; i++) {
          _at(
            fugazAt(i) + 0.1,
            () => snd.fiesta('fiesta_nota${(i * 3 + 2) % 8}', level: 0.5),
          );
        }
      case FiestaKind.luciernagas:
        _at(0.2, () => snd.fiesta('fiesta_grillos'));
      case FiestaKind.faros:
        for (var k = 0; k < n; k++) {
          _at(faroAt(k), () => snd.fiesta('fiesta_faro'));
        }
        _at(faroAt(n) + 0.1, () => snd.fiesta('fiesta_campanas', level: 0.6));
      case FiestaKind.pregon:
        _at(0.05, () => snd.fiesta('fiesta_pregon'));
      case FiestaKind.cronica:
        _at(0.5, () => snd.fiesta('fiesta_pluma'));
      case FiestaKind.mapa:
        _at(0.4, () => snd.fiesta('fiesta_pluma'));
      case FiestaKind.floracion:
        for (var k = 0; k < n; k++) {
          _at(floraAt(k), () => snd.fiesta('fiesta_nota${k % 8}', level: 0.6));
        }
      case FiestaKind.musica:
        _at(0.2, () => snd.fiesta('fiesta_pasacalle'));
      case FiestaKind.hogueras:
        _at(0.4, () => snd.fiesta('fiesta_fuego'));
      case FiestaKind.pompas:
        _at(0.3, () => snd.fiesta('fiesta_pompas'));
      case FiestaKind.fuentes:
        _at(0.25, () => snd.fiesta('fiesta_agua'));
      case FiestaKind.foto:
        _at(fotoFlash - 0.05, () => snd.fiesta('fiesta_foto'));
      case FiestaKind.confeti:
        _at(0.08, () => snd.fiesta('fiesta_confeti'));
      case FiestaKind.ronda:
        for (var k = 0; k < n; k++) {
          _at(
            rondaArrive(k),
            () => snd.fiesta('fiesta_nota${(k * 2) % 8}', level: 0.7),
          );
        }
        _at(
          rondaStep * n + 0.6,
          () => snd.fiesta('fiesta_campanas', level: 0.6),
        );
    }
  }

  void stop() {
    _show = null;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------- los tiempos
  //
  // Los comparten el que suena y los que pintan. Viven acá para que no
  // puedan no estar de acuerdo.

  static double campanaAt(int i) => 0.35 + 0.55 * i;

  /// Por dónde del recorrido del valle va la cámara a los [t] segundos, en
  /// las fiestas que siguen algo de pueblo en pueblo: 2,5 es a mitad de
  /// camino entre el tercero y el cuarto. Nulo cuando ya no sigue nada y le
  /// toca mirar el valle entero.
  static double? followAt(FiestaShow s, double t) {
    final n = s.towns.length;
    if (n == 0) return null;
    double tramo(double t0, double t1, int k) =>
        k + ((t - t0) / (t1 - t0)).clamp(0.0, 1.0);
    switch (s.kind) {
      case FiestaKind.campanas:
        // Llega a cada campana un poco antes de que suene.
        if (t > campanaAt(n) - 0.2) return null;
        for (var k = 0; k < n - 1; k++) {
          if (t < campanaAt(k + 1) - 0.25) {
            return tramo(campanaAt(k), campanaAt(k + 1) - 0.25, k);
          }
        }
        return (n - 1).toDouble();
      case FiestaKind.hilo:
        // Detrás de la cabeza del hilo.
        if (t > hiloReach(n - 1, n) + 0.15) return null;
        for (var k = 0; k < n - 1; k++) {
          if (t < hiloReach(k + 1, n)) {
            return tramo(hiloReach(k, n), hiloReach(k + 1, n), k);
          }
        }
        return (n - 1).toDouble();
      case FiestaKind.ronda:
        if (t > rondaStep * n) return null;
        final k = (t / rondaStep).floor();
        if (k == 0) return 0;
        return (k - 1) + ((t - k * rondaStep) / 1.1).clamp(0.0, 1.0);
      default:
        return null;
    }
  }

  /// Lo que la ronda se queda en cada pueblo.
  static const double rondaStep = 2.3;

  /// Cuándo llega la ronda a su pueblo número [k] del recorrido.
  static double rondaArrive(int k) => k == 0 ? 0.5 : k * rondaStep + 0.9;

  static double fugazAt(int i) => 0.9 + 0.55 * i;
  static double faroAt(int k) => 0.5 + 0.45 * k;
  static double floraAt(int k) => 0.35 + 0.35 * k;
  static const double fotoFlash = 0.6;

  static const double cuentaFill = 1.15;
  static const double cuentaJoin = 2.6;

  static const double selloLands = 0.5;

  /// Cuándo llega el hilo a su pueblo número [i], en un valle de [n]: un
  /// segundo de plaza a plaza, que es lo que deja seguirlo con la cámara sin
  /// marear; con muchos pueblos, más deprisa, para que no se haga eterno.
  static double hiloReach(int i, int n) =>
      0.6 + i * (n <= 1 ? 1.0 : (6.0 / (n - 1)).clamp(0.6, 1.1));

  static double estrellaAt(int i) => 0.6 + 0.45 * i;
  static const double estrellaRise = 0.9;

  static const double mayorTitle = 2.4;

  /// Los cohetes de una fiesta: cuándo sale cada uno, de qué pueblo, cuánto
  /// tarda en subir y de qué color revienta.
  static List<Cohete> cohetes(FiestaShow s) {
    final n = s.towns.length;
    final out = <Cohete>[];
    final grande = s.kind == FiestaKind.fuegos;
    final empieza = grande ? 0.5 : 5.6;
    final paso = grande ? 0.42 : 0.18;
    // Una ronda de uno en uno, por el orden del valle.
    for (var k = 0; k < n; k++) {
      final i = s.path[k];
      out.add(Cohete(i, empieza + paso * k, 1.05, i, k));
    }
    if (grande) {
      // Una segunda ronda más apretada, desordenada.
      final ronda2 = empieza + paso * n + 0.5;
      for (var k = 0; k < n; k++) {
        final i = s.path[(k * 3 + 1) % n];
        out.add(Cohete(i, ronda2 + 0.22 * k, 0.95, i + 3, n + k));
      }
    }
    // Y el final: todos a la vez.
    final fin = grande ? empieza + paso * n + 1.0 + 0.22 * n + 0.6 : 7.4;
    for (var i = 0; i < n; i++) {
      out.add(Cohete(i, fin + 0.05 * i, 1.15, i + 6, 2 * n + i, big: true));
    }
    return out;
  }
}

class Cohete {
  const Cohete(
    this.town,
    this.at,
    this.rise,
    this.color,
    this.seed, {
    this.big = false,
  });
  final int town;
  final double at, rise;
  final int color, seed;
  final bool big;
}
