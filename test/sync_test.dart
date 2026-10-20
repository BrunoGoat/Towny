import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/demo.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/board_seen.dart';
import 'package:towny/model/board_slots.dart';
import 'package:towny/model/census.dart';
import 'package:towny/model/habit.dart';
import 'package:towny/model/store.dart';
import 'package:towny/sync/remote.dart';
import 'package:towny/sync/tables.dart';

/// Un valle con todo lo que un valle puede tener escrito: el de la
/// demostración, más un plan entero, notas, una pausa y vecinos.
Map<String, dynamic> _valle() {
  final hoy = DateTime(2026, 3, 12, 21);
  final habitos = demoValley(hoy);
  final h = habitos.first
    ..why = 'Para llegar entero a los setenta'
    ..floor = 'Diez flexiones'
    ..vowHour = 7
    ..vowPlace = 'en el patio'
    ..identity = 'entrena aunque llueva'
    ..identityWonAt = DateTime(2026, 2, 1, 9, 30, 12, 345)
    ..identityAt = DateTime(2026, 1, 15, 8)
    ..planIf = 'llegue del trabajo'
    ..planThen = 'me pongo las zapatillas'
    // Cada dos días: un ritmo que no es un número entero de veces.
    ..perWeek = 3.5
    ..cadenceAskedAt = DateTime(2026, 1, 3)
    ..cadenceLaterAt = DateTime(2026, 1, 2)
    ..askedAt = DateTime(2026, 2, 20, 18)
    ..nudgedAt = DateTime(2026, 3, 1, 8)
    ..nudgesIgnored = 2;
  h.notes
    ..add('${DateTime(2026, 3, 10).millisecondsSinceEpoch}|Hoy | costó')
    ..add('${DateTime(2026, 3, 2).millisecondsSinceEpoch}|Primera nota');
  h.stumbles.add('${DateTime(2026, 2, 10).millisecondsSinceEpoch}|tired');
  h.rests.add(Rest(DateTime(2025, 12, 20), DateTime(2026, 1, 4)).encode());
  h.folk
    ..add(Villager(3, 991, DateTime(2025, 6, 1, 10), 'Andrés el Herrero').line)
    ..add(Villager(7, -12, DateTime(2025, 7, 2), 'María | la del pozo').line);
  h.chronicle.addAll(['house', 'pozo', 'cottage']);
  return {
    'v': 1,
    'a': 1,
    // Uno más de los que tiene fundados: el que se ganó y todavía no fundó.
    'u2': habitos.length + 1,
    'w': 3,
    'h': [for (final h in habitos) h.toJson()],
  };
}

/// Las columnas de cada tabla, leídas del propio SQL.
Map<String, Set<String>> _columnas() {
  final sql = File(
    'supabase/migrations/20261009000000_towny.sql',
  ).readAsStringSync();
  final out = <String, Set<String>>{};
  final tabla = RegExp(
    r'create table if not exists public\.(\w+) \((.*?)\n\);',
    dotAll: true,
  );
  for (final m in tabla.allMatches(sql)) {
    final cols = <String>{};
    for (final line in m.group(2)!.split('\n')) {
      final c = RegExp(r'^  "?(\w+)"? ').firstMatch(line);
      if (c == null) continue;
      final name = c.group(1)!;
      if (const {'primary', 'foreign', 'references'}.contains(name)) continue;
      cols.add(name);
    }
    out[m.group(1)!] = cols;
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el valle va a filas y vuelve sin perder nada', () {
    final save = _valle();
    final local = LocalSnapshot(
      save: save,
      prefs: const ['lang=es', 'hemisphere=s', 'seasons=0', 'onboarded=1'],
      boardSlots: const {'h0/bando:12': 3, 'h1/racha': 7},
      boardSeen: const {
        'h0': {'a', 'b'},
        'h1': {'c'},
      },
    );
    final rows = toRows(local, 'u-1');

    // Y desordenadas, que es como las devuelve una base de datos.
    for (final l in rows.tables.values) {
      l.shuffle();
    }
    final back = fromRows(rows);

    expect(jsonEncode(back.save), jsonEncode(save));
    expect(back.prefs.toSet(), local.prefs.toSet());
    expect(back.boardSlots, local.boardSlots);
    expect(back.boardSeen, local.boardSeen);
    expect(rows[Tables.pieces].length, greaterThan(200));
    // Las de la demostración y las que se le agregaron.
    expect(rows[Tables.notes].length, greaterThanOrEqualTo(2));
    expect(rows[Tables.rests], isNotEmpty);
    expect(rows[Tables.villagers].length, greaterThanOrEqualTo(2));
  });

  test('cada fila es de quien la sube', () {
    final rows = toRows(LocalSnapshot(save: _valle()), 'u-42');
    for (final t in Tables.all) {
      for (final r in rows[t]) {
        expect(r['user_id'], 'u-42', reason: t);
      }
    }
  });

  test('las columnas de Dart y las del SQL son las mismas', () {
    final sql = _columnas();
    expect(sql.keys.toSet(), Tables.all.toSet());
    final rows = toRows(
      LocalSnapshot(
        save: _valle(),
        prefs: const ['sound=1'],
        boardSlots: const {'h0/x': 1},
        boardSeen: const {
          'h0': {'x'},
        },
      ),
      'u',
    );
    for (final t in Tables.all) {
      expect(rows[t], isNotEmpty, reason: t);
      for (final r in rows[t]) {
        expect(
          r.keys.toSet(),
          sql[t]!.difference({'updated_at'}),
          reason: 'la tabla $t',
        );
      }
    }
  });

  test('las claves de Dart son las del SQL', () {
    // Si no coincidieran, comparar dos copias diría que cambió lo que no
    // cambió, o borraría allá filas que siguen vivas.
    final sql = File(
      'supabase/migrations/20261009000000_towny.sql',
    ).readAsStringSync();
    final tabla = RegExp(
      r'create table if not exists public\.(\w+) \((.*?)\n\);',
      dotAll: true,
    );
    for (final m in tabla.allMatches(sql)) {
      final cuerpo = m.group(2)!;
      final compuesta = RegExp(r'primary key \(([^)]*)\)').firstMatch(cuerpo);
      final clave = compuesta != null
          ? compuesta.group(1)!.split(',').map((c) => c.trim()).toList()
          : [
              RegExp(
                r'^  (\w+) [^\n]*primary key',
                multiLine: true,
              ).firstMatch(cuerpo)!.group(1)!,
            ];
      expect(primaryKeys[m.group(1)], clave, reason: m.group(1));
    }
  });

  test('un pueblo ganado y sin fundar vuelve de la nube', () async {
    // La nube guardaba sólo si la puerta del segundo estaba abierta: con un
    // valle de dos y el tercero ganado, restaurar devolvía la puerta cerrada.
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    final save = _valle();
    final back = fromRows(toRows(LocalSnapshot(save: save), 'u'));
    final s = Store();
    await s.load();
    expect(s.importSave(jsonEncode(back.save)), isNull);
    expect(s.habits.length, (save['h'] as List).length);
    expect(s.canAddHabit, isTrue, reason: 'se perdió el pueblo ganado');
  });

  test('las fechas viajan en UTC con milisegundos', () {
    final rows = toRows(LocalSnapshot(save: _valle()), 'u');
    final p = rows[Tables.pieces].first['placed_at'] as String;
    expect(p, endsWith('Z'));
    expect(p, matches(RegExp(r'\.\d{3}Z$')));
  });

  test('restaurar desde la nube deja la app como estaba', () async {
    SharedPreferences.setMockInitialValues({});
    final antes = Store();
    await antes.load();
    expect(antes.importSave(jsonEncode(_valle())), isNull);
    await Appearance.instance.load();
    // Lo contrario de lo de fábrica, para que se note si no viaja. Las
    // estaciones son de la persona y viajan; la calidad es del aparato y no.
    await Appearance.instance.setSeasons(false);
    await Appearance.instance.setCinematic(false);
    await BoardSlots.instance.replaceAll({'h0/x': 4});
    await BoardSeen.instance.replaceAll({
      'h0': {'y'},
    });
    final copia = toRows(captureLocal(antes), 'u');
    final guardado = antes.exportSave();

    // Otro teléfono: vacío.
    SharedPreferences.setMockInitialValues({});
    final despues = Store();
    await despues.load();
    await Appearance.instance.load();
    BoardSlots.instance.forget();
    BoardSeen.instance.forget();
    // El de este aparato, puesto a mano: cargar unas preferencias vacías no
    // devuelve todo a fábrica.
    await Appearance.instance.setSeasons(true);
    expect(Appearance.instance.cinematic, isTrue);

    expect(await applyLocal(despues, fromRows(copia)), isNull);
    expect(despues.exportSave(), guardado);
    expect(Appearance.instance.seasons, isFalse);
    expect(Appearance.instance.cinematic, isTrue, reason: 'es del aparato');
    expect(BoardSlots.instance.all, {'h0/x': 4});
    expect(BoardSeen.instance.all, {
      'h0': {'y'},
    });
  });
}
