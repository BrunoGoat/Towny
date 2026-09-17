import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/engine/palette.dart';
import 'package:la_muralla/model/store.dart';
import 'package:la_muralla/ui/habits_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:la_muralla/ui/legend_card.dart';
import 'package:la_muralla/ui/overlays.dart';
import 'package:la_muralla/ui/style.dart';
import 'package:la_muralla/ui/town_sign.dart';

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
void _dentro(WidgetTester tester, Size size, String quien) {
  for (final e in find.byType(Text).evaluate()) {
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
    expect(
      at.dy + box.size.height,
      lessThan(size.height + 1),
      reason: '$quien se sale por abajo en $size',
    );
  }
}

void main() {
  _cuando();
  _pieles();
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
            theme: UiTheme(Palette.forMoment(13, 1.0)),
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

  testWidgets('la tarjeta de la leyenda cabe y se lee', (tester) async {
    const leyenda = 'Corrí ocho kilómetros por el parque, con lluvia';
    for (final size in _pantallas) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _marco(
          size,
          Center(
            child: StoneCard(
              theme: UiTheme(Palette.forMoment(13, 1.0)),
              when: DateTime(2026, 9, 10, 8, 50),
              number: 1284,
              label: leyenda,
              onWrite: (_) {},
              onWhen: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.text(leyenda), findsOneWidget);
      _dentro(tester, size, 'la tarjeta');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('lo que falta por escribir no es un aviso, y es de esta hora', (
    tester,
  ) async {
    // Una leyenda que no está escrita no es una alerta. En el naranja de la
    // hora lo parecía, y de ahí viene esto.
    //
    // Lo que se exige cambió: era «que tire a pardo», y un pardo de mediodía a
    // las tres de la mañana es una mancha que no es de esa hora. Ahora sale de
    // la paleta como todo lo demás, así que de noche puede ser fría. Lo que no
    // puede es cantar: tiene que leerse como un texto apagado y no como el
    // color con que la app avisa de algo.
    for (final hora in [13.0, 2.0]) {
      final t = UiTheme(Palette.forMoment(hora, 1.0));
      tester.view.physicalSize = _pantallas.last;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _marco(
          _pantallas.last,
          Center(
            child: StoneCard(
              theme: t,
              when: DateTime(2026, 9, 10),
              number: 7,
              label: null,
              onWrite: (_) {},
              onWhen: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final texto = tester.widget<Text>(find.text('escribir una leyenda'));
      final color = texto.style!.color!;
      expect(
        color,
        isNot(t.accent),
        reason: 'sigue siendo el color de la hora',
      );
      double lejos(Color a, Color b) =>
          (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
      expect(
        lejos(color, t.fgSoft),
        lessThan(lejos(color, t.accent)),
        reason:
            'a las $hora se parece más al color de aviso que al del texto: '
            'una leyenda sin escribir es un hueco esperando, no una alerta',
      );
      expect(
        lejos(color, t.fgSoft),
        greaterThan(0.02),
        reason: 'a las $hora es exactamente el texto normal y no se distingue',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('y se escribe de la misma tinta con la que se lee', (
    tester,
  ) async {
    // De noche pasaba esto: escribías la leyenda en negro y, al guardarla, el
    // mismo texto salía blanco. La tarjeta le pone el color a su cuerpo con un
    // DefaultTextStyle, que un Text lee y un campo de texto no —ése se mezcla
    // contra el tema de Material, que lo pintaba oscuro sobre el bloque
    // oscuro—. Leer una leyenda y escribirla son la misma cosa vista dos
    // veces, así que tienen que verse igual.
    for (final hora in [13.0, 2.0]) {
      final t = UiTheme(Palette.forMoment(hora, 1.0));
      final size = _pantallas.last;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _marco(
          size,
          Center(
            child: StoneCard(
              theme: t,
              when: DateTime(2026, 9, 10),
              number: 7,
              label: 'Corrí',
              onWrite: (_) {},
              onWhen: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      // Lo que se ve al leerla: el Text sale sin color y se lo pone la
      // tarjeta, así que hay que preguntarle al párrafo ya resuelto.
      final leida = (tester.renderObject(find.text('Corrí')) as RenderParagraph)
          .text
          .style!
          .color!;

      await tester.tap(find.text('Corrí'));
      await tester.pump(const Duration(milliseconds: 200));
      final escribiendo = tester
          .widget<EditableText>(find.byType(EditableText))
          .style
          .color!;

      expect(
        escribiendo,
        leida,
        reason:
            'a las $hora se escribe en $escribiendo y se lee en $leida: '
            'el texto cambia de color al guardarlo',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('la leyenda se escribe en la propia tarjeta', (tester) async {
    // Antes esto abría una hoja por debajo, con su título, su explicación y
    // sus botones. Una pantalla entera para una frase de sesenta letras que ya
    // estaba en pantalla.
    final size = _pantallas.last;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? escrito;
    await tester.pumpWidget(
      _marco(
        size,
        Center(
          child: StoneCard(
            theme: UiTheme(Palette.forMoment(13, 1.0)),
            when: DateTime(2026, 9, 10),
            number: 7,
            label: null,
            onWrite: (t) => escrito = t,
            onWhen: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Se lee, se toca, y se escribe ahí mismo: una sola tarjeta de principio a
    // fin, sin ninguna pantalla nueva.
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('escribir una leyenda'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LegendCard), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Leí un rato');
    // Y sin botón de guardar: tocar fuera guarda, que es lo que iba a pasar
    // igual.
    expect(find.text('Guardar'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 200));
    expect(escrito, 'Leí un rato');
    expect(find.byType(TextField), findsNothing);
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
      for (final size in _pantallas) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final hora in [13.0, 23.0]) {
          final t = UiTheme(Palette.forMoment(hora, 1.0));
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
          _dentro(tester, size, 'la hoja');
          await tester.pumpWidget(const SizedBox());
        }
      }
    });
  });
}
