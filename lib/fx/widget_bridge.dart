import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/symbols.dart';
import '../engine/sigils.dart';
import '../model/arrival.dart';
import '../model/habit.dart';
import '../model/piece.dart';

/// El hilo entre la app y el cuadrito de la pantalla de inicio.
///
/// **Por qué hay un hilo y no una memoria compartida.** Lo obvio sería que el
/// widget leyera el mismo guardado que la app, y durante media tarde lo hizo:
/// el problema es que ese guardado ya no es un fichero de texto sino un
/// almacén de Jetpack que sólo puede tener un dueño vivo por proceso, y el
/// widget y la app viven en el mismo proceso. Abrirlo dos veces es un choque.
///
/// Así que cada uno tiene lo suyo y esto es la aduana. La app **publica** un
/// resumen —seis hábitos, su marca dibujada y si hoy ya pusiste— que es todo
/// lo que el widget necesita para pintarse; el widget **apunta** en su buzón
/// lo que se toca, y la app lo recoge al abrirse. Ninguno de los dos escribe
/// donde escribe el otro, que es la única manera de que dos procesos no se
/// pisen sin tener que ponerse de acuerdo.
class WidgetBridge {
  WidgetBridge._();
  static final WidgetBridge instance = WidgetBridge._();

  /// Uno nuevo, para los tests. El de verdad es único y recuerda si del otro
  /// lado hay alguien; un test que lo apague se lo apagaría a los siguientes.
  @visibleForTesting
  factory WidgetBridge.fresh() => WidgetBridge._();

  @visibleForTesting
  static const MethodChannel channel = MethodChannel('towny/widget');

  /// Cuántos pueblos entran en el valle, que son los que entran en el widget.
  static const int room = Habit.maxSlots;

  /// Lo que mide la marca que se manda, en píxeles.
  ///
  /// Noventa y seis: la fila la dibuja a veinticuatro puntos, y un teléfono
  /// denso de los de hoy multiplica por tres. Mandarla más grande es mandar
  /// bytes que nadie mira; más chica se ve el escalón.
  static const int markPx = 96;

  /// Las marcas ya dibujadas, por símbolo. Una marca no cambia nunca, y
  /// volver a rasterizar seis en cada publicación es trabajo que no hace nada.
  final Map<String, Uint8List> _drawn = {};

  bool _off = false;

  /// Lo que hay que enseñar en la pantalla de inicio, ahora mismo.
  ///
  /// Se manda entero cada vez y no lo que cambió: son seis filas de texto y
  /// seis marcas que ya estaban dibujadas, y un resumen entero no puede quedar
  /// a medias, que es lo que sí puede pasarle a una lista de cambios.
  Future<void> publish(List<Habit> habits, {DateTime? now}) async {
    if (_off) return;
    final hoy = now ?? DateTime.now();
    final filas = <Map<String, Object?>>[];
    for (final h in habits.take(room)) {
      filas.add({
        'id': h.id,
        'name': h.name,
        // Cuántas lleva hoy ese pueblo, y de qué día es esa cuenta.
        //
        // La cuenta y no un sí o un no. Lo que alguien quiere saber mirando la
        // pantalla de inicio no es sólo si apareció hoy: es cuánto lleva
        // hecho, y hacerle abrir la app para eso es cobrarle un peaje por una
        // información que cabe en un dígito. Registrar lo que hiciste y poder
        // verlo es de lo que va esto; el widget no está para proteger a la app
        // de ser útil.
        //
        // De hoy, y de nada más: ni rachas ni totales. «Llevás tres hoy» es lo
        // que hiciste; «llevás nueve días seguidos» es una cuenta que castiga
        // el día que se rompe, y ésa no la lleva la app por dentro.
        'today': _todayOf(h, hoy),
        // Y el día al que pertenece, para que el otro lado no enseñe la cuenta
        // de ayer a la hora del desayuno: allí no hay reloj que avise de que
        // cambió la fecha, y el resumen puede llevar horas puesto.
        'day': dayKey(hoy),
        // Un pueblo dormido no se despinta, se apaga: sigue ahí, y tocarlo lo
        // despierta, igual que dentro.
        'resting': h.restAt(hoy) != null,
        'mark': await _mark(h.symbol),
      });
    }
    await _send('publish', {'habits': filas});
  }

  /// Lo que se tocó mientras la app no estaba.
  ///
  /// No vacía el buzón: eso lo hace [ack] cuando las piezas ya están puestas y
  /// guardadas. Entre las dos llamadas la app puede morirse, y entonces lo que
  /// tocaste sigue ahí para la próxima vez — que es exactamente lo que tiene
  /// que pasar.
  Future<List<Arrival>> drain() async {
    if (_off) return const [];
    final raw = await _send('drain', const {});
    return Arrival.parseAll(raw);
  }

  /// Y ya se pueden olvidar las de hasta [serial] inclusive.
  Future<void> ack(int serial) async {
    if (_off || serial <= 0) return;
    await _send('ack', {'upTo': serial});
  }

  int _todayOf(Habit h, DateTime now) {
    final k = dayKey(now);
    var n = 0;
    for (var i = h.pieces.length - 1; i >= 0; i--) {
      final d = dayKey(h.pieces[i].placedAt);
      if (d == k) {
        n++;
        continue;
      }
      // La fila está en orden de reloj, así que en cuanto se pasa del día de
      // hoy hacia atrás no queda ninguna de hoy más abajo.
      if (d < k) break;
    }
    return n;
  }

  /// La marca de un hábito, dibujada en blanco sobre nada.
  ///
  /// En blanco porque del color se encarga el otro lado: el widget está sobre
  /// el fondo de pantalla de alguien y tiene que poder ir en tinta clara de
  /// noche y oscura de día, y eso desde aquí no se sabe. Se manda la forma y
  /// allí se tiñe.
  Future<Uint8List?> _mark(String symbol) async {
    final id = resolveHabitSymbol(symbol);
    final ya = _drawn[id];
    if (ya != null) return ya;
    try {
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      HabitSigils.draw(
        canvas,
        const ui.Rect.fromLTWH(0, 0, markPx * 1.0, markPx * 1.0),
        id,
        const ui.Color(0xFFFFFFFF),
      );
      final img = await rec.endRecording().toImage(markPx, markPx);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (bytes == null) return null;
      final png = bytes.buffer.asUint8List();
      _drawn[id] = png;
      return png;
    } catch (_) {
      // Una fila sin marca es una fila con su nombre, que se puede tocar
      // igual. Nada de esto vale una pantalla en blanco.
      return null;
    }
  }

  Future<Object?> _send(String name, Map<String, Object?> args) async {
    try {
      return await channel.invokeMethod<Object?>(name, args);
    } on MissingPluginException {
      // No hay widget de este lado —iOS, la web, un test— y no lo va a haber
      // durante el resto de la vida de este proceso. Se deja de preguntar.
      _off = true;
      return null;
    } catch (_) {
      return null;
    }
  }
}
