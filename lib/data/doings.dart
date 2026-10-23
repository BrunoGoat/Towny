/// Todo lo que hace la gente del pueblo cuando no está andando.
///
/// Andar de un sitio a otro era lo único que había, y un pueblo donde cuarenta
/// personas sólo andan se lee como tráfico y no como vida. Después vinieron
/// seis cosas, y seis cosas en cuarenta vecinos son seis cosas repetidas siete
/// veces, que se nota todavía más.
///
/// Esto es una **tabla**, no un montón de casos especiales, y esa es la única
/// razón por la que puede haber noventa. Cada renglón dice tres cosas: dónde
/// tiene sentido, cómo se mueve el cuerpo, y qué le flota en la mano. El motor
/// no sabe qué es amasar pan; sabe agacharse un tercio, mecerse despacio y
/// sostener una tabla. De ahí salen todas.
///
/// **Y ninguna se gana ni se compra.** Son consecuencia de lo construido, como
/// la gente misma: un pueblo con fuente tiene quien eche un barco de papel
/// porque tiene fuente. La regla de una pieza un logro no la toca nada de
/// esto.
library;

import '../l10n/en_doings.dart';
import '../l10n/lang.dart';

/// Dónde tiene sentido hacer algo.
///
/// Es la mitad de lo que hace que esto parezca un pueblo y no un parque de
/// atracciones: nadie pesca en una era ni amasa pan en mitad del prado. Cada
/// recado de la ronda cae en uno de estos sitios y sólo se sortea entre lo que
/// se puede hacer ahí.
enum Where {
  /// En su propia puerta. Es el único sitio de la ronda que es suyo, y por eso
  /// es donde pasan las cosas de casa.
  door,

  /// La plaza: el sitio de todos, donde se habla y se mira.
  square,

  /// Donde hay agua — el pozo, la fuente, el lavadero, el puente, la presa.
  water,

  /// Al pie de una obra grande.
  work,

  /// El prado, al borde del pueblo.
  meadow,
}

/// A quién le toca.
enum Who { anyone, kid, grown }

/// Lo que alguien lleva encima.
///
/// **Una por cosa, y hecha de verdad.** Antes había quince formas genéricas
/// —una caja en la mano, una vara, algo en el suelo— y cada actividad elegía
/// una y le daba un tamaño y un color. Eso no hace un objeto: la escoba salía
/// siendo un palo, y un palo no es una escoba por mucho que la nota diga
/// «barre el umbral». No es que la animación no se entienda; es que el objeto
/// está mal.
///
/// Así que ahora cada cosa tiene su geometría, con las piezas que hagan falta,
/// y sólo existe la que esté bien. La lista crece de a poco y sólo con lo que
/// se entiende mirándolo.
enum PropKind {
  none,

  /// Mango y cepillo, el cepillo en el suelo.
  broom,

  /// Un libro abierto: dos páginas en ángulo, sus tapas y el lomo.
  book,

  /// Una banqueta de tres patas. Quien la tiene se sienta en ella.
  stool,

  /// Un caldero colgado de una soga, que sube y baja con el gesto.
  pail,

  /// Un barreño en el suelo con ropa dentro.
  tub,

  /// Una caña larga con su sedal hasta el agua.
  rod,

  /// Un laúd: la caja de peras contra el pecho y el mástil cruzado.
  lute,

  /// Un tablero sobre caballetes con el género encima.
  stall,

  /// Una maza que baja sobre un sillar.
  mallet,

  /// Un madero sobre el caballete y la sierra pasando por él.
  saw,

  /// Una guadaña: el mango largo y la hoja a ras de suelo.
  scythe,

  /// Una cuerda entre dos palos con la ropa colgada.
  line,

  /// Tres pelotas de colores dando vueltas por encima de la cabeza.
  balls,

  /// Un tambor colgado a la altura de la tripa y las dos baquetas.
  drum,

  /// Una comba que pasa por encima de la cabeza y por debajo de los pies.
  rope,

  /// Un tocón con un leño encima y el hacha subiendo y cayendo.
  axe,

  /// Tres gallinas que viven delante de la casa, picoteando, y el grano
  /// cayendo de la mano de quien les da de comer.
  hens,

  /// Un barco de papel con su vela, meciéndose en el pilón de la fuente.
  boat,

  /// Una carretilla cargada de piedras, con su rueda.
  barrow,

  /// Un cesto lleno de flores, y las que quedan por coger en el suelo.
  flowers,
}

/// Una cosa que se hace.
class Doing {
  const Doing(
    this.id,
    this.nameEs, {
    required this.where,
    this.who = Who.anyone,
    this.weight = 1.0,
    this.sink = 0.0,
    this.bob = 0.0,
    this.rate = 1.0,
    this.lean = 0.0,
    this.wag = 0.0,
    this.turn = 1.0,
    this.prop = PropKind.none,
    this.lying = false,
    this.seated = false,
    this.hop = false,
  });

  /// Lo que se guarda si algún día se guarda. Nunca se reutiliza uno.
  final String id;

  /// Dicho en castellano, para el tablón y para los tests. Que el test diga
  /// «nadie amasa pan en el prado» y no «el doing 34 no va en el where 4» es
  /// la diferencia entre poder leer lo que falla y no.
  final String nameEs;

  /// Lo mismo en el idioma de ahora, para enseñarlo.
  String get name => inEnglish ? doingsEn[id] ?? nameEs : nameEs;

  final Where where;
  final Who who;

  /// Lo común que es. Charlar pasa mucho más que hacer malabares.
  final double weight;

  /// Cuánto se agacha: cero de pie, medio en cuclillas, uno sentado.
  final double sink;

  /// Cuánto sube y baja, y a qué ritmo. Negativo es doblar el espinazo.
  final double bob;
  final double rate;

  /// Hacia dónde se inclina. Negativo es echarse hacia atrás, que es lo que
  /// hace quien mira al cielo.
  final double lean;

  /// El vaivén lateral.
  final double wag;

  /// Cuánto gira la cabeza mirando alrededor. Cero es no moverla, que es lo
  /// que hace quien está concentrado en algo.
  final double turn;

  final PropKind prop;

  /// Tumbado del todo, no sentado. Es otra figura y no otro número: el cuerpo
  /// se acuesta, la cabeza se va a un extremo, y no hay manera de decir eso
  /// con lo agachado que está alguien.
  final bool lying;

  /// Sentado: la postura de sentarse de todos, en el suelo o en lo que haya
  /// (ver `folkSolids`). El torso, dos tercios del cuerpo, y las piernas, el
  /// otro tercio, hacia delante y del mismo color — una L. Agacharlo lo
  /// encogía, y alguien encogido se lee como más chico, no como sentado.
  final bool seated;

  /// Que sube y baja **saltando**: despega del suelo y vuelve a él, sin
  /// hundirse nunca por debajo. Es lo que hace quien salta a la comba, y no
  /// se puede decir con [bob], que sube tanto como baja.
  final bool hop;

  /// **Lo que no se lleva encima vive en su sitio.** El tocón con su leño,
  /// el tendedero, el puesto del mercado, el sillar de la obra, el caballete
  /// con su madero y las gallinas no aparecen cuando alguien se
  /// pone a ello ni se van cuando termina: están en el pueblo, en el sitio
  /// donde se hace, y quien lo hace va hasta ahí con lo que sí se lleva en la
  /// mano —el hacha, la maza, la sierra, el grano—.
  bool get anchored => _anclados.contains(prop);

  /// **Y lo que se lleva pero no cabe en un bolsillo se saca de casa.** La
  /// banqueta, el barreño y la carretilla: quien lo usa entra en su casa,
  /// sale con ello, lo lleva hasta donde lo usa, y al terminar lo vuelve a
  /// guardar.
  bool get fetched => _traidos.contains(prop);

  static const Set<PropKind> _anclados = {
    PropKind.axe,
    PropKind.line,
    PropKind.stall,
    PropKind.mallet,
    PropKind.saw,
    PropKind.hens,
  };
  static const Set<PropKind> _traidos = {
    PropKind.stool,
    PropKind.tub,
    PropKind.barrow,
  };

  /// Si esto se lo puede hacer alguien de esta edad.
  bool fits(bool kid) => switch (who) {
    Who.anyone => true,
    Who.kid => kid,
    Who.grown => !kid,
  };

  /// Quedarse mirando, que es lo que hace alguien que llega a un sitio donde
  /// todavía no hay nada escrito que hacer.
  ///
  /// No está en la tabla y no se sortea nunca: es el respaldo de un sitio
  /// vacío. Y no pretende nada — no hay objeto que no sea el objeto ni gesto
  /// que no se entienda, porque no hay gesto. Mientras la lista crece, la
  /// plaza y el pozo tienen gente parada mirando, que es honesto y es mejor
  /// que gente fingiendo hacer algo que no se ve.
  static const Doing idle = Doing(
    'quieto',
    'se queda mirando',
    where: Where.square,
    weight: 0,
    bob: 0.004,
    rate: 0.45,
    turn: 1.0,
  );

  /// Las que están bien.
  ///
  /// **Veintidós, y crece de a poco.** Hubo noventa y cuatro y se fueron todas:
  /// la mitad no se distinguía de estar quieto y la otra mitad llevaba un
  /// objeto que no era el objeto —la escoba era un palo—. Un catálogo grande
  /// de cosas que no se entienden vale menos que catorce que sí.
  ///
  /// Para entrar en esta lista hay que pasar dos cosas. Una, el expositor:
  /// mirarla de cerca, dando la vuelta, y saber qué está haciendo sin leer el
  /// nombre. Y dos, **no ser otra con otro nombre**. Hubo una siesta en la
  /// puerta y alguien mirando las nubes en el prado, y eran la misma persona
  /// tumbada con los mismos números: dos filas, un gesto. Se quedó la del
  /// prado, que es donde tumbarse se lee como tumbarse y no como caerse.
  ///
  /// Lo que distingue a una de otra no es el nombre ni el sitio: es la
  /// **silueta** y el **movimiento**. Por eso cada una tiene su objeto, y por
  /// eso ninguna repite el gesto de otra — quien pica piedra dobla el espinazo
  /// a golpes, quien sierra va de lado, quien saca agua sube y baja el
  /// caldero, y quien se tumba a mirar las nubes es el único que mira hacia
  /// arriba.
  /// El consejero, sentado en el banco de la plaza mirando el agua. No está
  /// en [all]: es suyo y de nadie más.
  static const Doing bench = Doing(
    'banco',
    'se sienta en el banco',
    where: Where.square,
    weight: 0,
    bob: 0.003,
    rate: 0.35,
    seated: true,
  );

  /// El consejero, saludando: de pie, con la mano en alto que va y viene.
  /// Sólo al llegar con la fundación, como [bench], fuera de [all].
  static const Doing greet = Doing(
    'saludar',
    'saluda',
    where: Where.square,
    weight: 0,
    bob: 0.006,
    rate: 2.2,
  );

  static const List<Doing> all = [
    // ------------------------------------------------------ en su propia puerta
    Doing(
      'barrer',
      'barre el umbral',
      where: Where.door,
      weight: 1.2,
      bob: 0.010,
      rate: 1.5,
      wag: 0.022,
      lean: 0.045,
      turn: 0.15,
      prop: PropKind.broom,
    ),
    Doing(
      'sentarse',
      'se sienta en una banqueta',
      where: Where.door,
      weight: 1.6,
      bob: 0.005,
      rate: 0.45,
      lean: -0.02,
      turn: 0.7,
      prop: PropKind.stool,
      seated: true,
    ),

    Doing(
      'tender',
      'tiende la ropa',
      where: Where.door,
      weight: 1.1,
      bob: 0.016,
      rate: 0.7,
      lean: 0.02,
      turn: 0.2,
      prop: PropKind.line,
    ),

    Doing(
      'lena',
      'parte leña',
      where: Where.door,
      who: Who.grown,
      weight: 1.2,
      bob: -0.020,
      rate: 1.3,
      lean: 0.03,
      turn: 0.0,
      prop: PropKind.axe,
    ),
    Doing(
      'gallinas',
      'echa de comer a las gallinas',
      where: Where.door,
      weight: 1.1,
      bob: 0.006,
      rate: 1.1,
      wag: 0.010,
      lean: 0.04,
      turn: 0.35,
      prop: PropKind.hens,
    ),

    // ---------------------------------------------------------------- la plaza
    Doing(
      'laud',
      'toca el laúd',
      where: Where.square,
      weight: 0.9,
      bob: 0.006,
      rate: 1.2,
      wag: 0.030,
      lean: 0.02,
      turn: 0.3,
      prop: PropKind.lute,
    ),
    Doing(
      'puesto',
      'atiende el puesto',
      where: Where.square,
      who: Who.grown,
      weight: 1.4,
      bob: 0.005,
      rate: 0.5,
      lean: 0.035,
      turn: 0.6,
      prop: PropKind.stall,
    ),

    Doing(
      'malabares',
      'hace malabares',
      where: Where.square,
      weight: 0.8,
      bob: 0.008,
      rate: 2.6,
      lean: -0.03,
      turn: 0.0,
      prop: PropKind.balls,
    ),
    Doing(
      'tambor',
      'toca el tambor',
      where: Where.square,
      weight: 0.8,
      bob: 0.010,
      rate: 3.4,
      lean: 0.01,
      turn: 0.25,
      prop: PropKind.drum,
    ),
    Doing(
      'comba',
      'salta a la comba',
      where: Where.square,
      who: Who.kid,
      weight: 1.0,
      bob: 0.110,
      rate: 2.6,
      turn: 0.0,
      prop: PropKind.rope,
      hop: true,
    ),
    // En el pilón de la fuente de la plaza, que es el agua que de verdad está
    // ahí: el barco sale del bolsillo y el agua no la trae nadie.
    Doing(
      'barquito',
      'echa un barco de papel',
      where: Where.square,
      who: Who.kid,
      // Un crío que llega a la fuente con un barco de papel en el bolsillo es
      // de lo que más se ve en una plaza.
      weight: 1.6,
      // De pie y asomado: el brocal del pilón le llega a la barbilla a un
      // crío, y de rodillas no vería el agua.
      bob: 0.005,
      rate: 0.8,
      lean: 0.10,
      turn: 0.1,
      prop: PropKind.boat,
    ),

    // ------------------------------------------------------------- donde hay agua
    Doing(
      'pozo',
      'saca agua',
      where: Where.water,
      who: Who.grown,
      weight: 1.5,
      bob: -0.045,
      rate: 0.9,
      lean: 0.05,
      turn: 0.0,
      prop: PropKind.pail,
    ),
    Doing(
      'lavar',
      'lava la ropa',
      where: Where.water,
      weight: 1.4,
      sink: 0.72,
      bob: 0.012,
      rate: 2.2,
      wag: 0.014,
      lean: 0.05,
      turn: 0.05,
      prop: PropKind.tub,
    ),
    Doing(
      'pescar',
      'pesca',
      where: Where.water,
      weight: 1.2,
      bob: 0.004,
      rate: 0.35,
      turn: 0.08,
      prop: PropKind.rod,
      seated: true,
    ),

    // ------------------------------------------------------------ al pie de la obra
    Doing(
      'cantero',
      'pica piedra',
      where: Where.work,
      who: Who.grown,
      weight: 1.5,
      bob: -0.050,
      rate: 1.9,
      lean: 0.06,
      turn: 0.0,
      prop: PropKind.mallet,
    ),
    Doing(
      'serrar',
      'sierra un madero',
      where: Where.work,
      weight: 1.3,
      bob: 0.006,
      rate: 2.4,
      wag: 0.045,
      lean: 0.04,
      turn: 0.0,
      prop: PropKind.saw,
    ),

    Doing(
      'carretilla',
      'empuja la carretilla',
      where: Where.work,
      who: Who.grown,
      weight: 1.2,
      bob: 0.010,
      rate: 1.4,
      lean: 0.07,
      turn: 0.0,
      prop: PropKind.barrow,
    ),

    // ---------------------------------------------------------------- el prado
    Doing(
      'segar',
      'siega',
      where: Where.meadow,
      who: Who.grown,
      weight: 1.3,
      bob: -0.028,
      rate: 0.9,
      wag: 0.060,
      lean: 0.05,
      turn: 0.0,
      prop: PropKind.scythe,
    ),
    Doing(
      'leer',
      'lee',
      where: Where.meadow,
      weight: 1.4,
      bob: 0.004,
      rate: 0.55,
      lean: 0.030,
      turn: 0.1,
      prop: PropKind.book,
      seated: true,
    ),
    Doing(
      'nubes',
      'se tumba a mirar las nubes',
      where: Where.meadow,
      weight: 1.5,
      bob: 0.008,
      rate: 0.35,
      turn: 0.0,
      lying: true,
    ),
    Doing(
      'flores',
      'coge flores',
      where: Where.meadow,
      weight: 1.1,
      sink: 0.50,
      bob: -0.030,
      rate: 0.9,
      lean: 0.05,
      turn: 0.1,
      prop: PropKind.flowers,
    ),
  ];
}
