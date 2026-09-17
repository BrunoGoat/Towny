/// Cómo se presenta la hoja de un hábito.
///
/// Es la única hoja de la app en la que se escribe algo —el nombre, la marca— y
/// la única desde la que se puede borrar un pueblo entero, así que es la que
/// más se mira de cerca.
///
/// **Las cinco son la misma hoja.** No hay panel: el texto va sobre el pueblo,
/// con un velo que sube desde abajo para que se lea sobre lo que haya —hierba,
/// tejado o cielo— y filetes de pelo por toda separación. Llegaron a estar
/// hechas diez —vidrio, papel, ficha, placa, pergamino, cinta, columna, margen,
/// sello— y se eligió ésta, así que las otras nueve se fueron. Del sello se
/// quedó lo que tenía de bueno: la marca grande, centrada y por encima de todo,
/// con el nombre debajo.
///
/// Lo único que cambia entre las cinco es **cuánto mide esa marca y a qué
/// altura flota**. Ninguna añade ni quita un dato.
///
/// Las cinco se ven de día y de noche sin tocar un color a mano: todo sale de
/// la paleta de la hora, igual que el resto de la app.
enum HabitSkin {
  apenas(
    'Apenas',
    'La marca pequeña y pegada al texto. Lo más callado de las cinco.',
    mark: 46,
    lift: 2,
    titulo: 18,
  ),
  bajo(
    'Bajo',
    'Marca mediana, poco aire por encima: la hoja empieza casi enseguida.',
    mark: 58,
    lift: 14,
    titulo: 20,
  ),
  medio(
    'Medio',
    'Marca grande y a media altura. El punto de equilibrio entre las cinco.',
    mark: 74,
    lift: 30,
    titulo: 21,
  ),
  alto(
    'Alto',
    'La misma marca grande pero muy arriba, flotando sola sobre el pueblo.',
    mark: 82,
    lift: 58,
    titulo: 22,
  ),
  gigante(
    'Gigante',
    'La marca enorme, por encima de todo, y el nombre a su medida.',
    mark: 108,
    lift: 26,
    titulo: 24,
  );

  const HabitSkin(
    this.label,
    this.about, {
    required this.mark,
    required this.lift,
    required this.titulo,
  });

  /// Cómo se llama en los ajustes.
  final String label;

  /// Y qué es, en una línea, para no tener que abrirlas las cinco.
  final String about;

  /// Lo que mide la marca de lado a lado.
  final double mark;

  /// Cuánto aire queda por encima de ella: lo que la separa del pueblo y la
  /// hace flotar más o menos alto.
  final double lift;

  /// Y de qué cuerpo va el nombre, que tiene que ir a la medida de la marca —
  /// una marca de ciento ocho con un nombre de dieciocho es una marca con un
  /// pie de foto.
  final double titulo;

  /// Lo que hubiera guardado, o la de siempre. Un nombre que ya no exista
  /// —porque un día se quite una— vuelve a la de en medio en vez de tirar el
  /// resto de los ajustes con él.
  static HabitSkin byName(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => HabitSkin.medio);
}
