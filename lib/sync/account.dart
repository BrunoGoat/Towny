/// Quién es la persona, para saber de quién es cada valle en la nube.
///
/// Se entra con un código que llega por correo: sin contraseña que recordar,
/// y sin nada que configurar fuera de Supabase. Más adelante se suma Google,
/// como otra manera de entrar a la misma cuenta.
library;

abstract interface class Account {
  /// Manda el código a [email]. Si no se pudo (sin conexión, demasiados
  /// pedidos seguidos), lanza, y la pantalla lo dice. [TooSoon] si es que se
  /// pidió otro hace un momento.
  Future<void> sendCode(String email);

  /// Si [code] es el que se mandó a [email]. Falso si no lo es; lanza si no
  /// se pudo preguntar.
  Future<bool> verify(String email, String code);
}

/// Se pidió un código hace muy poco: la nube no manda otro hasta dentro de un
/// rato, y el que llegó antes sigue sirviendo.
class TooSoon implements Exception {
  const TooSoon();
}

/// La nube contestó, y contestó que no. Lleva su motivo tal como vino, para
/// decirlo en pantalla: «revisá la conexión» cuando la conexión anda manda a
/// buscar el problema donde no está.
class AccountRefused implements Exception {
  const AccountRefused(this.reason);

  final String reason;
}
