import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/advice.dart';
import '../l10n/lang.dart';
import 'cadence.dart';
import 'habit.dart';
import 'piece.dart';
import 'stumble.dart';

/// La libreta del consejero: qué consejos ganaste, y cuándo.
///
/// **Una sola, tuya.** Los consejos son para quien usa la app, no para cada
/// pueblo: el consejero es el mismo viejo en todas las plazas, y lo que te
/// dijo en una lo sabés en todas.
///
/// Lo que sí es de cada pueblo es la respuesta a su pregunta —¿sembrar algo
/// o arrancar algo?— ([setGoal]), porque cada pueblo es un hábito y no es lo
/// mismo empezar a leer que dejar de fumar. De esas respuestas sale el camino
/// de consejos: si todos tus pueblos siembran, el de sembrar; si todos
/// arrancan, el de arrancar; si hay de los dos, uno y uno, alternando. Hasta
/// que no se contesta ninguna, no da consejos, porque no sabe cuáles dar.
///
/// Se gana uno del camino por cada **día que se entra**, no por cada día que
/// pasa: quien vuelve después de dos semanas encuentra uno nuevo, no catorce.
/// Y los de [eventAdvice] cuando pasa lo que los gana, una sola vez cada uno;
/// ésos sí pueden caer el mismo día que el del camino.
///
/// Lo que se ve en la libreta es todo lo ganado, del más nuevo al más viejo,
/// y sólo lo aprobado ([approvedAdvice]). Se guarda en el teléfono y no viaja
/// a la nube.
class AdviceBook extends ChangeNotifier {
  AdviceBook._();
  static final AdviceBook instance = AdviceBook._();

  static const String _key = 'consejero_v3';
  static const String _goalKey = 'consejero_busca_v1';
  static const String _sep = '\u0001';

  /// Lo ganado, en el orden en que se ganó: id y momento.
  final List<(String, DateTime)> _got = [];

  /// Por qué se ganó cada uno, cuando fue por algo que pasó.
  final Map<String, AdviceReason> _why = {};

  /// Pueblo -> lo que se busca con él.
  final Map<String, AdviceGoal> _goals = {};

  /// Si ya se presentó: la presentación es una vez en la vida.
  bool _met = false;
  static const String _metKey = 'consejero_conocido_v1';

  /// Si ya se presentó. Quien ya le había contestado algo lo conoce, aunque
  /// sea de antes de que se presentara.
  bool get met => _met || _goals.isNotEmpty;

  /// Ya se presentó.
  void meet() {
    if (_met) return;
    _met = true;
    unawaited(flush());
    notifyListeners();
  }

  /// Cuándo fue la última charla de la semana: «¿cómo fue el camino?».
  /// Nula hasta que se empieza a contar, que es la primera vez que se mira
  /// si toca ([weekDue]).
  DateTime? _weekAt;
  static const String _weekKey = 'consejero_semana_v1';

  /// Lo contestado en cada una, `milisegundos|cómo|qué costó`: para que el
  /// viejo pueda algún día decir cómo vienen siendo tus semanas.
  final List<String> _weeks = [];
  static const String _weeksKey = 'consejero_semanas_v1';

  /// Lo contestado en las charlas de la semana, de la más vieja a la más
  /// nueva.
  List<String> get weeks => List.unmodifiable(_weeks);

  /// Si ya toca la charla de la semana: siete días desde la última. La
  /// primera vez que se pregunta empieza a contar, y no toca todavía —que
  /// recién lo conocés—.
  bool weekDue({DateTime? at}) {
    final now = at ?? DateTime.now();
    if (!met) return false;
    final desde = _weekAt;
    if (desde == null) {
      _weekAt = now;
      unawaited(flush());
      return false;
    }
    return daysBetween(desde, now) >= 7;
  }

  /// Que la charla de la semana se tuvo, con lo que se contestó.
  void weekDone({DateTime? at, required String how, String cost = ''}) {
    final now = at ?? DateTime.now();
    _weekAt = now;
    _weeks.add('${now.millisecondsSinceEpoch}|$how|$cost');
    unawaited(flush());
    notifyListeners();
  }

  /// Pueblo -> cuándo se habló de sus descansos raros: las pausas de antes de
  /// eso ya se hablaron, y no vuelven a contar para la próxima.
  final Map<String, DateTime> _restTalks = {};
  static const String _restTalksKey = 'consejero_pausas_v1';

  /// Cuándo se habló de los descansos de [town], o nulo si nunca.
  DateTime? restTalkAt(String town) => _restTalks[town];

  /// Que ya se habló de los descansos de [town].
  void restTalked(String town, {DateTime? at}) {
    _restTalks[town] = at ?? DateTime.now();
    unawaited(flush());
  }

  /// Los que ya se miraron, para el punto del botón.
  final Set<String> _seen = {};
  static const String _seenKey = 'consejero_visto_v1';

  Future<void> load() async {
    _got.clear();
    _why.clear();
    _goals.clear();
    _seen.clear();
    _met = false;
    _weekAt = null;
    _weeks.clear();
    _restTalks.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final row in prefs.getStringList(_key) ?? const <String>[]) {
        // id|momento, y detrás, si lo hay, el motivo.
        final partes = row.split('|');
        if (partes.length < 2) continue;
        final id = partes[0];
        final ms = int.tryParse(partes[1]);
        if (ms == null || !adviceById.containsKey(id)) continue;
        _got.add((id, DateTime.fromMillisecondsSinceEpoch(ms)));
        if (partes.length >= 3) {
          final r = AdviceReason.decode(partes[2]);
          if (r != null) _why[id] = r;
        }
      }
      _seen.addAll(prefs.getStringList(_seenKey) ?? const <String>[]);
      _met = prefs.getBool(_metKey) ?? false;
      final semana = prefs.getInt(_weekKey);
      if (semana != null) {
        _weekAt = DateTime.fromMillisecondsSinceEpoch(semana);
      }
      _weeks.addAll(prefs.getStringList(_weeksKey) ?? const <String>[]);
      for (final row
          in prefs.getStringList(_restTalksKey) ?? const <String>[]) {
        final cut = row.lastIndexOf('|');
        final ms = cut > 0 ? int.tryParse(row.substring(cut + 1)) : null;
        if (ms == null) continue;
        _restTalks[row.substring(0, cut)] = DateTime.fromMillisecondsSinceEpoch(
          ms,
        );
      }
      for (final row in prefs.getStringList(_goalKey) ?? const <String>[]) {
        final a = row.indexOf(_sep);
        if (a <= 0) continue;
        final g = AdviceGoal.values.where(
          (g) => g.name == row.substring(a + 1),
        );
        if (g.isNotEmpty) _goals[row.substring(0, a)] = g.first;
      }
    } catch (_) {
      // Sin preferencias, la libreta empieza de cero.
    }
    notifyListeners();
  }

  /// Lo que busca el pueblo [habitId], o nulo si todavía no se le contestó.
  AdviceGoal? goalOf(String habitId) => _goals[habitId];

  /// La respuesta a la pregunta del consejero en ese pueblo.
  void setGoal(String habitId, AdviceGoal goal) {
    _goals[habitId] = goal;
    unawaited(flush());
    notifyListeners();
  }

  /// Lo que se ganó, antes de que el viejo esperara a que confirmes, por
  /// faltas que nadie confirmó: se borra como un error.
  ///
  /// Antes un día sin pieza ya era faltar, aunque el ritmo fuera de cinco
  /// por semana y ese día no tocara, o el pueblo estuviera dormido. Lo que
  /// se dijo por eso se va: la falta tiene que estar confirmada en una charla
  /// ese mismo día, y el «viene costando» no vale si el pueblo dormía.
  void _forgetFalseMisses(List<Habit> habits) {
    final porNombre = {for (final h in habits) h.name: h};
    final antes = _got.length;
    _got.removeWhere((g) {
      final r = _why[g.$1];
      final h = r == null ? null : porNombre[r.town];
      if (r == null || h == null) return false;
      final bool mal;
      if (r.event == AdviceEvent.missedDay ||
          r.moment == AdviceMoment.missedYesterday) {
        final dia = r.when;
        mal =
            dia == null ||
            !stumblesOf(h).any(
              (s) => isRealStumble(s.cause) && dayKey(s.day) == dayKey(dia),
            );
      } else if (r.moment == AdviceMoment.struggling) {
        mal = h.restedOn(g.$2);
      } else {
        mal = false;
      }
      if (mal) _why.remove(g.$1);
      return mal;
    });
    if (_got.length != antes) unawaited(flush());
  }

  /// Lo que se dijo por un tropiezo de [town] que resultó no serlo: ese día
  /// no tocaba. Se quita como un error, desde [since].
  ///
  /// Es lo que se ganó por haber faltado —el «que no sean dos», el «viene
  /// costando»— en ese pueblo. Dejarlo en la libreta sería que el viejo
  /// siguiera diciendo que faltaste cuando le acabás de decir que no.
  void retractMisses(String town, DateTime since) {
    final desde = dayStart(since);
    final antes = _got.length;
    _got.removeWhere((g) {
      final r = _why[g.$1];
      if (r == null || r.town != town || g.$2.isBefore(desde)) return false;
      final fallo =
          r.event == AdviceEvent.missedDay ||
          r.moment == AdviceMoment.missedYesterday ||
          r.moment == AdviceMoment.struggling;
      if (fallo) _why.remove(g.$1);
      return fallo;
    });
    if (_got.length != antes) {
      unawaited(flush());
      notifyListeners();
    }
  }

  /// Lo ganado, del más nuevo al más viejo. Sólo lo aprobado: lo que se saca
  /// de [approvedAdvice] deja de verse aunque ya se hubiera ganado.
  List<(Advice, DateTime)> unlocked({Set<String>? approved}) {
    final ok = approved ?? approvedAdvice;
    return [
      for (final (id, at) in _got.reversed)
        if (ok.contains(id)) (adviceById[id]!, at),
    ];
  }

  /// Lo ganado y ya leído, del más nuevo al más viejo: lo que se ve en la
  /// lista del consejero. Un consejo no entra en la lista hasta que se lee.
  List<(Advice, DateTime)> read({Set<String>? approved}) => [
    for (final g in unlocked(approved: approved))
      if (_seen.contains(g.$1.id)) g,
  ];

  /// Lo ganado que todavía no se leyó, en el orden en que se ganó: lo que el
  /// viejo tiene para dar.
  List<Advice> pending({Set<String>? approved}) => [
    for (final (a, _) in unlocked(approved: approved).reversed)
      if (!_seen.contains(a.id)) a,
  ];

  /// Cuántos hay para dar: es el punto del botón.
  int unseen({Set<String>? approved}) => pending(approved: approved).length;

  /// Si ése no se leyó todavía.
  bool isNew(Advice a) => !_seen.contains(a.id);

  /// Ya se leyó: pasa a la lista.
  void markRead(Advice a) {
    if (_seen.add(a.id)) {
      unawaited(flush());
      notifyListeners();
    }
  }

  /// Darlo ahora, sin que lo gane nada: lo que da al presentarse, antes del
  /// primer pueblo ([prologueAdvice]). Queda ganado y, al leerse, en la lista.
  void give(Advice a, {DateTime? now}) {
    if (_got.any((g) => g.$1 == a.id)) return;
    _got.add((a.id, now ?? DateTime.now()));
    unawaited(flush());
    notifyListeners();
  }

  /// Si todavía ningún pueblo le contestó qué se busca con él: la pregunta,
  /// entonces, es la del primer pueblo y no la de «un pueblo nuevo…».
  bool get noGoals => _goals.isEmpty;

  /// Por qué se ganó, si fue por algo que pasó; nulo si es uno del camino de
  /// todos los días sin más.
  AdviceReason? reasonOf(Advice a) => _why[a.id];

  /// El de hoy: lo último que se ganó, si fue hoy.
  Advice? today({DateTime? now, Set<String>? approved}) {
    final todo = unlocked(approved: approved);
    if (todo.isEmpty) return null;
    final (a, at) = todo.first;
    return dayKey(at) == dayKey(now ?? DateTime.now()) ? a : null;
  }

  /// El orden en que van a salir los consejos de todos los días **hoy**,
  /// según lo que te está pasando. Vacío si ningún pueblo contestó todavía.
  ///
  /// **Lee el momento, no sigue una lista.** Con un solo hábito es su camino
  /// ([pathFor]). Con varios, manda el que más te cuesta ahora ([focusOf]):
  /// si el primero era empezar a leer y ya lo tenés andando, y el nuevo es
  /// dejar de fumar, los consejos son para dejar de fumar. Y delante de todo,
  /// lo que pide lo que acaba de pasar en ese pueblo: si ayer faltaste, que
  /// no sean dos y sin culpa; si viene costando hace días, hacerlo más chico
  /// y más fácil. Detrás, por si el camino de ése se acaba, el de los demás.
  List<String> pathOf(List<Habit> habits, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final foco = focusOf(habits, now: at);
    if (foco == null) return const [];
    final busca = _goals[foco.id]!;
    bool sirve(String id) {
      final a = adviceById[id];
      return a != null &&
          a.event == null &&
          (a.goal == null || a.goal == busca);
    }

    final out = <String>[];
    void sumar(Iterable<String> ids) {
      for (final id in ids) {
        if (sirve(id) && !out.contains(id)) out.add(id);
      }
    }

    sumar(momentAdvice(momentOf(foco, at), busca));
    sumar(pathFor(busca));
    // Y los de lo que buscan los demás, por si éste se agota.
    for (final h in habits) {
      final g = _goals[h.id];
      if (g == null || g == busca) continue;
      for (final id in pathFor(g)) {
        final a = adviceById[id]!;
        if (a.goal == null || a.goal == g) {
          if (!out.contains(id)) out.add(id);
        }
      }
    }
    return out;
  }

  /// El pueblo que más te cuesta ahora, entre los que contestaron la
  /// pregunta: el que tiene más alto [struggleOf]. Nulo si ninguno contestó.
  Habit? focusOf(List<Habit> habits, {DateTime? now}) {
    final at = now ?? DateTime.now();
    Habit? mejor;
    var cuanto = -1.0;
    for (final h in habits) {
      if (!_goals.containsKey(h.id)) continue;
      // Uno dormido no cuesta: está descansando, y a propósito.
      if (h.restAt(at) != null) continue;
      final c = struggleOf(h, at);
      // A igualdad, el más nuevo: es el que menos dominás.
      if (c > cuanto ||
          (c == cuanto &&
              mejor != null &&
              h.createdAt.isAfter(mejor.createdAt))) {
        cuanto = c;
        mejor = h;
      }
    }
    return mejor;
  }

  /// Entrar a la app: gana el de hoy, si no se ganó ya, y los de lo que haya
  /// pasado. Devuelve los nuevos, en el orden en que se ganaron.
  List<Advice> visit(
    List<Habit> habits, {
    DateTime? now,
    Set<String>? approved,
  }) {
    final ok = approved ?? approvedAdvice;
    final at = now ?? DateTime.now();
    final camino = pathOf(habits, now: at);
    if (camino.isEmpty) return const [];
    _forgetFalseMisses(habits);
    final ya = {for (final (id, _) in _got) id};
    final nuevos = <Advice>[];
    void ganar(Advice a, [AdviceReason? por]) {
      if (!ok.contains(a.id) || !ya.add(a.id)) return;
      _got.add((a.id, at));
      if (por != null) _why[a.id] = por;
      nuevos.add(a);
    }

    // Lo que pasó va antes que el del día: es lo más oportuno, y así el del
    // día queda arriba como el último ganado.
    for (final r in reasonsOf(habits, _goals)) {
      for (final a in eventAdvice) {
        if (a.event != r.event) continue;
        if (a.goal != null && a.goal != r.goal) continue;
        ganar(a, r);
      }
    }
    final hoy = dayKey(at);
    // Los de la presentación no son el del día: el día que se funda el
    // primer pueblo, el viejo ya tiene uno nuevo.
    final yaHoy = _got.any(
      (g) =>
          dayKey(g.$2) == hoy &&
          adviceById[g.$1]!.event == null &&
          !prologueAdvice.contains(g.$1),
    );
    if (!yaHoy) {
      // Si lo que sale primero es por lo que le está pasando al pueblo que
      // más cuesta, también se dice por qué.
      final foco = focusOf(habits, now: at);
      final momento = foco == null ? AdviceMoment.steady : momentOf(foco, at);
      final porMomento = foco == null || momento == AdviceMoment.steady
          ? const <String>{}
          : momentAdvice(momento, _goals[foco.id]!).toSet();
      for (final id in camino) {
        if (ya.contains(id) || !ok.contains(id)) continue;
        ganar(
          adviceById[id]!,
          porMomento.contains(id)
              ? AdviceReason(
                  moment: momento,
                  town: foco!.name,
                  when: momento == AdviceMoment.missedYesterday
                      ? lastConfirmedStumble(foco)?.day
                      : null,
                )
              : null,
        );
        break;
      }
    }
    if (nuevos.isNotEmpty) {
      unawaited(flush());
      notifyListeners();
    }
    return nuevos;
  }

  Future<void> flush() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [
        for (final (id, at) in _got)
          [
            id,
            '${at.millisecondsSinceEpoch}',
            if (_why[id] != null) _why[id]!.encode(),
          ].join('|'),
      ]);
      await prefs.setStringList(_seenKey, _seen.toList());
      await prefs.setBool(_metKey, _met);
      if (_weekAt != null) {
        await prefs.setInt(_weekKey, _weekAt!.millisecondsSinceEpoch);
      } else {
        await prefs.remove(_weekKey);
      }
      await prefs.setStringList(_weeksKey, _weeks);
      await prefs.setStringList(_restTalksKey, [
        for (final MapEntry(key: town, value: at) in _restTalks.entries)
          '$town|${at.millisecondsSinceEpoch}',
      ]);
      await prefs.setStringList(_goalKey, [
        for (final MapEntry(key: town, value: g) in _goals.entries)
          '$town$_sep${g.name}',
      ]);
    } catch (_) {}
  }

  /// La libreta en blanco: para los tests, y para empezar de cero. Hay que
  /// llamar a [flush] después para que lo borrado no vuelva al abrir la app.
  void forget() {
    _met = false;
    _got.clear();
    _why.clear();
    _goals.clear();
    _seen.clear();
    _weekAt = null;
    _weeks.clear();
    _restTalks.clear();
    notifyListeners();
  }
}

/// Los consejos que se adelantan en el camino por lo que le está pasando a
/// un pueblo: si ayer faltó, que no sean dos y sin culpa; si viene costando
/// hace días, hacerlo más chico y más fácil.
List<String> momentAdvice(AdviceMoment m, AdviceGoal busca) => switch (m) {
  AdviceMoment.missedYesterday => [
    'nodosveces',
    'nojuzgar',
    'q_recaida',
    'diamalo',
  ],
  AdviceMoment.struggling =>
    busca == AdviceGoal.start
        ? ['chico', 'diamalo', 'estorbos', 'dosminutos', 'ambiente']
        : ['q_dificil', 'reemplazo', 'q_sed', 'diamalo', 'q_ola'],
  AdviceMoment.steady => const [],
};

/// Lo que ya pasó en el valle, de lo que gana consejos: cada cosa, con lo
/// que busca el pueblo en que pasó (nulo si ese pueblo no contestó). Ver
/// [reasonsOf], que dice además dónde y cuándo.
Set<(AdviceEvent, AdviceGoal?)> eventsOf(
  List<Habit> habits, [
  Map<String, AdviceGoal> goals = const {},
]) => {for (final r in reasonsOf(habits, goals)) (r.event!, r.goal)};

/// Lo que ya pasó en el valle, de lo que gana consejos, con en qué pueblo y
/// cuándo: es lo que el viejo dice debajo de cada consejo que ganó por algo.
/// De cada cosa, la última vez que pasó en cada pueblo.
///
/// Sale de lo que está guardado y nada más —las piezas con su fecha, los
/// pueblos, las notas, las pausas—, así que no hace falta apuntar nada aparte
/// para enterarse: quien ya tenía dos pueblos cuando apareció el consejero
/// lo oye la primera vez que entra.
List<AdviceReason> reasonsOf(
  List<Habit> habits, [
  Map<String, AdviceGoal> goals = const {},
]) {
  final out = <AdviceReason>[];
  // El segundo que se fundó, con lo que busca. Del tercero en adelante no
  // se dice nada a propósito: quien abre un pueblo nuevo es porque sostuvo
  // los que tenía, y el viejo no le advierte que son muchos.
  final orden = [...habits]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  for (final (k, e) in [(1, AdviceEvent.secondTown)]) {
    if (orden.length <= k) continue;
    final h = orden[k];
    out.add(
      AdviceReason(
        event: e,
        goal: goals[h.id],
        town: h.name,
        when: h.createdAt,
      ),
    );
  }
  for (final h in habits) {
    final busca = goals[h.id];
    void pasa(AdviceEvent e, {DateTime? when, int n = 0}) => out.add(
      AdviceReason(event: e, goal: busca, town: h.name, when: when, n: n),
    );
    if (h.total > 0) {
      pasa(
        AdviceEvent.firstPiece,
        when: h.pieces.isEmpty ? null : h.pieces.first.placedAt,
      );
    }
    if (h.total >= 100) {
      pasa(
        AdviceEvent.hundred,
        when: h.pieces.length >= 100 ? h.pieces[99].placedAt : null,
      );
    }
    if (h.vowHour != null || (h.vowPlace?.trim().isNotEmpty ?? false)) {
      pasa(AdviceEvent.plan);
    }
    if (h.notes.isNotEmpty) pasa(AdviceEvent.ownNote);
    if (h.rests.isNotEmpty) {
      pasa(AdviceEvent.rested, when: Rest.parse(h.rests.last)?.from);
    }
    // Los días con pieza, en orden, y los huecos entre ellos.
    final dias = <DateTime>[];
    var ultimo = -1;
    for (final p in h.pieces) {
      final k = dayKey(p.placedAt);
      if (k == ultimo) continue;
      ultimo = k;
      dias.add(dayStart(p.placedAt));
    }
    final distintos = <int>[];
    final vistos = <int>{};
    for (final d in dias) {
      if (vistos.add(dayKey(d))) distintos.add(dayKey(d));
    }
    DateTime? diaN(int n) {
      if (distintos.length < n) return null;
      final k = distintos[n - 1];
      return DateTime(k ~/ 10000, (k ~/ 100) % 100, k % 100);
    }

    if (distintos.length >= 7) pasa(AdviceEvent.week, when: diaN(7));
    if (distintos.length >= 30) pasa(AdviceEvent.month, when: diaN(30));
    // Volver es volver de un hueco más largo que tus días libres, y sin
    // contar los dormidos: a quien va tres veces por semana, tres días sin
    // pieza son lo normal.
    final libres = math.max(0, (7 - perWeekOf(h)).floor());
    DateTime? volvio;
    var tras = 0;
    for (var i = 1; i < dias.length; i++) {
      var blancos = 0;
      for (
        var d = dias[i - 1].add(const Duration(days: 1));
        d.isBefore(dias[i]);
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        if (!h.restedOn(d)) blancos++;
      }
      if (blancos >= math.max(3, libres + 2)) {
        volvio = dias[i];
        tras = blancos;
      }
    }
    // Faltar, sólo lo que confirmaste: un día sin pieza puede ser un día que
    // no tocaba, y el viejo no lo da por hecho hasta que se lo decís.
    final falto = lastConfirmedStumble(h)?.day;
    if (falto != null) pasa(AdviceEvent.missedDay, when: falto);
    if (volvio != null) pasa(AdviceEvent.comeback, when: volvio, n: tras);
  }
  return out;
}

/// Por qué el viejo dijo un consejo: lo que pasó, en qué pueblo y cuándo.
///
/// Se guarda con el consejo al ganarlo, y no se vuelve a calcular: lo que
/// dice es lo que pasó entonces, aunque después el pueblo cambie de nombre.
class AdviceReason {
  const AdviceReason({
    this.event,
    this.moment,
    this.goal,
    required this.town,
    this.when,
    this.n = 0,
  });

  /// Lo que pasó, si fue algo que pasó.
  final AdviceEvent? event;

  /// Lo que le estaba pasando, si es uno del camino adelantado por eso.
  final AdviceMoment? moment;

  /// Lo que busca el pueblo; no se guarda, sólo sirve para elegir.
  final AdviceGoal? goal;

  final String town;
  final DateTime? when;

  /// Un número que acompaña: cuántos días de silencio, en una vuelta.
  final int n;

  /// Dicho por el viejo, debajo del consejo.
  String get text {
    final t = town.trim().isEmpty ? tr('el pueblo', 'the town') : town.trim();
    final w = when;
    final dia = w == null ? '' : '${w.day}/${w.month}';
    final el = w == null ? '' : tr('el $dia ', 'on $dia ');
    final m = moment;
    if (m != null) {
      return (switch (m) {
        AdviceMoment.missedYesterday => tr(
          'Porque $el no hubo pieza en $t.',
          'Because ${el}there was no piece in $t.',
        ),
        AdviceMoment.struggling => tr(
          'Porque a $t le están faltando piezas estos días.',
          'Because $t has been missing pieces these days.',
        ),
        AdviceMoment.steady => '',
      }).replaceAll('  ', ' ');
    }
    return (switch (event!) {
      AdviceEvent.firstPiece => tr(
        'Porque $el se puso la primera pieza de $t.',
        'Because ${el}the first piece of $t was laid.',
      ),
      AdviceEvent.secondTown => tr(
        'Porque $el se fundó $t, el segundo pueblo del valle.',
        'Because $el$t was founded, the second town in the valley.',
      ),
      AdviceEvent.week => tr(
        'Porque $el $t cumplió siete días con pieza.',
        'Because $el$t reached seven days with a piece.',
      ),
      AdviceEvent.month => tr(
        'Porque $el $t cumplió treinta días con pieza.',
        'Because $el$t reached thirty days with a piece.',
      ),
      AdviceEvent.missedDay => tr(
        'Porque $el no hubo pieza en $t.',
        'Because ${el}there was no piece in $t.',
      ),
      AdviceEvent.comeback => tr(
        'Porque $el se volvió a $t, tras $n días de silencio.',
        'Because ${el}someone came back to $t, after $n days of silence.',
      ),
      AdviceEvent.plan => tr(
        'Porque en el tablón de $t quedó escrito cuándo o dónde.',
        'Because the board of $t now says when or where.',
      ),
      AdviceEvent.ownNote => tr(
        'Porque en el tablón de $t se clavó una nota propia.',
        'Because a note of your own was pinned on the board of $t.',
      ),
      AdviceEvent.rested => tr(
        'Porque $el $t se echó a dormir un tiempo.',
        'Because $el$t lay down to sleep for a while.',
      ),
      AdviceEvent.hundred => tr(
        'Porque $el $t llegó a cien piezas.',
        'Because $el$t reached a hundred pieces.',
      ),
      AdviceEvent.prologue => '',
    }).replaceAll('  ', ' ');
  }

  String encode() => [
    event?.name ?? '',
    moment?.name ?? '',
    Uri.encodeComponent(town),
    '${when?.millisecondsSinceEpoch ?? ''}',
    '$n',
  ].join('\u0002');

  static AdviceReason? decode(String s) {
    final p = s.split('\u0002');
    if (p.length < 5) return null;
    final e = AdviceEvent.values.where((e) => e.name == p[0]);
    final m = AdviceMoment.values.where((m) => m.name == p[1]);
    if (e.isEmpty && m.isEmpty) return null;
    final ms = int.tryParse(p[3]);
    return AdviceReason(
      event: e.isEmpty ? null : e.first,
      moment: m.isEmpty ? null : m.first,
      town: Uri.decodeComponent(p[2]),
      when: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
      n: int.tryParse(p[4]) ?? 0,
    );
  }
}

/// Cuánto te está costando un hábito ahora mismo, de 0 a 1.
///
/// Dos cosas: qué tan nuevo es —lo que empezaste la semana pasada no lo
/// dominás como lo que llevás un año— y cuántos de los últimos días apareciste
/// (hasta catorce, o desde que lo fundaste si hace menos). Pesa más lo
/// segundo: un hábito viejo que se está cayendo cuesta más que uno nuevo que
/// anda.
double struggleOf(Habit h, DateTime now) {
  final edad = daysBetween(h.createdAt, now) + 1;
  // Contra su ritmo y sin los días dormidos: cinco de siete en uno de cinco
  // por semana es ir perfecto, no ir flojo.
  final (hubo, esperado) = _contraRitmo(h, now);
  final ritmo = esperado <= 0 ? 1.0 : (hubo / esperado).clamp(0.0, 1.0);
  final nuevo = 1 / (1 + edad / 14);
  return 0.6 * (1 - ritmo) + 0.4 * nuevo;
}

/// Lo que le está pasando a un hábito, para elegir qué decir.
enum AdviceMoment {
  /// Nada en particular: se sigue el camino.
  steady,

  /// Ayer no hubo pieza, y hoy todavía no: lo que importa es que no sean dos.
  missedYesterday,

  /// Lleva una semana o más y aparece menos de la mitad de los días: hay
  /// que hacerlo más chico y más fácil.
  struggling,
}

AdviceMoment momentOf(Habit h, DateTime now) {
  // Dormido no le pasa nada: descansa.
  if (h.restAt(now) != null) return AdviceMoment.steady;
  final hoy = dayStart(now);
  // Que no sean dos, sólo si el tropiezo lo confirmaste vos, es reciente y
  // no volviste a poner pieza desde entonces.
  final tropiezo = lastConfirmedStumble(h);
  if (tropiezo != null && daysBetween(tropiezo.day, hoy) <= 2) {
    final ultima = h.lastPlacedAt;
    if (ultima == null || !dayStart(ultima).isAfter(dayStart(tropiezo.day))) {
      return AdviceMoment.missedYesterday;
    }
  }
  if (daysBetween(h.createdAt, now) + 1 >= 7) {
    final (hubo, esperado) = _contraRitmo(h, now);
    if (esperado >= 3 && hubo < esperado * 0.5) return AdviceMoment.struggling;
  }
  return AdviceMoment.steady;
}

/// En las dos últimas semanas (o desde que se fundó), los días con pieza y
/// los que pedía su ritmo, sin contar los dormidos.
(int, double) _contraRitmo(Habit h, DateTime now) {
  final edad = daysBetween(h.createdAt, now) + 1;
  final ventana = edad.clamp(1, 14);
  final hoy = dayStart(now);
  final con = {for (final p in h.pieces) dayKey(p.placedAt)};
  var despiertos = 0, hubo = 0;
  for (var i = 0; i < ventana; i++) {
    final d = DateTime(hoy.year, hoy.month, hoy.day - i);
    if (h.restedOn(d)) continue;
    despiertos++;
    if (con.contains(dayKey(d))) hubo++;
  }
  // Contra el ritmo dicho, o a diario si no se dijo, como el candado.
  return (hubo, despiertos * (h.perWeek ?? 7) / 7);
}
