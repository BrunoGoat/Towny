/// Lo que sabe el consejero: lo que dice, los consejos, y cuándo da cada uno.
///
/// El consejero es el viejo de la barba que anda por la plaza (ver
/// `Townsfolk.sage`). No tiene casa ni oficio. Tiene tiempo, y mira: sabe
/// cuándo pusiste la primera piedra y cuándo faltaste, y habla de eso.
///
/// **Habla como alguien, no como un menú.** Cada consejo tiene dos partes: lo
/// que dice él —corto, una imagen, a veces un acertijo— y debajo lo que
/// quiere decir, en llano, para que se pueda hacer. Lo primero es lo que se
/// recuerda; lo segundo, lo que sirve.
///
/// **Y pregunta antes de hablar.** No es lo mismo sembrar algo que arrancar
/// algo: quien quiere empezar a leer necesita un lugar y una hora; quien
/// quiere dejar de fumar necesita saber qué lo dispara y qué poner en el
/// hueco. Así que lo primero que hace es preguntar ([SageLines.question]), y
/// según la respuesta sigue un camino de consejos o el otro ([pathFor]).
///
/// **De a uno, y no la lista entera.** Se ganan: uno por cada día que entrás
/// —sin acumularse los días que no— y algunos cuando pasa algo que los vuelve
/// oportunos. Ver `AdviceBook`.
///
/// **Y sólo entran los que su autor aprobó** ([approvedAdvice]): lo de acá es
/// el borrador.
library;

import '../l10n/lang.dart';

/// Lo que se busca con un hábito.
enum AdviceGoal {
  /// Empezar un buen hábito: leer, correr, dormir temprano.
  start,

  /// Dejar un mal hábito: fumar, mirar el teléfono
  /// en la cama.
  quit,
}

/// Qué tiene que pasar para que el consejero diga algo.
enum AdviceEvent {
  /// La primera pieza del pueblo.
  firstPiece,

  /// Este pueblo no es el primero: ya hay uno más viejo en el valle.
  secondTown,

  /// Siete días distintos con alguna pieza.
  week,

  /// Treinta.
  month,

  /// Un día sin pieza en medio de otros con pieza.
  missedDay,

  /// Volviste después de tres días o más sin aparecer.
  comeback,

  /// Escribiste en el tablón a qué hora o en qué sitio lo hacés.
  plan,

  /// Clavaste una nota tuya.
  ownNote,

  /// Pusiste a dormir el pueblo.
  rested,

  /// Cien piezas.
  hundred,

  /// Antes del primer pueblo, en la presentación: no lo gana nada que pase,
  /// lo da él al presentarse. Ver [prologueAdvice].
  prologue,
}

/// Un consejo: lo que dice él, y lo que quiere decir.
class Advice {
  const Advice(
    this.id,
    this.sayEs,
    this.meanEs,
    this.sayEn,
    this.meanEn, {
    this.event,
    this.goal,
  });

  /// Para acordarse de cuáles ya se ganaron. No cambia nunca.
  final String id;

  /// Lo que dice él, y lo que quiere decir, en los dos idiomas.
  final String sayEs, meanEs, sayEn, meanEn;

  /// Lo que lo gana. Nulo es que va en el camino de uno por día.
  final AdviceEvent? event;

  /// Para quién es: para quien siembra, para quien arranca, o nulo para los
  /// dos.
  final AdviceGoal? goal;

  String get say => inEnglish ? sayEn : sayEs;
  String get mean => inEnglish ? meanEn : meanEs;
}

/// Lo que dice el consejero fuera de los consejos: cómo saluda, la pregunta
/// del principio y lo que contesta.
class SageLines {
  SageLines._();

  /// La primera vez que se le habla: se presenta, de a un globo por vez,
  /// antes de preguntar nada. Como el guía de los juegos que te reciben.
  static List<String> get intro => [
    tr(
      'Te doy la bienvenida al valle. Pasa, pasa… aquí nadie corre, ni '
          'siquiera el agua.',
      'Welcome to the valley. Come in, come in… nobody runs here, not even '
          'the water.',
    ),
    tr(
      'Soy el consejero. Llevo en esta plaza más años que sus piedras, '
          'mirando cómo crecen los pueblos.',
      'I am the advisor. I have sat in this square longer than its stones, '
          'watching towns grow.',
    ),
    tr(
      'Vengo a ayudarte a conseguir lo que te propongas: a empezar lo bueno '
          'y a dejar lo que hace daño. Una palabra cada día, cuando estés '
          'listo para oírla.',
      'I am here to help you reach what you set out to do: to start what is '
          'good and to leave what harms you. One word each day, when you are '
          'ready to hear it.',
    ),
  ];

  /// La pregunta, una vez por pueblo: qué se quiere hacer con este hábito.
  /// Directa, sin metáforas: empezar o dejar.
  static String get question => tr(
    'Primero, dime: con este pueblo, ¿quieres empezar un buen hábito, o '
        'dejar uno malo?',
    'First, tell me: with this town, do you want to start a good habit, or '
        'leave a bad one?',
  );

  /// La misma, en un pueblo nuevo, a quien ya lo conoce.
  static String get questionAgain => tr(
    'Un pueblo nuevo… Dime: aquí, ¿quieres empezar un buen hábito, o dejar '
        'uno malo?',
    'A new town… Tell me: here, do you want to start a good habit, or leave '
        'a bad one?',
  );

  /// Las dos respuestas.
  static String get answerStart =>
      tr('Empezar un buen hábito', 'Start a good habit');
  static String get answerQuit =>
      tr('Dejar un mal hábito', 'Leave a bad habit');

  /// Lo que dice después de cada una.
  static String get afterStart => tr(
    'Un buen hábito es una semilla. Las semillas no tienen prisa, y quien '
        'las siembra tampoco debería. Cada día traerá una palabra para que '
        'crezca.',
    'A good habit is a seed. Seeds don’t hurry, and neither should whoever '
        'sows them. Each day will bring a word to help it grow.',
  );
  static String get afterQuit => tr(
    'Un mal hábito es una raíz torcida. No sale de un tirón: se afloja poco '
        'a poco. Cada día traerá una palabra para aflojarla.',
    'A bad habit is a crooked root. It doesn’t come out in one pull: it '
        'loosens little by little. Each day will bring a word to loosen it.',
  );

  /// Cuando ya dijo lo de hoy y se le vuelve a hablar.
  static String get nothingNew => tr(
    'Por hoy ya está dicho lo que había que decir. El resto lo dirá el día.',
    'For today, what had to be said is said. The day will say the rest.',
  );

  /// Cuando tiene algo para dar: antes de darlo, pregunta.
  static String get ready => tr(
    'Hoy el viento trajo una palabra para ti. ¿Quieres oírla?',
    'Today the wind brought a word for you. Will you hear it?',
  );

  /// Y si ya dio una y tiene otra.
  static String get readyOther => tr(
    'Hay algo más que el día dejó para ti. ¿Quieres oírlo?',
    'There is something more the day left for you. Will you hear it?',
  );

  static String get yes => tr('Sí, dime', 'Yes, tell me');
  static String get notNow => tr('Todavía no', 'Not yet');

  /// Lo que dice si se le contesta que todavía no.
  static String get notYet => tr(
    'Esperará. Las palabras no se pudren: maduran.',
    'It will wait. Words don’t rot: they ripen.',
  );
}

/// Lo que dice el viejo la primera vez, en el valle vacío, antes de fundar el
/// primer pueblo: cómo funciona todo, de a un globo. Entre medio da dos
/// consejos de verdad —[prologueAdvice]—, para que se vea cómo es eso de
/// recibir uno, y al final queda el botón para fundar.
class SagePrologue {
  SagePrologue._();

  /// Lo que dice antes de los consejos.
  static List<String> get opening => [
    tr(
      'Te doy la bienvenida al valle. Pasa, pasa… aquí nadie corre, ni '
          'siquiera el agua.',
      'Welcome to the valley. Come in, come in… nobody hurries here, not '
          'even the water.',
    ),
    tr(
      'Soy el consejero. Llevo en este valle más años que sus piedras, '
          'mirando cómo nacen y crecen los pueblos.',
      'I am the advisor. I have been in this valley longer than its stones, '
          'watching towns be born and grow.',
    ),
    tr(
      'Aquí cada pueblo es un hábito. Tú lo fundas, y crece con lo que haces '
          'de verdad: cada día que cumples lo que te propusiste, pones una '
          'pieza.',
      'Here every town is a habit. You found it, and it grows with what you '
          'really do: each day you keep what you set out to do, you place a '
          'piece.',
    ),
    tr(
      'No cuentes los días sin pieza. El valle no castiga ni lleva la cuenta '
          'de lo que falta. Lo único que pide es que vuelvas, aunque sea un '
          'momento cada día.',
      'Don’t count the days without a piece. The valley doesn’t punish, and '
          'it keeps no tally of what is missing. All it asks is that you come '
          'back, even for a moment, every day.',
    ),
    // En dos globos: entero no entraba en el de un teléfono chico.
    tr(
      'Cada vez que vengas, el viento me traerá una palabra para ti.',
      'Each time you come, the wind will bring me a word for you.',
    ),
    tr(
      'Y si algo se tuerce, un día que no pudiste o un ritmo que te queda '
          'grande, dímelo. Juntos enderezamos el camino.',
      'And if something goes crooked, a day you couldn’t or a pace too big '
          'for you, tell me. Together we will straighten the path.',
    ),
    tr(
      'Muchos llegan aquí cansados de intentarlo. Antes de fundar nada, '
          'escucha esto.',
      'Many arrive here tired of trying. Before you found anything, listen '
          'to this.',
    ),
  ];

  /// Entre el primer consejo y el segundo.
  static String get between =>
      tr('Y una más, para el camino.', 'And one more, for the road.');

  /// Lo último, en dos globos: el botón sale con el segundo. Uno solo no
  /// entraba en el globo de un teléfono chico.
  static List<String> get closing => [
    tr(
      'Cuando estés listo, funda tu primer pueblo.',
      'When you are ready, found your first town.',
    ),
    tr(
      'Elige con calma: no lo que más te pesa, sino lo que de verdad puedas '
          'mantener. Primero se gana confianza.',
      'Choose calmly: not what weighs on you most, but what you can truly '
          'keep. First you build confidence.',
    ),
  ];

  /// El botón que queda abajo al terminar, en vez de «mantener».
  static String get found =>
      tr('FUNDAR MI PRIMER PUEBLO', 'FOUND MY FIRST TOWN');
}

/// Los dos consejos de la presentación, en el orden en que los da: el de
/// empezar por lo que se puede sostener, y el de empezar chico. Ya quedan
/// ganados y leídos al fundar el primer pueblo, y no cuentan como el consejo
/// del día: ese mismo día, con el pueblo fundado, el viejo tiene uno nuevo.
const List<String> prologueAdvice = ['herreria', 'chico'];

/// Los consejos de todos los días. El orden en que se ganan lo da [pathFor].
const List<Advice> dailyAdvice = [
  // ------------------------------------------------- para quien siembra
  Advice(
    'lugar',
    'Cada semilla necesita su rincón de tierra.',
    'Elige un lugar solo para esto. Que no sea donde duermes ni donde comes. Así, cuando estés ahí, tu cabeza ya sabe qué toca hacer.',
    'Every seed needs its own patch of earth.',
    'Choose a place just for this. Not where you sleep or where you eat. That way, when you are there, your mind already knows what comes next.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'hora',
    'El sol no pregunta si tiene ganas de salir.',
    'Dale una hora fija. La decisión la tomas una sola vez, el día que eliges la hora. Después, cada día solo queda cumplirla.',
    'The sun doesn’t ask whether it feels like rising.',
    'Give it a fixed time. You make the decision only once, the day you choose the time. After that, each day you just keep it.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'chico',
    'El roble más grande fue una bellota que no se rindió.',
    'Empieza muy pequeño, una página, dos minutos. Algo tan chico lo cumples hasta en el peor día. Primero te acostumbras a aparecer, lo grande viene después.',
    'The tallest oak was an acorn that didn’t give up.',
    'Start very small, one page, two minutes. Something that small you can do even on your worst day. First you get used to showing up, the big things come later.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'vista',
    'El camino que se ve es el que se anda.',
    'Deja a la vista lo que necesitas: las zapatillas junto a la puerta, el libro sobre la almohada. Verlo te lo recuerda sin que tengas que pensar.',
    'The path you can see is the path you walk.',
    'Leave what you need in plain sight: your shoes by the door, the book on the pillow. Seeing it reminds you without you having to think.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'dosminutos',
    'La rueda cuesta en el primer giro. Después gira sola.',
    'No te propongas hacerlo entero. Proponte solo empezar. Lo que más cuesta es arrancar, y una vez en marcha seguir cuesta mucho menos, así que casi siempre terminas haciendo más de lo que pensabas.',
    'The wheel is hard on the first turn. After that it turns on its own.',
    'Don’t set out to do all of it. Set out only to begin. Starting is what costs the most, and once you’re going, keeping on costs much less, so you almost always end up doing more than you planned.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'preparar',
    'Quien deja el farol encendido no busca la puerta a oscuras.',
    'Deja todo listo antes: la ropa doblada, el libro abierto en la página. Cada cosa que falta preparar es una excusa para no empezar. Si ya está todo listo, solo queda hacerlo.',
    'Who leaves the lantern lit doesn’t grope for the door in the dark.',
    'Get everything ready beforehand: clothes folded, the book open at the page. Every thing left to prepare is an excuse not to start. If it’s all ready, all that’s left is to do it.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'quiendecide',
    'Que decida quien traza el camino, no quien tropieza en él.',
    'Decide en calma, el día antes, qué harás y cuándo. Quien despierta con '
        'sueño no debe pensar ni elegir: solo seguir el plan que dejó tu mejor '
        'versión.',
    'Let the one who draws the path decide, not the one who stumbles on it.',
    'Decide calmly, the day before, what you will do and when. Whoever wakes '
        'up sleepy should not think or choose: only follow the plan your best '
        'self left behind.',
  ),
  Advice(
    'estorbos',
    'Lo que está a un paso se hace. Lo que está a diez, se piensa.',
    'Quita los pasos que hay antes de empezar: si entre tú y el hábito hay tres, que quede uno. Cada paso de más es un momento para dudar, y con menos pasos hay menos ocasiones de echarse atrás.',
    'What is one step away gets done. What is ten steps away gets thought about.',
    'Remove the steps before you start: if there are three between you and the habit, make it one. Every extra step is a moment to hesitate, and with fewer steps there are fewer chances to back out.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'gusto',
    'El viajero repite el camino que pasa por la panadería.',
    'Júntalo con algo que te guste: tu música favorita solo mientras caminas, tu té preferido solo mientras estudias. Así tu cabeza lo asocia con algo bueno, y lo que se asocia con algo bueno se busca solo.',
    'The traveller takes again the road that passes the bakery.',
    'Pair it with something you enjoy: your favourite music only while you walk, your favourite tea only while you study. That way your mind links it to something good, and what is linked to something good gets sought out on its own.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'mismo',
    'El que siempre entra por la misma puerta no se pierde en la casa.',
    'Empieza siempre con el mismo gesto: prender la misma luz, servirte el mismo té. Después de unas veces ese gesto avisa solo, y el cuerpo arranca antes de que tengas que pensarlo.',
    'Whoever always comes in through the same door doesn’t get lost in the house.',
    'Always begin with the same gesture: switching on the same light, pouring the same tea. After a few times that gesture gives the signal by itself, and your body gets going before you have to think about it.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'plan',
    'Una intención es una nube. Una cita es una piedra.',
    '«Algún día» no llega nunca. Escribe el plan entero: «haré esto, a esta hora, en este lugar». Un plan escrito ya está decidido, así que cuando llega el momento no hay nada que pensar, solo cumplirlo.',
    'An intention is a cloud. An appointment is a stone.',
    '“Someday” never comes. Write the whole plan: “I will do this, at this time, in this place.” A written plan is already decided, so when the moment comes there’s nothing to think about, just keep it.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'subir',
    'El arquero aleja el blanco cuando ya da en el centro.',
    'Cuando lo chico ya no te cueste, súmale un poco. Un poco, no el doble. Si lo agrandas de golpe vuelve a costar arrancar, y lo que tiene que seguir siendo fácil es empezar.',
    'The archer moves the target back once he hits the centre.',
    'When the small version no longer costs you, add a bit. A bit, not double. If you make it bigger all at once, starting gets hard again, and starting is what has to stay easy.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'mananas',
    'El que siembra al alba no compite con el día.',
    'Si puedes, hazlo temprano. A la mañana todavía no pasó nada: no hay cansancio, ni imprevistos, ni otros planes. Cuanto más avanza el día, más cosas se meten en el medio.',
    'Whoever sows at dawn doesn’t compete with the day.',
    'If you can, do it early. In the morning nothing has happened yet: no tiredness, no surprises, no other plans. The further the day goes, the more things get in the way.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'mismodia',
    'Quien suelta el día porque se le cayó la hora, tira la canasta por una manzana.',
    'Si se te pasó la hora, no des el día por perdido. Hazlo igual, más tarde y más chico, pero hoy. Lo que sostiene la costumbre es no saltear el día, no la hora exacta.',
    'Whoever drops the day because the hour fell throws away the basket for one apple.',
    'If the time slipped by, don’t give the day up for lost. Do it anyway, later and smaller, but today. What holds the habit up is not skipping the day, not the exact time.',
    goal: AdviceGoal.start,
  ),

  // -------------------------------------------------- para quien arranca
  Advice(
    'q_disparador',
    'Antes del humo, siempre hay una chispa.',
    'Observa lo que ocurre justo antes: la hora, el lugar, la gente, el aburrimiento. Esa chispa es lo que hay que vigilar, no el humo.',
    'Before the smoke there is always a spark.',
    'Notice what happens just before: the time, the place, the people, the boredom. That spark is what to watch, not the smoke.',
    goal: AdviceGoal.quit,
  ),
  Advice(
    'q_invisible',
    'Lo que no se ve, no llama.',
    'Sácalo de la vista: que no esté en la casa, borra la aplicación, cambia el camino que pasa por delante.',
    'What isn’t seen doesn’t call.',
    'Get it out of sight: keep it out of the house, delete the app, change the route that goes past it.',
    goal: AdviceGoal.quit,
  ),
  Advice(
    'sustituir',
    'La oscuridad no se echa a empujones: se enciende una vela.',
    'Un mal hábito no se arranca: se le quita el sitio. No pelees contra él; '
        'pon algo mejor en su lugar, una y otra vez, hasta que el viejo ya no '
        'encuentre dónde sentarse.',
    'Darkness isn’t pushed out of a room: you light a candle.',
    'A bad habit can’t be torn out: it can only lose its seat. Don’t fight '
        'it; put something better in its place, again and again, until the '
        'old one finds nowhere left to sit.',
    goal: AdviceGoal.quit,
  ),
  Advice(
    'reemplazo',
    'El hueco que deja una raíz se llena de algo. Que seas tú quien elija de qué.',
    'Decide qué harás en su lugar cuando llegue el momento: un vaso de agua, una vuelta a la manzana, cinco respiraciones.',
    'The hole a root leaves fills with something. You choose what.',
    'Decide what you’ll do instead when the moment comes: a glass of water, a walk round the block, five breaths.',
    goal: AdviceGoal.quit,
  ),
  Advice(
    'q_ola',
    'Las ganas son una ola: suben, rompen y se van.',
    'Cuando llegue el antojo, no luches: espera diez minutos. Casi siempre se va solo.',
    'Cravings are a wave: they rise, they break, they go.',
    'When the craving comes, don’t fight it: wait ten minutes. It almost always passes on its own.',
    goal: AdviceGoal.quit,
  ),
  Advice(
    'q_dificil',
    'Pon piedras en el camino que no quieres andar.',
    'Hazlo difícil: más lejos, más pasos, más tiempo. Lo que cuesta se hace menos.',
    'Put stones on the path you don’t want to walk.',
    'Make it hard: further away, more steps, more time. What costs more gets done less.',
    goal: AdviceGoal.quit,
  ),
  Advice(
    'q_identidad',
    'No digas «lo estoy dejando». Di «yo no».',
    '«No fumo» en lugar de «intento no fumar». Quien lo intenta aún es el de antes; quien no lo hace ya es otro.',
    'Don’t say “I’m quitting.” Say “I don’t.”',
    '“I don’t smoke” instead of “I’m trying not to smoke.” Whoever is trying is still the old one; whoever doesn’t is someone else already.',
    goal: AdviceGoal.quit,
  ),
  Advice(
    'q_lugares',
    'Hay sitios donde la raíz se agarra más fuerte.',
    'Los lugares y la gente que acompañan al hábito, evítalos un tiempo. No para siempre: hasta que la raíz afloje.',
    'There are places where the root holds tighter.',
    'Avoid the places and people that go with the habit for a while. Not forever: until the root loosens.',
    goal: AdviceGoal.quit,
  ),
  Advice(
    'q_costo',
    'Quien no mira la cuenta la paga dos veces.',
    'Haz visible lo que te cuesta: el dinero, el sueño, el tiempo. Escríbelo donde lo veas.',
    'Who doesn’t look at the bill pays it twice.',
    'Make what it costs you visible: the money, the sleep, the time. Write it where you’ll see it.',
    goal: AdviceGoal.quit,
  ),
  Advice(
    'q_sed',
    'Quien tiene sed bebe de cualquier charco.',
    'A menudo el hábito tapa otra cosa: cansancio, nervios, soledad. Atiende esa sed y el charco dejará de llamar.',
    'Whoever is thirsty drinks from any puddle.',
    'Often the habit covers something else: tiredness, nerves, loneliness. Tend to that thirst, and the puddle stops calling.',
    goal: AdviceGoal.quit,
  ),
  Advice(
    'q_primeros',
    'El río golpea más fuerte cerca de la cascada.',
    'Los primeros días son los peores. Después la corriente afloja: no siempre será así de difícil.',
    'The river hits hardest near the waterfall.',
    'The first days are the worst. Then it eases: it won’t always be this hard.',
    goal: AdviceGoal.quit,
  ),
  Advice(
    'q_recaida',
    'Un tropiezo no es el camino.',
    'Si caíste, no lo tires todo. La próxima vez que llegue el momento, elige distinto. Solo eso importa.',
    'A stumble is not the path.',
    'If you slipped, don’t throw it all away. Next time the moment comes, choose differently. That’s all that matters.',
    goal: AdviceGoal.quit,
  ),

  // ------------------------------------------------------- para los dos
  Advice(
    'nodosveces',
    'El charco no nace de una gota, nace de la que viene detrás.',
    'Faltar un día le pasa a cualquiera y no rompe nada. El hábito sigue vivo. Pero dos días seguidos ya empiezan a armar una costumbre nueva, la de no hacerlo. Si fallaste ayer, hoy hazlo aunque sea chiquito.',
    'The puddle isn’t born from one drop, it’s born from the one that comes after.',
    'Missing a day happens to anyone and breaks nothing. The habit is still alive. But two days in a row start building a new custom, the one of not doing it. If you missed yesterday, do it today, even if it’s tiny.',
  ),
  Advice(
    'diamalo',
    'En los días de sequía, el río se hace hilo, pero no deja de correr.',
    'Hay días en que no da para todo, y eso no es fallar. Decide ahora cuál es la versión mínima que cuenta, así ese día no tienes que pensarlo. Hacer poco mantiene viva la costumbre, y lo que está vivo vuelve a crecer.',
    'In days of drought the river becomes a thread, but it never stops running.',
    'Some days there isn’t room for all of it, and that isn’t failing. Decide now what the smallest version that counts is, so on that day you don’t have to think about it. Doing a little keeps the habit alive, and what is alive grows back.',
  ),
  Advice(
    'ganas',
    'El fuego no espera calor para encenderse: el calor viene del fuego.',
    'No esperes a tener ganas para empezar. Las ganas se despiertan con el movimiento, así que casi siempre llegan después de arrancar y casi nunca antes.',
    'Fire doesn’t wait for warmth to light: the warmth comes from the fire.',
    'Don’t wait to feel like it before you start. The wanting wakes up with the moving, so it almost always comes after you begin and almost never before.',
  ),
  Advice(
    'identidad',
    'Cada piedra que pones dice quién vive en la casa.',
    'Cuando lo haces por ser alguien, y no solo por llegar a algo, sostenerlo cuesta menos. Cada pieza es un voto por quien quieres ser. No digas «intento leer». Di «soy alguien que lee».',
    'Every stone you lay says who lives in the house.',
    'When you do it to be someone, not just to get somewhere, keeping it up costs less. Every piece is a vote for who you want to be. Don’t say “I’m trying to read.” Say “I’m someone who reads.”',
  ),
  Advice(
    'tentacion',
    'El que no quiere mojarse no camina bajo la cascada.',
    'No es falta de voluntad. Nadie le gana a algo que tiene al lado todo el día, porque la voluntad se cansa y la distracción no. Aleja lo que te distrae: el teléfono en otro cuarto, la tele apagada. Lo que no está cerca no tienta.',
    'Whoever doesn’t want to get wet doesn’t walk under the waterfall.',
    'It isn’t a lack of willpower. Nobody beats something sitting next to them all day, because willpower tires and the distraction doesn’t. Put what distracts you out of reach: the phone in another room, the TV off. What isn’t close doesn’t tempt.',
  ),
  Advice(
    'mirar',
    'Las huellas detrás de ti dicen más que las promesas delante.',
    'Cuando dudes de si puedes, da un paseo por tu pueblo. Cada pieza es un día que cumpliste. Lo que ya hiciste convence más que cualquier ánimo, porque no es una idea, es una prueba.',
    'The footprints behind you say more than the promises ahead.',
    'When you doubt you can, take a walk round your town. Every piece is a day you kept. What you’ve already done convinces more than any pep talk, because it isn’t an idea, it’s proof.',
  ),
  Advice(
    'aburrido',
    'El pan de cada día no tiene gusto a fiesta, y por eso alimenta.',
    'Que se vuelva aburrido es buena señal: quiere decir que ya es costumbre. Ahí es donde casi todos lo dejan, buscando algo nuevo. Quien sigue aunque no tenga gracia es el que se queda con el hábito.',
    'Daily bread doesn’t taste like a feast, and that’s why it feeds you.',
    'Getting boring is a good sign: it means it’s already a habit. That’s where almost everyone drops it, looking for something new. Whoever keeps going even when it’s dull is the one who keeps the habit.',
  ),
  Advice(
    'unoalavez',
    'Atrapa un conejo, y el bosque te enseña a atrapar el siguiente.',
    'Con ganas, dan ganas de cambiar la vida entera de una vez. Pero cambiarlo todo de golpe es la manera más segura de no cambiar nada. Por eso en el valle los pueblos se ganan de a poco: cada uno llega cuando el anterior ya está firme, y con lo que aprendiste en él.',
    'Catch one rabbit, and the forest teaches you to catch the next.',
    'When you’re fired up, you want to change your whole life at once. But changing everything in one go is the surest way to change nothing. That’s why towns in the valley are earned little by little: each one comes when the last is solid, with what you learned there.',
  ),
  Advice(
    'nomedir',
    'La luna no brilla entera cada noche, pero sale siempre.',
    'Al principio no importa cuánto hagas. Importa que ese día lo hiciste. Lo que se repite se vuelve costumbre, aunque sea poco, y una vez que es costumbre agrandarlo es fácil.',
    'The moon doesn’t shine full every night, but it always rises.',
    'At first it doesn’t matter how much you do. What matters is that you did it that day. What repeats becomes habit, however small, and once it is a habit, making it bigger is easy.',
  ),
  Advice(
    'viajes',
    'El sabio arregla el techo cuando hay sol.',
    'Los hábitos no se caen en los días comunes, se caen en los raros: un viaje, una visita, una fiesta. Piensa antes cómo lo harás ese día, aunque sea más chico. Si ya lo tienes decidido, el día raro no te saca del camino.',
    'The wise mend the roof while the sun shines.',
    'Habits don’t fall on ordinary days, they fall on odd ones: a trip, a visit, a party. Think ahead about how you’ll do it that day, even if it’s smaller. If it’s already decided, the odd day doesn’t knock you off the path.',
  ),
  Advice(
    'paciencia',
    'El que riega el bambú sin verlo crecer es el que lo ve llegar al cielo.',
    'Un hábito tarda más de lo que crees en sentirse natural, a veces meses. Los primeros días cuesta igual que siempre, pero por dentro ya está echando raíces. No es que no te salga: es que todavía se está haciendo.',
    'Whoever waters the bamboo without seeing it grow is the one who sees it reach the sky.',
    'A habit takes longer than you think to feel natural, sometimes months. The first days cost the same as always, but inside it’s already putting down roots. It isn’t that you can’t: it’s still being made.',
  ),
  Advice(
    'porque',
    'Quien mira la estrella no cuenta las piedras del camino.',
    'Los días difíciles las ganas no alcanzan, pero un motivo claro sí. Cuando recuerdas para qué lo haces, el esfuerzo deja de ser un castigo y pasa a ser un precio que vale la pena. Escribe en una línea por qué empezaste. El día que lo olvides, léela.',
    'Whoever watches the star doesn’t count the stones on the road.',
    'On hard days wanting it isn’t enough, but a clear reason is. When you remember what you do it for, the effort stops being a punishment and becomes a price worth paying. Write in one line why you began. On the day you can’t remember, read it.',
  ),
  Advice(
    'perfecto',
    'La flor no espera a ser perfecta para abrirse.',
    'Esperar a hacerlo perfecto es otra forma de no hacerlo. Un día flojo igual cuenta, porque lo que forma la costumbre es repetir, no lucirse. Hazlo como salga hoy, y mañana sale un poco mejor.',
    'The flower doesn’t wait to be perfect to open.',
    'Waiting to do it perfectly is another way of not doing it. A weak day still counts, because what builds the habit is repeating, not showing off. Do it however it comes out today, and tomorrow it comes out a little better.',
  ),
  Advice(
    'descanso',
    'La posada no termina el viaje: lo deja seguir.',
    'Si necesitas parar, para a propósito y con fecha de vuelta. Una pausa elegida no es abandonar, porque sabes cuándo vuelves. Lo que rompe un hábito no es el descanso, es dejarlo de a poco sin decidirlo.',
    'The inn doesn’t end the journey: it lets it go on.',
    'If you need to stop, stop on purpose and with a date to return. A chosen pause isn’t giving up, because you know when you’ll be back. What breaks a habit isn’t resting, it’s letting it slip bit by bit without deciding to.',
  ),
  Advice(
    'orgullo',
    'El herrero levanta la espada a la luz antes de apagar la fragua.',
    'Cuando termines, tómate un segundo para decirte «hoy lo hice», aunque haya sido poco. Esa pequeña alegría es lo que tu cabeza recuerda, y lo que se recuerda con gusto se quiere repetir.',
    'The smith holds the sword up to the light before putting out the forge.',
    'When you finish, take a second to tell yourself “I did it today,” even if it was little. That small joy is what your mind remembers, and what is remembered fondly wants repeating.',
  ),
  Advice(
    'compromiso',
    'La barca atada al muelle no se la lleva la marea.',
    'Átate a algo de afuera: queda con alguien a una hora, paga la clase por adelantado. No se trata de contarlo, se trata de que algo te espere. Fallarte a ti mismo es fácil, porque nadie lo nota. Dejar plantado a otro, o perder lo que ya pagaste, cuesta mucho más.',
    'The boat tied to the pier isn’t carried off by the tide.',
    'Tie yourself to something outside you: arrange to meet someone at a set time, pay for the class in advance. It isn’t about telling people, it’s about something waiting for you. Letting yourself down is easy, because nobody notices. Standing someone up, or losing what you already paid, costs much more.',
  ),
  Advice(
    'nojuzgar',
    'Quien se castiga por caer aprende a no levantarse.',
    'Si fallaste, no te retes. La culpa no te hace volver, te hace evitar el tema, y lo que se evita se abandona. Mira qué pasó, cambia algo chico y sigue.',
    'Who punishes themselves for falling learns not to get up.',
    'If you slipped, don’t scold yourself. Guilt doesn’t bring you back, it makes you avoid the subject, and what you avoid you abandon. See what happened, change something small and carry on.',
  ),
  Advice(
    'raices',
    'El jardinero no deja de regar porque el árbol ya creció.',
    'Cuando ya lo haces sin pensarlo, parece que está asegurado, y ahí muchos se confían y lo sueltan. Pero una costumbre se sostiene igual que se hizo: haciéndola. Sigue cuidándola, aunque ya no cueste.',
    'The gardener doesn’t stop watering because the tree has grown.',
    'Once you do it without thinking, it seems secure, and that’s when many get complacent and let go. But a habit is kept up the same way it was built: by doing it. Keep looking after it, even when it no longer costs you.',
  ),
  Advice(
    'enseñar',
    'El maestro herrero sabe por qué golpea donde golpea.',
    'Pregúntate de vez en cuando por qué te está saliendo: qué te ayuda, qué te frena. Cuando entiendes cómo funciona tu hábito, sabes arreglarlo el día que algo cambia.',
    'The master smith knows why he strikes where he strikes.',
    'Ask yourself now and then why it’s working: what helps, what holds you back. When you understand how your habit works, you know how to fix it the day something changes.',
  ),
  Advice(
    'largo',
    'Un ladrillo no es una casa. Mil ladrillos, sí.',
    'Piensa en años, no en días. Un día solo no cambia nada, y por eso a veces parece que no vale la pena. Pero mil días lo cambian todo, y cada uno de esos mil es un día como hoy.',
    'One brick isn’t a house. A thousand bricks are.',
    'Think in years, not days. One day alone changes nothing, and that’s why it sometimes seems not worth it. But a thousand days change everything, and each of those thousand is a day like today.',
  ),
];

/// En qué orden se gana cada uno, según lo que se busca.
///
/// Primero lo que más mueve para cada cosa —para sembrar, dónde, cuándo y qué
/// tan chico; para arrancar, qué lo dispara y qué va en su lugar— y después
/// lo que hace falta cuando el entusiasmo del principio se gasta, a las dos o
/// tres semanas. Lo último, lo que tiene que ver con quién te estás volviendo.
List<String> pathFor(AdviceGoal goal) => switch (goal) {
  // El orden lo decidió el autor hasta «porque»: primero lo que arma el
  // comienzo —sitio, a la vista, sin esperar ganas, con gusto, sin medir—,
  // después lo que quita roces y decide de antemano, y la paciencia y el
  // para qué. Lo demás va detrás, por cuándo suele hacer falta: lo de las
  // primeras semanas —hora, el día que se falta, el día malo—, lo de afinar
  // la costumbre, lo de cuando ya cuesta menos o aburre, y lo de los meses.
  // «chico» lo da en la presentación; está acá para que tenga camino.
  AdviceGoal.start => const [
    'chico',
    'lugar',
    'vista',
    'ganas',
    'gusto',
    'nomedir',
    'preparar',
    'estorbos',
    'tentacion',
    'paciencia',
    'porque',
    'hora',
    'nodosveces',
    'dosminutos',
    'diamalo',
    'mismodia',
    'mismo',
    'plan',
    'identidad',
    'perfecto',
    'mananas',
    'viajes',
    'mirar',
    'aburrido',
    'orgullo',
    'unoalavez',
    'subir',
    'nojuzgar',
    'compromiso',
    'descanso',
    'raices',
    'enseñar',
    'largo',
  ],
  AdviceGoal.quit => const [
    'q_disparador',
    'sustituir',
    'reemplazo',
    'q_invisible',
    'q_ola',
    'q_primeros',
    'q_dificil',
    'quiendecide',
    'nodosveces',
    'q_identidad',
    'q_lugares',
    'q_recaida',
    'q_sed',
    'q_costo',
    'diamalo',
    'tentacion',
    'porque',
    'nojuzgar',
    'paciencia',
    'mirar',
    'unoalavez',
    'identidad',
    'aburrido',
    'compromiso',
    'orgullo',
    'raices',
    'enseñar',
    'largo',
  ],
};

/// Los que llegan cuando pasa algo: es cuando más se nota que te mira.
const List<Advice> eventAdvice = [
  // Lo primero que da, antes de fundar nada: que el primer pueblo no sea lo
  // que más cuesta. Ver [prologueAdvice].
  Advice(
    'herreria',
    'El que empieza sin espada no busca al gigante… busca primero la herrería.',
    'No empieces por lo que más te cuesta. Empieza por algo que puedas sostener. Cada día cumplido es un arma que juntas: confianza, costumbre, ganas. Con eso en la mano, lo difícil llega después y ya no lo enfrentas desarmado.',
    'Whoever starts without a sword doesn’t go looking for the giant… first they look for the forge.',
    'Don’t start with what costs you the most. Start with something you can keep up. Each day you keep it is a weapon you gather: confidence, habit, will. With that in hand, the hard things come later and you no longer face them unarmed.',
    event: AdviceEvent.prologue,
  ),
  Advice(
    'ev_primera',
    'Vi la primera piedra posarse.',
    'Lo más difícil ya está hecho: empezar. Mañana solo hace falta lo mismo, en el mismo lugar.',
    'I saw you lay the first stone.',
    'You’ve done the hardest part: starting. Tomorrow you only have to do the same, in the same place.',
    event: AdviceEvent.firstPiece,
  ),
  Advice(
    'ev_segundo',
    'Ya tienes un río que corre. Deja que el nuevo nazca de él.',
    'Encadénalos: haz lo nuevo justo después de lo que ya te sale. El que ya tiene raíces le presta las suyas al que llega.',
    'You already have a river running. Let the new one spring from it.',
    'Chain them: do the new thing right after what already comes easily. The one with roots lends them to the newcomer.',
    event: AdviceEvent.secondTown,
    goal: AdviceGoal.start,
  ),
  // Atar lo nuevo a lo de siempre, recién cuando hay un segundo hábito: con
  // uno solo es pronto para pensar en cadenas.
  Advice(
    'despues',
    'El agua nueva sigue el cauce del río viejo.',
    'Átalo a algo que ya haces todos los días, como «al volver del trabajo, leo». Lo de siempre ya pasa solo, así que cuando termina te recuerda lo nuevo sin que tengas que acordarte.',
    'New water follows the old river’s bed.',
    'Tie it to something you already do every day, like “when I get home from work, I read.” The usual thing already happens on its own, so when it ends it reminds you of the new one without you having to remember.',
    event: AdviceEvent.secondTown,
    goal: AdviceGoal.start,
  ),
  Advice(
    'ev_semana',
    'Siete días. Ya no es casualidad.',
    'Es un comienzo. Ahora importa menos cuánto y más que no se corte.',
    'Seven days. It’s no longer chance.',
    'It’s a beginning. Now how much matters less than keeping it going.',
    event: AdviceEvent.week,
  ),
  Advice(
    'ev_mes',
    'Una luna entera. ¿Notas que pesa menos?',
    'Mira cuánto menos cuesta que al principio: es la costumbre haciendo su parte.',
    'A whole moon. Did you notice it weighs less?',
    'Notice how much less it costs you than at first: that’s the habit doing its share.',
    event: AdviceEvent.month,
  ),
  Advice(
    'ev_falta',
    'Ayer no viniste. Lo vi. No pasa nada.',
    'Lo único que importa ahora es hoy: que no sean dos.',
    'Yesterday you didn’t come. I saw. It’s all right.',
    'The only thing that matters now is today: don’t let it be two.',
    event: AdviceEvent.missedDay,
  ),
  Advice(
    'ev_vuelta',
    'Has vuelto. Eso es lo que hacen quienes de verdad pueden.',
    'No los que nunca fallan: los que siempre vuelven. Empieza pequeño.',
    'You came back. That’s what people who truly can do.',
    'Not the ones who never miss: the ones who always come back. Start small.',
    event: AdviceEvent.comeback,
  ),
  Advice(
    'ev_plan',
    'Vi lo que escribiste en el tablón. Ahora defiéndelo.',
    'Hora y lugar escritos. Cuando algo quiera ocupar ese rato, que tenga que pedir permiso.',
    'I saw what you wrote on the board. Now defend it.',
    'Time and place written down. When something wants that slot, make it ask permission.',
    event: AdviceEvent.plan,
  ),
  Advice(
    'ev_nota',
    'Lo que se escribe, se ve. Lo que se ve, se hace.',
    'Usa el tablón para lo que te ayude a volver: el porqué, el plan, lo que funcionó.',
    'What’s written is seen. What’s seen gets done.',
    'Use the board for whatever helps you come back: the why, the plan, what worked.',
    event: AdviceEvent.ownNote,
  ),
  Advice(
    'ev_pausa',
    'Hasta la tierra descansa en invierno.',
    'Parar a propósito no es abandonar. Cuando el pueblo despierte, vuelve con la versión más pequeña que tengas.',
    'Even the earth rests in winter.',
    'Stopping on purpose isn’t giving up. When the town wakes, come back with the smallest version you have.',
    event: AdviceEvent.rested,
  ),
  Advice(
    'ev_cien',
    'Cien piedras. Ya no necesitas creerme a mí.',
    'Cien veces elegiste aparecer. La prueba de que puedes está construida ahí afuera.',
    'A hundred stones. You no longer have to take my word for it.',
    'A hundred times you chose to show up. The proof that you can is built right out there.',
    event: AdviceEvent.hundred,
  ),
];

/// Los que entran a la app: los que su autor probó y le sirvieron.
///
/// **Ninguno entra por estar escrito acá.** Lo de arriba es el borrador
/// entero; lo que se le da a la gente es sólo lo que pasó la prueba de quien
/// hace la app, en su propia vida. Para sacar uno, se lo saca de acá; lo que
/// alguien ya ganó y después se saca deja de verse en su libreta.
///
/// **Por ahora entran todos**, para poder probarlos en la app; el autor va
/// sacando los que no le sirvieron. Cuando quede la lista, se escribe a mano
/// con los que quedaron.
final Set<String> approvedAdvice = {
  for (final a in [...dailyAdvice, ...eventAdvice]) a.id,
};

/// Todos, por su nombre.
final Map<String, Advice> adviceById = {
  for (final a in [...dailyAdvice, ...eventAdvice]) a.id: a,
};
