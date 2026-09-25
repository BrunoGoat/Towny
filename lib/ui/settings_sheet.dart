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
import '../model/appearance.dart';
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
  const SettingsSheet({super.key, required this.store, required this.theme});

  final Store store;
  final UiTheme theme;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return SheetSurface(
      theme: t,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
      child: ListenableBuilder(
        listenable: Appearance.instance,
        builder: (context, _) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.fg.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('AJUSTES', style: t.label),
                  // Qué build es ésta.
                  //
                  // Existe porque no existía, y no saberlo costó una tarde: se
                  // probaba algo que no salía, y la pregunta «¿está el cambio
                  // o es la build de antes?» no tenía manera de contestarse
                  // desde el teléfono. Con las APK saliendo de un flujo que
                  // numera cada ejecución, no decir el número en ninguna parte
                  // es guardarse el único dato que hace falta para saber qué
                  // se está mirando.
                  //
                  // Del mismo `--dart-define` que el resto de la app, así que
                  // no añade dependencia ninguna: lo pone el flujo al compilar
                  // y en local sale vacío, que es lo correcto — una build de
                  // tu propia máquina no tiene número.
                  if (_build.isNotEmpty)
                    Text(
                      'BUILD $_build',
                      style: t.label.copyWith(
                        fontSize: 9,
                        color: t.fg.withValues(alpha: 0.30),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: _body(context, t)),
            ],
          ),
        ),
      ),
    );
  }

  /// El número de ejecución del flujo que compiló esta APK. Vacío en local.
  static const String _build = String.fromEnvironment('BUILD');

  Widget _body(BuildContext context, UiTheme t) {
    final wants = Appearance.instance;
    final store = widget.store;
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _Head(theme: t, text: 'SONIDO'),
        _Switch(
          theme: t,
          title: 'Sonido',
          subtitle: 'El interruptor de todo, música incluida.',
          on: !wants.soundOff,
          onChanged: (v) => wants.setSoundOff(!v),
        ),
        _Switch(
          theme: t,
          title: 'Efectos',
          subtitle: 'Lo que suena al poner una pieza.',
          on: !wants.effectsOff,
          enabled: !wants.soundOff,
          onChanged: (v) => wants.setEffectsOff(!v),
        ),
        _Switch(
          theme: t,
          title: 'Música',
          subtitle: 'De fondo, y distinta según la hora del día.',
          on: !wants.musicOff,
          enabled: !wants.soundOff,
          onChanged: (v) => wants.setMusicOff(!v),
        ),
        const SizedBox(height: 8),
        _Slider(
          theme: t,
          title: 'Volumen de la música',
          value: wants.musicVolume,
          onChanged: wants.setMusicVolume,
        ),
        _Slider(
          theme: t,
          title: 'Volumen de los efectos',
          value: wants.effectsVolume,
          onChanged: (v) {
            wants.setEffectsVolume(v);
          },
          onSettled: () => Sensory.instance.preview('place'),
        ),
        Text(
          'La mitad es como sonaba antes de que hubiera dónde tocarlo, así que '
          'lo que muevas se mide contra algo que ya conocés.',
          style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.4),
        ),

        const SizedBox(height: 26),
        _Head(theme: t, text: 'EL TABLÓN'),
        Text(
          'Las letras del tablón ya no se eligen: tus cuentas van todas de la '
          'misma mano y cada bando sale con la del vecino que lo colgó. Un '
          'tablón de plaza se lee así, no con una letra que se elige en un '
          'menú.',
          style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.4),
        ),
        const SizedBox(height: 12),
        _Row(
          theme: t,
          icon: Icons.auto_stories_outlined,
          title: 'Ver el tablón con un pueblo lleno',
          subtitle:
              'Un valle de mentira: entrenar durante 300 días. Trae un dado '
              'que vuelve a repartirlo con notas al azar, para ver si el texto '
              'cabe también en las que no salen nunca.',
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

        const SizedBox(height: 26),
        _Head(theme: t, text: 'LA HORA'),
        _Switch(
          theme: t,
          title: 'Fingir la hora',
          subtitle:
              'Para mirar el pueblo a cualquier hora sin esperarla. Cambia el '
              'cielo, la música, las ventanas y las fugaces, porque las cuatro '
              'salen de la misma hora.',
          on: wants.fakeHour,
          onChanged: wants.setFakeHour,
        ),
        if (wants.fakeHour)
          _Slider(
            theme: t,
            title:
                'Son las ${wants.fakeHourAt.floor().toString().padLeft(2, '0')}'
                ':${((wants.fakeHourAt % 1) * 60).floor().toString().padLeft(2, '0')}',
            value: wants.fakeHourAt / 24,
            onChanged: (v) => wants.setFakeHourAt(v * 24),
          ),
        _Row(
          theme: t,
          icon: Icons.auto_awesome,
          title: 'Tirar una estrella fugaz',
          subtitle:
              'Sale ya mismo, sin esperar. Dura cinco segundos, cruza por donde '
              'estés mirando y de noche pasa una cada cuatro minutos y medio '
              'de media.',
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

        const SizedBox(height: 26),
        _Head(theme: t, text: 'EL AÑO'),
        _Switch(
          theme: t,
          title: 'Las estaciones',
          subtitle:
              'El valle cambia con el año: verde nuevo en primavera, dorado en '
              'otoño, nieve en los tejados en invierno, y los días más cortos '
              'o más largos según toque.',
          on: wants.seasons,
          onChanged: wants.setSeasons,
        ),
        if (wants.seasons) ...[
          _Switch(
            theme: t,
            title: 'Estoy en el hemisferio sur',
            subtitle:
                'Para que diciembre sea verano y julio invierno. Sale del '
                'idioma del teléfono; esto es para corregirlo.',
            on: wants.hemisphere == Hemisphere.south,
            onChanged: (v) =>
                wants.setHemisphere(v ? Hemisphere.south : Hemisphere.north),
          ),
          _Switch(
            theme: t,
            title: 'Fingir el día del año',
            subtitle:
                'Para ver el invierno en marzo sin esperarlo, igual que se '
                'finge la hora.',
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
              options: const [
                ('Invierno', 0.0),
                ('Primavera', 0.25),
                ('Verano', 0.5),
                ('Otoño', 0.75),
              ],
              value: wants.fakeSeasonAt,
              onPick: wants.setFakeSeasonAt,
            ),
            _Slider(
              theme: t,
              title:
                  '${Season(wants.fakeSeasonAt).name}, '
                  '${Season(wants.fakeSeasonAt).daylightHours.toStringAsFixed(1)}'
                  ' horas de luz',
              value: wants.fakeSeasonAt,
              onChanged: wants.setFakeSeasonAt,
            ),
          ],
        ],

        const SizedBox(height: 26),
        _Head(theme: t, text: 'LO DEMÁS'),
        // Encima de la vibración porque es el único de los tres que sale de la
        // app: los otros dos sólo suenan cuando ya la tenés abierta.
        _Switch(
          theme: t,
          title: 'Que el pueblo te avise',
          subtitle:
              'Sólo cuando llevás más de lo tuyo sin poner una pieza, a tu '
              'hora y con tus palabras. Como mucho dos por ausencia.',
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
          title: 'Vibración',
          subtitle: 'El peso de la pieza al caer.',
          on: !wants.hapticsOff,
          onChanged: (v) => wants.setHapticsOff(!v),
        ),
        _Switch(
          theme: t,
          title: 'Modo rápido',
          subtitle:
              'Mantener pone piezas seguidas. Para probar, no para usar: una '
              'pieza es un logro.',
          on: wants.rapid,
          onChanged: wants.setRapid,
        ),
        _Undo(theme: t, store: store),
        _Row(
          theme: t,
          icon: Icons.save_alt,
          title: 'Tus datos',
          subtitle: 'Copiar tu valle y volver a meterlo.',
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
              title: 'Ver cómo se hizo',
              subtitle:
                  'El valle entero, o uno de tus pueblos desde el primer día.',
              open: () => _WhichReel(store: store, theme: t),
            )
          else
            _Row(
              theme: t,
              icon: Icons.play_circle_outline,
              title: 'Ver cómo se hizo',
              subtitle: 'Tu pueblo entero desde el primer día, en un minuto.',
              page: () => ReelScreen.town(
                store: store,
                habit: _conCronica(store).firstOrNull ?? 0,
              ),
            ),
        _Row(
          theme: t,
          icon: Icons.tune,
          title: 'Ver el pueblo a futuro',
          subtitle: 'Cómo se vería con 100, 500 o 5000 piezas.',
          open: () => DebugSheet(store: store, theme: t),
        ),
        _Row(
          theme: t,
          icon: Icons.fork_right,
          title: 'Ver la tarjeta de elegir',
          subtitle:
              'La pregunta que sale al empezar una obra, con dos al azar del '
              'catálogo. Mirar y ya: no elige nada ni toca tu pueblo.',
          act: (nav) {
            nav.pop();
            _verLaPregunta(nav, t, store);
          },
        ),
        _Row(
          theme: t,
          icon: Icons.restart_alt,
          title: 'Ver la primera vez otra vez',
          subtitle:
              'Abre la pantalla de entrada como si acabaras de instalar la '
              'app. No borra ninguna pieza.',
          act: (nav) async {
            await Appearance.instance.forgetOnboarded();
            nav.pop();
          },
        ),
        _Row(
          theme: t,
          icon: Icons.view_in_ar,
          title: 'El expositor',
          subtitle:
              'Las ${landmarks.length + BuildingKind.values.length} estructuras '
              'que el pueblo sabe construir.',
          page: () => GalleryScreen(theme: t),
        ),
        _Row(
          theme: t,
          icon: Icons.directions_walk,
          title: 'El expositor de la gente',
          subtitle:
              'Las ${Doing.all.length} cosas que hacen los vecinos cuando no '
              'están andando, una a una y de cerca.',
          page: () => FolkGalleryScreen(theme: t),
        ),
      ],
    );
  }
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
      onLeave: () {},
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
        borderRadius: BorderRadius.circular(16),
        onTap: last == null ? null : () => _ask(context, last),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(Icons.undo, size: 20, color: t.fgSoft),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quitar la última pieza', style: t.body),
                    const SizedBox(height: 2),
                    Text(
                      last == null
                          ? 'Este pueblo todavía no tiene ninguna.'
                          : 'La ${store.habit.total} de '
                                '${store.habit.name}, puesta el '
                                '${StoneCard.formatDate(last.placedAt)}.',
                      style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.35),
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
        title: Text('¿Quitar la pieza ${store.habit.total}?', style: t.body),
        content: Text(
          last.hasLabel
              ? 'Dice «${last.label}». Se va con ella.'
              : 'Vuelve a quedar en ${store.habit.total - 1}.',
          style: t.bodySoft,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              store.removeLastPiece();
              Navigator.of(dialog).pop();
            },
            child: Text(
              'Quitarla',
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

class _Head extends StatelessWidget {
  const _Head({required this.theme, required this.text});
  final UiTheme theme;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: theme.label.copyWith(color: theme.accent)),
  );
}

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
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: on,
        activeThumbColor: t.accent,
        title: Text(title, style: t.body),
        subtitle: Text(
          subtitle,
          style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.35),
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

/// Unas cuantas opciones en fila, para elegir una de un toque.
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
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          for (final (name, at) in options) ...[
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Sensory.instance.tick();
                  onPick(at);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: t.fg.withValues(
                      alpha: (value - at).abs() < 0.01 ? 0.13 : 0.04,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: (value - at).abs() < 0.01
                          ? t.accent.withValues(alpha: 0.8)
                          : t.stroke,
                      width: (value - at).abs() < 0.01 ? 1.4 : 1,
                    ),
                  ),
                  child: Text(
                    name,
                    style: t.bodySoft.copyWith(
                      fontSize: 12,
                      color: (value - at).abs() < 0.01 ? t.fg : t.fgSoft,
                    ),
                  ),
                ),
              ),
            ),
            if (at != options.last.$2) const SizedBox(width: 7),
          ],
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
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: t.body)),
              Text(
                '${(value * 100).round()}%',
                style: t.bodySoft.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: t.accent.withValues(alpha: 0.85),
              inactiveTrackColor: t.fg.withValues(alpha: 0.12),
              thumbColor: t.accent,
              overlayColor: t.accent.withValues(alpha: 0.12),
              trackHeight: 3,
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
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
            Icon(icon, size: 19, color: t.fgSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.body),
                  const SizedBox(height: 2),
                  Text(subtitle, style: t.bodySoft.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 19, color: t.fgFaint),
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
    return SheetSurface(
      theme: t,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: t.fg.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('VER CÓMO SE HIZO', style: t.label),
          const SizedBox(height: 10),
          _Row(
            theme: t,
            icon: Icons.grass,
            title: 'El valle entero',
            subtitle:
                'Salta de pieza en pieza y de pueblo en pueblo, en el orden '
                'en que pasaron.',
            page: () => ReelScreen(store: store),
          ),
          for (final i in cuales)
            _Row(
              theme: t,
              icon: Icons.location_city,
              title: store.habits[i].name,
              subtitle:
                  'Sólo este pueblo, con la cámara dando la vuelta a su plaza.',
              page: () => ReelScreen.town(store: store, habit: i),
            ),
        ],
      ),
    );
  }
}
