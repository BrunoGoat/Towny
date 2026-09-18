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

  BoardPlan _real() {
    final said = boardNotices(widget.habit, valley: widget.valley);
    return BoardPlan.of(
      said,
      // Dónde quedó clavado cada papel. La misma tabla que mira el pueblo para
      // dibujar la silueta de su tablón, así que lo que se ve desde el valle y
      // lo que se ve al entrar es lo mismo.
      slots: BoardSlots.instance.assign(
        widget.habit.id,
        said,
        slots: NoticeBoard.capacity,
      ),
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
    setState(() => _plan = BoardPlan.of(said, slots: huecos));
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
class _PinButton extends StatelessWidget {
  const _PinButton({required this.theme, required this.onTap});

  final UiTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Frosted(
        theme: t,
        radius: 30,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.push_pin_outlined, size: 16, color: t.fgSoft),
            const SizedBox(width: 8),
            Text('Clavar una nota', style: t.bodySoft.copyWith(fontSize: 13)),
          ],
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
class _WriteSheet extends StatefulWidget {
  const _WriteSheet({required this.theme});

  final UiTheme theme;

  @override
  State<_WriteSheet> createState() => _WriteSheetState();
}

class _WriteSheetState extends State<_WriteSheet> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Frosted(
        theme: t,
        strong: true,
        radius: 28,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UNA NOTA TUYA', style: t.label),
            const SizedBox(height: 8),
            Text(
              'Se clava en el tablón, en papel limpio y con tu letra, para que '
              'no se confunda con lo que el pueblo averiguó.',
              style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _c,
              autofocus: true,
              maxLength: 90,
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: t.body,
              cursorColor: t.accent,
              decoration: InputDecoration(
                hintText: 'Lo que quieras acordarte de mirar acá.',
                hintStyle: t.bodySoft.copyWith(fontSize: 13),
                counterStyle: t.bodySoft.copyWith(fontSize: 10),
                filled: true,
                fillColor: t.fg.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: t.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: t.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: t.accent.withValues(alpha: 0.7),
                  ),
                ),
              ),
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_c.text),
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent.withValues(alpha: 0.85),
                  foregroundColor: t.dark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text('Clavarla'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
