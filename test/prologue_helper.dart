// Pasar la presentación del viejo, la primera vez, para llegar a la primera
// pregunta: sus globos de a uno, los dos consejos que da —se abren tirando y
// se cierran con un toque, como cualquier consejo nuevo— y el botón de fundar,
// aguantado, con su salto.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/advice.dart';

Future<void> pasarPresentacion(WidgetTester tester) async {
  Future<void> espera([int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final ancho = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final medio = ancho / 2;

  // Un toque termina de escribir lo que dice; el siguiente pasa de globo.
  Future<void> globo(String texto) async {
    await espera(5);
    final f = find.textContaining(texto, findRichText: true);
    expect(f, findsWidgets, reason: 'el viejo no dice «$texto»');
    // Arriba a la izquierda del texto, que siempre se ve: con la letra de las
    // pruebas, más ancha que la de verdad, un globo largo se sale por abajo y
    // su centro queda fuera.
    final donde = tester.getTopLeft(f.last) + const Offset(12, 8);
    await tester.tapAt(donde);
    await espera(3);
    await tester.tapAt(donde);
    await espera(6);
  }

  Future<void> rollo() async {
    await espera(12);
    final g = await tester.startGesture(Offset(medio, 200));
    for (var i = 0; i < 64; i++) {
      await g.moveBy(const Offset(0, 600 / 64));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await g.up();
    await espera(20);
    await tester.tapAt(Offset(medio, 420));
    await espera(30);
  }

  for (final l in SagePrologue.opening) {
    await globo(l);
  }
  await rollo();
  await globo(SagePrologue.between);
  await rollo();
  await globo(SagePrologue.closing.first);
  await espera(12);
  final boton = find.byKey(const ValueKey('fundar-primero'));
  expect(boton, findsOneWidget, reason: 'no quedó el botón de fundar');
  final g = await tester.startGesture(tester.getCenter(boton));
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await g.up();
  await espera(25);
}
