import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/ui/style.dart';

/// Lo clara que es una cosa, de cero a uno. La misma cuenta que usa el tema.
double _luz(Color c) => c.r * 0.3 + c.g * 0.55 + c.b * 0.15;

void main() {
  group('la tinta de la interfaz sigue a la luz que tiene detrás', () {
    test('a ninguna hora se pierde sobre el cielo', () async {
      // Ésta es la que importa. Los rótulos de arriba y los botones del
      // costado se pintan directamente sobre el techo del cielo, sin panel
      // debajo, así que lo único que los separa de él es su propio color.
      //
      // Durante mucho tiempo ese color lo decidía el **horizonte**, que es la
      // banda clara de más abajo: a las siete y media de la tarde el horizonte
      // todavía es naranja claro y el techo ya es azul de medianoche, así que
      // la interfaz salía en pardo de mediodía sobre un cielo casi negro. Se
      // veía; el test no existía.
      //
      // Lo que se mide no es que nunca se parezcan —en el instante mismo del
      // cruce la tinta pasa por el medio y el cielo del crepúsculo también—
      // sino que eso dure lo que dura un cruce y no una tarde. A tres minutos
      // por muestra se admiten cuatro en todo el día: dos por crepúsculo.
      final justas = <double>[];
      for (var h = 0.0; h < 24; h += 0.05) {
        final t = UiTheme(Palette.forMoment(h, 1.0));
        if ((_luz(t.fg) - _luz(t.palette.skyTop)).abs() < 0.25) justas.add(h);
      }
      // ignore: avoid_print
      print('minutos justos: ${justas.map((h) => h.toStringAsFixed(2))}');
      expect(
        justas.length,
        lessThanOrEqualTo(4),
        reason: 'la tinta se pierde sobre el cielo durante un buen rato',
      );
    });

    test('y va cambiando a lo largo del día, no son dos colores', () {
      // Lo otro que se pidió: que mute hora a hora. No puede hacerlo cruzando
      // por el medio —ahí no se lee— pero sí dentro de su propio lado: el
      // pardo se va templando según cae la tarde y el crema se va enfriando
      // según entra la noche.
      final tintas = <Color>{};
      for (var h = 0.0; h < 24; h += 0.25) {
        tintas.add(UiTheme(Palette.forMoment(h, 1.0)).fg);
      }
      expect(
        tintas.length,
        greaterThan(10),
        reason: 'la interfaz sólo tiene dos tintas en todo el día',
      );
      // Y las dos puntas de cada lado son distintas de verdad.
      expect(
        UiTheme(Palette.forMoment(13, 1.0)).fg,
        isNot(UiTheme(Palette.forMoment(18, 1.0)).fg),
      );
      expect(
        UiTheme(Palette.forMoment(19, 1.0)).fg,
        isNot(UiTheme(Palette.forMoment(3, 1.0)).fg),
      );
    });

    test('pero sin quedarse a medias: el cruce es corto', () {
      // Y corto, que es lo que no es obvio. A medio camino la tinta es un
      // pardo medio, y un pardo medio no contrasta con nada: un degradado
      // largo y bonito de dos horas serían dos horas de texto ilegible, que es
      // justo lo que se quería arreglar.
      var enMedio = 0;
      for (var h = 0.0; h < 24; h += 0.05) {
        final fg = UiTheme(Palette.forMoment(h, 1.0)).fg;
        final l = _luz(fg);
        if (l > 0.25 && l < 0.55) enMedio++;
      }
      // A veinte pasos por hora: unas pocas muestras en todo el día, las del
      // instante de cada cruce.
      expect(enMedio, lessThan(6), reason: 'se queda demasiado a medio camino');
    });

    test('la materia de los paneles cambia antes que la tinta', () {
      // Un panel no puede ir a medio camino —a mitad de un desvanecido es gris
      // medio y la letra encima también— así que salta. Y salta pronto: el
      // peor instante del cruce tiene que ser un pardo sobre un panel ya
      // oscuro, que se lee, y no un pardo sobre crema, que no.
      for (var h = 0.0; h < 24; h += 0.05) {
        final t = UiTheme(Palette.forMoment(h, 1.0));
        final l = _luz(t.fg);
        // Tinta a medio camino y panel todavía claro es la combinación que no
        // puede darse.
        expect(
          l > 0.30 && l < 0.55 && !t.dark,
          isFalse,
          reason: 'a las ${h.toStringAsFixed(2)} hay tinta media sobre crema',
        );
      }
    });

    test('y a mediodía y de madrugada sigue siendo lo de siempre', () {
      // Las dos puntas no se mueven: pardo hondo al mediodía —o a un paso de
      // él, que el matiz también corre— y el crema de siempre de madrugada.
      final medio = UiTheme(Palette.forMoment(13, 1.0));
      expect(medio.dark, isFalse);
      expect(_luz(medio.fg), lessThan(0.20));
      final madrugada = UiTheme(Palette.forMoment(3, 1.0));
      expect(madrugada.dark, isTrue);
      expect(madrugada.fg, const Color(0xFFF3EEE3));
      // Y las siete y media de la tarde, que es lo que se reportó, ya es noche
      // para la interfaz aunque el horizonte siga naranja.
      expect(UiTheme(Palette.forMoment(19.4, 1.0)).dark, isTrue);
      expect(_luz(UiTheme(Palette.forMoment(19.4, 1.0)).fg), greaterThan(0.80));
    });
  });
}
