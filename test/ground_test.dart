import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/scene.dart';
import 'package:la_muralla/engine/season.dart';
import 'package:la_muralla/engine/tones.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/fx/effects.dart';

const int _w = 320;
const int _h = 900;

/// Un prado vacío, que es donde se ve el suelo sin nada que lo tape.
Future<ByteData> frame({
  required double hour,
  double yaw = 0.4,
  double pitch = 0.42,
  double distance = 30,
  Season season = Season.none,
  int day = 0,
}) async {
  final cam = OrbitCamera()
    ..yaw = yaw
    ..yawTarget = yaw
    ..pitch = pitch
    ..pitchTarget = pitch
    ..distance = distance
    ..distanceTarget = distance;
  final scene = TownScene(
    placed: 0,
    palette: Palette.forMoment(hour, season: season),
    camera: cam,
    time: 0,
    hourOfDay: 12,
    effects: EffectSystem(),
    labelledBricks: const {},
    budget: 22000,
    day: day,
    towns: [
      TownEntry(
        // Y el pueblo, lejos. Lo que se mide aquí es el suelo desnudo, así
        // que ni el solar ni el contorno de la pieza que va a caer pueden
        // aparecer en la franja: en cuanto los solares dejaron de estar
        // siempre en el mismo sitio, a veces caían justo encima y el test
        // contaba el borde de una parcela como una raya del prado.
        layout: TownLayout(0, TownCharacter.all.first, cx: 600, cz: 600),
        name: 'Prueba',
        symbol: 'torre',
        placed: 0,
      ),
    ],
    active: 0,
  );
  final rec = ui.PictureRecorder();
  TownPainter(
    scene,
    TouchMap(),
  ).paint(Canvas(rec), const Size(_w * 1.0, _h * 1.0));
  final img = await rec.endRecording().toImage(_w, _h);
  final data = await img.toByteData();
  img.dispose();
  return data!;
}

int _at(ByteData px, int x, int y) => px.getUint32((y * _w + x) * 4);

/// Cuántas veces cambia de color una columna al bajar por ella.
///
/// Es la medida directa de lo que se veía. Una raya es un escalón: veinte
/// filas del mismo verde y de golpe otro, porque a ocho bits un degradado no
/// tiene más remedio que dar el salto en algún sitio. Un relleno plano no da
/// ninguno, y por eso no puede salir a rayas.
int steps(ByteData px, int x, int from, int to) {
  var n = 0;
  for (var y = from + 1; y < to; y++) {
    if (_at(px, x, y) != _at(px, x, y - 1)) n++;
  }
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Una franja de prado de primer plano: por debajo del horizonte, por
  // debajo de lo que el pueblo dibuja en el suelo, y dentro del círculo en el
  // que el viñeteado —que es de la atmósfera y no del suelo— todavía vale
  // cero. Lo que se mide aquí es el suelo y nada más que el suelo.
  const from = 700;
  const to = 780;
  const left = 50;
  const right = 270;

  group('el prado no se ve a rayas', () {
    test('la regla mide algo: el cielo, que sí es un degradado', () async {
      // Un test que sólo mira el resultado bueno no distingue «lo arreglé» de
      // «mi regla no mide nada». El cielo del mismo cuadro sigue siendo un
      // degradado, así que sirve de contraste: si la misma cuenta de escalones
      // no lo caza a él, tampoco valdría de nada aplicada al suelo.
      final px = await frame(hour: 12);
      final cielo = steps(px, 160, 40, 200);
      expect(
        cielo,
        greaterThan(3),
        reason:
            'el cielo, que es un degradado, sólo da $cielo escalones en '
            'ciento sesenta filas: la regla no mide lo que dice medir',
      );
    });

    test('el suelo no da un solo escalón en toda su altura', () async {
      for (final hour in [1.0, 7.0, 12.0, 19.0, 21.0]) {
        final px = await frame(hour: hour);
        for (final x in [left, 160, right]) {
          expect(
            steps(px, x, from, to),
            0,
            reason:
                'a las $hour la columna $x del prado cambia de color por el '
                'camino: eso es una raya',
          );
        }
      }
    });

    test('mire donde mire la cámara', () async {
      for (final yaw in [0.0, 1.1, 2.4, 4.0, 5.6]) {
        for (final pitch in [0.10, 0.42, 0.95]) {
          for (final distance in [12.0, 30.0, 190.0]) {
            final px = await frame(
              hour: 12,
              yaw: yaw,
              pitch: pitch,
              distance: distance,
            );
            expect(
              steps(px, 160, from, to),
              0,
              reason:
                  'con yaw $yaw, pitch $pitch y distancia $distance el prado '
                  'cambia de color al bajar',
            );
          }
        }
      }
    });

    test('y tampoco a lo ancho: es un color y nada más', () async {
      for (final hour in [1.0, 12.0, 21.0]) {
        final px = await frame(hour: hour);
        final one = _at(px, left, from);
        for (var y = from; y < to; y += 7) {
          for (var x = left; x < right; x += 5) {
            expect(
              _at(px, x, y),
              one,
              reason: 'a las $hour el píxel ($x, $y) no es el mismo verde',
            );
          }
        }
      }
    });

    test('sigue cambiando con la hora, que es lo que no había que tocar', () {
      // Lo único que se pidió conservar: que el prado sea de otro color a otra
      // hora.
      final noche = meadowTone(Palette.forMoment(1));
      final medio = meadowTone(Palette.forMoment(13));
      final tarde = meadowTone(Palette.forMoment(19));
      expect(
        noche.computeLuminance(),
        lessThan(medio.computeLuminance() * 0.4),
      );
      expect(tarde.r, greaterThan(medio.r * 0.85));
      for (final c in [noche, medio, tarde]) {
        expect(c.g, greaterThan(c.b * 0.7));
      }
    });
  });

  group('el invierno no es una sábana', () {
    // Lo que se veía: con nieve, el prado era una pared blanca de lado a lado.
    // La nieve de verdad no cubre parejo — por los claros asoma la hierba de
    // debajo— y eso es lo único que separa un campo nevado de un folio.
    //
    // Y es lo contrario de lo que pide el grupo de arriba, así que las dos
    // cosas tienen que convivir: **el prado sigue siendo un color plano las
    // tres estaciones en que no hay nieve**, porque el escalonado del que
    // venía todo aquello sigue estando ahí esperando. Las matas sólo existen
    // donde hay nieve que romper.
    const invierno = Season(0.09);

    test('con nieve asoma la hierba, y por eso el prado deja de ser uno',
        () async {
      final px = await frame(hour: 12, season: invierno);
      var distintos = 0;
      for (var y = from; y < to; y++) {
        for (var x = left; x < right; x++) {
          if (_at(px, x, y) != _at(px, left, from)) distintos++;
        }
      }
      expect(
        distintos,
        greaterThan(300),
        reason:
            'sólo $distintos píxeles de los ${(to - from) * (right - left)} de '
            'la franja se salen del blanco: la nieve sigue siendo una sábana',
      );
    });

    test('y en las otras tres sigue siendo un color y nada más', () async {
      // Primavera, verano y otoño: sin nieve no hay matas que pintar, y el
      // suelo tiene que seguir siendo el relleno plano que no se puede tramar.
      for (final s in [const Season(0.34), Season.none, const Season(0.84)]) {
        final px = await frame(hour: 12, season: s);
        for (final x in [left, 160, right]) {
          expect(
            steps(px, x, from, to),
            0,
            reason: 'la columna $x da escalones con el año en ${s.turn}',
          );
        }
      }
    });
  });

  group('las matas de la nieve', () {
    const invierno = Season(0.09);

    test('cambian de sitio y de forma cada día', () async {
      // La nieve no se posa dos noches igual. La semilla lleva la fecha
      // dentro, así que el reparto de mañana no es el de hoy — y eso es, de
      // paso, lo que hace que un valle nevado no sea un fondo de pantalla.
      final hoy = await frame(hour: 12, season: invierno, day: 20261001);
      final manana = await frame(hour: 12, season: invierno, day: 20261002);
      var dif = 0;
      for (var y = from; y < to; y++) {
        for (var x = left; x < right; x++) {
          if (_at(hoy, x, y) != _at(manana, x, y)) dif++;
        }
      }
      final total = (to - from) * (right - left);
      expect(
        dif,
        greaterThan(total ~/ 8),
        reason: 'de un día para otro sólo cambian $dif de $total píxeles',
      );
    });

    test('y están por todo el valle, no sólo junto al pueblo', () async {
      // Lo que se veía: las matas se apagaban a los veinte metros, así que de
      // lejos el valle era una sábana blanca con un pegote de hierba alrededor
      // del pueblo.
      //
      // Ahora la rejilla se hace el doble de gruesa cada vez que la cámara se
      // aleja —y cada mata tapa lo que tapaban las cuatro que sustituye— así
      // que el prado se ve igual de moteado se mire desde donde se mire. Lo
      // que se mide es eso: desde lejos, hay hierba en el primer plano, en el
      // medio y contra el horizonte.
      final px = await frame(
        hour: 12,
        season: invierno,
        day: 20261001,
        distance: 60,
        pitch: 0.3,
      );
      for (final banda in [260, 420, 700]) {
        var mata = 0;
        for (var y = banda; y < banda + 40; y++) {
          for (var x = left; x < right; x++) {
            if (_at(px, x, y) != _at(px, left, banda)) mata++;
          }
        }
        expect(
          mata,
          greaterThan(300),
          reason: 'a la altura de $banda el prado es una sábana: $mata',
        );
      }
    });
  });
}
