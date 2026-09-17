import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/character.dart';
import '../data/symbols.dart';
import '../fx/sensory.dart';
import '../model/appearance.dart';
import '../model/habit_skin.dart';
import '../model/store.dart';
import 'habit_sigil.dart';
import 'style.dart';

/// Making a habit, and everything you can change about one afterwards.
class HabitsSheet extends StatefulWidget {
  const HabitsSheet({
    super.key,
    required this.store,
    required this.theme,
    this.startNew = false,
  });

  final Store store;
  final UiTheme theme;
  final bool startNew;

  @override
  State<HabitsSheet> createState() => _HabitsSheetState();
}

/// Borrar un pueblo entero no se deshace, así que se dice en el color con el
/// que se dicen esas cosas.
///
/// Dos rojos, y no uno: el mismo rojo oscuro que sobre el panel claro se lee
/// como un aviso, sobre el panel de noche se apaga hasta parecer un texto
/// desactivado. El de noche es el mismo rojo, un punto más vivo.
Color _danger(bool dark) =>
    dark ? const Color(0xFFCC5B48) : const Color(0xFF9E3124);

class _HabitsSheetState extends State<HabitsSheet> {
  late final TextEditingController _name;
  late String _symbol;
  late int _place;
  bool _creating = false;

  /// The marks are only worth the room when somebody is actually choosing
  /// one. Until then this sheet is a name and a mark.
  bool _picking = false;

  /// Sixty-six marks is four screenfuls of grid on a phone, and a sheet that
  /// tall pushes its own name field off the top. Three rows that slide
  /// sideways instead: the common ones are already in front of you, and the
  /// rest are a drag away rather than a scroll through everything.
  final ScrollController _reel = ScrollController();

  static const double _tile = 40;
  static const double _gap = 8;
  static const int _rows = 3;
  static const double _stride = _tile + _gap;

  @override
  void initState() {
    super.initState();
    _creating = widget.startNew && widget.store.canAddHabit;
    final h = widget.store.habit;
    _name = TextEditingController(text: _creating ? '' : h.name);
    _symbol = _creating ? habitSymbols.first : h.symbol;
    _place = _creating
        ? TownCharacter.forSlot(widget.store.habits.length).order
        : h.character;
    _picking = false;
  }

  @override
  void dispose() {
    _name.dispose();
    _reel.dispose();
    super.dispose();
  }

  /// Opening the picker on a mark that lives in the twentieth column and
  /// showing the first three would look like the mark is not in the list.
  void _showTheChosenOne() {
    final at = habitSymbols.indexOf(_symbol);
    if (at < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_reel.hasClients) return;
      final want = (at ~/ _rows - 1) * _stride;
      _reel.jumpTo(want.clamp(0.0, _reel.position.maxScrollExtent));
    });
  }

  /// The whole catalogue, three rows tall, read down and then across.
  Widget _reelOfMarks(UiTheme t) {
    final columns = (habitSymbols.length + _rows - 1) ~/ _rows;
    return SizedBox(
      height: _rows * _tile + (_rows - 1) * _gap,
      child: ListView.builder(
        controller: _reel,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: columns,
        itemBuilder: (_, column) => Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < _rows; row++)
                Padding(
                  padding: EdgeInsets.only(top: row == 0 ? 0 : _gap),
                  child: _markTile(t, column * _rows + row),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// One square of the reel, or an empty square where the list runs out — so
  /// the last column is the same width as every other one.
  Widget _markTile(UiTheme t, int at) {
    if (at >= habitSymbols.length) {
      return const SizedBox(width: _tile, height: _tile);
    }
    final mark = habitSymbols[at];
    final chosen = mark == _symbol;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Sensory.instance.tick();
        setState(() {
          _symbol = mark;
          _picking = false;
        });
        _keep();
      },
      child: Container(
        width: _tile,
        height: _tile,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: chosen ? t.accent.withValues(alpha: 0.20) : Colors.transparent,
          border: Border.all(color: chosen ? t.accent : t.stroke),
        ),
        child: HabitSigil(
          symbol: mark,
          color: chosen ? t.accent : t.fg.withValues(alpha: 0.62),
          size: 21,
        ),
      ),
    );
  }

  /// Editing writes as you go, so there is no button to press and nothing to
  /// lose by closing the sheet. A save button on a screen with two fields is a
  /// button asking you to confirm that you meant the thing you just did.
  ///
  /// Founding is the other case and keeps its button: a town is a decision,
  /// and the region it is founded with can never be changed afterwards.
  void _keep() {
    if (_creating) return;
    final store = widget.store;
    store.renameHabit(store.active, name: _name.text, symbol: _symbol);
  }

  void _found() {
    Sensory.instance.tick();
    widget.store.addHabit(_name.text, _symbol, character: _place);
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------- piezas

  /// La marca del hábito, que es además la puerta a las otras sesenta y seis.
  ///
  /// Va desnuda —sin recuadro— y flotando sobre el pueblo, así que lleva detrás
  /// un halo redondo del color de la hoja: sin él, una marca clara sobre un
  /// tejado claro deja de verse, y lo que está sobre el pueblo tiene que leerse
  /// sobre cualquier cosa que haya debajo.
  ///
  /// Y un lápiz en la esquina, porque una marca que abre sesenta y seis marcas
  /// no parece una cosa que se pueda apretar si no lo dice.
  /// Lo que mide la marca. Mediano y fijo: se probaron cinco tamaños, de
  /// cuarenta y seis a ciento ocho, y el que quedó es éste.
  static const double _mark = 74.0;

  Widget _sigil(UiTheme t, double size) {
    // El lápiz crece con la marca hasta cierto punto y ahí se para: es un aviso
    // de que la cosa se puede tocar, y un aviso del tamaño de un pulgar deja de
    // ser un aviso para ser un botón encima de la marca.
    final aviso = math.min(size, 72.0);
    return GestureDetector(
      onTap: () {
        Sensory.instance.tick();
        setState(() => _picking = !_picking);
        if (_picking) _showTheChosenOne();
      },
      child: Container(
        width: size * 2.2,
        // Más ancho que alto, y a propósito. Con el halo cuadrado quedaba medio
        // tamaño de marca de aire muerto por debajo, y con ese aire la marca no
        // se apoyaba en la hoja: flotaba encima de ella. Achatado, el aliento
        // sigue estando —es lo que la salva sobre un tejado claro— y la marca
        // baja hasta apoyarse en el canto.
        height: size * 1.30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Un aliento y no un disco. Con dos paradas y mucha alfa lo que salía
          // era una bola de luz con la marca dentro; con tres y flojas es lo que
          // tiene que ser: el aire un punto más claro alrededor de la marca, para
          // que no se pierda sobre un tejado del mismo color que ella.
          gradient: RadialGradient(
            colors: [
              t.panelStrong.withValues(alpha: t.dark ? 0.62 : 0.58),
              t.panelStrong.withValues(alpha: t.dark ? 0.30 : 0.28),
              t.panelStrong.withValues(alpha: 0),
            ],
            stops: const [0.26, 0.52, 1.0],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: _picking ? 0.88 : 1.0,
              child: HabitSigil(symbol: _symbol, color: t.accent, size: size),
            ),
            Positioned(
              right: size * 0.10,
              top: size * 0.10,
              child: Container(
                padding: EdgeInsets.all(aviso * 0.055),
                decoration: BoxDecoration(
                  color: t.dark
                      ? const Color(0xFF1A1A22)
                      : const Color(0xFFF3EEE3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit,
                  size: aviso * 0.18,
                  color: t.accent.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dónde se escribe el nombre: centrado y sin caja ninguna.
  Widget _field(UiTheme t, double size) => TextField(
    controller: _name,
    onChanged: (_) => _keep(),
    textAlign: TextAlign.center,
    style: t.body.copyWith(
      fontSize: size,
      height: 1.2,
      fontWeight: FontWeight.w500,
    ),
    textCapitalization: TextCapitalization.sentences,
    maxLength: 24,
    decoration: InputDecoration(
      hintText: 'Leer, correr, no fumar…',
      hintStyle: t.bodySoft.copyWith(fontSize: size * 0.82),
      counterText: '',
      isDense: true,
      contentPadding: EdgeInsets.zero,
      border: InputBorder.none,
    ),
  );

  /// Qué clase de sitio es este pueblo: la comarca entre dos filetes, y su
  /// línea debajo.
  Widget _region(UiTheme t, TownCharacter ch) => Column(
    key: ValueKey(ch.region),
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _hair(t, 26),
          const SizedBox(width: 10),
          HabitSigil(
            symbol: ch.symbol,
            color: t.accent.withValues(alpha: 0.85),
            size: 17,
          ),
          const SizedBox(width: 8),
          Text(
            ch.region.toUpperCase(),
            style: t.label.copyWith(
              fontSize: 11,
              color: t.accent,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(width: 10),
          _hair(t, 26),
        ],
      ),
      const SizedBox(height: 8),
      Text(ch.blurb, textAlign: TextAlign.center, style: t.bodySoft),
    ],
  );

  /// Un filete de pelo. Es la única raya que dibuja esta hoja, y de ella salen
  /// todas sus separaciones.
  Widget _hair(UiTheme t, [double? ancho]) =>
      Container(width: ancho, height: 1, color: t.fg.withValues(alpha: 0.10));

  /// Borrar un pueblo entero. Nunca es un botón grande y nunca está arriba.
  Widget _remove(UiTheme t) => Center(
    child: TextButton(
      onPressed: () => _confirmRemove(context),
      style: TextButton.styleFrom(foregroundColor: _danger(t.dark)),
      child: Text(
        'Eliminar este hábito',
        style: t.bodySoft.copyWith(fontSize: 12.5, color: _danger(t.dark)),
      ),
    ),
  );

  /// Las seis comarcas, para elegir una al fundar.
  Widget _regionPicker(UiTheme t) => Row(
    children: [
      for (final c in TownCharacter.all)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Sensory.instance.tick();
                setState(() => _place = c.order);
              },
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: c.order == _place
                      ? t.accent.withValues(alpha: 0.18)
                      : Colors.transparent,
                  border: Border.all(
                    color: c.order == _place ? t.accent : t.stroke,
                  ),
                ),
                child: HabitSigil(
                  symbol: c.symbol,
                  color: c.order == _place
                      ? t.accent
                      : t.fg.withValues(alpha: 0.55),
                  size: 22,
                ),
              ),
            ),
          ),
        ),
    ],
  );

  /// El carrete de marcas, que se abre debajo del nombre.
  Widget _reelSlot(UiTheme t) => AnimatedSize(
    duration: const Duration(milliseconds: 190),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: _picking
        ? Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _reelOfMarks(t),
          )
        : const SizedBox(width: double.infinity),
  );

  Widget _foundButton(UiTheme t) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: _found,
      style: FilledButton.styleFrom(
        backgroundColor: t.accent.withValues(alpha: 0.85),
        foregroundColor: t.dark ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text('Fundar el pueblo'),
    ),
  );

  /// De qué está hecho el velo: su color, lo sólido que es y cuánto desenfoca
  /// lo que queda debajo.
  ///
  /// De noche es siempre el mismo —oscuro sobre oscuro, que es lo que
  /// funciona— y lo único que se elige es cuánto tapa, con un deslizador. De
  /// día se elige entre cinco, porque de día es donde se rompía: una crema casi
  /// opaca sobre un prado verde no es aire espesándose, es un papel puesto
  /// encima. Las cinco tiran de lo mismo: que el velo saque su color de la
  /// escena en vez de traerlo de fuera, y que deje ver algo de lo que hay
  /// debajo.
  ({Color tinte, double tapa, double bruma}) _veil(UiTheme t, HabitSkin skin) {
    final p = t.palette;
    if (t.dark) {
      return (
        tinte: t.panelStrong,
        tapa: Appearance.instance.nightVeil,
        bruma: 0,
      );
    }
    return switch (skin) {
      HabitSkin.bruma => (
        tinte: Color.lerp(p.skyHorizon, Colors.white, 0.62)!,
        tapa: 0.74,
        bruma: 8,
      ),
      HabitSkin.arena => (
        tinte: Color.lerp(p.ground, Colors.white, 0.74)!,
        tapa: 0.76,
        bruma: 6,
      ),
      HabitSkin.cielo => (
        tinte: Color.lerp(p.skyLight, Colors.white, 0.42)!,
        tapa: 0.68,
        bruma: 14,
      ),
      HabitSkin.vidrio => (
        tinte: Color.lerp(p.skyHorizon, Colors.white, 0.50)!,
        tapa: 0.42,
        bruma: 26,
      ),
      HabitSkin.lino => (tinte: t.panelStrong, tapa: 0.62, bruma: 16),
    };
  }

  /// Envuelve algo en un desenfoque de lo que tenga detrás, o no lo envuelve.
  ///
  /// Con recorte **y** con máscara, las dos cosas. Un `BackdropFilter` suelto
  /// desenfoca la capa entera —la pantalla completa, no lo que hay debajo del
  /// hijo— así que sin recortar lo que salía era el pueblo entero borroso y la
  /// hoja encima. Y recortando a secas queda una raya horizontal donde el
  /// mundo pasa de nítido a borroso de golpe, que es peor que no desenfocar: la
  /// máscara la deshace en el mismo tramo en el que cuaja el velo, así que las
  /// dos cosas aparecen juntas y no se ve ningún canto.
  Widget _blurred(double sigma, Widget child) {
    if (sigma <= 0.5) return child;
    return ClipRect(
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
          stops: [0.0, 0.18],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ hoja

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final store = widget.store;
    final ch = _creating ? TownCharacter.byOrder(_place) : store.habit.place;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final velo = _veil(t, Appearance.instance.skin);

    // La marca va fuera del velo y no dentro, que es lo que la deja flotando
    // sobre el propio pueblo en vez de pegada al canto de una hoja. El velo
    // empieza debajo de ella y sube desde abajo: lo único que hay aquí para
    // que la letra se lea es eso, porque no hay panel.
    //
    // Y el que rueda es el de fuera y no el de dentro: con la marca grande y
    // alta, más el teclado abierto, la hoja entera puede pasar de lo que hay de
    // pantalla, y lo que tiene que poder subirse entonces es todo —marca
    // incluida— y no sólo el texto de debajo.
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sigil(t, _mark),
            // El velo, y por detrás el desenfoque de lo que haya debajo.
            _blurred(
              velo.bruma,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      velo.tinte.withValues(alpha: 0),
                      velo.tinte.withValues(alpha: velo.tapa * 0.92),
                      velo.tinte.withValues(alpha: velo.tapa),
                    ],
                    stops: const [0.0, 0.16, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // El velo arranca transparente, así que el nombre no puede ir
                    // pegado a su canto: se le deja el aire en el que el velo
                    // acaba de cuajar.
                    const SizedBox(height: _mark * 0.20),
                    if (_creating) ...[
                      Text('UN HÁBITO NUEVO', style: t.label),
                      const SizedBox(height: 12),
                    ],
                    _field(t, 21),
                    const SizedBox(height: 10),
                    _hair(t),
                    _reelSlot(t),
                    const SizedBox(height: 18),
                    if (_creating) ...[
                      Text('QUÉ CLASE DE PUEBLO', style: t.label),
                      const SizedBox(height: 10),
                      _regionPicker(t),
                      const SizedBox(height: 16),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _region(t, ch),
                    ),
                    if (_creating) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Se elige una sola vez. Después no se puede cambiar sin '
                        'mover piezas ya puestas, y eso no se hace.',
                        textAlign: TextAlign.center,
                        style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      _foundButton(t),
                    ],
                    // Sólo al fundar hay botón. Editando se escribe según se
                    // teclea, así que no hay nada que confirmar ni nada que
                    // perder al cerrar.
                    if (!_creating) ...[
                      const SizedBox(height: 14),
                      _hair(t),
                      const SizedBox(height: 6),
                      _remove(t),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    final t = widget.theme;
    final h = widget.store.habit;
    // The last one can go too, and it is worth saying what that leaves: an
    // empty valley, not an app with nothing in it.
    final onlyOne = widget.store.habits.length <= 1;
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: t.panelStrong,
        elevation: 0,
        title: Text('¿Eliminar ${h.name}?', style: t.body),
        content: Text(
          'Se borra su pueblo entero: ${h.total} piezas. No hay vuelta atrás.'
          '${onlyOne ? ' Como es el único, el valle vuelve a empezar en '
                    'blanco.' : ''}',
          style: t.bodySoft,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              widget.store.removeHabit(widget.store.active);
              Navigator.of(dialog).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              'Eliminar',
              style: TextStyle(
                color: _danger(t.dark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
