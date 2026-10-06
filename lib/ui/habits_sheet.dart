import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/character.dart';
import '../data/symbols.dart';
import '../fx/sensory.dart';
import '../model/cadence.dart';
import '../model/habit.dart';
import '../model/pledge.dart';
import '../model/store.dart';
import 'cadence_sheet.dart';
import 'habit_sigil.dart';
import 'plan_picker.dart';
import 'rest_sheet.dart';
import 'style.dart';

/// Todo lo que se puede cambiar de un hábito.
///
/// Fundar uno nuevo no pasa por acá: tiene su propia pantalla, la de la
/// primera vez con su bienvenida ([FirstRun] con [NextTown]), porque fundar
/// un pueblo no es rellenar un formulario.
class HabitsSheet extends StatefulWidget {
  const HabitsSheet({super.key, required this.store, required this.theme});

  final Store store;
  final UiTheme theme;

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

  /// En quién te convierte, y el plan: a qué hora y en qué sitio. También
  /// opcionales, y también editables para siempre — un plan que ya no es el
  /// tuyo se cambia acá, que es lo que el tablón manda hacer cuando ve que la
  /// hora escrita no es la hora a la que aparecés.
  late final TextEditingController _identity;
  late final TextEditingController _spot;
  int? _hour;
  late String _symbol;

  /// The marks are only worth the room when somebody is actually choosing
  /// one. Until then this sheet is a name and a mark.
  bool _picking = false;

  /// Si el reloj del plan está abierto. Cerrado, el plan es su frase; abierto,
  /// se le puede cambiar la hora y el sitio. Empieza cerrado siempre: se abre
  /// la hoja a cambiar el nombre o a pausar el pueblo muchas más veces que a
  /// mover la hora.
  bool _tuning = false;

  /// The whole catalogue of marks is four screenfuls of grid on a phone, and a sheet that
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
    final h = widget.store.habit;
    _name = TextEditingController(text: h.name);
    _why = TextEditingController(text: h.why ?? '');
    _floor = TextEditingController(text: h.floor ?? '');
    // Sin el «alguien» del principio, que va fijo delante del campo.
    _identity = TextEditingController(text: identityTail(h.identity));
    _spot = TextEditingController(text: h.vowPlace ?? '');
    _hour = h.vowHour;
    _symbol = h.symbol;
    _picking = false;
  }

  @override
  void dispose() {
    _name.dispose();
    _why.dispose();
    _floor.dispose();
    _identity.dispose();
    _spot.dispose();
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
  Widget _reelOfMarks(UiTheme t, SheetInk velo) {
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
  Widget _markTile(UiTheme t, SheetInk velo, int at) {
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
  void _keep() {
    final store = widget.store;
    store.renameHabit(store.active, name: _name.text, symbol: _symbol);
    store.describeHabit(store.active, why: _why.text, floor: _floor.text);
    store.pledgeHabit(
      store.active,
      hour: _hour,
      // Quitar la hora es tocar la que estaba puesta, así que hay que decirlo:
      // en nulo, `pledgeHabit` entiende «no la toques».
      clearHour: _hour == null,
      place: _spot.text,
      // Vacío borra; nulo sería «no la toques».
      identity: identityWhole(_identity.text) ?? '',
    );
  }

  // ---------------------------------------------------------------- piezas

  /// La marca del hábito, que es además la puerta a todas las demás.
  ///
  /// Va desnuda —sin recuadro— y flotando sobre el pueblo, así que lleva detrás
  /// un halo redondo del color de la hoja: sin él, una marca clara sobre un
  /// tejado claro deja de verse, y lo que está sobre el pueblo tiene que leerse
  /// sobre cualquier cosa que haya debajo.
  ///
  /// Y un lápiz en la esquina, porque una marca que abre todas las demás no
  /// parece una cosa que se pueda apretar si no lo dice.
  /// Lo que mide la marca. Mediano y fijo: se probaron cinco tamaños, de
  /// cuarenta y seis a ciento ocho, y el que quedó es éste.
  static const double _mark = 74.0;

  Widget _sigil(UiTheme t, SheetInk velo, double size) {
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
  Widget _field(UiTheme t, SheetInk velo, double size) => TextField(
    controller: _name,
    // Repinta porque el nombre va dentro de la frase del plan: «voy a leer a
    // las 22» cambia con cada letra del nombre.
    onChanged: (_) {
      setState(() {});
      _keep();
    },
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
  Widget _region(UiTheme t, SheetInk velo, TownCharacter ch) => Column(
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
    ],
  );

  /// Un filete de pelo. Es la única raya que dibuja esta hoja, y de ella salen
  /// todas sus separaciones.
  Widget _hair(SheetInk velo, [double? ancho]) => Container(
    width: ancho,
    height: 1,
    color: velo.cuerpo.withValues(alpha: 0.16),
  );

  /// El plan entero en un sitio: cada cuánto, a qué hora y en qué sitio.
  ///
  /// Eran dos bloques con dos títulos —CADA CUÁNTO y EL PLAN— y son una sola
  /// cosa: un plan es cada cuánto, cuándo y dónde. Separados costaban dos
  /// títulos, dos aires y la sensación de estar bajando por un formulario con
  /// secciones; juntos son dos renglones debajo de un título.
  ///
  /// Y van **plegados**. El reloj de veinticuatro horas más el renglón del
  /// sitio ocupaban doscientos píxeles de hoja para decir lo mismo que ya dice
  /// la frase de debajo, que es la que está escrita en ámbar porque es lo que
  /// dijiste vos. Así que la frase se queda a la vista y el reloj se abre al
  /// tocarla: lo que se lee todas las veces ocupa sitio, y lo que se cambia una
  /// vez al año se abre cuando se va a cambiar.
  ///
  /// Va debajo de las líneas y no encima porque no es una de ellas: las tres de
  /// arriba se escriben una vez y se leen años después, y ésta se cambia. Un
  /// plan es de cuando se escribió, y el día en que la vida se mueve de sitio
  /// —otro trabajo, otro horario, un hijo— lo que hay que hacer con el viejo es
  /// cambiarlo, no cumplirlo.
  Widget _thePlan(UiTheme t, SheetInk velo) {
    final store = widget.store;
    final h = store.habit;
    final nombre = _name.text.trim().isEmpty ? h.name : _name.text;
    final frase = vowLine(nombre, _hour, _spot.text);
    final dicho = h.perWeek;
    return Column(
      children: [
        Text(
          'EL PLAN',
          style: t.label.copyWith(
            fontSize: 9,
            letterSpacing: 1.8,
            color: velo.suave,
            shadows: velo.aliento,
          ),
        ),
        const SizedBox(height: 5),
        // Cada cuánto va: una línea, y tocarla abre la misma hoja con la que lo
        // preguntó el pueblo la primera semana.
        if (_hasCadence && dicho != null)
          _tapLine(t, velo, cadenceSaid(dicho), t.accent, () {
            Sensory.instance.tick();
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => CadenceSheet(
                habit: h,
                theme: t,
                first: false,
                onPick: (n) {
                  store.setCadence(h, n);
                  if (mounted) setState(() {});
                },
              ),
            );
          }),
        if (_hasPlan && frase != null)
          // Abierto el reloj, la frase deja de llevar lápiz: el lápiz dice
          // «esto se puede tocar», y lo que hay debajo ya lo está diciendo.
          _tapLine(t, velo, frase, t.accent, () {
            Sensory.instance.tick();
            setState(() => _tuning = !_tuning);
          }, pencil: !_tuning),
        if (_hasPlan)
          AnimatedSize(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _tuning || frase == null
                ? Column(
                    children: [
                      const SizedBox(height: 6),
                      HourReel(
                        hour: _hour,
                        onPick: (h) => setState(() {
                          // Volver a tocar la hora elegida la quita. Es la
                          // única manera de deshacer un plan con hora sin
                          // borrar el sitio, y es el gesto que uno hace solo:
                          // se toca lo que está encendido para apagarlo.
                          _hour = _hour == h ? null : h;
                          _keep();
                        }),
                        ink: velo.cuerpo.withValues(alpha: 0.82),
                        accent: t.accent,
                        plate: velo.tinte.withValues(alpha: 0.42),
                        edge: velo.cuerpo.withValues(alpha: 0.20),
                        shadows: velo.aliento,
                      ),
                      const SizedBox(height: 4),
                      _softLine(t, velo, _spot, 'EN QUÉ SITIO', 'en la cama'),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
      ],
    );
  }

  /// Un renglón que se toca: el texto centrado y, detrás de la última palabra,
  /// el mismo lápiz flojo que lleva la marca de la cabecera.
  ///
  /// Hace falta por lo mismo que hacía falta allí. Un renglón de texto centrado
  /// en medio de una hoja de lectura no parece un botón, y éstos lo son: uno
  /// abre la hoja de la frecuencia y el otro despliega el reloj. Dentro del
  /// mismo texto y no al lado, para que al partirse en dos líneas el lápiz
  /// quede donde acaba la frase y no flotando a la derecha de un hueco.
  Widget _tapLine(
    UiTheme t,
    SheetInk velo,
    String texto,
    Color color,
    VoidCallback onTap, {
    bool pencil = true,
  }) {
    final estilo = t.bodySoft.copyWith(
      fontSize: 13,
      height: 1.35,
      color: color,
      shadows: velo.aliento,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text.rich(
          TextSpan(
            text: texto,
            style: estilo,
            children: pencil
                ? [
                    const TextSpan(text: ' '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        Icons.edit,
                        size: 11,
                        color: color.withValues(alpha: 0.6),
                      ),
                    ),
                  ]
                : null,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Las líneas escritas a mano: para qué, en quién te convierte, y —sólo
  /// editando— lo mínimo que cuenta.
  ///
  /// Al fundar son dos, las mismas dos que pregunta la primera vez que se abre
  /// la app: las que hablan de lo que querés y no de cómo vas a hacerlo. Lo
  /// mínimo que cuenta es una herramienta para el día malo, y el día que se
  /// funda un pueblo no es uno; queda acá para quien lo busque, y la hoja que
  /// pregunta si seguimos manda aquí cuando hace falta.
  ///
  /// Todas opcionales y en letra floja: quien viene a fundar un pueblo no tiene
  /// que rellenar un formulario, y un campo vacío no le quita nada a nadie.
  Widget _theLines(UiTheme t, SheetInk velo) => Column(
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
        _identity,
        'EN QUIÉN TE CONVIERTE',
        'que lee todos los días',
        prefix: 'alguien',
      ),
      if (_hasFloor) ...[
        const SizedBox(height: 8),
        _softLine(
          t,
          velo,
          _floor,
          'LO MÍNIMO QUE CUENTA',
          'abrir el libro y leer una página',
        ),
      ],
    ],
  );

  /// Si el plan tiene algo que enseñar: sólo lo que ya se escribió, desde el
  /// tablón o antes de que dejara de preguntarse al fundar.
  ///
  /// Un reloj vacío esperando una hora es una tarea, y se sacó de la fundación
  /// justamente por eso. Lo propone el tablón cuando ya sabe a qué hora
  /// aparecés; acá sólo se cambia lo que ya existe. Se decide al abrir la
  /// hoja, no con cada letra: borrar el sitio no tiene que hacer desaparecer
  /// el campo en el que se está escribiendo.
  late final bool _hasPlan =
      widget.store.habit.vowHour != null || widget.store.habit.vowPlace != null;

  /// Lo mínimo que cuenta, igual que el plan: sólo si ya se escribió. Un
  /// renglón vacío más en la hoja es un formulario más largo, y esto lo
  /// propone la hoja que pregunta si seguimos el día que hace falta.
  late final bool _hasFloor = widget.store.habit.floor?.isNotEmpty ?? false;

  /// La frecuencia, sólo si ya se dijo. Sin decir, la pregunta el pueblo la
  /// primera semana con su propia hoja; enseñar acá lo que cree mientras tanto
  /// era otra línea para algo que nadie estableció.
  late final bool _hasCadence = widget.store.habit.perWeek != null;

  Widget _softLine(
    UiTheme t,
    SheetInk velo,
    TextEditingController c,
    String label,
    String hint, {
    String? prefix,
  }) {
    final letra = t.bodySoft.copyWith(
      fontSize: 13,
      height: 1.35,
      color: velo.suave,
      shadows: velo.aliento,
    );
    TextField campoDe(int renglones) => TextField(
      controller: c,
      // Se repinta además de guardarse: la frase del plan se va escribiendo
      // debajo mientras se escribe el sitio, y sin esto no se movería hasta
      // el siguiente toque en cualquier otra cosa.
      onChanged: (_) {
        setState(() {});
        _keep();
      },
      textAlign: prefix == null ? TextAlign.center : TextAlign.start,
      textCapitalization: TextCapitalization.none,
      maxLength: 70,
      maxLines: renglones,
      minLines: 1,
      style: letra,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: letra.copyWith(color: velo.cuerpo.withValues(alpha: 0.34)),
        counterText: '',
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
      ),
    );
    return Column(
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
        if (prefix == null)
          campoDe(2)
        else
          // Una palabra fija delante, que no se borra: la frase empieza ahí y
          // lo que se escribe es el resto. Las dos cosas juntas y centradas,
          // como cada renglón de esta hoja: el campo mide lo que mide lo
          // escrito, y no el ancho entero, que dejaba el «alguien» pegado a la
          // izquierda.
          LayoutBuilder(
            builder: (context, box) {
              final delante = letra.copyWith(color: t.accent);
              double ancho(String x, TextStyle st) => (TextPainter(
                text: TextSpan(text: x, style: st),
                textDirection: TextDirection.ltr,
                textScaler: MediaQuery.textScalerOf(context),
              )..layout()).width;
              final palabra = ancho(prefix, delante) + 4;
              // Lo que mide lo escrito, o la pista si no hay nada, más el
              // cursor; y nunca más que lo que queda al lado de la palabra.
              final escrito = c.text.isEmpty
                  ? ancho(hint, letra)
                  : ancho(c.text, letra);
              final cabe = math.max(40.0, box.maxWidth - palabra - 8);
              // Un renglón mientras quepa: con dos permitidos el campo
              // reservaba el segundo aunque estuviera vacío, y quedaba un
              // hueco debajo que no tenía ningún otro renglón de la hoja.
              final enUno = escrito + 14 <= cabe;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prefix, style: delante),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: math.min(escrito + 14, cabe),
                    child: campoDe(enUno ? 1 : 2),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

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
  Widget _exits(UiTheme t, SheetInk velo) {
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

  /// El carrete de marcas, que se abre debajo del nombre.
  Widget _reelSlot(UiTheme t, SheetInk velo) => AnimatedSize(
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

  /// El velo de esta hoja. La receta vive en [SheetInk] desde que la tarjeta
  /// del final de la cinemática pasó a usar la misma: una hoja ahumada con
  /// letra crema y una tarjeta de papel blanco en la misma app son dos apps.
  SheetInk _veil(UiTheme t) => SheetInk.of(t);

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
    final ch = store.habit.place;
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
            // A los lados de la marca no hay hoja: se ve el pueblo, y tocar
            // ahí es tocar fuera, como más arriba. Sin esto ese aire era de
            // la hoja —la franja entera a lo ancho— y el toque se perdía. La
            // marca sigue abriendo su carrete: el toque más hondo gana.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: SizedBox(
                width: double.infinity,
                child: Center(child: _sigil(t, velo, _mark)),
              ),
            ),
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
                    _field(t, velo, 21),
                    const SizedBox(height: 10),
                    _hair(velo),
                    _reelSlot(t, velo),
                    const SizedBox(height: 14),
                    _theLines(t, velo),
                    if (_hasCadence || _hasPlan) ...[
                      const SizedBox(height: 12),
                      _hair(velo),
                      const SizedBox(height: 10),
                      _thePlan(t, velo),
                    ],
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _region(t, velo, ch),
                    ),
                    // Sin botón de guardar: se escribe según se teclea, así
                    // que no hay nada que confirmar ni nada que perder al
                    // cerrar.
                    const SizedBox(height: 10),
                    _hair(velo),
                    const SizedBox(height: 2),
                    _exits(t, velo),
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
