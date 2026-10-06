import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/engine/world.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/town_view.dart';

/// Cambiar de comarca un pueblo ya construido.
///
/// Ningún botón de la app lo hace todavía con un pueblo hecho —sólo la
/// primera vez, antes de la primera pieza—, y estas pruebas son las que dicen
/// que el día que se quiera, se puede: el mismo pueblo, con los mismos
/// edificios y las mismas piezas, levantado con otra cara.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Store> unPueblo(int piezas, TownCharacter de) async {
    SharedPreferences.setMockInitialValues({});
    final s = Store();
    await s.load();
    s.settle(0, de.order);
    s.debugFill(piezas);
    return s;
  }

  /// Lo que es el pueblo, sin lo que es su cara: qué se levantó, en qué
  /// orden, cuánto cuesta cada cosa y cuántas piezas tiene puestas.
  List<String> queHay(TownLayout l) => [
    for (final b in l.buildings)
      '${b.landmark?.id ?? b.kind!.name}:${b.cost}:${b.placedPieces}',
  ];

  test('lo que cuesta cada cosa es igual en todas las comarcas', () {
    // La base de todo lo demás: si una comarca cobrara distinto por la misma
    // obra, cambiar de comarca a mitad dejaría obras con piezas de más o de
    // menos.
    final costos = <String>{};
    for (final c in TownCharacter.all) {
      final l = TownLayout(400, c, seed: 7);
      costos.add(
        {
          for (final b in l.buildings)
            '${b.landmark?.id ?? b.kind!.name}=${b.cost}',
        }.join(','),
      );
    }
    // No se comparan los pueblos —cada uno levanta obras distintas—, sino
    // que una misma obra cueste lo mismo donde aparezca.
    final porObra = <String, Set<String>>{};
    for (final linea in costos) {
      for (final par in linea.split(',')) {
        final [obra, costo] = par.split('=');
        porObra.putIfAbsent(obra, () => {}).add(costo);
      }
    }
    for (final e in porObra.entries) {
      expect(e.value.length, 1, reason: '${e.key} cuesta ${e.value}');
    }
  });

  for (final de in TownCharacter.all) {
    test(
      'de ${de.region} a cualquier otra: el mismo pueblo, otra cara',
      () async {
        final s = await unPueblo(180, de);
        final h = s.habit;
        final cronica = [...h.chronicle];
        final plano = townOrder(h, valley: s.habits).layout;
        final antes = queHay(plano);
        // El plano lleva también la pieza que viene, la que se ve por llegar.
        final piezas = plano.pieces.length;
        expect(antes, isNotEmpty);

        for (final a in TownCharacter.all) {
          if (a.order == de.order) continue;
          s.changeRegion(0, a.order);
          expect(h.character, a.order);
          expect(h.total, 180, reason: '${a.region}: se perdieron piezas');
          // Lo empezado no se mueve: la crónica es la misma.
          expect(h.chronicle.take(cronica.length), cronica);
          final l = townOrder(h, valley: s.habits).layout;
          expect(l.character.order, a.order);
          expect(
            queHay(l),
            antes,
            reason: 'de ${de.region} a ${a.region} cambió lo que hay',
          );
          expect(l.pieces.length, piezas);
          // Y se levanta entero, con su geometría, sin caerse.
          expect(builtTown(l, 180).clusters, isNotEmpty);
        }
        // Y de vuelta a la de origen es el pueblo de antes.
        s.changeRegion(0, de.order);
        expect(queHay(townOrder(h, valley: s.habits).layout), antes);
      },
    );
  }

  test('el cambio sobrevive a cerrar la app', () async {
    final s = await unPueblo(40, TownCharacter.all.first);
    final costa = TownCharacter.all[4].order;
    s.changeRegion(0, costa);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final otra = Store();
    await otra.load();
    expect(otra.habit.character, costa);
    expect(otra.total, 40);
  });

  test('settle, el de la primera vez, no toca un pueblo con piezas', () async {
    final s = await unPueblo(3, TownCharacter.all.first);
    s.settle(0, TownCharacter.all[2].order);
    expect(s.habit.character, TownCharacter.all.first.order);
  });
}
