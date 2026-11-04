import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/model/habit.dart';
import 'package:towny/model/piece.dart';
import 'package:towny/ui/rest_sheet.dart';
import 'package:towny/ui/style.dart';

void main() {
  testWidgets('se puede dormir el pueblo la cantidad de días que se quiera', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    DateTime? hasta;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RestSheet(
              habit: Habit(
                id: 'h',
                name: 'Leer',
                symbol: 'book',
                slot: 0,
                createdAt: DateTime.now(),
              ),
              theme: UiTheme(Palette.forMoment(13)),
              onRest: (d) => hasta = d,
            ),
          ),
        ),
      ),
    );
    final otra = find.text('Otra cantidad de días');
    await tester.ensureVisible(otra);
    await tester.pumpAndSettle();
    await tester.tap(otra);
    await tester.pumpAndSettle();
    // En la línea de la opción y entre los botones.
    expect(find.text('3 días'), findsNWidgets(2));
    final mas = find.byIcon(Icons.add);
    await tester.ensureVisible(mas);
    await tester.pumpAndSettle();
    await tester.tap(mas);
    await tester.tap(mas);
    await tester.pumpAndSettle();
    expect(find.text('5 días'), findsNWidgets(2));
    final boton = find.textContaining('Que duerma hasta el');
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(hasta, dayStart(DateTime.now().add(const Duration(days: 6))));
    expect(tester.takeException(), isNull);
  });
}
