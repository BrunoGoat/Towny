import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/character.dart';
import 'engine/palette.dart';
import 'fx/notifier.dart';
import 'fx/sensory.dart';
import 'fx/widget_bridge.dart';
import 'model/appearance.dart';
import 'model/arrival.dart';
import 'model/board_seen.dart';
import 'model/board_slots.dart';
import 'model/reel.dart';
import 'model/store.dart';
import 'ui/first_run.dart';
import 'ui/gallery_screen.dart';
import 'ui/home_screen.dart';
import 'ui/reel_screen.dart';
import 'ui/style.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  // The first frame goes up straight away; loading happens behind it, so a
  // slow disk can never turn into a blank screen.
  runApp(const PuebloApp());
}

class PuebloApp extends StatefulWidget {
  const PuebloApp({super.key});

  @override
  State<PuebloApp> createState() => _PuebloAppState();
}

class _PuebloAppState extends State<PuebloApp> with WidgetsBindingObserver {
  final Store store = Store();

  /// Para poder poner la cinemática de lo que llegó encima de lo que haya sin
  /// tener que pedirle el contexto a nadie.
  final GlobalKey<NavigatorState> _nav = GlobalKey<NavigatorState>();

  /// Verdadero mientras se está mirando. Dos entregas seguidas —tocaste el
  /// widget, volviste, y tocaste otra vez sin salir— no pueden apilar dos
  /// cinemáticas una encima de la otra.
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Para enterarse de que alguien pidió ver la primera vez otra vez desde
    // ajustes: es lo único de las preferencias que cambia qué pantalla se está
    // mirando, y sin esto no pasaba nada hasta reiniciar la app.
    Appearance.instance.addListener(_prefsChanged);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Appearance.instance.removeListener(_prefsChanged);
    super.dispose();
  }

  /// Leave the app and the valley goes quiet; come back and it starts again.
  ///
  /// Without this the loops keep playing out of a phone that is showing
  /// something else entirely, and the only way to stop them is to throw the
  /// app out of the recents list — which is not something anybody should have
  /// to work out on their own.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Sensory.instance.wake();
      _replan();
      // Y lo que se haya tocado en la pantalla de inicio mientras tanto.
      _collect();
    } else {
      Sensory.instance.sleep();
      // Y lo que va a sonar mientras la app no esté se programa ahora, que es
      // el único momento en que se sabe cómo quedó todo. La app no corre de
      // fondo: lo que no quede puesto acá, no suena.
      _replan();
      // And anything changed a moment ago goes to disk now, rather than
      // waiting for a timer that may not get another turn.
      Appearance.instance.flush();
      // Y el cuadrito de la pantalla de inicio se queda con lo de ahora, que
      // es lo que va a estar mirando quien acaba de salir de la app.
      WidgetBridge.instance.publish(store.habits);
    }
  }

  /// Vuelve a programar los avisos desde cero.
  ///
  /// Entero cada vez y no un ajuste de lo que hubiera: es más barato que
  /// llevar la cuenta de qué hay puesto, y es lo único que garantiza que poner
  /// una pieza cancele el aviso que iba a decir que hace días que no ponés
  /// ninguna.
  void _replan() {
    if (store.habits.isEmpty) return;
    Notifier.instance.reschedule(
      store.habits,
      DateTime.now(),
      on: !Appearance.instance.nudgesOff,
    );
  }

  void _prefsChanged() {
    if (mounted) setState(() {});
  }

  /// Fundar el primer pueblo con lo que se contestó en la primera pantalla.
  ///
  /// Se le pone el nombre al hábito en blanco con el que arranca el valle en
  /// vez de crear uno: ese hueco ya existe, ya tiene su solar y ya tiene su
  /// región sorteada. Crear otro dejaría el de fábrica al lado, vacío.
  Future<void> _found(
    String name,
    String symbol,
    String? why,
    String? floor,
  ) async {
    store.renameHabit(
      0,
      name: name.isEmpty ? 'Mi hábito' : name,
      symbol: symbol,
    );
    store.describeHabit(0, why: why, floor: floor);
    store.justFounded = true;
    await Appearance.instance.setOnboarded();
    if (mounted) setState(() {});
    _replan();
    // Recién fundado ya hay algo que enseñar afuera.
    WidgetBridge.instance.publish(store.habits);
  }

  // ------------------------------------------- lo que llegó desde el inicio

  /// Recoge lo que se tocó en el widget, lo pone, y lo enseña caer.
  ///
  /// El orden no es casual. Primero se lee el buzón y se ponen las piezas;
  /// después se le dice al buzón que ya puede olvidarlas —nunca antes, porque
  /// entre las dos cosas la app se puede morir y lo que no está confirmado
  /// vuelve a llegar—; y al final se publica el resumen, que ya lleva las
  /// piezas puestas.
  Future<void> _collect() async {
    if (!store.loaded) return;
    final buzon = await WidgetBridge.instance.drain();
    if (buzon.isNotEmpty) {
      final puestas = store.applyArrivals(buzon);
      var ultimo = 0;
      for (final a in buzon) {
        if (a.serial > ultimo) ultimo = a.serial;
      }
      await WidgetBridge.instance.ack(ultimo);
      if (puestas.isNotEmpty && mounted) {
        setState(() {});
        _watch(puestas);
      }
    }
    await WidgetBridge.instance.publish(store.habits);
    _replan();
  }

  /// Y enseñarlas caer, que es la mitad de por qué se pone una pieza.
  ///
  /// Poner una desde la pantalla de inicio se lleva por delante lo único que
  /// esta app tiene de recompensa: la piedra bajando, el golpe, el polvo. Esto
  /// lo devuelve — no como un resumen de lo que pasó, sino pasando.
  void _watch(List<Arrival> puestas) {
    if (_watching) return;
    // Antes de fundar no hay pueblo sobre el que caiga nada, y la pantalla de
    // la primera vez no se interrumpe por nada.
    if (!Appearance.instance.onboarded) return;
    final pasos = <ReelStep>[];
    for (final a in puestas) {
      final at = store.habits.indexWhere((h) => h.id == a.habitId);
      if (at < 0) continue;
      pasos.add(ReelStep(a.when, at, null));
    }
    if (pasos.isEmpty) return;
    pasos.sort((a, b) => a.when.compareTo(b.when));
    _watching = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final nav = _nav.currentState;
      if (nav == null) {
        _watching = false;
        return;
      }
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => ReelScreen.arrivals(store: store, pieces: pasos),
        ),
      );
      _watching = false;
    });
  }

  Future<void> _boot() async {
    await Appearance.instance.load();
    await BoardSlots.instance.load();
    await BoardSeen.instance.load();
    await store.load();
    // Quien ya tenía pueblo no pasa por la pantalla de la primera vez, y no se
    // entera de que existe. Se apunta como pasada y a otra cosa.
    if (!Appearance.instance.onboarded && store.total > 0) {
      await Appearance.instance.setOnboarded();
    }
    _replan();

    // Development shortcut for inspecting how the wall reads after weeks or a
    // year of real use. Off unless explicitly compiled in.
    const seed = int.fromEnvironment('SEED');
    const idleDays = int.fromEnvironment('IDLE_DAYS');
    // Which of the six regions to build it in, for looking at one of them on
    // its own. The valley below shows all six at once, but from far enough
    // away that a thatched eave is two pixels.
    const region = int.fromEnvironment('REGION', defaultValue: -1);
    if (seed > 0 && store.total == 0) {
      if (region >= 0) {
        // Founded rather than edited: a town's region is chosen once, when it
        // is founded, and there is no way to change it afterwards on purpose.
        store.addHabit(
          'Leer',
          'libro',
          character: TownCharacter.forSlot(region).order,
        );
        store.removeHabit(0);
      }
      store.debugFill(seed, endedDaysAgo: idleDays);
    }
    // A whole valley, for looking at several habits side by side without
    // keeping four of them for a year first. Off unless compiled in.
    const valley = String.fromEnvironment('VALLEY');
    if (valley.isNotEmpty && store.habits.length == 1) {
      // Seis, que son las seis regiones: un valle de prueba al que le falta
      // una de ellas no sirve para comparar las seis.
      const names = [
        'Leer',
        'Correr',
        'Estudiar',
        'Guitarra',
        'Nadar',
        'Pintar',
      ];
      const symbols = ['libro', 'carrera', 'pesa', 'laud', 'ola', 'pluma'];
      final parts = valley.split(',');
      for (var i = 0; i < parts.length && i < names.length; i++) {
        final bits = parts[i].split(':');
        final n = int.tryParse(bits.first) ?? 0;
        final idle = bits.length > 1 ? (int.tryParse(bits[1]) ?? 0) : 0;
        if (i == 0) {
          store.renameHabit(0, name: names[0], symbol: symbols[0]);
          if (n > 0) store.debugFill(n, endedDaysAgo: idle, into: 0);
        } else {
          store.addHabit(names[i], symbols[i]);
          if (n > 0) store.debugFill(n, endedDaysAgo: idle);
        }
      }
      store.select(0);
    }

    if (mounted) setState(() {});
    Sensory.instance.init();
    // Lo último del arranque: recoger lo del widget y dejarlo publicado. Al
    // final y no al principio porque para entonces el valle ya está cargado y
    // las piezas que lleguen caen sobre el pueblo que les toca.
    _collect();
  }

  static const int _gallery = int.fromEnvironment('GALLERY', defaultValue: -1);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Towny',
      navigatorKey: _nav,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD6C9A8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFF9FB6D8),
      ),
      // Straight into the exhibition hall, for looking at one recipe without
      // walking through the app to reach it. Off unless compiled in.
      home: !store.loaded
          ? const _Opening()
          : (_gallery >= 0
                ? GalleryScreen(
                    theme: UiTheme(Palette.forMoment(11, 1)),
                    start: _gallery,
                  )
                : (Appearance.instance.onboarded
                      ? HomeScreen(store: store)
                      : FirstRun(onDone: _found))),
    );
  }
}

/// The first half-second: the valley, before there is a town in it.
class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9FB6D8),
      body: Center(
        child: Text(
          'EL PUEBLO',
          style: TextStyle(
            color: Color(0xCC241F16),
            fontSize: 15,
            letterSpacing: 6,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
