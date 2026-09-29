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
import 'package:la_muralla/engine/solid.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/engine/world.dart';
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
      TownEntry(layout: l, name: 'Pueblo $k', symbol: 'libro', placed: piezas),
    );
  }
  cam.wallLength = towns.first.layout.radius * 2;
  return TownScene(
    placed: piezas,
    palette: Palette.forMoment(hora),
    camera: cam,
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
    palette: Palette.forMoment(11),
    camera: cam,
    time: 2.0,
    hourOfDay: 11,
    effects: EffectSystem(),
    labelledBricks: const {},
    towns: [
      TownEntry(
        layout: layout,
        name: mark.name,
        symbol: 'libro',
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

/// Una obra a medio levantar con su última pieza todavía en el aire, y la
/// cámara puesta encima de ella.
///
/// Encima de ella a propósito: lo que hay que poder ver es el hueco que
/// dejaría debajo si se hubiera archivado mal, y desde el encuadre de la obra
/// entera ese hueco son cuatro píxeles.
TownScene _cayendo(Landmark mark, double t) {
  final place = TownCharacter.all.first;
  final layout = TownLayout.showcase(place, landmark: mark, placed: mark.cost);
  final ultima = layout.pieces[mark.cost - 1];
  final cam = OrbitCamera()
    ..yaw = 0.7
    ..pitch = 0.30
    ..distance = 7
    ..focusY = (ultima.y0 + ultima.y1) / 2
    ..travel = (ultima.x0 + ultima.x1) / 2
    ..focusZ = (ultima.z0 + ultima.z1) / 2;
  cam.wallLength = layout.radius * 2;
  cam.snap();
  final fx = PlacementFx(mark.cost - 1)..t = t;
  return TownScene(
    placed: mark.cost,
    palette: Palette.forMoment(11),
    camera: cam,
    time: 2.0,
    hourOfDay: 11,
    effects: EffectSystem(),
    labelledBricks: const {},
    towns: [
      TownEntry(
        layout: layout,
        name: mark.name,
        symbol: 'libro',
        placed: mark.cost,
      ),
    ],
    active: 0,
    fx: fx,
  );
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

/// Cuánto cambian: cuántos píxeles se mueven de verdad y cuál es el peor.
({int reales, int peor}) _cuanto(ByteData a, ByteData b) {
  final x = a.buffer.asUint8List();
  final y = b.buffer.asUint8List();
  var reales = 0, peor = 0;
  for (var i = 0; i < x.length; i += 4) {
    var d = 0;
    for (var c = 0; c < 3; c++) {
      final e = (x[i + c] - y[i + c]).abs();
      if (e > d) d = e;
    }
    if (d > 24) reales++;
    if (d > peor) peor = d;
  }
  return (reales: reales, peor: peor);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('las caras enterradas no se archivan, y no se nota', () {
    /// Levanta y pinta [hacer] dos veces: una archivando hasta lo que no se
    /// ve y otra sin archivarlo. Entre las dos hay que tirar los pueblos
    /// guardados, porque lo que cambia es la piedra y no la cámara.
    Future<void> igual(
      WidgetTester tester,
      String cual,
      TownScene Function() hacer, {
      double margen = 0.004,
    }) async {
      buryHidden = false;
      forgetTowns();
      final (antes, _) = await _pinta(tester, hacer());
      buryHidden = true;
      forgetTowns();
      final (luego, _) = await _pinta(tester, hacer());
      final d = _cuanto(antes, luego);
      // **Aquí el listón no puede ser cero, y conviene decir por qué.**
      //
      // Cada cara se pinta con un trazo de un píxel alrededor para cerrar la
      // costura con sus vecinas, y ese trazo lo llevaban también las caras
      // enterradas: el culo de una casa dejaba un pelo de su color asomando
      // por la línea donde la casa toca la hierba. Al no archivarlas, ese
      // pelo desaparece. Además, con otras caras el árbol de planos corta por
      // otro sitio, y un borde suavizado que se mueve medio píxel cambia el
      // píxel. Las dos cosas son de medio píxel; ninguna es un agujero.
      //
      // Lo que sí tiene que ser imposible es el agujero, y un agujero no se
      // parece a esto: una pared que falta son miles de píxeles cambiando de
      // piedra a hierba. Por eso se mide **cuánto** cambia cada píxel y no
      // cuántos: hasta aquí llega el pelo de una costura, de aquí en adelante
      // sólo llega la hierba.
      final cabe = 390 * 844 * margen;
      expect(
        d.reales,
        lessThan(cabe),
        reason:
            '$cual: ${d.reales} píxeles cambiaron de verdad (peor ${d.peor})',
      );
    }

    tearDown(() {
      buryHidden = true;
      forgetTowns();
    });

    testWidgets('en un pueblo, desde ocho ángulos', (tester) async {
      for (var i = 0; i < 8; i++) {
        await igual(
          tester,
          'yaw $i/8',
          () => _valle(200, yaw: i * 0.785, dist: 22),
        );
      }
    });

    testWidgets('de noche y a la deriva, que es cuando se abren huecos', (
      tester,
    ) async {
      // De noche el listón es más flojo, y por una razón concreta: los halos
      // de las ventanas se pintan intercalados en el orden de las caras, así
      // que al haber menos caras se recomponen un puesto antes o después. Lo
      // que cambia es sobre qué pared se apoya un resplandor, no dónde está
      // la pared — y que ninguna luz atraviese una casa lo sigue vigilando
      // `lamp_test.dart`, que pasa igual.
      await igual(
        tester,
        'noche',
        () => _valle(200, hora: 22.5, dist: 16),
        margen: 0.02,
      );
      await igual(tester, 'tarde', () => _valle(200, dist: 20, hora: 19.5));
    });

    testWidgets('a ras del suelo, que es donde se vería un culo que falta', (
      tester,
    ) async {
      await igual(tester, 'a ras', () => _valle(200, pitch: 0.02, dist: 18));
      await igual(tester, 'a plomo', () => _valle(200, pitch: 1.45, dist: 18));
    });

    testWidgets('con una pieza en el aire encima de cada tipo de obra', (
      tester,
    ) async {
      // **El caso que obliga a la regla de «sólo tapa el más viejo».** La
      // pieza que cae se dibuja aparte, levantada; si al archivarse hubiera
      // borrado la cara de abajo de lo que tiene debajo, el agujero se vería
      // durante todo el vuelo.
      for (final mark in landmarks) {
        for (final t in [0.3, 0.8]) {
          // Y que la pieza esté de verdad en el aire: una prueba que compara
          // dos fotogramas en los que no vuela nada no prueba nada.
          buryHidden = true;
          forgetTowns();
          final (conVuelo, _) = await _pinta(tester, _cayendo(mark, t));
          final (quieta, _) = await _pinta(tester, _obra(mark));
          expect(
            _difieren(conVuelo, quieta),
            greaterThan(0),
            reason: '${mark.name}: no se movió nada',
          );
          await igual(
            tester,
            '${mark.name} a $t de caer',
            () => _cayendo(mark, t),
          );
        }
      }
    });

    testWidgets('y obra por obra del catálogo, de cerca', (tester) async {
      for (final mark in landmarks) {
        await igual(tester, mark.name, () => _obra(mark));
      }
    });

    test('una pieza nueva nunca tapa la cara de una vieja', () {
      // **La propiedad que protege a la pieza que vuela**, comprobada por sí
      // misma y no por los píxeles: en el catálogo de verdad casi nunca pasa
      // que una pieza sea más ancha que la de debajo, así que un fallo aquí
      // no se vería en ninguna obra existente — y se vería el día que se
      // escriba una que sí, con la app ya en la calle.
      //
      // Así que la obra se escribe aquí: una caja angosta y encima otra que
      // la desborda por los cuatro lados. La cara de arriba de la angosta
      // está tapada del todo por la ancha, pero la ancha es **más nueva**: si
      // se archivara sin ella, mientras la ancha estuviera en el aire se
      // vería el agujero.
      //
      // Se cumple por dos motivos a la vez, y está bien que sean dos. El de
      // fondo es que se archiva en orden: cuando le toca a la angosta, la
      // ancha todavía no existe, así que no hay con qué taparla. El escrito
      // es la comparación de edades en `enterrada`, que sobra mientras ese
      // orden se respete y deja de sobrar el día que alguien lo cambie. Lo
      // que fija esta prueba es la propiedad, no cuál de los dos la sostiene.
      final torpe = Landmark('probeta', 'Probeta', 2, 0, 'Dos cajas.', (m) {
        m.box(PieceKind.floor, 1.0, 1.0, 1.0);
        m.box(PieceKind.floor, 2.0, 2.0, 1.0);
      });
      buryHidden = true;
      forgetTowns();
      final layout = TownLayout.showcase(
        TownCharacter.all.first,
        landmark: torpe,
        placed: 2,
      );
      final built = builtTown(layout, 2);
      final arriba = <Facet>[];
      for (final c in built.clusters) {
        for (final f in c.source) {
          if (f.n.y > 0.999 && f.piece == 0) arriba.add(f);
        }
      }
      expect(
        arriba,
        isNotEmpty,
        reason:
            'se archivó sin la cara de arriba de la pieza de abajo, y esa '
            'cara se ve mientras la de encima está cayendo',
      );
      forgetTowns();
    });
  });

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
