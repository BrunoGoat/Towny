import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/model/habit.dart';
import 'package:towny/model/piece.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/style.dart';
import 'package:towny/ui/unlock_sheet.dart';

/// La hoja del candado, a disco: un valle de dos pueblos con el primero en
/// pausa ahora, y otro con los dos despiertos y días de pausa ya pasados.
///
///   flutter test tool/unlock_shot_test.dart --dart-define=OUT=/tmp/candado
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
  await carga('EBGaramond', ['assets/fonts/EBGaramond.ttf']);
  await carga('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
}

/// Un valle de dos: «Leer» con piezas en [leer] días atrás y «Correr» en
/// [correr], y las pausas que se le pongan después.
/// Un hábito de prueba: fundado hace [edad] días, con piezas los días
/// [dias] (días antes de hoy), a [ritmo] por semana, y las pausas [pausas]
/// (desde, hasta, en días antes de hoy; negativo es en el futuro).
Habit _pueblo(
  String id,
  String nombre,
  String marca,
  int slot, {
  required int edad,
  required List<int> dias,
  double? ritmo,
  List<(int, int)> pausas = const [],
}) {
  final hoy = DateTime.now();
  DateTime dia(int atras, [int hora = 9]) =>
      DateTime(hoy.year, hoy.month, hoy.day - atras, hora);
  final orden = [...dias]..sort((a, b) => b.compareTo(a));
  return Habit(
    id: id,
    name: nombre,
    symbol: marca,
    slot: slot,
    createdAt: dia(edad, 8),
    perWeek: ritmo,
    pieces: [
      for (final (i, d) in orden.indexed) Piece(index: i, placedAt: dia(d)),
    ],
    rests: [for (final (a, b) in pausas) Rest(dia(a, 8), dia(b, 18)).encode()],
  );
}

Future<Store> _valle(List<int> leer, List<int> correr) async {
  SharedPreferences.setMockInitialValues({});
  await Appearance.instance.load();
  await Appearance.instance.setFreeHabits(true);
  final s = Store();
  await s.load();
  s.renameHabit(0, name: 'Leer', symbol: 'book');
  s.addHabit('Correr', 'run');
  final hoy = DateTime.now();
  // Fundados hace dos meses: si no, los días de la cuenta serían de antes de
  // que existieran.
  for (var i = 0; i < s.habits.length; i++) {
    s.habits[i] = Habit.fromJson({
      ...s.habits[i].toJson(),
      'c': DateTime(hoy.year, hoy.month - 2, hoy.day).millisecondsSinceEpoch,
    });
  }
  for (final (h, dias) in [(s.habits[0], leer), (s.habits[1], correr)]) {
    for (final d in dias.reversed) {
      s.lay(h, DateTime(hoy.year, hoy.month, hoy.day - d, 9));
    }
  }
  await Appearance.instance.setFreeHabits(false);
  return s;
}

final _key = GlobalKey();

Future<void> _pon(WidgetTester tester, Store s, {double alto = 844}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(390, alto), devicePixelRatio: 3),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto'),
        home: Scaffold(
          // Algo detrás que se parezca al valle, para que el vidrio se vea
          // como vidrio: cielo, montes y prado.
          body: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF8FB3DE),
                        Color(0xFFC9D8E4),
                        Color(0xFF8C9A6E),
                        Color(0xFF5E7A3E),
                        Color(0xFFB79A6A),
                      ],
                      stops: [0, 0.35, 0.45, 0.7, 1],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: RepaintBoundary(
                  key: _key,
                  child: UnlockSheet(
                    store: s,
                    theme: UiTheme(Palette.forMoment(13)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const out = String.fromEnvironment('OUT', defaultValue: '/tmp/candado');

  Future<void> foto(
    WidgetTester tester,
    Store s,
    String nombre, {
    bool pump = true,
  }) async {
    if (pump) await _pon(tester, s);
    final b = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final img = await b.toImage(pixelRatio: 2.5);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$nombre.png').writeAsBytesSync(png!.buffer.asUint8List());
      img.dispose();
    });
    // ignore: avoid_print
    print('escrito $out/$nombre.png');
  }

  testWidgets('el candado', (tester) async {
    Directory(out).createSync(recursive: true);
    await tester.runAsync(_letras);
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final hoy = DateTime.now();
    DateTime dia(int atras, int hora) =>
        DateTime(hoy.year, hoy.month, hoy.day - atras, hora);

    // El caso de la pregunta: «Leer» llegó y se pausó ayer por una semana;
    // «Correr» va por la mitad.
    final s = await tester.runAsync(
      () => _valle([2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], [0, 1, 3, 5, 6]),
    );
    s!.habits[0].rests.add(Rest(dia(1, 8), dia(-6, 8)).encode());
    await foto(tester, s, '1-uno-en-pausa');
    // Y tocando cada uno, su detalle.
    await tester.tap(find.text('Correr'));
    await tester.pumpAndSettle();
    await foto(tester, s, '1b-detalle', pump: false);

    // Los dos despiertos, y «Leer» con dos días de pausa ya pasados: la
    // cuenta se los salta.
    final t = await tester.runAsync(
      () =>
          _valle([0, 1, 4, 5, 6, 7, 8, 9, 10, 11], [0, 1, 2, 3, 4, 5, 6, 7, 9]),
    );
    t!.habits[0].rests.add(Rest(dia(3, 8), dia(1, 18)).encode());
    await foto(tester, t, '2-pausa-pasada');

    // Con un solo pueblo: el segundo.
    final u = await tester.runAsync(() => _valle([0, 1, 3, 4, 6, 8], [0]));
    u!.removeHabit(1);
    await foto(tester, u, '3-un-pueblo');

    // Cuatro pueblos camino al quinto, con todo a la vista: uno que llegó,
    // uno a medio camino de tres por semana, uno en pausa ahora, y uno nuevo
    // de dos por semana con su detalle abierto —días antes de fundarlo, días
    // en pausa y una pieza de más esa semana—.
    final v = u..habits.clear();
    v.habits.addAll([
      _pueblo(
        'a',
        'Leer',
        'book',
        0,
        edad: 90,
        dias: [0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 13],
        ritmo: 7,
      ),
      _pueblo('b', 'Correr', 'run', 1, edad: 70, dias: [1, 4, 8, 12], ritmo: 3),
      _pueblo(
        'c',
        'Meditar',
        'lotus',
        2,
        edad: 60,
        dias: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
        ritmo: 7,
        pausas: [(2, -5)],
      ),
      _pueblo(
        'd',
        'Guitarra',
        'lute',
        3,
        edad: 20,
        dias: [1, 2, 3, 9, 16],
        ritmo: 2,
        pausas: [(13, 11)],
      ),
    ]);
    await Appearance.instance.setFreeHabits(false);
    tester.view.physicalSize = const Size(390 * 3, 1300 * 3);
    await tester.pumpWidget(const SizedBox());
    await _pon(tester, v, alto: 1300);
    await tester.tap(find.text('Guitarra'));
    await tester.pumpAndSettle();
    await foto(tester, v, '4-cuatro-pueblos', pump: false);
  });
}
