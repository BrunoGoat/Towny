import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/reel_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saca fotogramas de la cinemática a disco para poder mirarla.
///
/// No es un test de nada: los tests dicen que no se cae y que los números
/// salen bien, y ninguna de las dos cosas dice si está bien encuadrada. Esto
/// es para verla.
///
///   flutter test tool/reel_frames_test.dart --dart-define=OUT=/tmp/reel
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Sin música. No es por gusto: en un test no hay plugin de audio, y
    // `AudioPlayer` arranca su inicialización por su cuenta en cuanto se
    // construye — fuera de cualquier `try` que podamos poner — así que pedirle
    // que suene tira una excepción asíncrona que cae encima del test y no de
    // la pantalla. Apagada, la cinemática no la pide, y lo que se prueba aquí
    // es lo que se ve, que es de lo que va esta pantalla.
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setMusicOff(true);
  });

  testWidgets('fotogramas', (tester) async {
    const out = String.fromEnvironment('OUT', defaultValue: '/tmp/reel');
    Directory(out).createSync(recursive: true);
    const n = int.fromEnvironment('PIEZAS', defaultValue: 140);
    const slots = int.fromEnvironment('PUEBLOS', defaultValue: 2);

    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.load();
    store.habits
      ..clear()
      ..addAll([
        for (var k = 0; k < slots; k++)
          Habit(
            id: 'h$k',
            name: ['Leer', 'Correr', 'Dibujar'][k % 3],
            symbol: ['libro', 'carrera', 'rueda'][k % 3],
            slot: k,
            createdAt: DateTime(2026, 1, 5),
            character: TownCharacter.all[k % TownCharacter.all.length].order,
            pieces: [
              for (var i = 0; i < (n >> k); i++)
                Piece(
                  index: i,
                  placedAt: DateTime(
                    2026,
                    1,
                    5,
                    18,
                  ).add(Duration(days: k * 40 + i * 2)),
                ),
            ],
          ),
      ]);

    final key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          devicePixelRatio: 2,
          padding: EdgeInsets.only(top: 44, bottom: 24),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: ReelScreen(store: store),
          ),
        ),
      ),
    );

    // Los instantes que valen: la entrada vacía, el primer pueblo, el segundo
    // apareciendo, el medio, el clímax y el final con la tarjeta.
    const cuando = [1.0, 4.0, 9.0, 17.0, 26.0, 36.0, 46.0, 54.0, 63.0, 66.0];
    var t = 0.0;
    for (final quiero in cuando) {
      while (t < quiero) {
        await tester.pump(const Duration(milliseconds: 50));
        t += 0.05;
      }
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final name = '$out/t${quiero.toStringAsFixed(0).padLeft(2, '0')}.png';
      // Dentro de `runAsync`, o se cuelga en la segunda: fuera de él el reloj
      // del test está parado, y `toImage` está esperando a un hilo que no
      // avanza mientras el test no le deje avanzar.
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1.6);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(name).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
      // ignore: avoid_print
      print('escrito $name');
    }
  });
}
