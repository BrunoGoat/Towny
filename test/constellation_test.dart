import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/character.dart';
import 'package:towny/data/constellations.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';
import 'package:towny/l10n/lang.dart';

const int _w = 393, _h = 852;

TownScene _noche(OrbitCamera cam, Constellation c, double rotulo) {
  final l = TownLayout(6, TownCharacter.all.first, seed: 21);
  return TownScene(
    placed: 6,
    palette: Palette.forMoment(23),
    camera: cam,
    time: 1,
    hourOfDay: 23,
    effects: EffectSystem(),
    budget: 60000,
    towns: [TownEntry(layout: l, name: 'Leer', symbol: 'libro', placed: 6)],
    active: 0,
    labels: false,
    folk: false,
    ghost: false,
    skyNight: 3,
    tonight: c,
    skyLabel: rotulo,
  );
}

Future<(List<int>, TouchMap)> _pintar(TownScene s) async {
  final hits = TouchMap();
  final rec = ui.PictureRecorder();
  TownPainter(s, hits).paint(Canvas(rec), Size(_w * 1.0, _h * 1.0));
  final img = await rec.endRecording().toImage(_w, _h);
  final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  return (raw!.buffer.asUint8List(), hits);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cada constelación tiene nombre, en los dos idiomas', () {
    for (final c in constellations) {
      final n = constellationNames[c.id];
      expect(n, isNotNull, reason: c.id);
      expect(n!.$1, isNotEmpty);
      expect(n.$2, isNotEmpty);
    }
    lang = Lang.en;
    expect(
      constellations.firstWhere((c) => c.id == 'osamayor').name,
      'Great Bear',
    );
    lang = Lang.es;
    expect(
      constellations.firstWhere((c) => c.id == 'osamayor').name,
      'Osa Mayor',
    );
  });

  test('al tocarla sale su nombre encima, y sólo ahí', () async {
    final c = constellations.firstWhere((c) => c.id == 'casiopea');
    // Se busca hacia dónde mirar para tenerla entera en pantalla.
    for (var yaw = 0.0; yaw < 6.3; yaw += 0.25) {
      final cam = OrbitCamera()
        ..yaw = yaw
        ..pitch = -0.6
        ..distance = 12
        ..focusY = 1.15;
      final (sin, hits) = await _pintar(_noche(cam, c, 0));
      if (hits.skies.isEmpty) continue;
      final (con, _) = await _pintar(_noche(cam, c, 1));
      final box = hits.skies.first.rect;
      var encima = 0, fuera = 0;
      for (var y = 0; y < _h; y++) {
        for (var x = 0; x < _w; x++) {
          final i = (y * _w + x) * 4;
          final d =
              (con[i] - sin[i]).abs() +
              (con[i + 1] - sin[i + 1]).abs() +
              (con[i + 2] - sin[i + 2]).abs();
          if (d < 40) continue;
          if (y < box.top + 16 && y > box.top - 60) {
            encima++;
          } else {
            fuera++;
          }
        }
      }
      expect(
        encima,
        greaterThan(30),
        reason: 'no se ve el nombre ($fuera fuera, caja $box)',
      );
      expect(fuera, 0, reason: 'el nombre salió lejos de la figura');
      return;
    }
    fail('no se encontró la constelación en ninguna dirección');
  });

  test(
    'el nombre va clavado a la figura, aunque se salga por un borde',
    () async {
      // Antes se sujetaba dentro de la pantalla: con la figura saliéndose por
      // la izquierda, el nombre se quedaba pegado al borde y acompañaba a la
      // cámara. Ahora va donde va la figura.
      final c = constellations.firstWhere((c) => c.id == 'casiopea');
      var probadas = 0;
      for (var yaw = 0.0; yaw < 6.3; yaw += 0.02) {
        final cam = OrbitCamera()
          ..yaw = yaw
          ..pitch = -0.6
          ..distance = 12
          ..focusY = 1.15;
        final (sin, hits) = await _pintar(_noche(cam, c, 0));
        if (hits.skies.isEmpty) continue;
        final box = hits.skies.first.rect.deflate(16);
        // Que la figura esté entrando por el borde izquierdo, con el centro
        // casi en el borde: donde el nombre sujeto se despegaba de ella.
        if (box.center.dx < 10 || box.center.dx > 40) continue;
        final (con, _) = await _pintar(_noche(cam, c, 1));
        var n = 0;
        for (var y = 0; y < _h; y++) {
          for (var x = 0; x < _w; x++) {
            final i = (y * _w + x) * 4;
            final d =
                (con[i] - sin[i]).abs() +
                (con[i + 1] - sin[i + 1]).abs() +
                (con[i + 2] - sin[i + 2]).abs();
            if (d < 40) continue;
            n++;
          }
        }
        // Lo que se ve del nombre es su mitad derecha: empieza en el borde y
        // termina pasado el centro de la figura, nunca mucho más allá.
        if (n == 0) continue;
        final derecha = [
          for (var y = 0; y < _h; y++)
            for (var x = _w - 1; x >= 0; x--)
              if (((con[(y * _w + x) * 4] - sin[(y * _w + x) * 4]).abs()) > 40)
                x,
        ].fold<int>(0, (m, x) => x > m ? x : m);
        expect(
          derecha,
          lessThan(box.center.dx + 60),
          reason: 'el nombre se despegó de la figura (centro ${box.center.dx})',
        );
        probadas++;
        if (probadas >= 3) return;
      }
      expect(probadas, greaterThan(0), reason: 'no se encontró el borde');
    },
  );

  test('detrás de una casa o de una montaña no se puede tocar', () async {
    // La figura se pinta detrás de todo. Lo que se toca es lo que se ve: en
    // el rectángulo de la figura, donde hay un tejado o una cumbre delante se
    // toca eso, y sólo donde se ve cielo se toca la constelación.
    final c = constellations.firstWhere((c) => c.id == 'osamayor');
    final l = TownLayout(120, TownCharacter.all.first, seed: 21);
    var tapada = false, libre = false;
    for (var yaw = 0.0; yaw < 6.3 && !(tapada && libre); yaw += 0.1) {
      final cam = OrbitCamera()
        ..yaw = yaw
        ..pitch = -0.05
        ..distance = 14
        ..focusY = 1.15;
      final s = TownScene(
        placed: 120,
        palette: Palette.forMoment(23),
        camera: cam,
        time: 1,
        hourOfDay: 23,
        effects: EffectSystem(),
        budget: 60000,
        towns: [
          TownEntry(layout: l, name: 'Leer', symbol: 'libro', placed: 120),
        ],
        active: 0,
        labels: false,
        folk: false,
        ghost: false,
        skyNight: 3,
        tonight: c,
      );
      final (_, hits) = await _pintar(s);
      if (hits.skies.isEmpty) continue;
      final box = hits.skies.first.rect.intersect(
        Rect.fromLTWH(0, 0, _w * 1.0, _h * 1.0),
      );
      for (var y = box.top; y < box.bottom; y += 4) {
        for (var x = box.left; x < box.right; x += 4) {
          final k = hits.topAt(x, y);
          final cielo = k >= 0 && hits.faceOwner[k] == TouchMap.sky;
          final t = hits.hitAt(Offset(x, y));
          final toca = t >= 0 && hits.faceOwner[t] == TouchMap.sky;
          if (cielo) {
            libre = true;
            expect(toca, isTrue, reason: 'cielo libre en ($x, $y)');
          } else if (toca) {
            // Sólo vale con el dedo corrido hasta un cielo que se ve.
            expect(
              [
                for (var d = 3.0; d <= 8; d += 2.5)
                  for (var i = 0; i < 12; i++) (d, i),
              ].any((e) {
                final o = hits.topAt(
                  x + math.cos(e.$2 * math.pi / 6) * e.$1,
                  y + math.sin(e.$2 * math.pi / 6) * e.$1,
                );
                return o >= 0 && hits.faceOwner[o] == TouchMap.sky;
              }),
              isTrue,
              reason: 'se tocó la constelación a través de algo en ($x, $y)',
            );
          } else {
            tapada = true;
          }
        }
      }
    }
    expect(tapada, isTrue, reason: 'no se encontró una figura tapada');
    expect(libre, isTrue, reason: 'no se encontró cielo libre en la figura');
  });
}
