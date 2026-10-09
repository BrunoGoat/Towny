import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/rng.dart';
import '../data/demo.dart';
import '../data/doings.dart';
import '../data/landmarks.dart';
import '../engine/season.dart';
import '../engine/shooting_star.dart';
import '../engine/town.dart';
import '../fx/notifier.dart';
import '../fx/sensory.dart';
import '../l10n/lang.dart';
import '../model/appearance.dart';
import '../model/board_seen.dart';
import '../model/board_slots.dart';
import '../model/piece.dart';
import '../model/reel.dart';
import '../model/store.dart';
import 'backup_sheet.dart';
import 'choice_sheet.dart';
import 'debug_sheet.dart';
import 'folk_gallery_screen.dart';
import 'gallery_screen.dart';
import 'notice_board.dart';
import 'overlays.dart';
import 'reel_screen.dart';
import 'style.dart';

/// Qué pueblos tienen historia bastante como para mirarla crecer.
List<int> _conCronica(Store store) => [
  for (var i = 0; i < store.habits.length; i++)
    if (Reel.worthIt(store.habits, only: i)) i,
];

/// Everything about the app that is a setting rather than a town.
///
/// It used to live at the bottom of the journey, under the stats and the
/// milestones, which meant scrolling past your own history to turn the sound
/// down. Now the gear opens this and the numbers still open the journey: two
/// doors, two different things behind them.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    super.key,
    required this.store,
    required this.theme,
    this.dev = false,
  });

  final Store store;
  final UiTheme theme;

  /// La hoja de desarrollo en vez de la de siempre: lo que sirve para probar
  /// la app y no para usarla. Se abre desde la última fila de la otra.
  ///
  /// Son dos hojas y no una con todo porque quien usa la app no tiene por qué
  /// leer, cada vez que busca el volumen, cómo fingir el día del año.
  final bool dev;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return ListenableBuilder(
      listenable: Appearance.instance,
      builder: (context, _) {
        final hoy = Season.on(DateTime.now(), Appearance.instance.hemisphere);
        return _Velo(
          theme: t,
          height: MediaQuery.of(context).size.height * 0.88,
          emblem: widget.dev ? Icons.science_outlined : Icons.tune_rounded,
          title: widget.dev
              ? tr('Desarrollo', 'Developer')
              : tr('Ajustes', 'Settings'),
          // Debajo del título, una línea que dice algo de verdad: en qué punto
          // del año está quien mira, o qué es esta hoja.
          //
          // Qué build es ésta va acá también. Existe porque no saberlo costó
          // una tarde: se probaba algo que no salía, y la pregunta «¿está el
          // cambio o es la build de antes?» no tenía manera de contestarse
          // desde el teléfono. Lo pone el flujo al compilar; en local no hay.
          line: [
            if (widget.dev)
              tr('Para probar, no para usar', 'For testing, not for using')
            else if (Appearance.instance.seasons)
              tr(
                '${hoy.name} · ${hoy.daylightHours.toStringAsFixed(1)} horas '
                    'de luz',
                '${hoy.name} · ${hoy.daylightHours.toStringAsFixed(1)} hours '
                    'of daylight',
              )
            else
              tr('El año quieto', 'The year standing still'),
            if (_build.isNotEmpty) 'build $_build',
          ].join('  ·  '),
          child: _body(context, t),
        );
      },
    );
  }

  /// El número de ejecución del flujo que compiló esta APK. Vacío en local.
  static const String _build = String.fromEnvironment('BUILD');

  Widget _body(BuildContext context, UiTheme t) {
    final wants = Appearance.instance;
    final store = widget.store;
    final items = widget.dev
        ? <Widget>[
            _Section(
              theme: t,
              title: tr('PIEZAS Y PUEBLOS', 'PIECES AND TOWNS'),
              icon: Icons.grid_view_rounded,
              children: [
                _Switch(
                  theme: t,
                  title: tr('Modo rápido', 'Fast mode'),
                  subtitle: tr(
                    'Mantener pone piezas seguidas. Para probar, no para usar: una '
                        'pieza es un logro.',
                    'Holding places pieces one after another. For testing, not for '
                        'real use: a piece is an achievement.',
                  ),
                  on: wants.rapid,
                  onChanged: wants.setRapid,
                ),
                _Switch(
                  theme: t,
                  title: tr('Sin límite de hábitos', 'No habit limit'),
                  subtitle: tr(
                    'Fundar pueblos nuevos sin tener que desbloquearlos. Para probar: '
                        'el segundo pueblo se gana.',
                    'Found new towns without unlocking them. For testing: the second '
                        'town is meant to be earned.',
                  ),
                  on: wants.freeHabits,
                  onChanged: wants.setFreeHabits,
                ),
              ],
            ),
            _Section(
              theme: t,
              title: tr('LA HORA', 'THE TIME'),
              icon: Icons.schedule,
              children: [
                _Switch(
                  theme: t,
                  title: tr('Fingir la hora', 'Pretend the time'),
                  subtitle: tr(
                    'Para mirar el pueblo a cualquier hora sin esperarla. Cambia el '
                        'cielo, la música, las ventanas y las fugaces, porque las '
                        'cuatro salen de la misma hora.',
                    'To look at the town at any hour without waiting for it. It '
                        'changes the sky, the music, the windows and the shooting '
                        'stars, because all four come from the same clock.',
                  ),
                  on: wants.fakeHour,
                  onChanged: wants.setFakeHour,
                ),
                if (wants.fakeHour)
                  _Slider(
                    theme: t,
                    title: tr(
                      'Son las ${wants.fakeHourAt.floor().toString().padLeft(2, '0')}'
                          ':${((wants.fakeHourAt % 1) * 60).floor().toString().padLeft(2, '0')}',
                      "It's ${wants.fakeHourAt.floor().toString().padLeft(2, '0')}"
                          ':${((wants.fakeHourAt % 1) * 60).floor().toString().padLeft(2, '0')}',
                    ),
                    value: wants.fakeHourAt / 24,
                    onChanged: (v) => wants.setFakeHourAt(v * 24),
                  ),
                _Row(
                  theme: t,
                  icon: Icons.auto_awesome,
                  title: tr('Tirar una estrella fugaz', 'Send a shooting star'),
                  subtitle: tr(
                    'Sale ya mismo, sin esperar. Dura cinco segundos, cruza por donde '
                        'estés mirando y de noche pasa una cada cuatro minutos y medio '
                        'de media.',
                    'It goes right now, no waiting. It lasts five seconds, crosses '
                        "wherever you're looking, and at night one passes every four "
                        'and a half minutes on average.',
                  ),
                  // Cierra los ajustes primero. Sin eso la fugaz cruzaba por detrás de
                  // esta misma hoja durante los cinco segundos que dura, que es la
                  // manera más tonta de que un botón de probar algo no pruebe nada. El
                  // sonido no lo toca esto: lo toca el valle al verla, y así suena una
                  // vez y no dos.
                  act: (nav) {
                    nav.pop();
                    Future<void>.delayed(
                      const Duration(milliseconds: 260),
                      ShootingStar.force,
                    );
                  },
                ),
              ],
            ),
            _Section(
              theme: t,
              title: tr('EL AÑO', 'THE YEAR'),
              icon: Icons.eco_outlined,
              children: [
                if (!wants.seasons)
                  Text(
                    tr(
                      'Las estaciones están apagadas en los ajustes.',
                      'The seasons are switched off in settings.',
                    ),
                    style: _nota(t),
                  ),
                if (wants.seasons) ...[
                  _Switch(
                    theme: t,
                    title: tr(
                      'Fingir el día del año',
                      'Pretend the day of the year',
                    ),
                    subtitle: tr(
                      'Para ver el invierno en marzo sin esperarlo, igual que se '
                          'finge la hora.',
                      'To see winter in March without waiting for it, the same way '
                          'you pretend the time.',
                    ),
                    on: wants.fakeSeason,
                    onChanged: wants.setFakeSeason,
                  ),
                  if (wants.fakeSeason) ...[
                    // Las cuatro de un toque, y el deslizador debajo para lo de en
                    // medio. Estaba sólo el deslizador y no servía para lo que la
                    // gente quiere hacer con esto, que es ver las cuatro estaciones
                    // seguidas: buscar el invierno a tientas en una barra no es verlo,
                    // es cazarlo.
                    _Pick(
                      theme: t,
                      // En el **pico** de cada una y no en su primer día: el suelo
                      // va un mes por detrás del sol, así que en el solsticio todavía
                      // se ve la estación que se va. Quien toca «Invierno» quiere ver
                      // el invierno, no el 21 de diciembre.
                      options: [
                        (tr('Invierno', 'Winter'), 0.09),
                        (tr('Primavera', 'Spring'), 0.34),
                        (tr('Verano', 'Summer'), 0.59),
                        (tr('Otoño', 'Autumn'), 0.84),
                      ],
                      value: wants.fakeSeasonAt,
                      onPick: wants.setFakeSeasonAt,
                    ),
                    _Slider(
                      theme: t,
                      title:
                          '${Season(wants.fakeSeasonAt).name}, '
                          '${Season(wants.fakeSeasonAt).daylightHours.toStringAsFixed(1)}'
                          '${tr(' horas de luz', ' hours of daylight')}',
                      value: wants.fakeSeasonAt,
                      onChanged: wants.setFakeSeasonAt,
                    ),
                  ],
                ],
              ],
            ),
            _Section(
              theme: t,
              title: tr('EL TABLÓN', 'THE NOTICE BOARD'),
              icon: Icons.push_pin_outlined,
              children: [
                Text(
                  tr(
                    'Las letras del tablón ya no se eligen: tus cuentas van todas de '
                        'la misma mano y cada bando sale con la del vecino que lo '
                        'colgó. Un tablón de plaza se lee así, no con una letra que se '
                        'elige en un menú.',
                    "The board's handwriting isn't chosen any more: your tallies are "
                        'all in the same hand, and each notice comes in the hand of the '
                        'neighbour who pinned it. That is how a town board reads, not '
                        'in a font picked from a menu.',
                  ),
                  style: _nota(t),
                ),
                const SizedBox(height: 12),
                _Row(
                  theme: t,
                  icon: Icons.auto_stories_outlined,
                  title: tr(
                    'Ver el tablón con un pueblo lleno',
                    'See the board of a full town',
                  ),
                  subtitle: tr(
                    'Un valle de mentira: entrenar durante 300 días. Trae un dado '
                        'que vuelve a repartirlo con notas al azar, para ver si el '
                        'texto cabe también en las que no salen nunca.',
                    'A pretend valley: training for 300 days. It comes with a die '
                        'that deals it again with random notes, to check that the text '
                        'also fits in the ones that hardly ever come up.',
                  ),
                  page: () {
                    final valle = demoValley();
                    return NoticeBoardScreen(
                      valley: valle,
                      habit: valle.first,
                      theme: t,
                      dice: true,
                    );
                  },
                ),
              ],
            ),
            _Section(
              theme: t,
              title: tr('PARA MIRAR', 'TO LOOK AT'),
              icon: Icons.visibility_outlined,
              children: [
                _Row(
                  theme: t,
                  icon: Icons.tune,
                  title: tr(
                    'Ver el pueblo a futuro',
                    'See the town in the future',
                  ),
                  subtitle: tr(
                    'Cómo se vería con 100, 500 o 5000 piezas.',
                    'How it would look with 100, 500 or 5000 pieces.',
                  ),
                  open: () => DebugSheet(store: store, theme: t),
                ),
                _Row(
                  theme: t,
                  icon: Icons.fork_right,
                  title: tr('Ver la tarjeta de elegir', 'See the choice card'),
                  subtitle: tr(
                    'La pregunta que sale al empezar una obra, con dos al azar del '
                        'catálogo. Mirar y ya: no elige nada ni toca tu pueblo.',
                    'The question that comes up when a work begins, with two random '
                        "ones from the catalogue. Just to look: it doesn't choose "
                        'anything or touch your town.',
                  ),
                  act: (nav) {
                    nav.pop();
                    _verLaPregunta(nav, t, store);
                  },
                ),
                _Row(
                  theme: t,
                  icon: Icons.restart_alt,
                  title: tr(
                    'Ver la primera vez otra vez',
                    'See the first time again',
                  ),
                  subtitle: tr(
                    'Abre la pantalla de entrada como si acabaras de instalar la '
                        'app. Es sólo para mirar: al terminar vuelve tu valle tal cual.',
                    "Opens the welcome screen as if you'd just installed the app. "
                        "It's only for looking: when you finish, your valley comes back "
                        'as it was.',
                  ),
                  act: (nav) {
                    Appearance.instance.rehearseOnboarding();
                    nav.pop();
                  },
                ),
                _Row(
                  theme: t,
                  icon: Icons.view_in_ar,
                  title: tr('El expositor', 'The showcase'),
                  subtitle: tr(
                    'Las ${landmarks.length + BuildingKind.values.length} estructuras '
                        'que el pueblo sabe construir.',
                    'The ${landmarks.length + BuildingKind.values.length} structures '
                        'the town knows how to build.',
                  ),
                  page: () => GalleryScreen(theme: t),
                ),
                _Row(
                  theme: t,
                  icon: Icons.directions_walk,
                  title: tr('El expositor de la gente', 'The people showcase'),
                  subtitle: tr(
                    'Las ${Doing.all.length} cosas que hacen los vecinos cuando no '
                        'están andando, una a una y de cerca.',
                    "The ${Doing.all.length} things the neighbours do when they're "
                        'not walking, one by one and up close.',
                  ),
                  page: () => FolkGalleryScreen(theme: t),
                ),
              ],
            ),
          ]
        : <Widget>[
            // Lo primero de todo: quien abrió los ajustes buscando esto puede no
            // entender nada de lo que hay debajo.
            _Section(
              theme: t,
              title: tr('IDIOMA · LANGUAGE', 'LANGUAGE · IDIOMA'),
              icon: Icons.translate,
              children: [
                _Pick(
                  theme: t,
                  options: [
                    for (final l in Lang.values) (l.name, l.index * 1.0),
                  ],
                  value: wants.language.index * 1.0,
                  onPick: (at) => wants.setLanguage(Lang.values[at.round()]),
                ),
                Text(
                  wants.languageChosen
                      ? tr('Lo elegiste vos.', 'You chose it.')
                      : tr(
                          'Sale del idioma del teléfono.',
                          "It follows your phone's language.",
                        ),
                  style: _nota(t),
                ),
              ],
            ),
            _Section(
              theme: t,
              title: tr('IMAGEN', 'GRAPHICS'),
              icon: Icons.auto_awesome,
              children: [
                _Switch(
                  theme: t,
                  title: tr('Calidad máxima', 'Maximum quality'),
                  subtitle: tr(
                    'Sombras de verdad que giran con el sol, ventanas que resplandecen, '
                        'rayos de luz al amanecer y al atardecer, y color de cine. '
                        'Pide bastante más al aparato.',
                    'Real shadows that turn with the sun, glowing windows, light rays '
                        'at sunrise and sunset, and cinematic colour. It asks a lot '
                        'more of your device.',
                  ),
                  on: wants.cinematic,
                  onChanged: wants.setCinematic,
                ),
              ],
            ),
            _Section(
              theme: t,
              title: tr('SONIDO', 'SOUND'),
              icon: Icons.music_note,
              children: [
                _Switch(
                  theme: t,
                  title: tr('Sonido', 'Sound'),
                  subtitle: tr(
                    'El interruptor de todo, música incluida.',
                    'The switch for everything, music included.',
                  ),
                  on: !wants.soundOff,
                  onChanged: (v) => wants.setSoundOff(!v),
                ),
                _Switch(
                  theme: t,
                  title: tr('Efectos', 'Effects'),
                  subtitle: tr(
                    'Lo que suena al poner una pieza.',
                    'What you hear when you place a piece.',
                  ),
                  on: !wants.effectsOff,
                  enabled: !wants.soundOff,
                  onChanged: (v) => wants.setEffectsOff(!v),
                ),
                _Switch(
                  theme: t,
                  title: tr('Música', 'Music'),
                  subtitle: tr(
                    'De fondo, y distinta según la hora del día.',
                    'In the background, and different depending on the time of day.',
                  ),
                  on: !wants.musicOff,
                  enabled: !wants.soundOff,
                  onChanged: (v) => wants.setMusicOff(!v),
                ),
                const SizedBox(height: 8),
                _Slider(
                  theme: t,
                  title: tr('Volumen de la música', 'Music volume'),
                  value: wants.musicVolume,
                  onChanged: wants.setMusicVolume,
                ),
                _Slider(
                  theme: t,
                  title: tr('Volumen de los efectos', 'Effects volume'),
                  value: wants.effectsVolume,
                  onChanged: (v) {
                    wants.setEffectsVolume(v);
                  },
                  onSettled: () => Sensory.instance.preview('place'),
                ),
                Text(
                  tr(
                    'La mitad es como sonaba antes de que hubiera dónde tocarlo, así '
                        'que lo que muevas se mide contra algo que ya conocés.',
                    'Halfway is how it sounded before there was a way to change it, '
                        'so whatever you move is measured against something you know.',
                  ),
                  style: _nota(t),
                ),
              ],
            ),
            _Section(
              theme: t,
              title: tr('EL AÑO', 'THE YEAR'),
              icon: Icons.eco_outlined,
              children: [
                _Switch(
                  theme: t,
                  title: tr('Las estaciones', 'The seasons'),
                  subtitle: tr(
                    'El valle cambia con el año: verde nuevo en primavera, dorado en '
                        'otoño, nieve en los tejados en invierno, y los días más '
                        'cortos o más largos según toque.',
                    'The valley changes with the year: fresh green in spring, gold in '
                        'autumn, snow on the roofs in winter, and shorter or longer '
                        'days as the year turns.',
                  ),
                  on: wants.seasons,
                  onChanged: wants.setSeasons,
                ),
                if (wants.seasons) ...[
                  // Y qué estación cree que es hoy, dicho en voz alta.
                  //
                  // Es la única manera de que quien lo mire sepa si esto está bien
                  // puesto sin esperar tres meses: si está en Montevideo en agosto y
                  // acá pone «otoño», el interruptor de abajo está del revés. Sale de
                  // la fecha de verdad aunque el año esté apagado o fingido, porque lo
                  // que contesta es dónde estás y no qué estás mirando.
                  _Switch(
                    theme: t,
                    title: tr(
                      'Estoy en el hemisferio sur',
                      "I'm in the southern hemisphere",
                    ),
                    subtitle: tr(
                      'Para que diciembre sea verano y julio invierno. '
                          '${wants.hemisphereChosen ? 'Lo pusiste vos' : 'Sale del idioma del teléfono'}, '
                          'y con eso hoy es '
                          '${Season.on(DateTime.now(), wants.hemisphere).name.toLowerCase()}.',
                      'So that December is summer and July is winter. '
                          '${wants.hemisphereChosen ? 'You set it' : "It follows your phone's language"}, '
                          'and with that today is '
                          '${Season.on(DateTime.now(), wants.hemisphere).name.toLowerCase()}.',
                    ),
                    on: wants.hemisphere == Hemisphere.south,
                    onChanged: (v) => wants.setHemisphere(
                      v ? Hemisphere.south : Hemisphere.north,
                    ),
                  ),
                ],
              ],
            ),
            _Section(
              theme: t,
              title: tr('LO DEMÁS', 'EVERYTHING ELSE'),
              icon: Icons.more_horiz,
              children: [
                // Encima de la vibración porque es el único de los tres que sale de la
                // app: los otros dos sólo suenan cuando ya la tenés abierta.
                _Switch(
                  theme: t,
                  title: tr(
                    'Que el pueblo te avise',
                    'Let the town remind you',
                  ),
                  subtitle: tr(
                    'Sólo cuando llevás más de lo tuyo sin poner una pieza, a tu '
                        'hora y con tus palabras. Como mucho dos por ausencia.',
                    "Only when you've gone longer than usual without placing a piece, "
                        'at your time and in your words. Two per absence at most.',
                  ),
                  on: !wants.nudgesOff,
                  onChanged: (v) async {
                    if (v && !await Notifier.instance.ask()) return;
                    await wants.setNudgesOff(!v);
                    await Notifier.instance.reschedule(
                      store.habits,
                      DateTime.now(),
                      on: v,
                    );
                  },
                ),
                _Switch(
                  theme: t,
                  title: tr('Vibración', 'Vibration'),
                  subtitle: tr(
                    'El peso de la pieza al caer.',
                    'The weight of the piece as it lands.',
                  ),
                  on: !wants.hapticsOff,
                  onChanged: (v) => wants.setHapticsOff(!v),
                ),
                _Undo(theme: t, store: store),
                _Row(
                  theme: t,
                  icon: Icons.save_alt,
                  title: tr('Tus datos', 'Your data'),
                  subtitle: tr(
                    'Copiar tu valle y volver a meterlo.',
                    'Copy your valley out and put it back in.',
                  ),
                  open: () => BackupSheet(store: store, theme: t),
                ),
                // Al lado de «a futuro» a propósito: son la misma clase de cosa mirada
                // en las dos direcciones, y la de atrás es la única de las dos que
                // habla de vos. Va primero porque es la que existe de verdad — la otra
                // enseña un pueblo que todavía no es tuyo.
                if (Reel.worthIt(store.habits))
                  if (_conCronica(store).length > 1)
                    _Row(
                      theme: t,
                      icon: Icons.play_circle_outline,
                      title: tr('Ver cómo se hizo', 'Watch how it was made'),
                      subtitle: tr(
                        'El valle entero, o uno de tus pueblos desde el primer día.',
                        'The whole valley, or one of your towns from the first day.',
                      ),
                      open: () => _WhichReel(store: store, theme: t),
                    )
                  else
                    _Row(
                      theme: t,
                      icon: Icons.play_circle_outline,
                      title: tr('Ver cómo se hizo', 'Watch how it was made'),
                      subtitle: tr(
                        'Tu pueblo entero desde el primer día, en un minuto.',
                        'Your whole town from the first day, in a minute.',
                      ),
                      page: () => ReelScreen.town(
                        store: store,
                        habit: _conCronica(store).firstOrNull ?? 0,
                      ),
                    ),
              ],
            ),
            // Las dos salidas, como en la hoja del hábito: en letra y no en
            // filas, y la que no se deshace en rojo.
            _Salidas(
              theme: t,
              onDev: (nav) {
                nav.pop();
                showModalBottomSheet<void>(
                  context: nav.context,
                  backgroundColor: Colors.transparent,
                  barrierColor: sheetScrim(t.dark),
                  isScrollControlled: true,
                  builder: (_) =>
                      SettingsSheet(store: store, theme: t, dev: true),
                );
              },
              onReset: (nav) => _empezarDeCero(nav, t, store),
            ),
          ];
    return ListView(
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      children: items,
    );
  }
}

/// Borrar el valle entero y volver a la primera vez.
///
/// Pregunta antes, y dice dónde está la copia: es lo único de la app que no
/// tiene vuelta atrás. Los ajustes —el sonido, la vibración— se quedan como
/// estaban, porque son de quien usa el teléfono y no del valle.
void _empezarDeCero(NavigatorState nav, UiTheme t, Store store) {
  Sensory.instance.tick();
  showDialog<void>(
    context: nav.context,
    builder: (dialog) => AlertDialog(
      backgroundColor: t.panelStrong,
      elevation: 0,
      title: Text(
        tr(
          '¿Borrar todo y empezar de cero?',
          'Delete everything and start from scratch?',
        ),
        style: t.body,
      ),
      content: Text(
        tr(
          'Se borran todos tus pueblos, sus piezas y lo que clavaste en el '
              'tablón. No se puede deshacer.\n\n'
              'Si querés guardar una copia, sacala antes desde «Tus datos».',
          'All your towns, their pieces and what you pinned on the board are '
              "deleted. It can't be undone.\n\n"
              'If you want to keep a copy, take it first from "Your data".',
        ),
        style: t.bodySoft,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(tr('No', 'No')),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(dialog).pop();
            await store.wipe();
            BoardSeen.instance.forget();
            await BoardSeen.instance.flush();
            BoardSlots.instance.forget();
            await BoardSlots.instance.flush();
            await Appearance.instance.forgetOnboarded();
            if (nav.mounted) nav.pop();
          },
          child: Text(
            tr('Borrar todo', 'Delete everything'),
            style: TextStyle(
              color: t.dark ? const Color(0xFFCC5B48) : const Color(0xFF9E3124),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// La tarjeta de elegir, enseñada por enseñarla.
///
/// Sale sola una vez cada varias semanas, cuando toca empezar una obra grande,
/// y eso la hace la pantalla más difícil de revisar de la app: para verla hay
/// que esperar a que el pueblo la pida. Desde aquí se abre cuando uno quiera.
///
/// **Y no elige nada.** Contestar aquí no empieza ninguna obra, no gasta la
/// pregunta de verdad y no escribe una línea en la crónica: las dos respuestas
/// cierran la tarjeta y se acabó. Una herramienta para mirar que además toca
/// lo que mira no sirve para mirar.
///
/// Las dos que salen son del catálogo entero y al azar, no las que le tocarían
/// al pueblo ahora. Es a propósito: lo que hay que ver de esta pantalla es si
/// aguanta **cualquier** pareja —un pozo de seis piezas contra una catedral de
/// treinta y tres, un nombre de una palabra contra «Panteón de los
/// fundadores»— y para eso la pareja de verdad es la menos útil de todas,
/// porque es siempre la misma hasta que se construye algo.
void _verLaPregunta(NavigatorState nav, UiTheme t, Store store) {
  final dado = SeqRandom(DateTime.now().microsecondsSinceEpoch);
  final a = dado.intN(landmarks.length);
  var b = dado.intN(landmarks.length);
  if (b == a) b = (a + 1) % landmarks.length;
  showDialog<void>(
    context: nav.context,
    barrierColor: sheetScrim(t.dark),
    builder: (_) => ChoiceSheet(
      options: [landmarks[a], landmarks[b]],
      place: store.habit.place,
      theme: t,
      onPick: (_) {},
    ),
  );
}

/// Deshacer la última pieza.
///
/// Vive aquí abajo, entre lo demás, y no al lado del botón de poner. Poner una
/// pieza es el gesto de la app y quitarla no puede estar a un dedo de él: lo
/// que se busca es que quien se equivocó pueda arreglarlo, no que quitar sea
/// tan fácil como poner.
class _Undo extends StatelessWidget {
  const _Undo({required this.theme, required this.store});

  final UiTheme theme;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final last = store.habit.pieces.isEmpty ? null : store.habit.pieces.last;
    return Opacity(
      opacity: last == null ? 0.42 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: last == null ? null : () => _ask(context, last),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              _Tile(theme: t, icon: Icons.undo),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Quitar la última pieza', 'Remove the last piece'),
                      style: _titulo(t),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      last == null
                          ? tr(
                              'Este pueblo todavía no tiene ninguna.',
                              "This town doesn't have any yet.",
                            )
                          : tr(
                              'La ${store.habit.total} de '
                                  '${store.habit.name}, puesta el '
                                  '${StoneCard.formatDate(last.placedAt)}.',
                              'Number ${store.habit.total} of '
                                  '${store.habit.name}, placed on '
                                  '${StoneCard.formatDate(last.placedAt)}.',
                            ),
                      style: _bajada(t),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ask(BuildContext context, Piece last) {
    final t = theme;
    Sensory.instance.tick();
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: t.panelStrong,
        elevation: 0,
        title: Text(
          tr(
            '¿Quitar la pieza ${store.habit.total}?',
            'Remove piece ${store.habit.total}?',
          ),
          style: t.body,
        ),
        content: Text(
          tr(
            'Vuelve a quedar en ${store.habit.total - 1}.',
            "It's back to ${store.habit.total - 1}.",
          ),
          style: t.bodySoft,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(tr('No', 'No')),
          ),
          TextButton(
            onPressed: () {
              store.removeLastPiece();
              Navigator.of(dialog).pop();
            },
            child: Text(
              tr('Quitarla', 'Remove it'),
              style: TextStyle(
                color: t.dark
                    ? const Color(0xFFCC5B48)
                    : const Color(0xFF9E3124),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La hoja entera: la marca flotando sobre el pueblo, y debajo el velo que
/// cuaja desde la nada, como el de la hoja del hábito.
///
/// Tuvo la superficie clara y opaca de las primeras hojas, y después un vidrio
/// con bloques redondeados: las dos se leían como la pantalla de ajustes de
/// cualquier app. Ésta no tiene canto: arriba el velo es transparente y se ve
/// el pueblo, y espesa hacia abajo hasta que la letra se lee.
class _Velo extends StatelessWidget {
  const _Velo({
    required this.theme,
    required this.height,
    required this.emblem,
    required this.title,
    required this.line,
    required this.child,
  });

  final UiTheme theme;
  final double height;
  final IconData emblem;
  final String title;
  final String line;
  final Widget child;

  static const double _marca = 46;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final velo = SheetInk.of(t);
    return SizedBox(
      height: height,
      child: Column(
        children: [
          // A los lados de la marca no hay hoja: tocar ahí es tocar fuera.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: double.infinity,
              child: Center(
                child: _Marca(theme: t, icon: emblem),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, caja) {
                // El velo cuaja en los primeros treinta y pico píxeles, sean
                // cuantos sean los de la hoja: medido en proporción, en una
                // pantalla alta el título quedaba a medio fundir con el prado.
                final cuaja = (34 / math.max(caja.maxHeight, 1)).clamp(
                  0.0,
                  0.5,
                );
                return _blurred(
                  velo.bruma,
                  cuaja,
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          velo.tinte.withValues(alpha: 0),
                          velo.tinte.withValues(alpha: velo.tapa * 0.92),
                          velo.tinte.withValues(alpha: velo.tapa),
                        ],
                        stops: [0.0, cuaja, 1.0],
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        Text(
                          title,
                          style: t.body.copyWith(
                            fontSize: 24,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: velo.cuerpo,
                            shadows: velo.aliento,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            line,
                            textAlign: TextAlign.center,
                            style: t.bodySoft.copyWith(
                              fontSize: 12,
                              color: velo.suave,
                              shadows: velo.aliento,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ShaderMask(
                            // La lista se desvanece arriba al subir, en vez de
                            // cortarse en seco debajo del título.
                            shaderCallback: (r) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
                              stops: [0.0, 0.04],
                            ).createShader(r),
                            blendMode: BlendMode.dstIn,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: child,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// La marca de la hoja, flotando con su aliento, como la del hábito.
class _Marca extends StatelessWidget {
  const _Marca({required this.theme, required this.icon});
  final UiTheme theme;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final velo = SheetInk.of(theme);
    const size = _Velo._marca;
    return Container(
      width: size * 2.4,
      height: size * 1.5,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            velo.tinte.withValues(alpha: 0.66),
            velo.tinte.withValues(alpha: 0.32),
            velo.tinte.withValues(alpha: 0),
          ],
          stops: const [0.26, 0.52, 1.0],
        ),
      ),
      child: Icon(
        icon,
        size: size,
        color: theme.accent,
        shadows: [
          Shadow(color: theme.accent.withValues(alpha: 0.45), blurRadius: 18),
        ],
      ),
    );
  }
}

/// Envuelve algo en un desenfoque de lo que tenga detrás, recortado y con
/// máscara para que no se vea la raya donde el pueblo pasa de nítido a
/// borroso. La receta es la de la hoja del hábito.
Widget _blurred(double sigma, double cuaja, Widget child) {
  if (sigma <= 0.5) return child;
  return ClipRect(
    child: ShaderMask(
      shaderCallback: (r) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
        stops: [0.0, cuaja],
      ).createShader(r),
      blendMode: BlendMode.dstIn,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    ),
  );
}

/// Un filete de pelo: la única raya que dibujan estas hojas.
Widget _hair(UiTheme t, [double? ancho]) => Container(
  width: ancho,
  height: 1,
  color: SheetInk.of(t).cuerpo.withValues(alpha: 0.14),
);

TextStyle _titulo(UiTheme t) => t.body.copyWith(
  color: SheetInk.of(t).cuerpo,
  fontSize: 15,
  height: 1.3,
  fontWeight: FontWeight.w500,
  shadows: SheetInk.of(t).aliento,
);

TextStyle _bajada(UiTheme t) => t.bodySoft.copyWith(
  color: SheetInk.of(t).suave,
  fontSize: 12.5,
  height: 1.4,
  shadows: SheetInk.of(t).aliento,
);

/// La letra de lo que explica sin ser una opción.
TextStyle _nota(UiTheme t) => t.bodySoft.copyWith(
  color: SheetInk.of(t).tenue,
  fontSize: 12,
  height: 1.45,
  fontStyle: FontStyle.italic,
  shadows: SheetInk.of(t).aliento,
);

/// Una sección: su nombre entre dos filetes con su dibujito, como la comarca
/// en la hoja del hábito, y sus filas debajo separadas por un filete.
///
/// Sin caja. Fueron bloques redondeados y se leían como la pantalla de
/// ajustes de cualquier teléfono; acá la hoja es un velo, y lo que separa una
/// cosa de otra es aire y una raya de pelo.
class _Section extends StatelessWidget {
  const _Section({
    required this.theme,
    this.title,
    this.icon,
    required this.children,
  });

  final UiTheme theme;
  final String? title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final velo = SheetInk.of(t);
    final filas = <Widget>[];
    for (final c in children) {
      if (filas.isNotEmpty) filas.add(_hair(t));
      // Las notas sueltas —lo que explica sin ser una opción— con aire.
      filas.add(
        c is Text
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: c,
              )
            : c,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(child: _hair(t)),
                  const SizedBox(width: 12),
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 15,
                      color: t.accent.withValues(alpha: 0.9),
                      shadows: velo.aliento,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title!,
                    style: t.label.copyWith(
                      fontSize: 11,
                      color: t.accent,
                      letterSpacing: 2.4,
                      shadows: velo.aliento,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _hair(t)),
                ],
              ),
            ),
          ...filas,
        ],
      ),
    );
  }
}

/// El dibujito de una fila: suelto, del color del acento, con su aliento.
class _Tile extends StatelessWidget {
  const _Tile({required this.theme, required this.icon});
  final UiTheme theme;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = theme.accent;
    return SizedBox(
      width: 28,
      child: Icon(
        icon,
        size: 21,
        color: c.withValues(alpha: 0.92),
        shadows: SheetInk.of(theme).aliento,
      ),
    );
  }
}

/// Las salidas del pie de la hoja, como las de la hoja del hábito: en letra,
/// una al lado de la otra, y la que no se deshace en rojo.
class _Salidas extends StatelessWidget {
  const _Salidas({
    required this.theme,
    required this.onDev,
    required this.onReset,
  });

  final UiTheme theme;
  final void Function(NavigatorState nav) onDev;
  final void Function(NavigatorState nav) onReset;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final velo = SheetInk.of(t);
    Widget boton(
      String texto,
      IconData icono,
      Color color,
      void Function(NavigatorState) hacer,
    ) => Flexible(
      child: TextButton.icon(
        onPressed: () {
          Sensory.instance.tick();
          hacer(Navigator.of(context));
        },
        style: TextButton.styleFrom(foregroundColor: color),
        icon: Icon(icono, size: 16, color: color),
        label: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodySoft.copyWith(
            fontSize: 12.5,
            color: color,
            shadows: velo.aliento,
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          _hair(t),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              boton(
                tr('Desarrollo', 'Developer'),
                Icons.science_outlined,
                velo.suave,
                onDev,
              ),
              boton(
                tr('Empezar de cero', 'Start from scratch'),
                Icons.delete_outline,
                _rojo(t),
                onReset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// El rojo de lo que no se deshace, legible sobre el vidrio.
Color _rojo(UiTheme t) => const Color(0xFFE0705C);

class _Switch extends StatelessWidget {
  const _Switch({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.on,
    required this.onChanged,
    this.enabled = true,
  });

  final UiTheme theme;
  final String title;
  final String subtitle;
  final bool on;
  final bool enabled;
  final void Function(bool v) onChanged;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final velo = SheetInk.of(t);
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        visualDensity: const VisualDensity(vertical: 1),
        value: on,
        activeThumbColor: const Color(0xFFFFF8EC),
        activeTrackColor: t.accent,
        inactiveThumbColor: velo.cuerpo.withValues(alpha: 0.80),
        inactiveTrackColor: velo.cuerpo.withValues(alpha: 0.14),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        title: Text(title, style: _titulo(t)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(subtitle, style: _bajada(t)),
        ),
        onChanged: enabled
            ? (v) {
                Sensory.instance.tick();
                onChanged(v);
              }
            : null,
      ),
    );
  }
}

/// Unas cuantas opciones en fila, para elegir una de un toque: palabras, y
/// debajo de la elegida una raya del color del acento.
class _Pick extends StatelessWidget {
  const _Pick({
    required this.theme,
    required this.options,
    required this.value,
    required this.onPick,
  });

  final UiTheme theme;
  final List<(String, double)> options;
  final double value;
  final void Function(double) onPick;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final velo = SheetInk.of(t);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          for (final (name, at) in options)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Sensory.instance.tick();
                  onPick(at);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Text(
                        name,
                        style: t.body.copyWith(
                          fontSize: 14,
                          color: (value - at).abs() < 0.01
                              ? velo.cuerpo
                              : velo.tenue,
                          fontWeight: (value - at).abs() < 0.01
                              ? FontWeight.w600
                              : FontWeight.w400,
                          shadows: velo.aliento,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: (value - at).abs() < 0.01 ? 26 : 0,
                        height: 2,
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.theme,
    required this.title,
    required this.value,
    required this.onChanged,
    this.onSettled,
  });

  final UiTheme theme;
  final String title;
  final double value;
  final void Function(double v) onChanged;

  /// Something to hear once the finger comes off, so a volume can be judged
  /// rather than guessed.
  final VoidCallback? onSettled;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final velo = SheetInk.of(t);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: _titulo(t))),
              Text(
                '${(value * 100).round()}%',
                style: _bajada(
                  t,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: t.accent,
              inactiveTrackColor: velo.cuerpo.withValues(alpha: 0.14),
              thumbColor: const Color(0xFFFFF8EC),
              overlayColor: t.accent.withValues(alpha: 0.14),
              trackHeight: 4,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
              onChangeEnd: (_) => onSettled?.call(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.open,
    this.page,
    this.act,
  });

  final UiTheme theme;
  final IconData icon;
  final String title;
  final String subtitle;

  /// A sheet that rises over this one.
  final Widget Function()? open;

  /// A whole screen that replaces it.
  final Widget Function()? page;

  /// O nada de eso: algo que pasa y ya, sin salir de aquí.
  final void Function(NavigatorState nav)? act;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final velo = SheetInk.of(t);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Sensory.instance.tick();
        final nav = Navigator.of(context);
        final hacer = act;
        if (hacer != null) {
          hacer(nav);
          return;
        }
        nav.pop();
        if (page != null) {
          nav.push(MaterialPageRoute<void>(builder: (_) => page!()));
          return;
        }
        showModalBottomSheet<void>(
          context: nav.context,
          backgroundColor: Colors.transparent,
          barrierColor: sheetScrim(t.dark),
          isScrollControlled: true,
          builder: (_) => open!(),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _Tile(theme: t, icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _titulo(t)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: _bajada(t)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 20, color: velo.tenue),
          ],
        ),
      ),
    );
  }
}

/// Cuál de las dos maneras de mirar atrás.
///
/// **Son dos cosas distintas, no dos tamaños de la misma.** El valle entero se
/// mira saltando: hay piezas cayendo en tres pueblos a la vez y lo que cuenta
/// es cuándo apareció cada uno y cómo se repartieron los meses. Un pueblo se
/// mira girando alrededor de su plaza, que es lo que se puede hacer cuando no
/// hay nada a lo que saltar, y ahí lo que cuenta es cómo creció ése.
///
/// Sólo sale cuando hay más de un pueblo con historia. Con uno solo no hay
/// nada que elegir, y una pregunta con una sola respuesta es un paso de más.
class _WhichReel extends StatelessWidget {
  const _WhichReel({required this.store, required this.theme});

  final Store store;
  final UiTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final cuales = _conCronica(store);
    return _Velo(
      theme: t,
      height: math.min(
        MediaQuery.of(context).size.height * 0.7,
        300.0 + cuales.length * 76,
      ),
      emblem: Icons.play_circle_outline,
      title: tr('Ver cómo se hizo', 'Watch how it was made'),
      line: tr(
        'El valle entero, o uno de tus pueblos',
        'The whole valley, or one of your towns',
      ),
      child: ListView(
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          _Section(
            theme: t,
            children: [
              _Row(
                theme: t,
                icon: Icons.grass,
                title: tr('El valle entero', 'The whole valley'),
                subtitle: tr(
                  'Salta de pieza en pieza y de pueblo en pueblo, en el orden '
                      'en que pasaron.',
                  'It jumps from piece to piece and town to town, in the order '
                      'they happened.',
                ),
                page: () => ReelScreen(store: store),
              ),
              for (final i in cuales)
                _Row(
                  theme: t,
                  icon: Icons.location_city,
                  title: store.habits[i].name,
                  subtitle: tr(
                    'Sólo este pueblo, con la cámara dando la vuelta a su plaza.',
                    'Just this town, with the camera circling its square.',
                  ),
                  page: () => ReelScreen.town(store: store, habit: i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
