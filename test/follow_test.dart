import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/character.dart';
import 'package:towny/data/folknames.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/folk.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/census.dart';
import 'package:towny/model/habit.dart';
import 'package:towny/model/piece.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/overlays.dart';
import 'package:towny/ui/style.dart';
import 'package:towny/ui/town_view.dart';

/// Tocar a un vecino: la cámara se le acerca y lo sigue, y al costado se
/// cuenta quién es.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('la ficha de un vecino', () {
    Habit pueblo(int piezas) {
      final h = Habit(
        id: 'h0',
        name: 'Leer',
        symbol: 'libro',
        slot: 0,
        createdAt: DateTime(2026, 1, 1),
      );
      for (var i = 0; i < piezas; i++) {
        h.pieces.add(
          Piece(
            index: i,
            placedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
          ),
        );
      }
      return h;
    }

    test('el oficio es el que dice su nombre, si lo dice', () {
      // «Ximena la Tejedora» teje: la ficha no puede decir que es pastora.
      final h = pueblo(400);
      final l = TownLayout(400, TownCharacter.byOrder(h.character));
      enrolFolk(h, l);
      var probados = 0;
      for (final b in l.buildings) {
        final c = folkCardOf(h, l, 0, b.index);
        if (c == null) continue;
        final seed = censusOf(h.folk)[b.index]?.seed;
        if (seed == null) continue;
        final k = folkNamedTrade(seed);
        if (k == null) continue;
        probados++;
        expect(c.name, contains(c.trade), reason: 'casa ${b.index}');
      }
      expect(probados, greaterThan(10));
    });

    test('en los hitos no vive nadie, y sólo las casas cuentan', () {
      final h = pueblo(400);
      final l = TownLayout(400, TownCharacter.byOrder(h.character));
      var casas = 0;
      for (final b in l.buildings) {
        final c = folkCardOf(h, l, 0, b.index);
        if (b.isLandmark) {
          expect(c, isNull, reason: '${b.name} es un hito');
          continue;
        }
        casas++;
        // La primera casa es la 1, la segunda la 2: los hitos de en medio
        // no cuentan.
        expect(c!.house, casas);
        expect(c.houseName, b.name);
      }
      expect(casas, greaterThan(20));
      expect(l.buildings.any((b) => b.isLandmark), isTrue);
    });

    test('la fecha es la del padrón: el día que se remató su casa', () {
      final h = pueblo(200);
      final l = TownLayout(200, TownCharacter.byOrder(h.character));
      enrolFolk(h, l);
      final v = censusOf(h.folk).values.first;
      final c = folkCardOf(h, l, 0, v.home)!;
      expect(c.born, v.born);
      expect(c.name, v.name);
    });

    testWidgets('al costado: nombre, oficio, desde cuándo y con qué casa', (
      tester,
    ) async {
      final c = FolkCard(
        town: 0,
        home: 7,
        name: 'Ximena la Tejedora',
        trade: 'Tejedora',
        born: DateTime(2026, 3, 1),
        house: 3,
        houseName: 'Taller',
        woman: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolkPanel(
              theme: UiTheme(Palette.forMoment(13)),
              card: c,
              now: DateTime(2026, 3, 11),
              onClose: () {},
            ),
          ),
        ),
      );
      expect(find.text('VECINA'), findsOneWidget);
      expect(find.text('Ximena la Tejedora'), findsOneWidget);
      expect(find.text('Tejedora'), findsOneWidget);
      expect(find.textContaining('hace 10 días'), findsOneWidget);
      expect(
        find.textContaining('3.ª casa del pueblo: taller'),
        findsOneWidget,
      );
    });
  });

  group('la cámara sigue a quien se toca', () {
    test('con la cámara encima, la persona se pinta siempre', () {
      // Lo que se encontró al probar el encuadre: el pintor se ahorraba a
      // quien tuviera **el medio de su ronda** detrás de la cámara. Desde
      // lejos no pasa nunca; con la cámara pegada a alguien pasa a menudo, y
      // la persona que se estaba siguiendo desaparecía.
      final l = TownLayout(160, TownCharacter.all.first, seed: 21);
      final gente = folkOf(l, 160);
      var probadas = 0;
      for (final who in gente) {
        for (final t in [0.0, 30.0, 80.0, 140.0]) {
          final at = folkWhere(who, t, 0)!.at;
          final cam = OrbitCamera()
            ..travel = at.x
            ..focusZ = at.z
            ..focusY = 0.3
            ..distance = 4.6
            ..pitch = 0.75
            ..yaw = 0.62 + t;
          final s = TownScene(
            placed: 160,
            palette: Palette.forMoment(11),
            camera: cam,
            time: t,
            hourOfDay: 11,
            effects: EffectSystem(),
            budget: 60000,
            towns: [
              TownEntry(layout: l, name: 'Leer', symbol: 'libro', placed: 160),
            ],
            active: 0,
            labels: false,
          );
          final hits = TouchMap();
          TownPainter(
            s,
            hits,
          ).paint(Canvas(ui.PictureRecorder()), const Size(393, 852));
          var esta = false;
          for (var k = 0; k < hits.faceCount && !esta; k++) {
            esta =
                hits.faceOwner[k] == TouchMap.folk &&
                TouchMap.folkOf(hits.regionData[k]).$2 == who.home;
          }
          probadas++;
          expect(esta, isTrue, reason: 'casa ${who.home} a los $t s');
        }
      }
      expect(probadas, greaterThan(40));
    });

    testWidgets('se acerca, lo sigue, y deja de seguirlo al moverse', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await Appearance.instance.load();
      await Appearance.instance.setSoundOff(true);
      await Appearance.instance.setMusicOff(true);
      // De día, que de noche están todos en casa.
      await Appearance.instance.setFakeHour(true);
      await Appearance.instance.setFakeHourAt(11);
      final store = Store();
      await store.load();
      for (var i = 0; i < 160; i++) {
        store.lay(
          store.habit,
          DateTime.now().subtract(Duration(days: 400 - i)),
        );
      }
      store.justFounded = false;

      final mando = TownViewController();
      FolkCard? ficha;
      var perdido = 0;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TownView(
              store: store,
              controller: mando,
              onTownLandmark: (_, _) {},
              onPlaced: (_) {},
              onStoneTapped: (_) {},
              onNothingTapped: () {},
              onCameraMoved: () {},
              onFlewOut: () {},
              onSkyTapped: (_) {},
              onTownTapped: (_) {},
              onBoardTapped: (_) {},
              onWhisper: (_, {duration = Duration.zero}) {},
              onPaletteChanged: (_) {},
              onFolkTapped: (c) => ficha = c,
              onFolkLost: () => perdido++,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(seconds: 3));

      // Un vecino a la vista.
      Offset? donde;
      for (var y = 120.0; y < 760 && donde == null; y += 3) {
        for (var x = 10.0; x < 380 && donde == null; x += 3) {
          if (mando.ownerAt(Offset(x, y)) == TouchMap.folk) {
            donde = Offset(x, y);
          }
        }
      }
      expect(donde, isNotNull, reason: 'no se ve a nadie por la calle');

      await tester.tapAt(donde!);
      await tester.pump(const Duration(milliseconds: 400));
      expect(ficha, isNotNull, reason: 'tocarlo no dijo quién es');
      expect(mando.following, isNotNull);
      expect(mando.distanceTarget, lessThan(5));

      // Lo sigue: en cada momento, la mira está donde está él.
      final quien = mando.following!;
      final e = store.habit;
      final vecino = folkOf(
        townOrder(e, valley: store.habits, placed: store.total).layout,
        store.total,
      ).firstWhere((v) => v.home == quien.$2);
      expect(vecino.home, ficha!.home);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final ahora = folkWhere(vecino, mando.clock, 0)!.at;
        final mira = mando.aim;
        expect(
          (mira.x - ahora.x).abs() + (mira.z - ahora.z).abs(),
          lessThan(0.01),
          reason: 'la cámara mira a otro sitio que donde está él',
        );
      }

      // Y arrastrar con dos dedos para irse es dejar de seguirlo.
      final a = await tester.createGesture(pointer: 1);
      final b = await tester.createGesture(pointer: 2);
      await a.down(const Offset(150, 400));
      await b.down(const Offset(250, 400));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await a.moveBy(const Offset(12, 0));
        await b.moveBy(const Offset(12, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(mando.following, isNull);
      expect(perdido, 1);

      await tester.pumpWidget(const SizedBox());
      await Appearance.instance.setFakeHour(false);
      await Appearance.instance.flush();
    });
  });
}
