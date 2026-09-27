import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/world.dart';

/// **El pueblo levantado en otro hilo.**
///
/// Cortar y ordenar un pueblo cuesta casi trescientos milisegundos y se
/// pagaban en el primer fotograma que lo pedía. Ahora se encarga mientras
/// sigue puesta la pantalla de apertura, y lo único que hay que demostrar es
/// que lo que vuelve **es el mismo pueblo**: un plano no se puede mandar a
/// otro hilo —lleva recetas dentro, que son funciones— así que del otro lado
/// se levanta otro plano con el mismo encargo. Dos planos del mismo encargo
/// tienen que dar el mismo pueblo, y si algún día dejan de darlo, esto falla.
TownOrder _encargo(int n, {double cx = 0}) => TownOrder(
  placed: n,
  character: TownCharacter.all.first.order,
  cx: cx,
  cz: 0,
  chronicle: const [],
  folk: const [],
  notices: const [0, 3, 6],
  seed: 0x51a1e,
);

/// La huella de un pueblo: cada cara de cada grupo, en el orden en que quedó
/// archivada. Dos pueblos con la misma huella son el mismo pueblo hasta el
/// último vértice.
int _huella(BuiltTown t) {
  var h = 0x811c9dc5;
  void come(int v) => h = ((h ^ v) * 0x01000193) & 0x3fffffff;
  come(t.clusters.length);
  for (final c in t.clusters) {
    come(c.faces);
    come(c.members.length);
    for (final f in c.source) {
      come(f.surface.index);
      come(f.piece + 2);
      come((f.ao * 4096).round());
      for (final v in f.v) {
        come((v.x * 8192).round());
        come((v.y * 8192).round());
        come((v.z * 8192).round());
      }
    }
  }
  return h;
}

void main() {
  group('levantar el pueblo en otro hilo', () {
    tearDown(forgetTowns);

    test(
      'el que vuelve es el mismo que se habría levantado aquí',
      () async {
        for (final n in [60, 200]) {
          final encargo = _encargo(n, cx: n * 3.0);
          forgetTowns();
          final aqui = _huella(builtTown(encargo.layout, n));
          forgetTowns();
          await warmTown(encargo);
          final alla = _huella(builtTown(encargo.layout, n));
          expect(
            alla,
            aqui,
            reason: '$n piezas: el pueblo que vino de fuera no es el de aquí',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'y cuando vuelve, el primer fotograma no construye nada',
      () async {
        final encargo = _encargo(200, cx: 900);
        forgetTowns();
        final frio = Stopwatch()..start();
        builtTown(encargo.layout, 200);
        frio.stop();
        // Si levantarlo de cero no costara nada, no habría nada que sacar de
        // este hilo y esta prueba no mediría más que ruido.
        expect(
          frio.elapsedMilliseconds,
          greaterThan(40),
          reason: 'levantarlo costó ${frio.elapsedMilliseconds} ms',
        );

        forgetTowns();
        await warmTown(encargo);
        final tibio = Stopwatch()..start();
        final hecho = builtTown(encargo.layout, 200);
        tibio.stop();
        expect(
          tibio.elapsedMilliseconds,
          lessThan(30),
          reason: 'el fotograma lo volvió a levantar: ${tibio.elapsed}',
        );
        expect(hecho.clusters, isNotEmpty);
        // Y es el mismo objeto la segunda vez: está guardado, no rehecho.
        expect(identical(builtTown(encargo.layout, 200), hecho), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'dos encargos iguales a la vez se sirven con un solo pueblo',
      () async {
        final encargo = _encargo(120, cx: 1500);
        forgetTowns();
        await Future.wait([warmTown(encargo), warmTown(encargo)]);
        expect(builtTown(encargo.layout, 120).placed, 120);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('si lo guardado no es lo que se pide, se levanta lo que se pide', () {
      // El pueblo encargado tenía ciento veinte piezas y la vista pide
      // doscientas: lo guardado sirve de punto de partida, no de respuesta.
      final encargo = _encargo(120, cx: 2100);
      forgetTowns();
      final corto = builtTown(encargo.layout, 120);
      final largo = builtTown(_encargo(200, cx: 2100).layout, 200);
      expect(largo.placed, 200);
      expect(identical(corto, largo), isFalse);
      expect(largo.clusters.length, greaterThan(corto.clusters.length));
    });
  });
}
