/// De qué está hecha la hoja de un hábito.
///
/// Es la única hoja de la app en la que se escribe algo —el nombre, la marca—
/// y la única en la que se puede borrar un pueblo entero, así que es la que más
/// se mira de cerca. Diez maneras de presentarla, y todas dicen exactamente lo
/// mismo: la marca, el nombre, qué clase de sitio es y cómo se va.
///
/// Lo que cambia es de qué está hecha y cómo se reparte, no cuánta letra hay.
/// Ninguna de las diez añade ni quita un dato — quien elige elige un material,
/// no una versión con más cosas.
///
/// Las diez se ven de día y de noche sin tocar un color a mano: todo sale de la
/// paleta de la hora, igual que el resto de la app, así que la misma hoja es
/// pergamino al mediodía y ceniza de madrugada.
enum HabitSkin {
  vidrio(
    'Vidrio',
    'La de siempre: vidrio esmerilado, esquinas muy redondas y el nombre '
        'subrayado.',
  ),
  papel(
    'Papel',
    'Sin desenfoque y con menos curva: una hoja de papel apoyada, con una '
        'raya fina bajo la cabecera.',
  ),
  ficha(
    'Ficha',
    'Una ficha que flota con aire por los cuatro lados y un canto de color '
        'a la izquierda.',
  ),
  placa(
    'Placa',
    'Un borde marcado, esquinas casi rectas y el nombre en versalitas: una '
        'placa atornillada.',
  ),
  desnudo(
    'Desnudo',
    'Sin panel ninguno. El texto sobre el pueblo, con rayas de pelo por toda '
        'separación.',
  ),
  pergamino(
    'Pergamino',
    'Doble filete alrededor y todo centrado, como la primera página de un '
        'libro.',
  ),
  cinta(
    'Cinta',
    'Una banda de color arriba con la marca y el nombre dentro, y lo demás '
        'debajo.',
  ),
  columna(
    'Columna',
    'Todo en el eje: la marca grande arriba del todo, el nombre debajo y el '
        'resto en fila.',
  ),
  margen(
    'Margen',
    'La marca y los rótulos en un margen a la izquierda, separados por un '
        'filete vertical.',
  ),
  sello(
    'Sello',
    'La marca en un medallón redondo montado sobre el canto de la hoja, como '
        'un lacre.',
  );

  const HabitSkin(this.label, this.about);

  /// Cómo se llama en los ajustes.
  final String label;

  /// Y qué es, en una línea, para no tener que abrirlas las diez.
  final String about;

  /// Lo que hubiera guardado, o la de siempre. Un nombre que ya no exista
  /// —porque un día se quite una— vuelve a la primera en vez de tirar el resto
  /// de los ajustes con él.
  static HabitSkin byName(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => HabitSkin.vidrio);
}
