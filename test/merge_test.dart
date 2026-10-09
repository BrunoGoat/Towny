import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/demo.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/board_seen.dart';
import 'package:towny/model/board_slots.dart';
import 'package:towny/model/changes.dart';
import 'package:towny/model/store.dart';
import 'package:towny/sync/merge.dart';
import 'package:towny/sync/remote.dart';
import 'package:towny/sync/tables.dart';

/// Una nube de mentira: guarda las filas en memoria, y se puede apagar.
class _Nube implements Remote {
  final Map<String, ValleyRows> _datos = {};
  bool caida = false;
  int subidas = 0;

  @override
  Future<ValleyRows?> pull(String userId) async {
    if (caida) throw Exception('sin conexión');
    return _datos[userId];
  }

  @override
  Future<void> push(String userId, ValleyRows rows) async {
    if (caida) throw Exception('sin conexión');
    subidas++;
    _datos[userId] = rows;
  }

  int piezas(String userId) => _datos[userId]?[Tables.pieces].length ?? 0;
}

final _lunes = DateTime(2026, 10, 5, 9);
final _martes = DateTime(2026, 10, 6, 9);
final _miercoles = DateTime(2026, 10, 7, 9);

String _valle() => jsonEncode({
  'v': 1,
  'a': 0,
  'h': [for (final h in demoValley(DateTime(2026, 3, 12, 21))) h.toJson()],
});

Future<Store> _telefono({String? valle}) async {
  SharedPreferences.setMockInitialValues({});
  LocalChanges.instance.forget();
  BoardSlots.instance.forget();
  BoardSeen.instance.forget();
  await Appearance.instance.load();
  final s = Store();
  await s.load();
  if (valle != null) expect(s.importSave(valle), isNull);
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('qué hacer al conectarse', () {
    SyncPlan plan({
      DateTime? aqui,
      DateTime? juntos,
      DateTime? alla,
      int piezasAqui = 10,
      int piezasAlla = 10,
    }) => decide(
      localChanged: aqui,
      lastSynced: juntos,
      remoteChanged: alla,
      localPieces: piezasAqui,
      remotePieces: piezasAlla,
    );

    test('usada sin conexión: lo del teléfono se sube', () {
      final p = plan(aqui: _miercoles, juntos: _lunes, alla: _lunes);
      expect(p.action, SyncAction.upload);
      expect(p.backup, isFalse);
    });

    test('teléfono nuevo: baja la nube y nunca la pisa', () {
      // Vacío y sin haber tocado nada.
      expect(
        plan(piezasAqui: 0, alla: _lunes, piezasAlla: 300).action,
        SyncAction.download,
      );
      // Vacío y con algo tocado ahora mismo, que es más nuevo que la nube:
      // aun así baja, y lo poco de acá se guarda.
      final p = plan(
        aqui: _miercoles,
        piezasAqui: 0,
        alla: _lunes,
        piezasAlla: 300,
      );
      expect(p.action, SyncAction.download);
      expect(p.backup, isTrue);
    });

    test('la nube vacía recibe lo que haya', () {
      expect(
        plan(aqui: _lunes, alla: null, piezasAlla: 0).action,
        SyncAction.upload,
      );
      expect(
        plan(piezasAqui: 0, alla: null, piezasAlla: 0).action,
        SyncAction.none,
      );
    });

    test('otro teléfono subió algo: se baja', () {
      final p = plan(aqui: _lunes, juntos: _lunes, alla: _martes);
      expect(p.action, SyncAction.download);
      expect(p.backup, isFalse);
    });

    test('cambiaron los dos: gana el más reciente y el otro se guarda', () {
      final a = plan(aqui: _miercoles, juntos: _lunes, alla: _martes);
      expect(a.action, SyncAction.upload);
      expect(a.backup, isTrue);
      final b = plan(aqui: _martes, juntos: _lunes, alla: _miercoles);
      expect(b.action, SyncAction.download);
      expect(b.backup, isTrue);
    });

    test('nada cambió: nada se toca', () {
      expect(
        plan(aqui: _lunes, juntos: _martes, alla: _lunes).action,
        SyncAction.none,
      );
    });
  });

  group('de punta a punta, con una nube de mentira', () {
    test('el teléfono recién instalado baja el valle entero', () async {
      final nube = _Nube();
      final viejo = await _telefono(valle: _valle());
      await syncNow(viejo, nube, 'u');
      final piezas = viejo.habits.fold<int>(0, (n, h) => n + h.total);
      expect(nube.piezas('u'), piezas);

      final nuevo = await _telefono();
      expect(nuevo.total, 0);
      final hecho = await syncNow(nuevo, nube, 'u');
      expect(hecho.action, SyncAction.download);
      expect(nuevo.habits.fold<int>(0, (n, h) => n + h.total), piezas);
      expect(LocalChanges.instance.dirty, isFalse);
    });

    test('cada cambio se sube solo, y sin conexión queda pendiente', () async {
      final nube = _Nube();
      final s = await _telefono(valle: _valle());
      await syncNow(s, nube, 'u');
      final antes = nube.piezas('u');
      final auto = AutoSync(s, nube, 'u', pause: Duration.zero)..start();

      s.placePiece();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(nube.piezas('u'), antes + 1);

      // Sin conexión: la pieza se pone igual y espera.
      nube.caida = true;
      s.placePiece();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(nube.piezas('u'), antes + 1);
      expect(LocalChanges.instance.dirty, isTrue);

      // Vuelve la conexión: al entrar, sube lo pendiente.
      nube.caida = false;
      final hecho = await syncNow(s, nube, 'u');
      expect(hecho.action, SyncAction.upload);
      expect(nube.piezas('u'), antes + 2);
      auto.stop();
    });

    test('mover un papel del tablón también es un cambio', () async {
      await _telefono();
      await BoardSlots.instance.replaceAll({'h0/a': 1, 'h0/b': 2});
      final antes = LocalChanges.instance.changedAt;
      BoardSlots.instance.place('h0', const ['a', 'b'], 0, 3);
      expect(LocalChanges.instance.changedAt, isNot(antes));
      expect(LocalChanges.instance.dirty, isTrue);
    });

    test('abrir la app no cuenta como cambio', () async {
      // Si contara, un teléfono recién instalado parecería más nuevo que la
      // nube.
      await _telefono();
      expect(LocalChanges.instance.changedAt, isNull);
    });
  });

  test('los ajustes de desarrollo no viajan', () {
    final rows = toRows(
      LocalSnapshot(
        save: jsonDecode(_valle()) as Map<String, dynamic>,
        prefs: const [
          'lang=es',
          'quality=max',
          'fakeHour=1',
          'fakeHourAt=22.0',
          'fakeSeason=1',
          'fakeSeasonAt=0.5',
        ],
      ),
      'u',
    );
    final ajustes = rows[Tables.valleys].first['settings'] as Map;
    expect(ajustes.keys.toSet(), {'lang', 'quality'});
  });
}
