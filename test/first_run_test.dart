import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/data/character.dart';
import 'package:towny/engine/town.dart';
import 'package:towny/engine/world.dart';
import 'package:towny/model/appearance.dart';
import 'package:towny/sync/account.dart';
import 'package:towny/ui/first_run.dart';
import 'package:towny/ui/habit_sigil.dart';

Widget _marco(Widget child) => MediaQuery(
  data: const MediaQueryData(
    size: Size(390, 844),
    padding: EdgeInsets.only(top: 44, bottom: 24),
  ),
  child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
);

Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Lo que tarda en fundarse de verdad: la tarjeta se va y la cámara baja al
/// pueblo antes de avisar, que es cuando el pueblo toma el relevo.
Future<void> _bajar(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Toca «Siguiente», llevándolo antes a la vista: la tarjeta rueda cuando no
/// cabe, y en la pantalla de los tests a veces queda justo debajo del borde.
Future<void> _siguiente(WidgetTester tester) async {
  await tester.ensureVisible(find.text('SIGUIENTE'));
  await tester.pump();
  await tester.tap(find.text('SIGUIENTE'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Appearance.instance.load();
    await Appearance.instance.setSoundOff(true);
  });

  group('la primera vez', () {
    testWidgets('cinco pantallas, y lo que se contestó llega entero', (
      tester,
    ) async {
      // Del tamaño de un teléfono: en la pantalla de pruebas de siempre la
      // pregunta de la comarca tapa el pueblo de muestra entero.
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      // Los nombres de fuera no pueden llamarse igual que los parámetros con
      // nombre de la llamada, que si no los tapan.
      String? elNombre, laMarca, elMotivo, laIdentidad;
      int? laComarca;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (n, s, {required character, why, identity}) {
              elNombre = n;
              laMarca = s;
              laComarca = character;
              elMotivo = why;
              laIdentidad = identity;
            },
          ),
        ),
      );
      await _asentar(tester);

      await tester.tap(find.text('FUNDAR MI PUEBLO'));
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'Leer');
      await tester.pump();
      await _siguiente(tester);
      await _asentar(tester);

      // La comarca: se elige mirando el pueblo de muestra, sin explicación.
      expect(find.text('¿Qué clase de pueblo?'), findsOneWidget);
      // Los botones son sólo el sello; el nombre se revela al tocarlo.
      expect(find.text('Sierra'), findsNothing);
      await tester.tap(
        find.byWidgetPredicate((w) => w is HabitSigil && w.symbol == 'montana'),
      );
      await _asentar(tester);
      expect(find.text('Sierra'), findsOneWidget);
      expect(find.textContaining('esfuerzo físico'), findsOneWidget);

      // Y se puede recorrer: la pregunta se esconde, queda el pueblo de
      // muestra con su nombre, y «Volver» devuelve a la misma pregunta.
      await tester.ensureVisible(find.text('Recorrer este pueblo'));
      await tester.pump();
      await tester.tap(find.text('Recorrer este pueblo'));
      await _asentar(tester);
      expect(find.text('VOLVER'), findsOneWidget);
      expect(find.text('Sierra'), findsNWidgets(2));
      // Mientras se recorre, lo de la pregunta no se puede tocar.
      expect(find.text('SIGUIENTE').hitTestable(), findsNothing);
      await tester.drag(find.byType(Scaffold).first, const Offset(-120, 40));
      await _asentar(tester);
      await tester.tap(find.text('VOLVER'));
      await _asentar(tester);
      expect(find.text('VOLVER'), findsNothing);
      expect(find.text('¿Qué clase de pueblo?'), findsOneWidget);
      // Y tocar el pueblo de muestra, arriba, hace lo mismo que el botón.
      await tester.tapAt(const Offset(300, 130));
      await _asentar(tester);
      expect(find.text('VOLVER'), findsOneWidget);
      await tester.tap(find.text('VOLVER'));
      await _asentar(tester);
      await _siguiente(tester);
      await _asentar(tester);

      // Ni cuándo ni dónde: eso lo propone el pueblo cuando ya lo sabe.
      expect(find.text('¿Cuándo y dónde?'), findsNothing);
      expect(find.text('¿Para qué querés ese hábito?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'para dormir mejor');
      await tester.pump();
      await _siguiente(tester);
      await _asentar(tester);

      expect(
        find.text('¿En quién te convierte tener ese hábito?'),
        findsOneWidget,
      );
      // El «alguien» ya está escrito delante del campo: se escribe el resto.
      expect(find.text('alguien'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        'que lee todos los días',
      );
      await tester.pump();
      // Y ésta es la última: no hay «lo mínimo que cuenta» detrás.
      await tester.tap(find.text('FUNDAR LEER'));
      await _asentar(tester);
      // Mientras baja la cámara todavía no se fundó nada: el pueblo toma el
      // relevo al llegar, no antes.
      expect(elNombre, isNull);
      expect(find.text('Leer'), findsWidgets, reason: 'el nombre, bajando');
      await _bajar(tester);

      expect(elNombre, 'Leer');
      expect(laMarca, isNotEmpty);
      expect(elMotivo, 'para dormir mejor');
      expect(laIdentidad, 'alguien que lee todos los días');
      expect(
        laComarca,
        TownCharacter.all.firstWhere((c) => c.region == 'Sierra').order,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('las dos hay que contestarlas: no se pueden saltar', (
      tester,
    ) async {
      String? elMotivo = 'sin tocar', laIdentidad = 'sin tocar';
      var fundado = false;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (n, s, {required character, why, identity}) {
              elMotivo = why;
              laIdentidad = identity;
              fundado = true;
            },
          ),
        ),
      );
      await _asentar(tester);
      await tester.tap(find.text('FUNDAR MI PUEBLO'));
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'Correr');
      await tester.pump();
      await _siguiente(tester);
      await _asentar(tester);
      // La comarca no se salta: ya viene una elegida.
      await _siguiente(tester);
      await _asentar(tester);
      // Ni «ahora no» ni seguir en blanco: el botón está, pero apagado.
      for (final respuesta in ['para correr la maratón', 'que no se rinde']) {
        expect(find.text('Ahora no'), findsNothing);
        final apagado = find.textContaining(RegExp('SIGUIENTE|FUNDAR'));
        await tester.ensureVisible(apagado.last);
        await tester.tap(apagado.last, warnIfMissed: false);
        await _asentar(tester);
        expect(fundado, isFalse);
        await tester.enterText(find.byType(TextField).first, respuesta);
        await tester.pump();
        await tester.ensureVisible(find.byType(TextField).first);
        final boton = find.textContaining(RegExp('SIGUIENTE|FUNDAR'));
        await tester.tap(boton.last);
        await _asentar(tester);
      }
      await _bajar(tester);
      expect(fundado, isTrue);
      expect(elMotivo, 'para correr la maratón');
      expect(laIdentidad, 'alguien que no se rinde');
    });

    testWidgets('no se puede seguir sin decir qué querés hacer', (
      tester,
    ) async {
      var fundado = false;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (_, _, {required character, why, identity}) =>
                fundado = true,
          ),
        ),
      );
      await _asentar(tester);
      await tester.tap(find.text('FUNDAR MI PUEBLO'));
      await _asentar(tester);
      // El botón está a la vista pero apagado: que se vea dónde está la salida
      // antes de poder usarla es la mitad de saber cuánto falta.
      expect(find.text('SIGUIENTE'), findsOneWidget);
      await _siguiente(tester);
      await _asentar(tester);
      expect(find.text('¿Para qué querés ese hábito?'), findsNothing);
      expect(fundado, isFalse);
    });

    testWidgets('cabe en un teléfono chico, con el teclado abierto', (
      tester,
    ) async {
      for (final teclado in [0.0, 260.0]) {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 568),
              padding: const EdgeInsets.only(top: 20),
              viewInsets: EdgeInsets.only(bottom: teclado),
            ),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: FirstRun(
                onDone: (_, _, {required character, why, identity}) {},
              ),
            ),
          ),
        );
        await _asentar(tester);
        expect(tester.takeException(), isNull, reason: 'bienvenida, $teclado');
        // Con el teclado abierto la tarjeta rueda: el botón está, pero hay que
        // llegar a él.
        await tester.ensureVisible(find.text('FUNDAR MI PUEBLO'));
        await tester.pump();
        await tester.tap(find.text('FUNDAR MI PUEBLO'));
        await _asentar(tester);
        expect(tester.takeException(), isNull, reason: 'nombre, $teclado');
        await tester.enterText(find.byType(TextField).first, 'Leer');
        await tester.pump();
        await tester.ensureVisible(find.text('SIGUIENTE'));
        await tester.pump();
        await _siguiente(tester);
        await _asentar(tester);
        expect(tester.takeException(), isNull, reason: 'comarca, $teclado');
        await tester.ensureVisible(find.text('SIGUIENTE'));
        await tester.pump();
        await _siguiente(tester);
        await _asentar(tester);
        expect(tester.takeException(), isNull, reason: 'para qué, $teclado');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('fundar dos veces seguidas funda una sola', (tester) async {
      // Un dedo impaciente toca otra vez mientras baja la cámara.
      var veces = 0;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            onDone: (_, _, {required character, why, identity}) => veces++,
          ),
        ),
      );
      await _asentar(tester);
      await tester.tap(find.text('FUNDAR MI PUEBLO'));
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'Leer');
      await tester.pump();
      await _siguiente(tester);
      await _asentar(tester);
      await _siguiente(tester);
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'para saber más');
      await tester.pump();
      await _siguiente(tester);
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'que lee');
      await tester.pump();
      await tester.tap(find.text('FUNDAR LEER'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text('FUNDAR LEER'), warnIfMissed: false);
      await _bajar(tester);
      expect(veces, 1);
    });
  });

  group('atrás', () {
    testWidgets('vuelve a la pregunta de antes, con lo contestado', (
      tester,
    ) async {
      await tester.pumpWidget(
        _marco(
          FirstRun(onDone: (_, _, {required character, why, identity}) {}),
        ),
      );
      await _asentar(tester);
      await tester.tap(find.text('FUNDAR MI PUEBLO'));
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'Leer');
      await tester.pump();
      await _siguiente(tester);
      await _asentar(tester);
      expect(find.text('¿Qué clase de pueblo?'), findsOneWidget);
      // El botón de atrás del sistema.
      await tester.binding.handlePopRoute();
      await _asentar(tester);
      expect(find.text('¿Qué hábito querés desarrollar?'), findsOneWidget);
      expect(find.text('Leer'), findsWidgets);
      // Y el gesto de deslizar desde el borde izquierdo.
      await _siguiente(tester);
      await _asentar(tester);
      expect(find.text('¿Qué clase de pueblo?'), findsOneWidget);
      // Uno corto no vuelve: la pregunta se queda.
      await tester.dragFrom(const Offset(4, 400), const Offset(60, 0));
      await _asentar(tester);
      expect(find.text('¿Qué clase de pueblo?'), findsOneWidget);
      await tester.dragFrom(const Offset(4, 400), const Offset(240, 0));
      await _asentar(tester);
      expect(find.text('¿Qué hábito querés desarrollar?'), findsOneWidget);
      // Y la flecha de arriba hace lo mismo.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await _asentar(tester);
      expect(find.text('FUNDAR MI PUEBLO'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('en la bienvenida del siguiente, vuelve al valle', (
      tester,
    ) async {
      var cancelado = false;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            next: NextTown(
              towns: [
                (name: 'Leer', symbol: 'libro', pieces: 34, character: 0),
              ],
            ),
            onCancel: () => cancelado = true,
            onDone: (_, _, {required character, why, identity}) {},
          ),
        ),
      );
      await _asentar(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(cancelado, isTrue);
    });
  });

  group('el pueblo siguiente', () {
    final next = NextTown(
      towns: [
        (
          name: 'Leer',
          symbol: 'libro',
          pieces: 34,
          character: TownCharacter.all.first.order,
        ),
      ],
    );

    testWidgets('dice qué se ganó, y con qué', (tester) async {
      var cancelado = false;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            next: next,
            onCancel: () => cancelado = true,
            onDone: (_, _, {required character, why, identity}) {},
          ),
        ),
      );
      await _asentar(tester);
      expect(find.text('Te ganaste tu segundo pueblo.'), findsOneWidget);
      expect(find.textContaining('«Leer» lleva 34 piezas'), findsOneWidget);
      expect(find.text('PUEBLO II'), findsOneWidget);
      expect(find.text('FUNDAR MI SEGUNDO PUEBLO'), findsOneWidget);
      // Y la salida a la vista: un pueblo se funda cuando hay ganas.
      await tester.tap(find.text('Ahora no'));
      expect(cancelado, isTrue);
    });

    testWidgets('se funda entero, en una comarca que el valle no tiene', (
      tester,
    ) async {
      String? elNombre;
      int? laComarca;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            next: next,
            onCancel: () {},
            onDone: (n, _, {required character, why, identity}) {
              elNombre = n;
              laComarca = character;
            },
          ),
        ),
      );
      await _asentar(tester);
      await tester.tap(find.text('FUNDAR MI SEGUNDO PUEBLO'));
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'Correr');
      await tester.pump();
      await _siguiente(tester);
      await _asentar(tester);
      await _siguiente(tester);
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'para estar bien');
      await tester.pump();
      await _siguiente(tester);
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'que corre');
      await tester.pump();
      await tester.tap(find.text('FUNDAR CORRER'));
      await _bajar(tester);
      expect(elNombre, 'Correr');
      expect(laComarca, isNot(TownCharacter.all.first.order));
    });
  });

  group('la cuenta', () {
    Future<void> tocar(WidgetTester tester, String texto) async {
      await tester.ensureVisible(find.text(texto));
      await tester.pump();
      await tester.tap(find.text(texto));
      await _asentar(tester);
    }

    testWidgets('el correo, el código, y después la bienvenida', (
      tester,
    ) async {
      final cuenta = _Cuenta();
      await tester.pumpWidget(
        _marco(
          FirstRun(
            account: cuenta,
            onDone: (_, _, {required character, why, identity}) {},
          ),
        ),
      );
      await _asentar(tester);
      // Antes que nada: la cuenta, con la marca arriba como en la bienvenida.
      expect(find.text('Guardá tu valle.'), findsOneWidget);
      expect(find.text('Towny'), findsWidgets);
      expect(find.text('Esto es un valle vacío.'), findsNothing);

      // Sin algo que parezca un correo, no se manda nada.
      await tester.enterText(find.byType(TextField).first, 'bruno');
      await tester.pump();
      await tocar(tester, 'MANDARME EL CÓDIGO');
      expect(cuenta.mandados, isEmpty);

      await tester.enterText(
        find.byType(TextField).first,
        ' bruno@correo.com ',
      );
      await tester.pump();
      await tocar(tester, 'MANDARME EL CÓDIGO');
      expect(cuenta.mandados, ['bruno@correo.com']);
      expect(find.text('Revisá tu correo.'), findsOneWidget);
      expect(find.textContaining('bruno@correo.com'), findsOneWidget);

      // Uno equivocado se dice, y se queda en el código.
      await tester.enterText(find.byType(TextField).first, '111111');
      await _asentar(tester);
      expect(find.textContaining('Ese código no es'), findsOneWidget);
      expect(find.text('Revisá tu correo.'), findsOneWidget);

      // El bueno entra solo, sin tocar nada más.
      await tester.enterText(find.byType(TextField).first, '123456');
      await _asentar(tester);
      expect(find.text('Esto es un valle vacío.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('se puede volver a cambiar el correo', (tester) async {
      final cuenta = _Cuenta();
      await tester.pumpWidget(
        _marco(
          FirstRun(
            account: cuenta,
            onDone: (_, _, {required character, why, identity}) {},
          ),
        ),
      );
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'bruno@correo.com');
      await tester.pump();
      await tocar(tester, 'MANDARME EL CÓDIGO');
      await tocar(tester, 'Usar otro correo');
      expect(find.text('Guardá tu valle.'), findsOneWidget);
    });

    testWidgets('si no se pudo mandar, se dice y no se sigue', (tester) async {
      final cuenta = _Cuenta()..falla = true;
      await tester.pumpWidget(
        _marco(
          FirstRun(
            account: cuenta,
            onDone: (_, _, {required character, why, identity}) {},
          ),
        ),
      );
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'bruno@correo.com');
      await tester.pump();
      await tocar(tester, 'MANDARME EL CÓDIGO');
      expect(find.textContaining('No se pudo mandar'), findsOneWidget);
      expect(find.text('Guardá tu valle.'), findsOneWidget);
    });

    testWidgets('si la nube dice que no, se dice por qué', (tester) async {
      final cuenta = _Cuenta()..rechazo = 'Error sending magic link email';
      await tester.pumpWidget(
        _marco(
          FirstRun(
            account: cuenta,
            onDone: (_, _, {required character, why, identity}) {},
          ),
        ),
      );
      await _asentar(tester);
      await tester.enterText(find.byType(TextField).first, 'bruno@correo.com');
      await tester.pump();
      await tocar(tester, 'MANDARME EL CÓDIGO');
      expect(
        find.textContaining('Error sending magic link email'),
        findsOneWidget,
      );
      expect(find.textContaining('Revisá la conexión'), findsNothing);
    });

    testWidgets('y se puede seguir sin cuenta', (tester) async {
      await tester.pumpWidget(
        _marco(
          FirstRun(
            account: _Cuenta(),
            onDone: (_, _, {required character, why, identity}) {},
          ),
        ),
      );
      await _asentar(tester);
      await tocar(tester, 'Seguir sin cuenta');
      expect(find.text('Esto es un valle vacío.'), findsOneWidget);
    });
  });

  group('la plaza', () {
    test('existe desde que se funda, no desde la primera pieza', () {
      // Antes hacía falta una pieza puesta, y eso era una plaza apareciendo de
      // la nada a la vez que la primera casa.
      for (final ch in TownCharacter.all) {
        final l = TownLayout(0, ch, seed: 3);
        final t = builtTown(l, 0);
        expect(
          t.clusters,
          isNotEmpty,
          reason: '${ch.region}: un pueblo fundado sin plaza',
        );
        expect(t.bounds, isNotNull);
      }
    });

    test('y el expositor no la tiene, que no es un pueblo', () {
      // El expositor planta una estructura sola en un prado, sobre su peana.
      // Una plaza ahí sería decorado de un sitio que no existe.
      final ch = TownCharacter.all.first;
      final solo = TownLayout.showcase(
        ch,
        kind: BuildingKind.values.first,
        placed: 0,
      );
      int caras(TownLayout l) =>
          builtTown(l, 0).clusters.fold<int>(0, (a, c) => a + c.faces);
      // Por caras y no por grupos: el enlosado y el tablón se tocan,
      // así que el árbol los funde en uno solo y contar grupos da uno en los
      // dos casos. Lo que hay debajo de ese uno es muy distinto.
      expect(caras(solo) * 4, lessThan(caras(TownLayout(0, ch, seed: 3))));
    });
  });
}

/// Una cuenta de mentira: apunta a quién se mandó y sólo acepta 123456.
class _Cuenta implements Account {
  final mandados = <String>[];
  bool falla = false;
  String? rechazo;

  @override
  Future<void> sendCode(String email) async {
    if (falla) throw Exception('sin conexión');
    if (rechazo != null) throw AccountRefused(rechazo!);
    mandados.add(email);
  }

  @override
  Future<bool> verify(String email, String code) async => code == '123456';
}
