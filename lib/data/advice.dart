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
    'Lo que el ojo no ve, la mano no lo busca.',
    'Déjalo a la vista: el calzado junto a la puerta, el libro sobre la almohada.',
    'What the eye doesn’t see, the hand doesn’t reach for.',
    'Leave it in plain sight: shoes by the door, the book on the pillow.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'dosminutos',
    'Nadie sube la montaña. Se dan pasos.',
    'No te propongas hacerlo entero: proponte empezar. Casi nadie se detiene una vez que ha empezado.',
    'Nobody climbs the mountain. They take steps.',
    'Don’t set out to do all of it: set out to begin. Hardly anyone stops once they’ve started.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'preparar',
    'Quien prepara la leña al atardecer tiene fuego en la noche.',
    'Déjalo listo antes: la ropa doblada, la página marcada. Cuando llegue el momento, no habrá nada que decidir.',
    'Who stacks the wood at dusk has fire at night.',
    'Get it ready beforehand: clothes folded, page marked. When the moment comes, there’s nothing to decide.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'noche',
    'La buena mañana se siembra la noche anterior.',
    'Si es de mañana, déjalo todo listo antes de dormir: la ropa a la vista, '
        'el agua servida, el camino despejado. Que al despertar no haya nada '
        'que buscar ni nada que decidir.',
    'A good morning is sown the night before.',
    'If it happens in the morning, have everything ready before you sleep: '
        'clothes in sight, water poured, the way clear. When you wake there '
        'should be nothing to look for and nothing to decide.',
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
    'Cada piedra en el camino es una excusa sentada, esperando.',
    'Quita pasos: si entre tú y el hábito hay tres, que quede uno.',
    'Every stone on the path is an excuse sitting there waiting for you.',
    'Remove steps: if there are three between you and the habit, make it one.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'gusto',
    'La abeja vuelve a la flor que le dio miel.',
    'Únelo a algo que te guste: tu música solo al caminar, el té bueno solo al estudiar.',
    'The bee returns to the flower that gave it honey.',
    'Pair it with something you enjoy: your music only while you walk, the good tea only while you study.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'mismo',
    'El pájaro vuelve a la misma rama, y por eso la rama lo espera.',
    'Mismo lugar, misma hora, mismo primer gesto. El cuerpo lo reconoce antes que la mente.',
    'The bird returns to the same branch, and so the branch waits for it.',
    'Same place, same time, same first move. The body recognises it before the mind does.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'plan',
    'Una intención es una nube. Una cita es una piedra.',
    'Escribe el plan entero: «haré esto, a esta hora, en este lugar».',
    'An intention is a cloud. An appointment is a stone.',
    'Write the whole plan: “I will do this, at this time, in this place.”',
    goal: AdviceGoal.start,
  ),
  Advice(
    'subir',
    'El árbol no pide el cielo de un día para otro.',
    'Cuando lo pequeño ya no cueste, añade un poco. Un poco, no el doble: lo que debe seguir siendo fácil es empezar.',
    'The tree doesn’t ask for the sky overnight.',
    'When the small version no longer costs you, add a bit. A bit, not double: starting is what has to stay easy.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'mananas',
    'El rocío se junta antes de que salga el sol.',
    'Lo que importa, temprano: cuanto más avanza el día, más cosas se interponen.',
    'Dew gathers before the sun comes up.',
    'Do what matters early: the further the day goes, the more gets in the way.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'cierre',
    'Lo que termina bien, vuelve.',
    'Termina con algo amable: un vaso de agua fresca, un rato al sol. Lo que se recuerda con gusto se repite.',
    'What ends well comes back.',
    'End on something pleasant: a glass of cool water, a moment in the sun. What’s remembered well gets repeated.',
    goal: AdviceGoal.start,
  ),
  Advice(
    'mismodia',
    'Llegar tarde a la fuente igual calma la sed.',
    'Si la hora pasó, hazlo igual: más tarde y más pequeño, pero hoy.',
    'Arriving late at the fountain still quenches your thirst.',
    'If the time slipped by, do it anyway: later and smaller, but today.',
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
    'Una gota no hace un charco. Dos, empiezan.',
    'Faltar un día le pasa a cualquiera y no rompe nada. Lo que rompe es el segundo seguido.',
    'One drop doesn’t make a puddle. Two begin one.',
    'Missing a day happens to anyone and breaks nothing. What breaks things is the second in a row.',
  ),
  Advice(
    'diamalo',
    'En invierno el árbol no da frutos, y sigue siendo árbol.',
    'Decide ahora cuál es la versión mínima que cuenta. En el día malo, haz esa y nada más.',
    'In winter the tree bears no fruit, and it’s still a tree.',
    'Decide now what the smallest version that counts is. On a bad day, do that and nothing more.',
  ),
  Advice(
    'ganas',
    'Quien espera el viento perfecto nunca suelta la vela.',
    'No esperes a tener ganas. Las ganas llegan después de empezar, no antes.',
    'Who waits for the perfect wind never sets sail.',
    'Don’t wait to feel like it. The wanting comes after you start, not before.',
  ),
  Advice(
    'identidad',
    'No eres lo que haces una vez. Eres lo que haces siempre.',
    'Cada pieza es un voto por quien quieres ser. No «intento leer»: «soy alguien que lee».',
    'You aren’t what you do once. You are what you always do.',
    'Every piece is a vote for who you want to be. Not “I’m trying to read”: “I’m someone who reads.”',
  ),
  Advice(
    'tentacion',
    'Nadie le gana al río parado en el medio.',
    'No es falta de voluntad: nadie vence a lo que tiene al lado todo el día. Apártate de lo que te distrae.',
    'Nobody beats the river standing in the middle of it.',
    'It isn’t a lack of willpower: nobody beats something sitting next to them all day. Step away from what distracts you.',
  ),
  Advice(
    'mirar',
    'Mira atrás de vez en cuando: el camino también enseña.',
    'Da un paseo por el pueblo. Lo construido es la prueba de que puedes, y una prueba convence más que las ganas.',
    'Look back now and then: the path teaches too.',
    'Take a walk round the town. What you’ve built is proof you can, and proof convinces more than wanting.',
  ),
  Advice(
    'aburrido',
    'La piedra no se gasta por la fuerza del agua, sino por su costumbre.',
    'Que se vuelva aburrido es buena señal: ahí es donde casi todos lo dejan, y donde se queda quien sigue.',
    'Stone is worn not by the water’s force but by its habit.',
    'Getting boring is a good sign: that’s where almost everyone stops, and where whoever carries on stays.',
  ),
  Advice(
    'unoalavez',
    'Quien persigue dos conejos no atrapa ninguno.',
    'De uno en uno. Cambiarlo todo a la vez un lunes es la manera más segura de no cambiar nada.',
    'Who chases two rabbits catches neither.',
    'One at a time. Changing everything at once on Monday is the surest way to change nothing.',
  ),
  Advice(
    'ambiente',
    'La semilla no decide dónde cae. Tú sí.',
    'Cambia el lugar, no la fuerza de voluntad. El lugar decide más que tú.',
    'The seed doesn’t choose where it falls. You do.',
    'Change the place, not your willpower. The place decides more than you do.',
  ),
  Advice(
    'nomedir',
    'No preguntes cuánto llovió. Pregunta si llovió.',
    'Al principio no importa cuánto: importa que ese día estuviste.',
    'Don’t ask how much it rained. Ask whether it rained.',
    'At first it doesn’t matter how much: it matters that you were there that day.',
  ),
  Advice(
    'viajes',
    'El sabio arregla el techo cuando hay sol.',
    'Piensa en los días extraños antes de que lleguen: un viaje, una visita. Si ya sabes qué harás ese día, nada se derrumba.',
    'The wise mend the roof while the sun shines.',
    'Think about the odd days before they come: a trip, a visit. If you already know what you’ll do that day, nothing falls apart.',
  ),
  Advice(
    'paciencia',
    'El bambú pasa años bajo tierra antes de asomar.',
    'Tarda más de lo que crees. No es que no te salga: es que todavía se está haciendo.',
    'Bamboo spends years underground before it shows.',
    'It takes longer than you think. It isn’t that you can’t: it’s still being made.',
  ),
  Advice(
    'porque',
    'Quien sabe para qué soporta casi cualquier cómo.',
    'Escribe en una línea por qué empezaste. El día que lo olvides, léela.',
    'Who knows the why can bear almost any how.',
    'Write in one line why you began. On the day you can’t remember, read it.',
  ),
  Advice(
    'perfecto',
    'La flor no espera a ser perfecta para abrirse.',
    'Hecho es mejor que perfecto: un día flojo que cuenta vale más que uno perfecto que nunca llega.',
    'The flower doesn’t wait to be perfect to open.',
    'Done beats perfect: a weak day that counts is worth more than a perfect one that never comes.',
  ),
  Advice(
    'senal',
    'Todo río tiene un manantial.',
    'Todo hábito nace de algo que lo despierta: una hora, un lugar, algo que acaba de pasar. Quien conoce el suyo puede cuidarlo.',
    'Every river has a spring.',
    'Every habit starts with something that sets it off: a time, a place, something that just happened. If you know yours, you can tend it.',
  ),
  Advice(
    'descanso',
    'Hasta el río se detiene en el lago.',
    'Si necesitas parar, para a propósito y con fecha de vuelta. Una pausa elegida no es un abandono.',
    'Even the river rests in the lake.',
    'If you need to stop, stop on purpose and with a date to return. A decided pause isn’t giving up.',
  ),
  Advice(
    'orgullo',
    'Agradece al día, aunque haya sido pequeño.',
    'Un segundo, nada más: «hoy lo hice». Ese segundo es lo que el cuerpo guarda para querer volver mañana.',
    'Thank the day, even if it was a small one.',
    'Just a second: “I did it today.” That second is what the body keeps so it wants to come back tomorrow.',
  ),
  Advice(
    'compromiso',
    'Una promesa dicha en voz alta pesa más que mil pensadas.',
    'Átate un poco: cita a alguien a una hora, paga por adelantado. Es más fácil cumplirle a otro que a uno mismo.',
    'A promise said aloud weighs more than a thousand thought.',
    'Tie yourself down a little: arrange to meet someone, pay in advance. It’s easier to keep your word to someone else.',
  ),
  Advice(
    'nojuzgar',
    'Quien se castiga por caer aprende a no levantarse.',
    'Sin culpa. Reñirte no te hace volver: te hace esquivar el asunto. Mira qué pasó, ajusta algo pequeño y sigue.',
    'Who punishes themselves for falling learns not to get up.',
    'No guilt. Scolding yourself doesn’t bring you back: it makes you avoid it. See what happened, adjust something small, carry on.',
  ),
  Advice(
    'raices',
    'Cuando ya no se piensa, es que echó raíz. Entonces se riega.',
    'Cuando un hábito deja de ser una decisión, es el momento de cuidarlo, no de soltarlo.',
    'When you no longer think about it, it has taken root. That’s when you water it.',
    'When a habit stops being a decision, that’s the time to look after it, not to let it go.',
  ),
  Advice(
    'enseñar',
    'Quien enseña, aprende dos veces.',
    'Cuéntale a alguien cómo lo haces. Explicarlo obliga a entenderlo, y lo que se entiende se sostiene mejor.',
    'Who teaches learns twice.',
    'Tell someone how you do it. Explaining it makes you understand it, and what you understand you keep up better.',
  ),
  Advice(
    'largo',
    'Un ladrillo no es una casa. Mil ladrillos, sí.',
    'Piensa en años, no en días. Un día no cambia nada; mil días lo cambian todo.',
    'One brick isn’t a house. A thousand bricks are.',
    'Think in years, not days. One day changes nothing; a thousand change everything.',
  ),
];

/// En qué orden se gana cada uno, según lo que se busca.
///
/// Primero lo que más mueve para cada cosa —para sembrar, dónde, cuándo y qué
/// tan chico; para arrancar, qué lo dispara y qué va en su lugar— y después
/// lo que hace falta cuando el entusiasmo del principio se gasta, a las dos o
/// tres semanas. Lo último, lo que tiene que ver con quién te estás volviendo.
List<String> pathFor(AdviceGoal goal) => switch (goal) {
  AdviceGoal.start => const [
    'lugar',
    'hora',
    'chico',
    'vista',
    'dosminutos',
    'nodosveces',
    'preparar',
    'noche',
    'quiendecide',
    'estorbos',
    'gusto',
    'diamalo',
    'mismo',
    'ganas',
    'plan',
    'identidad',
    'tentacion',
    'mirar',
    'aburrido',
    'unoalavez',
    'ambiente',
    'nomedir',
    'cierre',
    'mismodia',
    'viajes',
    'paciencia',
    'subir',
    'porque',
    'perfecto',
    'senal',
    'descanso',
    'orgullo',
    'mananas',
    'compromiso',
    'nojuzgar',
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
    'senal',
    'q_costo',
    'diamalo',
    'tentacion',
    'ambiente',
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
