import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/advice.dart';
import 'habit.dart';
import 'piece.dart';

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
class AdviceBook {
  AdviceBook._();
  static final AdviceBook instance = AdviceBook._();

  static const String _key = 'consejero_v3';
  static const String _goalKey = 'consejero_busca_v1';
  static const String _sep = '\u0001';

  /// Lo ganado, en el orden en que se ganó: id y momento.
  final List<(String, DateTime)> _got = [];

  /// Pueblo -> lo que se busca con él.
  final Map<String, AdviceGoal> _goals = {};

  Future<void> load() async {
    _got.clear();
    _goals.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final row in prefs.getStringList(_key) ?? const <String>[]) {
        final b = row.lastIndexOf('|');
        if (b <= 0) continue;
        final id = row.substring(0, b);
        final ms = int.tryParse(row.substring(b + 1));
        if (ms == null || !adviceById.containsKey(id)) continue;
        _got.add((id, DateTime.fromMillisecondsSinceEpoch(ms)));
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
  }

  /// Lo que busca el pueblo [habitId], o nulo si todavía no se le contestó.
  AdviceGoal? goalOf(String habitId) => _goals[habitId];

  /// La respuesta a la pregunta del consejero en ese pueblo.
  void setGoal(String habitId, AdviceGoal goal) {
    _goals[habitId] = goal;
    unawaited(flush());
  }

  /// Lo ganado, del más nuevo al más viejo. Sólo lo aprobado: lo que se saca
  /// de [approvedAdvice] deja de verse aunque ya se hubiera ganado.
  List<(Advice, DateTime)> unlocked({Set<String> approved = approvedAdvice}) =>
      [
        for (final (id, at) in _got.reversed)
          if (approved.contains(id)) (adviceById[id]!, at),
      ];

  /// El de hoy: lo último que se ganó, si fue hoy.
  Advice? today({DateTime? now, Set<String> approved = approvedAdvice}) {
    final todo = unlocked(approved: approved);
    if (todo.isEmpty) return null;
    final (a, at) = todo.first;
    return dayKey(at) == dayKey(now ?? DateTime.now()) ? a : null;
  }

  /// El camino de consejos de todos los días, según lo que buscan tus
  /// pueblos. Vacío si ninguno contestó todavía.
  List<String> pathOf(List<Habit> habits) {
    final buscan = {
      for (final h in habits)
        if (_goals[h.id] case final g?) g,
    };
    if (buscan.isEmpty) return const [];
    if (buscan.length == 1) return pathFor(buscan.single);
    // De los dos: uno y uno, sin repetir lo que está en los dos caminos.
    final a = pathFor(AdviceGoal.start), b = pathFor(AdviceGoal.quit);
    final out = <String>[];
    for (var i = 0; i < a.length || i < b.length; i++) {
      for (final id in [if (i < a.length) a[i], if (i < b.length) b[i]]) {
        if (!out.contains(id)) out.add(id);
      }
    }
    return out;
  }

  /// Entrar a la app: gana el de hoy, si no se ganó ya, y los de lo que haya
  /// pasado. Devuelve los nuevos, en el orden en que se ganaron.
  List<Advice> visit(
    List<Habit> habits, {
    DateTime? now,
    Set<String> approved = approvedAdvice,
  }) {
    final camino = pathOf(habits);
    if (camino.isEmpty) return const [];
    final at = now ?? DateTime.now();
    final ya = {for (final (id, _) in _got) id};
    final nuevos = <Advice>[];
    void ganar(Advice a) {
      if (!approved.contains(a.id) || !ya.add(a.id)) return;
      _got.add((a.id, at));
      nuevos.add(a);
    }

    // Lo que pasó va antes que el del día: es lo más oportuno, y así el del
    // día queda arriba como el último ganado.
    for (final (evento, busca) in eventsOf(habits, _goals)) {
      for (final a in eventAdvice) {
        if (a.event != evento) continue;
        if (a.goal != null && a.goal != busca) continue;
        ganar(a);
      }
    }
    final hoy = dayKey(at);
    final yaHoy = _got.any(
      (g) => dayKey(g.$2) == hoy && adviceById[g.$1]!.event == null,
    );
    if (!yaHoy) {
      for (final id in camino) {
        if (ya.contains(id) || !approved.contains(id)) continue;
        ganar(adviceById[id]!);
        break;
      }
    }
    if (nuevos.isNotEmpty) unawaited(flush());
    return nuevos;
  }

  Future<void> flush() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [
        for (final (id, at) in _got) '$id|${at.millisecondsSinceEpoch}',
      ]);
      await prefs.setStringList(_goalKey, [
        for (final MapEntry(key: town, value: g) in _goals.entries)
          '$town$_sep${g.name}',
      ]);
    } catch (_) {}
  }

  /// Para los tests: la libreta en blanco.
  void forget() {
    _got.clear();
    _goals.clear();
  }
}

/// Lo que ya pasó en el valle, de lo que gana consejos: cada cosa, con lo
/// que busca el pueblo en que pasó (nulo si ese pueblo no contestó).
///
/// Sale de lo que está guardado y nada más —las piezas con su fecha, los
/// pueblos, las notas, las pausas—, así que no hace falta apuntar nada aparte
/// para enterarse: quien ya tenía dos pueblos cuando apareció el consejero
/// lo oye la primera vez que entra.
Set<(AdviceEvent, AdviceGoal?)> eventsOf(
  List<Habit> habits, [
  Map<String, AdviceGoal> goals = const {},
]) {
  final out = <(AdviceEvent, AdviceGoal?)>{};
  // El segundo y el tercero que se fundaron, con lo que busca cada uno.
  final orden = [...habits]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  if (orden.length >= 2) {
    out.add((AdviceEvent.secondTown, goals[orden[1].id]));
  }
  if (orden.length >= 3) out.add((AdviceEvent.thirdTown, goals[orden[2].id]));
  for (final h in habits) {
    final busca = goals[h.id];
    void pasa(AdviceEvent e) => out.add((e, busca));
    if (h.total > 0) pasa(AdviceEvent.firstPiece);
    if (h.total >= 100) pasa(AdviceEvent.hundred);
    if (h.vowHour != null || (h.vowPlace?.trim().isNotEmpty ?? false)) {
      pasa(AdviceEvent.plan);
    }
    if (h.notes.isNotEmpty) pasa(AdviceEvent.ownNote);
    if (h.rests.isNotEmpty) pasa(AdviceEvent.rested);
    // Los días con pieza, en orden, y los huecos entre ellos.
    final dias = <DateTime>[];
    var ultimo = -1;
    for (final p in h.pieces) {
      final k = dayKey(p.placedAt);
      if (k == ultimo) continue;
      ultimo = k;
      dias.add(dayStart(p.placedAt));
    }
    final distintos = {for (final d in dias) dayKey(d)}.length;
    if (distintos >= 7) pasa(AdviceEvent.week);
    if (distintos >= 30) pasa(AdviceEvent.month);
    for (var i = 1; i < dias.length; i++) {
      final hueco = daysBetween(dias[i - 1], dias[i]);
      // Un día sin nada entre dos con algo, y no en una pausa: dormir el
      // pueblo es decidirlo, no saltearse un día.
      if (hueco == 2 && !h.restedOn(dias[i - 1].add(const Duration(days: 1)))) {
        pasa(AdviceEvent.missedDay);
      }
      if (hueco >= 4) pasa(AdviceEvent.comeback);
    }
  }
  return out;
}
