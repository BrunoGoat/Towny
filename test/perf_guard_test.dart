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
