/// El valle, en las filas de las tablas de `supabase/migrations/`.
///
/// Es un traductor y nada más: no sabe de red, ni de Supabase, ni de cuándo
/// se sube nada. De un lado entra lo que la app ya sabe guardar —la copia de
/// [Store.exportSave], los ajustes `clave=valor` y el tablón— y del otro salen
/// filas, una lista por tabla. Y al revés, sin perder nada: un test hace el
/// viaje de ida y vuelta con un valle entero y compara.
///
/// Por qué partiendo de la copia y no de los objetos: la copia es el formato
/// que la app ya lee y escribe, con todas sus compatibilidades hacia atrás.
/// Restaurar desde la nube es exactamente restaurar una copia, y pasa por el
/// mismo sitio que ya se sabe que funciona.
///
/// Las fechas viajan como texto ISO 8601 en UTC, con milisegundos, que es lo
/// que Postgres lee como `timestamptz` y lo que devuelve.
library;

import '../model/census.dart';

/// Los nombres de las tablas, en el orden en que hay que escribirlas: las
/// piezas, los vecinos, las notas y las pausas cuelgan de su hábito.
abstract final class Tables {
  static const valleys = 'valleys';
  static const habits = 'habits';
  static const pieces = 'pieces';
  static const villagers = 'villagers';
  static const notes = 'notes';
  static const rests = 'rests';
  static const boardSlots = 'board_slots';
  static const boardSeen = 'board_seen';

  static const all = [
    valleys,
    habits,
    pieces,
    villagers,
    notes,
    rests,
    boardSlots,
    boardSeen,
  ];
}

typedef Row = Map<String, Object?>;

/// Todo lo de una persona, como filas.
class ValleyRows {
  ValleyRows(this.tables);

  /// Tabla → filas. Están todas las de [Tables.all], aunque sea vacías.
  final Map<String, List<Row>> tables;

  List<Row> operator [](String table) => tables[table] ?? const [];

  int get count => tables.values.fold(0, (n, l) => n + l.length);
}

/// Lo que la app tiene guardado, tal como lo tiene: la entrada y la salida
/// del traductor.
class LocalSnapshot {
  const LocalSnapshot({
    required this.save,
    this.prefs = const [],
    this.boardSlots = const {},
    this.boardSeen = const {},
  });

  /// La copia del valle, ya leída: lo que escribe [Store.exportSave].
  final Map<String, dynamic> save;

  /// Los ajustes, `clave=valor`: [Appearance.exportPrefs].
  final List<String> prefs;

  /// `pueblo/papel` → hueco: [BoardSlots.all].
  final Map<String, int> boardSlots;

  /// Pueblo → lo leído: [BoardSeen.all].
  final Map<String, Set<String>> boardSeen;
}

String? _when(Object? ms) => ms is num
    ? DateTime.fromMillisecondsSinceEpoch(
        ms.toInt(),
        isUtc: true,
      ).toIso8601String()
    : null;

int? _ms(Object? iso) =>
    iso is String ? DateTime.parse(iso).millisecondsSinceEpoch : null;

/// La copia de la app, en filas para [userId].
ValleyRows toRows(LocalSnapshot local, String userId) {
  final save = local.save;
  final out = {for (final t in Tables.all) t: <Row>[]};

  out[Tables.valleys]!.add({
    'user_id': userId,
    'active': (save['a'] as num?)?.toInt() ?? 0,
    'unlocked': save['u'] == true,
    'seen_arrival': (save['w'] as num?)?.toInt() ?? 0,
    'settings': {
      for (final row in local.prefs)
        if (row.indexOf('=') > 0)
          row.substring(0, row.indexOf('=')): row.substring(
            row.indexOf('=') + 1,
          ),
    },
  });

  final habits = (save['h'] as List?) ?? const [];
  for (var at = 0; at < habits.length; at++) {
    final h = habits[at] as Map<String, dynamic>;
    final id = h['id'] as String;
    out[Tables.habits]!.add({
      'user_id': userId,
      'id': id,
      'position': at,
      'name': h['n'],
      'symbol': h['s'],
      'slot': h['slot'],
      'character': h['ch'],
      'created_at': _when(h['c']),
      'why': h['y'],
      'floor': h['q'],
      'vow_hour': h['vh'],
      'vow_place': h['vp'],
      'identity': h['qn'],
      'identity_won_at': _when(h['iw']),
      'after_id': h['af'],
      'per_week': h['pw'],
      'cadence_asked_at': _when(h['ca']),
      'asked_at': _when(h['k']),
      'nudged_at': _when(h['g']),
      'nudges_ignored': (h['gi'] as num?)?.toInt() ?? 0,
      'chronicle': [for (final w in (h['w'] as List?) ?? const []) '$w'],
    });

    for (final p in (h['p'] as List?) ?? const []) {
      final piece = p as Map<String, dynamic>;
      out[Tables.pieces]!.add({
        'user_id': userId,
        'habit_id': id,
        'idx': piece['i'],
        'placed_at': _when(piece['t']),
      });
    }

    // Un renglón que la app no sabría leer tampoco se sube: allá lo ignora
    // igual, y una fila a medias no cabe en una tabla con columnas.
    final folk = (h['f'] as List?) ?? const [];
    for (var i = 0, n = 0; i < folk.length; i++) {
      final v = Villager.parse('${folk[i]}');
      if (v == null) continue;
      out[Tables.villagers]!.add({
        'user_id': userId,
        'habit_id': id,
        'position': n++,
        'home': v.home,
        'seed': v.seed,
        'born_at': v.born.toUtc().toIso8601String(),
        'name': v.name,
      });
    }

    final notes = (h['m'] as List?) ?? const [];
    for (var i = 0, n = 0; i < notes.length; i++) {
      final line = '${notes[i]}';
      final cut = line.indexOf('|');
      final ms = cut > 0 ? int.tryParse(line.substring(0, cut)) : null;
      if (ms == null) continue;
      out[Tables.notes]!.add({
        'user_id': userId,
        'habit_id': id,
        'position': n++,
        'pinned_at': _when(ms),
        'body': line.substring(cut + 1),
      });
    }

    final rests = (h['r'] as List?) ?? const [];
    for (var i = 0, n = 0; i < rests.length; i++) {
      final bits = '${rests[i]}'.split('|');
      final a = bits.length == 2 ? int.tryParse(bits[0]) : null;
      final b = bits.length == 2 ? int.tryParse(bits[1]) : null;
      if (a == null || b == null || b <= a) continue;
      out[Tables.rests]!.add({
        'user_id': userId,
        'habit_id': id,
        'position': n++,
        'from_at': _when(a),
        'until_at': _when(b),
      });
    }
  }

  for (final e in local.boardSlots.entries) {
    out[Tables.boardSlots]!.add({
      'user_id': userId,
      'key': e.key,
      'slot': e.value,
    });
  }
  for (final e in local.boardSeen.entries) {
    for (final k in e.value) {
      out[Tables.boardSeen]!.add({
        'user_id': userId,
        'town_id': e.key,
        'key': k,
      });
    }
  }
  return ValleyRows(out);
}

/// Las filas, de vuelta a lo que la app sabe leer.
///
/// Las filas pueden llegar en cualquier orden —una base de datos no promete
/// ninguno— así que todo se ordena por su posición antes de armar nada.
LocalSnapshot fromRows(ValleyRows rows) {
  int pos(Row r, [String key = 'position']) => (r[key] as num).toInt();
  Map<String, List<Row>> byHabit(String table, String key) {
    final out = <String, List<Row>>{};
    for (final r in rows[table]) {
      (out[r['habit_id'] as String] ??= []).add(r);
    }
    for (final l in out.values) {
      l.sort((a, b) => pos(a, key).compareTo(pos(b, key)));
    }
    return out;
  }

  final pieces = byHabit(Tables.pieces, 'idx');
  final folk = byHabit(Tables.villagers, 'position');
  final notes = byHabit(Tables.notes, 'position');
  final rests = byHabit(Tables.rests, 'position');

  final habits = [...rows[Tables.habits]]
    ..sort((a, b) => pos(a).compareTo(pos(b)));
  final list = <Map<String, dynamic>>[];
  for (final h in habits) {
    final id = h['id'] as String;
    String? text(String k) {
      final v = h[k] as String?;
      return v == null || v.isEmpty ? null : v;
    }

    list.add({
      'id': id,
      'n': h['name'],
      's': h['symbol'],
      'slot': h['slot'],
      'ch': h['character'],
      'c': _ms(h['created_at']),
      'p': [
        for (final p in pieces[id] ?? const <Row>[])
          {'i': p['idx'], 't': _ms(p['placed_at'])},
      ],
      'w': [for (final w in (h['chronicle'] as List?) ?? const []) '$w'],
      'f': [
        for (final v in folk[id] ?? const <Row>[])
          Villager(
            (v['home'] as num).toInt(),
            (v['seed'] as num).toInt(),
            DateTime.parse(v['born_at'] as String),
            v['name'] as String,
          ).line,
      ],
      'm': [
        for (final n in notes[id] ?? const <Row>[])
          '${_ms(n['pinned_at'])}|${n['body']}',
      ],
      if (text('why') case final v?) 'y': v,
      if (text('floor') case final v?) 'q': v,
      if (h['vow_hour'] case final num v) 'vh': v.toInt(),
      if (text('vow_place') case final v?) 'vp': v,
      if (text('identity') case final v?) 'qn': v,
      if (_ms(h['identity_won_at']) case final v?) 'iw': v,
      if (text('after_id') case final v?) 'af': v,
      if (h['per_week'] case final num v) 'pw': v.toInt(),
      if (_ms(h['cadence_asked_at']) case final v?) 'ca': v,
      if ((rests[id] ?? const <Row>[]).isNotEmpty)
        'r': [
          for (final r in rests[id]!)
            '${_ms(r['from_at'])}|${_ms(r['until_at'])}',
        ],
      if (_ms(h['asked_at']) case final v?) 'k': v,
      if (_ms(h['nudged_at']) case final v?) 'g': v,
      if (((h['nudges_ignored'] as num?)?.toInt() ?? 0) > 0)
        'gi': (h['nudges_ignored'] as num).toInt(),
    });
  }

  final valley = rows[Tables.valleys].isEmpty
      ? const <String, Object?>{}
      : rows[Tables.valleys].first;
  final settings = (valley['settings'] as Map?) ?? const {};
  final seen = <String, Set<String>>{};
  for (final r in rows[Tables.boardSeen]) {
    (seen[r['town_id'] as String] ??= {}).add(r['key'] as String);
  }

  return LocalSnapshot(
    save: {
      'v': 1,
      'a': (valley['active'] as num?)?.toInt() ?? 0,
      if (valley['unlocked'] == true) 'u': true,
      if (((valley['seen_arrival'] as num?)?.toInt() ?? 0) > 0)
        'w': (valley['seen_arrival'] as num).toInt(),
      'h': list,
    },
    prefs: [for (final e in settings.entries) '${e.key}=${e.value}'],
    boardSlots: {
      for (final r in rows[Tables.boardSlots])
        r['key'] as String: (r['slot'] as num).toInt(),
    },
    boardSeen: seen,
  );
}
