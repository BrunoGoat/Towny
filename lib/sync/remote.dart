/// Dónde puede vivir una copia del valle fuera del teléfono.
///
/// Todavía no hay ninguno conectado. Esto es el enchufe: cuando se conecte
/// Supabase, lo que hace falta es una clase que implemente [Remote] con su
/// cliente —`from(tabla).upsert(filas)` y `from(tabla).select()`— y nada más
/// de la app tiene que cambiar. Qué hay en cada tabla lo dice
/// `supabase/migrations/`, y cómo se traduce, `tables.dart`.
library;

import 'dart:convert';

import '../model/appearance.dart';
import '../model/board_seen.dart';
import '../model/board_slots.dart';
import '../model/store.dart';
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
