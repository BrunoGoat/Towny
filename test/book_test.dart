import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/engine/town.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';
import 'package:la_muralla/ui/legends_book.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:la_muralla/ui/works_calendar.dart';

Habit _habit(List<String?> labels) => Habit(
  id: 'h1758000000000001',
  name: 'Leer todos los días',
  symbol: 'rueda',
  slot: 0,
  createdAt: DateTime(2026, 3, 1),
  character: TownCharacter.all.first.order,
  pieces: [
    for (var i = 0; i < labels.length; i++)
      Piece(
        index: i,
        placedAt: DateTime(2026, 3, 1).add(Duration(days: i)),
        label: labels[i],
      ),
  ],
);

/// Un pueblo de [n] piezas, una por día, con su crónica escrita: el que hace
/// falta para que haya obras rematadas y calendario.
Habit _pueblo(int n) {
  final start = DateTime(2026, 1, 8, 20);
  final h = Habit(
    id: 'h1758000000000009',
    name: 'Leer todos los días',
    symbol: 'rueda',
    slot: 0,
    createdAt: start,
    character: TownCharacter.all.first.order,
    pieces: [
      for (var i = 0; i < n; i++)
        Piece(
          index: i,
          placedAt: start.add(Duration(days: i)),
        ),
    ],
  );
  h.chronicle.addAll(
    TownPlan.of(h.place, seed: h.townSeed).chronicleFor(n, const []),
  );
  return h;
}

Future<void> _open(WidgetTester tester, Habit h) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LegendsBook(habit: h, theme: UiTheme(Palette.forMoment(13, 1.0))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('el libro del atril', () {
    testWidgets('con las leyendas de este pueblo y ninguna más', (
      tester,
    ) async {
      await _open(
        tester,
        _habit(['Leí treinta páginas', null, 'Corrí', null, 'Hoy costó']),
      );
      expect(find.text('Leí treinta páginas'), findsOneWidget);
      expect(find.text('Corrí'), findsOneWidget);
      expect(find.text('Hoy costó'), findsOneWidget);
      // Las piezas sin leyenda no dejan renglón: un libro de la bitácora no es
      // un registro de asistencia.
      expect(find.text('Leer todos los días'), findsWidgets);
    });

    testWidgets('un pueblo sin nada escrito abre igual y lo dice', (
      tester,
    ) async {
      await _open(tester, _habit([null, null, null]));
      expect(find.textContaining('nada escrito'), findsOneWidget);
      // Y no hay a dónde pasar: un libro de dos páginas tiene una hoja.
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('se pasa la hoja, y se vuelve', (tester) async {
      await _open(tester, _habit(List.filled(60, 'Corrí cinco kilómetros')));
      expect(find.text('1 / 1'), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 / '), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 / '), findsOneWidget);
    });

    testWidgets('y no se pasa más allá del final ni más acá del principio', (
      tester,
    ) async {
      await _open(tester, _habit(['Corrí']));
      // Con una sola leyenda hay portada y una página: un solo par abierto.
      expect(find.text('1 / 1'), findsOneWidget);
      // Las flechas están apagadas, y tocarlas no rompe nada.
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('el gesto hace lo mismo que el botón', (tester) async {
      await _open(tester, _habit(List.filled(60, 'Escribí dos páginas')));
      await tester.drag(find.byType(LegendsBook), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 / '), findsOneWidget);
    });

    // **Por delante, no por detrás.** Girar media vuelta sobre el lomo lleva
    // la hoja de un lado al otro con cualquiera de los dos signos: el ancho va
    // con el coseno y sale igual. Lo que cambia de signo es la profundidad, y
    // con el signo equivocado el canto libre se hunde por detrás del libro y
    // reaparece por el otro lado, que es lo que se veía en el teléfono.
    //
    // Se mide por el tamaño: lo que está cerca se ve más grande. Si el canto
    // que se levanta viene hacia quien mira, su lado se proyecta más alto que
    // el del lomo, que se queda en el plano del papel.
    testWidgets('la hoja pasa por delante del libro, no por detrás', (
      tester,
    ) async {
      for (final adelante in [true, false]) {
        await _open(tester, _habit(List.filled(60, 'Corrí cinco kilómetros')));
        if (!adelante) {
          // Para poder ir hacia atrás hay que estar en la segunda hoja.
          await tester.tap(find.byIcon(Icons.chevron_right_rounded));
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.byIcon(
            adelante ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
          ),
        );
        // Un fotograma para que arranque el giro, y otro a un tercio de
        // vuelta, que es donde el canto está más levantado.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        final hoja = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('cara')),
        );
        final w = hoja.size.width, h = hoja.size.height;
        Offset en(double x, double y) => hoja.localToGlobal(Offset(x, y));
        // El lomo es el eje del giro: adelante gira sobre su borde izquierdo,
        // atrás sobre el derecho.
        final xLomo = adelante ? 0.0 : w;
        final xLibre = adelante ? w : 0.0;
        final lomo = (en(xLomo, h) - en(xLomo, 0)).dy;
        final libre = (en(xLibre, h) - en(xLibre, 0)).dy;
        expect(
          libre,
          greaterThan(lomo * 1.02),
          reason: adelante
              ? 'la hoja se hunde al pasar hacia adelante '
                    '(canto $libre, lomo $lomo)'
              : 'y hacia atrás también ($libre contra $lomo)',
        );
        await tester.pumpAndSettle();
      }
    });

    testWidgets('las obras salen fechadas, y antes que las leyendas', (
      tester,
    ) async {
      // La bitácora fechaba cada pieza y no fechaba las obras, que es lo que
      // uno recuerda. Van delante de las leyendas porque son los años y las
      // leyendas son los días.
      await _open(tester, _pueblo(300));
      expect(find.byType(WorksCalendar), findsWidgets);
      expect(find.text('LAS OBRAS'), findsWidgets);
      expect(find.text('AÑO MMXXVI'), findsWidgets);
      expect(find.text('LEYENDAS'), findsNothing);
    });

    testWidgets('y cada una dice cuándo empezó, cuándo acabó y cuánto duró', (
      tester,
    ) async {
      // El calendario está dibujado —barras contra una regla de meses— así
      // que lo que se comprueba es lo que dice en palabras, que es lo mismo
      // que oye quien no ve la pantalla.
      final h = _pueblo(300);
      await _open(tester, h);
      final hoja = tester.widget<WorksCalendar>(
        find.byType(WorksCalendar).first,
      );
      final primera = hoja.page.spans.first;
      expect(hoja.dicho, contains(primera.name));
      expect(
        hoja.dicho,
        contains('del ${primera.began.day} de '),
        reason: hoja.dicho,
      );
      expect(hoja.dicho, contains('días.'), reason: hoja.dicho);
      // Y las fechas son las de las piezas de esa obra, no las de otra.
      expect(primera.began, h.pieces[primera.from].placedAt);
    });

    testWidgets('un pueblo que no remató nada todavía no tiene calendario', (
      tester,
    ) async {
      // Una barra empezada no es un calendario, y una sección para eso es una
      // sección vacía con adorno.
      await _open(tester, _pueblo(3));
      expect(find.byType(WorksCalendar), findsNothing);
    });

    // Ésta es la que importa y es la que falló tres veces mientras se
    // escribía: las leyendas las escribe el usuario, así que no hay un alto de
    // tanteo que valga. Si la cuenta de lo que cabe no se mide de verdad, la
    // última de cada página se sale por abajo — y una página de papel que deja
    // ver lo que se sale de ella no es una página.
    testWidgets('ninguna página se desborda, escriba lo que escriba', (
      tester,
    ) async {
      final largas = [
        'Corrí',
        'a',
        'Leí treinta páginas del libro de los cátaros antes de dormir, '
            'que es lo que me había propuesto y no había conseguido en '
            'todo el mes, y encima me gustó',
        'Salí a caminar con mi hermana hasta el puente viejo',
        '  ',
        'Media hora de guitarra, escalas y nada más',
        'Ω' * 120,
        'Hoy costó pero fui igual',
      ];
      for (final size in [
        const Size(320, 640),
        const Size(360, 780),
        const Size(412, 915),
        const Size(600, 480),
      ]) {
        // Y un pueblo de tres años, que es el que llena el calendario.
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3.0;
        await _open(tester, _pueblo(900));
        for (var k = 0; k < 6; k++) {
          expect(
            tester.takeException(),
            isNull,
            reason: 'el calendario se desbordó en $size, hoja $k',
          );
          if (find.byIcon(Icons.chevron_right_rounded).evaluate().isEmpty) {
            break;
          }
          await tester.tap(find.byIcon(Icons.chevron_right_rounded));
          await tester.pumpAndSettle();
        }
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);
        await _open(tester, _habit([...largas, ...largas, ...largas]));
        for (var k = 0; k < 4; k++) {
          expect(
            tester.takeException(),
            isNull,
            reason: 'una página se desbordó en $size, hoja $k',
          );
          if (find.byIcon(Icons.chevron_right_rounded).evaluate().isEmpty) {
            break;
          }
          await tester.tap(find.byIcon(Icons.chevron_right_rounded));
          await tester.pumpAndSettle();
        }
      }
    });
  });
}
