import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/character.dart';
import 'package:towny/data/doings.dart';
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
        symbol: 'book',
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

    test('los críos lo dicen, y no tienen oficio', () {
      final h = pueblo(400);
      final l = TownLayout(400, TownCharacter.byOrder(h.character));
      enrolFolk(h, l);
      final gente = {for (final v in folkOf(l, 400)) v.home: v};
      var criosVistos = 0;
      for (final b in l.buildings) {
        final c = folkCardOf(h, l, 0, b.index);
        final v = gente[b.index];
        if (c == null || v == null) continue;
        // La ficha y el que anda por el pueblo son la misma persona.
        expect(c.name, v.name, reason: 'casa ${b.index}');
        if (!v.kid) continue;
        criosVistos++;
        expect(c.trade, anyOf('Niño', 'Niña'), reason: c.name);
        for (final oficio in ['Tejedor', 'Herrer', 'Pastor', 'Moliner']) {
          expect(c.name, isNot(contains(oficio)), reason: c.name);
        }
      }
      expect(criosVistos, greaterThan(3));
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

    testWidgets('debajo de él: nombre, oficio, desde cuándo y con qué casa', (
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
            body: FolkPanel(theme: UiTheme(Palette.forMoment(13)), card: c),
          ),
        ),
      );
      expect(find.text('Ximena la Tejedora'), findsOneWidget);
      expect(find.text('Tejedora'), findsOneWidget);
      expect(find.textContaining('desde el'), findsOneWidget);
      expect(find.text('3.ª casa · taller'), findsOneWidget);
      // Sin caja ni fondo: es texto sobre el pueblo.
      expect(find.byType(Container), findsNothing);
      expect(find.byType(DecoratedBox), findsNothing);
      expect(find.byType(ColoredBox), findsNothing);
    });
  });

  group('a quien se sigue, se le ve hacer cosas', () {
    // Lo que se vio: con la cámara encima, la persona se quedaba de medio
    // minuto a un minuto en cada sitio haciendo una sola cosa.
    /// Tres minutos mirándola: cuántas veces cambia lo que hace por minuto
    /// —echar a andar, pararse, pasar a otra cosa—, cuánto dura el rato
    /// más largo sin que cambie nada, y cuántas cosas distintas hace.
    ({double cambios, double quieto, int cosas}) mirar(
      Townsfolk who,
      double desde,
    ) {
      var cambios = 0;
      var quieto = 0.0, racha = 0.0;
      final cosas = <String>{};
      String? antes;
      for (var t = desde; t < desde + 180; t += 0.25) {
        final a = who.at(t);
        final ahora = a.moving ? 'andar' : (a.act?.id ?? 'nada');
        if (ahora != 'andar' && ahora != Doing.idle.id) cosas.add(ahora);
        if (antes != null && ahora != antes && ahora != Doing.idle.id) {
          cambios++;
          racha = 0;
        } else if (ahora == 'andar') {
          // Andar es moverse: no cuenta como estar quieto.
          racha = 0;
        } else {
          racha += 0.25;
          if (racha > quieto) quieto = racha;
        }
        if (ahora != Doing.idle.id) antes = ahora;
      }
      return (cambios: cambios / 3, quieto: quieto, cosas: cosas.length);
    }

    test('cambia de cosa mucho más a menudo que en su ronda de siempre', () {
      final l = TownLayout(160, TownCharacter.all.first, seed: 21);
      // Al consejero no se le sigue: tocarlo abre su menú.
      final gente = folkOf(l, 160).where((v) => !v.sage).toList();
      var cAntes = 0.0, cAhora = 0.0, qAntes = 0.0, qAhora = 0.0;
      var cosasAntes = 0, cosasAhora = 0;
      for (final who in gente) {
        final normal = mirar(who, 0);
        who.spotlight(0, on: true);
        final seguida = mirar(who, 0);
        who.spotlight(180, on: false);
        cAntes += normal.cambios;
        cAhora += seguida.cambios;
        qAntes += normal.quieto;
        qAhora += seguida.quieto;
        cosasAntes += normal.cosas;
        cosasAhora += seguida.cosas;
        // Nunca más de dieciséis segundos haciendo lo mismo sin moverse: en
        // un sitio donde sólo cabe una cosa —un crío en la plaza sólo puede
        // tocar el laúd— se queda la mitad, y aunque la parada siguiente sea
        // en el mismo sitio, son dos mitades.
        expect(
          seguida.quieto,
          lessThanOrEqualTo(16),
          reason: 'casa ${who.home}',
        );
      }
      // Medido sobre este pueblo: de 1,6 a 4,4 cambios por minuto, el rato
      // más largo sin que cambie nada de 49 a 9 segundos de media, y de 2,4
      // a 5,6 cosas distintas en tres minutos.
      final n = gente.length;
      expect(cAhora / n, greaterThan(cAntes / n * 2));
      expect(qAhora / n, lessThan(qAntes / n / 3));
      expect(cosasAhora / n, greaterThan(cosasAntes / n * 1.5));
    });

    test('ni al empezar ni al terminar salta de sitio', () {
      final l = TownLayout(160, TownCharacter.all.first, seed: 21);
      for (final who in folkOf(l, 160)) {
        for (final t in [3.0, 47.0, 131.0, 260.0]) {
          final a = who.at(t);
          who.spotlight(t, on: true);
          final b = who.at(t);
          expect(
            (a.x - b.x).abs() + (a.z - b.z).abs(),
            lessThan(1e-6),
            reason: 'casa ${who.home} al empezar, a los $t s',
          );
          final t2 = t + 37;
          final c = who.at(t2);
          who.spotlight(t2, on: false);
          final d = who.at(t2);
          expect(
            (c.x - d.x).abs() + (c.z - d.z).abs(),
            lessThan(1e-6),
            reason: 'casa ${who.home} al terminar, a los $t2 s',
          );
        }
      }
    });
  });

  group('la cámara sigue a quien se toca', () {
    test('con la cámara encima, la persona se pinta siempre', () {
      // Lo que se encontró al probar el encuadre: el pintor se ahorraba a
      // quien tuviera **el medio de su ronda** detrás de la cámara. Desde
      // lejos no pasa nunca; con la cámara pegada a alguien pasa a menudo, y
      // la persona que se estaba siguiendo desaparecía.
      final l = TownLayout(160, TownCharacter.all.first, seed: 21);
      // El consejero no se toca todavía: no tiene ficha.
      final gente = folkOf(l, 160).where((v) => !v.sage);
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
              TownEntry(layout: l, name: 'Leer', symbol: 'book', placed: 160),
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
      expect(mando.distanceTarget, lessThan(5.5));

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

      // El botón de prueba: a quien se sigue se le puede pedir cualquier
      // actividad, y la hace él, en este pueblo.
      final barrer = Doing.all.firstWhere((d) => d.id == 'barrer');
      expect(mando.tryOut(barrer), isTrue);
      expect(vecino.trying, barrer);

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
