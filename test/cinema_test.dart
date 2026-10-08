import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/core/math3.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/camera.dart';
import 'package:towny/engine/cinema.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/renderer.dart';
import 'package:towny/engine/scene.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/fx/effects.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/settings_sheet.dart';
import 'package:towny/ui/style.dart';

const int _w = 640, _h = 480;

/// Una casa sola en el prado, mirada desde arriba para que el suelo de los
/// cuatro lados quede a la vista.
TownLayout _casa() => TownLayout(6, TownCharacter.all.first, seed: 21);

OrbitCamera _camara(TownLayout l) => OrbitCamera()
  ..yaw = 0.68
  ..pitch = 1.1
  ..focusY = 0.5
  ..distance = 26
  ..wallLength = l.radius * 2;

TownScene _escena(TownLayout l, double hora, {required bool cine}) => TownScene(
  placed: 6,
  palette: Palette.forMoment(hora),
  camera: _camara(l),
  time: 7.3,
  hourOfDay: hora,
  effects: EffectSystem(),
  budget: 60000,
  towns: [TownEntry(layout: l, name: 'Leer', symbol: 'libro', placed: 6)],
  active: 0,
  labels: false,
  folk: false,
  ghost: false,
  cinematic: cine,
);

Future<List<int>> _pintar(TownScene s, [TouchMap? hits]) async {
  final rec = ui.PictureRecorder();
  TownPainter(
    s,
    hits ?? TouchMap(),
  ).paint(Canvas(rec), const Size(_w * 1.0, _h * 1.0));
  final img = await rec.endRecording().toImage(_w, _h);
  final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  return raw!.buffer.asUint8List();
}

/// Lo claro que está el suelo alrededor de un punto del mundo: la media de
/// un cuadradito de cinco por cinco.
double _luz(List<int> px, Projector p, double x, double z) {
  final s = p.project(V3(x, 0, z))!;
  var suma = 0.0;
  for (var dy = -2; dy <= 2; dy++) {
    for (var dx = -2; dx <= 2; dx++) {
      final i = ((s.y.round() + dy) * _w + s.x.round() + dx) * 4;
      suma += 0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2];
    }
  }
  return suma / 25;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('la calidad máxima se elige y se queda elegida', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('apagada de fábrica, y sobrevive a cerrar la app', () async {
      final a = Appearance.instance;
      await a.load();
      expect(a.cinematic, isFalse, reason: 'cuesta: no se enciende sola');
      await a.setCinematic(true);
      await a.flush();
      await a.setCinematic(false);
      await a.load();
      expect(a.cinematic, isTrue, reason: 'no se guardó');
      await a.setCinematic(false);
      await a.flush();
      await a.load();
      expect(a.cinematic, isFalse);
    });

    testWidgets('está en los ajustes y el interruptor la enciende', (
      tester,
    ) async {
      final store = Store();
      await store.load();
      await Appearance.instance.load();
      tester.view.physicalSize = const Size(420, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSheet(
              store: store,
              theme: UiTheme(Palette.forMoment(13)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final fila = find.widgetWithText(SwitchListTile, 'Calidad máxima');
      expect(fila, findsOneWidget);
      expect(Appearance.instance.cinematic, isFalse);
      await tester.tap(fila);
      await tester.pump(const Duration(milliseconds: 500));
      expect(Appearance.instance.cinematic, isTrue);
      await tester.tap(fila);
      await tester.pump(const Duration(milliseconds: 500));
      expect(Appearance.instance.cinematic, isFalse);
    });
  });

  group('el color de cine', () {
    // Un gris medio pasado por la matriz de la hora.
    List<double> gris(Palette pal) {
      final m = Cinema.grade(pal);
      return [
        for (var r = 0; r < 3; r++)
          (m[r * 5] + m[r * 5 + 1] + m[r * 5 + 2]) * 128 + m[r * 5 + 4],
      ];
    }

    test('la noche se va al azul', () {
      final c = gris(Palette.forMoment(23));
      expect(c[2], greaterThan(c[0] + 10));
    });

    test('la hora dorada se calienta', () {
      final c = gris(Palette.forMoment(19.2));
      expect(c[0], greaterThan(c[2] + 10));
    });

    test('a mediodía no tiñe: sólo aviva', () {
      final c = gris(Palette.forMoment(13));
      expect((c[0] - c[2]).abs(), lessThan(4));
    });

    test('el resplandor sale de lo claro y no de lo oscuro', () {
      final m = Cinema.threshold(0.8, 1.0, const Color(0xFFFFFFFF));
      double sale(double v) =>
          (m[0] + m[1] + m[2]) * v * 255 + m[4]; // canal rojo, gris de entrada
      expect(sale(0.5), lessThan(0), reason: 'un gris medio no brilla');
      expect(sale(1.0), closeTo(255, 1), reason: 'el blanco da todo');
    });
  });

  group('las sombras', () {
    test('caen del lado contrario al sol, y giran con la hora', () async {
      final l = _casa();
      final b = l.buildings.first;
      Future<(double, double)> lados(double hora, bool cine) async {
        final s = _escena(l, hora, cine: cine);
        final p = s.camera.projector(_w * 1.0, _h * 1.0, s.time);
        final px = await _pintar(s);
        final luz = s.palette.lightDir;
        final n = math.sqrt(luz.x * luz.x + luz.z * luz.z);
        final dx = -luz.x / n, dz = -luz.z / n;
        // Fuera de la casa y de su sombra de contacto, pero dentro de lo que
        // mide la de verdad con el sol bajo.
        final r = b.reach + 1.4;
        return (
          _luz(px, p, b.cx + dx * r, b.cz + dz * r),
          _luz(px, p, b.cx - dx * r, b.cz - dz * r),
        );
      }

      // Al atardecer, con la calidad máxima, el suelo a la sombra de la casa
      // está claramente más oscuro que el del otro lado.
      final (sombra, sol) = await lados(18.6, true);
      expect(
        sombra,
        lessThan(sol - 12),
        reason: 'a la sombra $sombra, al sol $sol',
      );

      // Sin ella sólo hay la de contacto, que se queda debajo de la casa.
      final (sombraN, solN) = await lados(18.6, false);
      expect(
        sol - sombra,
        greaterThan((solN - sombraN) + 12),
        reason: 'sin calidad máxima: a la sombra $sombraN, al sol $solN',
      );

      // Y por la mañana el sol viene del otro lado: el lado oscuro también.
      final (manana, mananaSol) = await lados(8.0, true);
      final s8 = _escena(l, 8.0, cine: true).palette.lightDir;
      final s18 = _escena(l, 18.6, cine: true).palette.lightDir;
      expect(s8.x * s18.x, lessThan(0), reason: 'el sol cruzó el cielo');
      expect(manana, lessThan(mananaSol - 12));
    });
  });

  test('se sigue pudiendo tocar todo lo que se ve', () async {
    // El mundo se pinta en una grabación y no en la pantalla: los sitios
    // donde tocar se apuntan al pintar, y tienen que salir los mismos.
    final l = _casa();
    final normal = TouchMap(), cine = TouchMap();
    await _pintar(_escena(l, 13, cine: false), normal);
    await _pintar(_escena(l, 13, cine: true), cine);
    expect(normal.pieces, isNotEmpty);
    expect(cine.pieces.length, normal.pieces.length);
    expect(cine.boards.length, normal.boards.length);
  });

  test('lo que brilla sangra luz alrededor, y lo apagado no', () async {
    // Un cuadro negro con dos cuadrados: uno blanco, como una ventana
    // encendida, y otro gris, como una pared. Pasado por la cámara de noche,
    // al lado del blanco el negro se aclara; al lado del gris, no.
    final pal = Palette.forMoment(23);
    final cam = OrbitCamera()
      ..pitch = 1.3
      ..distance = 20;
    final p = cam.projector(_w * 1.0, _h * 1.0, 0);
    final rec = ui.PictureRecorder();
    Canvas(rec)
      ..drawRect(
        const Rect.fromLTWH(0, 0, _w * 1.0, _h * 1.0),
        Paint()..color = const Color(0xFF000000),
      )
      ..drawRect(
        const Rect.fromLTWH(140, 220, 24, 24),
        Paint()..color = const Color(0xFFFFFFFF),
      )
      ..drawRect(
        const Rect.fromLTWH(460, 220, 24, 24),
        Paint()..color = const Color(0xFF808080),
      );
    final mundo = rec.endRecording();
    final rec2 = ui.PictureRecorder();
    Cinema(pal, p, const Size(_w * 1.0, _h * 1.0)).compose(Canvas(rec2), mundo);
    final img = await rec2.endRecording().toImage(_w, _h);
    final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final px = raw!.buffer.asUint8List();
    int luz(int x, int y) {
      final i = (y * _w + x) * 4;
      return px[i] + px[i + 1] + px[i + 2];
    }

    // Doce píxeles fuera de cada cuadrado.
    final junto = luz(152, 256), lejos = luz(472, 256);
    expect(
      junto,
      greaterThan(lejos + 30),
      reason: 'blanco $junto, gris $lejos',
    );
  });
}
