/// Quién es la persona, para saber de quién es cada valle en la nube.
///
/// Se entra con un código que llega por correo: sin contraseña que recordar,
/// y sin nada que configurar fuera de Supabase. Más adelante se suma Google,
/// como otra manera de entrar a la misma cuenta.
library;

abstract interface class Account {
  /// Manda el código a [email]. Si no se pudo (sin conexión, demasiados
  /// pedidos seguidos), lanza, y la pantalla lo dice.
  Future<void> sendCode(String email);

  /// Si [code] es el que se mandó a [email]. Falso si no lo es; lanza si no
  /// se pudo preguntar.
  Future<bool> verify(String email, String code);
}

/// La pantalla sin la nube detrás, para verla mientras no esté conectada.
///
/// No manda ningún correo: cualquier código de seis números entra. Se va en
/// cuanto exista la cuenta de Supabase.
class PreviewAccount implements Account {
  const PreviewAccount();

  @override
  Future<void> sendCode(String email) =>
      Future.delayed(const Duration(milliseconds: 700));

  @override
  Future<bool> verify(String email, String code) => Future.delayed(
    const Duration(milliseconds: 500),
    () => RegExp(r'^\d{6}$').hasMatch(code),
  );
}
