import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:towny/data/landmarks.dart';
import 'package:towny/engine/mason.dart';

/// Vuelca todas las obras del catálogo a un JSON, pieza por pieza.
///
///   flutter test tool/dump_test.dart
///
/// **Para qué.** Una obra es una receta de doce líneas y no un modelo, así que
/// no hay ningún fichero que abrir en un editor 3D para mirarla: lo único que
/// existe es el código, y ver si algo está flotando exige compilar la app,
/// abrirla y girar la cámara. Esto saca las cajas que la receta produce —en sus
/// propios números, sin las proporciones de ninguna comarca— para poder
/// mirarlas y moverlas fuera, y volver con las coordenadas ya corregidas.
///
/// Los números son **los de la receta**: el albañil trabaja con un `dx`, un
/// `dz`, un ancho, un fondo y una altura, y eso es lo que sale aquí. Un `cx` de
/// 2,4 en el volcado es un `dx: 2.4` en la receta, sin cuentas por el medio.
void main() {
  test('el catálogo entero, en cajas', () {
    final todas = landmarks;
    final out = <Map<String, dynamic>>[];
    for (final l in todas) {
      // Un albañil neutro: sin estirar, centrado en el origen y con la semilla
      // fija, para que lo que salga sea la receta y no una comarca concreta.
      final m = Mason(0, 0, 0x51a1e, true);
      l.build(m);
      out.add({
        'id': l.id,
        'name': l.name,
        'cost': l.cost,
        'tier': l.tier,
        'rigid': l.rigid,
        'pieces': [
          for (var i = 0; i < m.out.length; i++)
            () {
              final s = m.out[i];
              double r2(double v) => (v * 1000).round() / 1000;
              return {
                'i': i,
                'kind': s.kind.name,
                'dx': r2(s.cx),
                'dz': r2(s.cz),
                'w': r2(s.w),
                'd': r2(s.d),
                'at': r2(s.y0),
                'h': r2(s.y1 - s.y0),
                'along': s.alongX,
              };
            }(),
        ],
      });
    }
    const path = '/tmp/estructuras.json';
    File(path).writeAsStringSync(jsonEncode({'landmarks': out}));
    // ignore: avoid_print
    print(
      '${out.length} obras y '
      '${out.fold<int>(0, (a, l) => a + (l['pieces'] as List).length)} '
      'piezas en $path',
    );
  });
}
