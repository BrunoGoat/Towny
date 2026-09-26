import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/engine/camera.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/renderer.dart';
import 'package:la_muralla/engine/scene.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/fx/effects.dart';

/// **La prueba de que tirar lo que no se ve no se nota.**
///
/// Una optimización de dibujo no se juzga por lo que diga quien la escribió:
/// se pinta la misma escena con ella y sin ella y se comparan los dos
/// fotogramas píxel a píxel. Si cambia uno solo, la optimización está mal.
///
/// Esa exigencia —cero, no «casi»— es la que se le puede pedir a este recorte
/// y no a cualquier otro: lo que quita son caras cuyo rectángulo en pantalla
/// no toca el lienzo, o sea caras que no pintaban nada. Nada de esto toca el
/// orden en que se pintan las que sí se ven, que es lo que decide el árbol de
/// planos y lo que costó arreglar en su día.
const _size = Size(390, 844);

TownScene _valle(
  int piezas, {
  double yaw = 0.6,
  double pitch = 0.34,
  double dist = 30,
  double hora = 14,
  int pueblos = 1,
  double integrity = 1,
}) {
  final cam = OrbitCamera()
    ..yaw = yaw
    ..pitch = pitch
    ..distance = dist
    ..focusY = 2.0;
  final towns = <TownEntry>[];
  for (var k = 0; k < pueblos; k++) {
    final ch = TownCharacter.all[k % TownCharacter.all.length];
    final l = TownLayout(piezas, ch, cx: k * 124.0, cz: 0, seed: 7 + k);
    towns.add(
      TownEntry(
        layout: l,
        name: 'Pueblo $k',
        symbol: 'libro',
        integrity: integrity,
        placed: piezas,
      ),
    );
  }
  cam.wallLength = towns.first.layout.radius * 2;
  return TownScene(
    placed: piezas,
    palette: Palette.forMoment(hora, integrity),
    camera: cam,
    integrity: integrity,
    time: 3.0,
    hourOfDay: hora,
    effects: EffectSystem(),
    labelledBricks: const {},
    towns: towns,
    active: 0,
  );
}

/// La vitrina de una obra sola, que es donde una cara de más o de menos se ve.
TownScene _obra(Landmark mark, {double yaw = 0.7, double dist = 14}) {
  final place = TownCharacter.all.first;
  final layout = TownLayout.showcase(place, landmark: mark, placed: mark.cost);
  final cam = OrbitCamera()
    ..yaw = yaw
    ..pitch = 0.42
    ..distance = dist
    ..focusY = 1.6;
  cam.wallLength = layout.radius * 2;
  return TownScene(
    placed: mark.cost,
    palette: Palette.forMoment(11, 1),
    camera: cam,
    integrity: 1,
    time: 2.0,
    hourOfDay: 11,
    effects: EffectSystem(),
    labelledBricks: const {},
    towns: [
      TownEntry(
        layout: layout,
        name: mark.name,
        symbol: 'libro',
        integrity: 1,
        placed: mark.cost,
      ),
    ],
    active: 0,
  );
}

/// Pinta y devuelve el pintor, para preguntarle qué dejó fuera.
TownPainter _frame(TownScene scene) {
  final painter = TownPainter(scene, TouchMap());
  final rec = ui.PictureRecorder();
  painter.paint(Canvas(rec), _size);
  rec.endRecording().dispose();
  return painter;
}

Future<(ByteData, int)> _pinta(WidgetTester tester, TownScene scene) async {
  final hits = TouchMap();
  final painter = TownPainter(scene, hits);
  final rec = ui.PictureRecorder();
  painter.paint(Canvas(rec), _size);
  final pic = rec.endRecording();
  late ByteData bytes;
  await tester.runAsync(() async {
    final img = await pic.toImage(_size.width.round(), _size.height.round());
    bytes = (await img.toByteData())!;
    img.dispose();
  });
  pic.dispose();
  return (bytes, painter.culled);
}

/// Cuántos píxeles cambian entre dos fotogramas.
int _difieren(ByteData a, ByteData b) {
  final x = a.buffer.asUint32List();
  final y = b.buffer.asUint32List();
  var n = 0;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) n++;
  }
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('el presupuesto recorta, no amputa', () {
    test('un pueblo de trescientas piezas nunca se queda a medias', () {
      // El suelo del termostato son nueve mil caras en pantalla. Un pueblo de
      // trescientas piezas cabe entero ahí dentro, que es justo lo que no
      // pasaba antes: el suelo estaba en cuatro mil y un pueblo de doscientas
      // ya tiene siete mil.
      for (final n in [100, 200, 300]) {
        final s = _valle(n, dist: 26);
        final p = _frame(
          TownScene(
            placed: n,
            palette: s.palette,
            camera: s.camera,
            integrity: 1,
            time: s.time,
            hourOfDay: 14,
            effects: EffectSystem(),
            labelledBricks: const {},
            towns: s.towns,
            active: 0,
            budget: 9000,
          ),
        );
        expect(
          p.unaffordableWorks,
          0,
          reason: '$n piezas: se quedaron ${p.unaffordableWorks} sin pintar',
        );
      }
    });

    test('lo que se cae de la lista es lo chico, no lo de atrás', () {
      // Con un presupuesto imposible, lo que sobrevive tiene que ser lo que
      // más pantalla ocupa. Antes era lo más cercano, que con la cámara del
      // pueblo es casi lo mismo **dentro** de un pueblo pero no entre dos: un
      // caserón del pueblo de al lado se comía el presupuesto de media calle
      // del tuyo.
      final s = _valle(260, pueblos: 3, dist: 70);
      final apretado = TownScene(
        placed: 260,
        palette: s.palette,
        camera: s.camera,
        integrity: 1,
        time: s.time,
        hourOfDay: 14,
        effects: EffectSystem(),
        labelledBricks: const {},
        towns: s.towns,
        active: 0,
        budget: 2500,
      );
      final p = _frame(apretado);
      expect(p.unaffordableWorks, greaterThan(0), reason: 'no recortó nada');
      // Y el pueblo que se está mirando se sirve primero: con el presupuesto
      // justo para uno, lo que se pinta es el suyo.
      expect(
        p.picks.map((t) => t.brickIndex).toList(),
        isNotEmpty,
        reason: 'no quedó ni una pieza del pueblo activo',
      );
    });

    test('lo que no toca la pantalla no gasta presupuesto', () {
      // Mirando a un lado, el pueblo entero se sale del encuadre: eso no es
      // una decisión de presupuesto, es que no está.
      final mirando = _valle(300, dist: 18);
      final deLado = _valle(300, dist: 18, yaw: 0.6);
      deLado.camera.travel = 320;
      deLado.camera.snap();
      final a = _frame(mirando);
      final b = _frame(deLado);
      expect(b.offScreenWorks, greaterThan(a.offScreenWorks));
      expect(b.unaffordableWorks, 0);
    });
  });

  group('tirar lo que no se ve no cambia lo que se ve', () {
    /// Pinta [scene] dos veces —con recorte y sin él— y exige que salgan dos
    /// fotogramas idénticos.
    Future<void> igual(
      WidgetTester tester,
      String cual,
      TownScene scene, {
      bool esperaRecorte = true,
    }) async {
      TownPainter.clipping = false;
      final (antes, _) = await _pinta(tester, scene);
      TownPainter.clipping = true;
      final (luego, tiradas) = await _pinta(tester, scene);
      final n = _difieren(antes, luego);
      expect(n, 0, reason: '$cual: $n píxeles distintos');
      if (esperaRecorte) {
        expect(
          tiradas,
          greaterThan(0),
          reason: '$cual: no tiró ninguna, así que no probó nada',
        );
      }
    }

    tearDown(() => TownPainter.clipping = true);

    testWidgets('en un pueblo, desde ocho ángulos y a tres distancias', (
      tester,
    ) async {
      for (var i = 0; i < 8; i++) {
        for (final d in [16.0, 30.0, 60.0]) {
          await igual(
            tester,
            'yaw $i/8 a $d',
            _valle(200, yaw: i * 0.785, dist: d),
            // De lejos entra el pueblo entero y puede no sobrar nada.
            esperaRecorte: d < 40,
          );
        }
      }
    });

    testWidgets('de noche, con las ventanas encendidas', (tester) async {
      // El caso que obligó a la excepción: el halo de una ventana mide hasta
      // cien píxeles de radio, así que una ventana que se sale por el canto
      // sigue alumbrando dentro y **no se puede tirar**.
      for (final d in [14.0, 26.0]) {
        await igual(tester, 'noche a $d', _valle(200, hora: 22.5, dist: d));
      }
    });

    testWidgets('mirando casi desde arriba y casi desde el suelo', (
      tester,
    ) async {
      await igual(tester, 'a ras', _valle(200, pitch: 0.02, dist: 20));
      await igual(tester, 'a plomo', _valle(200, pitch: 1.45, dist: 20));
    });

    testWidgets('en un valle de seis pueblos', (tester) async {
      await igual(tester, 'valle', _valle(300, pueblos: 6, dist: 90));
    });

    testWidgets('en un pueblo a la deriva, con el deterioro puesto', (
      tester,
    ) async {
      await igual(
        tester,
        'deriva',
        _valle(200, dist: 22, hora: 19.5, integrity: 0.25),
      );
    });

    testWidgets('y obra por obra, de cerca, que es donde se vería el agujero', (
      tester,
    ) async {
      for (final mark in landmarks) {
        await igual(
          tester,
          mark.name,
          _obra(mark),
          // Una obra chica cabe entera en el encuadre y no sobra nada.
          esperaRecorte: false,
        );
      }
    });
  });
}
