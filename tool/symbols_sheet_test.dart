import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/symbols.dart';
import 'package:towny/ui/habit_sigil.dart';

/// Las marcas de los hábitos en hojas, numeradas y con su nombre, para
/// revisarlas juntas: si se reconocen en chico y si alguna se confunde con
/// otra. En la app se ven de a una, y así no se juzga el conjunto.
///
///   flutter test tool/symbols_sheet_test.dart --dart-define=OUT=/tmp/marcas
///
/// Cada marca va dos veces: grande, para ver el dibujo, y del tamaño de la
/// barra de hábitos, que es donde tiene que entenderse.
Future<void> _letras() async {
  Future<void> carga(String familia, List<String> archivos) async {
    final l = FontLoader(familia);
    for (final a in archivos) {
      final f = File(a);
      if (!f.existsSync()) continue;
      l.addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
    }
    await l.load();
  }

  final sdk =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final material = '$sdk/bin/cache/artifacts/material_fonts';
  await carga('Roboto', [
    'assets/fonts/Roboto.ttf',
    '$material/Roboto-Medium.ttf',
    '$material/Roboto-Bold.ttf',
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const out = String.fromEnvironment('OUT', defaultValue: '/tmp/marcas');
  const columnas = 4, filas = 6;
  const porHoja = columnas * filas;
  const ancho = 1080.0, celda = ancho / columnas;

  const fondo = Color(0xFF1B1813);
  const tinta = Color(0xFFF6EFE1);
  const dorado = Color(0xFFEBC07A);

  testWidgets('las marcas en hojas', (tester) async {
    Directory(out).createSync(recursive: true);
    await tester.runAsync(_letras);
    // SOLO=leaf,quill… dibuja sólo ésas, con su número de siempre.
    const solo = String.fromEnvironment('SOLO');
    final todas = [
      for (var i = 0; i < habitSymbols.length; i++)
        if (solo.isEmpty || solo.split(',').contains(habitSymbols[i])) i,
    ];
    final hojas = (todas.length / porHoja).ceil();
    tester.view.physicalSize = const Size(ancho, celda * filas);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (var hoja = 0; hoja < hojas; hoja++) {
      final key = GlobalKey();
      final aca = todas.skip(hoja * porHoja).take(porHoja).toList();
      final ids = [for (final i in aca) habitSymbols[i]];
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          // Con Material encima: sin él los textos no heredan la letra del
          // tema y salen en la de las pruebas, que son cuadrados.
          home: RepaintBoundary(
            key: key,
            child: Material(
              color: fondo,
              child: Container(
                color: fondo,
                child: Wrap(
                  children: [
                    for (var i = 0; i < ids.length; i++)
                      SizedBox(
                        width: celda,
                        height: celda,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0x22F6EFE1)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${aca[i] + 1}',
                                      style: const TextStyle(
                                        color: dorado,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    // Del tamaño de la barra de hábitos.
                                    HabitSigil(
                                      symbol: ids[i],
                                      color: tinta,
                                      size: 22,
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: Center(
                                    child: HabitSigil(
                                      symbol: ids[i],
                                      color: tinta,
                                      size: 120,
                                    ),
                                  ),
                                ),
                                Text(
                                  habitSymbolNames[ids[i]]!,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: const TextStyle(
                                    color: tinta,
                                    fontSize: 22,
                                    height: 1.15,
                                  ),
                                ),
                                Text(
                                  ids[i],
                                  style: const TextStyle(
                                    color: Color(0x99F6EFE1),
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/marcas-${hoja + 1}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
      // ignore: avoid_print
      print('escrito $out/marcas-${hoja + 1}.png');
    }
  });
}
