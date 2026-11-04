import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/landmarks.dart';
import 'habit.dart';
import 'works_log.dart';

/// **Cuando una obra pasa a costar otra cantidad de piezas.**
///
/// El catálogo de obras se va a ir retocando: el colmenar que hoy lleva seis
/// piezas puede pasar a llevar cinco, o siete. Ningún pueblo guarda cuántas
/// costó cada obra: las piezas se reparten en orden entre las obras de la
/// crónica, cada una con lo que cuesta *hoy*. Por eso un cambio de costo ya
/// se arregla solo, sin tocar nada guardado:
///
/// - **Si cuesta menos**, las piezas que sobraban pasan a la obra siguiente:
///   son piezas a favor, que ya están puestas y no hay que volver a poner.
/// - **Si cuesta más**, las piezas que ya pusiste la completan primero, y lo
///   que falta lo ponen las próximas piezas, en la obra que estaba en curso.
///
/// Lo único que faltaba era **decirlo**: abrir la app y ver el pueblo
/// distinto sin saber por qué es peor que el cambio mismo. Esto recuerda lo
/// que costaba cada obra la última vez que se abrió la app y, si algo cambió
/// en una obra ya empezada, arma el aviso: qué obras, de cuánto a cuánto, y
/// cuántas piezas quedan a favor o faltan.
///
/// Escala sola: agregar, quitar o cambiar obras del catálogo es tocar
/// `landmarks.dart` y nada más. Una obra nueva no avisa (nadie la empezó con
/// otro costo); una que se quite deja de existir para el pueblo igual que
/// antes.
class CostChange {
  const CostChange({
    required this.town,
    required this.id,
    required this.name,
    required this.before,
    required this.after,
  });

  /// El nombre del pueblo (el del hábito).
  final String town;
  final String id;
  final String name;
  final int before, after;

  /// Lo que cambió: positivo, piezas a favor; negativo, piezas que faltan.
  int get delta => before - after;
}

/// Lo que cuesta hoy cada obra del catálogo.
Map<String, int> currentCosts() => {for (final l in landmarks) l.id: l.cost};

/// Las obras ya empezadas en [habits] que cuestan distinto que en [before].
///
/// Sólo las empezadas: una obra que nadie empezó no cambia nada en ningún
/// pueblo. Y cada pueblo por su lado, porque cada uno la levantó en su
/// momento.
List<CostChange> costChangesFor(
  List<Habit> habits,
  Map<String, int> before, [
  Map<String, int>? now,
]) {
  final hoy = now ?? currentCosts();
  final out = <CostChange>[];
  for (final h in habits) {
    for (final w in worksOf(h)) {
      final antes = before[w.id], ahora = hoy[w.id];
      if (antes == null || ahora == null || antes == ahora) continue;
      out.add(
        CostChange(
          town: h.name,
          id: w.id,
          name: w.name,
          before: antes,
          after: ahora,
        ),
      );
    }
  }
  return out;
}

/// Piezas a favor, en total: las de las obras que ahora cuestan menos.
int piecesInFavour(List<CostChange> c) =>
    c.fold(0, (a, x) => a + (x.delta > 0 ? x.delta : 0));

/// Piezas que faltan, en total: las de las obras que ahora cuestan más.
int piecesOwed(List<CostChange> c) =>
    c.fold(0, (a, x) => a + (x.delta < 0 ? -x.delta : 0));

/// Lo que se recuerda entre aperturas: lo que costaba cada obra.
class CostMemory {
  static const String _key = 'costes_obras_v1';

  /// Los cambios desde la última vez, y deja anotado lo de hoy. La primera
  /// vez no hay con qué comparar: se anota y no avisa.
  static Future<List<CostChange>> check(List<Habit> habits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(_key);
      final hoy = currentCosts();
      await prefs.setString(_key, jsonEncode(hoy));
      if (guardado == null) return const [];
      final antes = <String, int>{
        for (final e in (jsonDecode(guardado) as Map).entries)
          if (e.value is int) e.key.toString(): e.value as int,
      };
      return costChangesFor(habits, antes, hoy);
    } catch (_) {
      return const [];
    }
  }
}
