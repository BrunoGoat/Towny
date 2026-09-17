/// De qué manera se sube al valle.
///
/// Hay diez y se eligen en los ajustes, lo cual es mucho para una transición —
/// y es a propósito. Esto es lo que más veces se va a ver de toda la app
/// después del propio pueblo: se hace cada vez que uno quiere comparar dos
/// hábitos. Una sola manera, por buena que sea, se gasta; diez hacen que la
/// que uno tiene puesta sea **suya**, y que probar las otras sea una cosa más
/// que mirar.
///
/// Las diez cumplen la misma condición y no es negociable: a mitad de camino
/// tapan la pantalla entera. Ahí es donde la cámara salta del pueblo al valle
/// —doscientos metros y otro giro en un fotograma— y una rendija de dos
/// píxeles en ese instante tira el truco entero. Cada una lo consigue por su
/// cuenta y por construcción, y hay un test que lo mide píxel a píxel en las
/// diez.
///
/// Vive en `model` y no con sus dibujos porque es lo que alguien eligió: se
/// guarda en el disco junto al volumen y al hemisferio, y los ajustes no
/// pueden depender de cómo se pinta una nube.
enum FlightStyle {
  /// Dos bancos de cúmulos que se cierran, uno subiendo y otro bajando.
  cumulos('Cúmulos', 'Dos bancos que se cierran, uno sube y otro baja.', 750),

  /// Lo mismo pero de lado: dos cortinas que se juntan en el medio.
  cortina(
    'Cortina',
    'Lo mismo pero de lado, como dos hojas de un portón.',
    750,
  ),

  /// Un ojo de nube que se cierra sobre el centro y se vuelve a abrir.
  ojo('Ojo', 'La nube se cierra sobre el centro y se vuelve a abrir.', 660),

  /// Franjas finas que entran alternando izquierda y derecha.
  cirros(
    'Cirros',
    'Franjas finas cruzando con viento, una para cada lado.',
    720,
  ),

  /// Sin silueta: se cierra la niebla y ya está. La más callada de las diez.
  niebla(
    'Niebla',
    'Sin silueta ninguna: se cierra y ya está. La más callada.',
    820,
  ),

  /// Un campo de bolas blandas que se junta hasta no dejar hueco.
  algodon(
    'Algodón',
    'Un campo de bolas blandas que se junta hasta no dejar hueco.',
    760,
  ),

  /// Una nevada que blanquea la pantalla.
  nevada(
    'Nevada',
    'Primero se ve nevar y después deja de verse todo lo demás.',
    820,
  ),

  /// Un ojo que además gira: la nube se cierra en espiral.
  remolino('Remolino', 'Como el ojo, pero girando: se cierra en espiral.', 720),

  /// Un picado: la nube viene de frente y se te echa encima.
  picado(
    'Picado',
    'La nube viene de frente y se te echa encima. La más corta.',
    620,
  ),

  /// Un chaparrón: gris, con la lluvia cruzando.
  tormenta(
    'Aguacero',
    'Gris y con la lluvia cruzando. La única que no es pastel.',
    820,
  );

  const FlightStyle(this.label, this.about, this.millis);

  /// Cómo se llama en los ajustes.
  final String label;

  /// Y qué es, en una línea, para no tener que probarlas todas a ciegas.
  final String about;

  /// Cuánto dura. No todas quieren lo mismo: un picado que dura lo que una
  /// nevada no es un picado.
  final int millis;

  Duration get span => Duration(milliseconds: millis);

  /// Lo que hubiera guardado, o la de siempre. Un nombre que ya no exista
  /// —porque un día se quite un estilo— vuelve a la primera en vez de tirar
  /// el resto de los ajustes con él.
  static FlightStyle byName(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => FlightStyle.cumulos);
}
