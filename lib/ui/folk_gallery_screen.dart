import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/character.dart';
import '../data/doings.dart';
import '../engine/camera.dart';
import '../engine/folk.dart';
import '../engine/palette.dart';
import '../engine/renderer.dart';
import '../engine/scene.dart';
import '../engine/town.dart';
import '../fx/effects.dart';
import '../fx/sensory.dart';
import 'style.dart';

/// El expositor de lo que hace la gente.
///
/// Hay noventa y cuatro cosas escritas en una tabla, y una tabla no se revisa
/// leyéndola: cada renglón son cinco números —cuánto se agacha, cuánto sube y
/// baja, a qué ritmo, cuánto se inclina, qué le flota en la mano— y de leerlos
/// no se sabe si lo que sale se entiende o es una caja moviéndose sola.
///
/// Aquí se ve una a una, de cerca, dando la vuelta alrededor y con el tiempo
/// corriendo. Es el mismo camino de pintado que la gente de un pueblo —las
/// mismas cajas, el mismo sombreado, el mismo descarte de caras— porque un
/// expositor que enseñe algo distinto de lo que se ve luego no sirve para
/// decidir nada. Y lo que hay que decidir es justamente eso: **qué se queda y
/// qué se va**. Lo que no se entiende mirándolo así, de cerca y quieto,
/// tampoco se va a entender a doce píxeles en medio de una plaza.
class FolkGalleryScreen extends StatefulWidget {
  const FolkGalleryScreen({super.key, required this.theme, this.start = 0});

  final UiTheme theme;
  final int start;

  @override
  State<FolkGalleryScreen> createState() => _FolkGalleryScreenState();
}

class _FolkGalleryScreenState extends State<FolkGalleryScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final OrbitCamera _cam = OrbitCamera();
  final EffectSystem _fx = EffectSystem();

  /// Por sitio y luego por nombre: es como se revisa, sitio por sitio, porque
  /// lo que se compara es lo que compite entre sí.
  static final List<Doing> _all = [
    for (final w in Where.values)
      ...[
        for (final d in Doing.all)
          if (d.where == w) d,
      ]..sort((a, b) => a.name.compareTo(b.name)),
  ];

  late int _at = widget.start.clamp(0, _all.length - 1);

  /// Un crío o alguien hecho, cuando la actividad admite las dos.
  bool _kid = false;

  /// La región, que le cambia la talla y de paso el paño.
  int _character = 0;

  /// La hora, porque un farol encendido a mediodía no se ve.
  double _hour = 11;

  double _time = 0;
  Duration _last = Duration.zero;
  double _lastScale = 1;

  Doing get _it => _all[_at];

  /// El de muestra. Se rehace al cambiar de actividad o de edad, y no en cada
  /// fotograma: su semilla decide la ropa y la cara, y si se rehiciera todo el
  /// rato cambiaría de persona sesenta veces por segundo.
  late Townsfolk _who;
  String _whoKey = '';

  void _rebuild() {
    final key = '${_it.id}:$_kid';
    if (key == _whoKey) return;
    _whoKey = key;
    _who = Townsfolk.showcase(_it, kid: _kid);
  }

  @override
  void initState() {
    super.initState();
    _rebuild();
    // Encuadrado corto a propósito: esto es una lupa, no una postal. Con la
    // figura a media pantalla no se distingue el que charla del que está
    // quieto, que es justo lo que hay que poder distinguir aquí.
    _cam
      ..reaches(-4, 4)
      ..yawTarget = 0.62
      ..pitchTarget = 0.18
      ..distanceTarget = 1.30
      ..travelTarget = 0
      ..focusZTarget = 0
      ..focusYTarget = 0.27;
    _cam.snap();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0005, 0.05);
    _last = elapsed;
    _time += dt;
    _cam.step(dt);
    _fx.update(dt);
    setState(() {});
  }

  void _go(int delta) {
    Sensory.instance.tick();
    setState(() => _at = (_at + delta + _all.length) % _all.length);
  }

  Future<void> _pick() async {
    Sensory.instance.tick();
    final n = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _IndexSheet(theme: widget.theme, all: _all, at: _at),
    );
    if (n != null && mounted) setState(() => _at = n);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final media = MediaQuery.of(context);
    final palette = Palette.forMoment(_hour, 1.0);
    _rebuild();
    final place = TownCharacter.all[_character];

    final scene = TownScene(
      placed: 0,
      palette: palette,
      camera: _cam,
      integrity: 1,
      time: _time,
      hourOfDay: _hour,
      effects: _fx,
      labelledBricks: const {},
      budget: 2000,
      towns: [
        TownEntry(
          layout: TownLayout.showcase(place, placed: 0),
          name: _it.name,
          symbol: place.symbol,
          integrity: 1,
          placed: 0,
        ),
      ],
      active: 0,
      labels: false,
      soloFolk: _who,
    );

    return Scaffold(
      backgroundColor: palette.skyTop,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (_) => _lastScale = 1,
              onScaleUpdate: (d) {
                if (d.pointerCount >= 2) {
                  final f = d.scale / (_lastScale == 0 ? 1 : _lastScale);
                  _lastScale = d.scale;
                  if (f.isFinite && f > 0) _cam.zoomBy(1 / f);
                } else {
                  _cam.orbitBy(
                    -d.focalPointDelta.dx * 0.0062,
                    d.focalPointDelta.dy * 0.0048,
                  );
                }
              },
              child: CustomPaint(
                painter: TownPainter(scene, [], [], [], [], [], []),
                size: Size.infinite,
                isComplex: true,
                willChange: true,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: media.padding.top + 6,
            child: _Header(
              theme: t,
              doing: _it,
              at: _at,
              total: _all.length,
              who: _who,
              onBack: () => Navigator.of(context).pop(),
              onIndex: _pick,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: media.padding.bottom + 10,
            child: _Controls(
              theme: t,
              doing: _it,
              kid: _kid,
              onKid: (v) {
                Sensory.instance.tick();
                setState(() => _kid = v);
              },
              place: place,
              onPlace: () {
                Sensory.instance.tick();
                setState(
                  () =>
                      _character = (_character + 1) % TownCharacter.all.length,
                );
              },
              hour: _hour,
              onHour: (v) => setState(() => _hour = v),
              onPrev: () => _go(-1),
              onNext: () => _go(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.theme,
    required this.doing,
    required this.at,
    required this.total,
    required this.who,
    required this.onBack,
    required this.onIndex,
  });

  final UiTheme theme;
  final Doing doing;
  final int at, total;
  final Townsfolk who;
  final VoidCallback onBack, onIndex;

  static String _where(Where w) => switch (w) {
    Where.door => 'en su puerta',
    Where.square => 'en la plaza',
    Where.water => 'donde hay agua',
    Where.work => 'al pie de una obra',
    Where.meadow => 'en el prado',
  };

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Frosted(
        theme: t,
        radius: 20,
        padding: const EdgeInsets.fromLTRB(6, 8, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back, color: t.fgSoft, size: 20),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${at + 1} DE $total  ·  ${doing.id.toUpperCase()}',
                    style: t.label,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    // Con el nombre delante se lee como lo que es: «Urraca la
                    // Barquera echa a navegar un barco de papel». Si hay que
                    // leerlo dos veces para saber qué está pasando, la
                    // actividad sobra.
                    '${who.name} ${doing.name}',
                    style: t.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_where(doing.where)}'
                    '${doing.who == Who.anyone
                        ? ''
                        : doing.who == Who.kid
                        ? ' · sólo críos'
                        : ' · sólo mayores'}'
                    '${doing.prop == PropKind.none ? '' : ' · ${doing.prop.name}'}'
                    ' · peso ${doing.weight.toStringAsFixed(1)}',
                    style: t.bodySoft.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onIndex,
              icon: Icon(Icons.list, color: t.fgSoft, size: 20),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.theme,
    required this.doing,
    required this.kid,
    required this.onKid,
    required this.place,
    required this.onPlace,
    required this.hour,
    required this.onHour,
    required this.onPrev,
    required this.onNext,
  });

  final UiTheme theme;
  final Doing doing;
  final bool kid;
  final void Function(bool) onKid;
  final TownCharacter place;
  final VoidCallback onPlace;
  final double hour;
  final void Function(double) onHour;
  final VoidCallback onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // Una actividad de sólo críos no admite mayores y al revés: el interruptor
    // de edad se apaga en vez de mentir.
    final bothAges = doing.who == Who.anyone;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Frosted(
        theme: t,
        radius: 22,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _Pill(
                  theme: t,
                  text: place.region,
                  onTap: onPlace,
                  hint: 'región',
                ),
                const SizedBox(width: 8),
                _Pill(
                  theme: t,
                  text: kid ? 'crío' : 'mayor',
                  on: bothAges,
                  onTap: bothAges ? () => onKid(!kid) : null,
                  hint: 'edad',
                ),
                const Spacer(),
                Text(
                  '${hour.toStringAsFixed(0)}h',
                  style: t.bodySoft.copyWith(fontSize: 12),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: t.accent.withValues(alpha: 0.8),
                inactiveTrackColor: t.fg.withValues(alpha: 0.14),
                thumbColor: t.accent,
              ),
              child: Slider(value: hour, min: 0, max: 23.9, onChanged: onHour),
            ),
            Row(
              children: [
                Expanded(
                  child: _Round(
                    theme: t,
                    icon: Icons.chevron_left,
                    onTap: onPrev,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Round(
                    theme: t,
                    icon: Icons.chevron_right,
                    onTap: onNext,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.theme,
    required this.text,
    required this.hint,
    this.onTap,
    this.on = true,
  });

  final UiTheme theme;
  final String text, hint;
  final VoidCallback? onTap;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: t.fg.withValues(alpha: on ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: t.stroke),
        ),
        child: Text(
          text,
          style: t.bodySoft.copyWith(
            fontSize: 12,
            color: on ? t.fg : t.fgFaint,
          ),
        ),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.theme, required this.icon, required this.onTap});

  final UiTheme theme;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.fg.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.stroke),
        ),
        child: Icon(icon, color: t.fg, size: 22),
      ),
    );
  }
}

/// El índice, por sitio.
class _IndexSheet extends StatelessWidget {
  const _IndexSheet({required this.theme, required this.all, required this.at});

  final UiTheme theme;
  final List<Doing> all;
  final int at;

  static String _head(Where w) => switch (w) {
    Where.door => 'EN SU PUERTA',
    Where.square => 'EN LA PLAZA',
    Where.water => 'DONDE HAY AGUA',
    Where.work => 'AL PIE DE UNA OBRA',
    Where.meadow => 'EN EL PRADO',
  };

  @override
  Widget build(BuildContext context) {
    final t = theme;
    Where? last;
    return Frosted(
      theme: t,
      strong: true,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      child: SizedBox(
        height: math.min(MediaQuery.of(context).size.height * 0.72, 620),
        child: ListView.builder(
          itemCount: all.length,
          itemBuilder: (context, i) {
            final d = all[i];
            final head = d.where != last ? _head(d.where) : null;
            last = d.where;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (head != null) ...[
                  SizedBox(height: i == 0 ? 0 : 16),
                  Text(head, style: t.label),
                  const SizedBox(height: 6),
                ],
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Text(
                      d.name,
                      style: t.body.copyWith(
                        fontSize: 13.5,
                        color: i == at ? t.accent : t.fgSoft,
                        fontWeight: i == at
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
