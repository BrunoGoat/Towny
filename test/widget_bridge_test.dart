import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_muralla/data/character.dart';
import 'package:la_muralla/fx/widget_bridge.dart';
import 'package:la_muralla/model/habit.dart';
import 'package:la_muralla/model/piece.dart';

/// Un hábito con piezas puestas a las horas que se le digan.
Habit _habit({
  required String id,
  String name = 'Leer',
  String symbol = 'libro',
  List<DateTime> cuando = const [],
  int slot = 0,
}) => Habit(
  id: id,
  name: name,
  symbol: symbol,
  slot: slot,
  createdAt: DateTime(2026, 1, 1),
  character: TownCharacter.all.first.order,
  pieces: [
    for (var i = 0; i < cuando.length; i++)
      Piece(index: i, placedAt: cuando[i]),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// El otro lado del canal, de mentira: apunta lo que le mandan y contesta lo
  /// que se le diga.
  ({List<MethodCall> dichas, void Function(Object?) responde}) espiar({
    bool nadie = false,
  }) {
    final dichas = <MethodCall>[];
    Object? respuesta;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WidgetBridge.channel, (call) async {
          if (nadie) throw MissingPluginException('sin widget');
          dichas.add(call);
          return respuesta;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(WidgetBridge.channel, null);
    });
    return (dichas: dichas, responde: (r) => respuesta = r);
  }

  /// Una fila del resumen. Pasa por el códec del canal, así que del otro lado
  /// los mapas vuelven sin tipo: se rehacen para poder mirarlos.
  Map<String, Object?> fila(MethodCall call, int at) =>
      Map<String, Object?>.from(
        ((call.arguments as Map)['habits'] as List)[at] as Map,
      );

  group('lo que la app publica', () {
    test('una fila por pueblo, con su marca dibujada', () async {
      final espia = espiar();
      final hoy = DateTime(2026, 5, 4, 20);
      await WidgetBridge.fresh().publish([
        _habit(id: 'a', name: 'Leer', symbol: 'libro'),
        _habit(id: 'b', name: 'Correr', symbol: 'carrera', slot: 1),
      ], now: hoy);

      expect(espia.dichas.single.method, 'publish');
      final a = fila(espia.dichas.single, 0);
      expect(a['id'], 'a');
      expect(a['name'], 'Leer');
      // La marca va dibujada, no por su nombre: del otro lado no hay nada que
      // sepa dibujar un símbolo de esta app.
      final png = a['mark'] as Uint8List?;
      expect(png, isNotNull);
      expect(png!.length, greaterThan(64));
      // Y es un PNG de verdad, con su firma.
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(fila(espia.dichas.single, 1)['name'], 'Correr');
    });

    test('el punto dice si hoy ya pusiste, y nada más', () async {
      final espia = espiar();
      final hoy = DateTime(2026, 5, 4, 20);
      await WidgetBridge.fresh().publish([
        // Una de ayer y ninguna de hoy.
        _habit(id: 'a', cuando: [DateTime(2026, 5, 3, 21)]),
        // Y una de esta mañana.
        _habit(id: 'b', slot: 1, cuando: [DateTime(2026, 5, 4, 7, 30)]),
      ], now: hoy);

      final call = espia.dichas.single;
      expect(fila(call, 0)['today'], isFalse);
      expect(fila(call, 1)['today'], isTrue);
      // Lo que no va: ni cuántas lleva, ni cuántos días seguidos. Si algún día
      // alguien mete una racha en el widget, que sea a sabiendas.
      expect(fila(call, 0).keys.toSet(), {
        'id',
        'name',
        'today',
        'resting',
        'mark',
      });
    });

    test('un pueblo dormido va marcado como dormido', () async {
      final espia = espiar();
      final hoy = DateTime(2026, 5, 4, 20);
      final h = _habit(id: 'a');
      h.rests.add(
        '${DateTime(2026, 5, 1).millisecondsSinceEpoch}|'
        '${DateTime(2026, 5, 9).millisecondsSinceEpoch}',
      );
      await WidgetBridge.fresh().publish([h], now: hoy);
      expect(fila(espia.dichas.single, 0)['resting'], isTrue);
    });

    test('nunca más filas que solares hay en el valle', () async {
      final espia = espiar();
      final muchos = [
        for (var i = 0; i < 9; i++) _habit(id: 'h$i', slot: i % 6),
      ];
      await WidgetBridge.fresh().publish(muchos);
      final filas = (espia.dichas.single.arguments as Map)['habits'] as List;
      expect(filas.length, Habit.maxSlots);
    });
  });

  group('lo que la app recoge', () {
    test('lee el buzón y lo entiende', () async {
      final espia = espiar();
      espia.responde([
        {
          'n': 1,
          'h': 'a',
          't': DateTime(2026, 5, 4, 21).millisecondsSinceEpoch,
        },
        {
          'n': 2,
          'h': 'b',
          't': DateTime(2026, 5, 4, 22).millisecondsSinceEpoch,
        },
      ]);
      final leidas = await WidgetBridge.fresh().drain();
      expect(leidas.length, 2);
      expect(leidas.first.habitId, 'a');
      expect(leidas.last.serial, 2);
    });

    test('un buzón vacío no es un error', () async {
      final espia = espiar();
      espia.responde(const []);
      expect(await WidgetBridge.fresh().drain(), isEmpty);
    });

    test('confirmar es una llamada aparte, y no se hace por gusto', () async {
      final espia = espiar();
      final puente = WidgetBridge.fresh();
      await puente.ack(0);
      expect(espia.dichas, isEmpty, reason: 'confirmó sin nada que confirmar');
      await puente.ack(7);
      expect(espia.dichas.single.method, 'ack');
      expect((espia.dichas.single.arguments as Map)['upTo'], 7);
    });
  });

  test('sin widget del otro lado no revienta ni insiste', () async {
    // iOS, la web, un teléfono cuyo lanzador no tiene widgets. La app tiene
    // que seguir siendo la app.
    espiar(nadie: true);
    final puente = WidgetBridge.fresh();
    await puente.publish([_habit(id: 'a')]);
    expect(await puente.drain(), isEmpty);
    await puente.ack(3);

    // Y a partir de la primera negativa deja de preguntar: el canal no va a
    // aparecer a mitad de la vida del proceso.
    final espia = espiar();
    await puente.publish([_habit(id: 'a')]);
    expect(espia.dichas, isEmpty);
  });
}
