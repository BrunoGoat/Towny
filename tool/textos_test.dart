import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/bandos.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/constellations.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/data/landmarks_retired.dart';
import 'package:la_muralla/engine/town.dart';

/// La mitad del inventario de textos que no se puede sacar leyendo el código.
///
/// El catálogo de obras, los bandos y las comarcas son listas de Dart con
/// tuplas y mapas dentro: leerlos con una expresión regular es adivinar. Esto
/// los importa de verdad y los escribe tal cual los ve la app.
///
/// La otra mitad —las frases sueltas de cada pantalla— sí sale de leer el
/// código, y de eso se ocupa `tool/textos.py`, que además junta las dos y
/// escribe `TEXTOS.md`.
///
///   flutter test tool/textos_test.dart
///   python3 tool/textos.py
void main() {
  test('el catálogo, escrito', () {
    final b = StringBuffer();
    b.writeln('## OBRAS (${landmarks.length})');
    for (final l in landmarks) {
      b.writeln('- [${l.id}] ${l.name} · ${l.cost} piezas · nivel ${l.tier}');
      b.writeln('    ${l.blurb}');
    }
    b.writeln('\n## OBRAS RETIRADAS (${retiredLandmarks.length})');
    for (final l in retiredLandmarks) {
      b.writeln('- [${l.id}] ${l.name}');
      b.writeln('    ${l.blurb}');
    }
    b.writeln('\n## CASAS CORRIENTES (${buildingName.length})');
    buildingName.forEach((k, v) => b.writeln('- [${k.name}] $v'));
    b.writeln('\n## COMARCAS (${TownCharacter.all.length})');
    for (final c in TownCharacter.all) {
      b.writeln('- ${c.region} · ${c.blurb}');
      c.houseNames?.forEach((k, v) => b.writeln('    [${k.name}] $v'));
    }
    b.writeln('\n## CONSTELACIONES (${constellations.length})');
    for (final c in constellations) {
      b.writeln('- ${c.name} / ${c.latin}');
      b.writeln('    ${c.blurb}');
    }
    b.writeln('\n## BANDOS DEL TABLÓN (${bandos.length})');
    for (final x in bandos) {
      b.writeln('- ${x.$1}');
      b.writeln('    ${x.$2}');
    }
    Directory('/tmp/towny').createSync(recursive: true);
    File('/tmp/towny/datos.md').writeAsStringSync(b.toString());
    // ignore: avoid_print
    print('escrito /tmp/towny/datos.md');
  });
}
