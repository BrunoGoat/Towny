import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/render_debug.dart';

/// Dónde se está, para que el defensor apague primero lo que pesa ahí.
enum PerfScene { pueblo, consejero, bienvenida }

/// Una de las cosas que el defensor puede apagar.
class PerfStep {
  const PerfStep(this.id, this.nombre, this.queHace, this.donde);

  /// Lo que se guarda. Nunca se reutiliza uno.
  final String id;

  /// Cómo se llama en los ajustes de desarrollo.
  final String nombre;

  /// Qué se deja de ver al apagarla.
  final String queHace;

  /// En qué pantallas pesa.
  final Set<PerfScene> donde;
}

/// **El defensor de rendimiento.**
///
/// Mide lo que tarda cada fotograma y, si la app no llega, va apagando cosas
/// de a una, de la que más cuesta a la que menos, y da unos segundos a cada
/// apagón para ver si alcanzó. En cuanto va bien deja de apagar, y lo
/// apagado queda apagado —también la próxima vez que se abra la app—: un
/// teléfono que no llegaba hoy no va a llegar mañana.
///
/// Empieza por lo que pesa en la pantalla donde se está: con el consejero
/// abierto no sirve de mucho quitarle sombras al pueblo de detrás.
///
/// En Ajustes → Desarrollo se ve qué apagó y qué sigue encendido, y se
/// puede volver a encender todo.
class PerfGuard extends ChangeNotifier {
  PerfGuard._();
  static final PerfGuard instance = PerfGuard._();

  static const String _key = 'perf_guard_v1';
  static const String _keyOn = 'perf_guard_on_v1';

  /// Si el defensor está encendido. **Apagado de fábrica**: quien no tiene
  /// la hoja de desarrollo vería que se le apagan cosas sin poder volver a
  /// prenderlas. Se enciende desde Ajustes, Desarrollo, El defensor.
  bool get enabled => _on;
  bool _on = false;

  Future<void> setEnabled(bool v) async {
    if (v == _on) return;
    _on = v;
    try {
      await _prefs?.setBool(_keyOn, v);
    } catch (_) {}
    if (v) {
      _reiniciar();
      _escuchar();
      notifyListeners();
    } else {
      // Apagarlo vuelve a encender todo lo que había apagado.
      await reset();
    }
  }

  /// Todo lo que puede apagar, de lo que más cuesta a lo que menos.
  static const List<PerfStep> steps = [
    PerfStep(
      'resplandor',
      'Resplandor',
      'El brillo borroso alrededor de las luces del pueblo.',
      {PerfScene.pueblo},
    ),
    PerfStep(
      'sombras',
      'Sombras',
      'Las sombras de las casas y de la gente sobre el suelo.',
      {PerfScene.pueblo},
    ),
    PerfStep(
      'viento',
      'Hilos de viento',
      'Los hilos de aire que cruzan la pantalla del consejero.',
      {PerfScene.consejero, PerfScene.bienvenida},
    ),
    PerfStep(
      'rayos',
      'Rayos de sol',
      'Los rayos de luz detrás del pueblo al amanecer y al atardecer.',
      {PerfScene.pueblo},
    ),
    PerfStep(
      'color',
      'Color de cine',
      'El tono de color de cada hora sobre todo el pueblo.',
      {PerfScene.pueblo},
    ),
    PerfStep(
      'polvo',
      'Polvo y hojas',
      'Las motas de luz y las hojas que vuelan con el consejero y en la '
          'bienvenida.',
      {PerfScene.consejero, PerfScene.bienvenida},
    ),
    PerfStep(
      'calidad',
      'Calidad máxima',
      'Lo que queda de la calidad máxima: más estrellas, el sombreado al pie '
          'de las paredes y la neblina.',
      {PerfScene.pueblo},
    ),
    PerfStep(
      'cuadros',
      'Veinte cuadros por segundo',
      'Todo lo que se mueve solo se dibuja veinte veces por segundo en vez '
          'de treinta.',
      {PerfScene.pueblo, PerfScene.consejero, PerfScene.bienvenida},
    ),
    PerfStep(
      'gente',
      'Menos vecinos a la vez',
      'Se dibujan como mucho treinta personas, las más cercanas.',
      {PerfScene.pueblo},
    ),
    PerfStep(
      'agua',
      'Chorros de la fuente',
      'El agua que cae de la fuente de la plaza.',
      {PerfScene.pueblo, PerfScene.bienvenida},
    ),
  ];

  final Set<String> _apagadas = {};
  SharedPreferences? _prefs;

  /// Si el defensor apagó [id].
  bool off(String id) => _on && _apagadas.contains(id);

  /// Lo apagado, en el orden en que se apagó.
  final List<String> _orden = [];
  List<String> get apagadas => List.unmodifiable(_orden);

  /// Lo que tardaron los últimos fotogramas, de media, en milisegundos. Para
  /// enseñarlo en los ajustes.
  double get ultimaMedida => _ultima;
  double _ultima = 0;

  /// Las pantallas abiertas, la de arriba la última.
  final List<PerfScene> _pantallas = [];
  PerfScene get scene =>
      _pantallas.isEmpty ? PerfScene.pueblo : _pantallas.last;

  void enter(PerfScene s) {
    _pantallas.add(s);
    _reiniciar();
  }

  void leave(PerfScene s) {
    final i = _pantallas.lastIndexOf(s);
    if (i >= 0) _pantallas.removeAt(i);
    _reiniciar();
  }

  /// Cuántas veces por segundo se dibuja lo que se mueve solo, cuando hay
  /// tope: treinta, o veinte si el defensor lo bajó.
  double get fps => off('cuadros') ? 20 : 30;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _on = _prefs!.getBool(_keyOn) ?? false;
      final guardadas = _prefs!.getStringList(_key) ?? const [];
      for (final id in guardadas) {
        if (steps.any((s) => s.id == id) && _apagadas.add(id)) _orden.add(id);
      }
    } catch (_) {
      // Sin dónde guardar, el defensor trabaja igual; sólo no recuerda.
    }
    if (!_on) {
      // Apagado: lo que hubiera apagado antes, cuando venía encendido de
      // fábrica, vuelve a estar encendido.
      if (_orden.isNotEmpty) await reset();
      return;
    }
    _aplicar();
    _escuchar();
  }

  /// Vuelve a encender todo. Si el teléfono sigue sin llegar, el defensor
  /// volverá a apagar lo que haga falta.
  Future<void> reset() async {
    _apagadas.clear();
    _orden.clear();
    RenderDebug.instance.set((d) {
      d.bloom = true;
      d.shadows = true;
      d.rays = true;
      d.grade = true;
      d.water = true;
    });
    _reiniciar();
    await _guardar();
    notifyListeners();
  }

  void _aplicar() {
    RenderDebug.instance.set((d) {
      if (off('resplandor')) d.bloom = false;
      if (off('sombras')) d.shadows = false;
      if (off('rayos')) d.rays = false;
      if (off('color')) d.grade = false;
      if (off('agua')) d.water = false;
    });
  }

  Future<void> _guardar() async {
    try {
      await _prefs?.setStringList(_key, _orden);
    } catch (_) {}
  }

  // ------------------------------------------------------------- la medida

  bool _escuchando = false;

  /// Lo que costó cada fotograma de la ventana que se está midiendo, en
  /// milisegundos.
  final List<double> _costes = [];

  /// Hasta cuándo no se mide: al arrancar —la primera vez que se dibuja
  /// cada cosa siempre se traba, y no dice nada del teléfono—, después de
  /// cada apagón y al cambiar de pantalla.
  Duration _esperaHasta = const Duration(seconds: 8);
  Duration _reloj = Duration.zero;
  Duration? _antes;

  /// Fotogramas que hacen falta para decidir.
  static const int _ventana = 90;

  /// Cuánto puede tardar un fotograma. Con tope de [fps] en el teléfono,
  /// lo que dura cada uno menos un margen; sin tope, sesenta por segundo.
  double get _limite => _conTope ? 1000 / fps * 0.80 : 1000 / 60 * 1.3;
  bool get _conTope =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      off('cuadros');

  void _escuchar() {
    if (_escuchando) return;
    _escuchando = true;
    if (kIsWeb) {
      // En la web el navegador no cuenta lo que tardó cada fotograma: se
      // mide lo que pasa entre uno y el siguiente.
      SchedulerBinding.instance.addPersistentFrameCallback(_entreFotogramas);
    } else {
      SchedulerBinding.instance.addTimingsCallback(_tiempos);
    }
  }

  void _reiniciar() {
    _costes.clear();
    if (!kIsWeb) _reloj = _cronometro.elapsed;
    _esperaHasta = _reloj + const Duration(seconds: 3);
  }

  final Stopwatch _cronometro = Stopwatch()..start();

  void _tiempos(List<FrameTiming> lista) {
    _reloj = _cronometro.elapsed;
    for (final t in lista) {
      if (_reloj < _esperaHasta) continue;
      final build = t.buildDuration.inMicroseconds / 1000;
      final raster = t.rasterDuration.inMicroseconds / 1000;
      _anotar(math.max(build, raster));
    }
  }

  void _entreFotogramas(Duration ahora) {
    final antes = _antes;
    _antes = ahora;
    _reloj = ahora;
    if (antes == null || ahora < _esperaHasta) return;
    final ms = (ahora - antes).inMicroseconds / 1000;
    // Un hueco largo es que no había nada que mover, no que tardara.
    if (ms > 300) return;
    // Entre dos fotogramas cuenta también la espera del tope: lo que se
    // mide es si se llega a tiempo, así que el límite es el del tope.
    _anotar(ms * 0.8);
  }

  void _anotar(double ms) {
    if (!_on) return;
    _costes.add(ms);
    if (_costes.length < _ventana) return;
    _costes.sort();
    // La mitad más cara: con el tope de cuadros, uno de cada dos fotogramas
    // no dibuja nada y cuesta casi cero, y con la media de todos un teléfono
    // que no llega parecía que sí.
    final caros = _costes.sublist(_costes.length ~/ 2);
    final media = caros.reduce((a, b) => a + b) / caros.length;
    _ultima = media;
    _costes.clear();
    if (media > _limite) _apagarOtra();
  }

  /// Para las pruebas: un fotograma que costó [ms], sin esperas.
  @visibleForTesting
  void debugFeed(double ms) => _anotar(ms);

  /// Para las pruebas: todo encendido, sin pantallas y sin tocar lo
  /// guardado.
  @visibleForTesting
  void debugClear() {
    _apagadas.clear();
    _orden.clear();
    _pantallas.clear();
    _costes.clear();
  }

  void _apagarOtra() {
    final aqui = scene;
    PerfStep? toca;
    for (final s in steps) {
      if (off(s.id)) continue;
      if (s.donde.contains(aqui)) {
        toca = s;
        break;
      }
    }
    // Si en esta pantalla ya no queda nada que apagar, lo siguiente de
    // cualquier otra, que también se dibuja detrás.
    toca ??= steps.where((s) => !off(s.id)).firstOrNull;
    if (toca == null) return;
    _apagadas.add(toca.id);
    _orden.add(toca.id);
    _aplicar();
    _reiniciar();
    _guardar();
    notifyListeners();
  }
}
