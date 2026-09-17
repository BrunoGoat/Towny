import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/constellations.dart';

/// El ángulo real entre dos estrellas, desde su ascensión recta y su
/// declinación. Es la respuesta contra la que se mide todo lo demás.
double trueAngle(Star a, Star b) {
  List<double> unit(Star s) {
    final ra = s.ra * math.pi / 12.0, dec = s.dec * math.pi / 180.0;
    final cd = math.cos(dec);
    return [cd * math.cos(ra), cd * math.sin(ra), math.sin(dec)];
  }

  final u = unit(a), v = unit(b);
  final dot = (u[0] * v[0] + u[1] * v[1] + u[2] * v[2]).clamp(-1.0, 1.0);
  return math.acos(dot);
}

/// Y el ángulo entre dos direcciones del cielo de la app.
double skyAngle((double, double) a, (double, double) b) {
  List<double> unit((double, double) p) {
    final ce = math.cos(p.$2);
    return [math.sin(p.$1) * ce, math.sin(p.$2), math.cos(p.$1) * ce];
  }

  final u = unit(a), v = unit(b);
  final dot = (u[0] * v[0] + u[1] * v[1] + u[2] * v[2]).clamp(-1.0, 1.0);
  return math.acos(dot);
}

void main() {
  group('las ocho son de verdad', () {
    test('están completas y bien formadas', () {
      expect(constellations.length, 8);
      expect(constellations.map((c) => c.id).toSet().length, 8);
      for (final c in constellations) {
        expect(c.id, matches(RegExp(r'^[a-z]+$')));
        expect(c.name, isNotEmpty);
        expect(c.latin, isNotEmpty);
        expect(c.blurb, isNotEmpty);
        expect(c.stars.length, greaterThanOrEqualTo(4), reason: c.id);
        // Los trazos van de a pares, y ninguno apunta a una estrella que no
        // está.
        expect(c.lines.length.isEven, isTrue, reason: c.id);
        // Dos, y no tres: la Cruz del Sur son exactamente dos trazos, y es la
        // constelación más chica de las ochenta y ocho por algo.
        expect(c.lines.length ~/ 2, greaterThanOrEqualTo(2), reason: c.id);
        for (final k in c.lines) {
          expect(k, inInclusiveRange(0, c.stars.length - 1), reason: c.id);
        }
        for (final s in c.stars) {
          expect(s.ra, inInclusiveRange(0.0, 24.0), reason: c.id);
          expect(s.dec, inInclusiveRange(-90.0, 90.0), reason: c.id);
          expect(s.mag, inInclusiveRange(-2.0, 7.0), reason: c.id);
        }
        // Y ninguna estrella suelta: una figura es lo que se une.
        final touched = c.lines.toSet();
        for (var k = 0; k < c.stars.length; k++) {
          expect(
            touched,
            contains(k),
            reason: '${c.id}: la estrella $k no se une a nada',
          );
        }
      }
    });

    test('las separaciones conocidas salen donde tienen que salir', () {
      // Contra el cielo, no contra sí mismas. Si alguien copia mal una
      // coordenada, esto se entera.
      double between(String id, int a, int b) {
        final c = constellationOf(id)!;
        return trueAngle(c.stars[a], c.stars[b]) * 180 / math.pi;
      }

      // Los dos punteros del Carro, Dubhe y Merak: cinco grados y pico.
      expect(between('osamayor', 0, 1), closeTo(5.37, 0.15));
      // Betelgeuse a Rigel, de hombro a pie de Orión.
      expect(between('orion', 0, 6), closeTo(18.6, 0.3));
      // Y el cinturón entero, de Mintaka a Alnitak.
      expect(between('orion', 2, 4), closeTo(2.73, 0.15));
      // Vega a Sheliak, el lado corto de la Lira. Seis grados justos: puesto a
      // mano quedó en 5,79 y el test lo cazó — la cuenta a partir de las
      // coordenadas reales da 6,04, y las coordenadas eran las buenas.
      expect(between('lira', 0, 3), closeTo(6.04, 0.1));
      // El palo largo de la Cruz, Acrux a Gacrux.
      expect(between('cruz', 0, 1), closeTo(6.0, 0.2));
    });

    test('colgarla del cielo no le deforma la figura', () {
      // Lo único que importa de todo esto: que lo que se dibuja siga siendo la
      // constelación. Se cuelga de sitios muy distintos del cielo y se
      // comprueba que todos los ángulos entre sus estrellas guardan la
      // proporción real.
      //
      // La proporción y no el ángulo a secas, desde que la figura se encoge a
      // la mitad para colgarla: a tamaño real, la Osa Mayor ocupaba la pantalla
      // de canto a canto y dejaba de ser un detalle del cielo para ser el
      // fondo. Lo que se pierde al encogerla es poder decir que el tamaño en
      // pantalla es el tamaño de verdad; lo que **no** se pierde —y es lo que
      // la hace reconocible— es la forma, porque todos los ángulos se encogen
      // por igual. Eso es justo lo que mide esto: si uno solo se encogiera
      // distinto, la figura sería otra.
      for (final c in constellations) {
        for (final az in [0.0, 1.9, -2.6]) {
          for (final el in [0.25, 0.6, 1.0]) {
            final at = hang(c, az, el);
            expect(at.length, c.stars.length);
            // Todos los pares, y lo que se compara es **la misma proporción
            // para todos**: si un lado se encogiera distinto que otro, la
            // figura sería otra figura.
            final razones = <double>[];
            for (var i = 0; i < c.stars.length; i++) {
              for (var j = i + 1; j < c.stars.length; j++) {
                final real = trueAngle(c.stars[i], c.stars[j]);
                if (real < 1e-6) continue;
                razones.add(skyAngle(at[i], at[j]) / real);
              }
            }
            final min = razones.reduce(math.min);
            final max = razones.reduce(math.max);
            //
            // Tres centésimas y media de margen, y viene todo de encoger: a
            // tamaño real esto clavaba el ángulo exacto y el margen era cero.
            // Encoger en el plano tangente es hacer zoom con una lente, y una
            // lente no reparte por igual — en Escorpio, que son veinticinco
            // grados de cielo, el lado largo se encoge un dos por ciento
            // distinto del corto. Es invisible y es el precio de que la figura
            // quepa; lo que este número vigila es que siga siendo eso y no un
            // `hang` roto, que daría proporciones dispares de verdad.
            expect(
              max - min,
              lessThan(0.035),
              reason:
                  '${c.id}: colgada en $az/$el se deforma — unos lados se '
                  'encogen mucho más que otros (de $min a $max)',
            );
            // Y la proporción es la que se pidió. No clava el medio exacto
            // porque el plano tangente es gnomónico y la tangente no es
            // lineal: encoger a la mitad la coordenada no encoge a la mitad
            // exacta el ángulo, y en una figura de veinticinco grados eso es
            // un uno por ciento. Lo que importa es que sea igual para todos,
            // que es lo de arriba.
            expect(
              (min + max) / 2,
              closeTo(Constellation.skyScale, 0.03),
              reason: '${c.id}: no se encogió lo que se pidió',
            );
          }
        }
      }
    });

    test('y queda centrada donde se la cuelga', () {
      for (final c in constellations) {
        final at = hang(c, 1.2, 0.5);
        var mx = 0.0, my = 0.0, mz = 0.0;
        for (final (az, el) in at) {
          final ce = math.cos(el);
          mx += math.sin(az) * ce;
          my += math.sin(el);
          mz += math.cos(az) * ce;
        }
        final n = at.length;
        final middle = (
          math.atan2(mx / n, mz / n),
          math.asin(
            (my / n) /
                math.sqrt(
                  (mx / n) * (mx / n) +
                      (my / n) * (my / n) +
                      (mz / n) * (mz / n),
                ),
          ),
        );
        expect(middle.$1, closeTo(1.2, 0.05), reason: c.id);
        expect(middle.$2, closeTo(0.5, 0.05), reason: c.id);
      }
    });

    test('hay noches con figura y noches sin ninguna', () {
      // Ésta es la mitad del asunto. Una figura cada noche sin falta es una
      // agenda; lo que hace que valga la pena mirar hacia arriba es que a
      // veces no hay nada. Ni todas ni tan pocas que no se vea ninguna en una
      // semana: entre la mitad y las tres cuartas partes de las noches.
      var con = 0;
      for (var n = 0; n < 400; n++) {
        if (tonight(n) != null) con++;
      }
      expect(con, greaterThan(200), reason: 'casi nunca hay cielo');
      expect(con, lessThan(300), reason: 'hay cielo todas las noches');
    });

    test('y en un mes salen las ocho, sin que ninguna se quede fuera', () {
      // Al azar puro habría quien esperase un año por la última, y eso deja de
      // ser un hallazgo y pasa a ser un peaje.
      for (final from in [0, 1, 57, 4000]) {
        final seen = <String>{};
        for (var d = 0; d < 30; d++) {
          final c = tonight(from + d);
          if (c != null) seen.add(c.id);
        }
        expect(
          seen.length,
          constellations.length,
          reason: 'desde la noche $from',
        );
      }
    });

    test('la misma noche da siempre lo mismo', () {
      // Quien salga a las nueve y vuelva a la una tiene que encontrar lo
      // mismo: la noche es una y la figura es la de esa noche.
      for (final n in [0, 3, 77, 512, 99991]) {
        expect(tonight(n)?.id, tonight(n)?.id);
        expect(tonight(n) == null, tonight(n) == null);
      }
    });

    test('la noche cambia a mediodía y no a medianoche', () {
      // Quien mira el cielo a la una de la mañana está en la misma noche que a
      // las once de la anterior. Cambiarle la constelación en la mano por
      // haber pasado las doce sería una pequeña traición.
      final anoche = DateTime(2026, 9, 8, 23, 40);
      final madrugada = DateTime(2026, 9, 9, 1, 20);
      expect(nightOf(anoche), nightOf(madrugada));
      // Y al mediodía siguiente sí es otra.
      expect(nightOf(DateTime(2026, 9, 9, 13, 0)), isNot(nightOf(anoche)));
    });
  });
}
