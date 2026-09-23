import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/rng.dart';
import '../data/bandos.dart';
import '../engine/board_plan.dart';
import '../engine/solids.dart';
import '../fx/sensory.dart';
import '../model/appearance.dart';
import '../model/board.dart';
import '../model/board_slots.dart';
import '../model/habit.dart';
import '../model/notice.dart';
import '../model/store.dart';
import 'board_scene.dart';
import 'style.dart';

/// El tablón de la plaza, al que uno se acerca.
///
/// Ya no es una pantalla con el tablón dibujado encima: es el tablón, el mismo
/// que está clavado en la plaza, con su cámara, sus postes, su tejadito y sus
/// hojas de papel puestas en el mundo. Se recorre y se tocan las hojas.
///
/// Todo lo que hay que saber de fuera son las notas, y ésas salen de lo que el
/// pueblo tiene apuntado. Ninguna existe hasta que hay bastante detrás para
/// que sea verdad, así que un tablón vacío no es un fallo: es el pueblo
/// diciendo que todavía no te conoce.
class NoticeBoardScreen extends StatefulWidget {
  const NoticeBoardScreen({
    super.key,
    required this.valley,
    required this.habit,
    required this.theme,
    this.dice = false,
    this.store,
  });

  /// Los pueblos del valle, [habit] incluido: de ahí salen las notas que
  /// comparan dos hábitos y la corona. Pide la lista y no el almacén para que
  /// se le pueda enseñar un valle inventado sin tocar el de verdad.
  final List<Habit> valley;
  final Habit habit;
  final UiTheme theme;

  /// Enseña un dado que vuelve a repartir el tablón con notas al azar.
  ///
  /// Sólo para el tablón de mentira de los ajustes. Es lo que hace falta para
  /// probar una letra y un cuerpo de verdad: con las notas de siempre uno mira
  /// diez papeles y se queda tranquilo, y el que se sale por el borde es el
  /// bando número trescientos doce, que no ha visto nunca.
  final bool dice;

  /// Con almacén se pueden clavar y quitar notas tuyas; sin él, el tablón es
  /// sólo de lectura. El de mentira de los ajustes no lo lleva, y así no hay
  /// manera de clavar una nota en un pueblo que no existe.
  final Store? store;

  /// La ruta que te lleva hasta él. El acercamiento lo hace la cámara dentro
  /// de la escena —se llega al tablón desde un lado y desde lejos—, así que
  /// aquí sólo se funde: dos acercamientos, uno encima del otro, se pisan.
  static Route<void> route({
    required List<Habit> valley,
    required Habit habit,
    required UiTheme theme,
    Store? store,
  }) => PageRouteBuilder<void>(
    opaque: false,
    barrierColor: sheetScrim(theme.dark),
    transitionDuration: const Duration(milliseconds: 240),
    // La vuelta dura algo más que antes porque ya no es un corte al final del
    // tirón hacia atrás: se pide a mitad, y lo que se ve es el tablón
    // alejándose mientras se abre el pueblo debajo.
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => NoticeBoardScreen(
      valley: valley,
      habit: habit,
      theme: theme,
      store: store,
    ),
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: a,
        curve: Curves.easeOutCubic,
        // Al irse, tarda en empezar a borrarse y luego se va de golpe: así el
        // tablón se lee todavía durante el primer trozo del tirón, que es
        // cuando la cámara aún no ha ganado velocidad.
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    ),
  );

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  /// La hora con la que se pinta el cielo del tablón. La misma que el valle,
  /// hora fingida incluida: si no, se entra al tablón y amanece de golpe.
  double get _hora {
    if (Appearance.instance.fakeHour) return Appearance.instance.fakeHourAt;
    final now = DateTime.now();
    return now.hour + now.minute / 60.0;
  }

  late BoardPlan _plan;

  /// Lo que hay clavado y en qué hueco va cada uno, guardado aparte del plano.
  ///
  /// El plano no lo dice —una vez armado, un papel sólo sabe en qué punto de
  /// la madera cayó— y para cambiar dos de sitio hace falta saber quién tiene
  /// cuál.
  List<Notice> _said = const [];
  List<int> _slots = const [];

  /// Qué tirada del dado va. Cero es el tablón de verdad.
  int _roll = 0;

  @override
  void initState() {
    super.initState();
    _plan = _real();
  }

  /// Clavar una nota tuya.
  Future<void> _clavar() async {
    Sensory.instance.tick();
    final text = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WriteSheet(theme: widget.theme),
    );
    if (text == null || !mounted) return;
    widget.store!.pinNote(widget.habit, text);
    setState(() {
      _plan = _real();
      // Rehace las hojas: maquetar es caro y no se hace al pintar, así que la
      // escena necesita una llave nueva para enterarse de que hay un papel más.
      _roll++;
    });
  }

  /// Llevar el papel [i] al hueco [slot].
  ///
  /// El plano se rehace una vez, al soltar. Durante el arrastre no se toca
  /// nada: lo que se ve moverse lo dibuja la escena por su cuenta, que es lo
  /// que evita volver a maquetar diez hojas sesenta veces por segundo.
  ///
  /// Y **sin llave nueva**, al revés que clavar o quitar. La llave rehace la
  /// escena entera, y rehacerla devuelve la cámara a la entrada: acabás de
  /// soltar un papel en el lado derecho del tablón y el tablón te lleva al
  /// izquierdo. Aquí no hace falta, porque la escena ya se entera sola de que
  /// el plano cambió.
  void _mover(int i, int slot) {
    if (i < 0 || i >= _slots.length || slot < 0) return;
    final mio = _slots[i];
    if (mio == slot) return;
    final huecos = [..._slots];
    final otro = huecos.indexOf(slot);
    if (otro >= 0) huecos[otro] = mio;
    huecos[i] = slot;

    // En el tablón de mentira de los ajustes no hay nada que guardar: sus
    // notas son bandos sacados al azar y su pueblo no existe. El gesto se
    // prueba igual, y eso es justo para lo que está ese tablón.
    if (widget.store != null) {
      BoardSlots.instance.place(
        widget.habit.id,
        [for (final n in _said) noticeId(n)],
        i,
        slot,
      );
    }
    setState(() {
      _slots = huecos;
      _plan = BoardPlan.of(_said, slots: huecos);
    });
  }

  BoardPlan _real() {
    final said = boardNotices(widget.habit, valley: widget.valley);
    _said = said;
    _slots = BoardSlots.instance.assign(
      widget.habit.id,
      said,
      slots: NoticeBoard.capacity,
    );
    return BoardPlan.of(
      said,
      // Dónde quedó clavado cada papel. La misma tabla que mira el pueblo para
      // dibujar la silueta de su tablón, así que lo que se ve desde el valle y
      // lo que se ve al entrar es lo mismo.
      slots: _slots,
    );
  }

  /// Un tablón lleno de lo que haya: las notas del pueblo mezcladas con bandos
  /// sacados al azar de los cuatrocientos treinta y seis.
  ///
  /// Los huecos también van al azar y no por la tabla de siempre: lo que se
  /// prueba con esto es si el texto cabe, y para eso hace falta que salgan los
  /// largos, los cortos y los raros, no los diez de siempre.
  void _tirar() {
    Sensory.instance.tick();
    final semilla = ++_roll * 7919 + DateTime.now().millisecondsSinceEpoch;
    final reales = boardNotices(
      widget.habit,
      valley: widget.valley,
    ).where((n) => n.kind != NoticeKind.pueblo).toList();
    final said = <Notice>[];
    final huecos = <int>[];
    final libres = [for (var i = 0; i < NoticeBoard.capacity; i++) i];
    for (var i = libres.length - 1; i > 0; i--) {
      final j = hashInt(i + 1, semilla, i, 5);
      final t = libres[i];
      libres[i] = libres[j];
      libres[j] = t;
    }
    for (var i = 0; i < NoticeBoard.capacity; i++) {
      // Una de cada tres de las de verdad, cuando las haya, y el resto bandos.
      final real = reales.isNotEmpty && hash01(semilla, i, 1) < 0.35;
      if (real) {
        said.add(reales[hashInt(reales.length, semilla, i, 2)]);
      } else {
        final (dice, y) = bandos[hashInt(bandos.length, semilla, i, 3)];
        said.add(Notice(NoticeKind.pueblo, dice, y));
      }
      huecos.add(libres[i]);
    }
    setState(() {
      _said = said;
      _slots = huecos;
      _plan = BoardPlan.of(said, slots: huecos);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: ListenableBuilder(
      listenable: Appearance.instance,
      builder: (context, _) {
        // Sigue escuchando a Appearance porque el cielo del tablón lleva la
        // hora fingida de los ajustes.
        return Stack(
          children: [
            Positioned.fill(
              child: BoardScene(
                // La clave rehace las hojas en cada tirada del dado: maquetar
                // es caro y no puede hacerse al pintar.
                key: ValueKey(_roll),
                plan: _plan,
                habit: widget.habit,
                palette: widget.theme.palette,
                hourOfDay: _hora,
                onLeave: () => Navigator.of(context).maybePop(),
                // Llevar un papel a otro hueco. Va también en el tablón de
                // mentira de los ajustes: no hay nada que guardar allí, pero
                // probar el gesto sin tener que fundar un pueblo es
                // precisamente para lo que ese tablón existe.
                onMove: _mover,
                onUnpin: widget.store == null
                    ? null
                    : (said) {
                        Sensory.instance.tick();
                        widget.store!.unpinNote(widget.habit, said);
                        setState(() {
                          _plan = _real();
                          _roll++;
                        });
                      },
              ),
            ),
            if (widget.dice)
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: _tirar,
                    icon: const Icon(Icons.casino_outlined, size: 22),
                    color: Colors.white.withValues(alpha: 0.92),
                    tooltip: 'Volver a repartir el tablón',
                  ),
                ),
              ),
            if (widget.store != null)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PinButton(theme: widget.theme, onTap: _clavar),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// El botón de clavar, abajo y discreto.
///
/// Discreto a propósito: el tablón es para leerlo, y lo primero que se hace al
/// llegar es mirar qué hay clavado. Escribir viene después, y sólo a veces.
///
/// Del mismo vidrio que las hojas de la app y no de `Frosted`, que de día es
/// papel claro: esto va sobre un tablón de madera al sol, y un rectángulo de
/// papel encima de otro se lee como un fallo de recorte.
class _PinButton extends StatelessWidget {
  const _PinButton({required this.theme, required this.onTap});

  final UiTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final velo = SheetInk.of(theme);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: velo.bruma, sigmaY: velo.bruma),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: velo.tinte.withValues(alpha: velo.tapa),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: velo.canto),
            ),
            child: Text(
              'Clavar una nota',
              style: theme.bodySoft.copyWith(
                fontSize: 13,
                color: velo.cuerpo,
                shadows: velo.aliento,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dónde se escribe.
///
/// Una línea y poco más. Lo que se clava en un tablón es un recordatorio o una
/// promesa, no una entrada de diario: para lo largo ya está la bitácora, donde
/// va la leyenda de cada pieza.
///
/// **Minimalista quiere decir que no hay nada que leer antes de escribir.**
/// Había un rótulo, un párrafo explicando de qué iba el papel, una caja con su
/// marco y su contador, y un botón ámbar del ancho de la pantalla: cinco cosas
/// para pedir una línea. Ahora hay un renglón y, debajo, la palabra que lo
/// clava. Lo que hacía el párrafo —decir que la nota va en papel tuyo y con tu
/// letra— lo dice mejor el propio tablón en cuanto se clava la primera.
class _WriteSheet extends StatefulWidget {
  const _WriteSheet({required this.theme});

  final UiTheme theme;

  @override
  State<_WriteSheet> createState() => _WriteSheetState();
}

class _WriteSheetState extends State<_WriteSheet> {
  final TextEditingController _c = TextEditingController();

  /// Lo más largo que puede ser una nota. El papel del tablón no da para más,
  /// y una nota que no cabe en su papel no es una nota corta mal contada: es
  /// otra cosa, y para esa otra cosa está la bitácora.
  static const int _tope = 90;

  @override
  void initState() {
    super.initState();
    _c.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _clavar() {
    final texto = _c.text.trim();
    if (texto.isEmpty) return;
    Navigator.of(context).pop(texto);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final velo = SheetInk.of(t);
    final hay = _c.text.trim().isNotEmpty;
    // Lo que queda, y sólo cuando queda poco. Un contador puesto siempre
    // convierte escribir una línea en rellenar un formulario.
    final queda = _tope - _c.text.characters.length;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: velo.bruma, sigmaY: velo.bruma),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
            decoration: BoxDecoration(
              color: velo.tinte.withValues(alpha: velo.tapa),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(top: BorderSide(color: velo.canto)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: velo.cuerpo.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _c,
                  autofocus: true,
                  maxLength: _tope,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  style: t.body.copyWith(
                    fontSize: 17,
                    height: 1.3,
                    color: velo.cuerpo,
                  ),
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    // Sin marco, sin relleno y sin contador: la caja de texto
                    // no tiene por qué parecer una caja.
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                    border: InputBorder.none,
                    hintText: 'Lo que quieras acordarte de mirar acá.',
                    hintStyle: t.body.copyWith(
                      fontSize: 17,
                      height: 1.3,
                      color: velo.cuerpo.withValues(alpha: 0.38),
                    ),
                  ),
                  onSubmitted: (_) => _clavar(),
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: velo.canto),
                Row(
                  children: [
                    if (queda <= 20)
                      Text(
                        '$queda',
                        style: t.bodySoft.copyWith(
                          fontSize: 12,
                          color: queda <= 0 ? t.accent : velo.tenue,
                        ),
                      ),
                    const Spacer(),
                    // La acción, en una palabra y en ámbar. Apagada mientras no
                    // hay nada que clavar, en vez de escondida: un botón que
                    // aparece de golpe al escribir la primera letra es un botón
                    // que se mueve debajo del dedo.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: hay ? _clavar : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 14,
                        ),
                        child: Text(
                          'CLAVARLA',
                          style: TextStyle(
                            color: hay ? t.accent : velo.tenue,
                            fontSize: 11.5,
                            letterSpacing: 2.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
