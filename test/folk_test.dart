import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/doings.dart';
import 'package:la_muralla/engine/folk.dart';
import 'package:la_muralla/engine/folk_body.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/season.dart';
import 'package:la_muralla/engine/solid.dart';
import 'package:la_muralla/engine/town.dart';

TownLayout _town(int pieces, [String region = 'Ribera']) =>
    TownLayout(pieces, TownCharacter.all.firstWhere((c) => c.region == region));

/// Las casas corrientes que ya están pagadas enteras.
int _finished(TownLayout t, int placed) => t.buildings
    .where((b) => !b.isLandmark && b.firstPiece + b.cost <= placed)
    .length;

void main() {
  _nacimientos();
  group('quién vive en el pueblo', () {
    test('una casa terminada, un vecino; ni uno más ni uno menos', () {
      for (final n in [1, 5, 20, 80, 300]) {
        final t = _town(n);
        expect(folkOf(t, n).length, _finished(t, n), reason: 'con $n piezas');
      }
    });

    test('un pueblo recién fundado no tiene a nadie', () {
      // La primera casa cuesta dos o tres piezas. Hasta que esté pagada
      // entera no vive nadie en ella, porque no hay ella.
      final t = _town(1);
      expect(folkOf(t, 1), isEmpty);
    });

    test('nadie sale de una casa a medio pagar', () {
      // La regla de siempre, dicha desde aquí: una persona no es un premio ni
      // un adelanto. Aparece cuando la última pieza de su casa está puesta.
      final t = _town(300);
      final casas = {for (final w in folkOf(t, 300)) w.home};
      for (final b in t.buildings) {
        if (b.isLandmark) continue;
        final entera = b.firstPiece + b.cost <= 300;
        expect(
          casas.contains(b.index),
          entera,
          reason: 'el edificio ${b.index} (${b.name}) tiene vecino sin estarlo',
        );
      }
    });

    test('en los hitos no vive nadie', () {
      final t = _town(400);
      final hitos = {
        for (final b in t.buildings)
          if (b.isLandmark) b.index,
      };
      for (final w in folkOf(t, 400)) {
        expect(hitos.contains(w.home), isFalse);
      }
    });

    test('crece con el pueblo y nunca mengua', () {
      var antes = 0;
      for (var n = 0; n <= 400; n += 20) {
        final ahora = folkOf(_town(n), n).length;
        expect(ahora, greaterThanOrEqualTo(antes), reason: 'con $n piezas');
        antes = ahora;
      }
      expect(antes, greaterThan(20));
    });
  });

  group('la ronda', () {
    test('en el mismo segundo están siempre en el mismo sitio', () {
      // No hay simulación que guardar ni que adelantar: es una función del
      // reloj. Si esto fallara, la gente saltaría de sitio al repintar.
      final t = _town(200);
      for (final w in folkOf(t, 200)) {
        for (final s in [0.0, 13.7, 91.25, 1200.0]) {
          final a = w.at(s), b = w.at(s);
          expect(a.x, b.x);
          expect(a.z, b.z);
          expect(a.heading, b.heading);
        }
      }
    });

    test('y el pueblo entero da la misma gente dos veces', () {
      final t = _town(200);
      final a = folkOf(t, 200), b = folkOf(t, 200);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].seed, b[i].seed);
        expect(a[i].at(40).x, b[i].at(40).x);
      }
    });

    test('la ronda se cierra: vuelven por donde salieron', () {
      final t = _town(200);
      for (final w in folkOf(t, 200)) {
        final a = w.at(0), b = w.at(w.period);
        expect((a.x - b.x).abs(), lessThan(1e-6));
        expect((a.z - b.z).abs(), lessThan(1e-6));
      }
    });

    test('se mueven de verdad, y no se van del pueblo', () {
      final t = _town(200);
      final r = t.radius + 6;
      for (final w in folkOf(t, 200)) {
        var lejos = 0.0;
        final desde = w.at(0);
        for (var k = 0; k <= 40; k++) {
          final at = w.at(w.period * k / 40);
          final d = math.sqrt(
            math.pow(at.x - desde.x, 2) + math.pow(at.z - desde.z, 2),
          );
          if (d > lejos) lejos = d;
          expect(
            math.sqrt(at.x * at.x + at.z * at.z),
            lessThan(r),
            reason: 'alguien se fue del pueblo',
          );
        }
        expect(lejos, greaterThan(1.0), reason: 'alguien no se movió nunca');
      }
    });

    test('no andan ni demasiado rápido ni a saltos', () {
      // Lo que caza un fallo en el reparto de tiempos: un tramo con tiempo
      // cero es una persona teletransportándose.
      final t = _town(200);
      for (final w in folkOf(t, 200)) {
        var prev = w.at(0);
        for (var k = 1; k <= 400; k++) {
          final at = w.at(k * 0.25);
          final d = math.sqrt(
            math.pow(at.x - prev.x, 2) + math.pow(at.z - prev.z, 2),
          );
          expect(
            d,
            lessThan(Townsfolk.pace * 0.25 + 0.02),
            reason: 'un salto de $d en un cuarto de segundo',
          );
          prev = at;
        }
      }
    });
  });

  group('no atraviesan las casas', () {
    test('la ronda entera pasa por fuera de lo que está en pie', () {
      // El fallo que esto existe para cazar se ve a simple vista en cuanto uno
      // se acerca: alguien saliendo de una pared. En línea recta de un recado
      // al siguiente pasaba todo el rato.
      const placed = 300;
      final t = _town(placed);
      // Lo que ocupa cada edificio en el suelo, a la altura de una persona.
      final cajas = <(double x0, double z0, double x1, double z1)>[];
      for (var i = 0; i < math.min(placed, t.pieces.length); i++) {
        final p = t.pieces[i];
        if (p.y0 > 0.95) continue;
        cajas.add((p.x0, p.z0, p.x1, p.z1));
      }
      final dentro = <String>[];
      for (final w in folkOf(t, placed)) {
        for (var k = 0; k < 600; k++) {
          final at = w.at(w.period * k / 600);
          for (final c in cajas) {
            if (at.x > c.$1 + 0.06 &&
                at.x < c.$3 - 0.06 &&
                at.z > c.$2 + 0.06 &&
                at.z < c.$4 - 0.06) {
              dentro.add(
                'el de la casa ${w.home} pasa por dentro de una pared '
                'en (${at.x.toStringAsFixed(1)}, ${at.z.toStringAsFixed(1)})',
              );
              break;
            }
          }
          if (dentro.isNotEmpty) break;
        }
      }
      expect(dentro, isEmpty, reason: dentro.join('\n'));
    });

    test('y ni uno solo de los quiebros cae dentro de una pared', () {
      // Más fino que muestrear la ronda: un vértice metido en una pared y un
      // tramo largo que corta una esquina se ven igual muestreando, y tienen
      // arreglos distintos —uno es el sitio al que se va, el otro es el camino
      // por el que se va—. Así se sabe cuál de los dos falló.
      const placed = 300;
      final t = _town(placed);
      final cajas = <(double, double, double, double)>[];
      for (var i = 0; i < math.min(placed, t.pieces.length); i++) {
        final p = t.pieces[i];
        if (p.y0 > 0.95) continue;
        cajas.add((p.x0, p.z0, p.x1, p.z1));
      }
      for (final w in folkOf(t, placed)) {
        for (final q in w.debugPath) {
          for (final c in cajas) {
            final dentro =
                q.$1 > c.$1 + 0.06 &&
                q.$1 < c.$3 - 0.06 &&
                q.$2 > c.$2 + 0.06 &&
                q.$2 < c.$4 - 0.06;
            expect(
              dentro,
              isFalse,
              reason:
                  'el de la casa ${w.home} tiene un quiebro en $q, '
                  'que está dentro de $c',
            );
          }
        }
      }
    });

    test('y las seis regiones se portan igual', () {
      for (final c in TownCharacter.all) {
        final t = TownLayout(200, c);
        final cajas = <(double, double, double, double)>[];
        for (var i = 0; i < math.min(200, t.pieces.length); i++) {
          final p = t.pieces[i];
          if (p.y0 > 0.95) continue;
          cajas.add((p.x0, p.z0, p.x1, p.z1));
        }
        var malos = 0;
        for (final w in folkOf(t, 200)) {
          for (var k = 0; k < 200; k++) {
            final at = w.at(w.period * k / 200);
            for (final b in cajas) {
              if (at.x > b.$1 + 0.06 &&
                  at.x < b.$3 - 0.06 &&
                  at.z > b.$2 + 0.06 &&
                  at.z < b.$4 - 0.06) {
                malos++;
                break;
              }
            }
          }
        }
        expect(malos, 0, reason: '${c.region}: $malos pasos por dentro');
      }
    });
  });

  group('cada uno en lo suyo', () {
    test('la cometa y las mariposas son cosa de críos', () {
      // Un maestro cantero de cincuenta años corriendo detrás de una mariposa
      // es gracioso una vez y raro siempre.
      final t = _town(400);
      for (final w in folkOf(t, 400)) {
        if (w.kid) continue;
        for (final d in w.debugActs) {
          expect(
            d?.who,
            isNot(Who.kid),
            reason: '${w.name} no es un crío y ${d?.name}',
          );
        }
      }
    });

    test('y sólo en el prado, nunca en medio de la plaza', () {
      // La regla de la que sale todo esto: lo que se hace depende de dónde se
      // está. Los sitios del prado están al borde del pueblo, así que basta
      // con mirar lo lejos que queda del centro.
      final t = _town(400);
      final borde = t.radius * 0.55;
      for (final w in folkOf(t, 400)) {
        final donde = w.debugPath;
        final quehace = w.debugActs;
        for (var i = 0; i < quehace.length; i++) {
          if (quehace[i]?.where != Where.meadow) continue;
          final d = math.sqrt(
            math.pow(donde[i].$1 - t.cx, 2) + math.pow(donde[i].$2 - t.cz, 2),
          );
          expect(
            d,
            greaterThan(borde),
            reason: 'alguien suelta una cometa dentro del pueblo',
          );
        }
      }
    });

    test('andando no se está haciendo otra cosa', () {
      // Lo que esto caza: un gesto que se queda pegado mientras la persona
      // cruza el pueblo, que es alguien martilleando el aire mientras anda.
      final t = _town(200);
      for (final w in folkOf(t, 200)) {
        for (var k = 0; k < 300; k++) {
          final at = w.at(w.period * k / 300);
          if (at.moving) expect(at.act, isNull);
        }
      }
    });

    test('en una parada se hace siempre lo mismo, y se ve entero', () {
      // El gesto se mueve con [phase], así que una parada tiene que durar lo
      // bastante como para que se vea el gesto y no un fotograma suelto.
      final t = _town(200);
      var visto = 0;
      for (final w in folkOf(t, 200)) {
        Doing? antes;
        var seguidos = 0;
        for (var k = 0; k < 600; k++) {
          final at = w.at(w.period * k / 600);
          if (at.moving) {
            antes = null;
            seguidos = 0;
            continue;
          }
          if (at.act == antes) {
            seguidos++;
            if (seguidos > 1) visto++;
          }
          antes = at.act;
          expect(at.phase, greaterThanOrEqualTo(0));
        }
      }
      expect(visto, greaterThan(100), reason: 'las paradas duran un suspiro');
    });

    test('las cosas de casa pasan en su casa', () {
      // Su puerta es el único sitio de la ronda que es suyo. Amasar pan en
      // mitad del prado sería exactamente el tipo de cosa que convierte un
      // pueblo en un parque de atracciones.
      final t = _town(400);
      for (final w in folkOf(t, 400)) {
        final donde = w.debugPath, quehace = w.debugActs;
        final casa = t.buildings[w.home];
        for (var i = 0; i < quehace.length; i++) {
          if (quehace[i]?.where != Where.door) continue;
          final d = math.sqrt(
            math.pow(donde[i].$1 - casa.cx, 2) +
                math.pow(donde[i].$2 - casa.cz, 2),
          );
          expect(
            d,
            lessThan(6.0),
            reason: '${w.name} ${quehace[i]!.name} lejos de su casa',
          );
        }
      }
    });

    test('todo lo que está escrito se llega a ver en un pueblo', () {
      // El número que importa no es cuántas hay escritas sino cuántas se ven.
      // Antes había noventa y cuatro y lo que se medía era que salieran
      // bastantes; ahora hay pocas a propósito, y lo que hay que exigir es lo
      // contrario: que **ninguna** se quede sin salir. Una fila escrita que no
      // se sortea nunca es una fila muerta.
      final t = _town(400);
      final vistas = <String>{};
      for (final w in folkOf(t, 400)) {
        for (final d in w.debugActs) {
          if (d != null) vistas.add(d.id);
        }
      }
      for (final d in Doing.all) {
        expect(vistas, contains(d.id), reason: '${d.id} no le toca a nadie');
      }
    });

    test('todas las de la tabla son alcanzables desde algún sitio', () {
      // Una actividad que ninguna clase de sitio puede sortear es una
      // actividad escrita y nunca vista.
      for (final d in Doing.all) {
        final crios = d.fits(true), mayores = d.fits(false);
        expect(crios || mayores, isTrue, reason: '${d.id} no le toca a nadie');
        expect(d.weight, greaterThan(0), reason: '${d.id} no sale nunca');
      }
      final ids = {for (final d in Doing.all) d.id};
      expect(ids.length, Doing.all.length, reason: 'hay dos con el mismo id');
    });

    test('el mismo vecino hace lo mismo dos veces', () {
      final a = folkOf(_town(200), 200), b = folkOf(_town(200), 200);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].debugActs, b[i].debugActs);
        expect(a[i].kid, b[i].kid);
        expect(a[i].build, b[i].build);
      }
    });

    test('hay críos, y son más chicos', () {
      final gente = folkOf(_town(400), 400);
      final crios = gente.where((w) => w.kid).toList();
      expect(crios.length, greaterThan(3));
      expect(crios.length, lessThan(gente.length ~/ 2));
      for (final w in crios) {
        expect(w.build, lessThan(0.85));
      }
      for (final w in gente.where((w) => !w.kid)) {
        expect(w.build, greaterThan(0.85));
      }
    });

    test('nadie se llama igual que su vecino de al lado', () {
      // No es que no puedan repetirse dos en un pueblo de trescientas casas;
      // es que con una lista corta se repetirían todo el rato.
      final gente = folkOf(_town(400), 400);
      final nombres = {for (final w in gente) w.name};
      expect(nombres.length, greaterThan(gente.length * 0.8));
    });
  });

  group('lo que mide una persona', () {
    /// Lo que mide una planta de suelo a techo, y una ventana, en un pueblo de
    /// verdad de esta región. Medido de la mampostería y no de una constante:
    /// si mañana cambia el carácter, el test cambia con él.
    (double planta, double ventana) medidas(TownCharacter c) {
      final t = TownLayout(300, c);
      var planta = 0.0;
      for (var i = 0; i < math.min(300, t.pieces.length); i++) {
        final p = t.pieces[i];
        if (t.buildings[p.building].isLandmark) continue;
        // La planta baja: lo que arranca del suelo y llega a donde llega.
        if (p.y0 < 0.05 && p.y1 > planta && p.y1 < 3) planta = p.y1;
      }
      // Una ventana ocupa el cuarenta por ciento de su planta: lo dice la
      // receta que las abre, `wy0 = base + alto * 0.34`, `wy1 = + 0.74`.
      return (planta, planta * 0.40);
    }

    test(
      'no son enanos: una persona pasa de la ventana por la que se asoma',
      () {
        // El fallo que esto existe para cazar se ve a simple vista en cuanto uno
        // se acerca, y estuvo ahí desde el primer día: la talla era un 0.58
        // puesto a ojo en mitad del render, y con él una persona medía media
        // planta y no llegaba a lo alto de su propia ventana.
        //
        // Los márgenes bajaron un cuarto cuando la figura se hizo cabezona:
        // lo que la cuenta da es lo que mide una persona de verdad, y una
        // figura con media cabeza por cuerpo a esa talla sale gigante. Lo que
        // se sigue exigiendo es lo mismo — que pase de su ventana, que no pase
        // de su pared y que quepa por su puerta—; sólo cambia contra qué.
        for (final c in TownCharacter.all) {
          final (planta, ventana) = medidas(c);
          final alto = TownPainter.folkHeight(c);
          expect(
            alto,
            greaterThan(ventana * 1.02),
            reason: '${c.region}: una persona no llega a su ventana',
          );
          expect(
            alto,
            lessThan(ventana * 1.45),
            reason: '${c.region}: una persona es más alta que la pared',
          );
          expect(
            alto / planta,
            inInclusiveRange(0.46, 0.60),
            reason: '${c.region}: una persona no cabe por su propia puerta',
          );
        }
      },
    );

    test('y los críos son críos, no adultos encogidos', () {
      final t = _town(400);
      final gente = folkOf(t, 400);
      final alto = TownPainter.folkHeight(t.character);
      for (final w in gente) {
        final suyo = alto * w.build;
        if (w.kid) {
          expect(suyo, lessThan(alto * 0.8));
          expect(suyo, greaterThan(alto * 0.6));
        } else {
          expect(suyo, greaterThan(alto * 0.9));
          expect(suyo, lessThan(alto * 1.12));
        }
      }
    });
  });

  group('el expositor de la gente', () {
    test('el de muestra hace lo que se le pide y nada más', () {
      for (final d in Doing.all) {
        final w = Townsfolk.showcase(d);
        expect(w.debugActs, [d]);
        for (final s in [0.0, 5.0, 90.0, 4000.0]) {
          final at = w.at(s);
          expect(at.act, d, reason: '${d.id} cambia de idea sola');
          expect(at.moving, isFalse);
          expect(at.x, 0);
          expect(at.z, 0);
        }
      }
    });

    test('y el reloj del gesto corre, que es lo que se va a mirar', () {
      // Un expositor donde todo sale congelado no sirve para revisar
      // animaciones, que es literalmente para lo que existe.
      final w = Townsfolk.showcase(Doing.all.first);
      expect(w.at(10).phase, greaterThan(w.at(2).phase));
    });

    test('se puede pedir crío o mayor cuando la cosa admite los dos', () {
      for (final d in Doing.all) {
        if (d.who != Who.anyone) continue;
        expect(Townsfolk.showcase(d, kid: true).kid, isTrue, reason: d.id);
        expect(Townsfolk.showcase(d, kid: false).kid, isFalse, reason: d.id);
      }
    });

    test('lo que se lleva no le atraviesa el cuerpo a quien lo lleva', () {
      // **Lo que caza esto**: un objeto metido dentro de la persona. Un
      // caldero que sale del pecho, un laúd clavado en la barriga, una caña
      // que le cruza la cabeza. Pasa sin que nadie lo note porque el objeto
      // se escribe con números sueltos y el cuerpo está a una distancia que
      // no se mira — y después, en el pueblo, se ve un vecino con una cosa
      // saliéndole de dentro.
      //
      // **Cómo se mide.** El cuerpo y la cabeza son dos cajas rectas, así que
      // su caja envolvente es exacta. El objeto no: una soga o un mango van
      // en diagonal, y su caja envolvente es mucho más grande que la soga, de
      // modo que compararlas daría por malo casi todo. Lo que se compara son
      // **puntos sobre las aristas** del objeto: si una vara cruza el pecho,
      // alguno de sus puntos cae dentro. Y se deja tocar —un objeto apoyado
      // en el cuerpo está bien— pidiendo que entre de verdad, más de un
      // centímetro y medio de los de esta escala.
      const dentro = 0.015;
      const pasos = 10;
      for (final d in Doing.all) {
        if (d.prop == PropKind.none) continue;
        final quien = Townsfolk.showcase(d, kid: d.who == Who.kid);
        for (final t in [0.0, 0.9, 1.8, 2.7, 3.6, 4.5]) {
          final piezas = folkSolids(quien, quien.at(t), 1.0);
          final cuerpo = [for (final s in piezas.take(2)) Aabb.of(s.faces)!];
          for (final cosa in piezas.skip(3)) {
            for (final f in cosa.faces) {
              for (var i = 0; i < f.v.length; i++) {
                final a = f.v[i], b = f.v[(i + 1) % f.v.length];
                for (var k = 0; k <= pasos; k++) {
                  final u = k / pasos;
                  final x = a.x + (b.x - a.x) * u;
                  final y = a.y + (b.y - a.y) * u;
                  final z = a.z + (b.z - a.z) * u;
                  for (final c in cuerpo) {
                    final metido =
                        x > c.x0 + dentro &&
                        x < c.x1 - dentro &&
                        y > c.y0 + dentro &&
                        y < c.y1 - dentro &&
                        z > c.z0 + dentro &&
                        z < c.z1 - dentro;
                    expect(
                      metido,
                      isFalse,
                      reason:
                          '${d.id}: lo que lleva le entra en el cuerpo por '
                          '(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, '
                          '${z.toStringAsFixed(2)})',
                    );
                  }
                }
              }
            }
          }
        }
      }
    });

    test('y cada una se mueve de una manera que no tiene ninguna otra', () {
      // Dos filas con nombres distintos y el mismo gesto son una actividad
      // con dos nombres. Pasó: había una siesta en la puerta y alguien
      // mirando las nubes en el prado, tumbados los dos con los mismos
      // números. Lo que distingue a una de otra es la mezcla de postura,
      // vaivén y objeto — si dos coinciden en todo, sobra una.
      final huellas = <String, String>{};
      for (final d in [Doing.idle, ...Doing.all]) {
        final huella = [
          d.lying,
          d.prop.name,
          d.sink.toStringAsFixed(2),
          d.bob.toStringAsFixed(3),
          d.rate.toStringAsFixed(2),
          d.wag.toStringAsFixed(3),
          d.lean.toStringAsFixed(3),
        ].join('|');
        expect(
          huellas.containsKey(huella),
          isFalse,
          reason: '${d.id} y ${huellas[huella]} son el mismo gesto',
        );
        huellas[huella] = d.id;
      }
    });

    test('todas dan geometría, y ninguna se queda en nada', () {
      // Lo que esto caza es una fila de la tabla con los números a cero: una
      // actividad que existe, se sortea, y se ve igual que no hacer nada.
      for (final d in Doing.all) {
        final w = Townsfolk.showcase(d, kid: d.who == Who.kid);
        final solids = folkSolids(w, w.at(3.4), 0.6);
        expect(solids, isNotEmpty, reason: '${d.id} no dibuja nada');
        for (final s in solids) {
          for (final f in s.faces) {
            expect(f.v.length, greaterThanOrEqualTo(3), reason: d.id);
            for (final v in f.v) {
              expect(
                v.x.isFinite && v.y.isFinite && v.z.isFinite,
                isTrue,
                reason: '${d.id} saca un vértice que no es un número',
              );
            }
          }
        }
      }
    });
  });

  group('el día y la noche', () {
    double luz(double hora, {Season season = Season.none}) =>
        Palette.forMoment(hora, 1.0, season: season).daylight;

    test('de día están fuera y de noche dentro', () {
      expect(folkHome(luz(13)), 0.0);
      expect(folkHome(luz(9)), 0.0);
      expect(folkHome(luz(23)), 1.0);
      expect(folkHome(luz(3)), 1.0);
    });

    test('y se van yendo, no desaparecen de golpe', () {
      // Un pueblo que se vacía en un fotograma es una luz que se apaga. Lo que
      // tiene que verse es a todo el mundo tirando para su casa.
      var antes = 0.0;
      var subidas = 0;
      for (var h = 16.0; h < 22.0; h += 0.1) {
        final ahora = folkHome(luz(h));
        expect(ahora, greaterThanOrEqualTo(antes - 1e-9));
        if (ahora > antes + 1e-9) subidas++;
        antes = ahora;
      }
      expect(subidas, greaterThan(8), reason: 'se recogen de golpe');
      expect(antes, 1.0);
    });

    test('en invierno se recogen antes que en verano', () {
      // Sin ninguna hora escrita en ningún sitio: sale de la luz que hay.
      final invierno = Season.on(DateTime(2026, 12, 21), Hemisphere.north);
      final verano = Season.on(DateTime(2026, 6, 21), Hemisphere.north);
      expect(
        folkHome(luz(18, season: invierno)),
        greaterThan(folkHome(luz(18, season: verano))),
      );
    });
  });

  group('un pueblo desatendido se queda vacío', () {
    test('cuanto peor está, menos gente sale', () {
      var antes = folkOut(1.0);
      for (final i in [0.9, 0.7, 0.5, 0.3, 0.12]) {
        final ahora = folkOut(i);
        expect(ahora, lessThan(antes), reason: 'con integridad $i');
        antes = ahora;
      }
    });

    test('con el pueblo entero sale todo el mundo', () {
      expect(folkOut(1.0), greaterThanOrEqualTo(1.0));
    });

    test('pero nunca se queda solo del todo', () {
      // Igual que la integridad no llega a cero: el pueblo se apaga, no se
      // muere. Siempre queda alguien.
      expect(folkOut(0.0), greaterThan(0.15));
    });
  });

  group('el ritmo de los gestos', () {
    // Un gesto que dura poco es un gesto que vuelve a empezar enseguida, y con
    // cuarenta vecinos haciendo eso a la vez el pueblo parpadea. Lo que se
    // quiere mirar es gente **estando** en un sitio.
    test('el pueblo pasa más tiempo estando que yendo', () {
      // En conjunto y no vecino a vecino: a alguno le tocan los tres recados
      // en la otra punta y se pasa el día andando, y eso está bien. Lo que no
      // puede ser es que el pueblo entero se lea como tráfico.
      final t = _town(200);
      var parado = 0, andando = 0;
      for (final w in folkOf(t, 200)) {
        const pasos = 900;
        for (var k = 0; k < pasos; k++) {
          if (w.at(w.period * k / pasos).moving) {
            andando++;
          } else {
            parado++;
          }
        }
      }
      expect(
        parado,
        greaterThan(andando),
        reason:
            'el pueblo pasa más tiempo yendo a sitios que estando en '
            'ellos, y entonces lo que se ve es tráfico y no vida',
      );
    });

    test('al llegar se para antes de ponerse, y termina antes de irse', () {
      // Sin esto, una persona pasaba de andar a estar barriendo entre dos
      // fotogramas: la escoba aparecía en la mano sin que nadie se hubiera
      // parado a sacarla.
      final t = _town(200);
      var visto = 0;
      for (final w in folkOf(t, 200)) {
        // Hasta no haberlo visto andar no se sabe si lo que hay es una llegada
        // o el medio de una parada que empezó antes del primer fotograma.
        var venia = false;
        for (var k = 0; k < 1500; k++) {
          final at = w.at(w.period * k / 1500);
          if (at.moving) {
            venia = true;
            continue;
          }
          if (!venia) continue;
          venia = false;
          // Justo después de andar, lo que hay es alguien quieto mirando y no
          // ya metido en faena.
          expect(
            at.act,
            Doing.idle,
            reason:
                '${w.name} llega y empieza el gesto en el mismo '
                'fotograma en que deja de andar',
          );
          visto++;
        }
      }
      expect(visto, greaterThan(20), reason: 'no se vio ninguna llegada');
    });
  });

  group('tumbarse', () {
    // Lo que esto caza: la cabeza no giraba con el cuerpo. Alguien tumbado
    // mirando las nubes salía con el pelo hacia arriba, o sea con la coronilla
    // apuntando al cielo y la cara hacia los pies, que es la postura de nadie.
    test('la coronilla apunta al lado contrario al cuerpo, no al cielo', () {
      for (final d in Doing.all) {
        if (!d.lying) continue;
        final who = Townsfolk.showcase(d);
        final solidos = folkSolids(who, who.at(0), 1.0);
        // Cuerpo, cabeza y pelo: las tres cajas de una figura acostada.
        expect(solidos.length, greaterThanOrEqualTo(3), reason: d.id);
        final cuerpo = _caja(solidos[0]);
        final cabeza = _caja(solidos[1]);
        final pelo = _caja(solidos[2]);

        // La cabeza está a un extremo del cuerpo, no encima.
        expect(
          cabeza.$5,
          greaterThan(cuerpo.$5),
          reason: '${d.id}: la cabeza no está en un extremo',
        );

        // Y el pelo está en el canto de más allá de la cabeza —la coronilla—,
        // no sobre ella. Es lo único que dice hacia dónde mira la cara cuando
        // no hay cara que mirar.
        final altoCabeza = cabeza.$4 - cabeza.$3;
        final altoPelo = pelo.$4 - pelo.$3;
        expect(
          altoPelo,
          greaterThan(altoCabeza * 0.7),
          reason: '${d.id}: el pelo sigue siendo una tapa encima de la cabeza',
        );
        expect(
          pelo.$5,
          greaterThan(cabeza.$5),
          reason: '${d.id}: el pelo no está en la coronilla',
        );
      }
    });

    test('y de pie el pelo sigue siendo un gorro, que es donde va', () {
      // La otra mitad de lo mismo: al arreglar la postura de tumbado no se
      // puede haber movido el pelo de quien está de pie.
      final who = Townsfolk.showcase(Doing.idle);
      final solidos = folkSolids(who, who.at(0), 1.0);
      final cabeza = _caja(solidos[1]);
      final pelo = _caja(solidos[2]);
      expect(
        pelo.$3,
        greaterThan((cabeza.$3 + cabeza.$4) / 2),
        reason:
            'el pelo de alguien de pie tiene que estar en la mitad de '
            'arriba de la cabeza',
      );
    });
  });
}

/// Los límites de una caja: (x0, x1, y0, y1, zMedio).
(double, double, double, double, double) _caja(Solid s) {
  var x0 = double.infinity, y0 = double.infinity, z0 = double.infinity;
  var x1 = -double.infinity, y1 = -double.infinity, z1 = -double.infinity;
  for (final f in s.faces) {
    for (final v in f.v) {
      if (v.x < x0) x0 = v.x;
      if (v.x > x1) x1 = v.x;
      if (v.y < y0) y0 = v.y;
      if (v.y > y1) y1 = v.y;
      if (v.z < z0) z0 = v.z;
      if (v.z > z1) z1 = v.z;
    }
  }
  return (x0, x1, y0, y1, (z0 + z1) / 2);
}

void _nacimientos() {
  group('el censo se guarda, pero no de más', () {
    test('un vecino nace en cuanto se remata su casa', () {
      // La caché de la gente está puesta contra la rejilla de casillas libres:
      // si una pieza no tapa ninguna casilla nueva, nadie cambia de camino y
      // se reutiliza la gente de antes. Eso es cierto para los caminos y falso
      // para los nacimientos — lo que remata una casa suele ser el tejado, que
      // va encima de lo ya ocupado y deja la rejilla exactamente igual.
      //
      // Sin la parte de la huella que cuenta las casas terminadas, este test
      // falla: el vecino no aparece hasta la siguiente pieza que mueva un
      // obstáculo, que puede ser muchas piezas después.
      for (final ch in TownCharacter.all) {
        final full = TownLayout(400, ch, seed: 11);
        final remates = <int>[];
        for (final b in full.buildings) {
          if (b.isLandmark) continue;
          final fin = b.firstPiece + b.cost;
          if (fin > 1 && fin <= 400) remates.add(fin);
        }
        expect(remates, isNotEmpty, reason: '${ch.region}: no remata ninguna');
        for (final fin in remates.take(6)) {
          final antes = folkOf(full, fin - 1).length;
          final despues = folkOf(full, fin).length;
          expect(
            despues,
            greaterThan(antes),
            reason:
                '${ch.region}: se remató una casa en la pieza $fin y no nació '
                'nadie ($antes → $despues)',
          );
        }
      }
    });
  });
}
