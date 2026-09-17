/// De qué está hecho el fondo de la hoja de un hábito **de día**.
///
/// La hoja no tiene panel: el texto va sobre el pueblo, con la marca grande
/// encima y un velo que sube desde abajo para que se lea sobre lo que haya
/// —hierba, tejado o cielo—. De noche eso funciona solo: el velo es oscuro
/// sobre un pueblo oscuro y lo que se ve es el mismo aire, un punto más denso.
///
/// De día no. El velo era una crema casi opaca, y una crema casi opaca sobre un
/// prado verde es una tarjeta blanca pegada encima: el corte se ve, el color no
/// es de aquí, y lo que era «el aire se espesa» pasa a ser «alguien puso un
/// papel». Cinco maneras de que no lo sea, y las cinco tiran de lo mismo: que
/// el velo saque su color de la escena en vez de traerlo de fuera, y que deje
/// ver algo de lo que hay debajo.
///
/// Lo sólido que es de noche no se elige aquí: eso es un deslizador, porque es
/// un número y no una manera.
enum HabitSkin {
  bruma(
    'Bruma',
    'El color del cielo de esta hora, aclarado y flojo. Lo que se espesa es '
        'el aire, y el aire ya tiene un color.',
  ),
  arena(
    'Arena',
    'El color del propio prado, subido. El velo sale del suelo sobre el que '
        'está, así que no hay dos colores peleando.',
  ),
  cielo(
    'Cielo',
    'La luz de arriba traída abajo, con algo de desenfoque: como mirar el '
        'pueblo a través de una ventana.',
  ),
  vidrio(
    'Vidrio',
    'Casi sin tinte: lo que hace legible el texto es el desenfoque y no la '
        'pintura. El pueblo se sigue viendo debajo.',
  ),
  lino(
    'Lino',
    'La crema de siempre, pero mucho más floja y desenfocada. La más clara '
        'de las cinco.',
  );

  const HabitSkin(this.label, this.about);

  /// Cómo se llama en los ajustes.
  final String label;

  /// Y qué es, en una línea, para no tener que abrirlas las cinco.
  final String about;

  /// Lo que hubiera guardado, o la de siempre. Un nombre que ya no exista
  /// —porque un día se quite una— vuelve a la primera en vez de tirar el resto
  /// de los ajustes con él.
  static HabitSkin byName(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => HabitSkin.bruma);
}
