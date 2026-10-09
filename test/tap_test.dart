import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/town_view.dart';

/// Tocar el tablón desde el pueblo, que es lo único que importa de todo esto:
/// lo demás —cuánto miden los blancos— son medios.
///
/// Lo que pasaba, y se vio usando la app: en un pueblo crecido no se podía
/// abrir. El blanco salía de **una sola cara** —la plancha—, que mira a la
/// fuente, y la cámara se planta en otro ángulo, así que de lo que se veía era
/// el canto. Con el pueblo chico colaba; según crece, la cámara se aleja con el
/// radio, el canto baja de doce píxeles y el blanco **se descartaba entero**.
/// Medido: a partir de las seiscientas piezas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Un pueblo de [piezas] piezas, montado como lo monta la app.
  Future<
    ({
      TownViewController mando,
      List<String> abierto,
      Future<void> Function(Offset) tocar,
    })
  >
  pueblo(WidgetTester tester, int piezas) async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.setSoundOff(true);
    await Appearance.instance.setMusicOff(true);
    final store = Store();
    await store.load();
    for (var i = 0; i < piezas; i++) {
      store.lay(store.habit, DateTime.now().subtract(Duration(days: 400 - i)));
    }
    store.justFounded = false;

    final abierto = <String>[];
    final mando = TownViewController();
    const size = Size(390, 844);
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
            onStoneTapped: (_) => abierto.add('piedra'),
            onNothingTapped: () => abierto.add('nada'),
            onCameraMoved: () {},
            onFlewOut: () {},
            onSkyTapped: (_) => abierto.add('cielo'),
            onTownTapped: (_) => abierto.add('pueblo'),
            onBoardTapped: (_) => abierto.add('tablón'),
            onWhisper: (_, {duration = Duration.zero}) {},
            onPaletteChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump(const Duration(seconds: 3));
    expect(size, const Size(390, 844));

    // Un dedo de verdad: aprieta, se mueve un pelo, suelta. Y se le deja
    // expirar el reloj del doble toque, que es lo que hace esperar al simple.
    Future<void> tocar(Offset donde) async {
      final g = await tester.startGesture(donde);
      await tester.pump(const Duration(milliseconds: 90));
      await g.moveBy(const Offset(2, 1));
      await g.up();
      await tester.pump(const Duration(milliseconds: 350));
    }

    return (mando: mando, abierto: abierto, tocar: tocar);
  }

  /// Un punto del rectángulo en el que lo que se ve es el tablón.
  Offset visible(TownViewController mando, Rect r) {
    for (var y = r.center.dy; y < r.bottom; y += 2) {
      for (final dy in [y, r.center.dy * 2 - y]) {
        for (var x = r.left + 1; x < r.right - 1; x += 2) {
          if ([
            Offset.zero,
            const Offset(3, 3),
            const Offset(-3, -3),
            const Offset(3, -3),
            const Offset(-3, 3),
          ].every((d) => mando.ownerAt(Offset(x, dy) + d) == TouchMap.board)) {
            return Offset(x, dy);
          }
        }
      }
    }
    // Un tablón lejano mide pocos píxeles: entonces cualquier punto suyo en el
    // que caiga también el dedo después de correrse al soltar.
    for (var y = r.top; y < r.bottom; y += 1) {
      for (var x = r.left; x < r.right; x += 1) {
        final o = Offset(x, y);
        if (mando.ownerAt(o) == TouchMap.board &&
            mando.ownerAt(o + const Offset(2, 1)) == TouchMap.board) {
          return o;
        }
      }
    }
    fail('no se ve nada del tablón');
  }

  group('el tablón se abre tocándolo', () {
    // Seiscientas es la cuenta en la que se rompía, y mil es un pueblo de los
    // que existen de verdad después de un año.
    for (final piezas in [10, 80, 300, 600, 1000]) {
      testWidgets('con $piezas piezas', (tester) async {
        final p = await pueblo(tester, piezas);
        expect(
          p.mando.boardTargets,
          isNotEmpty,
          reason: 'con $piezas piezas el tablón no tiene dónde tocarse',
        );

        // Donde se ve el tablón, que no es siempre el centro de su
        // rectángulo: con el pueblo crecido puede tener una casa delante.
        await p.tocar(visible(p.mando, p.mando.boardTargets.first));
        expect(p.abierto, ['tablón'], reason: 'con $piezas piezas');

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });

  group('el tablón no se toca a través de una casa', () {
    // Lo que se vio en un teléfono: con dos piezas, la casa entera delante del
    // tablón, tocar la pared abría el tablón de atrás. El blanco del tablón es
    // su rectángulo, y el rectángulo sigue ahí aunque algo se le ponga delante.
    for (final piezas in [2, 3, 10, 80]) {
      testWidgets('con $piezas piezas', (tester) async {
        final p = await pueblo(tester, piezas);
        for (var giro = 0; giro < 16; giro++) {
          if (p.mando.boardTargets.isEmpty) break;
          final r = p.mando.boardTargets.first;
          // Un punto del rectángulo del tablón en el que lo que se ve es una
          // casa.
          Offset? tapado;
          for (var y = r.top + 2; y < r.bottom - 2; y += 3) {
            for (var x = r.left + 2; x < r.right - 2; x += 3) {
              // Con margen alrededor: el dedo se corre un poco al soltar.
              final o = p.mando.ownerAt(Offset(x, y));
              if (o == null) continue;
              var firme = true;
              for (final d in const [
                Offset(-4, -4),
                Offset(4, -4),
                Offset(-4, 4),
                Offset(4, 4),
              ]) {
                if (p.mando.ownerAt(Offset(x, y) + d) != o) firme = false;
              }
              if (!firme) continue;
              if (o >= 0) tapado ??= Offset(x, y);
            }
          }
          // Que se abra tocando donde se ve ya lo exige el grupo de arriba;
          // aquí, que no se abra tocando la casa de delante.
          if (tapado != null) {
            await p.tocar(tapado);
            expect(
              p.abierto.last,
              'piedra',
              reason: 'con $piezas piezas, tocar la casa abrió el tablón',
            );
          }
          if (tapado != null) {
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 1));
            return;
          }
          // Esta vez no había nada delante: se gira y se vuelve a mirar.
          final g = await tester.startGesture(const Offset(100, 500));
          await g.moveBy(const Offset(120, 0));
          await g.up();
          // Hasta que la cámara se quede quieta: un blanco apuntado a mitad
          // de un giro ya no está donde se toca.
          for (var i = 0; i < 40; i++) {
            final antes = p.mando.boardTargets.firstOrNull;
            await tester.pump(const Duration(milliseconds: 250));
            if (antes == p.mando.boardTargets.firstOrNull) break;
          }
        }
        if (piezas == 10) fail('con $piezas piezas no hubo casa delante');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });

  test('lo que se ve bajo el dedo es la casa, no el tablón que tapa', () {
    // La escena de la captura: dos piezas, la casa entera entre la cámara y
    // el tablón. Se da la vuelta al pueblo hasta encontrar ese encuadre y ahí
    // se exige que, en la parte del rectángulo del tablón que tapa la casa,
    // lo que se ve sea la casa; y en la que no, el tablón.
    final l = TownLayout(2, TownCharacter.all.first, seed: 21);
    const size = Size(390, 844);
    var tapa = 0, deja = 0;
    for (var yaw = 0.0; yaw < 6.3; yaw += 0.1) {
      final cam = OrbitCamera()
        ..yaw = yaw
        ..pitch = 0.25
        ..focusY = 1.0
        ..distance = 11
        ..travel = l.cx
        ..focusZ = l.cz
        ..wallLength = l.radius * 2;
      final hits = TouchMap();
      TownPainter(
        TownScene(
          placed: 2,
          palette: Palette.forMoment(21),
          camera: cam,
          time: 7.3,
          hourOfDay: 21,
          effects: EffectSystem(),
          towns: [TownEntry(layout: l, name: 'L', symbol: 'libro', placed: 2)],
          active: 0,
          labels: false,
          folk: false,
        ),
        hits,
      ).paint(Canvas(ui.PictureRecorder()), size);
      if (hits.boards.isEmpty) continue;
      final r = hits.boards.first.rect;
      var casa = 0, tablon = 0;
      for (var y = r.top; y < r.bottom; y += 2) {
        for (var x = r.left; x < r.right; x += 2) {
          final o = hits.ownerAt(x, y);
          if (o != null && o >= 0) casa++;
          if (o == TouchMap.board) tablon++;
        }
      }
      if (casa > 20 && tablon > 20) tapa++;
      if (casa == 0 && tablon > 20) deja++;
    }
    expect(tapa, greaterThan(0), reason: 'ningún encuadre con la casa delante');
    expect(deja, greaterThan(0), reason: 'ningún encuadre con el tablón libre');
  });
}
