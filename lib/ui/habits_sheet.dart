import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/character.dart';
import '../data/symbols.dart';
import '../fx/sensory.dart';
import '../model/habit.dart';
import '../model/store.dart';
import 'habit_sigil.dart';
import 'rest_sheet.dart';
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

  /// Para qué es esto, y qué es lo más chico que cuenta. Las dos opcionales.
  late final TextEditingController _why;
  late final TextEditingController _floor;
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
    _why = TextEditingController(text: _creating ? '' : (h.why ?? ''));
    _floor = TextEditingController(text: _creating ? '' : (h.floor ?? ''));
    _symbol = _creating ? habitSymbols.first : h.symbol;
    _place = _creating
        ? TownCharacter.forSlot(widget.store.habits.length).order
        : h.character;
    _picking = false;
  }

  @override
  void dispose() {
    _name.dispose();
    _why.dispose();
    _floor.dispose();
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
  Widget _reelOfMarks(UiTheme t, _Veil velo) {
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
                  child: _markTile(t, velo, column * _rows + row),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// One square of the reel, or an empty square where the list runs out — so
  /// the last column is the same width as every other one.
  Widget _markTile(UiTheme t, _Veil velo, int at) {
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
          // Un plato de vidrio espesado debajo de cada marca.
          //
          // Es lo mismo que el `aliento` hace detrás de las letras, y hacía
          // falta por lo mismo: la hoja es un vidrio casi transparente, y una
          // marca dibujada encima cae sobre una fuente o medio tejado. Sin el
          // plato, lo que se veía era el pueblo a través del icono.
          color: chosen
              ? t.accent.withValues(alpha: 0.20)
              : velo.tinte.withValues(alpha: 0.42),
          border: Border.all(
            color: chosen ? t.accent : velo.cuerpo.withValues(alpha: 0.20),
          ),
        ),
        child: HabitSigil(
          symbol: mark,
          // **La tinta del velo, no la del tema.** Era el fallo entero: de día
          // el vidrio es ahumado y la letra va crema, pero las marcas iban en
          // `t.fg`, que a esa hora es marrón oscuro. El texto de al lado se
          // leía y los iconos desaparecían, y era el mismo icono.
          color: chosen ? t.accent : velo.cuerpo.withValues(alpha: 0.82),
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
    store.describeHabit(store.active, why: _why.text, floor: _floor.text);
  }

  void _found() {
    Sensory.instance.tick();
    widget.store.addHabit(
      _name.text,
      _symbol,
      character: _place,
      why: _why.text,
      floor: _floor.text,
    );
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

  Widget _sigil(UiTheme t, _Veil velo, double size) {
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
          // era una bola de luz con la marca dentro; con tres y flojas es lo
          // que tiene que ser: el aire alrededor de la marca, un punto más
          // denso, para que no se pierda sobre un tejado.
          //
          // Y del color de la propia hoja, que es lo que la ata a ella. Salía
          // de `panelStrong`, que de día es crema: sobre un velo ahumado eso
          // era un foco blanco encendido justo encima de una hoja oscura, y lo
          // que tiene que parecer es que la hoja sube un poco para recibirla.
          gradient: RadialGradient(
            colors: [
              velo.tinte.withValues(alpha: 0.66),
              velo.tinte.withValues(alpha: 0.32),
              velo.tinte.withValues(alpha: 0),
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
                // La pastilla del lápiz, del color del velo: de crema sobre
                // una hoja ahumada era el segundo foco blanco de la cabecera.
                decoration: BoxDecoration(
                  color: Color.lerp(velo.tinte, Colors.black, 0.15)!,
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
  Widget _field(UiTheme t, _Veil velo, double size) => TextField(
    controller: _name,
    onChanged: (_) => _keep(),
    textAlign: TextAlign.center,
    style: t.body.copyWith(
      fontSize: size,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: velo.cuerpo,
      shadows: velo.aliento,
    ),
    textCapitalization: TextCapitalization.sentences,
    maxLength: 24,
    decoration: InputDecoration(
      hintText: 'Leer, correr, no fumar…',
      hintStyle: t.bodySoft.copyWith(
        fontSize: size * 0.82,
        color: velo.suave,
        shadows: velo.aliento,
      ),
      counterText: '',
      isDense: true,
      contentPadding: EdgeInsets.zero,
      border: InputBorder.none,
    ),
  );

  /// Qué clase de sitio es este pueblo: la comarca entre dos filetes, y su
  /// línea debajo.
  Widget _region(UiTheme t, _Veil velo, TownCharacter ch) => Column(
    key: ValueKey(ch.region),
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _hair(velo, 26),
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
              shadows: velo.aliento,
            ),
          ),
          const SizedBox(width: 10),
          _hair(velo, 26),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        ch.blurb,
        textAlign: TextAlign.center,
        style: t.bodySoft.copyWith(color: velo.suave, shadows: velo.aliento),
      ),
    ],
  );

  /// Un filete de pelo. Es la única raya que dibuja esta hoja, y de ella salen
  /// todas sus separaciones.
  Widget _hair(_Veil velo, [double? ancho]) => Container(
    width: ancho,
    height: 1,
    color: velo.cuerpo.withValues(alpha: 0.16),
  );

  /// Las dos líneas que sólo se leen el día malo.
  ///
  /// Van juntas y debajo del nombre porque son la misma pregunta hecha por los
  /// dos lados: para qué querés esto, y qué es lo más chico que sigue
  /// contando. La primera es lo que se olvida cuando se acaba el entusiasmo;
  /// la segunda es lo que decide si un día flojo termina en cero o en algo.
  ///
  /// Las dos opcionales y las dos en letra floja: quien viene a fundar un
  /// pueblo y ponerse a ello no tiene que rellenar un formulario, y un campo
  /// vacío acá no le quita nada a nadie. No se enseñan en ningún día bueno —
  /// salen en el susurro de vuelta y en la hoja que pregunta si seguimos.
  Widget _theTwoLines(UiTheme t, _Veil velo) => Column(
    children: [
      _softLine(
        t,
        velo,
        _why,
        'PARA QUÉ',
        'para tener más energía durante el día',
      ),
      const SizedBox(height: 8),
      _softLine(
        t,
        velo,
        _floor,
        'LO MÍNIMO QUE CUENTA',
        'abrir el libro y leer una página',
      ),
    ],
  );

  Widget _softLine(
    UiTheme t,
    _Veil velo,
    TextEditingController c,
    String label,
    String hint,
  ) => Column(
    children: [
      Text(
        label,
        style: t.label.copyWith(
          fontSize: 9,
          letterSpacing: 1.8,
          color: velo.suave,
          shadows: velo.aliento,
        ),
      ),
      const SizedBox(height: 3),
      TextField(
        controller: c,
        onChanged: (_) => _keep(),
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.none,
        maxLength: 70,
        maxLines: 2,
        minLines: 1,
        style: t.bodySoft.copyWith(
          fontSize: 13,
          height: 1.35,
          color: velo.suave,
          shadows: velo.aliento,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: t.bodySoft.copyWith(
            fontSize: 13,
            height: 1.35,
            color: velo.cuerpo.withValues(alpha: 0.34),
            shadows: velo.aliento,
          ),
          counterText: '',
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
      ),
    ],
  );

  /// Las dos salidas de un hábito que no está yendo, una al lado de la otra.
  ///
  /// En la misma fila y no una debajo de otra, y no sólo por el alto: puestas
  /// juntas se leen como lo que son, dos respuestas a la misma situación entre
  /// las que hay que elegir. Dormirlo va primero y en la tinta del velo;
  /// borrarlo va segundo y en el color con el que se dicen las cosas que no se
  /// deshacen.
  ///
  /// Dormirlo está acá y no sólo en la hoja que pregunta si seguimos, porque
  /// una pausa casi siempre se decide antes y no después: uno sabe que se va de
  /// viaje el martes que viene. Que la única manera de pausar fuera desaparecer
  /// cuatro días y esperar a que la app preguntara sería pedirle a la gente que
  /// falle primero para poder decir que no va a poder.
  Widget _exits(UiTheme t, _Veil velo) {
    final h = widget.store.habit;
    final duerme = h.resting;
    // El rojo de aviso, en la versión que se lee sobre este velo: el oscuro se
    // apaga hasta parecer texto desactivado sobre un vidrio ahumado.
    final rojo = _danger(t.dark || velo.oscuro);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: TextButton(
            onPressed: duerme ? () => _wake(h) : () => _sleep(t, h),
            child: Text(
              duerme ? 'Despertar el pueblo' : 'Pausar este pueblo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySoft.copyWith(
                fontSize: 12.5,
                color: duerme ? t.accent : velo.suave,
                shadows: velo.aliento,
              ),
            ),
          ),
        ),
        Flexible(
          child: TextButton(
            onPressed: () => _confirmRemove(context),
            style: TextButton.styleFrom(foregroundColor: rojo),
            child: Text(
              'Eliminar este hábito',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySoft.copyWith(
                fontSize: 12.5,
                color: rojo,
                shadows: velo.aliento,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _wake(Habit h) {
    Sensory.instance.tick();
    widget.store.wake(h);
    setState(() {});
  }

  void _sleep(UiTheme t, Habit h) {
    Sensory.instance.tick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: sheetScrim(t.dark),
      builder: (_) => RestSheet(
        habit: h,
        theme: t,
        onRest: (cuando) => widget.store.rest(h, cuando),
      ),
    ).whenComplete(() {
      if (mounted) setState(() {});
    });
  }

  /// Las seis comarcas, para elegir una al fundar.
  Widget _regionPicker(UiTheme t, _Veil velo) => Row(
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
                      : velo.tinte.withValues(alpha: 0.42),
                  border: Border.all(
                    color: c.order == _place
                        ? t.accent
                        : velo.cuerpo.withValues(alpha: 0.20),
                  ),
                ),
                child: HabitSigil(
                  symbol: c.symbol,
                  color: c.order == _place
                      ? t.accent
                      : velo.cuerpo.withValues(alpha: 0.82),
                  size: 22,
                ),
              ),
            ),
          ),
        ),
    ],
  );

  /// El carrete de marcas, que se abre debajo del nombre.
  Widget _reelSlot(UiTheme t, _Veil velo) => AnimatedSize(
    duration: const Duration(milliseconds: 190),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: _picking
        ? Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _reelOfMarks(t, velo),
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
  _Veil _veil(UiTheme t) {
    final p = t.palette;
    // De noche: oscuro sobre oscuro al noventa y cinco por ciento, que es el
    // número al que se llegó probándolo con un deslizador.
    if (t.dark) {
      return _Veil(tinte: t.panelStrong, tapa: 0.95, bruma: 0, cuerpo: t.fg);
    }
    // Y de día, lo mismo. Se probaron quince maneras de hacerlo claro —crema,
    // prado, cielo, escarcha, miel, musgo, pizarra, y ocho vidrios de distinta
    // transparencia— y la que quedó fue ésta: vidrio **ahumado**. En un
    // mediodía verde y brillante, oscurecer separa mejor que aclarar, que es
    // justo lo que ya funcionaba a las once de la noche; y la hoja se ve igual
    // a cualquier hora en vez de darse la vuelta a las siete de la tarde.
    //
    // La tinta va clara encima, y no blanca: crema con una gota del color del
    // pueblo. El blanco de papel sobre esto es lo único que se sigue viendo de
    // fuera.
    return _Veil(
      tinte: Color.lerp(p.ink, Colors.black, 0.30)!,
      tapa: 0.72,
      bruma: 18,
      cuerpo: Color.lerp(const Color(0xFFF3EEE3), p.accent, 0.16)!,
      oscuro: true,
    );
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
    final velo = _veil(t);

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
            _sigil(t, velo, _mark),
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
                      Text(
                        'UN HÁBITO NUEVO',
                        style: t.label.copyWith(
                          color: velo.suave,
                          shadows: velo.aliento,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _field(t, velo, 21),
                    const SizedBox(height: 10),
                    _hair(velo),
                    _reelSlot(t, velo),
                    const SizedBox(height: 14),
                    _theTwoLines(t, velo),
                    const SizedBox(height: 14),
                    if (_creating) ...[
                      Text(
                        'QUÉ CLASE DE PUEBLO',
                        style: t.label.copyWith(
                          color: velo.suave,
                          shadows: velo.aliento,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _regionPicker(t, velo),
                      const SizedBox(height: 16),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _region(t, velo, ch),
                    ),
                    if (_creating) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Se elige una sola vez. Después no se puede cambiar sin '
                        'mover piezas ya puestas, y eso no se hace.',
                        textAlign: TextAlign.center,
                        style: t.bodySoft.copyWith(
                          fontSize: 11.5,
                          height: 1.4,
                          color: velo.suave,
                          shadows: velo.aliento,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _foundButton(t),
                    ],
                    // Sólo al fundar hay botón. Editando se escribe según se
                    // teclea, así que no hay nada que confirmar ni nada que
                    // perder al cerrar.
                    if (!_creating) ...[
                      const SizedBox(height: 10),
                      _hair(velo),
                      const SizedBox(height: 2),
                      _exits(t, velo),
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

/// De qué está hecho el velo de la hoja, y con qué tinta se escribe encima.
///
/// Las dos cosas juntas y no por separado, porque no son dos decisiones: un
/// vidrio ahumado pide letra clara y uno de escarcha la pide oscura, y
/// elegirlas por separado es la manera de acabar con letra parda sobre un
/// vidrio casi negro.
class _Veil {
  const _Veil({
    required this.tinte,
    required this.tapa,
    required this.bruma,
    required this.cuerpo,
    this.oscuro = false,
  });

  /// De qué color está teñido el vidrio.
  final Color tinte;

  /// Y cuánto pinta: cero es un cristal limpio, uno es una pared.
  final double tapa;

  /// Cuánto desenfoca lo que queda debajo. En estos diez es lo que hace el
  /// trabajo, más que la pintura.
  final double bruma;

  /// La tinta de todo lo que se escribe encima.
  final Color cuerpo;

  /// Si el vidrio oscurece el pueblo en vez de aclararlo. Cambia el rojo del
  /// botón de borrar, que es lo único que no sale de [cuerpo].
  final bool oscuro;

  /// Lo mismo, apagado: para lo que acompaña y no es el nombre.
  Color get suave => cuerpo.withValues(alpha: 0.66);

  /// El aliento que va detrás de las letras: el propio color del velo, soplado
  /// alrededor. El velo es casi transparente —es un vidrio, esa es la gracia—
  /// así que el texto cae encima de la plaza y se pierde entre una fuente y
  /// medio tejado. Esto espesa el velo **sólo donde hay letra**: no se lee como
  /// una sombra, se lee como que ahí el cristal está un poco más empañado.
  List<Shadow> get aliento => [
    Shadow(color: tinte.withValues(alpha: 0.95), blurRadius: 10),
    Shadow(color: tinte.withValues(alpha: 0.75), blurRadius: 22),
  ];
}
