/// Dónde puede vivir una copia del valle fuera del teléfono.
///
/// Todavía no hay ninguno conectado. Esto es el enchufe: cuando se conecte
/// Supabase, lo que hace falta es una clase que implemente [Remote] con su
/// cliente —`from(tabla).upsert(filas)` y `from(tabla).select()`— y nada más
/// de la app tiene que cambiar. Qué hay en cada tabla lo dice
/// `supabase/migrations/`, y cómo se traduce, `tables.dart`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/appearance.dart';
import '../model/board_seen.dart';
import '../model/board_slots.dart';
import '../model/changes.dart';
import '../model/store.dart';
import 'merge.dart';
import 'tables.dart';

abstract interface class Remote {
  /// Lo que hay guardado de [userId], o null si nunca subió nada.
  Future<ValleyRows?> pull(String userId);

  /// Deja guardado exactamente [rows]: lo que ya no está —un hábito borrado,
  /// una nota descolgada— se borra también allá. Una copia, no una suma.
  Future<void> push(String userId, ValleyRows rows);
}

/// Lo que la app tiene ahora mismo, listo para traducir.
LocalSnapshot captureLocal(Store store) => LocalSnapshot(
  changedAt: LocalChanges.instance.changedAt,
  save: jsonDecode(store.exportSave()) as Map<String, dynamic>,
  prefs: Appearance.instance.exportPrefs(),
  boardSlots: BoardSlots.instance.all,
  boardSeen: BoardSeen.instance.all,
);

/// Pone en la app lo que trajo una copia. Devuelve null si salió bien, o el
/// motivo si no — y entonces no se tocó nada del valle.
///
/// El valle pasa por [Store.importSave], que es la misma puerta que una copia
/// pegada a mano: todo o nada, con las mismas comprobaciones.
Future<String?> applyLocal(Store store, LocalSnapshot copy) async {
  final error = store.importSave(jsonEncode(copy.save));
  if (error != null) return error;
  await Appearance.instance.importPrefs(copy.prefs);
  await BoardSlots.instance.replaceAll(copy.boardSlots);
  await BoardSeen.instance.replaceAll(copy.boardSeen);
  return null;
}

/// Dónde queda la copia que perdió, la última vez que dos no coincidieron.
const String backupKey = 'pueblo_respaldo_v1';

Future<void> _keepBackup(Map<String, dynamic> save) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      backupKey,
      jsonEncode({'at': DateTime.now().millisecondsSinceEpoch, 'save': save}),
    );
  } catch (_) {}
}

int _piecesOf(Map<String, dynamic> save) {
  var n = 0;
  for (final h in (save['h'] as List?) ?? const []) {
    n += ((h as Map)['p'] as List?)?.length ?? 0;
  }
  return n;
}

/// Pone de acuerdo el teléfono y la nube, al entrar o al recuperar conexión.
/// Ver [decide] para las reglas. Devuelve lo que hizo.
Future<SyncPlan> syncNow(Store store, Remote remote, String userId) async {
  final changes = LocalChanges.instance;
  final local = captureLocal(store);
  final rows = await remote.pull(userId);
  final cloud = rows == null ? null : fromRows(rows);
  final plan = decide(
    localChanged: changes.changedAt,
    lastSynced: changes.syncedAt,
    remoteChanged: cloud?.changedAt,
    localPieces: _piecesOf(local.save),
    remotePieces: cloud == null ? 0 : _piecesOf(cloud.save),
  );
  switch (plan.action) {
    case SyncAction.none:
      changes.markSynced(DateTime.now());
    case SyncAction.upload:
      if (plan.backup && cloud != null) await _keepBackup(cloud.save);
      await remote.push(userId, toRows(local, userId));
      changes.markSynced(DateTime.now());
    case SyncAction.download:
      if (plan.backup) await _keepBackup(local.save);
      final error = await applyLocal(store, cloud!);
      if (error == null) changes.markSynced(DateTime.now());
  }
  return plan;
}

/// Sube cada cambio: una pieza, un papel movido en el tablón, un ajuste.
///
/// Con una pausa corta antes de subir, porque un cambio casi nunca viene
/// solo —arrastrar un papel son muchos movimientos, y poner una pieza escribe
/// el valle, el tablón y la crónica— y una subida por cada uno sería subir lo
/// mismo diez veces. Si falla (sin conexión), lo cambiado queda marcado y se
/// sube en el próximo cambio o en el próximo [syncNow].
class AutoSync {
  AutoSync(
    this.store,
    this.remote,
    this.userId, {
    this.pause = const Duration(seconds: 2),
  });

  final Store store;
  final Remote remote;
  final String userId;
  final Duration pause;

  Timer? _soon;
  bool _busy = false;

  void start() => LocalChanges.instance.addListener(_changed);

  void stop() {
    LocalChanges.instance.removeListener(_changed);
    _soon?.cancel();
  }

  void _changed() {
    _soon?.cancel();
    _soon = Timer(pause, pushNow);
  }

  /// Sube ya lo que haya pendiente.
  Future<void> pushNow() async {
    if (_busy || !LocalChanges.instance.dirty) return;
    _busy = true;
    final now = DateTime.now();
    var subio = false;
    try {
      await remote.push(userId, toRows(captureLocal(store), userId));
      LocalChanges.instance.markSynced(now);
      subio = true;
    } catch (_) {
      // Sin conexión: queda pendiente, y no se reintenta en bucle.
    } finally {
      _busy = false;
    }
    // Lo que cambió mientras subía se perdió esa subida: va en otra.
    if (subio && LocalChanges.instance.dirty && _soon?.isActive != true) {
      _changed();
    }
  }
}
