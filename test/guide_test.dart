import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/advice.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/model/advice_book.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/habit.dart';
import 'package:towny/model/piece.dart';
import 'package:towny/model/sage_talk.dart';
import 'package:towny/model/store.dart';
import 'package:towny/model/stumble.dart';
import 'package:towny/ui/sage_screen.dart';
import 'package:towny/ui/style.dart';

/// El consejero como guía: los tropiezos, tus propias palabras de vuelta, el
/// plan de «cuando… voy a…», los votos y la charla de la semana.
void main() {
  final hoy = DateTime(2026, 3, 18, 15); // un miércoles

  /// Un hábito diario con piezas los días [hace] (días antes de hoy).
  Habit diario(List<int> hace, {String? why}) {
    final h = Habit(
      id: 'h1',
      name: 'Correr',
      symbol: 'run',
      slot: 1,
      createdAt: hoy.subtract(const Duration(days: 40)),
      perWeek: 7,
      why: why,
    );
    final dias = [...hace]..sort((a, b) => b.compareTo(a));
    for (final (i, d) in dias.indexed) {
      h.pieces.add(
        Piece(
          index: i,
          placedAt: DateTime(hoy.year, hoy.month, hoy.day - d, 9),
        ),
      );
    }
    return h;
  }

  group('tropiezos', () {
    test('un día en blanco de un hábito diario es un tropiezo', () {
      final h = diario([5, 4, 3, 2]);
      expect(stumbleDue(h, at: hoy), DateTime(2026, 3, 17));
    });

    test('hoy todavía está a tiempo: no cuenta', () {
      final h = diario([4, 3, 2, 1]);
      expect(stumbleDue(h, at: hoy), isNull);
    });

    test('contra tu ritmo: dos por semana aguanta tres días en blanco', () {
      final h = diario([12, 8, 4])..perWeek = 2;
      expect(stumbleDue(h, at: hoy), isNull);
      final h2 = diario([16, 12, 8, 5])..perWeek = 2;
      expect(stumbleDue(h2, at: hoy), DateTime(2026, 3, 17));
    });

    test('con poca historia no pregunta nada', () {
      expect(stumbleDue(diario([5, 4]), at: hoy), isNull);
    });

    test('una vez por hueco', () {
      final h = diario([5, 4, 3, 2]);
      h.stumbles.add(
        StumbleEntry(DateTime(2026, 3, 17), Stumble.tired).encode(),
      );
      expect(stumbleDue(h, at: hoy), isNull);
      // Y el hueco siguiente vuelve a preguntar.
      h.pieces.add(Piece(index: 4, placedAt: DateTime(2026, 3, 18, 8)));
      expect(stumbleDue(h, at: DateTime(2026, 3, 20, 10)), isNotNull);
    });

    test('el patrón sale a la tercera, y sólo si se repite', () {
      final h = diario([1]);
      expect(stumblePattern([h]).cause, isNull);
      for (final (d, c) in [
        (DateTime(2026, 3, 2), Stumble.tired), // lunes
        (DateTime(2026, 3, 9), Stumble.tired), // lunes
        (DateTime(2026, 3, 12), Stumble.forgot),
      ]) {
        h.stumbles.add(StumbleEntry(d, c).encode());
      }
      final p = stumblePattern([h]);
      expect(p.cause, Stumble.tired);
      expect(p.weekday, DateTime.monday);
    });
  });

  test('lo nuevo viaja en la copia', () {
    final h = diario([3, 2, 1])
      ..planIf = 'termine de cenar'
      ..planThen = 'leer una página'
      ..identityAt = DateTime(2026, 2, 1)
      ..stumbles.add(StumbleEntry(DateTime(2026, 3, 1), Stumble.mood).encode());
    final otra = Habit.fromJson(h.toJson());
    expect(otra.planIf, 'termine de cenar');
    expect(otra.planThen, 'leer una página');
    expect(otra.identityAt, DateTime(2026, 2, 1));
    expect(stumblesOf(otra).single.cause, Stumble.mood);
  });

  test('votos: una pieza, un voto, desde que se escribió la frase', () {
    final h = diario([10, 6, 3, 1])..identity = 'alguien que corre';
    expect(identityVotes(h), 4);
    h.identityAt = DateTime(hoy.year, hoy.month, hoy.day - 5);
    expect(identityVotes(h), 2);
    // Al mes, se pregunta si sigue siendo la tuya.
    expect(identityDue([h], at: hoy), isNull);
    h.identityAt = hoy.subtract(const Duration(days: 31));
    expect(identityDue([h], at: hoy), h);
  });

  group('en la pantalla', () {
    Future<Store> abrir(WidgetTester tester, Habit Function() hace) async {
      SharedPreferences.setMockInitialValues({});
      late Store store;
      await tester.runAsync(() async {
        await Appearance.instance.load();
        await Appearance.instance.setSoundOff(true);
        store = Store();
        await store.load();
      });
      store.habits[0] = hace();
      AdviceBook.instance.forget();
      AdviceBook.instance.meet();
      AdviceBook.instance.setGoal(store.habit.id, AdviceGoal.quit);
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: SageScreen(store: store, theme: UiTheme(Palette.forMoment(13))),
        ),
      );
      await _espera(tester);
      return store;
    }

    testWidgets('el tropiezo: qué se interpuso, tu motivo, y un plan', (
      tester,
    ) async {
      final ahora = DateTime.now();
      final store = await abrir(tester, () {
        final h = Habit(
          id: 'h0',
          name: 'Fumar',
          symbol: 'run',
          slot: 1,
          createdAt: ahora.subtract(const Duration(days: 20)),
          perWeek: 7,
          why: 'para respirar mejor',
        );
        for (final (i, d) in [6, 5, 4, 3].indexed) {
          h.pieces.add(
            Piece(
              index: i,
              placedAt: DateTime(ahora.year, ahora.month, ahora.day - d, 9),
            ),
          );
        }
        return h;
      });
      expect(find.textContaining('¿Qué se interpuso?'), findsOneWidget);
      await _toca(tester, find.text('Tentación'));
      await _espera(tester);
      expect(stumblesOf(store.habit).single.cause, Stumble.tempted);
      // Lo que escribiste, devuelto.
      expect(find.textContaining('«para respirar mejor»'), findsOneWidget);
      await _toca(tester, find.textContaining('«para respirar mejor»'));
      await _espera(tester);
      await _toca(tester, find.text('Trazar un plan'));
      await _espera(tester);
      await tester.enterText(find.byType(TextField), 'me aburra en el sillón');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _espera(tester);
      await tester.enterText(find.byType(TextField), 'salir a caminar');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _espera(tester);
      expect(store.habit.planIf, 'me aburra en el sillón');
      expect(store.habit.planThen, 'salir a caminar');
      expect(
        find.textContaining('Cuando me aburra en el sillón, voy a salir'),
        findsOneWidget,
      );
      // Y no vuelve a preguntar por el mismo hueco.
      expect(stumbleDue(store.habit), isNull);
    });

    testWidgets('ese día no tocaba: se corrige el ritmo, sin caída', (
      tester,
    ) async {
      final ahora = DateTime.now();
      final store = await abrir(tester, () {
        final h = Habit(
          id: 'h0',
          name: 'Nadar',
          symbol: 'run',
          slot: 1,
          createdAt: ahora.subtract(const Duration(days: 20)),
          perWeek: 7,
        );
        for (final (i, d) in [6, 5, 4, 3].indexed) {
          h.pieces.add(
            Piece(
              index: i,
              placedAt: DateTime(ahora.year, ahora.month, ahora.day - d, 9),
            ),
          );
        }
        return h;
      });
      await _toca(tester, find.text('Ese día no tocaba'));
      await _espera(tester);
      expect(find.textContaining('el tropiezo fue mío'), findsOneWidget);
      await _toca(tester, find.text('5 veces por semana'));
      await _espera(tester);
      expect(store.habit.perWeek, 5);
      expect(stumblesOf(store.habit).single.cause, Stumble.notDue);
      // Y no entra en los patrones.
      expect(stumblePattern(store.habits).cause, isNull);
    });

    testWidgets('la identidad: sigue siendo, o cambió', (tester) async {
      final ahora = DateTime.now();
      final store = await abrir(tester, () {
        final h = Habit(
          id: 'h0',
          name: 'Leer',
          symbol: 'run',
          slot: 1,
          createdAt: ahora.subtract(const Duration(days: 45)),
          perWeek: 2,
          identity: 'alguien que lee',
        );
        h.pieces.add(Piece(index: 0, placedAt: ahora));
        return h;
      });
      expect(find.textContaining('querías ser «alguien que lee»'), findsOne);
      await _toca(tester, find.textContaining('querías ser «alguien que lee»'));
      await _espera(tester);
      expect(find.textContaining('un voto por esa persona'), findsOne);
      await _toca(tester, find.text('Ha cambiado'));
      await _espera(tester);
      await tester.enterText(find.byType(TextField), 'que aprende');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _espera(tester);
      expect(store.habit.identity, 'alguien que aprende');
      expect(identityDue(store.habits), isNull);
    });
  });
}

Future<void> _toca(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

Future<void> _espera(WidgetTester tester) async {
  for (var i = 0; i < 70; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
