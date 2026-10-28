/// Las letras que puede llevar un papel del tablón.
///
/// Van en el repositorio y no traídas de internet: un tablón tiene que poder
/// leerse en un tren sin cobertura.
///
/// Son pocas: la de las notas que el pueblo escribe de vos, y la tuya. Antes
/// había nueve manos más, una por vecino, para los bandos del pueblo; se
/// fueron con ellos.
///
/// ## Licencias
///
/// Todas llevan licencia abierta de fuentes o Apache, así que todas se pueden
/// publicar. Aquí no entra ninguna que no se pueda: hubo cinco de prueba —Mi
/// pueblo, Verde, Recta, Torcida y Sureña— que sin licencia clara viajaban
/// dentro de cada APK, y por eso se fueron del repositorio enteras.
library;

enum NoteFont {
  /// La del sistema, que es con la que venía. Se queda para poder comparar.
  sistema(null, null, 'La de ahora', 1.0),

  // La de las notas que clavás vos: todo lo que clavás lo escribe la misma
  // persona, que sos vos.
  rotulador('PermanentMarker', 'PermanentMarker.ttf', 'Rotulador', 0.93),

  // La de las notas que el pueblo escribe de vos. Ya no hay otras que
  // elegir: las que se probaban a mano se fueron con el selector.
  arquitecta(
    'ArchitectsDaughter',
    'ArchitectsDaughter.ttf',
    'Arquitecta',
    1.01,
  );

  const NoteFont(this.family, this.asset, this.label, this.scale);

  /// Null quiere decir la del sistema.
  final String? family;

  /// El archivo, dentro de `assets/fonts/`. En un solo sitio porque hay un
  /// test que las carga todas para medir si el texto cabe, y dos listas de
  /// nombres de archivo se separan en cuanto se añade una.
  final String? asset;

  final String label;

  /// Cuánto hay que agrandarla para que quepa lo mismo por línea que las demás.
  ///
  /// Medido, no puesto a ojo: es cuánto ocupa una frase larga con esta letra
  /// comparada con la de referencia: sin esto, cambiar de letra sería cambiar de
  /// tamaño.
  final double scale;

  static NoteFont? porNombre(String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
