import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towny/model/perf_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final g = PerfGuard.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    g.debugClear();
    await g.load();
    await g.setEnabled(true);
  });

  test('de fábrica está apagado y no apaga nada', () async {
    SharedPreferences.setMockInitialValues({});
    g.debugClear();
    await g.load();
    expect(g.enabled, isFalse);
    for (var i = 0; i < 180; i++) {
      g.debugFeed(60);
    }
    expect(g.apagadas, isEmpty);
  });

  test('si se apaga, vuelve a encender lo que había apagado', () async {
    for (var i = 0; i < 90; i++) {
      g.debugFeed(60);
    }
    expect(g.apagadas, isNotEmpty);
    await g.setEnabled(false);
    expect(g.apagadas, isEmpty);
    expect(g.off('resplandor'), isFalse);
    await g.setEnabled(true);
  });

  void ventana(double ms) {
    for (var i = 0; i < 90; i++) {
      g.debugFeed(ms);
    }
  }

  test('con cuadros lentos apaga de a una, de la más cara a la menos', () {
    ventana(60);
    expect(g.apagadas, ['resplandor']);
    ventana(60);
    expect(g.apagadas, ['resplandor', 'sombras']);
  });

  test('cuando ya va bien deja de apagar, y lo apagado queda', () {
    ventana(60);
    ventana(60);
    ventana(8);
    ventana(8);
    expect(g.apagadas, ['resplandor', 'sombras']);
  });

  test('con el consejero abierto empieza por lo que pesa ahí', () {
    g.enter(PerfScene.consejero);
    ventana(60);
    expect(g.apagadas, ['viento']);
    ventana(60);
    expect(g.apagadas, ['viento', 'polvo']);
    g.leave(PerfScene.consejero);
    ventana(60);
    expect(g.apagadas.last, 'resplandor');
  });

  test('un cuadro de cada dos que no dibuja no esconde a los lentos', () {
    for (var i = 0; i < 45; i++) {
      g.debugFeed(1);
      g.debugFeed(60);
    }
    expect(g.apagadas, isNotEmpty);
  });

  test('se acuerda al volver a abrir, y se puede encender todo', () async {
    ventana(60);
    ventana(60);
    g.debugClear();
    await g.load();
    expect(g.apagadas, ['resplandor', 'sombras']);
    expect(g.off('sombras'), isTrue);
    await g.reset();
    expect(g.apagadas, isEmpty);
    g.debugClear();
    await g.load();
    expect(g.apagadas, isEmpty);
  });
}
