/// Los ritmos que la app decide por su cuenta.
///
/// Queda uno solo: cuándo se abre el segundo solar del valle. Lo que se
/// construye, cuándo y cuánto cuesta vive en el plan de cada pueblo
/// (`engine/town.dart`), dicho sólo en piezas.
///
/// Acá vivía también lo rápido que se apagaba un pueblo sin piezas: día y
/// medio de gracia y dos semanas hasta quedar casi a oscuras, iguales para
/// todos. Se quitó. Un hábito de una vez por semana pasaba seis días de cada
/// siete apagándose sin haber faltado a nada, y un pueblo apagado le decía a
/// quien lo miraba que estaba fallando — que es justo lo que esta app no
/// quiere que se sienta. Lo construido se queda como está, con las luces
/// puestas; volver se sigue celebrando, pero medido contra tu ritmo (ver
/// `Store.awayAfter`).
class Pacing {
  const Pacing._();

  /// Cuántos días con pieza hacen falta para poder fundar el segundo pueblo, y
  /// en cuántos días se pueden juntar.
  ///
  /// Diez de catorce, y las dos cifras importan. Diez porque es lo que se
  /// tarda en saber si una cosa va a aguantar o era el entusiasmo del primer
  /// domingo. Catorce y no diez porque exigir diez seguidos sería una racha, y
  /// una racha es exactamente lo que esta app dejó de medir: se puede fallar
  /// cuatro veces por el camino y la puerta se abre igual.
  ///
  /// Se abre una sola vez y no se vuelve a cerrar. Un candado que se cierra
  /// castigaría a quien vuelve después de un mes fuera, que es la persona para
  /// la que está hecho todo lo demás de acá.
  static const int unlockDays = 10;
  static const int unlockWindow = 14;
}
