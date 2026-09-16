import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';
import 'package:la_muralla/ui/legends_book.dart';
import 'package:la_muralla/ui/style.dart';

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
