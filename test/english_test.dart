import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/bandos.dart';
import 'package:towny/data/character.dart';
import 'package:towny/data/demo.dart';
import 'package:towny/data/doings.dart';
import 'package:towny/data/folknames.dart';
import 'package:towny/data/gossip.dart';
import 'package:towny/data/landmarks.dart';
import 'package:towny/data/symbols.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/season.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/l10n/en_landmarks.dart';
import 'package:towny/l10n/en_regions.dart';
import 'package:towny/l10n/en_symbols.dart';
import 'package:towny/l10n/lang.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/board.dart';
import 'package:towny/model/findings.dart';
import 'package:towny/model/notice.dart';
import 'package:towny/model/pledge.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/adrift_sheet.dart';
import 'package:towny/ui/backup_sheet.dart';
import 'package:towny/ui/cadence_sheet.dart';
import 'package:towny/ui/choice_sheet.dart';
import 'package:towny/ui/debug_sheet.dart';
import 'package:towny/ui/first_run.dart';
import 'package:towny/ui/habits_sheet.dart';
import 'package:towny/ui/home_screen.dart';
import 'package:towny/ui/notice_board.dart';
import 'package:towny/ui/rest_sheet.dart';
import 'package:towny/ui/settings_sheet.dart';
import 'package:towny/ui/style.dart';
import 'package:towny/ui/unlock_sheet.dart';

/// La app entera en inglés, y nada de castellano colado.
///
/// Dos clases de comprobación. Que **no falte nada** en los catálogos —una
/// obra nueva sin su nombre inglés saldría en castellano en mitad de una app
/// en inglés, y eso no lo ve nadie hasta que lo ve alguien—. Y que lo que se
/// enseña **no tenga castellano**: se abren las pantallas en inglés y se lee
/// todo el texto que pintan.
///
/// «Castellano» es lo que lo delata: una tilde, una eñe, un signo de apertura,
/// o una de las palabras que en inglés no existen y en castellano están en
/// cada frase.
final RegExp _castellano = RegExp(
  r'[áéíóúñÁÉÍÓÚÑ¿¡]|\b(el|los|las|del|de|la|que|y|pueblo|pueblos|pieza|'
  r'piezas|día|días|tu|tus|hoy|ayer|semana|semanas|para|por|con|una|hábito|'
  r'hábitos|nada|más|sin|obra|tablón)\b',
  caseSensitive: false,
);

void _sinCastellano(String texto, String donde) {
  final m = _castellano.firstMatch(texto);
  expect(
    m,
    isNull,
    reason: '$donde dice «$texto» — «${m?.group(0)}» es castellano',
  );
}

/// Todo el texto que hay en pantalla ahora mismo.
List<String> _leer(WidgetTester tester) => [
  for (final w in tester.widgetList<Text>(find.byType(Text)))
    w.data ?? w.textSpan?.toPlainText() ?? '',
  for (final w in tester.widgetList<RichText>(find.byType(RichText)))
    w.text.toPlainText(),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setSoundOff(true);
    lang = Lang.en;
  });
  tearDown(() => lang = Lang.es);

  group('no falta nada en los catálogos', () {
    test('todas las obras', () {
      for (final l in landmarks) {
        expect(landmarksEn[l.id], isNotNull, reason: l.id);
        _sinCastellano(l.name, 'el nombre de ${l.id}');
        _sinCastellano(l.blurb, 'la frase de ${l.id}');
      }
    });

    test('todas las comarcas', () {
      for (final c in TownCharacter.all) {
        expect(regionsEn[c.order], isNotNull, reason: c.regionEs);
        _sinCastellano(c.region, 'el nombre de ${c.regionEs}');
        _sinCastellano(c.blurb, 'cómo es ${c.regionEs}');
        _sinCastellano(c.suits, 'para qué va ${c.regionEs}');
      }
    });

    test('todas las marcas de hábito', () {
      expect(habitSymbolNamesEn.keys.toSet(), habitSymbols.toSet());
      for (final s in habitSymbols) {
        _sinCastellano(habitSymbolNames[s]!, 'la marca $s');
      }
    });

    test('todos los bandos, en el mismo orden', () {
      final ingles = bandos;
      lang = Lang.es;
      final castellano = bandos;
      lang = Lang.en;
      expect(ingles.length, castellano.length);
      for (var i = 0; i < ingles.length; i++) {
        _sinCastellano(ingles[i].$1, 'el bando $i');
        _sinCastellano(ingles[i].$2, 'el renglón del bando $i');
      }
      for (final n in villageNotices(DateTime(2026, 3, 1), town: 0)) {
        _sinCastellano('${n.said} ${n.because}', 'el tablón de hoy');
      }
    });

    test('lo que hace la gente, sus apodos y las casas', () {
      for (final d in Doing.all) {
        _sinCastellano(d.name, 'lo que hace ${d.id}');
      }
      for (var seed = 0; seed < 600; seed++) {
        // El nombre de pila se queda: es un nombre. Lo que va detrás no.
        final resto = folkName(seed).split(' ').skip(1).join(' ');
        _sinCastellano(resto, 'el apodo del vecino $seed');
      }
      for (final k in BuildingKind.values) {
        _sinCastellano(buildingName[k]!, 'la casa $k');
      }
      for (final t in [0.09, 0.34, 0.59, 0.84]) {
        _sinCastellano(Season(t).name, 'la estación $t');
      }
    });
  });

  group('el tablón dice todo en inglés', () {
    test('el valle de muestra, nota por nota', () {
      final valle = demoValley();
      for (final h in valle) {
        final notas = <Notice>[
          ...noticesFor(
            h,
            others: valle,
            underway: landmarks.first.name,
            left: 4,
          ),
          emptyNotice(h),
        ];
        expect(notas.length, greaterThan(3), reason: h.name);
        for (final n in notas) {
          _sinCastellano(n.said, 'el título de una nota de ${h.name}');
          _sinCastellano(n.because, 'el cuerpo de una nota de ${h.name}');
          if (n.more != null) _sinCastellano(n.more!, 'el «más» de ${h.name}');
          for (final t in n.ticks) {
            _sinCastellano(t, 'un pie de barra de ${h.name}');
          }
        }
      }
    });

    test('el plan, la identidad y el ritmo', () {
      _sinCastellano(vowLine('Reading', 22, 'bed')!, 'el plan');
      _sinCastellano(vowLine('Reading', 7, 'at the gym')!, 'el plan');
      for (var h = 0; h < 24; h++) {
        _sinCastellano(hourSaid(h), 'la hora $h');
      }
      expect(
        identityWhole('who reads every day'),
        'someone who reads every day',
      );
      // Una identidad escrita en castellano sigue abriéndose bien.
      expect(identityTail('alguien sabio'), 'sabio');
      for (var n = 1; n <= 7; n++) {
        _sinCastellano(rhythmSaid(n), 'el ritmo $n');
      }
    });
  });

  group('las pantallas, en inglés', () {
    final t = UiTheme(Palette.forMoment(13));

    Future<Store> valle() async {
      final store = Store();
      await store.load();
      store.renameHabit(0, name: 'Reading', symbol: 'libro');
      for (var i = 0; i < 30; i++) {
        store.lay(store.habit, DateTime.now().subtract(Duration(days: 40 - i)));
      }
      return store;
    }

    Future<void> abrir(
      WidgetTester tester,
      Widget hoja, {
      Size size = const Size(420, 3000),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: hoja)),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    void sinCastellanoEnPantalla(WidgetTester tester, String cual) {
      final textos = _leer(tester);
      expect(textos, isNotEmpty, reason: cual);
      for (final x in textos) {
        if (x == 'Reading') continue;
        _sinCastellano(x, cual);
      }
    }

    testWidgets('los ajustes', (tester) async {
      final store = await valle();
      tester.view.physicalSize = const Size(420, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSheet(store: store, theme: t),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // «Español» es el nombre del idioma, dicho en su idioma: es lo único de
      // castellano que tiene que estar.
      for (final x in _leer(tester)) {
        if (x == 'Español' || x.contains('IDIOMA')) continue;
        _sinCastellano(x, 'los ajustes');
      }
    });

    testWidgets('los ajustes de desarrollo', (tester) async {
      final store = await valle();
      await Appearance.instance.setFakeHour(true);
      await Appearance.instance.setFakeSeason(true);
      tester.view.physicalSize = const Size(420, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSheet(store: store, theme: t, dev: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Developer'), findsOneWidget);
      for (final x in _leer(tester)) {
        _sinCastellano(x, 'los ajustes de desarrollo');
      }
      // Como estaban, y que se escriba ya: guardar espera a que se suelte el
      // dedo, y un reloj pendiente al terminar es un test roto.
      await Appearance.instance.setFakeHour(false);
      await Appearance.instance.setFakeSeason(false);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('la hoja del hábito', (tester) async {
      final store = await valle();
      await abrir(tester, HabitsSheet(store: store, theme: t));
      sinCastellanoEnPantalla(tester, 'la hoja del hábito');
    });

    testWidgets('las hojas de pausar, el candado, la deriva y el ritmo', (
      tester,
    ) async {
      final store = await valle();
      final h = store.habit;
      await abrir(tester, RestSheet(habit: h, theme: t, onRest: (_) {}));
      sinCastellanoEnPantalla(tester, 'pausar');
      await abrir(tester, UnlockSheet(store: store, theme: t));
      sinCastellanoEnPantalla(tester, 'el candado');
      await abrir(
        tester,
        AdriftSheet(
          habit: h,
          theme: t,
          days: 9,
          onKeep: () {},
          onShrink: () {},
          onRest: () {},
          onDrop: () {},
        ),
      );
      sinCastellanoEnPantalla(tester, 'la deriva');
      await abrir(tester, CadenceSheet(habit: h, theme: t, onPick: (_) {}));
      sinCastellanoEnPantalla(tester, 'el ritmo');
      await abrir(tester, BackupSheet(store: store, theme: t));
      sinCastellanoEnPantalla(tester, 'tus datos');
      await abrir(tester, DebugSheet(store: store, theme: t));
      sinCastellanoEnPantalla(tester, 'el pueblo a futuro');
    });

    testWidgets('la pantalla de inicio y el tablón', (tester) async {
      final store = await valle();
      store.justFounded = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: HomeScreen(store: store)));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      sinCastellanoEnPantalla(tester, 'la pantalla de inicio');

      final demo = demoValley();
      await tester.pumpWidget(
        MaterialApp(
          home: NoticeBoardScreen(valley: demo, habit: demo.first, theme: t),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      for (final x in _leer(tester)) {
        _sinCastellano(x, 'el tablón');
      }
      await tester.pumpWidget(const SizedBox());
      // Los avisos de la pantalla de inicio se van solos a los pocos segundos.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('la tarjeta de elegir', (tester) async {
      await abrir(
        tester,
        ChoiceSheet(
          options: [landmarks[3], landmarks[40]],
          place: TownCharacter.all.first,
          theme: t,
          onPick: (_) {},
        ),
        size: const Size(420, 900),
      );
      sinCastellanoEnPantalla(tester, 'la tarjeta de elegir');
    });

    testWidgets('la primera vez, de punta a punta', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> asentar() async {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
      }

      Future<void> siguiente() async {
        await tester.ensureVisible(find.text('NEXT'));
        await tester.pump();
        await tester.tap(find.text('NEXT'));
        await asentar();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: FirstRun(
            onDone: (n, s, {required character, why, identity}) {},
          ),
        ),
      );
      await asentar();
      sinCastellanoEnPantalla(tester, 'la bienvenida');
      await tester.tap(find.text('FOUND MY TOWN'));
      await asentar();
      sinCastellanoEnPantalla(tester, 'el nombre');
      await tester.enterText(find.byType(TextField).first, 'Reading');
      await tester.pump();
      await siguiente();
      sinCastellanoEnPantalla(tester, 'la comarca');
      await siguiente();
      sinCastellanoEnPantalla(tester, 'el motivo');
      await tester.enterText(find.byType(TextField).first, 'to sleep better');
      await tester.pump();
      await siguiente();
      sinCastellanoEnPantalla(tester, 'quién sos');
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('elegir el idioma se guarda, y sin elegir manda el teléfono', () async {
    // Sin elegir y fuera de la app de verdad: castellano, que es en lo que
    // están escritos los tests.
    expect(Appearance.instance.languageChosen, isFalse);
    expect(Appearance.instance.language, Lang.es);
    await Appearance.instance.setLanguage(Lang.en);
    expect(lang, Lang.en);
    expect(tr('Hola', 'Hello'), 'Hello');
    // Y lo guardado se lee al volver a abrir.
    SharedPreferences.setMockInitialValues({
      'pueblo_sound_v1': ['lang=en'],
    });
    lang = Lang.es;
    await Appearance.instance.load();
    expect(Appearance.instance.language, Lang.en);
    expect(Appearance.instance.languageChosen, isTrue);
    expect(lang, Lang.en);
    await Appearance.instance.setLanguage(null);
    expect(Appearance.instance.languageChosen, isFalse);
    expect(Lang.ofCode('es_AR'), Lang.es);
    expect(Lang.ofCode('en_GB'), Lang.en);
    expect(Lang.ofCode('fr'), Lang.en);
  });
}
