/// Una pieza que se puso desde la pantalla de inicio, mientras la app no
/// estaba mirando.
///
/// El widget no puede levantar el pueblo: no tiene el rasterizador, no tiene
/// el plano y no tiene por qué tenerlos. Lo único que hace es dejar apuntado
/// que a tal hora tocaste tal hábito, y la app lo recoge la próxima vez que se
/// abre. Esto es ese apunte.
///
/// **Por qué lleva número.** Porque entre que la app lee el buzón y confirma
/// que lo aplicó puede morirse —la mata Android, se acaba la batería— y las
/// dos maneras de equivocarse son igual de malas: perder una pieza que
/// pusiste, o contártela dos veces. Con un número que sólo sube, el buzón no
/// borra nada hasta que le confirman, y la app no aplica dos veces lo que ya
/// tiene apuntado. Ninguna de las dos se pierde por un apagón a destiempo.
class Arrival {
  const Arrival({
    required this.serial,
    required this.habitId,
    required this.when,
  });

  /// Su sitio en la cola del buzón. Sólo sube, nunca se reutiliza.
  final int serial;

  /// A qué hábito. Por id y no por hueco: un hábito se puede borrar mientras
  /// tanto, y entonces lo que llega es de un pueblo que ya no existe.
  final String habitId;

  /// La hora a la que se tocó, que es la que cuenta — no la de llegada.
  final DateTime when;

  /// Lo que manda el buzón, tal cual llega del otro lado.
  ///
  /// Nada de aquí es de fiar: lo escribió otro proceso y pudo haberse quedado
  /// a medias. Lo que no se entiende se devuelve como nulo y se tira.
  static Arrival? parse(Object? raw) {
    if (raw is! Map) return null;
    final n = raw['n'];
    final id = raw['h'];
    final t = raw['t'];
    if (n is! num || id is! String || t is! num) return null;
    if (id.isEmpty) return null;
    return Arrival(
      serial: n.toInt(),
      habitId: id,
      when: DateTime.fromMillisecondsSinceEpoch(t.toInt()),
    );
  }

  /// Todas las del buzón, en orden y sin las que no se entienden.
  static List<Arrival> parseAll(Object? raw) {
    if (raw is! List) return const [];
    final out = <Arrival>[];
    for (final e in raw) {
      final a = parse(e);
      if (a != null) out.add(a);
    }
    out.sort((a, b) => a.serial.compareTo(b.serial));
    return out;
  }
}
