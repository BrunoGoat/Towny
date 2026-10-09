/// Dónde puede vivir una copia del valle fuera del teléfono.
///
/// Todavía no hay ninguno conectado. Esto es el enchufe: cuando se conecte
/// Supabase, lo que hace falta es una clase que implemente [Remote] con su
/// cliente —`from(tabla).upsert(filas)`, `delete()` por clave y `select()`—
/// y nada más de la app tiene que cambiar. Qué hay en cada tabla lo dice
/// `supabase/migrations/`, y cómo se traduce, `tables.dart`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

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

  /// Aplica [changes]: escribe sus filas y borra sus claves. Las escrituras
  /// tabla por tabla en el orden de [Tables.all] —el hábito antes que sus
  /// piezas— y los borrados en el orden contrario.
  Future<void> apply(String userId, RowChanges changes);
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

int _piecesOf(Map<String, dynamic> save) {
  var n = 0;
  for (final h in (save['h'] as List?) ?? const []) {
    n += ((h as Map)['p'] as List?)?.length ?? 0;
  }
  return n;
}

/// La conexión con la nube de una persona: ponerse de acuerdo al entrar, y
/// después subir cada cambio.
///
/// Guarda lo último que quedó en la nube ([_base]) para subir sólo la
/// diferencia: una pieza nueva son tres filas, no el valle entero. Por eso
/// lo primero siempre es [connect], que baja lo que hay y fija esa base; sin
/// base no se sube nada.
///
/// Las subidas esperan una pausa corta, porque un cambio casi nunca viene
/// solo —arrastrar un papel son muchos movimientos, y poner una pieza escribe
/// el valle, el tablón y la crónica—. Si una falla (sin conexión), lo
/// cambiado queda marcado y va en la próxima, o en el próximo [connect].
class CloudSync {
  CloudSync(
    this.store,
    this.remote,
    this.userId, {
    this.pause = const Duration(seconds: 2),
  });

  final Store store;
  final Remote remote;
  final String userId;
  final Duration pause;

  /// Lo que hay en la nube ahora, escrito como lo escribe [toRows].
  ValleyRows? _base;

  Timer? _soon;
  bool _busy = false;
  bool _listening = false;

  /// Cuántas filas se mandaron en la última subida. Para los tests.
  @visibleForTesting
  int lastSent = 0;

  /// Pone de acuerdo el teléfono y la nube. Ver [decide] para las reglas.
  /// Después de esto, cada cambio se sube solo.
  Future<SyncPlan> connect() async {
    final changes = LocalChanges.instance;
    final local = captureLocal(store);
    final rows = await remote.pull(userId);
    final cloud = rows == null ? null : fromRows(rows);
    final base = rows == null ? null : canonical(rows, userId);
    final plan = decide(
      localChanged: changes.changedAt,
      lastSynced: changes.syncedAt,
      remoteChanged: cloud?.changedAt,
      localPieces: _piecesOf(local.save),
      remotePieces: cloud == null ? 0 : _piecesOf(cloud.save),
    );
    switch (plan.action) {
      case SyncAction.none:
        _base = base;
        changes.markSynced(DateTime.now());
      case SyncAction.upload:
        if (plan.backup && cloud != null) {
          await LocalChanges.keepBackup(cloud.save);
        }
        final now = DateTime.now();
        final mine = toRows(local, userId);
        await _send(diffRows(base, mine));
        _base = mine;
        changes.markSynced(now);
      case SyncAction.download:
        if (plan.backup) await LocalChanges.keepBackup(local.save);
        final error = await applyLocal(store, cloud!);
        if (error == null) {
          _base = base;
          changes.markSynced(DateTime.now());
        }
    }
    if (!_listening) {
      _listening = true;
      changes.addListener(_changed);
    }
    return plan;
  }

  void stop() {
    if (_listening) LocalChanges.instance.removeListener(_changed);
    _listening = false;
    _soon?.cancel();
  }

  void _changed() {
    _soon?.cancel();
    _soon = Timer(pause, pushNow);
  }

  Future<void> _send(RowChanges changes) async {
    lastSent = changes.count;
    if (changes.isEmpty) return;
    await remote.apply(userId, changes);
  }

  /// Sube ya lo que haya pendiente: sólo lo que cambió desde la última vez.
  Future<void> pushNow() async {
    if (_busy || _base == null || !LocalChanges.instance.dirty) return;
    _busy = true;
    final now = DateTime.now();
    var subio = false;
    try {
      final mine = toRows(captureLocal(store), userId);
      await _send(diffRows(_base, mine));
      _base = mine;
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
