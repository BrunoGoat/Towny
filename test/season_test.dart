import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/season.dart';
import 'package:towny/engine/tones.dart';
import 'package:towny/model/appearance.dart';

/// Un cuarto de vuelta al año, en días.
const int _quarter = 91;

Season _n(int month, int day) =>
    Season.on(DateTime(2026, month, day), Hemisphere.north);
Season _s(int month, int day) =>
    Season.on(DateTime(2026, month, day), Hemisphere.south);

void main() {
  group('el año da la vuelta', () {
    test('los solsticios caen donde dice el calendario', () {
      // Lo que hay que acertar y es fácil errar por un mes: en diciembre el
      // norte está en lo más crudo y el sur en lo más alto del verano.
      expect(_n(12, 21).winter, greaterThan(0.99));
      expect(_n(6, 21).summer, greaterThan(0.99));
      expect(_s(12, 21).summer, greaterThan(0.99));
      expect(_s(6, 21).winter, greaterThan(0.99));
    });

    test('los equinoccios reparten mitad y mitad', () {
      for (final (m, d) in [(3, 21), (9, 21)]) {
        final e = _n(m, d);
        expect(e.winter, closeTo(0.5, 0.06), reason: '$d/$m');
        expect(e.summer, closeTo(0.5, 0.06), reason: '$d/$m');
      }
    });

    test('primavera y otoño no coinciden nunca', () {
      // Son los dos caminos entre invierno y verano, así que a lo sumo uno de
      // los dos está encendido. Si los dos pesaran a la vez, las hojas
      // estarían brotando y cayéndose el mismo día.
      for (var d = 0; d < 366; d++) {
        final s = Season.on(
          DateTime(2026).add(Duration(days: d)),
          Hemisphere.north,
        );
        expect(
          s.spring * s.autumn,
          lessThan(1e-9),
          reason: 'el día $d es primavera y otoño a la vez',
        );
      }
    });

    test('cada estación tiene su pico un mes después de su equinoccio', () {
      // **El suelo va por detrás del sol.** El equinoccio de septiembre es el
      // primer día del otoño, no el de más otoño: las hojas tardan cinco
      // semanas en dorarse, igual que el mes más caluroso es julio y no junio.
      //
      // Estaba sin ese retraso y cada estación daba su máximo el día que
      // empezaba, para ir apagándose durante los tres meses que duraba. Abajo
      // se veía peor que arriba, porque el error cae en otros meses: en
      // Montevideo nevaba en mayo y agosto salía sin un copo.
      expect(_n(11, 1).autumn, greaterThan(0.98));
      expect(_n(5, 1).spring, greaterThan(0.98));
      expect(_n(11, 1).spring, lessThan(0.02));
      expect(_n(5, 1).autumn, lessThan(0.02));
      // Y en el equinoccio mismo va subiendo, que es lo que hace un otoño que
      // empieza.
      expect(_n(9, 21).autumn, inInclusiveRange(0.5, 0.95));
    });

    test('lo que se ve por la ventana en Montevideo', () {
      // Las tres fechas que contó quien lo vio: agosto es lo más crudo del
      // invierno, mayo es el oro del otoño y el 1 de octubre es primavera.
      // Antes del retraso, agosto salía sin nieve con el prado verdeando,
      // mayo salía nevado y el oro del otoño caía en marzo.
      final agosto = _s(8, 10);
      expect(agosto.snow, greaterThan(0.9), reason: 'agosto sin nieve');
      expect(agosto.autumn, lessThan(0.05), reason: 'agosto dorado');

      final mayo = _s(5, 1);
      expect(mayo.autumn, greaterThan(0.9), reason: 'mayo sin oro');
      expect(mayo.snow, 0, reason: 'nieve en mayo');

      final octubre = _s(10, 1);
      expect(octubre.snow, 0);
      expect(octubre.autumn, 0);
      expect(octubre.spring, greaterThan(0.85));
    });

    test('el nombre cambia el 21, como el almanaque', () {
      // Nombraba el cuarto de año centrado en cada solsticio —invierno del 5
      // de noviembre al 4 de febrero— así que iba media estación por delante
      // del calendario: en agosto, en Montevideo, decía «primavera».
      expect(_n(12, 21).name, 'Invierno');
      expect(_n(3, 21).name, 'Primavera');
      expect(_n(6, 21).name, 'Verano');
      expect(_n(9, 21).name, 'Otoño');
      expect(_s(6, 21).name, 'Invierno');
      expect(_s(9, 21).name, 'Primavera');
      expect(_s(12, 21).name, 'Verano');
      expect(_s(3, 21).name, 'Otoño');
      // Y en medio de cada una, lo mismo.
      expect(_s(8, 10).name, 'Invierno');
      expect(_s(10, 1).name, 'Primavera');
    });

    test('el nombre acompaña al número', () {
      expect(_n(1, 15).name, 'Invierno');
      expect(_n(4, 15).name, 'Primavera');
      expect(_n(7, 15).name, 'Verano');
      expect(_n(10, 15).name, 'Otoño');
      // Y en el sur, al revés, el mismo día.
      expect(_s(1, 15).name, 'Verano');
      expect(_s(7, 15).name, 'Invierno');
    });

    test('el sur va medio año por delante del norte', () {
      for (var d = 0; d < 366; d += 7) {
        final day = DateTime(2026).add(Duration(days: d));
        final n = Season.on(day, Hemisphere.north);
        final s = Season.on(day, Hemisphere.south);
        expect(
          n.winter,
          closeTo(s.summer, 1e-9),
          reason: 'el día $d los dos lados están en lo mismo',
        );
      }
    });

    test('nada da un salto de un día para el otro', () {
      // Un mundo que cambia de color de golpe una noche está mal. Lo más que
      // se puede mover cualquiera de estos números en un día es lo que se
      // mueve un coseno en un día, que es muy poco.
      var prev = Season.on(DateTime(2026), Hemisphere.north);
      for (var d = 1; d < 400; d++) {
        final s = Season.on(
          DateTime(2026).add(Duration(days: d)),
          Hemisphere.north,
        );
        for (final (nombre, a, b) in [
          ('invierno', prev.winter, s.winter),
          ('nieve', prev.snow, s.snow),
          ('hoja', prev.bare, s.bare),
          ('amanecer', prev.sunrise, s.sunrise),
        ]) {
          expect(
            (a - b).abs(),
            lessThan(0.09),
            reason: '$nombre pegó un salto en el día $d',
          );
        }
        prev = s;
      }
    });
  });

  group('la luz del día', () {
    test('el día más largo es el de verano y el más corto el de invierno', () {
      final verano = _n(6, 21).daylightHours;
      final invierno = _n(12, 21).daylightHours;
      expect(verano, greaterThan(invierno + 4));
      // Y son duraciones de un sitio donde vive gente, no de Islandia.
      expect(verano, inInclusiveRange(13.0, 15.5));
      expect(invierno, inInclusiveRange(8.5, 11.0));
    });

    test('el mediodía solar no se mueve', () {
      for (var d = 0; d < 366; d += 11) {
        final s = Season.on(
          DateTime(2026).add(Duration(days: d)),
          Hemisphere.north,
        );
        expect((s.sunrise + s.sunset) / 2, closeTo(Season.noon, 1e-9));
      }
    });

    test('en los equinoccios el día y la noche se parecen', () {
      expect(_n(3, 21).daylightHours, closeTo(12.1, 0.6));
    });
  });

  group('la nieve y la hoja', () {
    test('no hay nieve fuera de lo más crudo del invierno', () {
      // Una escarcha de nueve meses sería peor que no tener estaciones.
      var conNieve = 0;
      for (var d = 0; d < 365; d++) {
        final s = Season.on(
          DateTime(2026).add(Duration(days: d)),
          Hemisphere.north,
        );
        if (s.snow > 0.02) conNieve++;
      }
      expect(conNieve, inInclusiveRange(40, 130), reason: '$conNieve días');
      expect(_n(6, 21).snow, 0);
      expect(_n(9, 21).snow, 0);
      expect(_n(1, 5).snow, greaterThan(0.5));
    });

    test('primero se doran las hojas y después se caen', () {
      // El orden importa: un árbol pelado en pleno otoño dorado es un árbol
      // que se saltó la mitad bonita.
      final dorado = _n(10, 20);
      expect(dorado.autumn, greaterThan(0.6));
      expect(dorado.bare, lessThan(0.45));
      final pelado = _n(1, 10);
      expect(pelado.bare, greaterThan(0.8));
      expect(pelado.autumn, lessThan(0.35));
    });
  });

  group('de qué lado del mundo', () {
    test('el país del idioma decide, y se puede equivocar hacia el norte', () {
      expect(Season.hemisphereOf('AR'), Hemisphere.south);
      expect(Season.hemisphereOf('AU'), Hemisphere.south);
      expect(Season.hemisphereOf('ES'), Hemisphere.north);
      expect(Season.hemisphereOf('US'), Hemisphere.north);
      // Sin país, el norte, que es lo que sale por defecto en todo.
      expect(Season.hemisphereOf(null), Hemisphere.north);
      expect(Season.hemisphereOf(''), Hemisphere.north);
    });
  });

  group('el año que no existe', () {
    test('Season.none es verano pleno, que es la luz de siempre', () {
      // Todo lo que estaba medido antes de que hubiera estaciones se midió con
      // esta luz. Si esto cambiara, cambiarían de golpe todas las capturas y
      // ninguna prueba diría por qué.
      expect(Season.none.summer, 1.0);
      expect(Season.none.snow, 0.0);
      expect(Season.none.bare, 0.0);
      // Y exactamente de seis a ocho, que es el día que supone el ciclo de
      // colores. Con eso, remapear la hora con Season.none es no hacer nada.
      expect(Season.none.sunrise, 6.0);
      expect(Season.none.sunset, 20.0);
    });
  });

  group('el sol sale a la hora que sale', () {
    // Lo que se vio: un 9 de octubre en Montevideo, con el sol saliendo a
    // las siete menos cuarto, a las siete menos cinco la app seguía con la
    // luna arriba. El disco estaba media hora por debajo de su propia hora
    // de salida.
    for (final (d, lado) in [
      (DateTime(2026, 10, 9), Hemisphere.south),
      (DateTime(2026, 6, 21), Hemisphere.south),
      (DateTime(2026, 12, 21), Hemisphere.south),
      (DateTime(2026, 3, 20), Hemisphere.north),
      (DateTime(2026, 1, 15), Hemisphere.north),
    ]) {
      test('${d.day}/${d.month} en el ${lado.name}', () {
        final s = Season.on(d, lado);
        bool sol(double h) => Palette.forMoment(h, season: s).isDaylight;
        const diez = 10 / 60;
        expect(sol(s.sunrise - diez), isFalse, reason: 'sol antes de salir');
        expect(sol(s.sunrise + diez), isTrue, reason: 'salió y no se ve');
        expect(sol(s.sunset - diez), isTrue, reason: 'se fue antes de ponerse');
        expect(sol(s.sunset + diez), isFalse, reason: 'sigue después');
      });
    }

    test('el 9 de octubre en el sur, a las siete menos cinco ya es de día', () {
      final s = Season.on(DateTime(2026, 10, 9), Hemisphere.south);
      expect(Palette.forMoment(6 + 55 / 60, season: s).isDaylight, isTrue);
    });
  });

  group('la hora, llevada al horario del ciclo', () {
    // La paleta guarda en `hour` la hora ya remapeada, así que se puede leer
    // desde fuera sin abrir nada privado.
    double cycle(double clock, Season s) =>
        Palette.forMoment(clock, season: s).hour;

    test('sin estación no se mueve nada', () {
      // Lo que protege todo lo que ya estaba: las capturas, los tests de cielo
      // y de silueta, los colores elegidos a mano. Si esto falla, añadir el
      // año le cambió el aspecto a la app entera sin querer.
      // Hasta las veinticuatro sin incluirlas: la paleta trabaja en módulo
      // veinticuatro, así que las veinticuatro son las cero y siempre lo
      // fueron.
      for (var h = 0.0; h < 24.0; h += 0.25) {
        expect(cycle(h, Season.none), closeTo(h, 1e-9), reason: 'a las $h');
      }
    });

    test('el amanecer de hoy cae siempre en las seis', () {
      for (final s in [_n(1, 15), _n(4, 15), _n(7, 15), _n(10, 15)]) {
        expect(cycle(s.sunrise, s), closeTo(6.0, 1e-9), reason: s.name);
        expect(cycle(s.sunset, s), closeTo(20.0, 1e-9), reason: s.name);
        expect(cycle(Season.noon, s), closeTo(Season.noon, 1e-9));
      }
    });

    test('la hora nunca va para atrás', () {
      // Es la única propiedad que no se puede romper: con un remapeo que no
      // sea monótono, el cielo daría marcha atrás a alguna hora del día.
      for (final s in [_n(1, 15), _n(4, 15), _n(7, 15), _n(10, 15)]) {
        var prev = -1.0;
        for (var h = 0.0; h < 24.0; h += 0.05) {
          final c = cycle(h, s);
          expect(c, greaterThanOrEqualTo(prev - 1e-9), reason: '${s.name} $h');
          prev = c;
        }
        expect(cycle(0, s), closeTo(0, 1e-9));
        expect(cycle(23.999, s), greaterThan(23.99));
      }
    });

    test('una mañana de invierno todavía está amaneciendo', () {
      // El asunto entero, dicho como se ve: a las ocho de un enero del norte
      // el cielo tiene que estar todavía en el amanecer —el ciclo pone el
      // amanecer entre las 5,6 y las 7,2— y a las ocho de julio ya no.
      final enero = _n(1, 15), julio = _n(7, 15);
      expect(cycle(8.0, enero), lessThan(7.2));
      expect(cycle(8.0, julio), greaterThan(7.2));
      // Y la tarde al revés: a las siete y media anochece en enero y todavía
      // es de día en julio.
      expect(cycle(19.5, enero), greaterThan(20.0));
      expect(cycle(19.5, julio), lessThan(19.6));
    });
  });

  group('y se ve en el prado', () {
    Color prado(Season s, [double h = 13]) =>
        meadowTone(Palette.forMoment(h, season: s));

    test('sin estación, ni un bit de diferencia', () {
      // El seguro de todo lo anterior a las estaciones: con el año apagado,
      // el prado tiene que salir exactamente el de siempre, a cualquier hora.
      for (var h = 0.0; h < 24.0; h += 0.5) {
        final antes = meadowTone(Palette.forMoment(h));
        final ahora = prado(Season.none, h);
        expect(ahora, antes, reason: 'a las $h');
      }
    });

    test('las cuatro se distinguen a simple vista', () {
      // Cuatro estaciones que hay que mirar dos veces para notar no son
      // cuatro estaciones. El umbral está en lo que separa dos colores que
      // cualquiera diría que son distintos.
      // En el **medio** de cada una, que es donde cada estación se parece a
      // sí misma: el suelo va un mes por detrás del sol, así que el día del
      // equinoccio el prado todavía es el de la estación que se va.
      final cuatro = {
        'invierno': prado(_n(2, 1)),
        'primavera': prado(_n(5, 1)),
        'verano': prado(_n(8, 1)),
        'otoño': prado(_n(11, 1)),
      };
      final nombres = cuatro.keys.toList();
      for (var i = 0; i < nombres.length; i++) {
        for (var j = i + 1; j < nombres.length; j++) {
          final a = cuatro[nombres[i]]!, b = cuatro[nombres[j]]!;
          final d = (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
          expect(
            d,
            greaterThan(0.10),
            reason: '${nombres[i]} y ${nombres[j]} son el mismo prado',
          );
        }
      }
    });

    test('el otoño es más cálido que el verano y no es Marte', () {
      // Lo que salió mal al teñir por razón entre colores: el ocre subía el
      // rojo vez y media y el valle quedaba plantado en Marte.
      final o = prado(_n(11, 1)), v = prado(_n(8, 1));
      expect(o.r - o.g, greaterThan(v.r - v.g), reason: 'el otoño no calienta');
      expect(o.r, lessThan(0.47), reason: 'demasiado rojo: ${o.r}');
    });

    test('la primavera es más clara y más verde que el verano', () {
      final p = prado(_n(5, 1)), v = prado(_n(8, 1));
      expect(p.computeLuminance(), greaterThan(v.computeLuminance()));
    });

    test('el invierno está nevado y las otras tres no', () {
      final i = prado(_n(2, 1));
      expect(i.computeLuminance(), greaterThan(0.28));
      for (final (m, d) in [(5, 1), (8, 1), (11, 1)]) {
        expect(prado(_n(m, d)).computeLuminance(), lessThan(0.22));
      }
    });

    test('y la nieve de noche sigue siendo de noche', () {
      // Nieve casi blanca en un paisaje nocturno es un agujero recortado. Se
      // ve —tiene que verse, es lo único claro que hay— pero no alumbra.
      final noche = prado(_n(12, 21), 2);
      final dia = prado(_n(12, 21), 13);
      expect(noche.computeLuminance(), lessThan(dia.computeLuminance() * 0.62));
      expect(
        noche.b,
        greaterThan(noche.r),
        reason: 'la nieve de noche es azul',
      );
    });
  });

  group('lo que se elige se queda elegido', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('el hemisferio sobrevive a cerrar la app', () async {
      // Lo que contó quien lo vio: «activé el hemisferio sur y no anda». Si
      // la fila se guardara mal, el valle volvería al norte en el siguiente
      // arranque y en agosto, en Montevideo, se vería otoño.
      final a = Appearance.instance;
      await a.load();
      await a.setHemisphere(Hemisphere.south);
      expect(a.hemisphere, Hemisphere.south);
      expect(a.hemisphereChosen, isTrue);
      await a.flush();

      await a.setHemisphere(null);
      await a.load();
      expect(a.hemisphere, Hemisphere.south, reason: 'no se guardó');
      expect(a.hemisphereChosen, isTrue);

      // Y al norte también: «no lo he tocado» y «lo puse en el norte» no son
      // lo mismo, porque lo primero sigue haciendo caso al teléfono.
      await a.setHemisphere(Hemisphere.north);
      await a.flush();
      await a.setHemisphere(null);
      await a.load();
      expect(a.hemisphere, Hemisphere.north);
      expect(a.hemisphereChosen, isTrue);
    });

    test('y mientras está puesto, el año se cuenta desde abajo', () async {
      final a = Appearance.instance;
      await a.load();
      await a.setHemisphere(Hemisphere.south);
      await a.setSeasons(true);
      await a.setFakeSeason(false);
      // Agosto en el sur es invierno, se mire como se mire.
      expect(
        Season.on(DateTime(2026, 8, 10), a.hemisphere).snow,
        greaterThan(0.9),
      );
    });
  });

  test('un cuarto de año es una estación', () {
    // Guarda contra que la vuelta se descuadre: del pico de una al pico de la
    // siguiente hay un cuarto de vuelta y ni un día más.
    final a = _n(12, 21).turn;
    final b = Season.on(
      DateTime(2026, 12, 21).add(const Duration(days: _quarter)),
      Hemisphere.north,
    ).turn;
    expect((b - a + 1) % 1.0, closeTo(0.25, 0.01));
  });

  group('un valle nevado que parezca nieve', () {
    final enero = _n(1, 25), julio = _n(7, 15);
    double luz(Color c) => c.r * 0.3 + c.g * 0.55 + c.b * 0.15;

    test('al mediodía la nieve es clara y fría, no gris ni hueso', () {
      // Lo que se veía: un campo gris sucio con un velo de prado debajo, y
      // la nieve tirando a amarillo por el sol de la paleta.
      final nieve = meadowTone(Palette.forMoment(13, season: enero));
      expect(luz(nieve), greaterThan(0.80));
      expect(nieve.b, greaterThanOrEqualTo(nieve.r));
    });

    test('la nieve cuaja de golpe: no hay semanas de prado gris', () {
      // El manto va por [snowCover] y no por la nieve a secas, que sube de a
      // poco: a la par, durante las semanas en que llegaba el valle era de un
      // gris barroso.
      expect(snowCover(Season.none), 0);
      expect(snowCover(julio), 0);
      var grises = 0;
      for (var d = 0; d < 365; d++) {
        final s = Season.on(
          DateTime(2026, 1, 1).add(Duration(days: d)),
          Hemisphere.north,
        );
        final c = snowCover(s);
        if (c > 0.15 && c < 0.85) grises++;
      }
      expect(grises, lessThanOrEqualTo(4), reason: '$grises días a medias');
    });

    test('las cumbres se nievan en invierno y en verano no', () {
      for (var li = 0; li < 3; li++) {
        expect(snowCap(Palette.forMoment(13, season: julio), li, 3), isNull);
        final cap = snowCap(Palette.forMoment(13, season: enero), li, 3);
        expect(cap, isNotNull);
        // Sólida: es nieve, no una luz encima de la roca.
        expect(cap!.$1.a, 1.0, reason: 'sierra $li');
      }
    });

    test('la nieve de las cumbres crece hasta enero y se retira después', () {
      // La línea de nieve es una altura del mundo: cuanto más baja, más
      // montaña blanca. Baja mes a mes hasta lo más crudo y sube igual de
      // despacio, y fuera del frío no hay.
      double? linea(int mes) =>
          snowCap(Palette.forMoment(13, season: _n(mes, 25)), 2, 3)?.$2;
      expect(linea(10), isNull);
      expect(linea(11), isNotNull);
      expect(linea(12)!, lessThan(linea(11)!));
      expect(linea(1)!, lessThanOrEqualTo(linea(12)!));
      expect(linea(2)!, greaterThan(linea(1)!));
      expect(linea(3)!, greaterThan(linea(2)!));
      expect(linea(4), isNull);
    });

    test('el aire de un día de nieve es frío, y sin nieve no cambia nada', () {
      final pal = Palette.forMoment(13, season: enero);
      final bruma = winterHaze(pal);
      expect(bruma.b, greaterThan(bruma.r));
      expect(luz(bruma), greaterThan(luz(pal.haze)));
      final verano = Palette.forMoment(13, season: julio);
      expect(winterHaze(verano), verano.haze);
      expect(winterAir(verano.groundFar, verano), verano.groundFar);
    });
  });
}
