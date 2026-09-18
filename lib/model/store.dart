import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/rng.dart';
import '../data/character.dart';
import '../data/landmarks.dart';
import '../data/pacing.dart';
import '../data/symbols.dart';
import '../engine/town.dart';
import 'census.dart';
import 'findings.dart';
import 'habit.dart';
import 'piece.dart';

/// What happened when a piece was laid. Drives the celebration.
class PlaceResult {
  PlaceResult({
    required this.piece,
    required this.relit,
    required this.relitFrom,
    this.startedNewDay = false,
    this.woke = false,
    this.unlocked = false,
  });

  final Piece piece;

  /// True when this piece brought a town's lights back on.
  final bool relit;
  final double relitFrom;

  final bool startedNewDay;

  /// True cuando esta pieza despertó a un pueblo que dormía: volviste antes de
  /// lo que habías dicho.
  final bool woke;

  /// True cuando esta pieza fue la que abrió el valle: a partir de acá se
  /// puede fundar un segundo pueblo. Pasa una sola vez en la vida de un valle.
  final bool unlocked;
}

/// Everything the app remembers: the habits, and the towns they have built.
class Store extends ChangeNotifier {
  Store();

  static const _key = 'pueblo_state_v1';

  /// What the app was called when it was a wall. Read once, then left alone.
  static const _wallKey = 'la_muralla_state_v2';
  static const _wallLegacyKey = 'la_muralla_state_v1';

  final List<Habit> habits = [];
  int active = 0;

  bool loaded = false;
  bool _dirty = false;
  SharedPreferences? _prefs;

  /// Set at launch so the first piece back can play the relighting against the
  /// state the person actually walked in on.
  double integrityAtLaunch = 1.0;

  Habit get habit => habits[active.clamp(0, habits.length - 1)];

  /// What kind of place the town in front of you is.
  TownCharacter get character => habit.place;

  /// Its plan: which landmark comes next, and what everything costs.
  TownPlan get plan => TownPlan.of(character, seed: habit.townSeed);

  int get total => habit.total;

  /// A pretend count, for looking at what the town becomes without waiting
  /// years for it. The real pieces are untouched.
  int? preview;
  bool get isPreviewing => preview != null;
  int get shownTotal => preview ?? habit.total;

  void setPreview(int? count) {
    preview = count;
    notifyListeners();
  }

  DateTime? get lastPlacedAt => habit.lastPlacedAt;

  // ------------------------------------------------------------- la crónica

  /// Escribe en la crónica de un pueblo todo lo que ya se empezó y todavía no
  /// estaba escrito.
  ///
  /// Se llama al cargar, al importar y cada vez que cae una pieza. Ni antes ni
  /// después: escribir de más le cerraría la puerta a lo que se añada mañana
  /// —el edificio siguiente ya estaría decidido— y escribir de menos dejaría
  /// que un cambio del catálogo le cambie las casas a alguien que ya las tiene
  /// levantadas.
  ///
  /// Sólo crece. Una crónica no se acorta ni se corrige: lo que dice es lo que
  /// pasó.
  bool _writeUpWorks(Habit h) {
    final want = TownPlan.of(
      h.place,
      seed: h.townSeed,
    ).chronicleFor(h.total, h.chronicle);
    if (want.length <= h.chronicle.length) return false;
    h.chronicle
      ..clear()
      ..addAll(want);
    return true;
  }

  /// Lo que el pueblo está esperando que le contesten, si es que espera algo.
  ///
  /// Todo lo demás de esta app ocurre solo: las casas se eligen con el hash del
  /// pueblo y los hitos por el orden que le tocó al fundarlo, y está bien que
  /// sea así — hay un solo botón y ninguna decisión que tomar, y ésa es la
  /// mitad de lo que la hace descansada.
  ///
  /// Pero una vez cada varias semanas, cuando toca empezar una obra grande, el
  /// pueblo pregunta. Dos obras que le tocaban igual de pronto, y la que no
  /// salga sigue la primera de la lista para la próxima vez, así que elegir no
  /// es renunciar a nada: es decidir el orden de tu propio valle. Es la única
  /// decisión que hay en toda la app, y por eso tiene que ser rara.
  ///
  /// Nulo casi siempre. Deja de serlo justo en la pieza en la que la obra
  /// empezaría, y vuelve a serlo en cuanto se contesta.
  List<Landmark>? get pendingChoice {
    final c = plan.choiceFor(habit.total, habit.chronicle);
    if (c == null) return null;
    final marks = [
      for (final id in c.$2)
        if (TownPlan.landmarkOf(id) != null) TownPlan.landmarkOf(id)!,
    ];
    return marks.length < 2 ? null : marks;
  }

  /// Contestar: se escribe en la crónica y de ahí no se mueve nunca más.
  ///
  /// Si lo que llega no es una de las dos que se preguntaron, no pasa nada —
  /// se escribe la primera, que es la que habría salido sola. Un pueblo no se
  /// queda esperando por una respuesta que no llega.
  void chooseWork(String id) {
    final c = plan.choiceFor(habit.total, habit.chronicle);
    if (c == null) return;
    final want = c.$2.contains(id) ? id : c.$2.first;
    while (habit.chronicle.length < c.$1) {
      // No puede pasar —la crónica llega justo hasta aquí— pero si pasara,
      // escribir en el hueco equivocado le cambiaría los edificios a un pueblo
      // que ya está en pie. Mejor rellenar con lo que decía el plan.
      habit.chronicle.add(plan.chronicleFor(total, habit.chronicle).last);
    }
    habit.chronicle.add(want);
    _writeUpWorks(habit);
    _save();
    notifyListeners();
  }

  /// Cerrar sin contestar: que decidan ellos, y que lo decidan ahora.
  ///
  /// Escribe la primera, que es la que habría salido sola. Se podría no hacer
  /// nada —la pregunta caduca con la pieza siguiente y entonces se escribe lo
  /// mismo— pero eso deja la crónica un hueco corta mientras tanto, y si ese
  /// mientras tanto dura un mes y en el medio cae una actualización con hitos
  /// nuevos, la obra que estaba a punto de empezar podría cambiar. Es una
  /// ventana chica, pero cerrarla cuesta una línea.
  void letThemDecide() {
    final c = plan.choiceFor(habit.total, habit.chronicle);
    if (c == null) return;
    chooseWork(c.$2.first);
  }

  /// Y de todos, que es lo que hace falta al abrir la app y al importar.
  /// Apunta en el padrón a los vecinos que hayan nacido en [layout].
  ///
  /// Lo llama la vista con el plano que ya tiene construido, que es lo que
  /// evita levantar un pueblo entero otra vez sólo para contar casas. Se llama
  /// una vez por cada cuenta de piezas, que es exactamente cuando puede haber
  /// nacido alguien.
  ///
  /// Nunca sobre un plano a medio enseñar: mientras cae una pieza la vista
  /// dibuja el pueblo de antes, y apuntar a alguien contra ese plano le daría
  /// la fecha de la pieza que todavía no ha caído.
  void enrol(Habit h, TownLayout layout) {
    if (layout.placed != h.total) return;
    if (enrolFolk(h, layout).isEmpty) return;
    _save();
  }

  /// Clava una nota tuya en el tablón de [h].
  ///
  /// La más nueva arriba, que es como queda en un tablón de verdad. Se guarda
  /// entera aunque no quepa clavada: las que sobran del tope vuelven a asomar
  /// en cuanto se quita una.
  void pinNote(Habit h, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    h.notes.insert(
      0,
      '${DateTime.now().millisecondsSinceEpoch}|${t.replaceAll('\n', ' ')}',
    );
    // Un tope generoso y lejos de la vista, para que esto no crezca sin fin en
    // una copia de seguridad. Cincuenta notas tuyas son muchísimas más de las
    // que nadie clava.
    while (h.notes.length > 50) {
      h.notes.removeLast();
    }
    _save();
    notifyListeners();
  }

  /// Quita una de las tuyas: la que dice exactamente eso y se clavó ese día.
  ///
  /// Por contenido y no por número de hueco, porque quien la quita la está
  /// mirando descolgada y no sabe qué puesto ocupa en la lista.
  void unpinNote(Habit h, String said) {
    final antes = h.notes.length;
    h.notes.removeWhere((line) {
      final corte = line.indexOf('|');
      return corte > 0 && line.substring(corte + 1).trim() == said.trim();
    });
    if (h.notes.length == antes) return;
    _save();
    notifyListeners();
  }

  bool _writeUpAll() {
    var moved = false;
    for (final h in habits) {
      if (_writeUpWorks(h)) moved = true;
    }
    return moved;
  }

  // El cielo ya no se guarda.
  //
  // Hubo un cuaderno de constelaciones: se tocaba la figura de esta noche, se
  // anotaba, y había una lista de ocho con las que llevabas encontradas —y un
  // observatorio que había que construir antes de que apareciera ninguna. Eso
  // es un sistema dentro de una app que sólo tiene uno: una pieza, un logro.
  // El cielo se queda de cielo: algunas noches hay una figura ahí arriba y
  // otras no, tocarla suena, y no lleva la cuenta nadie.
  //
  // Lo que hubiera guardado sigue leyéndose y se tira al escribir, para que el
  // disco se limpie solo igual que se hizo con las letras del tablón.

  // ------------------------------------------------------------------ habits

  // ------------------------------------------------------------- el candado

  /// Si el valle ya se ganó el derecho a tener más de un pueblo.
  ///
  /// Una vez abierta, la puerta no se vuelve a cerrar nunca. Es lo único que
  /// hace que un candado sea aceptable en esta app: un mes malo no te puede
  /// quitar algo que ya habías conseguido, porque entonces el castigo caería
  /// justo sobre la persona para la que está hecho todo lo demás.
  bool _unlocked = false;

  bool get unlocked => _unlocked || habits.length > 1;

  /// Cuántos de los últimos [Pacing.unlockWindow] días tienen pieza, contando
  /// el hábito que mejor va.
  ///
  /// Días con pieza y no piezas: diez en una tarde son una tarde, y lo que
  /// esto pregunta es si la cosa se sostiene.
  int get unlockProgress {
    final today = dayStart(DateTime.now());
    final from = today.subtract(const Duration(days: Pacing.unlockWindow - 1));
    var best = 0;
    for (final h in habits) {
      final days = <int>{};
      for (final p in h.pieces) {
        final d = dayStart(p.placedAt);
        if (d.isBefore(from) || d.isAfter(today)) continue;
        days.add(dayKey(d));
      }
      if (days.length > best) best = days.length;
    }
    return best;
  }

  /// Si lo de hoy abre la puerta, dejarlo escrito.
  ///
  /// Se mira al poner una pieza y al cargar, que es cuando puede haber
  /// cambiado. Escribirlo y no recalcularlo es lo que hace que no se cierre.
  bool _checkUnlock() {
    if (_unlocked) return false;
    if (habits.length > 1 || unlockProgress >= Pacing.unlockDays) {
      _unlocked = true;
      return true;
    }
    return false;
  }

  /// Si se puede fundar otro pueblo ahora mismo.
  ///
  /// Dos condiciones, y son distintas entre sí: el valle tiene sitio, y vos
  /// demostraste que podés sostener uno. La primera es geometría; la segunda
  /// es la única cosa que esta app te pide antes de darte algo.
  ///
  /// El segundo pueblo se gana porque sobreestimar cuánto cambio se puede
  /// sostener es lo que hace casi todo el mundo el primer día: cuando hay
  /// ganas es facilísimo pensar «ahora sí» y querer arreglar diez cosas a la
  /// vez, y cada una de ellas cuesta un poco de atención aunque no cueste
  /// tiempo. Un valle que se abre solo es una lista de deseos; uno que se abre
  /// cuando lo anterior se sostiene dice otra cosa — primero aprendí a
  /// mantener una, ahora estoy listo para otra.
  bool get canAddHabit => habits.length < Habit.maxSlots && unlocked;

  // ------------------------------------------------------------ desenganche

  /// A partir de cuántos días sin piezas un hueco deja de parecer un hueco.
  ///
  /// Contra tu propio ritmo y no contra un número fijo. Quien pone piezas tres
  /// veces por semana no está desenganchado el jueves, y decirle que sí sería
  /// exactamente el error que comete cualquier app que trate todos los días en
  /// blanco como incumplimientos: cuatro faltas seguidas y cuatro faltas
  /// seguidas de alguien que nunca falla no son la misma cosa.
  ///
  /// El tope de dos semanas está para que a nadie se le pase: con una mediana
  /// de seis días el umbral saldría a dieciocho, y a los dieciocho días ya no
  /// hay ritmo que valga.
  static int adriftAfter(Habit h) {
    final mid = typicalReturn(h) ?? 1;
    return (mid * 3).clamp(4, 14);
  }

  /// El hábito sobre el que el pueblo tiene algo que preguntar, si lo hay.
  ///
  /// Lo que se está buscando no es incumplimiento sino desenganche, que son
  /// dos cosas distintas y se tratan distinto. Un día sin aparecer no necesita
  /// que nadie intervenga. Cuatro pueden ser el momento en que alguien pasa de
  /// «fallé» a «ya fue», y eso vale la pena cortarlo — no para presionar, sino
  /// porque a lo mejor el problema no sos vos y el hábito está mal planteado.
  ///
  /// Nulo casi siempre, que es como tiene que ser. Esta app pregunta dos veces
  /// en su vida: cuando toca empezar una obra grande, y acá.
  Habit? get adrift {
    final h = habit;
    if (h.pieces.isEmpty || h.resting) return null;
    // Con menos de una semana de historia no se sabe nada de nadie, y una
    // pregunta así el tercer día es una app opinando sin datos.
    if (daysOf(h).length < 5) return null;
    // Ya se preguntó por este hueco. Una vez y no más: la pregunta caduca
    // cuando vuelve a caer una pieza, que es cuando empieza un hueco nuevo.
    final asked = h.askedAt;
    final last = h.lastPlacedAt;
    if (asked != null && last != null && asked.isAfter(last)) return null;
    return daysIdleOf(h) >= adriftAfter(h) ? h : null;
  }

  /// Que conste que ya se preguntó, conteste lo que conteste.
  ///
  /// Se apunta al abrir la hoja y no al contestarla, porque cerrarla sin
  /// contestar también es una respuesta — es «ahora no» — y volver a
  /// preguntar mañana sería no haberla escuchado.
  void asked(Habit h) {
    h.askedAt = DateTime.now();
    _save();
  }

  // ----------------------------------------------------------------- dormir

  /// Dormir un pueblo hasta [until].
  ///
  /// Mientras duerme no se apaga, no cuenta días en contra y no sale en
  /// ninguna cuenta del tablón. La vida cambia: un hábito que iba perfecto en
  /// enero puede no tener ningún sentido durante un viaje, una mudanza o un
  /// mes imposible, y una app cuyas dos únicas opciones son seguir o fallar
  /// convierte eso en un fracaso. Esto es lo que separa «no estoy pudiendo con
  /// esto ahora» de «ya no quiero que esto forme parte de mi vida».
  ///
  /// Siempre con fecha de vuelta, nunca abierta. Una pausa sin final es
  /// abandono con mejor nombre.
  void rest(Habit h, DateTime until) {
    final now = DateTime.now();
    if (!until.isAfter(now)) return;
    // Dormir dos veces es dormir una vez más largo, no dos tramos solapados.
    wake(h, silent: true);
    h.rests.add(Rest(now, until).encode());
    integrityAtLaunch = integrityOf(habit);
    _save();
    notifyListeners();
  }

  /// Despertarlo ahora, antes de tiempo.
  ///
  /// El tramo se recorta hasta hoy en vez de borrarse: lo que duró de verdad
  /// es un dato, y volver antes de tiempo es exactamente la clase de cosa que
  /// esta app tiene que saber contar.
  void wake(Habit h, {bool silent = false}) {
    final now = DateTime.now();
    var moved = false;
    for (var i = 0; i < h.rests.length; i++) {
      final r = Rest.parse(h.rests[i]);
      if (r == null || !r.covers(now)) continue;
      // Una pausa que se corta el mismo día que empezó no llegó a existir: no
      // llegó a pasar una noche, no le quitó un día a ninguna cuenta y lo
      // único que dejaría escrito es que alguien tocó el botón y se arrepintió.
      if (dayKey(r.from) == dayKey(now)) {
        h.rests.removeAt(i--);
      } else {
        h.rests[i] = Rest(r.from, now).encode();
      }
      moved = true;
    }
    if (!moved || silent) return;
    integrityAtLaunch = integrityOf(habit);
    _save();
    notifyListeners();
  }

  /// The next free plot in the valley. Slots are never reused while their
  /// habit exists, so nobody's town ever moves.
  int _freeSlot() {
    final taken = habits.map((h) => h.slot).toSet();
    for (var i = 0; i < Habit.maxSlots; i++) {
      if (!taken.contains(i)) return i;
    }
    return habits.length;
  }

  Habit addHabit(
    String name,
    String symbol, {
    int? character,
    String? why,
    String? floor,
  }) {
    final slot = _freeSlot();
    final h = Habit(
      id: 'h${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Sin nombre' : name.trim(),
      symbol: resolveHabitSymbol(symbol),
      slot: slot,
      character: character ?? TownCharacter.forSlot(slot).order,
      why: why == null || why.trim().isEmpty ? null : why.trim(),
      floor: floor == null || floor.trim().isEmpty ? null : floor.trim(),
      createdAt: DateTime.now(),
    );
    habits.add(h);
    active = habits.length - 1;
    // Un valle con dos pueblos está del otro lado de la puerta por definición.
    _checkUnlock();
    _save();
    notifyListeners();
    return h;
  }

  void renameHabit(int index, {String? name, String? symbol}) {
    if (index < 0 || index >= habits.length) return;
    final h = habits[index];
    if (name != null && name.trim().isNotEmpty) h.name = name.trim();
    if (symbol != null && symbol.isNotEmpty) {
      h.symbol = resolveHabitSymbol(symbol);
    }
    _save();
    notifyListeners();
  }

  /// Para qué es esto, y qué es lo más chico que cuenta.
  ///
  /// Las dos se pueden borrar dejándolas en blanco, al revés que el nombre:
  /// un pueblo sin nombre no se puede dibujar, y un hábito sin motivo escrito
  /// es un hábito normal.
  void describeHabit(int index, {String? why, String? floor}) {
    if (index < 0 || index >= habits.length) return;
    final h = habits[index];
    if (why != null) {
      final t = why.trim();
      h.why = t.isEmpty ? null : t;
    }
    if (floor != null) {
      final t = floor.trim();
      h.floor = t.isEmpty ? null : t;
    }
    _save();
    notifyListeners();
  }

  /// Removing a habit removes its town. There is no way back, which is why the
  /// only caller asks twice.
  ///
  /// The last one can go too. A valley with nothing in it is not a state this
  /// app has — the town view would have nothing to draw — so removing the only
  /// habit leaves the same blank one you would have got on a phone that had
  /// never opened the app. That is what deleting it means: the name, the mark
  /// and every piece are gone, and the ground is empty again.
  void removeHabit(int index) {
    if (index < 0 || index >= habits.length) return;
    habits.removeAt(index);
    if (habits.isEmpty) habits.add(_blankHabit());
    if (active >= habits.length) active = habits.length - 1;
    integrityAtLaunch = integrity;
    _save();
    notifyListeners();
  }

  /// The habit a valley starts with: no name worth keeping, no pieces, the
  /// first plot.
  static Habit _blankHabit() => Habit(
    id: 'h${DateTime.now().microsecondsSinceEpoch}',
    name: 'Mi hábito',
    symbol: kDefaultHabitSymbol,
    slot: 0,
    createdAt: DateTime.now(),
  );

  /// Quita la última pieza puesta.
  ///
  /// Es lo único en toda la app que le quita algo a un pueblo, y existe por un
  /// motivo concreto y aburrido: un dedo que se apoya solo, un bolsillo, un
  /// toque de más. Un logro que no pasó no tiene por qué quedar en piedra.
  ///
  /// La crónica de obra no se toca. Si esa pieza era la primera de un edificio,
  /// ese edificio sigue escrito y sigue siendo el que se va a construir — que
  /// es lo correcto: lo que se decidió, se decidió, y deshacer un dedo no es
  /// motivo para volver a sortear qué se está levantando.
  Piece? removeLastPiece() {
    if (habit.pieces.isEmpty) return null;
    final gone = habit.pieces.removeLast();
    integrityAtLaunch = integrity;
    preview = null;
    _save();
    notifyListeners();
    return gone;
  }

  void select(int index) {
    if (index < 0 || index >= habits.length || index == active) return;
    active = index;
    preview = null;
    integrityAtLaunch = integrity;
    _save();
    notifyListeners();
  }

  /// Which habit has laid the most pieces, or null while there is nothing to
  /// compare — one habit is not a valley, and a valley where nobody has begun
  /// has no leader either.
  ///
  /// Ties go to whoever got there first, so the crown never flickers between
  /// two towns on the same count.
  int? get leader {
    if (habits.length < 2) return null;
    var best = -1;
    for (var i = 0; i < habits.length; i++) {
      if (habits[i].total <= 0) continue;
      if (best < 0 ||
          habits[i].total > habits[best].total ||
          (habits[i].total == habits[best].total &&
              habits[i].createdAt.isBefore(habits[best].createdAt))) {
        best = i;
      }
    }
    return best < 0 ? null : best;
  }

  // ------------------------------------------------------------------- state

  Future<void> load() async {
    // Storage must never be able to hold the app hostage: if the platform
    // channel is slow or unavailable we carry on in memory.
    try {
      _prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      _prefs = null;
    }
    final raw = _prefs?.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        _decode(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        habits.clear();
      }
    } else {
      _adoptTheWall();
    }
    if (habits.isEmpty) habits.add(_blankHabit());
    active = active.clamp(0, habits.length - 1);
    // Una copia guardada por una versión anterior no trae crónica. Se escribe
    // aquí, con el catálogo de hoy, y de ahí en adelante ya no se recalcula.
    // Y si los días que ya llevaba puestos abren la puerta, queda escrito al
    // arrancar y no la primera vez que ponga una pieza: nadie tiene que poner
    // una más para cobrar algo que ya se había ganado.
    var moved = _checkUnlock();
    if (_writeUpWorks(habit) || _writeUpAll()) moved = true;
    if (moved) _save();
    integrityAtLaunch = integrity;
    loaded = true;
    notifyListeners();
  }

  /// Everything laid back when this was one wall becomes the first habit's
  /// town. Nobody loses a year of work to a change of mind about the app.
  void _adoptTheWall() {
    final raw =
        _prefs?.getString(_wallKey) ?? _prefs?.getString(_wallLegacyKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final list =
          ((j['bricks'] as List?) ?? [])
              .map((e) => Piece.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.index.compareTo(b.index));
      for (var i = 0; i < list.length; i++) {
        list[i] = Piece(
          index: i,
          placedAt: list[i].placedAt,
          label: list[i].label,
        );
      }
      if (list.isEmpty) return;
      habits.add(
        Habit(
          id: 'h0',
          name: 'Mi hábito',
          symbol: kDefaultHabitSymbol,
          slot: 0,
          createdAt: list.first.placedAt,
          pieces: list,
        ),
      );
    } catch (_) {
      // A save from a version that no longer exists is not worth crashing for.
    }
  }

  void _decode(Map<String, dynamic> j) {
    habits
      ..clear()
      ..addAll(
        ((j['h'] as List?) ?? []).map(
          (e) => Habit.fromJson(e as Map<String, dynamic>),
        ),
      );
    active = (j['a'] as num?)?.toInt() ?? 0;
    // El candado llegó después que la app, así que una copia anterior no lo
    // trae — y un valle que ya tenía varios pueblos cuando esto no existía es,
    // por definición, un valle que ya está del otro lado de la puerta. Se
    // marca abierto y no se le pregunta nada. Nadie pierde un pueblo por una
    // regla que se inventó después de que lo fundara.
    _unlocked = (j['u'] as bool?) ?? habits.length > 1;
    // `sky` —el cuaderno de constelaciones— se lee y se tira: al no volver a
    // escribirse, el disco se limpia solo en el primer guardado.
  }

  Map<String, dynamic> _encode() => {
    'v': 1,
    'a': active,
    if (_unlocked) 'u': true,
    'h': habits.map((h) => h.toJson()).toList(),
  };

  // ------------------------------------------------------- taking it with you

  /// Everything this app knows about you, as one line of text.
  ///
  /// Because a town should not be able to disappear for a reason that has
  /// nothing to do with you. A phone gets lost, a signing key changes and
  /// Android refuses the update, somebody clears an app's storage by mistake —
  /// none of those are your fault and none of them should cost you a year of
  /// mornings. This is the same thing the app writes to storage, handed over
  /// so you can keep it somewhere it is yours.
  ///
  /// It is plain JSON on purpose. Not compressed, not encoded: it is your
  /// history and you should be able to open it and see it — the dates you laid
  /// each piece and what you wrote on them, in the order they happened.
  String exportSave() => jsonEncode(_encode());

  /// What [exportSave] wrote, read back. Returns null when it worked, and the
  /// reason in Spanish when it did not.
  ///
  /// All or nothing: everything is parsed into a new list first, and the
  /// habits this store is holding are not touched until the whole thing has
  /// come back clean. A restore that half-worked would be worse than one that
  /// refused, because it would look like it had worked.
  String? importSave(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return 'No hay nada pegado.';
    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      return 'Eso no es una copia de La Muralla.';
    }
    if (parsed is! Map<String, dynamic>) {
      return 'Eso no es una copia de La Muralla.';
    }
    final list = parsed['h'];
    if (list is! List) return 'A esa copia le falta la lista de pueblos.';
    final read = <Habit>[];
    try {
      for (final e in list) {
        read.add(Habit.fromJson(e as Map<String, dynamic>));
      }
    } catch (_) {
      return 'Esa copia está rota: no pude leer uno de los pueblos.';
    }
    if (read.isEmpty) return 'Esa copia no tiene ningún pueblo dentro.';
    if (read.length > Habit.maxSlots) {
      return 'Esa copia trae ${read.length} pueblos y el valle tiene sitio '
          'para ${Habit.maxSlots}.';
    }
    habits
      ..clear()
      ..addAll(read);
    active = ((parsed['a'] as num?)?.toInt() ?? 0).clamp(0, habits.length - 1);
    // Lo mismo que al cargar: una copia con varios pueblos dentro ya está del
    // otro lado de la puerta, la traiga escrito o no. Restaurar una copia no
    // puede devolverte a un valle donde tus propios pueblos no cabrían.
    _unlocked = (parsed['u'] as bool?) ?? habits.length > 1;
    _checkUnlock();
    preview = null;
    _writeUpAll();
    integrityAtLaunch = integrity;
    _save();
    notifyListeners();
    return null;
  }

  /// How much is in a copy, for saying so out loud before and after.
  String describe() {
    final towns = habits.length;
    final pieces = habits.fold<int>(0, (n, h) => n + h.total);
    return '$pieces ${pieces == 1 ? 'pieza' : 'piezas'} en '
        '$towns ${towns == 1 ? 'pueblo' : 'pueblos'}';
  }

  void _save() {
    _dirty = true;
    // Writes are cheap but not free; coalesce bursts into one write.
    Future.microtask(() {
      if (!_dirty) return;
      _dirty = false;
      _prefs?.setString(_key, jsonEncode(_encode()));
    });
  }

  // ----------------------------------------------------------------- placing

  /// The one and only way a town grows. One call, one piece.
  PlaceResult placePiece() {
    final now = DateTime.now();
    final before = integrity;
    final hadToday = _countOn(now) > 0;
    // Poner una pieza durante una pausa es volver, y volver antes de tiempo es
    // volver. Nadie tiene que despertar el pueblo a mano para poder usarlo.
    final wasResting = habit.resting;
    if (wasResting) wake(habit, silent: true);

    final piece = Piece(index: habit.total, placedAt: now);
    habit.pieces.add(piece);
    // Y si esta pieza empieza un edificio nuevo, queda escrito qué edificio es.
    _writeUpWorks(habit);
    final abrio = _checkUnlock();

    _save();
    notifyListeners();

    return PlaceResult(
      piece: piece,
      relit: before < 0.999,
      relitFrom: before,
      startedNewDay: !hadToday,
      woke: wasResting,
      unlocked: abrio,
    );
  }

  /// Writes (or clears) the note on a piece. Always optional.
  void setLabel(int index, String? text) {
    final list = habit.pieces;
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].withLabel(text);
    _save();
    notifyListeners();
  }

  /// Corrige la hora a la que se puso una pieza.
  ///
  /// Nunca hacia el futuro: una pieza puesta dentro de tres horas rompe todo
  /// lo que mide el tiempo desde la última —el deterioro, la racha, lo que el
  /// tablón va notando— y no significa nada. Lo que pase de ahora se recorta a
  /// ahora, en silencio, porque es lo único que puede querer decir.
  void setPlacedAt(int index, DateTime when) {
    final list = habit.pieces;
    if (index < 0 || index >= list.length) return;
    final now = DateTime.now();
    final cuando = when.isAfter(now) ? now : when;
    if (cuando == list[index].placedAt) return;
    list[index] = list[index].withWhen(cuando);
    _save();
    notifyListeners();
  }

  Piece? pieceAt(int index) {
    final list = habit.pieces;
    return index >= 0 && index < list.length ? list[index] : null;
  }

  List<Piece> get pieces => habit.pieces;

  List<Piece> get labelled =>
      habit.pieces.where((p) => p.hasLabel).toList().reversed.toList();

  /// Undo for the fat-finger case: only the most recent piece, only for a
  /// couple of minutes.
  bool canUndoLast() {
    if (habit.pieces.isEmpty) return false;
    return DateTime.now().difference(habit.pieces.last.placedAt).inMinutes < 2;
  }

  void undoLast() {
    if (!canUndoLast()) return;
    habit.pieces.removeLast();
    _save();
    notifyListeners();
  }

  // ------------------------------------------------------------------- decay

  static double daysIdleOf(Habit h) {
    final last = h.lastPlacedAt;
    if (last == null) return 0;
    // Dormido no es abandonado: mientras dura la pausa no corre el reloj.
    if (h.resting) return 0;
    // Y al despertar se cuenta desde que despertó, no desde la última pieza.
    // Es la mitad de para lo que existe una pausa: se vuelve sin deuda, con el
    // día y medio de gracia entero, y no arrastrando las tres semanas que el
    // pueblo estuvo durmiendo con las luces encendidas.
    final woke = h.wokeAt;
    final since = woke != null && woke.isAfter(last) ? woke : last;
    final d = DateTime.now().difference(since).inMinutes / 1440.0;
    return d < 0 ? 0 : d;
  }

  static double integrityOf(Habit h) =>
      h.pieces.isEmpty ? 1.0 : Pacing.integrityFor(daysIdleOf(h));

  double get daysIdle => daysIdleOf(habit);
  double get integrity => integrityOf(habit);
  bool get isDecaying => integrity < 0.995;

  // ------------------------------------------------------------ consistencia

  // Acá vivían la racha y la mejor racha. Ya no.
  //
  // Una racha es atractiva porque se entiende sola y se ve bonita, y tiene un
  // defecto psicológico que se lleva por delante todo lo demás: hace que el
  // pasado pese demasiado. Con cuarenta días detrás y un fallo hoy parece que
  // pasaste de cuarenta a cero — pero tu comportamiento no hizo eso. Hiciste
  // el hábito cuarenta días y hoy no.
  //
  // Una racha te dice «no rompas esto». La consistencia te dice «en general,
  // lo estás haciendo». Lo segundo es lo único que se puede decir de algo
  // sostenible, porque la sostenibilidad admite imperfección por definición.
  //
  // No quedó ninguna en ningún rincón de la app a propósito: dejarla escondida
  // en una hoja secundaria sería seguir diciendo que importa.

  Consistency get consistency => consistencyOf(habit);

  /// Cuánto tardás en volver. Ver [typicalReturn].
  int? get comingBack => typicalReturn(habit);

  /// Cuántas piezas lleva hoy este pueblo.
  ///
  /// Del día natural y no de las últimas veinticuatro horas: lo que se está
  /// contestando es «¿qué hice hoy?», y hoy empieza a medianoche aunque uno
  /// siga despierto.
  int get today => _countOn(DateTime.now());

  int _countOn(DateTime when) {
    final k = dayKey(when);
    var n = 0;
    for (final p in habit.pieces) {
      if (dayKey(p.placedAt) == k) n++;
    }
    return n;
  }

  List<DayTally> lastDays(int days) {
    final counts = <int, int>{};
    for (final p in habit.pieces) {
      counts.update(dayKey(p.placedAt), (v) => v + 1, ifAbsent: () => 1);
    }
    final today = dayStart(DateTime.now());
    return List.generate(days, (i) {
      final d = today.subtract(Duration(days: days - 1 - i));
      return DayTally(d, counts[dayKey(d)] ?? 0);
    });
  }

  /// What the town is putting up right now.
  String get nextEventLabel {
    final work = plan.underway(shownTotal, habit.chronicle);
    if (work == null) return 'El pueblo sigue creciendo';
    final left = work.$2;
    return left == 1
        ? 'Una pieza más y ${work.$1} queda en pie'
        : '${work.$1} · faltan $left';
  }

  Future<void> wipe() async {
    habits.clear();
    habits.add(
      Habit(
        id: 'h${DateTime.now().microsecondsSinceEpoch}',
        name: 'Mi hábito',
        symbol: kDefaultHabitSymbol,
        slot: 0,
        createdAt: DateTime.now(),
      ),
    );
    active = 0;
    // Un valle en blanco es un valle en blanco: la puerta vuelve a estar
    // cerrada, igual que en un teléfono que nunca abrió la app.
    _unlocked = false;
    await _prefs?.remove(_key);
    integrityAtLaunch = 1.0;
    notifyListeners();
  }

  /// Fast-forwards a town for development, so a year of use can be looked at
  /// without waiting a year. Driven by a compile-time define, off by default.
  static const List<String> _debugLabels = [
    'Leí',
    'Corrí',
    'Estudié',
    'Escribí',
    'No fumé',
    'Salí a caminar',
    'Llamé a mamá',
    'Ordené el taller',
    'Toqué la guitarra',
    'Nadé',
  ];

  /// Fast-forwards a town for development, so a year of use can be looked at
  /// without waiting a year.
  ///
  /// It lays them the way a person would: one on most days at an hour this
  /// habit favours, a weekday it tends to skip, the odd double day, and misses
  /// that come in runs rather than scattered evenly — because a blank day
  /// really does drag the next one. Pieces every 137 minutes round the clock
  /// would fill the town just as fast and be no use at all for looking at
  /// anything that reads the shape of a history rather than its length.
  void debugFill(int count, {int endedDaysAgo = 0, int? into}) {
    if (count <= 0) return;
    final h = habits[(into ?? active).clamp(0, habits.length - 1)];
    final s = hash32(h.slot + 1, 0x0FEED, 3);
    final hour = 6 + hash32(s, 1, 1) % 15;
    final weak = 1 + hash32(s, 2, 1) % 7;
    final end = dayStart(DateTime.now().subtract(Duration(days: endedDaysAgo)));
    final when = <DateTime>[];
    var day = 0;
    var missed = false;
    while (when.length < count && day < count * 6 + 60) {
      final d = end.subtract(Duration(days: day));
      final r = hash01(s, 7, day);
      var miss = r < 0.16;
      if (d.weekday == weak) miss = r < 0.66;
      if (missed && r < 0.45) miss = true;
      missed = miss;
      if (!miss) {
        final m = hashRange(-40, 55, s, 8, day).round();
        when.add(d.add(Duration(hours: hour, minutes: m)));
        if (hash01(s, 9, day) < 0.12 && when.length < count) {
          when.add(d.add(Duration(hours: hour + 4, minutes: m ~/ 2)));
        }
      }
      day++;
    }
    when.sort();
    for (var i = 0; i < when.length; i++) {
      h.pieces.add(
        Piece(
          index: h.total,
          placedAt: when[i],
          label: i % 9 == 3
              ? _debugLabels[(i ~/ 9) % _debugLabels.length]
              : null,
        ),
      );
    }
    _writeUpWorks(h);
    integrityAtLaunch = integrity;
    notifyListeners();
  }
}
