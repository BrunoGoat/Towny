import 'dart:async';

import 'package:flutter/material.dart';

import '../data/landmarks.dart';
import '../engine/palette.dart';
import '../fx/sensory.dart';
import '../model/appearance.dart';
import '../model/board.dart';
import '../model/board_seen.dart';
import '../model/habit.dart';
import '../model/piece.dart';
import '../model/store.dart';
import 'adrift_sheet.dart';
import 'board_glyph.dart';
import 'choice_sheet.dart';
import 'cloud_flight.dart';
import 'habits_sheet.dart';
import 'home_chrome.dart';
import 'lectern_glyph.dart';
import 'legends_book.dart';
import 'notice_board.dart';
import 'overlays.dart';
import 'rest_sheet.dart';
import 'settings_sheet.dart';
import 'style.dart';
import 'town_sign.dart';
import 'town_view.dart';
import 'unlock_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final Store store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TownViewController _wall = TownViewController();

  /// El color de la interfaz, sacado de la luz que hay en el valle.
  ///
  /// Arranca en la hora de ahora y no en un mediodía de mentira. Con el
  /// mediodía clavado, entrar de noche era entrar en pardo: el primer
  /// fotograma iba con la tinta del mediodía, el pueblo avisaba de la luz de
  /// verdad un fotograma después y los rótulos cambiaban de color en la cara
  /// de quien acababa de abrir la app. Con la hora de verdad no hay nada que
  /// corregir después.
  late UiTheme _theme = UiTheme(
    Palette.forMoment(
      Appearance.instance.hourNow,
      1,
      season: Appearance.instance.season,
    ),
  );

  /// A landmark of the town, and which number it is, waiting to be shown.
  (Landmark, int)? _revealTown;

  /// The piece just laid, while its card is still up.
  String? _whisper;
  Timer? _whisperTimer;

  /// El cartel del pueblo al que acabás de entrar: qué dice, con qué diseño de
  /// los cinco, y un número que cambia en cada anuncio para que la animación
  /// vuelva a empezar aunque el pueblo sea el mismo.
  (String, String, int)? _sign;
  Timer? _signTimer;

  /// Si el cartel está yéndose porque alguien movió la cámara.
  bool _signOut = false;

  /// El cartel del pueblo se quita en cuanto alguien mueve la cámara.
  ///
  /// Dura lo que dura por si uno se queda quieto leyendo, pero mover la cámara
  /// es decir «ya sé dónde estoy, quiero mirar»: a partir de ahí el cartel es
  /// algo en medio. Y se va desvaneciendo, no de un tirón: quitarlo del árbol
  /// en el primer dedo lo hacía desaparecer entre dos cuadros, que se lee como
  /// un fallo y no como que se aparta.
  void _dismissSign() {
    if (_sign == null || _signOut) return;
    _signTimer?.cancel();
    setState(() => _signOut = true);
  }

  int _signNonce = 0;

  /// Cuál de las cinco maneras de anunciar la pieza le tocó a ésta. Se sortea
  /// al caer y no al pintar: si se sorteara al pintar, cambiaría de diseño en
  /// cada cuadro.
  static const Duration _signLife = Duration(milliseconds: 2600);
  Piece? _selected;

  /// De qué pueblo es la pieza elegida.
  ///
  /// Una pieza se identifica por su número dentro de su pueblo, así que al
  /// cambiar de pueblo la número uno de allá pasaba a ser la elegida sin que
  /// nadie la tocara: uno se iba al pueblo de al lado y se encontraba abierta
  /// la leyenda de su primera pieza.
  String? _selectedTown;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    Appearance.instance.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _greet();
      _lookForNews();
      _askIfAdrift();
    });
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    Appearance.instance.removeListener(_onStore);
    _whisperTimer?.cancel();
    _signTimer?.cancel();
    _flight.dispose();
    super.dispose();
  }

  void _onStore() {
    // Keep the open card in step with the store, so a note written now shows
    // up on the card straight away.
    if (_selected != null) {
      if (_selectedTown != widget.store.habit.id) {
        _selected = null;
        _selectedTown = null;
      } else {
        _selected = widget.store.pieceAt(_selected!.index);
      }
    }
    setState(() {});
    // Una pieza más, una leyenda escrita o un cambio de pueblo pueden haberle
    // dado al tablón algo nuevo que decir.
    _lookForNews();
  }

  /// Una línea al abrir.
  ///
  /// Y de todas las líneas de la app, ésta es la que más importa, porque el
  /// momento en que alguien vuelve después de tres semanas fuera pesa mucho
  /// más que su primer día. Ahí hay una bifurcación: o «volví, pero perdí
  /// todo y estoy atrasadísimo», o «volví, sigamos». Lo primero es vergüenza y
  /// deuda; lo segundo es continuidad, y es lo único que hace que haya una
  /// cuarta vez.
  ///
  /// Decía «17 días sin piezas. El pueblo se está quedando a oscuras.», que es
  /// recibir a alguien con la cuenta de su ausencia. El dato era cierto y no
  /// servía para nada: quien vuelve ya sabe que estuvo fuera. Lo único que
  /// hacía falta decirle es que no tiene nada que justificar y que una sola
  /// pieza lo arregla entero — que en esta app, además, es literalmente verdad.
  void _greet() {
    final s = widget.store;
    final h = s.habit;
    if (s.total == 0) {
      _showWhisper(
        'Mantené el botón para poner tu primera piedra',
        duration: const Duration(seconds: 6),
      );
      return;
    }
    if (h.resting) {
      _showWhisper(
        'Este pueblo está durmiendo. Podés poner una pieza igual.',
        duration: const Duration(seconds: 4),
      );
      return;
    }
    if (s.integrityAtLaunch >= 0.92) return;
    // Cuanto más tiempo estuvo fuera, más claro hay que decirle que no hay
    // nada que recuperar. El caso largo es el que se pierde si se calla.
    final largo = s.daysIdle >= 10;
    var vuelta = largo
        ? 'El pueblo te estaba esperando. No perdiste nada: una pieza y '
              'vuelven las luces.'
        : 'Acá seguís. Una pieza y el pueblo vuelve a encenderse.';
    // Y en el hueco largo, lo que vos mismo escribiste el día que fundaste
    // esto — el motivo primero, y si no hay, lo mínimo que cuenta. Éste es
    // justo el momento para el que se guardaron: no hacen falta cuando hay
    // ganas, hacen falta cuando ya no las hay.
    if (largo) {
      final suyo = h.why ?? h.floor;
      if (suyo != null) vuelta = '$vuelta\n«$suyo»';
    }
    _showWhisper(vuelta, duration: Duration(seconds: largo ? 7 : 5));
  }

  /// Anunciar el pueblo. Sale uno de los cinco diseños al azar, para poder
  /// verlos todos usando la app y quedarse con uno.
  void _announceTown() {
    final h = widget.store.habit;
    _signTimer?.cancel();
    setState(() {
      _sign = (h.name, h.symbol, ++_signNonce);
      _signOut = false;
    });
    _signTimer = Timer(_signLife, () {
      if (mounted) setState(() => _sign = null);
    });
  }

  void _showWhisper(
    String msg, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _whisperTimer?.cancel();
    setState(() => _whisper = msg);
    _whisperTimer = Timer(duration, () {
      if (mounted) setState(() => _whisper = null);
    });
  }

  /// Alguien tocó la figura que hay en el cielo esta noche.
  ///
  /// Y no pasa **nada más** que un sonido. No se anota en ningún sitio, no hay
  /// ocho que juntar, no dice cómo se llama y no cuenta nada de ella.
  ///
  /// Llegó a decirlo: salía su nombre y una frase con lo que se sabe de la
  /// figura. Estaba bien escrito y sobraba igual — una constelación acá no es
  /// contenido, es el cielo, y un cielo que te explica cosas cuando lo tocás
  /// deja de ser cielo y pasa a ser una pantalla con información. Lo que tiene
  /// que hacer es estar ahí para quien mire hacia arriba, sonar si lo tocan, y
  /// callarse.
  ///
  /// Ni siquiera hace falta saber cuál es: el identificador llega del propio
  /// dibujo y no se usa para nada, porque las ocho suenan igual.
  void _wishOn(String id) => Sensory.instance.star();

  /// El tablón de este pueblo, desde el botón.
  void _readOwnBoard() {
    final store = widget.store;
    Navigator.of(context)
        .push(
          NoticeBoardScreen.route(
            valley: store.habits,
            habit: store.habit,
            theme: _theme,
            store: store,
          ),
        )
        // Al volver se repinta: dentro se habrán leído notas, y el punto del
        // botón tiene que estar apagado ya cuando se vuelve a ver el pueblo.
        .then((_) => _lookForNews());
  }

  /// Si el tablón de este pueblo tiene algo clavado que no leíste.
  ///
  /// Guardado y no calculado al pintar. Saberlo cuesta releer todas las piezas
  /// del pueblo —eso es lo que hace el tablón— y esto se pinta en cada
  /// fotograma mientras la cámara se mueve. Se vuelve a mirar cuando puede
  /// haber cambiado: al arrancar, cuando el almacén se mueve —una pieza, una
  /// leyenda, cambiar de pueblo— y al salir del tablón.
  bool _news = false;

  void _lookForNews() {
    final store = widget.store;
    final hay =
        BoardSeen.instance.unread(
          store.habit.id,
          boardNotices(store.habit, valley: store.habits),
        ) >
        0;
    if (hay != _news && mounted) setState(() => _news = hay);
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final store = widget.store;
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: t.palette.skyTop,
      body: Stack(
        children: [
          Positioned.fill(
            child: TownView(
              store: store,
              controller: _wall,
              onTownLandmark: (mark, ordinal) {
                if (Appearance.instance.rapid) return;
                setState(() => _revealTown = (mark, ordinal));
              },
              onPlaced: (piece) {
                // In the testing mode the pieces come far too fast for a card
                // to be anything but in the way.
                if (Appearance.instance.rapid) return;
                setState(() {});
                _askWhatToBuild();
              },
              onStoneTapped: (brick) => setState(() {
                _selected = brick;
                _selectedTown = widget.store.habit.id;
              }),
              onCameraMoved: _dismissSign,
              onFlewOut: _flyToValley,
              onNothingTapped: () {
                if (_selected != null) setState(() => _selected = null);
              },
              onSkyTapped: _wishOn,
              onTownTapped: (i) {
                store.select(i);
                _announceTown();
              },
              onBoardTapped: _readBoard,
              onLecternTapped: _openBook,
              onWhisper: _showWhisper,
              onPaletteChanged: (p) {
                final next = UiTheme(p);
                if (next.dark != _theme.dark ||
                    next.accent != _theme.accent ||
                    next.palette.skyClean != _theme.palette.skyClean) {
                  setState(() => _theme = next);
                }
              },
            ),
          ),

          // --- top: the numbers, set straight on the scene
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: media.padding.top + 130,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      t.palette.ink.withValues(alpha: t.dark ? 0.34 : 0.14),
                      t.palette.ink.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: media.padding.top + 12,
            left: 22,
            right: 14,
            child: TopBar(theme: t, store: store, onSettings: _openSettings),
          ),

          // --- right: mirar, y entrar
          //
          // Arriba, las tres maneras de mirar: este pueblo entero, la última
          // pieza que pusiste, y el valle entero. Debajo de una raya, las
          // puertas: sitios donde se entra y de los que se sale, que es otra
          // cosa. La raya está porque sin ella son cinco iconos en fila y
          // ninguno dice a cuál de las dos familias pertenece.
          Positioned(
            right: 10,
            top: media.padding.top + 92,
            child: Column(
              children: [
                GhostButton(
                  icon: Icons.zoom_out_map,
                  theme: t,
                  tooltip: 'Ver todo el pueblo',
                  onTap: _wall.frameAll,
                ),
                GhostButton(
                  icon: Icons.center_focus_strong,
                  theme: t,
                  tooltip: 'Ir a donde cae la siguiente',
                  onTap: _wall.lookAtNext,
                ),
                if (store.habits.length > 1)
                  GhostButton(
                    icon: Icons.travel_explore,
                    theme: t,
                    tooltip: 'Ver todo el valle',
                    onTap: _flyToValley,
                  ),
                Container(
                  width: 18,
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 7),
                  color: t.fg.withValues(alpha: 0.18),
                ),
                GhostButton(
                  // El tablón mismo y no una chincheta: lo que se abre tiene
                  // esa forma, con sus postes y su tejadito, y así el botón se
                  // parece a donde lleva.
                  glyph: (c) => BoardGlyph(color: c, shadows: t.halo),
                  theme: t,
                  tooltip: 'El tablón del pueblo',
                  // El punto: hay algo clavado que no leíste. Del color de la
                  // hora, como todo lo demás — a las tres de la mañana un
                  // naranja de mediodía es una mancha que no es de aquí.
                  dot: _news ? t.accent : null,
                  onTap: _readOwnBoard,
                ),
                // Y debajo el atril, que está al lado en la plaza y tiene que
                // estar al lado aquí. El mueble mismo y no un libro genérico,
                // por lo mismo que el tablón no es una chincheta.
                GhostButton(
                  glyph: (c) => LecternGlyph(color: c, shadows: t.halo),
                  theme: t,
                  tooltip: 'El libro de las leyendas',
                  onTap: _openOwnBook,
                ),
              ],
            ),
          ),

          // --- preview mode: impossible to forget you are in it
          if (store.isPreviewing)
            Positioned(
              top: media.padding.top + 100,
              left: 0,
              right: 0,
              child: Center(
                child: PreviewBanner(theme: t, store: store),
              ),
            ),

          // --- the tapped stone, and its optional note
          if (_selected != null)
            Positioned(
              left: 14,
              right: 14,
              // Se queda donde está aunque salga el teclado. Se probó a
              // subirla por encima y quedaba flotando en mitad de la pantalla;
              // desde su sitio de siempre se lee bien igual.
              bottom: media.padding.bottom + 214,
              child: Center(
                child: StoneCard(
                  key: ValueKey(_selected!.index),
                  theme: t,
                  when: _selected!.placedAt,
                  number: _selected!.index + 1,
                  label: _selected!.label,
                  onWrite: (text) => setState(() {
                    store.setLabel(_selected!.index, text);
                    _selected = store.pieceAt(_selected!.index);
                  }),
                  onWhen: (when) => setState(() {
                    store.setPlacedAt(_selected!.index, when);
                    _selected = store.pieceAt(_selected!.index);
                  }),
                ),
              ),
            ),

          if (_sign != null)
            Positioned.fill(
              child: TownSignOverlay(
                key: ValueKey(_sign!.$3),
                name: _sign!.$1,
                symbol: _sign!.$2,
                theme: t,
                life: _signLife,
                leaving: _signOut,
                onGone: () {
                  if (mounted) setState(() => _sign = null);
                },
              ),
            ),

          if (_whisper != null && _selected == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: media.padding.bottom + 222,
              child: Center(
                child: Whisper(message: _whisper!, theme: t),
              ),
            ),

          // --- bottom: travel, then the one button
          // The card for the piece just laid, riding above the deck and out of
          // the way of the keyboard when it comes up.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomDeck(
              theme: t,
              placed: store.total,
              plan: store.plan,
              store: store,
              onSelect: (i) {
                widget.store.select(i);
                _announceTown();
              },
              onManage: _openHabits,
              onAdd: _addHabit,
              wall: _wall,
              onPlace: () {
                _wall.clearSelection();
                setState(() => _selected = null);
                _wall.place();
              },
            ),
          ),

          // El vuelo, por encima de todo lo demás: mientras dura, lo que se ve
          // es el cielo, y los botones del pueblo que se deja no pintan nada
          // ahí. Va el último del montón porque tiene que tapar también a los
          // carteles y a las hojas que pudieran estar abiertas.
          if (_flying)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _flight,
                builder: (_, _) =>
                    CloudFlight(t: _flight.value, palette: t.palette),
              ),
            ),

          if (_revealTown != null)
            Positioned.fill(
              child: TownLandmarkOverlay(
                mark: _revealTown!.$1,
                ordinal: _revealTown!.$2,
                theme: t,
                onDismiss: () => setState(() => _revealTown = null),
              ),
            ),
        ],
      ),
    );
  }

  /// El más de la barra. Dos puertas distintas detrás del mismo botón: la de
  /// fundar, y la de enterarse de cuánto falta para poder.
  void _addHabit() {
    if (widget.store.canAddHabit) {
      _openHabits(startNew: true);
      return;
    }
    if (widget.store.unlocked) return; // el valle está lleno, y eso no se abre
    Sensory.instance.tick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: sheetScrim(_theme.dark),
      builder: (_) => UnlockSheet(store: widget.store, theme: _theme),
    );
  }

  void _openHabits({bool startNew = false}) {
    Sensory.instance.tick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: sheetScrim(_theme.dark),
      builder: (_) =>
          HabitsSheet(store: widget.store, theme: _theme, startNew: startNew),
    );
  }

  /// The notice board of one town. Reading another town's board does not move
  /// you there: you can stand in your own plaza and read what the next valley
  /// over has worked out about itself.
  /// Si el pueblo tiene algo que preguntar, preguntarlo.
  ///
  /// Justo después de que caiga la pieza que empezaría la obra, que es el
  /// único momento en que la pregunta tiene sentido: antes no se ve venir, y
  /// después ya habría piedra puesta de algo que se elegiría luego.
  ///
  /// Se espera a que termine el fotograma de la pieza cayendo. Una hoja que
  /// sube encima del polvo y del sonido le pisa a la pieza su momento, que es
  /// lo único que esta app celebra.
  void _askWhatToBuild() {
    if (_asking) return;
    final options = widget.store.pendingChoice;
    if (options == null) return;
    _asking = true;
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) {
        _asking = false;
        return;
      }
      final ahora = widget.store.pendingChoice;
      if (ahora == null) {
        _asking = false;
        return;
      }
      Sensory.instance.tick();
      // En el medio de la pantalla y no subiendo desde abajo. Una hoja que
      // sube es para lo que uno pide; esto no lo pidió nadie —sale solo, una
      // vez cada varias semanas— y lo que hace es parar el valle un momento
      // para preguntar. Eso se pone delante, no debajo.
      showDialog<void>(
        context: context,
        barrierColor: sheetScrim(_theme.dark),
        builder: (_) => ChoiceSheet(
          options: ahora,
          place: widget.store.habit.place,
          theme: _theme,
          onPick: (mark) => widget.store.chooseWork(mark.id),
          onLeave: widget.store.letThemDecide,
        ),
      ).whenComplete(() {
        _asking = false;
        // Tocar fuera de la tarjeta también es cerrarla sin contestar, y no
        // pasa por ningún botón. Si sigue sin contestarse, deciden ellos.
        widget.store.letThemDecide();
      });
    });
  }

  /// Para no abrir dos hojas si caen dos piezas seguidas muy rápido.
  bool _asking = false;

  // ------------------------------------------------------------ desenganche

  /// Si el pueblo tiene algo que preguntar sobre un hueco largo, preguntarlo.
  ///
  /// Al abrir la app y no al poner una pieza, que es justo al revés que la
  /// otra pregunta: ésta trata sobre no haber puesto ninguna. Y detrás del
  /// saludo, porque lo primero que tiene que pasar al volver es que te reciban
  /// —una hoja encima del susurro de vuelta convierte el regreso en un
  /// trámite, que es exactamente lo que no puede pasar acá.
  void _askIfAdrift() {
    if (_asking) return;
    final store = widget.store;
    final h = store.adrift;
    if (h == null) return;
    _asking = true;
    final days = store.daysIdle.floor();
    // Detrás del saludo y no encima. Lo primero que tiene que pasar al volver
    // es que te reciban; una hoja subiendo sobre el susurro de bienvenida
    // convierte el regreso en un trámite.
    Future.delayed(const Duration(milliseconds: 4200), () {
      if (!mounted) {
        _asking = false;
        return;
      }
      // Que conste ahora y no antes de la espera: si la app se cierra en esos
      // cuatro segundos, la pregunta no llegó a hacerse y tiene que seguir
      // pendiente. Y desde acá vale para cualquier respuesta, incluida cerrar
      // la hoja sin contestar — eso también es contestar «ahora no», y volver
      // a preguntar mañana sería no haberlo oído.
      store.asked(h);
      _whisperTimer?.cancel();
      setState(() => _whisper = null);
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: sheetScrim(_theme.dark),
        builder: (_) => AdriftSheet(
          habit: h,
          theme: _theme,
          days: days,
          onKeep: () => _showWhisper('Acá seguimos.'),
          // Lo mínimo que cuenta se escribe donde se escribe todo lo del
          // hábito, y no en una copia del campo dentro de esta hoja: hay una
          // sola manera de cambiarlo y está en un solo sitio.
          onShrink: _openHabits,
          onRest: () => _openRest(h),
          onDrop: _openHabits,
        ),
      ).whenComplete(() => _asking = false);
    });
  }

  /// Dormir un pueblo: desde la pregunta, y desde la hoja del hábito.
  void _openRest(Habit h) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: sheetScrim(_theme.dark),
      builder: (_) => RestSheet(
        habit: h,
        theme: _theme,
        onRest: (until) {
          widget.store.rest(h, until);
          _showWhisper(
            'El pueblo duerme. Volvé cuando puedas: no cuenta ningún día.',
            duration: const Duration(seconds: 5),
          );
        },
      ),
    );
  }

  void _readBoard(int town) {
    final store = widget.store;
    if (town < 0 || town >= store.habits.length) return;
    Navigator.of(context).push(
      NoticeBoardScreen.route(
        valley: store.habits,
        habit: store.habits[town],
        theme: _theme,
        store: store,
      ),
    );
  }

  /// El atril de este pueblo, desde el botón.
  void _openOwnBook() => _openBook(widget.store.active);

  /// El atril de un pueblo: su libro de leyendas.
  void _openBook(int town) {
    final store = widget.store;
    if (town < 0 || town >= store.habits.length) return;
    Navigator.of(
      context,
    ).push(LegendsBook.route(habit: store.habits[town], theme: _theme));
  }

  // ------------------------------------------------------------- el vuelo

  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: CloudFlight.span,
  );
  bool _flying = false;

  /// Subir al valle: despegar, taparse con nubes, y aparecer arriba.
  ///
  /// Lo llaman dos cosas y hacen lo mismo a propósito: el botón de explorar el
  /// valle, y apartarse con los dedos hasta que el pueblo deja de ser el
  /// asunto. Pedirlo de las dos maneras tiene que llevar al mismo sitio por el
  /// mismo camino.
  void _flyToValley() {
    if (_flying || !_wall.hasValley || _wall.aloft) return;
    // El cartel del pueblo se va con el pueblo.
    //
    // Aparece en mitad de la pantalla al llegar a uno y dura dos segundos y
    // pico, así que tocar el botón del valle justo después lo dejaba colgado
    // sobre la vista aérea: el nombre de un sitio en el que ya no se está,
    // encima de otro sitio. Alejarse con los dedos ya lo apartaba —eso lo hace
    // `onCameraMoved`— pero el botón no pasa por ahí.
    _dismissSign();
    setState(() => _flying = true);
    Sensory.instance.tick();
    _wall.liftOff();

    // El corte va justo en la mitad, que es donde las nubes tapan del todo.
    var llego = false;
    void mirar() {
      if (llego || _flight.value < 0.5) return;
      llego = true;
      _wall.arriveAtValley();
    }

    _flight.addListener(mirar);
    _flight.forward(from: 0).whenComplete(() {
      _flight.removeListener(mirar);
      if (mounted) setState(() => _flying = false);
    });
  }

  void _openSettings() {
    Sensory.instance.tick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: sheetScrim(_theme.dark),
      builder: (_) => SettingsSheet(store: widget.store, theme: _theme),
    );
  }
}
