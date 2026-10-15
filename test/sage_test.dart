import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/character.dart';
import 'package:towny/data/folknames.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/folk.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/solids.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';

void main() {
  group('el consejero', () {
    test('hay uno solo, y está desde la primera pieza', () {
      for (final n in [1, 40, 300]) {
        final l = TownLayout(n, TownCharacter.all[0], seed: 3);
        final sabios = folkOf(l, n).where((v) => v.sage).toList();
        expect(sabios, hasLength(1), reason: 'con $n piezas');
        expect(sabios.single.home, Townsfolk.sageHome);
        expect(sabios.single.kid, isFalse);
        expect(folkIsWoman(sabios.single.seed), isFalse);
      }
    });

    test('uno por valle: sólo en el primer pueblo, el del medio', () {
      final otro = TownLayout(120, TownCharacter.all[0], cx: 124, seed: 3);
      expect(folkOf(otro, 120).where((v) => v.sage), isEmpty);
    });

    test('anda por la plaza, fuera de la fuente y lejos del tablón', () {
      final l = TownLayout(120, TownCharacter.all[2], seed: 9);
      final v = folkOf(l, 120).firstWhere((v) => v.sage);
      final pilon = Plaza.basinOf(TownLayout.plazaReach);
      final borde = TownLayout.plazaReach * Plaza.lawnOut;
      final tablon = (l.cx + NoticeBoard.offX, l.cz + NoticeBoard.offZ);
      for (var t = 0.0; t < v.period * 2; t += 0.25) {
        final at = v.at(t);
        final r = math.sqrt(
          math.pow(at.x - l.cx, 2) + math.pow(at.z - l.cz, 2),
        );
        expect(r, greaterThan(pilon + 0.15), reason: 'en la fuente a los $t s');
        expect(
          r,
          lessThan(borde - 0.4),
          reason: 'fuera de la plaza a los $t s',
        );
        final aTablon = math.sqrt(
          math.pow(at.x - tablon.$1, 2) + math.pow(at.z - tablon.$2, 2),
        );
        expect(aTablon, greaterThan(0.7), reason: 'en el tablón a los $t s');
      }
    });

    test('de noche no se va: no tiene casa', () {
      final l = TownLayout(120, TownCharacter.all[0], seed: 4);
      final gente = folkOf(l, 120);
      final v = gente.firstWhere((v) => v.sage);
      expect(folkWhere(v, 100, 1.0), isNotNull);
    });

    test('tocarlo en la plaza es tocar al consejero, no a un vecino', () {
      final l = TownLayout(120, TownCharacter.all.first, seed: 21);
      final v = folkOf(l, 120).firstWhere((v) => v.sage);
      var visto = 0;
      for (final t in [20.0, 60.0, 110.0]) {
        final at = folkWhere(v, t, 0)!.at;
        final cam = OrbitCamera()
          ..travel = at.x
          ..focusZ = at.z
          ..focusY = 0.3
          ..distance = 3.5
          ..pitch = 0.6
          ..yaw = 0.62 + t;
        final hits = TouchMap();
        TownPainter(
          TownScene(
            placed: 120,
            palette: Palette.forMoment(11),
            camera: cam,
            time: t,
            hourOfDay: 11,
            effects: EffectSystem(),
            budget: 60000,
            towns: [
              TownEntry(layout: l, name: 'Leer', symbol: 'libro', placed: 120),
            ],
            active: 0,
            labels: false,
          ),
          hits,
        ).paint(Canvas(ui.PictureRecorder()), const Size(393, 852));
        var sabio = false, comoVecino = false;
        for (var k = 0; k < hits.faceCount; k++) {
          if (hits.faceOwner[k] == TouchMap.sage) sabio = true;
          if (hits.faceOwner[k] == TouchMap.folk &&
              hits.regionData[k] == TouchMap.sageTag) {
            comoVecino = true;
          }
        }
        expect(comoVecino, isFalse);
        if (sabio) visto++;
      }
      expect(visto, greaterThan(0), reason: 'nunca se lo pudo tocar');
    });
  });
}
