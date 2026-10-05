import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/palette.dart';
import 'package:towny/engine/tones.dart';
import 'package:towny/model/store.dart';
import 'package:towny/ui/habit_bar.dart';
import 'package:towny/ui/habit_sigil.dart';
import 'package:towny/ui/habits_sheet.dart';
import 'package:towny/ui/hold_button.dart';
import 'package:towny/ui/overlays.dart';
import 'package:towny/ui/plan_picker.dart';
import 'package:towny/ui/style.dart';
import 'package:towny/ui/town_sign.dart';

/// Un teléfono estrecho y uno ancho: lo que se rompe en algo puesto sobre la
/// escena es que se salga por un costado, y eso depende del ancho.
const _pantallas = [Size(320, 640), Size(440, 950)];

/// Un nombre largo de verdad. Los hábitos de la gente no se llaman «Leer».
const _largo = 'Despertarse temprano sin excusas';

/// El campo de texto quiere un Material y sus localizaciones encima. En la app
/// se los pone el MaterialApp; aquí hay que ponerlos igual, o lo que falla es
/// el andamio y no el diseño.
Widget _marco(Size size, Widget child) => MediaQuery(
  data: MediaQueryData(
    size: size,
    padding: const EdgeInsets.only(top: 34, bottom: 22),
  ),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Material(
      color: const Color(0xFF7E9058),
      child: Stack(children: [Positioned.fill(child: child)]),
    ),
  ),
);

/// Que nada de lo que se escribe se salga de la pantalla.
///
/// Menos lo que va dentro de una lista que se desliza a lo largo —el reloj del
/// plan, el carrete de las marcas—, donde estar fuera de cuadro es lo normal:
/// una fila de veinticuatro horas no cabe en ningún teléfono y no tiene que
/// caber. Lo que sí se comprueba de esas listas es lo de siempre, porque la
/// lista misma es un hijo de la hoja como cualquier otro.
/// [abajo] en falso comprueba sólo los dos costados: es para lo que rueda, donde
/// que algo esté por debajo del filo no quiere decir que no se pueda leer.
void _dentro(
  WidgetTester tester,
  Size size,
  String quien, {
  bool abajo = true,
}) {
  final enCarrete = find
      .descendant(of: find.byType(ListView), matching: find.byType(Text))
      .evaluate()
      .toSet();
  for (final e in find.byType(Text).evaluate()) {
    if (enCarrete.contains(e)) continue;
    final box = e.renderObject! as RenderBox;
    final at = box.localToGlobal(Offset.zero);
    expect(
      at.dx,
      greaterThan(-1),
      reason: '$quien se sale por la izquierda en $size',
    );
    expect(
      at.dx + box.size.width,
      lessThan(size.width + 1),
      reason: '$quien se sale por la derecha en $size',
    );
    if (abajo) {
      expect(
        at.dy + box.size.height,
        lessThan(size.height + 1),
        reason: '$quien se sale por abajo en $size',
      );
    }
  }
}

void main() {
  _cuando();
  _pieles();
  _abajo();
  _arriba();
  testWidgets('el cartel del pueblo cabe y no se queda puesto', (tester) async {
    for (final size in _pantallas) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const vida = Duration(milliseconds: 1700);
      await tester.pumpWidget(
        _marco(
          size,
          TownSignOverlay(
            name: _largo,
            symbol: 'sol',
            theme: UiTheme(Palette.forMoment(13)),
            life: vida,
          ),
        ),
      );
      // A media entrada y ya entero: si algo se sale, se sale en uno de los dos.
      for (final ms in [90, 700]) {
        await tester.pump(Duration(milliseconds: ms));
        expect(tester.takeException(), isNull);
        _dentro(tester, size, 'el cartel');
      }
      // Y para el final de su vida se ha ido del todo, que es lo que se pidió:
      // que se desvanezca antes.
      await tester.pump(vida);
      final opacidad = tester.widgetList<Opacity>(find.byType(Opacity));
      expect(
        opacidad.every((o) => o.opacity < 0.02),
        isTrue,
        reason: 'el cartel sigue puesto cuando ya debería haberse ido',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('la tarjeta de una pieza cabe y dice cuál y cuándo', (
    tester,
  ) async {
    for (final size in _pantallas) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _marco(
          size,
          Center(
            child: StoneCard(
              theme: UiTheme(Palette.forMoment(13)),
              when: DateTime(2026, 9, 10, 8, 50),
              number: 1284,
              onWhen: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.text('PIEZA 1284'), findsOneWidget);
      expect(find.text('10 sep 2026 · 08:50'), findsOneWidget);
      // Y nada que escribir.
      expect(find.byType(TextField), findsNothing);
      _dentro(tester, size, 'la tarjeta');
      await tester.pumpWidget(const SizedBox());
    }
  });
}

void _cuando() {
  group('cuándo fue la última', () {
    // Lo que se lee arriba a la izquierda. Un «10 sep 21:44» cuando hoy es el
    // 10 de septiembre obliga a mirar el calendario para entender una cosa que
    // se sabe sola.
    final hoy = DateTime(2026, 9, 17, 22, 5);

    test('hoy y ayer se dicen con su nombre', () {
      expect(
        StoneCard.formatWhen(DateTime(2026, 9, 17, 21, 44), from: hoy),
        'hoy 21:44',
      );
      expect(
        StoneCard.formatWhen(DateTime(2026, 9, 17, 0, 3), from: hoy),
        'hoy 00:03',
      );
      expect(
        StoneCard.formatWhen(DateTime(2026, 9, 16, 7, 12), from: hoy),
        'ayer 07:12',
      );
    });

    test('y lo anterior lleva día y mes, con el año sólo si es otro', () {
      expect(
        StoneCard.formatWhen(DateTime(2026, 9, 10, 12, 23), from: hoy),
        '10 sep 12:23',
      );
      expect(
        StoneCard.formatWhen(DateTime(2025, 12, 31, 23, 59), from: hoy),
        '31 dic 2025 23:59',
      );
    });

    test('la medianoche de anoche es ayer y no hoy', () {
      // El corte es el día natural y no las veinticuatro horas: a las 22:05 de
      // hoy, algo puesto a las 23:50 de ayer hace dos horas y pico, pero fue
      // ayer y así se dice.
      expect(
        StoneCard.formatWhen(DateTime(2026, 9, 16, 23, 50), from: hoy),
        'ayer 23:50',
      );
    });
  });
}

void _pieles() {
  group('la hoja de un hábito', () {
    // Llegó a haber quince maneras de hacer esta hoja y quedó una: vidrio
    // ahumado sobre el pueblo, con la marca encima y el nombre debajo. Lo que
    // tiene que cumplir es lo mismo que cumplían las quince — caber en un
    // teléfono estrecho y en uno ancho, de día y de noche, y decirlo todo.
    testWidgets('cabe y lo dice todo, de día y de noche', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = Store();
      await store.load();
      store.renameHabit(store.active, name: _largo, symbol: store.habit.symbol);
      // Con todo escrito, que es la hoja más alta que puede haber: las líneas,
      // la frecuencia dicha y el plan. La hoja creció varios bloques de golpe
      // al escribirse el plan y la identidad, y en un teléfono de 320 se
      // salía por tres píxeles.
      store.pledgeHabit(
        store.active,
        hour: 22,
        place: 'en la mesa de la cocina',
        identity: 'alguien que se levanta temprano',
      );
      store.describeHabit(
        store.active,
        why: 'para tener más energía durante el día',
        floor: 'abrir el libro y leer una página',
      );
      store.setCadence(store.habit, 3);
      store.addHabit('Correr', 'carrera');
      store.active = 0;
      for (final size in _pantallas) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final hora in [13.0, 23.0]) {
          final t = UiTheme(Palette.forMoment(hora));
          await tester.pumpWidget(
            _marco(
              size,
              Align(
                alignment: Alignment.bottomCenter,
                child: HabitsSheet(store: store, theme: t),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 250));
          expect(
            tester.takeException(),
            isNull,
            reason: 'a las $hora en $size',
          );
          expect(find.text(_largo), findsOneWidget);
          expect(find.text('Eliminar este hábito'), findsOneWidget);
          // Con todo escrito, en un teléfono de 320 la hoja ya no cabe entera:
          // son los renglones tuyos, la frecuencia y el reloj del plan.
          // Por eso rueda, y lo que hay que exigirle entonces no es que quepa
          // sino que se pueda llegar a todo — se arrastra hasta el final y la
          // última fila tiene que quedar dentro de la pantalla.
          // La hoja mide lo que la pantalla porque rueda por dentro, así que
          // lo que dice si cabe es dónde acaba su última fila.
          final cabe =
              tester.getRect(find.text('Eliminar este hábito')).bottom <=
              size.height;
          _dentro(tester, size, 'la hoja', abajo: cabe);
          if (!cabe) {
            await tester.ensureVisible(find.text('Eliminar este hábito'));
            await tester.pump();
            final ultima = tester.getRect(find.text('Eliminar este hábito'));
            expect(
              ultima.bottom,
              lessThan(size.height + 1),
              reason: 'no se llega al final de la hoja en $size',
            );
            expect(ultima.top, greaterThan(-1), reason: 'se pasó de largo');
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    });

    /// Lo que el dueño de la app dijo al verla: «quedó bastante llena y con
    /// muchas cosas».
    ///
    /// Tenía razón y se podía medir. Con todo escrito eran 832 píxeles de hoja
    /// en un teléfono de 320 y 777 en uno de 390: en los dos casos la hoja
    /// entera o casi, y en el estrecho había que arrastrarla para llegar a
    /// pausar el pueblo. Siete secciones con siete títulos, de las cuales dos
    /// —el reloj de veinticuatro horas y el párrafo de la comarca— ocupaban
    /// trescientos píxeles para decir lo que ya decía la frase de al lado o lo
    /// que no se puede cambiar.
    ///
    /// Así que la regla es que **quepa sin rodar**, que es otra cosa que caber:
    /// la de antes cabía porque rodaba. Si vuelve a crecer, esto se rompe antes
    /// de que lo note alguien con un teléfono en la mano.
    testWidgets('con todo escrito cabe sin rodar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = Store();
      await store.load();
      store.renameHabit(store.active, name: _largo, symbol: store.habit.symbol);
      store.pledgeHabit(
        store.active,
        hour: 22,
        place: 'en la mesa de la cocina',
        identity: 'alguien que se levanta temprano',
      );
      store.describeHabit(
        store.active,
        why: 'para tener más energía durante el día',
        floor: 'abrir el libro y leer una página',
      );
      store.setCadence(store.habit, 3);
      for (final size in _pantallas) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final t = UiTheme(Palette.forMoment(13));
        await tester.pumpWidget(
          _marco(
            size,
            Align(
              alignment: Alignment.bottomCenter,
              child: HabitsSheet(store: store, theme: t),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        // La hoja rueda por dentro; lo que dice si sobra algo es cuánto le
        // queda por rodar.
        final hoja = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        expect(
          hoja.maxScrollExtent,
          lessThan(1),
          reason:
              'en $size la hoja se pasa de pantalla por '
              '${hoja.maxScrollExtent.round()} píxeles',
        );
        expect(
          tester.getRect(find.text('Eliminar este hábito')).bottom,
          lessThan(size.height + 1),
          reason: 'en $size no se llega al final de la hoja',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    /// El reloj de veinticuatro horas, plegado detrás de su propia frase.
    ///
    /// Es de donde salen la mitad de los píxeles que sobraban: el reloj más el
    /// renglón del sitio son doscientos, y dicen lo mismo que la frase en
    /// ámbar que iba debajo. La frase se queda y el reloj se abre al tocarla,
    /// que es cuando hace falta.
    testWidgets('el reloj del plan se abre al tocar la frase', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = Store();
      await store.load();
      store.renameHabit(store.active, name: 'Leer', symbol: store.habit.symbol);
      store.pledgeHabit(store.active, hour: 22, place: 'en la cama');
      const size = Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _marco(
          size,
          Align(
            alignment: Alignment.bottomCenter,
            child: HabitsSheet(
              store: store,
              theme: UiTheme(Palette.forMoment(13)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      final frase = find.textContaining('Voy a leer', findRichText: true);
      expect(frase, findsOneWidget, reason: 'la frase del plan no está');
      expect(
        find.byType(HourReel),
        findsNothing,
        reason: 'el reloj sale desplegado al abrir la hoja',
      );
      await tester.tap(frase);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byType(HourReel),
        findsOneWidget,
        reason: 'tocar la frase no abre el reloj',
      );
      expect(find.text('EN QUÉ SITIO'), findsOneWidget);
      // Y se vuelve a plegar, que es lo que hace un pliegue.
      await tester.tap(find.textContaining('Voy a leer', findRichText: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(HourReel), findsNothing);
    });

    /// El párrafo de la comarca, sólo donde sirve.
    ///
    /// Al fundar se está eligiendo entre seis y lo que dice es en qué se
    /// diferencian. Editando ya está elegida y no se puede cambiar: son ochenta
    /// píxeles de párrafo que nadie lee dos veces. El sello y el nombre se
    /// quedan en los dos sitios, porque dicen de qué pueblo es la hoja.
    testWidgets('la comarca se describe al fundar y no al editar', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final store = Store();
      await store.load();
      // Dos pueblos: con uno solo el tercer solar está cerrado y la hoja no
      // entra en modo fundar aunque se le pida.
      store.addHabit('Correr', 'carrera');
      store.active = 0;
      const size = Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final t = UiTheme(Palette.forMoment(13));
      for (final fundando in [false, true]) {
        await tester.pumpWidget(
          _marco(
            size,
            Align(
              alignment: Alignment.bottomCenter,
              child: HabitsSheet(store: store, theme: t, startNew: fundando),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        final comarca = fundando
            ? TownCharacter.forSlot(store.habits.length)
            : store.habit.place;
        expect(
          find.text(comarca.region.toUpperCase()),
          findsOneWidget,
          reason: 'sin sello no se sabe de qué pueblo es la hoja',
        );
        expect(
          find.text(comarca.blurb),
          fundando ? findsOneWidget : findsNothing,
          reason: fundando
              ? 'al fundar hay que decir qué clase de pueblo es cada uno'
              : 'editando, el párrafo de la comarca es relleno',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });
    // El fallo que se vio en un teléfono de verdad: a mediodía los símbolos
    // sin elegir salían en negro sobre el vidrio ahumado de la hoja y no se
    // veía ninguno, mientras las palabras de al lado —crema— se leían
    // perfectamente. Eran la misma hoja y dos tintas distintas.
    //
    // La hoja es vidrio oscuro a cualquier hora: de día porque se ahúma el
    // cielo, de noche porque el panel ya es oscuro. Así que la regla es una
    // sola y no depende de la hora: lo que se dibuja encima va en tinta
    // clara.
    // Editando, lo mínimo que cuenta y el plan salen sólo si ya se dijeron:
    // un renglón vacío más es un formulario más largo para nada.
    testWidgets('editando, lo que no se dijo no aparece', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = Store();
      await store.load();
      const size = Size(440, 950);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final t = UiTheme(Palette.forMoment(13));
      Future<void> abrir() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          _marco(
            size,
            Align(
              alignment: Alignment.bottomCenter,
              child: HabitsSheet(store: store, theme: t),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
      }

      await abrir();
      expect(find.text('LO MÍNIMO QUE CUENTA'), findsNothing);
      expect(find.text('EL PLAN'), findsNothing);

      store.describeHabit(0, floor: 'leer una página');
      store.setCadence(store.habit, 3);
      await abrir();
      expect(find.text('LO MÍNIMO QUE CUENTA'), findsOneWidget);
      expect(find.text('EL PLAN'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('las marcas sin elegir se leen a cualquier hora', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final store = Store();
      await store.load();
      const size = Size(440, 950);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final hora in [7.0, 13.0, 18.6, 23.0]) {
        final t = UiTheme(Palette.forMoment(hora));
        await tester.pumpWidget(
          _marco(
            size,
            Align(
              alignment: Alignment.bottomCenter,
              child: HabitsSheet(store: store, theme: t),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        // Abrir el carrete: se toca la marca grande de la cabecera.
        await tester.tap(find.byType(HabitSigil).first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));

        final marcas = tester
            .widgetList<HabitSigil>(find.byType(HabitSigil))
            // El ámbar del tema aparece en la marca elegida y en el sello de
            // la comarca, con alfas distintas: se descarta por el color, no
            // por la instancia.
            .where(
              (s) =>
                  s.color.r != t.accent.r ||
                  s.color.g != t.accent.g ||
                  s.color.b != t.accent.b,
            )
            .toList();
        expect(
          marcas,
          isNotEmpty,
          reason: 'el carrete no se abrió a las $hora',
        );
        for (final m in marcas) {
          expect(
            m.color.computeLuminance(),
            greaterThan(0.35),
            reason:
                'a las $hora una marca sin elegir va en tinta oscura '
                '(${m.color}) sobre el vidrio de la hoja',
          );
          expect(
            m.color.a,
            greaterThan(0.6),
            reason: 'a las $hora una marca sin elegir va casi transparente',
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}

/// El contraste entre dos colores, como lo mide todo el mundo.
double _contraste(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  final alto = x > y ? x : y, bajo = x > y ? y : x;
  return (alto + 0.05) / (bajo + 0.05);
}

void _abajo() {
  group('lo que va sobre el prado', () {
    // El fallo, visto en un teléfono a las cinco y media de la tarde: el botón
    // de poner y la fila de hábitos casi no se veían. La causa no es el
    // tamaño ni la opacidad: **toda la interfaz saca su tinta del techo del
    // cielo**, que es lo correcto para los rótulos de arriba, y a esa hora el
    // cielo todavía está claro, así que la tinta sale parda oscura. Parda
    // oscura sobre un verde de pradera no se lee, y lo de abajo tiene prado
    // detrás a cualquier hora.
    const horas = [6.0, 9.0, 11.0, 13.0, 17.6, 19.0, 19.6, 21.0, 23.0, 3.0];

    test('va en tinta clara, no en la del cielo', () {
      for (final hora in horas) {
        final t = UiTheme(Palette.forMoment(hora));
        expect(
          t.grassInk.computeLuminance(),
          greaterThan(0.45),
          reason: 'a las $hora la tinta de abajo sale oscura',
        );
      }
    });

    test('y se separa del prado de esa hora', () {
      // Lo que de verdad importa, medido: la tinta contra el verde que tiene
      // detrás. Tres a uno es el suelo por debajo del cual un texto chico deja
      // de leerse de un vistazo.
      for (final hora in horas) {
        final t = UiTheme(Palette.forMoment(hora));
        final prado = meadowTone(t.palette);
        expect(
          _contraste(t.grassInk, prado),
          greaterThan(3.0),
          reason:
              'a las $hora la tinta de abajo y el prado van a '
              '${_contraste(t.grassInk, prado).toStringAsFixed(2)} a uno',
        );
      }
    });

    testWidgets('y el botón y los hábitos la usan de verdad', (tester) async {
      // Lo anterior mide un color del tema; esto mide que abajo se use. Es la
      // mitad que se rompe sola: alguien escribe `t.fg` porque es lo que se
      // escribe en todas las demás pantallas y nadie se entera hasta que lo
      // mira a las cinco y media de la tarde.
      SharedPreferences.setMockInitialValues({});
      final store = Store();
      await store.load();
      store.renameHabit(0, name: 'Leer', symbol: 'libro');
      store.debugFill(40);

      for (final hora in [11.0, 17.6, 21.0]) {
        final t = UiTheme(Palette.forMoment(hora));
        await tester.pumpWidget(
          _marco(
            const Size(390, 844),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HabitBar(
                    store: store,
                    theme: t,
                    onSelect: (_) {},
                    onManage: () {},
                    onAdd: () {},
                  ),
                  HoldToPlace(theme: t, onPlace: () {}, onCharge: (_) {}),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final letras = tester.widget<Text>(find.text('MANTENER'));
        final tinta =
            letras.style?.color ??
            DefaultTextStyle.of(
              tester.element(find.text('MANTENER')),
            ).style.color!;
        expect(
          tinta.computeLuminance(),
          greaterThan(0.45),
          reason: 'a las $hora «MANTENER» va en tinta oscura',
        );

        for (final s in tester.widgetList<HabitSigil>(
          find.byType(HabitSigil),
        )) {
          // El del pueblo que se está mirando va en ámbar, que es su sitio.
          if (s.color.r == t.accent.r && s.color.b == t.accent.b) continue;
          expect(
            s.color.computeLuminance(),
            greaterThan(0.40),
            reason: 'a las $hora una marca de la fila va en tinta oscura',
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}

void _arriba() {
  group('lo que va sobre el cielo', () {
    /// Las veinticuatro horas, de cuatro en cuatro minutos: lo que se busca
    /// aquí es un mal instante, y un mal instante dura minutos.
    Iterable<double> todasLasHoras() sync* {
      for (var h = 0.0; h < 24.0; h += 1 / 15) {
        yield h;
      }
    }

    test('la tinta nunca pasa por el gris de en medio', () {
      // El fallo, medido: la tinta de arriba se desvanecía de parda a crema
      // en un cuarto de hora de reloj, y a mitad del desvanecido era un gris
      // medio sobre un cielo que a esa hora también es gris medio. A las
      // cinco y treinta y cinco de la tarde iban a **1,14 a 1**, que es texto
      // invisible durante ocho minutos, dos veces al día.
      //
      // Tres a uno es el suelo de un texto chico. Aquí se pide algo más
      // porque la tinta de arriba **puede** cumplirlo a cualquier hora: no
      // hay ninguna en la que las dos tintas vayan mal a la vez, sólo había
      // que dejar de mezclarlas.
      var peor = 99.0;
      var cuando = -1.0;
      for (final hora in todasLasHoras()) {
        final t = UiTheme(Palette.forMoment(hora));
        final r = _contraste(t.fg, t.palette.skyTop);
        if (r < peor) {
          peor = r;
          cuando = hora;
        }
      }
      expect(
        peor,
        greaterThan(3.3),
        reason:
            'a las ${cuando.toStringAsFixed(2)} la tinta de arriba y el '
            'cielo van a ${peor.toStringAsFixed(2)} a uno',
      );
    });
  });
}
