import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/core/math3.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/data/landmarks.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/appearance.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/choice_sheet.dart';
import 'package:la_muralla/ui/settings_sheet.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El plan de un pueblo cualquiera, siempre el mismo.
TownPlan get _plan => TownPlan.of(TownCharacter.all.first);

/// Una pregunta del pueblo, con todo lo que había alrededor cuando la hizo.
typedef Ask = ({
  int at,
  List<String> options,
  String taken,
  List<String> before,
});

/// Levanta un pueblo pieza a pieza, exactamente como hace la app: en cada
/// pieza se escribe en la crónica lo que ya se puede ver, y si el pueblo
/// pregunta, se le contesta con [pick] —o con lo primero que ofrece, que es lo
/// que pasa cuando nadie contesta— y se vuelve a escribir.
///
/// Devuelve todas las preguntas que hizo por el camino. Hace falta simular y
/// no calcular: al contestar distinto, la obra siguiente **empieza en otra
/// pieza**, porque las obras no cuestan todas lo mismo. Cualquier test que dé
/// por hecho dónde cae el segundo hito está mirando otro pueblo.
({List<String> chronicle, List<Ask> asks}) _grow(
  int pieces, {
  String Function(List<String> options)? pick,
}) {
  final plan = _plan;
  final chron = <String>[];
  final asks = <Ask>[];
  void escribir(int n) {
    final want = plan.chronicleFor(n, chron);
    chron
      ..clear()
      ..addAll(want);
  }

  for (var n = 0; n <= pieces; n++) {
    escribir(n);
    final c = plan.choiceFor(n, chron);
    if (c == null) continue;
    final before = [...chron];
    final taken = pick == null ? c.$2.first : pick(c.$2);
    asks.add((at: n, options: c.$2, taken: taken, before: before));
    chron.add(taken);
    escribir(n);
  }
  return (chronicle: chron, asks: asks);
}

/// Cuántas piezas hay que poner para que el pueblo pregunte [n] veces.
int _piecesFor(int n) {
  var pieces = 60;
  while (pieces < 4000) {
    if (_grow(pieces).asks.length >= n) return pieces;
    pieces += 60;
  }
  return -1;
}

void main() {
  group('el pueblo pregunta antes de empezar una obra', () {
    test('no pregunta por las casas, sólo por los hitos', () {
      final g = _grow(400);
      expect(g.asks, isNotEmpty, reason: 'no preguntó nunca en 400 piezas');
      for (final a in g.asks) {
        for (final id in a.options) {
          expect(
            TownPlan.landmarkOf(id),
            isNotNull,
            reason: 'ofreció «$id», que no es un hito',
          );
        }
      }
    });

    test('pregunta justo en la pieza en que la obra empezaría', () {
      // Ni antes —sería preguntar por algo que no se ve venir— ni después:
      // después ya habría piezas puestas de una obra que se elegiría luego, y
      // una pieza no se mueve nunca.
      final plan = _plan;
      for (final a in _grow(400).asks) {
        expect(
          plan.choiceFor(a.at - 1, a.before),
          isNull,
          reason: 'con ${a.at} piezas preguntó una pieza antes de tiempo',
        );
        final obra = plan.underway(a.at, a.before);
        expect(obra, isNotNull);
        expect(
          obra!.$2,
          TownPlan.landmarkOf(a.taken)!.cost,
          reason: 'la obra ya estaba empezada cuando preguntó',
        );
      }
    });

    test('las dos que ofrece son distintas y ninguna está en pie', () {
      for (final a in _grow(600).asks) {
        expect(
          a.options.toSet().length,
          2,
          reason: 'con ${a.at} piezas ofreció dos veces lo mismo',
        );
        for (final id in a.options) {
          expect(
            a.before.contains(id),
            isFalse,
            reason: 'ofreció «$id», que ya está levantado',
          );
        }
      }
    });

    test('deja de preguntar en cuanto se contesta', () {
      final plan = _plan;
      final a = _grow(_piecesFor(1)).asks.first;
      final chron = [...a.before, a.taken];
      expect(plan.choiceFor(a.at, chron), isNull);
    });
  });

  group('contestar no le cambia el pueblo a nadie', () {
    test('lo que ya estaba escrito no se toca', () {
      // La regla de la crónica: sólo crece. Si contestar reescribiera algo de
      // más atrás, a alguien con doscientas piezas puestas le cambiarían las
      // casas por debajo.
      for (final a in _grow(400, pick: (o) => o.last).asks) {
        final chron = [...a.before, a.taken];
        expect(chron.sublist(0, a.before.length), a.before);
      }
    });

    test('la que dejás puede volver a salir o no, y ésa es la gracia', () {
      // La regla vieja era que la descartada encabezaba la pregunta siguiente,
      // y con eso elegir no decidía nada: las dos se construían igual, una
      // detrás de la otra, y lo único que cambiaba era el orden. Ahora las dos
      // se sortean de entre las que le tocan pronto, así que dejar una es
      // dejarla de verdad — puede volver, y puede que no.
      final g = _grow(_piecesFor(10), pick: (o) => o.last);
      expect(g.asks.length, greaterThanOrEqualTo(4));
      var volvio = 0, no = 0;
      for (var i = 0; i + 1 < g.asks.length; i++) {
        if (g.asks[i + 1].options.contains(g.asks[i].options.first)) {
          volvio++;
        } else {
          no++;
        }
      }
      expect(
        no,
        greaterThan(0),
        reason: 'la descartada volvió a salir **siempre**: no se sortea nada',
      );
      expect(
        volvio,
        greaterThan(0),
        reason: 'la descartada no volvió a salir nunca: se está perdiendo',
      );
    });

    test('pero no se pierde: sigue en el catálogo del pueblo', () {
      // Lo que no puede pasar es que dejar una la borre. Dejando siempre la
      // primera, todas las que se dejaron tienen que seguir estando —sin
      // construir, y disponibles— al final del recorrido.
      final plan = _plan;
      final g = _grow(_piecesFor(10), pick: (o) => o.last);
      final dejadas = {for (final a in g.asks) a.options.first}
        ..removeAll(g.chronicle);
      expect(dejadas, isNotEmpty);
      final puestas = {
        for (final id in g.chronicle)
          if (!id.startsWith(TownPlan.kindMark)) id,
      };
      for (final id in dejadas) {
        expect(
          plan.order.contains(id),
          isTrue,
          reason: '«$id» se cayó del orden del pueblo',
        );
        expect(
          puestas.contains(id),
          isFalse,
          reason: '«$id» se dejó y aun así se construyó',
        );
      }
    });

    test('la descartada se levanta la vez que se la elige', () {
      // Alternando —una vez la primera, otra la segunda, que es como contesta
      // cualquiera— todo lo que se ofrece acaba en pie.
      var turno = 0;
      final g = _grow(_piecesFor(6), pick: (o) => o[turno++ % 2]);
      for (final a in g.asks) {
        if (a.taken != a.options.first) continue;
        expect(
          g.chronicle.contains(a.options.first),
          isTrue,
          reason: 'se eligió «${a.taken}» y no se construyó',
        );
      }
    });

    test('y una que se deja una y otra vez vuelve a ofrecerse', () {
      // No se pierde por dejarla, aunque no salga en la pregunta siguiente:
      // mientras no se construya sigue en la ventana de las que le tocan
      // pronto, y de ahí se sortea otra vez.
      final g = _grow(_piecesFor(12), pick: (o) => o.last);
      final tomadas = {for (final a in g.asks) a.taken};
      final veces = <String, int>{};
      for (final a in g.asks) {
        for (final id in a.options) {
          veces.update(id, (n) => n + 1, ifAbsent: () => 1);
        }
      }
      // Alguna que se ofreció más de una vez y nunca se eligió. Que exista es
      // la prueba: se dejó, no salió a la siguiente, y aun así volvió.
      final porfiadas = [
        for (final e in veces.entries)
          if (e.value > 1 && !tomadas.contains(e.key)) e.key,
      ];
      expect(
        porfiadas,
        isNotEmpty,
        reason: 'ninguna obra dejada volvió a ofrecerse: se pierden',
      );
      for (final id in porfiadas) {
        expect(
          g.chronicle.contains(id),
          isFalse,
          reason: '«$id» no se eligió nunca y se construyó igual',
        );
      }
    });

    test('no contestar levanta exactamente el pueblo de antes', () {
      // El seguro de compatibilidad: quien nunca conteste tiene que ver el
      // mismo pueblo que veía antes de que esto existiera, porque la primera
      // opción es justo la que el plan daba solo.
      final plan = _plan;
      final g = _grow(600);
      // Contestar la primera de las dos es lo mismo que no contestar: la
      // crónica entera tiene que salir, obra por obra, igual que la que el
      // plan levanta solo.
      final solo = [
        for (final w in plan.walk(const []).take(g.chronicle.length)) w.id,
      ];
      expect(g.chronicle, solo);
    });
  });

  group('la pregunta caduca, y eso es lo que la hace segura', () {
    test('en cuanto cae la pieza siguiente, se escribe sola', () {
      // Lo peligroso de dejar la pregunta abierta: si nadie contesta nunca, la
      // crónica se queda congelada, y una crónica congelada es exactamente lo
      // que la crónica existe para evitar —un hito nuevo en el catálogo le
      // cambiaría las casas a alguien que ya las tiene levantadas—. Así que la
      // pregunta dura una pieza. La siguiente la cierra sola con lo de siempre.
      final plan = _plan;
      final a = _grow(_piecesFor(1)).asks.first;
      expect(plan.choiceFor(a.at, a.before), isNotNull);
      expect(
        plan.choiceFor(a.at + 1, a.before),
        isNull,
        reason: 'la pregunta siguió abierta con la obra ya empezada',
      );
      final escrita = plan.chronicleFor(a.at + 1, a.before);
      expect(
        escrita.length,
        greaterThan(a.before.length),
        reason: 'la crónica se quedó congelada esperando una respuesta',
      );
      expect(escrita[a.before.length], a.options.first);
    });

    test('y la crónica de quien nunca conteste sigue creciendo', () {
      // La misma garantía, dicha a lo largo: se ponen mil piezas sin contestar
      // una sola vez y la crónica tiene que llegar hasta el final.
      final plan = _plan;
      final chron = <String>[];
      for (var n = 0; n <= 1000; n++) {
        final want = plan.chronicleFor(n, chron);
        chron
          ..clear()
          ..addAll(want);
      }
      final obras = plan.walk(chron).takeWhile((w) => w.from <= 999).length;
      expect(
        chron.length,
        greaterThanOrEqualTo(obras - 1),
        reason: 'con mil piezas sin contestar la crónica se quedó corta',
      );
    });
  });

  group('mientras no se conteste', () {
    test('el pueblo se ve como si hubiera elegido la primera', () {
      // Nada se queda a medias esperando una respuesta: el plan sigue dando la
      // primera opción, así que la pieza que cae tiene dónde ir. Lo único que
      // pasa es que todavía no está escrito, y por eso se puede cambiar.
      final plan = _plan;
      final a = _grow(_piecesFor(1)).asks.first;
      final obra = plan.underway(a.at, a.before);
      expect(obra, isNotNull);
      expect(obra!.$1, TownPlan.landmarkOf(a.options.first)!.name);
      expect(obra.$3, isTrue, reason: 'debería estar levantando un hito');
    });

    test('y la crónica se planta ahí, sin escribirlo', () {
      final plan = _plan;
      final a = _grow(_piecesFor(1)).asks.first;
      expect(
        plan.chronicleFor(a.at, a.before).length,
        a.before.length,
        reason: 'escribió el hito sin preguntar',
      );
    });
  });

  group('el store, que es quien lo escribe', () {
    Future<Store> fresh() async {
      SharedPreferences.setMockInitialValues({});
      final s = Store();
      await s.load();
      return s;
    }

    /// Pone piezas hasta que el pueblo pregunte, y devuelve la pregunta.
    Future<List<Landmark>> untilAsks(Store s) async {
      for (var n = 0; n < 4000; n++) {
        final q = s.pendingChoice;
        if (q != null) return q;
        s.placePiece();
      }
      throw StateError('nunca preguntó');
    }

    test('no pregunta nada al empezar un pueblo', () async {
      final s = await fresh();
      expect(s.pendingChoice, isNull);
    });

    test('contestar lo escribe y deja de preguntar', () async {
      final s = await fresh();
      final q = await untilAsks(s);
      expect(q.length, 2);
      s.chooseWork(q.last.id);
      expect(s.pendingChoice, isNull);
      expect(s.habit.chronicle.last, q.last.id);
    });

    test('y el pueblo levanta lo que se eligió', () async {
      final s = await fresh();
      final q = await untilAsks(s);
      s.chooseWork(q.last.id);
      final obra = s.plan.underway(s.total, s.habit.chronicle);
      expect(obra, isNotNull);
      expect(obra!.$1, q.last.name);
    });

    test('que decidan ellos escribe la primera', () async {
      final s = await fresh();
      final q = await untilAsks(s);
      s.letThemDecide();
      expect(s.pendingChoice, isNull);
      expect(s.habit.chronicle.last, q.first.id);
    });

    test('contestar algo que no se preguntó no rompe nada', () async {
      // Nadie debería poder, pero un pueblo no se queda esperando por una
      // respuesta que no tiene sentido: se escribe la que habría salido sola.
      final s = await fresh();
      final q = await untilAsks(s);
      s.chooseWork('no-existe-esta-obra');
      expect(s.pendingChoice, isNull);
      expect(s.habit.chronicle.last, q.first.id);
    });

    test('lo elegido sobrevive a guardar y volver a cargar', () async {
      // Es lo único que hace que la elección signifique algo: si no se
      // guardara, mañana el pueblo estaría levantando la otra.
      SharedPreferences.setMockInitialValues({});
      final s = Store();
      await s.load();
      final q = await untilAsks(s);
      s.chooseWork(q.last.id);
      final piezas = s.total;

      final otra = Store();
      await otra.load();
      expect(otra.total, piezas);
      expect(otra.habit.chronicle.last, q.last.id);
      expect(
        otra.plan.underway(otra.total, otra.habit.chronicle)!.$1,
        q.last.name,
      );
    });
  });

  group('el botón de ajustes que la enseña', () {
    /// Abre los ajustes de verdad y busca la fila.
    Future<Store> abrirAjustes(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await Appearance.instance.load();
      final store = Store();
      await store.load();
      store.renameHabit(0, name: 'Leer', symbol: 'libro');
      store.debugFill(120);
      // **Y con el pueblo justo en una pregunta de verdad.** Si no, contestar
      // en la tarjeta de mentira no escribiría nada ni siendo de verdad
      // —`chooseWork` se va sin hacer nada cuando nadie está preguntando— y el
      // test de abajo pasaría por el motivo equivocado.
      while (store.plan.choiceFor(store.habit.total, store.habit.chronicle) ==
              null &&
          store.habit.total < 900) {
        store.debugFill(1);
      }
      expect(
        store.plan.choiceFor(store.habit.total, store.habit.chronicle),
        isNotNull,
        reason: 'no se encontró una pieza en la que el pueblo pregunte',
      );
      await tester.binding.setSurfaceSize(const Size(393, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Los ajustes se abren como hoja, que es como se abren en la app: la
      // fila cierra la hoja antes de enseñar la tarjeta, y eso sólo funciona
      // si la hoja es una ruta de verdad.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => SettingsSheet(
                    store: store,
                    theme: UiTheme(Palette.forMoment(11, 1.0)),
                  ),
                ),
                child: const Text('ajustes'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ajustes'));
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('enseña la tarjeta sin que la pida el pueblo', (tester) async {
      // La pantalla sale sola una vez cada varias semanas: sin esto, para
      // mirarla hay que esperar a que el pueblo la pida.
      await abrirAjustes(tester);
      final fila = find.text('Ver la tarjeta de elegir');
      await tester.scrollUntilVisible(fila, 120);
      await tester.ensureVisible(fila);
      await tester.pumpAndSettle();
      await tester.tap(fila);
      await tester.pumpAndSettle();
      expect(find.text('¿Qué construir?'), findsOneWidget);
    });

    testWidgets('y contestar ahí no le toca el pueblo a nadie', (tester) async {
      // **Lo que importa de este botón.** Una herramienta para mirar que
      // además toca lo que mira no sirve para mirar: contestar aquí no puede
      // empezar ninguna obra, ni gastar la pregunta de verdad, ni escribir una
      // línea en la crónica.
      final store = await abrirAjustes(tester);
      final antes = [...store.habit.chronicle];
      final piezas = store.habit.pieces.length;

      final fila = find.text('Ver la tarjeta de elegir');
      await tester.scrollUntilVisible(fila, 120);
      await tester.ensureVisible(fila);
      await tester.pumpAndSettle();
      await tester.tap(fila);
      await tester.pumpAndSettle();

      // Elegir una, que es el camino que sí escribe cuando la pregunta es de
      // verdad. Se toca el retrato porque los nombres de las dos obras salen
      // al azar del catálogo y no se saben de antemano.
      final retrato = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is WorkPortrait,
      );
      await tester.tap(retrato.first);
      await tester.pumpAndSettle();
      expect(find.text('¿Qué construir?'), findsNothing);

      expect(store.habit.chronicle, antes);
      expect(store.habit.pieces.length, piezas);
    });
  });

  group('la hoja', () {
    /// La hoja, montada con dos obras cualquiera y abierta como la abre la
    /// app: encima de todo, en su propia ruta. Abierta a mano dentro de un
    /// `Scaffold` no valdría, porque elegir cierra la tarjeta y no habría
    /// ruta que cerrar.
    Future<List<String>> pump(WidgetTester tester, {Size? size}) async {
      final picked = <String>[];
      await tester.binding.setSurfaceSize(size ?? const Size(393, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // **El contexto, por encima del `Scaffold`.** No es un detalle del
      // andamio: `showDialog` se lleva a la ruta nueva los temas heredados
      // del contexto desde el que se la abre, y `DefaultTextStyle` es uno de
      // ellos. Abierta desde dentro del `Scaffold` la tarjeta hereda la
      // tipografía del `Material` que el `Scaffold` pone debajo y **el fallo
      // no se reproduce**; la app la abre desde el contexto de la pantalla,
      // que está por encima, y ahí no hay ninguna.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ChoiceSheet(
                    options: [
                      landmarks.firstWhere((l) => l.id == 'catedral'),
                      landmarks.firstWhere((l) => l.id == 'coso'),
                    ],
                    place: TownCharacter.all.first,
                    theme: UiTheme(Palette.forMoment(11, 1.0)),
                    onPick: (m) => picked.add(m.id),
                  ),
                ),
                child: const Text('preguntar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('preguntar'));
      await tester.pumpAndSettle();
      return picked;
    }

    testWidgets('tocar una obra es elegirla, y ahí se acaba', (tester) async {
      // Había un paso más: señalar una y después confirmar en un renglón de
      // abajo. Señalar y decir que sí es decir dos veces lo mismo cuando lo
      // que se elige son dos cosas dibujadas.
      final picked = await pump(tester);
      await tester.tap(find.text('Coso y graderío'));
      await tester.pumpAndSettle();
      expect(picked, ['coso']);
      expect(find.text('¿Qué construir?'), findsNothing);
    });

    testWidgets('y no queda nada del formulario que era', (tester) async {
      // Lo que se quitó, y que no vuelva por descuido: el rótulo de encima, el
      // párrafo de las reglas, el botón ámbar del ancho de la tarjeta, y los
      // dos renglones de abajo —confirmar y «que decidan ellos»—, que eran
      // tres maneras de contestar la misma pregunta.
      await pump(tester);
      expect(find.text('EL PUEBLO PREGUNTA'), findsNothing);
      expect(find.textContaining('la próxima vez'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('ELEGÍ UNA'), findsNothing);
      expect(find.text('QUE EMPIECEN'), findsNothing);
      expect(find.text('Que decidan ellos'), findsNothing);
      expect(find.text('¿Qué construir?'), findsOneWidget);
    });

    testWidgets('el título entra en un renglón hasta en el móvil más '
        'estrecho', (tester) async {
      // «¿Qué levantamos ahora?» partía en dos, y dos renglones de título
      // encima de dos dibujos ocupan el sitio de los dibujos.
      await pump(tester, size: const Size(320, 700));
      final p = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('¿Qué construir?'),
          matching: find.byType(RichText),
        ),
      );
      expect(p.didExceedMaxLines, isFalse, reason: 'el título se cortó');
      expect(p.size.height, lessThan(34), reason: '${p.size.height}px de alto');
    });

    testWidgets('se escribe con la letra de la app y sin subrayar', (
      tester,
    ) async {
      // **El fallo que se vio en el teléfono.** Una tarjeta abierta con
      // `showDialog` cuelga del pasillo de rutas, fuera del `Scaffold`, y
      // arriba del todo no hay ningún `Material` del que heredar tipografía.
      // Flutter entonces escribe con su letra de emergencia: monoespaciada y
      // subrayada en amarillo doble. Salía así la tarjeta entera.
      await pump(tester);
      final malas = <String>[];
      for (final e in find.byType(RichText).evaluate()) {
        final style = (e.widget as RichText).text.style;
        if (style == null) continue;
        final texto = (e.widget as RichText).text.toPlainText();
        if (style.decoration == TextDecoration.underline) {
          malas.add('«$texto» subrayado');
        }
        if (style.fontFamily == 'monospace') {
          malas.add('«$texto» en monoespaciada');
        }
      }
      expect(malas, isEmpty, reason: malas.join(', '));
    });

    testWidgets('las dos obras salen con su nombre y su precio', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Catedral'), findsOneWidget);
      expect(find.text('Coso y graderío'), findsOneWidget);
      for (final id in ['catedral', 'coso']) {
        final m = landmarks.firstWhere((l) => l.id == id);
        expect(find.text('${m.cost}'), findsWidgets, reason: id);
      }
    });

    testWidgets('el dibujo manda sobre lo escrito', (tester) async {
      // Lo que se está decidiendo es qué quiere uno ver en su valle, y eso se
      // decide mirando: si el retrato no es con diferencia lo más grande de
      // la columna, la tarjeta vuelve a ser una lista con una miniatura al
      // lado, que es de donde venía.
      //
      // El listón está en el 45% y no en la mitad por la letra de las
      // pruebas: aquí cada letra es un cuadrado del alto de la línea, así que
      // un párrafo mide casi el doble de renglones que en un teléfono. Con
      // una letra de verdad esto pasa del sesenta por ciento; con una
      // miniatura de ochenta y dos píxeles —lo que había antes— daría
      // veinticinco.
      await pump(tester);
      final retrato = find
          .byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is WorkPortrait,
          )
          .first;
      final alto = tester.getSize(retrato).height;
      final columna = tester
          .getSize(
            find
                .ancestor(
                  of: find.text('Catedral'),
                  matching: find.byType(Column),
                )
                .first,
          )
          .height;
      expect(alto, greaterThan(columna * 0.45), reason: '$alto de $columna');
    });
  });

  group('el retrato de la obra', () {
    test('la obra entra entera, y las ciento y pico', () {
      // El fallo que esto existe para cazar no se ve leyendo el código: la
      // cámara se fijaba sobre sus valores y no sobre sus objetivos, y
      // `snap()` los pisa, así que el retrato salía desde el sitio por defecto
      // y el castillo aparecía cortado por la mitad. Se ve mirándolo, o
      // midiéndolo — y mirar ciento y pico obras una a una no lo hace nadie.
      const size = Size(82, 82);
      final place = TownCharacter.all.first;
      final malas = <String>[];
      for (final mark in landmarks) {
        final layout = TownLayout.showcase(
          place,
          landmark: mark,
          placed: mark.cost,
        );
        final cam = WorkPortrait.frame(layout, size);
        final p = cam.projector(size.width, size.height, 0);
        var fuera = 0, vistos = 0;
        for (final pieza in layout.pieces) {
          for (final v in [
            V3(pieza.x0, pieza.y0, pieza.z0),
            V3(pieza.x1, pieza.y1, pieza.z1),
            V3(pieza.x0, pieza.y1, pieza.z1),
            V3(pieza.x1, pieza.y0, pieza.z0),
          ]) {
            final at = p.project(v);
            if (at == null) continue;
            vistos++;
            if (at.x < -1 ||
                at.y < -1 ||
                at.x > size.width + 1 ||
                at.y > size.height + 1) {
              fuera++;
            }
          }
        }
        if (vistos == 0 || fuera > 0) malas.add('${mark.name} ($fuera fuera)');
      }
      expect(malas, isEmpty, reason: malas.join(', '));
    });

    test('y no sale tan lejos que no se vea nada', () {
      // El otro extremo del mismo ajuste: encuadrar de sobra es fácil y deja
      // la obra del tamaño de una mosca en una miniatura de ochenta píxeles.
      const size = Size(82, 82);
      final place = TownCharacter.all.first;
      final chicas = <String>[];
      for (final mark in landmarks) {
        final layout = TownLayout.showcase(
          place,
          landmark: mark,
          placed: mark.cost,
        );
        final cam = WorkPortrait.frame(layout, size);
        final p = cam.projector(size.width, size.height, 0);
        // El lado mayor y no el ancho: una atalaya es alta y flaca, así que
        // ocupa poco a lo ancho por bien encuadrada que esté. Lo que se está
        // midiendo es si la obra llena el retrato, y una torre lo llena a lo
        // alto.
        var x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
        for (final pieza in layout.pieces) {
          for (final v in [
            V3(pieza.x0, pieza.y0, pieza.z0),
            V3(pieza.x1, pieza.y1, pieza.z1),
            V3(pieza.x0, pieza.y1, pieza.z1),
            V3(pieza.x1, pieza.y0, pieza.z0),
          ]) {
            final at = p.project(v);
            if (at == null) continue;
            if (at.x < x0) x0 = at.x;
            if (at.x > x1) x1 = at.x;
            if (at.y < y0) y0 = at.y;
            if (at.y > y1) y1 = at.y;
          }
        }
        final lado = math.max(x1 - x0, y1 - y0);
        if (lado < size.width * 0.55) {
          chicas.add('${mark.name} (${lado.round()}px de 82)');
        }
      }
      expect(chicas, isEmpty, reason: chicas.join(', '));
    });
  });

  group('preguntar de verdad cambia el pueblo', () {
    test('dos respuestas distintas dan dos valles distintos', () {
      // Si elegir no cambiara nada, sería una pregunta de adorno.
      final iguales = _grow(600).chronicle;
      final otros = _grow(600, pick: (o) => o.last).chronicle;
      expect(otros, isNot(iguales));
    });

    test('pero se pregunta poco: es una decisión, no un trámite', () {
      // Una app de un solo botón no puede estar preguntando cada semana. Con
      // seiscientas piezas —más de un año a una diaria— son un puñado.
      final asks = _grow(600).asks;
      expect(asks.length, inInclusiveRange(4, 12), reason: '${asks.length}');
    });
  });
}
