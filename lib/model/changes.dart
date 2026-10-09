import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cuándo cambió algo en este teléfono, y cuándo fue la última vez que eso
/// quedó guardado en la nube.
///
/// Con esas dos fechas se sabe qué hacer al conectarse sin perder nada (ver
/// `lib/sync/merge.dart`): si sólo cambió el teléfono se sube, si sólo cambió
/// la nube se baja, y si cambiaron los dos gana el cambio más reciente. Una
/// sola fecha —«la de la nube es más vieja que ahora»— no alcanza: un teléfono
/// recién instalado está vacío *ahora*, y pisaría el valle de la nube.
///
/// Avisa a quien escuche cada vez que algo cambia, que es de donde saldrá la
/// subida automática: poner una pieza, mover un papel del tablón, cambiar un
/// ajuste.
class LocalChanges extends ChangeNotifier {
  LocalChanges._();
  static final LocalChanges instance = LocalChanges._();

  static const String _key = 'pueblo_cambios_v1';

  /// La última vez que alguien cambió algo acá. Null si nunca.
  DateTime? changedAt;

  /// La última vez que lo de acá y lo de la nube fueron lo mismo. Null si
  /// nunca se sincronizó.
  DateTime? syncedAt;

  /// Si hay algo acá que la nube todavía no tiene.
  bool get dirty {
    final c = changedAt;
    if (c == null) return false;
    final s = syncedAt;
    return s == null || c.isAfter(s);
  }

  Future<void> load() async {
    changedAt = null;
    syncedAt = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final row in prefs.getStringList(_key) ?? const <String>[]) {
        final at = row.indexOf('=');
        if (at <= 0) continue;
        final ms = int.tryParse(row.substring(at + 1));
        if (ms == null) continue;
        final when = DateTime.fromMillisecondsSinceEpoch(ms);
        switch (row.substring(0, at)) {
          case 'changed':
            changedAt = when;
          case 'synced':
            syncedAt = when;
        }
      }
    } catch (_) {}
  }

  /// Algo cambió, ahora.
  void touch([DateTime? now]) {
    changedAt = now ?? DateTime.now();
    _keep();
    notifyListeners();
  }

  /// Lo de acá y lo de la nube quedaron iguales, a las [when].
  void markSynced(DateTime when) {
    syncedAt = when;
    if (changedAt == null || changedAt!.isBefore(when)) changedAt = when;
    _keep();
  }

  bool _pending = false;

  /// Una ráfaga de cambios —poner una pieza toca el valle, el tablón y la
  /// crónica— se escribe una vez, al final de la ráfaga. Sin temporizador,
  /// como el propio valle.
  void _keep() {
    if (_pending) return;
    _pending = true;
    Future.microtask(flush);
  }

  Future<void> flush() async {
    _pending = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [
        if (changedAt != null) 'changed=${changedAt!.millisecondsSinceEpoch}',
        if (syncedAt != null) 'synced=${syncedAt!.millisecondsSinceEpoch}',
      ]);
    } catch (_) {}
  }

  /// Para los tests.
  void forget() {
    changedAt = null;
    syncedAt = null;
  }
}
