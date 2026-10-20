/// La nube de verdad: Supabase detrás de [Account] y de [Remote].
///
/// La dirección del proyecto y su clave pública llegan al compilar
/// (`--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`, que el
/// flujo saca de los secretos del repositorio) y nunca están escritas acá.
/// Sin ellas —en local, en los tests— no hay nube: la app no pide cuenta y
/// todo vive en el teléfono, como siempre.
///
/// La clave es la pública a propósito. Lo que impide que alguien lea el valle
/// de otro no es esconderla sino las políticas de cada tabla
/// (`supabase/migrations/`): cada fila es de quien entró con su código.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/store.dart';
import 'account.dart';
import 'remote.dart';
import 'tables.dart';

/// Entrar con el código que llega por correo.
class SupabaseAccount implements Account {
  SupabaseAccount(this._auth);

  final GoTrueClient _auth;

  @override
  Future<void> sendCode(String email) async {
    try {
      await _auth.signInWithOtp(email: email, shouldCreateUser: true);
    } on AuthRetryableFetchException {
      rethrow;
    } on AuthException catch (e) {
      if (e.statusCode == '429' || e.code == 'over_email_send_rate_limit') {
        throw const TooSoon();
      }
      rethrow;
    }
  }

  @override
  Future<bool> verify(String email, String code) async {
    try {
      final r = await _auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      return r.session != null;
    } on AuthRetryableFetchException {
      // Sin conexión: no es que el código esté mal.
      rethrow;
    } on AuthException {
      // Equivocado o vencido: para quien lo escribe es lo mismo.
      return false;
    }
  }
}

/// Las tablas del valle, en Supabase.
class SupabaseRemote implements Remote {
  SupabaseRemote(this._db);

  final SupabaseClient _db;

  /// Supabase no devuelve más de mil filas por pedido, y un pueblo de un año
  /// tiene más piezas que eso: se piden de a mil, en orden de clave.
  static const int _page = 1000;

  /// Y se escriben de a quinientas: la primera subida de un valle grande es
  /// todo de una vez.
  static const int _chunk = 500;

  @override
  Future<ValleyRows?> pull(String userId) async {
    final tablas = <String, List<Row>>{};
    for (final t in Tables.all) {
      final filas = <Row>[];
      final clave = primaryKeys[t]!;
      while (true) {
        var q = _db.from(t).select().eq('user_id', userId).order(clave.first);
        for (final c in clave.skip(1)) {
          q = q.order(c);
        }
        final pagina = await q.range(filas.length, filas.length + _page - 1);
        filas.addAll([for (final f in pagina) Map<String, Object?>.from(f)]);
        if (pagina.length < _page) break;
      }
      tablas[t] = filas;
    }
    // Sin la fila del valle es que nunca subió nada.
    if (tablas[Tables.valleys]!.isEmpty) return null;
    return ValleyRows(tablas);
  }

  @override
  Future<void> apply(String userId, RowChanges changes) async {
    for (final t in Tables.all) {
      final filas = changes.upserts[t] ?? const <Row>[];
      for (var i = 0; i < filas.length; i += _chunk) {
        await _db
            .from(t)
            .upsert(
              filas.sublist(i, (i + _chunk).clamp(0, filas.length)),
              onConflict: primaryKeys[t]!.join(','),
            );
      }
    }
    for (final t in Tables.all.reversed) {
      for (final clave in changes.deletes[t] ?? const <Row>[]) {
        var q = _db.from(t).delete();
        for (final e in clave.entries) {
          q = q.eq(e.key, e.value!);
        }
        await q;
      }
    }
  }
}

/// La cuenta y la sincronización, para toda la app.
///
/// Avisa cuando cambia algo que se ve: que se entró, que se salió, que se
/// pudo o no se pudo hablar con la nube, y que bajó un valle.
class Cloud extends ChangeNotifier {
  Cloud._();

  static final Cloud instance = Cloud._();

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _key = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Si esta build sabe dónde está la nube.
  static bool get configured => _url.isNotEmpty && _key.isNotEmpty;

  bool _ready = false;
  CloudSync? _sync;

  /// La última vez que se intentó, no se pudo hablar con la nube. Lo hecho
  /// queda guardado en el teléfono y sube en cuanto se pueda.
  bool get offline => _offline;
  bool _offline = false;

  Future<void> init() async {
    if (!configured || _ready) return;
    try {
      await Supabase.initialize(url: _url, publishableKey: _key);
      _ready = true;
    } catch (e) {
      debugPrint('nube: no arrancó: $e');
    }
  }

  /// Con qué se entra, o null si no hay nube.
  Account? get account =>
      _ready ? SupabaseAccount(Supabase.instance.client.auth) : null;

  User? get _user => _ready ? Supabase.instance.client.auth.currentUser : null;

  bool get signedIn => _user != null;

  String? get email => _user?.email;

  /// Pone de acuerdo el teléfono y la nube, y desde ahí sube cada cambio.
  /// Sin cuenta no hace nada; sin conexión lo deja para la próxima.
  Future<void> start(Store store) async {
    final user = _user;
    if (user == null) return;
    _sync?.stop();
    final sync = CloudSync(
      store,
      SupabaseRemote(Supabase.instance.client),
      user.id,
    );
    _sync = sync;
    try {
      await sync.connect();
      _offline = false;
    } catch (e) {
      debugPrint('nube: $e');
      _offline = true;
    }
    notifyListeners();
  }

  /// Al volver a la app: si la última vez no hubo conexión, otra vez; si no,
  /// lo que haya quedado pendiente.
  Future<void> resume(Store store) async {
    if (!signedIn) return;
    if (_offline || _sync == null) {
      await start(store);
    } else {
      await _sync!.pushNow();
    }
  }

  /// Salir de la cuenta. El valle se queda en el teléfono.
  Future<void> signOut() async {
    _sync?.stop();
    _sync = null;
    _offline = false;
    if (_ready) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        debugPrint('nube: $e');
      }
    }
    notifyListeners();
  }
}
