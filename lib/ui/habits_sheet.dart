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
  //
  // Las diez maneras de ver esta hoja se montan con las mismas cinco piezas.
  // Lo que cambia de una a otra es de qué está hecha la hoja y cómo se
  // reparten, nunca cuántas son: quien elige elige un material, no una versión
  // con más cosas.

  /// La marca del hábito, que es además la puerta a las otras sesenta y seis.
  ///
  /// Un lápiz en la esquina, porque una marca que abre treinta y seis marcas
  /// no parece una cosa que se pueda apretar si no lo dice.
  Widget _sigil(
    UiTheme t, {
    double size = 54,
    bool circle = false,
    bool bare = false,
  }) {
    final forma = circle ? BoxShape.circle : BoxShape.rectangle;
    return GestureDetector(
      onTap: () {
        Sensory.instance.tick();
        setState(() => _picking = !_picking);
        if (_picking) _showTheChosenOne();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: bare
            ? null
            : BoxDecoration(
                shape: forma,
                color: t.fg.withValues(alpha: _picking ? 0.12 : 0.07),
                borderRadius: circle
                    ? null
                    : BorderRadius.circular(size * 0.30),
                border: Border.all(color: _picking ? t.accent : t.stroke),
              ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            HabitSigil(symbol: _symbol, color: t.accent, size: size * 0.56),
            Positioned(
              right: bare ? -8 : -3,
              top: bare ? -4 : -3,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: t.dark
                      ? const Color(0xFF1A1A22)
                      : const Color(0xFFF3EEE3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit,
                  size: size * 0.19,
                  color: t.accent.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dónde se escribe el nombre.
  Widget _field(
    UiTheme t, {
    bool underline = true,
    bool boxed = false,
    TextAlign align = TextAlign.start,
    double size = 17,
    double spacing = 0,
    FontWeight weight = FontWeight.w400,
  }) => TextField(
    controller: _name,
    onChanged: (_) => _keep(),
    textAlign: align,
    style: t.body.copyWith(
      fontSize: size,
      letterSpacing: spacing,
      fontWeight: weight,
    ),
    textCapitalization: TextCapitalization.sentences,
    maxLength: 24,
    decoration: InputDecoration(
      hintText: 'Leer, correr, no fumar…',
      hintStyle: t.bodySoft.copyWith(letterSpacing: spacing),
      counterText: '',
      isDense: boxed,
      contentPadding: boxed
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
          : null,
      filled: boxed,
      fillColor: boxed ? t.fg.withValues(alpha: 0.05) : null,
      border: boxed
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.stroke),
            )
          : underline
          ? UnderlineInputBorder(borderSide: BorderSide(color: t.stroke))
          : InputBorder.none,
      enabledBorder: boxed
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.stroke),
            )
          : null,
    ),
  );

  /// Qué clase de sitio es este pueblo: la comarca y su línea.
  Widget _region(UiTheme t, TownCharacter ch, {required _Reg como}) {
    final marca = HabitSigil(
      symbol: ch.symbol,
      color: t.accent.withValues(alpha: 0.85),
      size: 17,
    );
    final rotulo = Text(
      ch.region.toUpperCase(),
      style: t.label.copyWith(
        fontSize: 11,
        color: t.accent,
        letterSpacing: 2.4,
      ),
    );
    switch (como) {
      case _Reg.fila:
        return Column(
          key: ValueKey(ch.region),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [marca, const SizedBox(width: 8), rotulo]),
            const SizedBox(height: 5),
            Text(ch.blurb, style: t.bodySoft),
          ],
        );
      case _Reg.centro:
        return Column(
          key: ValueKey(ch.region),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _hair(t, 26),
                const SizedBox(width: 10),
                marca,
                const SizedBox(width: 8),
                rotulo,
                const SizedBox(width: 10),
                _hair(t, 26),
              ],
            ),
            const SizedBox(height: 7),
            Text(ch.blurb, textAlign: TextAlign.center, style: t.bodySoft),
          ],
        );
      case _Reg.sello:
        return Column(
          key: ValueKey(ch.region),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [marca, const SizedBox(width: 7), rotulo],
              ),
            ),
            const SizedBox(height: 7),
            Text(ch.blurb, style: t.bodySoft),
          ],
        );
    }
  }

  /// Un filete de pelo. Es la única raya que dibuja esta hoja, y de ella salen
  /// las separaciones de la mitad de las diez.
  Widget _hair(UiTheme t, [double? ancho]) =>
      Container(width: ancho, height: 1, color: t.fg.withValues(alpha: 0.10));

  /// Borrar un pueblo entero. Nunca es un botón grande y nunca está arriba.
  Widget _remove(UiTheme t, {bool boxed = false, bool centred = false}) {
    final hoja = TextButton(
      onPressed: () => _confirmRemove(context),
      style: TextButton.styleFrom(
        foregroundColor: _danger(t.dark),
        padding: boxed
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            : null,
        shape: boxed
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: _danger(t.dark).withValues(alpha: 0.4)),
              )
            : null,
      ),
      child: Text(
        'Eliminar este hábito',
        style: t.bodySoft.copyWith(fontSize: 12.5, color: _danger(t.dark)),
      ),
    );
    return Align(
      alignment: centred ? Alignment.center : Alignment.centerLeft,
      child: hoja,
    );
  }

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

  /// El carrete de marcas, que se abre debajo de donde esté la marca.
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

  /// El asa de arriba. Una raya cuando la hoja es una hoja; nada cuando no hay
  /// hoja de la que tirar.
  Widget _grab(UiTheme t, HabitSkin skin) {
    switch (skin) {
      case HabitSkin.desnudo:
      // El medallón del sello ya hace de asa. Una raya debajo de él son dos
      // asas, una encima de otra.
      case HabitSkin.sello:
        return const SizedBox(height: 4);
      case HabitSkin.placa:
      case HabitSkin.pergamino:
        return Center(child: _hair(t, 54));
      default:
        return Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: t.fg.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
    }
  }

  // ------------------------------------------------------------------ hoja

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final store = widget.store;
    final ch = _creating ? TownCharacter.byOrder(_place) : store.habit.place;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final skin = Appearance.instance.skin;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: _dressed(t, skin, _inside(t, skin, ch)),
    );
  }

  /// De qué está hecha la hoja.
  Widget _dressed(UiTheme t, HabitSkin skin, Widget dentro) {
    switch (skin) {
      case HabitSkin.vidrio:
        return Frosted(
          theme: t,
          strong: true,
          radius: 30,
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
          child: dentro,
        );

      // Papel: sin desenfoque y con poca curva. Lo que hace legible al resto de
      // las hojas es el desenfoque de detrás; ésta lo cambia por pintura, que
      // es lo que hace que se lea como algo apoyado encima y no como un cambio
      // en el aire.
      case HabitSkin.papel:
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
          decoration: BoxDecoration(
            color: t.dark ? const Color(0xFF16151C) : const Color(0xFFFAF5EA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(
              top: BorderSide(color: t.fg.withValues(alpha: 0.12)),
            ),
          ),
          child: dentro,
        );

      // Ficha: aire por los cuatro lados y un canto de color. La hoja deja de
      // estar pegada al borde de abajo, que es lo que la convierte en una cosa
      // suelta sobre el pueblo en vez de en un cajón que sube.
      case HabitSkin.ficha:
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            // IntrinsicHeight y no `stretch` a secas: una hoja se mide por lo
            // que trae dentro, y una fila estirada dentro de un hueco suelto
            // se come la pantalla entera para que el canto llegue abajo.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: t.accent.withValues(alpha: 0.75)),
                  Expanded(
                    child: Frosted(
                      theme: t,
                      strong: true,
                      radius: 0,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                      child: dentro,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      // Placa: borde marcado y esquinas casi rectas.
      case HabitSkin.placa:
        return Container(
          decoration: BoxDecoration(
            color: t.panelStrong,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            border: Border.all(
              color: t.accent.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
          child: dentro,
        );

      // Desnudo: no hay hoja. Sólo un velo que sube desde abajo para que la
      // letra se lea sobre lo que haya —hierba, tejado o cielo— y nada más.
      case HabitSkin.desnudo:
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                t.panelStrong.withValues(alpha: 0),
                t.panelStrong.withValues(alpha: t.dark ? 0.78 : 0.82),
                t.panelStrong.withValues(alpha: t.dark ? 0.88 : 0.92),
              ],
              stops: const [0.0, 0.22, 1.0],
            ),
          ),
          child: dentro,
        );

      // Pergamino: doble filete, como el marco de la primera página de un
      // libro. Dos rayas y no una, porque una sola es un borde y dos son un
      // marco — y lo que se busca aquí es que la hoja se lea como una página.
      case HabitSkin.pergamino:
        return Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: t.panelStrong,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border.all(color: t.accent.withValues(alpha: 0.30)),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border.all(color: t.fg.withValues(alpha: 0.12)),
            ),
            child: dentro,
          ),
        );

      case HabitSkin.cinta:
        return Frosted(
          theme: t,
          strong: true,
          radius: 26,
          padding: EdgeInsets.zero,
          child: dentro,
        );

      case HabitSkin.columna:
        return Frosted(
          theme: t,
          strong: true,
          radius: 22,
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 26),
          child: dentro,
        );

      case HabitSkin.margen:
        return Frosted(
          theme: t,
          strong: true,
          radius: 26,
          padding: const EdgeInsets.fromLTRB(18, 16, 20, 26),
          child: dentro,
        );

      // Sello: el medallón se monta sobre el canto de arriba, así que la hoja
      // deja sitio para media marca y el Stack no recorta.
      case HabitSkin.sello:
        return Padding(
          padding: const EdgeInsets.only(top: 34),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Frosted(
                theme: t,
                strong: true,
                radius: 24,
                padding: const EdgeInsets.fromLTRB(24, 44, 24, 26),
                child: dentro,
              ),
              Positioned(
                top: -34,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.panelStrong,
                    border: Border.all(color: t.accent.withValues(alpha: 0.45)),
                  ),
                  child: _sigil(t, size: 56, circle: true),
                ),
              ),
            ],
          ),
        );
    }
  }

  /// Y cómo se reparte por dentro.
  Widget _inside(UiTheme t, HabitSkin skin, TownCharacter ch) {
    final centrado =
        skin == HabitSkin.pergamino ||
        skin == HabitSkin.columna ||
        skin == HabitSkin.sello;
    final reg = switch (skin) {
      HabitSkin.ficha => _Reg.sello,
      HabitSkin.pergamino ||
      HabitSkin.columna ||
      HabitSkin.sello => _Reg.centro,
      _ => _Reg.fila,
    };

    // Lo que va debajo de la cabecera. En el margen se mete hasta donde
    // empieza la columna de texto —que es lo que hace que sea un margen y no
    // una marca suelta arriba a la izquierda— y en las demás va a ras.
    final sangria = skin == HabitSkin.margen ? 75.0 : 0.0;

    final resto = <Widget>[
      const SizedBox(height: 20),
      if (_creating) ...[
        Text('QUÉ CLASE DE PUEBLO', style: t.label),
        const SizedBox(height: 10),
        _regionPicker(t),
        const SizedBox(height: 12),
      ],
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _region(t, ch, como: reg),
      ),
      if (_creating) ...[
        const SizedBox(height: 8),
        Text(
          'Se elige una sola vez. Después no se puede cambiar sin mover piezas '
          'ya puestas, y eso no se hace.',
          textAlign: centrado ? TextAlign.center : TextAlign.start,
          style: t.bodySoft.copyWith(fontSize: 11.5, height: 1.4),
        ),
        const SizedBox(height: 18),
        _foundButton(t),
      ],
      // Sólo al fundar hay botón. Editando se escribe según se teclea, así que
      // no hay nada que confirmar ni nada que perder al cerrar.
      if (!_creating) ...[
        if (skin == HabitSkin.desnudo || skin == HabitSkin.margen) ...[
          const SizedBox(height: 16),
          _hair(t),
        ],
        const SizedBox(height: 10),
        _remove(
          t,
          boxed: skin == HabitSkin.ficha || skin == HabitSkin.placa,
          centred: centrado,
        ),
      ],
    ];

    final cuerpo = <Widget>[
      if (skin != HabitSkin.cinta) _grab(t, skin),
      if (skin != HabitSkin.cinta) const SizedBox(height: 16),
      if (_creating) ...[
        if (centrado)
          Center(child: Text('UN HÁBITO NUEVO', style: t.label))
        else
          Text('UN HÁBITO NUEVO', style: t.label),
        const SizedBox(height: 12),
      ],

      ..._head(t, skin),
      _reelSlot(t),

      Padding(
        padding: EdgeInsets.only(left: sangria),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: centrado
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: resto,
        ),
      ),
    ];

    final columna = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centrado
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: cuerpo,
    );

    // La cinta lleva su banda pegada al canto de arriba, así que su relleno va
    // por dentro y no en la hoja.
    if (skin == HabitSkin.cinta) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _band(t),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
              child: columna,
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(child: columna);
  }

  /// La banda de la cinta: la marca y el nombre dentro de una franja de color.
  Widget _band(UiTheme t) => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
    color: t.accent.withValues(alpha: t.dark ? 0.20 : 0.16),
    child: Row(
      children: [
        _sigil(t, size: 46),
        const SizedBox(width: 14),
        Expanded(child: _field(t, underline: false, size: 18)),
      ],
    ),
  );

  /// La cabecera: la marca y el nombre, repartidos según la hoja.
  List<Widget> _head(UiTheme t, HabitSkin skin) {
    switch (skin) {
      // La banda ya los lleva dentro.
      case HabitSkin.cinta:
        return const [];

      // El medallón ya está montado en el canto, así que aquí sólo va el
      // nombre, centrado y debajo.
      case HabitSkin.sello:
        return [_field(t, underline: false, align: TextAlign.center, size: 19)];

      // La marca grande y centrada, el nombre debajo.
      case HabitSkin.columna:
        return [
          Center(child: _sigil(t, size: 64)),
          const SizedBox(height: 12),
          _field(t, align: TextAlign.center, size: 18),
        ];

      case HabitSkin.pergamino:
        return [
          Center(child: _sigil(t, size: 52, bare: true)),
          const SizedBox(height: 10),
          _field(
            t,
            underline: false,
            align: TextAlign.center,
            size: 17,
            spacing: 1.4,
          ),
          const SizedBox(height: 6),
          Center(child: _hair(t, 120)),
        ];

      // Versalitas en caja: una placa tiene el nombre grabado dentro de un
      // recuadro, no colgando de una raya.
      case HabitSkin.placa:
        return [
          Row(
            children: [
              _sigil(t, size: 50),
              const SizedBox(width: 14),
              Expanded(
                child: _field(
                  t,
                  boxed: true,
                  size: 16,
                  spacing: 1.2,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ];

      // Un margen a la izquierda con la marca, un filete, y el nombre en la
      // columna de la derecha: la caja de un manuscrito.
      case HabitSkin.margen:
        return [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 58,
                  child: Center(child: _sigil(t, size: 46, bare: true)),
                ),
                Container(width: 1, color: t.fg.withValues(alpha: 0.10)),
                const SizedBox(width: 16),
                Expanded(child: _field(t, underline: false, size: 18)),
              ],
            ),
          ),
        ];

      // Sin recuadro y sin subrayado: la marca suelta y el nombre suelto, que
      // es lo que queda cuando se le quita todo lo demás.
      case HabitSkin.desnudo:
        return [
          Row(
            children: [
              _sigil(t, size: 46, bare: true),
              const SizedBox(width: 18),
              Expanded(child: _field(t, underline: false, size: 19)),
            ],
          ),
          const SizedBox(height: 6),
          _hair(t),
        ];

      case HabitSkin.ficha:
        return [
          Row(
            children: [
              _sigil(t, size: 50, circle: true),
              const SizedBox(width: 14),
              Expanded(child: _field(t, size: 17)),
            ],
          ),
        ];

      case HabitSkin.vidrio:
      case HabitSkin.papel:
        return [
          Row(
            children: [
              _sigil(t),
              const SizedBox(width: 14),
              Expanded(child: _field(t)),
            ],
          ),
        ];
    }
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

/// Las tres maneras de decir de qué comarca es el pueblo.
enum _Reg {
  /// La marca y el rótulo en fila, la línea debajo.
  fila,

  /// Lo mismo pero en el eje, con un filete a cada lado del rótulo.
  centro,

  /// El rótulo dentro de una pastilla, como un sello estampado.
  sello,
}
