import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/core/math3.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';

const Size _screen = Size(420, 860);

/// Pinta un pueblo y devuelve el mapa de lo que se ve, junto con la cámara
/// con la que se pintó.
(TouchMap, TownLayout, OrbitCamera) shot({
  required int placed,
  required double pitch,
  required double yaw,
  TownCharacter? place,
}) {
  final where = place ?? TownCharacter.all.first;
  final layout = TownLayout(placed, where);
  final cam = OrbitCamera()
    ..yaw = yaw
    ..yawTarget = yaw
    ..pitch = pitch
    ..pitchTarget = pitch
    ..distance = 26
    ..distanceTarget = 26;
  final scene = TownScene(
    placed: placed,
    palette: Palette.forMoment(11),
    camera: cam,
    time: 0,
    hourOfDay: 12,
    effects: EffectSystem(),
    budget: 22000,
    towns: [
      TownEntry(
        layout: layout,
        name: 'Prueba',
        symbol: 'torre',
        placed: placed,
      ),
    ],
    active: 0,
  );
  final hits = TouchMap();
  final rec = ui.PictureRecorder();
  TownPainter(scene, hits).paint(Canvas(rec), _screen);
  rec.endRecording().dispose();
  return (hits, layout, cam);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// De quién es lo que se toca en [o].
  int? tocado(TouchMap hits, Offset o) {
    final k = hits.hitAt(o);
    return k < 0 ? null : hits.faceOwner[k];
  }

  group('tocar una pieza', () {
    test('cada pieza que se ve se puede tocar', () {
      // Donde se ve una pieza, tocar es tocar ésa: no la de detrás, no la más
      // cercana al dedo, no la que tenga el rectángulo más chico.
      for (final pitch in [0.25, 0.7, 1.2]) {
        final (hits, _, _) = shot(placed: 60, pitch: pitch, yaw: 0.4);
        final vistas = <int>{};
        for (var y = 0.0; y < _screen.height; y += 3) {
          for (var x = 0.0; x < _screen.width; x += 3) {
            final dueno = hits.ownerAt(x, y);
            if (dueno == null || dueno < 0) continue;
            vistas.add(dueno);
            expect(
              tocado(hits, Offset(x, y)),
              dueno,
              reason: 'inclinación $pitch, en ($x, $y)',
            );
          }
        }
        expect(vistas.length, greaterThan(10), reason: 'inclinación $pitch');
      }
    });

    test('desde arriba gana la de encima, no la de debajo', () {
      // Mirando desde arriba, el techo de una pieza apilada tapa a la de
      // abajo: tocar ahí es tocar la de arriba.
      final (hits, layout, cam) = shot(placed: 60, pitch: 1.25, yaw: 0.3);
      final p = cam.projector(_screen.width, _screen.height, 0);
      var pares = 0;
      for (final abajo in layout.pieces) {
        for (final arriba in layout.pieces) {
          if (identical(abajo, arriba)) continue;
          if ((arriba.cx - abajo.cx).abs() > 0.15) continue;
          if ((arriba.cz - abajo.cz).abs() > 0.15) continue;
          if (arriba.y0 < abajo.y1 - 0.01) continue;
          final o = p.project(V3(arriba.cx, arriba.y1, arriba.cz));
          if (o == null) continue;
          final t = tocado(hits, Offset(o.x, o.y));
          if (t == null) continue;
          pares++;
          expect(
            t,
            isNot(abajo.index),
            reason: 'se tocó la ${abajo.index} a través de la ${arriba.index}',
          );
        }
      }
      expect(pares, greaterThan(3), reason: 'no había nada apilado que mirar');
    });

    test('un dedo un poco corrido acierta igual', () {
      // Una pieza lejana mide pocos píxeles y una yema no: a unos píxeles de
      // ella, sobre el prado, se toca igual.
      final (hits, _, _) = shot(placed: 40, pitch: 0.45, yaw: 0.2);
      var probadas = 0;
      for (var y = 0.0; y < _screen.height && probadas < 20; y += 5) {
        for (var x = 0.0; x < _screen.width && probadas < 20; x += 5) {
          final dueno = hits.ownerAt(x, y);
          if (dueno == null || dueno < 0) continue;
          // Un punto de prado a cinco píxeles.
          final al = Offset(x, y + 5);
          final debajo = hits.ownerAt(al.dx, al.dy);
          if (debajo != null && debajo != TouchMap.nobody) continue;
          probadas++;
          expect(tocado(hits, al), isNotNull, reason: 'en $al');
        }
      }
      expect(probadas, greaterThan(5));
    });
  });
}
