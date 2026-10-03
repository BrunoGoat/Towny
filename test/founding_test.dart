import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';

/// **El día que se funda el pueblo.**
///
/// Sale una plaza de la nada: el enlosado, el tablón y el atril. El enlosado
/// sale de la tierra —es el suelo, y lo que hace es descubrirse—; los otros dos
/// caen del cielo, como cae todo lo que se pone en este pueblo.
const int _w = 420, _h = 420;

/// La plaza fundándose, parada en el momento [t] del reloj de la fundación.
///
/// La cámara es la que pone la app en ese momento: encima del claro y cerca,
/// porque lo que pasa pasa ahí.
Future<ui.Image> _frame(double t) async {
  final layout = TownLayout(0, TownCharacter.all.first);
  final cam = OrbitCamera()
    ..yaw = 0.62
    ..pitch = 0.30
    ..distance = 11
    ..focusY = 1.2
    ..wallLength = layout.radius * 2;
  final rec = ui.PictureRecorder();
  TownPainter(
    TownScene(
      placed: 0,
      palette: Palette.forMoment(11),
      camera: cam,
      time: 2.0,
      hourOfDay: 11,
      effects: EffectSystem(),
      labelledBricks: const {},
      budget: 40000,
      towns: [
        TownEntry(layout: layout, name: 'Pueblo', symbol: 'rueda', placed: 0),
      ],
      active: 0,
      labels: false,
      founding: t,
    ),
    TouchMap(),
  ).paint(Canvas(rec), const Size(_w * 1.0, _h * 1.0));
  return rec.endRecording().toImage(_w, _h);
}

Future<Uint8List> _bytes(ui.Image img) async => (await img.toByteData(
  format: ui.ImageByteFormat.rawRgba,
))!.buffer.asUint8List();

/// El primer renglón de prado: donde acaba el horizonte y empieza el valle.
///
/// Los montes del fondo son pardos y pasarían por madera, así que la medida de
/// más abajo empieza donde ellos acaban. Sale de la imagen y no de un número
/// escrito a mano, que sería un número que caduca la próxima vez que alguien
/// toque la cámara.
int _horizonte(Uint8List px) {
  for (var y = 0; y < _h; y++) {
    var verde = 0;
    for (var x = 0; x < _w; x++) {
      final i = (y * _w + x) * 4;
      if (px[i + 1] > px[i] && px[i + 1] > px[i + 2]) verde++;
    }
    if (verde > _w * 0.8) return y;
  }
  return 0;
}

/// El renglón más alto en el que hay madera, del horizonte para abajo, o -1 si
/// no hay ninguna.
///
/// El tablón y el atril son lo único de madera oscura que tiene una plaza: el
/// enlosado es piedra clara, la fuente es piedra y el prado es verde. Así que
/// «dónde está la madera» es «dónde están esos dos» sin tener que proyectar
/// nada a mano.
int _maderaMasAlta(Uint8List px) {
  for (var y = _horizonte(px); y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final i = (y * _w + x) * 4;
      final r = px[i], g = px[i + 1], b = px[i + 2];
      if (r < 150 && r > g && g > b && r - b > 18) return y;
    }
  }
  return -1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el tablón y el atril caen del cielo, no salen de la tierra', () async {
    // El fallo que esto cierra: los tres subían del suelo. En una app donde
    // cada logro es una piedra que cae, las dos cosas de la plaza salían de
    // debajo de la tierra como si las empujara un topo.
    //
    // **Cómo se mide.** Dónde está lo más alto que hay de madera. Quieto, es
    // el tejadillo del tablón. En vuelo tiene que estar **más arriba** que
    // eso, porque viene cayendo; saliendo de la tierra estaría más abajo, que
    // es exactamente lo que se cambió.
    final quieta = await _frame(1.0);
    final yFinal = _maderaMasAlta(await _bytes(quieta));
    quieta.dispose();
    expect(yFinal, greaterThan(0), reason: 'no se ve madera con todo puesto');

    // A mitad de caída del tablón.
    final medio =
        FoundingShow.boardAt +
        (FoundingShow.boardLands - FoundingShow.boardAt) * 0.5;
    final volando = await _frame(medio);
    final yVuelo = _maderaMasAlta(await _bytes(volando));
    volando.dispose();
    expect(
      yVuelo,
      greaterThan(0),
      reason: 'a media caída no se ve el tablón por ningún lado',
    );
    expect(
      yVuelo,
      lessThan(yFinal - 20),
      reason:
          'a media caída la madera está en el renglón $yVuelo y parada en el '
          '$yFinal: no viene de arriba',
    );
  });

  test('y la plaza no cambia de color al acabar de fundarse', () async {
    // La plaza se pinta dos veces en la vida de la app: mientras se funda la
    // dibuja el pintor de la fundación, y a partir del fotograma siguiente la
    // dibuja el camino de siempre. Si los dos no la pintan igual, hay un salto
    // de color en el último fotograma — y era así: acá los sólidos se arman a
    // mano, `Facet.piece` vale cero mientras nadie diga otra cosa, y cero es
    // una pieza de verdad, así que la plaza entera se pintaba con el color y
    // el desgaste del primer logro del pueblo.
    final antes = await _frame(0.999);
    final despues = await _frame(1.0);
    final a = await _bytes(antes), b = await _bytes(despues);
    antes.dispose();
    despues.dispose();
    var distintos = 0;
    for (var i = 0; i < a.length; i += 4) {
      for (var c = 0; c < 3; c++) {
        if ((a[i + c] - b[i + c]).abs() > 8) {
          distintos++;
          break;
        }
      }
    }
    expect(
      distintos,
      lessThan(200),
      reason:
          '$distintos píxeles cambian entre el último fotograma de la '
          'fundación y el primero del pueblo: la plaza da un salto de color',
    );
  });
}
