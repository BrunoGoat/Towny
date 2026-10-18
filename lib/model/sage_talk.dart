/// Las charlas del consejero: lo que tiene para hablar además de sus dichos.
///
/// Los dichos son de todos; esto es tuyo. Usa lo que escribiste —para qué
/// querés el hábito, en quién te convierte, lo mínimo que cuenta— y lo
/// devuelve en el momento en que sirve, que nunca es el día que se escribió.
/// Tu propia razón pesa más que cualquier consejo, y la app ya la tenía
/// guardada: lo que faltaba era alguien que te la recordara a tiempo.
///
/// Tres charlas, y como mucho una por visita, en este orden:
///
/// * **El tropiezo.** Un pueblo salió de tu ritmo: el viejo pregunta qué se
///   interpuso —sin culpa—, te devuelve tu motivo, y según la causa propone
///   lo mínimo que cuenta o un plan de «cuando pase esto, voy a hacer
///   aquello». A la tercera, el patrón: «tus caídas suelen venir del
///   cansancio».
/// * **La identidad.** Al mes de escrita, si todavía es la persona que querés
///   ser, con los votos que diste por ella: una pieza, un voto.
/// * **La semana.** Cada siete días, cómo fue el camino, qué costó y qué se
///   ajusta.
///
/// Cada paso es un globo con sus respuestas, o con un renglón para escribir.
library;

import '../data/advice.dart';
import '../l10n/lang.dart';
import 'advice_book.dart';
import 'habit.dart';
import 'piece.dart';
import 'pledge.dart';
import 'store.dart';
import 'stumble.dart';

/// Un globo de una charla.
///
/// Con [options], se contesta tocando una; con [input], escribiendo; sin
/// ninguna de las dos, tocar el globo sigue con [next] —o termina la charla
/// si no hay—.
class TalkStep {
  TalkStep(this.says, {this.options = const [], this.input, this.next});

  final String says;
  final List<TalkOption> options;
  final TalkInput? input;
  final TalkStep? Function()? next;

  /// Si es el último globo: tocarlo termina la charla.
  bool get closes => options.isEmpty && input == null && next == null;
}

/// Una respuesta: lo que dice, y adónde lleva. Nulo termina la charla.
class TalkOption {
  TalkOption(this.label, this.then);

  final String label;
  final TalkStep? Function() then;
}

/// Un renglón para escribir: con su comienzo fijo delante —«cuando…»—, una
/// pista de ejemplo, y lo que pasa al escribirlo o al decir que ahora no.
class TalkInput {
  TalkInput({required this.hint, required this.then, this.prefix, this.skip});

  final String hint;
  final String? prefix;
  final TalkStep? Function(String text) then;

  /// «Ahora no»: nulo termina la charla.
  final TalkStep? Function()? skip;
}

/// A partir de cuántos días se pregunta si la identidad sigue siendo la tuya.
const int identityReviewDays = 30;

/// Cuántos votos dio un hábito por la persona que dice que querés ser: una
/// pieza, un voto, desde que se escribió la frase.
int identityVotes(Habit h) {
  final desde = h.identityAt;
  if (desde == null) return h.pieces.length;
  return h.pieces.where((p) => !p.placedAt.isBefore(desde)).length;
}

/// El hábito cuya identidad toca repasar, si lo hay.
Habit? identityDue(Iterable<Habit> habits, {DateTime? at}) {
  final now = at ?? DateTime.now();
  for (final h in habits) {
    if (identityWanted(h) == null || h.pieces.isEmpty) continue;
    if (h.restAt(now) != null) continue;
    final desde = h.identityAt ?? h.createdAt;
    if (daysBetween(desde, now) >= identityReviewDays) return h;
  }
  return null;
}

/// Si el consejero tiene algo que hablar: es el punto de su botón.
bool talkDue(Store store, AdviceBook book, {DateTime? at}) {
  if (!book.met) return false;
  for (final h in store.habits) {
    if (stumbleDue(h, at: at) != null) return true;
  }
  return identityDue(store.habits, at: at) != null || book.weekDue(at: at);
}

/// La charla que toca ahora, o nula. Una por visita: la pide la pantalla del
/// consejero al abrirse.
TalkStep? nextTalk(Store store, AdviceBook book, {DateTime? at}) {
  final now = at ?? DateTime.now();
  if (!book.met) return null;
  for (final h in store.habits) {
    final dia = stumbleDue(h, at: now);
    if (dia != null) return _Charla(store, book, now).tropiezo(h, dia);
  }
  final quien = identityDue(store.habits, at: now);
  if (quien != null) return _Charla(store, book, now).identidad(quien);
  if (book.weekDue(at: now)) return _Charla(store, book, now).semana();
  return null;
}

/// Las tres charlas, para probarlas desde los ajustes de desarrollo.
enum TalkKind { stumble, identity, week }

/// Una charla a la fuerza, sobre el pueblo de delante, toque o no toque. Lo
/// que se conteste se guarda como si fuera de verdad.
TalkStep trialTalk(TalkKind kind, Store store, AdviceBook book) {
  final now = DateTime.now();
  final c = _Charla(store, book, now);
  return switch (kind) {
    TalkKind.stumble => c.tropiezo(
      store.habit,
      DateTime(now.year, now.month, now.day - 1),
    ),
    TalkKind.identity => c.identidad(store.habit),
    TalkKind.week => c.semana(),
  };
}

class _Charla {
  _Charla(this.store, this.book, this.now);

  final Store store;
  final AdviceBook book;
  final DateTime now;

  AdviceGoal _busca(Habit h) => book.goalOf(h.id) ?? AdviceGoal.start;

  // ----------------------------------------------------------- el tropiezo

  TalkStep tropiezo(Habit h, DateTime dia) {
    final cuando = _diaDicho(dia);
    TalkOption op(String label, Stumble c) => TalkOption(label, () {
      store.stumbled(h, dia, c);
      return _tuMotivo(h, c);
    });
    return TalkStep(
      tr(
        '$cuando, el pueblo de «${h.name}» se quedó sin piedra. No vengo a '
            'reprochártelo: todo camino tiene piedras sueltas. ¿Qué se '
            'interpuso?',
        '$cuando, the town of "${h.name}" got no stone. I am not here to '
            'reproach you: every road has loose stones. What got in the way?',
      ),
      options: [
        op(tr('Cansancio', 'Tiredness'), Stumble.tired),
        op(tr('Me olvidé', 'I forgot'), Stumble.forgot),
        op(tr('Tentación', 'Temptation'), Stumble.tempted),
        op(tr('Desánimo', 'Low spirits'), Stumble.mood),
        op(tr('Otra cosa', 'Something else'), Stumble.other),
      ],
    );
  }

  /// Ayer, el martes, o hace nueve días.
  String _diaDicho(DateTime dia) {
    final n = daysBetween(dia, now);
    if (n <= 1) return tr('Ayer', 'Yesterday');
    if (n < 7) {
      return tr('El ${_semana(dia.weekday)}', 'On ${_semana(dia.weekday)}');
    }
    return tr('Hace $n días', '$n days ago');
  }

  /// Lo que escribiste, devuelto; y después, lo de la causa.
  TalkStep _tuMotivo(Habit h, Stumble c) {
    final porque = h.why?.trim();
    if (porque == null || porque.isEmpty) return _segunCausa(h, c);
    final n = daysBetween(h.createdAt, now);
    final hace = n < 2
        ? tr('Hace muy poco', 'Not long ago')
        : tr('Hace $n días', '$n days ago');
    return TalkStep(
      tr(
        '$hace escribiste que querías esto «$porque». Esa razón no se ha '
            'movido de su sitio.',
        '$hace you wrote that you wanted this "$porque". That reason has not '
            'moved from its place.',
      ),
      next: () => _segunCausa(h, c),
    );
  }

  TalkStep _segunCausa(Habit h, Stumble c) {
    final minimo = h.floor?.trim();
    final hayMinimo = minimo != null && minimo.isNotEmpty;
    switch (c) {
      case Stumble.tired:
      case Stumble.mood:
        final dice = c == Stumble.tired
            ? tr(
                'Cuando el cuerpo pesa, basta con poco. Una piedra pequeña '
                    'sigue siendo piedra.',
                'When the body is heavy, a little is enough. A small stone '
                    'is still a stone.',
              )
            : tr(
                'Los días grises también cuentan. No exijas grandeza: basta '
                    'con no soltar del todo el hilo.',
                'Grey days count too. Do not demand greatness: it is enough '
                    'not to let go of the thread.',
              );
        if (hayMinimo) {
          return TalkStep(
            '$dice ${tr('Lo tuyo es «$minimo».', 'Yours is "$minimo".')}',
            next: () => _patron(h),
          );
        }
        return TalkStep(
          dice,
          options: [
            TalkOption(
              tr('Decidir lo mínimo', 'Decide the least'),
              () => minimoQue(h, then: () => _patron(h)),
            ),
            TalkOption(tr('Ahora no', 'Not now'), () => _patron(h)),
          ],
        );
      case Stumble.forgot:
      case Stumble.tempted:
        final dice = c == Stumble.forgot
            ? tr(
                'Lo que no tiene sitio en el día se pierde por el camino. '
                    'Átalo a algo que ya haces.',
                'What has no place in the day gets lost on the road. Tie it '
                    'to something you already do.',
              )
            : tr(
                'La tentación no se vence a empujones: se le cierra el paso '
                    'antes de que llegue.',
                'Temptation is not beaten by pushing: you close the path '
                    'before it arrives.',
              );
        final hayPlan = h.planIf != null && h.planThen != null;
        return TalkStep(
          hayPlan
              ? '$dice ${tr('Tu plan era: cuando ${h.planIf}, voy a ${h.planThen}.', 'Your plan was: when ${h.planIf}, I will ${h.planThen}.')}'
              : dice,
          options: [
            TalkOption(
              hayPlan
                  ? tr('Cambiar el plan', 'Change the plan')
                  : tr('Trazar un plan', 'Make a plan'),
              () => plan(h, then: () => _patron(h)),
            ),
            TalkOption(
              hayPlan
                  ? tr('Sigue valiendo', 'It still holds')
                  : tr('Ahora no', 'Not now'),
              () => _patron(h),
            ),
          ],
        );
      case Stumble.other:
      case Stumble.skipped:
        return TalkStep(
          tr(
            'La vida tiene sus propios caminos, y a veces se cruzan con el '
                'tuyo. No pasa nada.',
            'Life has its own roads, and sometimes they cross yours. That is '
                'all right.',
          ),
          next: () => _patron(h),
        );
    }
  }

  /// Lo que se repite, si ya se ve; y la regla de no caer dos veces.
  TalkStep _patron(Habit h) {
    final p = stumblePattern(store.habits);
    final partes = <String>[
      if (p.cause != null) _causaVista(p.cause!),
      if (p.weekday != null)
        tr(
          'Y suelen caer en ${_semana(p.weekday!)}. Ese día, ten el camino '
              'preparado de antemano.',
          'And they tend to fall on ${_semana(p.weekday!)}. On that day, have '
              'the path ready beforehand.',
        ),
    ];
    final cierre = _dosVeces(h);
    if (partes.isEmpty) return cierre;
    return TalkStep(partes.join(' '), next: () => cierre);
  }

  String _causaVista(Stumble c) => switch (c) {
    Stumble.tired => tr(
      'He notado que tus tropiezos suelen venir del cansancio. Que lo mínimo '
          'sea de verdad mínimo.',
      'I have noticed your stumbles tend to come from tiredness. Let the '
          'least be truly the least.',
    ),
    Stumble.forgot => tr(
      'He notado que tus tropiezos suelen venir del olvido. Lo que no tiene '
          'hora ni lugar, no tiene día.',
      'I have noticed your stumbles tend to come from forgetting. What has no '
          'hour nor place has no day.',
    ),
    Stumble.tempted => tr(
      'He notado que tus tropiezos suelen venir de la tentación. Fíjate en '
          'qué la despierta.',
      'I have noticed your stumbles tend to come from temptation. Watch what '
          'wakes it.',
    ),
    Stumble.mood => tr(
      'He notado que tus tropiezos suelen venir del desánimo. Cuando el ánimo '
          'baja, que el paso sea corto.',
      'I have noticed your stumbles tend to come from low spirits. When the '
          'spirit sinks, let the step be short.',
    ),
    _ => '',
  };

  /// Nunca dos veces seguidas: y si hoy todavía no hubo piedra, hoy está a
  /// tiempo.
  TalkStep _dosVeces(Habit h) {
    final hoy =
        h.lastPlacedAt != null && dayKey(h.lastPlacedAt!) == dayKey(now);
    return TalkStep(
      hoy
          ? tr(
              'Y ya volviste a poner piedra. Una caída es un accidente; lo que '
                  'cuenta es levantarse, y eso ya está hecho.',
              'And you have already laid a stone again. A fall is an accident; '
                  'what counts is getting up, and that is done.',
            )
          : tr(
              'Una caída es un accidente; dos seguidas, el comienzo de otra '
                  'costumbre. Hoy todavía estás a tiempo.',
              'One fall is an accident; two in a row, the start of another '
                  'habit. Today there is still time.',
            ),
    );
  }

  // ---------------------------------------------------------------- el plan

  /// «Cuando pase esto…» y «…voy a hacer aquello»: dos renglones, y el plan
  /// queda escrito en la ficha del hábito.
  TalkStep plan(Habit h, {required TalkStep? Function() then}) {
    final deja = _busca(h) == AdviceGoal.quit;
    return TalkStep(
      deja
          ? tr(
              'Piensa en el momento en que suele llegar. ¿Qué pasa justo '
                  'antes?',
              'Think of the moment it usually comes. What happens just '
                  'before?',
            )
          : tr(
              'Busca algo que ya haces cada día, y ata ahí tu hábito. ¿Cuándo '
                  'será?',
              'Find something you already do each day, and tie your habit to '
                  'it. When will it be?',
            ),
      input: TalkInput(
        prefix: tr('Cuando', 'When'),
        hint: deja
            ? tr('me aburra en el sillón', 'I get bored on the couch')
            : tr('termine de cenar', 'I finish dinner'),
        skip: then,
        then: (cuando) => TalkStep(
          deja
              ? tr(
                  '¿Y qué pondrás en su lugar? La oscuridad no se echa a '
                      'empujones: se enciende una vela.',
                  'And what will you put in its place? Darkness is not pushed '
                      'out: a candle is lit.',
                )
              : tr(
                  '¿Y qué harás entonces? Que sea pequeño: lo pequeño se '
                      'cumple.',
                  'And what will you do then? Keep it small: small things get '
                      'done.',
                ),
          input: TalkInput(
            prefix: tr('voy a', 'I will'),
            hint: deja
                ? tr('salir a caminar diez minutos', 'go for a ten-minute walk')
                : tr('leer una página', 'read one page'),
            skip: then,
            then: (que) {
              store.planHabit(h, when: cuando, then: que);
              return TalkStep(
                tr(
                  'Cuando ${h.planIf}, voy a ${h.planThen}. Así queda escrito en tu '
                      'ficha. Lo decidido de antemano ya no hay que decidirlo.',
                  'When ${h.planIf}, I will ${h.planThen}. So it is written in your '
                      'card. What is decided beforehand need not be decided '
                      'again.',
                ),
                next: then,
              );
            },
          ),
        ),
      ),
    );
  }

  /// Lo mínimo que cuenta, escrito desde el consejero.
  TalkStep minimoQue(Habit h, {required TalkStep? Function() then}) => TalkStep(
    tr(
      '¿Qué es lo más pequeño que todavía cuenta? Para los días en que '
          'no hay fuerzas.',
      'What is the smallest thing that still counts? For the days with '
          'no strength.',
    ),
    input: TalkInput(
      hint: tr(
        'abrir el libro y leer una página',
        'open the book and read a page',
      ),
      skip: then,
      then: (texto) {
        store.setFloor(h, texto);
        return TalkStep(
          tr(
            '«${h.floor}». Así sea: en los días grises, con eso basta.',
            '"${h.floor}". So be it: on grey days, that is enough.',
          ),
          next: then,
        );
      },
    ),
  );

  // ----------------------------------------------------------- la identidad

  TalkStep identidad(Habit h) {
    final quien =
        identityWanted(h) ??
        tr('alguien que cumple su palabra', 'someone who keeps their word');
    final n = daysBetween(h.identityAt ?? h.createdAt, now);
    final votos = identityVotes(h);
    return TalkStep(
      n < 2
          ? tr(
              'Hace poco dijiste que querías ser «$quien».',
              'Not long ago you said you wanted to be "$quien".',
            )
          : tr(
              'Hace $n días dijiste que querías ser «$quien».',
              '$n days ago you said you wanted to be "$quien".',
            ),
      next: () => TalkStep(
        votos == 1
            ? tr(
                'Desde entonces has dado un voto por esa persona: cada piedra '
                    'es uno. ¿Sigue siendo quien quieres ser?',
                'Since then you have cast one vote for that person: each stone '
                    'is one. Is it still who you want to be?',
              )
            : tr(
                'Desde entonces has dado $votos votos por esa persona: cada '
                    'piedra es uno. ¿Sigue siendo quien quieres ser?',
                'Since then you have cast $votos votes for that person: each '
                    'stone is one. Is it still who you want to be?',
              ),
        options: [
          TalkOption(tr('Sí, sigue siendo', 'Yes, it still is'), () {
            store.confirmIdentity(h);
            return TalkStep(
              tr(
                'Entonces sigue votando. No te conviertes de un salto: te '
                    'conviertes piedra a piedra.',
                'Then keep voting. You do not become it in a leap: you become '
                    'it stone by stone.',
              ),
            );
          }),
          TalkOption(
            tr('Ha cambiado', 'It has changed'),
            () => TalkStep(
              tr(
                'La gente cambia, y el camino con ella. ¿Quién quieres ser '
                    'ahora?',
                'People change, and the road with them. Who do you want to be '
                    'now?',
              ),
              input: TalkInput(
                prefix: identityPrefix,
                hint: tr('que cuida su cuerpo', 'who looks after their body'),
                skip: () {
                  store.confirmIdentity(h);
                  return null;
                },
                then: (texto) {
                  store.confirmIdentity(h, identity: identityWhole(texto));
                  return TalkStep(
                    tr(
                      'Así sea: «${identityWanted(h)}». Cada piedra, desde hoy, '
                          'es un voto por esa persona.',
                      'So be it: ${identityWanted(h)}. Every stone, from '
                          'today, is a vote for that person.',
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- la semana

  TalkStep semana() {
    final desde = now.subtract(const Duration(days: 7));
    var piedras = 0;
    for (final h in store.habits) {
      piedras += h.pieces.where((p) => p.placedAt.isAfter(desde)).length;
    }
    TalkOption como(String label, String how, String responde) =>
        TalkOption(label, () => TalkStep(responde, next: () => _costo(how)));
    return TalkStep(
      piedras == 1
          ? tr(
              'Ha pasado una semana desde la última vez. Tus pueblos '
                  'recibieron una piedra. ¿Cómo fue el camino?',
              'A week has passed since last time. Your towns received one '
                  'stone. How was the road?',
            )
          : tr(
              'Ha pasado una semana desde la última vez. Tus pueblos '
                  'recibieron $piedras piedras. ¿Cómo fue el camino?',
              'A week has passed since last time. Your towns received $piedras '
                  'stones. How was the road?',
            ),
      options: [
        como(
          tr('Bien', 'Good'),
          'bien',
          tr(
            'Me alegra. Lo que se hace con gusto echa raíces.',
            'I am glad. What is done gladly takes root.',
          ),
        ),
        como(
          tr('A medias', 'So-so'),
          'medias',
          tr(
            'A medias también es avanzar. El río no corre recto, y llega.',
            'Halfway is still moving. The river does not run straight, and it '
                'arrives.',
          ),
        ),
        como(
          tr('Cuesta arriba', 'Uphill'),
          'cuesta',
          tr(
            'Las cuestas son las que hacen las piernas. Bien hecho en '
                'decirlo.',
            'Hills are what make the legs. Well done for saying it.',
          ),
        ),
      ],
    );
  }

  TalkStep _costo(String how) {
    TalkOption op(String label, String cost) => TalkOption(label, () {
      book.weekDone(at: now, how: how, cost: cost);
      return _ajuste(cost);
    });
    return TalkStep(
      tr('¿Qué fue lo que más costó?', 'What was hardest?'),
      options: [
        op(tr('Cansancio', 'Tiredness'), 'tired'),
        op(tr('Me olvidé', 'I forgot'), 'forgot'),
        op(tr('Tentación', 'Temptation'), 'tempted'),
        op(tr('Desánimo', 'Low spirits'), 'mood'),
        op(tr('Nada en especial', 'Nothing in particular'), ''),
      ],
    );
  }

  TalkStep _ajuste(String cost) {
    final h = store.habit;
    TalkStep? hastaLaProxima() => TalkStep(
      tr(
        'Así sea. Dentro de siete días volvemos a mirar el camino.',
        'So be it. In seven days we look at the road again.',
      ),
    );
    final minimo = TalkOption(
      tr('Achicar lo mínimo', 'Shrink the least'),
      () => minimoQue(h, then: hastaLaProxima),
    );
    final plano = TalkOption(
      tr('Trazar un plan', 'Make a plan'),
      () => plan(h, then: hastaLaProxima),
    );
    final igual = TalkOption(tr('Seguir igual', 'Keep as is'), hastaLaProxima);
    // Lo que se ofrece primero, según lo que costó.
    final ops = switch (cost) {
      'tired' || 'mood' => [minimo, plano, igual],
      'forgot' || 'tempted' => [plano, minimo, igual],
      _ => [igual, plano, minimo],
    };
    return TalkStep(
      tr(
        '¿Qué ajustamos en «${h.name}» para la semana que viene?',
        'What shall we adjust in "${h.name}" for the coming week?',
      ),
      options: ops,
    );
  }

  String _semana(int weekday) => tr(
    const [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ][weekday - 1],
    const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][weekday - 1],
  );
}
