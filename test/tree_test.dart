import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lo que ningún otro test mira: la forma del proyecto.
///
/// Los dos fallos que esto atrapa ya habían pasado los dos, y ninguno dio
/// error en ninguna parte — ni el analizador, ni los otros cuatrocientos
/// setenta tests, ni la APK, que se construyó y se instaló tan contenta.
///
///   · Una pantalla entera de seiscientas noventa líneas a la que no llegaba
///     nadie. Se le quitó la puerta de entrada en septiembre y el fichero se
///     quedó ahí una semana, compilando. Y encima se le metió dentro una
///     función nueva, que salió en una APK sin ser alcanzable.
///
///   · Una flecha de dependencia hacia arriba: el motor importando una
///     pantalla para poder dibujar un cartel. Que `engine/` no sepa nada de
///     `ui/` es lo que deja probar el rasterizador sin levantar Flutter, y era
///     verdad por costumbre, que es la peor manera de que algo sea verdad.

/// Los ficheros de `lib/`, con lo que importa cada uno.
Map<String, List<String>> _arbol() {
  final out = <String, List<String>>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final dentro = <String>[];
    for (final l in f.readAsLinesSync()) {
      final m = RegExp("^import\\s+'([^']+)'").firstMatch(l);
      if (m == null) continue;
      final to = m.group(1)!;
      if (to.startsWith('dart:') ||
          (to.startsWith('package:') &&
              !to.startsWith('package:la_muralla/'))) {
        continue;
      }
      dentro.add(
        to.startsWith('package:la_muralla/')
            ? 'lib/${to.substring('package:la_muralla/'.length)}'
            : _normalize('${File(f.path).parent.path}/$to'),
      );
    }
    out[f.path] = dentro;
  }
  return out;
}

/// `a/b/../c` → `a/c`. No hay `path` en las dependencias y para esto sobra.
String _normalize(String p) {
  final parts = <String>[];
  for (final bit in p.split('/')) {
    if (bit == '.' || bit.isEmpty) continue;
    if (bit == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(bit);
  }
  return parts.join('/');
}

void main() {
  group('la forma del proyecto', () {
    test('a todo fichero de lib/ se llega desde main.dart', () {
      final arbol = _arbol();
      final visto = <String>{};
      final pila = <String>['lib/main.dart'];
      while (pila.isNotEmpty) {
        final p = pila.removeLast();
        if (!visto.add(p)) continue;
        pila.addAll(arbol[p] ?? const []);
      }
      final huerfanos = arbol.keys.where((p) => !visto.contains(p)).toList()
        ..sort();
      expect(
        huerfanos,
        isEmpty,
        reason:
            'nadie importa esto, así que no se puede abrir desde la app por '
            'mucho que compile:\n  ${huerfanos.join('\n  ')}',
      );
    });

    test('nada por debajo de ui/ sabe que ui/ existe', () {
      // La regla entera del proyecto en una línea. `engine/` es un
      // rasterizador y no una pantalla: se prueba sin levantar Flutter, se
      // mira con el expositor, y la cinemática lo usa desde otro sitio. En
      // cuanto importa un widget, nada de eso sigue siendo verdad.
      final malas = <String>[];
      _arbol().forEach((p, dentro) {
        if (p.startsWith('lib/ui/') || p == 'lib/main.dart') return;
        for (final d in dentro) {
          if (d.startsWith('lib/ui/')) malas.add('$p → $d');
        }
      });
      expect(malas, isEmpty, reason: malas.join('\n'));
    });

    test('y nadie se importa a sí mismo dando la vuelta por una carpeta', () {
      // `engine/foo.dart` importando `../engine/bar.dart` compila igual, pero
      // hace que mover una carpeta sea un día de trabajo en vez de un `git mv`.
      final malas = <String>[];
      _arbol().forEach((p, dentro) {
        final casa = File(p).parent.path;
        for (final d in dentro) {
          if (File(d).parent.path == casa && d != p) {
            final crudo = File(
              p,
            ).readAsStringSync().contains("'../${casa.split('/').last}/");
            if (crudo) malas.add('$p → $d');
          }
        }
      });
      expect(malas, isEmpty, reason: malas.join('\n'));
    });
  });
}
