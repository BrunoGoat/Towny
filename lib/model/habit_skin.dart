/// De qué está hecho el velo de la hoja de un hábito **de día**.
///
/// La hoja no tiene panel: el texto va sobre el pueblo, con la marca encima y
/// un velo que sube desde abajo para que se lea sobre lo que haya. De noche eso
/// funciona solo y no se elige nada: oscuro sobre oscuro, al noventa y cinco
/// por ciento, que es donde quedó tras probarlo con un deslizador.
///
/// De día hay que elegir. Se probaron cinco maneras —crema, prado, cielo,
/// vidrio, lino— y la que gustó fue la de vidrio: casi sin pintura, y lo que
/// hace legible el texto es el desenfoque de lo que hay debajo. Estas diez son
/// esa misma idea llevada a diez sitios distintos: **todas son vidrio**, y lo
/// que cambia entre ellas es de qué color está teñido, cuánto pinta y cuánto
/// desenfoca.
///
/// Dos de las diez son vidrio **ahumado**: oscurecen el pueblo en vez de
/// aclararlo, y entonces la letra de la hoja se vuelve clara. Están porque en
/// un pueblo de mediodía, que es verde y brillante, oscurecer separa mejor que
/// aclarar — y porque eso es exactamente lo que ya funciona de noche.
enum HabitSkin {
  vidrio(
    'Vidrio',
    'El punto de partida: apenas teñido del color del cielo, y mucho '
        'desenfoque.',
  ),
  hondo(
    'Hondo',
    'El mismo vidrio con la mitad de pintura y casi el doble de desenfoque. '
        'Se ve el pueblo, pero no se distingue.',
  ),
  limpio(
    'Limpio',
    'Casi nada de tinte. Lo único que separa el texto del pueblo es el '
        'desenfoque. El más transparente de los diez.',
  ),
  escarcha(
    'Escarcha',
    'Vidrio helado: el tinte es blanco pero muy flojo, así que aclara sin '
        'llegar a tapar.',
  ),
  miel(
    'Miel',
    'Teñido del color del propio pueblo —el de la marca y los rótulos—, muy '
        'aclarado.',
  ),
  musgo(
    'Musgo',
    'Teñido del prado sobre el que está, subido. El que menos se pelea con '
        'el verde de debajo.',
  ),
  pizarra(
    'Pizarra',
    'El gris frío de la piedra del pueblo. Neutro: no tira ni a cálido ni a '
        'azul.',
  ),
  bruma(
    'Bruma',
    'El más cargado de los claros: el cielo de esta hora, aclarado, con '
        'bastante desenfoque.',
  ),
  ahumado(
    'Ahumado',
    'Vidrio oscuro en vez de claro: oscurece el pueblo y la letra se vuelve '
        'clara, como de noche.',
  ),
  tinta(
    'Tinta',
    'El ahumado llevado más lejos: casi negro y con la letra clara encima. '
        'El de más contraste de los diez.',
  );

  const HabitSkin(this.label, this.about);

  /// Cómo se llama en los ajustes.
  final String label;

  /// Y qué es, en una línea, para no tener que abrirlos los diez.
  final String about;

  /// Lo que hubiera guardado, o el primero. Un nombre que ya no exista —porque
  /// un día se quite uno— vuelve al primero en vez de tirar el resto de los
  /// ajustes con él.
  static HabitSkin byName(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => HabitSkin.vidrio);
}
