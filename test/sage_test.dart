import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/core/math3.dart';
import 'package:towny/data/character.dart';
import 'package:towny/data/doings.dart';
import 'package:towny/data/folknames.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/folk.dart';
import 'package:towny/engine/fountain_birds.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/pigeons.dart';
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

    test('de pie nunca está dentro del banco', () {
      // Se paraba en el sitio del asiento, y al llegar, al irse y al
      // levantarse después de caer con la fundación quedaba con medio cuerpo
      // atravesando el banco.
      final l = TownLayout(60, TownCharacter.all.first, seed: 7);
      final v = folkOf(l, 60).firstWhere((v) => v.sage);
      final bx = PlazaBench.xAt(l.cx), bz = PlazaBench.zAt(l.cz);
      final fx = math.sin(PlazaBench.turn), fz = math.cos(PlazaBench.turn);
      bool dentro(FolkAt a) {
        final dx = a.x - bx, dz = a.z - bz;
        final hondo = dx * fx + dz * fz; // hacia delante del banco
        final largo = dx * fz - dz * fx; // a lo largo del banco
        return largo.abs() < PlazaBench.half + 0.05 &&
            hondo.abs() < PlazaBench.depth + 0.08;
      }

      var sentado = 0;
      for (var t = 0.0; t < v.period * 2; t += 0.25) {
        final a = v.at(t);
        if (a.act == Doing.bench) {
          sentado++;
          continue;
        }
        expect(dentro(a), isFalse, reason: 'de pie en el banco a los $t s');
      }
      expect(sentado, greaterThan(0), reason: 'nunca se sentó');
      // Y al llegar con la fundación: sentado, se levanta, saluda.
      v.arriveNow(l, 1000);
      for (var s = 0.0; s < Townsfolk.greetLength + 2; s += 0.1) {
        final a = v.at(1000 + s);
        if (a.act == Doing.bench) continue;
        expect(dentro(a), isFalse, reason: 'al levantarse, a los $s s');
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
              TownEntry(layout: l, name: 'Leer', symbol: 'book', placed: 120),
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
        if (sabio) {
          visto++;
          // Y un dedo sobre él lo encuentra: lo que se toca pasa por
          // [TouchMap.hitAt], que sólo devuelve lo que se puede tocar.
          final p = cam.projector(393, 852, t);
          final talla = TownPainter.folkHeight(l.character);
          final s = p.project(V3(at.x, Plaza.lawnTop + talla * 0.45, at.z))!;
          final k = hits.hitAt(Offset(s.x, s.y));
          expect(k, greaterThanOrEqualTo(0), reason: 'el dedo no lo encuentra');
          expect(hits.faceOwner[k], TouchMap.sage);
        }
      }
      expect(visto, greaterThan(0), reason: 'nunca se lo pudo tocar');
    });
  });

  group('las palomas del consejero', () {
    // La primera vuelta en la que da de comer, y desde cuándo.
    (Townsfolk, TownLayout, double, double) primera() {
      final l = TownLayout(60, TownCharacter.all[0], seed: 7);
      final sabio = folkOf(l, 60).firstWhere((v) => v.sage);
      for (var k = 0; k < 40000; k++) {
        final c = sabio.benchClock(k * 1.0);
        if (c == null || c.since < 0 || c.since > 1) continue;
        if (sageFeast(sabio, l, k * 1.0, h: 0.5) != null) {
          return (sabio, l, k - c.since, c.sits);
        }
      }
      fail('nunca les da de comer');
    }

    test('sólo cada mucho, y sólo sentado en el banco', () {
      final (sabio, l, t0, sits) = primera();
      expect(sabio.at(t0 + 10).act, Doing.bench);
      var vueltas = 0, comidas = 0;
      for (var k = 0; k < 60; k++) {
        final t = t0 + k * sabio.period + 10;
        vueltas++;
        if (sageFeast(sabio, l, t, h: 0.5) != null) comidas++;
      }
      expect(comidas, greaterThan(0));
      expect(comidas, lessThan(vueltas * 0.6));
      expect(sageFeast(sabio, l, t0 - 20, h: 0.5), isNull);
      expect(sageFeast(sabio, l, t0 + 10, h: 0.5, day: false), isNull);
    });

    test(
      'bajan, se comen todas las migas y se van antes de que se levante',
      () {
        final (sabio, l, t0, sits) = primera();
        var vistas = 0;
        var hubo = false;
        for (var s = 0.05; s <= sits; s += 0.1) {
          final f = sageFeast(sabio, l, t0 + s, h: 0.5)!;
          if (f.crumbs.isNotEmpty) hubo = true;
          vistas = math.max(vistas, f.pigeons.length);
          for (final b in f.pigeons) {
            expect(
              b.at.x.isFinite && b.at.y.isFinite && b.at.z.isFinite,
              isTrue,
            );
          }
        }
        expect(hubo, isTrue);
        expect(vistas, inInclusiveRange(3, 5));
        final fin = sageFeast(sabio, l, t0 + sits, h: 0.5)!;
        expect(fin.crumbs, isEmpty, reason: 'no quedan migas');
        expect(fin.pose!.bread, 0, reason: 'ni pan');
        expect(
          fin.pigeons.where((b) => b.doing == BirdDoing.perched),
          isEmpty,
          reason: 'ya se fueron',
        );
      },
    );

    test('ninguna salta de sitio de un fotograma al siguiente', () {
      final (sabio, l, t0, sits) = primera();
      List<BirdVisit> en(double s) =>
          sageFeast(sabio, l, t0 + s, h: 0.5)!.pigeons;
      for (var s = 0.5; s < sits; s += 1 / 30) {
        final a = en(s), b = en(s + 1 / 30);
        if (a.length != b.length) continue;
        for (var i = 0; i < a.length; i++) {
          // En el aire van deprisa; lo que no puede saltar es una paloma
          // en el suelo, ni al posarse ni al despegar.
          if (a[i].doing != BirdDoing.perched &&
              b[i].doing != BirdDoing.perched) {
            continue;
          }
          expect(
            (a[i].at - b[i].at).length,
            lessThan(0.05),
            reason: 'paloma $i en el segundo $s',
          );
        }
      }
    });
  });
}
