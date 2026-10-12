import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/rng.dart';
import '../data/character.dart';
import '../data/doings.dart';
import '../data/folknames.dart';
import 'folk_body.dart';
import 'solids.dart';
import 'streets.dart';
import 'town.dart';

/// La gente que vive en el pueblo.
///
/// Una casa terminada es una casa donde vive alguien, y hasta ahora no vivía
/// nadie: el pueblo era un sitio precioso y vacío. Cada casa corriente que se
/// remata pone una persona en la calle, y al hacerlo convierte la cuenta de
/// piezas en una cuenta de vecinos — que es la misma cuenta dicha de la manera
/// en que la gente se acuerda de las cosas.
///
/// **No son piezas y no se ganan.** Son consecuencia de lo ganado, como la
/// huerta o el roble de la parcela: nadie paga un logro por un vecino, el
/// vecino aparece porque su casa está en pie. La regla de una pieza un logro
/// no se toca por ningún lado.
///
/// **Y no se guardan.** Dónde está cada uno es una función pura del reloj y de
/// su semilla, igual que las bandadas de pájaros o el sol. No hay simulación
/// que adelantar al volver a abrir la app, no hay nada que se desincronice, no
/// hay nada que se corrompa, y dos vistas del mismo pueblo en el mismo momento
/// enseñan a la misma gente en el mismo sitio. Lo único que se paga por eso es
/// que al cerrar y abrir vuelven a empezar su ronda, que no lo nota nadie.
class Townsfolk {
  Townsfolk._(
    this.home,
    this.seed,
    this.name,
    this.born,
    this._stops,
    this._stay,
    this._facing,
    this._act,
    this.period,
  );

  /// Una persona quieta en el origen, haciendo una cosa y nada más.
  ///
  /// Para el expositor de actividades. Noventa y cuatro cosas escritas en una
  /// tabla no se revisan leyendo la tabla: se revisan mirándolas una a una, de
  /// cerca y dando la vuelta alrededor. Y lo que no se entiende mirándolo así
  /// tampoco se va a entender a doce píxeles en medio de un pueblo, que es
  /// exactamente lo que hay que poder decidir.
  ///
  /// La ronda es un solo sitio con una parada larguísima, así que [at] siempre
  /// devuelve lo mismo salvo el reloj del gesto.
  factory Townsfolk.showcase(Doing doing, {int seed = 7, bool kid = false}) {
    // La semilla manda sobre si es crío, y el expositor quiere poder enseñar
    // las dos cosas: se busca una que dé la edad pedida en vez de forzarla,
    // que sería una regla más que mantener.
    var s = seed;
    for (var k = 0; k < 4096; k++) {
      if ((hash01(s, 12) < 0.24) == kid) break;
      s = hash32(s, 0x5EED, k);
    }
    return Townsfolk._(
      -1,
      s,
      folkName(s),
      null,
      const [(0.0, 0.0)],
      const [1e6],
      const [0.0],
      [doing],
      1e6,
    );
  }

  /// El edificio en el que vive, que es el que lo puso en el mundo.
  ///
  /// Vale `-1` para el de muestra, que no vive en ninguno.
  final int home;

  /// De donde sale todo lo suyo: la cara, el paño, la talla, la ronda y a qué
  /// dedica la tarde. Viene del padrón cuando lo hay, y del plano cuando no.
  final int seed;

  /// Cómo se llama.
  final String name;

  /// El día que se remató su casa, que es el día que nació. Nulo en el
  /// expositor y en los tests, que no tienen un hábito detrás.
  final DateTime? born;

  /// Lo que tarda en salir por su puerta un vecino que acaba de nacer.
  ///
  /// La casa se remata, la última pieza cae, y hasta ahora el vecino estaba en
  /// la calle **antes de que la pieza tocara el suelo**: la casa cuenta como
  /// terminada en cuanto la pieza entra en la cuenta, y la cuenta sube al
  /// soltarla, no al posarla. Lo que se veía era una persona apareciendo de la
  /// nada en medio del pueblo mientras el tejado todavía estaba en el aire.
  ///
  /// Tres segundos desde que la pieza se posa, que es justo después del
  /// confeti: primero se ve terminarse la casa, y entonces sale quien vive en
  /// ella.
  static const double settleIn = 3.0;

  /// En qué segundo del reloj de la escena salió por su puerta por primera
  /// vez. Nulo para quien ya vivía aquí cuando se abrió la app.
  ///
  /// Hace dos cosas, y la segunda es la que importa. Mientras no llega, no se
  /// le dibuja. Y a partir de ahí **su ronda cuenta desde aquí**, así que el
  /// segundo en que aparece está en su propia puerta y lo primero que hace es
  /// salir de ella — en vez de materializarse a medio camino de la plaza, que
  /// es donde le pillaba el reloj común.
  double? debut;

  /// Lo que hace en cada parada de su ronda. Nulo en los quiebros del camino,
  /// que no son sitios a los que se va.
  final List<Doing?> _act;

  /// Si es un crío. Más chico, y es el que sale al prado a soltar la cometa o
  /// a correr detrás de una mariposa — que es lo que hace un crío en un pueblo
  /// donde no hay nada más que hacer.
  bool get kid => hash01(seed, 12) < 0.24;

  /// Lo que mide, contra lo que mide una persona hecha.
  double get build => buildOf(seed);

  /// Lo que mide quien sale de la semilla [seed]. Ver [build].
  static double buildOf(int seed) => hash01(seed, 12) < 0.24
      ? 0.66 + hash01(seed, 13) * 0.10
      : 0.94 + hash01(seed, 14) * 0.15;

  /// Lo que mide de verdad en el valle: su talla por la de su región. Cero en
  /// el expositor, que no tiene región ni nada contra lo que chocar.
  double _h = 0;

  /// Por dónde pasa: su puerta, sus recados, y los quiebros que da para
  /// rodear las casas que le quedan en medio.
  final List<(double x, double z)> _stops;

  /// Lo que se queda parado al llegar a cada punto. Cero en los quiebros, que
  /// no son sitios a los que se va sino esquinas que se doblan.
  final List<double> _stay;

  /// Hacia dónde mira en cada parada mientras espera.
  final List<double> _facing;

  /// Lo que tarda en dar la ronda entera, en segundos.
  final double period;

  /// Dónde tiene la puerta. Es donde aparece al amanecer y donde se mete al
  /// anochecer.
  (double x, double z) get door => _stops.first;

  /// Por dónde se mueve, en redondo: el centro de su ronda y hasta dónde se
  /// aleja de él.
  ///
  /// Nunca sale de ese círculo, porque está siempre en un tramo entre dos
  /// paradas y el círculo contiene a todas. Sirve para lo que no se puede
  /// hacer sin él: **decidir que a alguien no se le va a ver sin calcular
  /// antes dónde está.**
  ///
  /// Averiguar dónde anda uno cuesta recorrerle la ronda, y hasta que existió
  /// esto se le hacía a todo el mundo en cada fotograma para descartar después
  /// al que caía fuera de la pantalla. En un valle de seis pueblos eso era
  /// simular quinientos cincuenta vecinos para dibujar cincuenta y dos: los
  /// otros cinco pueblos están al otro lado del valle y su gente no se ve, ni
  /// va a verse, y se les calculaba el paseo entero sesenta veces por segundo.
  ///
  /// Se calcula la primera vez que se pregunta y no cambia nunca: la ronda se
  /// decide el día que se funda y no se vuelve a tocar.
  late final ({double x, double z, double r}) roam = _roam();

  /// Por dónde puede andar **ahora**: su ronda, y si está en una prueba
  /// ([tryOut]), también el camino de la prueba. Es lo que mira el pintor
  /// para decidir que no se le ve; con sólo [roam], quien va a pescar al otro
  /// lado del pueblo desaparecía en cuanto salía de su paseo de siempre.
  ({double x, double z, double r}) get reach {
    final p = _trial;
    final h = _homing;
    if (p == null && h == null) return roam;
    var x0 = roam.x - roam.r, x1 = roam.x + roam.r;
    var z0 = roam.z - roam.r, z1 = roam.z + roam.r;
    for (final q in [...?p?.ida, ...?p?.vuelta, ...?h?.path]) {
      x0 = math.min(x0, q.$1 - 1.2);
      x1 = math.max(x1, q.$1 + 1.2);
      z0 = math.min(z0, q.$2 - 1.2);
      z1 = math.max(z1, q.$2 + 1.2);
    }
    final cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
    return (
      x: cx,
      z: cz,
      r: math.sqrt(math.pow(x1 - cx, 2) + math.pow(z1 - cz, 2)),
    );
  }

  ({double x, double z, double r}) _roam() {
    var x0 = _stops.first.$1, x1 = x0;
    var z0 = _stops.first.$2, z1 = z0;
    for (final s in _stops) {
      if (s.$1 < x0) x0 = s.$1;
      if (s.$1 > x1) x1 = s.$1;
      if (s.$2 < z0) z0 = s.$2;
      if (s.$2 > z1) z1 = s.$2;
    }
    final cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
    var r = 0.0;
    for (final s in _stops) {
      final dx = s.$1 - cx, dz = s.$2 - cz;
      final d = dx * dx + dz * dz;
      if (d > r) r = d;
    }
    // Y un poco de aire: lo que se dibuja no es un punto, es alguien de metro
    // y pico de ancho con una escoba en la mano.
    return (x: cx, z: cz, r: math.sqrt(r) + 1.2);
  }

  /// La ronda, vértice a vértice. Para poder medirla en un test: mirando sólo
  /// lo que devuelve [at] no se distingue un vértice metido en una pared de un
  /// tramo largo que corta una esquina, y son dos fallos con dos arreglos
  /// distintos.
  @visibleForTesting
  List<(double x, double z)> get debugPath => _stops;

  /// En qué anda cuando está parado. Para poder exigir en un test que un crío
  /// no se ponga a martillear un puente y que nadie suelte una cometa dentro
  /// de la plaza.
  @visibleForTesting
  List<Doing?> get debugActs => _act;

  // ------------------------------------------------------------ protagonista

  /// Si la cámara la está siguiendo. Ver [spotlight].
  bool get spotlit => _spot != null;

  /// Cuánto se corre su reloj: el de siempre ([_shift]) y el de cuando la
  /// sigue la cámara ([_spot], nulo si no la sigue). Existen para que
  /// cambiar de una manera de andar a la otra no la haga saltar de sitio.
  double _shift = 0;
  double? _spot;

  /// Cuando la cámara la sigue, se queda menos en cada sitio y hace más
  /// cosas. Ver [spotlight].
  ///
  /// Donde sólo cabe una cosa —un crío en la plaza sólo puede tocar el laúd—
  /// la parada es la mitad: hacer lo mismo dieciséis segundos es estar quieto.
  late final List<double> _spotStay = [
    for (var i = 0; i < _stay.length; i++)
      _act[i] == null
          ? 0.0
          : (_spotChoices(i).length > 1 ? _spotStop : _spotEach),
  ];

  /// Lo que puede hacer en la parada [i] cuando la sigue la cámara: lo de
  /// siempre primero, y después todo lo demás que tiene sentido ahí.
  ///
  /// Sólo las que **caben** ahí: mirando a donde mira en esa parada, nada de
  /// lo que lleva puede meterse en una pared. Ver [_fitsAt].
  List<Doing> _spotChoices(int i) => _spotMemo[i] ??= _spotChoicesOf(i);

  final Map<int, List<Doing>> _spotMemo = {};

  List<Doing> _spotChoicesOf(int i) {
    final suya = _act[i] ?? Doing.idle;
    return [
      suya,
      for (final d in Doing.all)
        if (d.where == suya.where &&
            d.fits(kid) &&
            d.id != suya.id &&
            _fitsAt(_calles, _h, d, kid, _stops[i], _facing[i]))
          d,
    ];
  }

  late final double _spotPeriod = _periodWith(_spotStay);

  double _periodWith(List<double> stays) {
    var p = 0.0;
    final n = _stops.length;
    for (var i = 0; i < n; i++) {
      final a = _stops[i], b = _stops[(i + 1) % n];
      p +=
          math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2)) / pace;
      p += stays[(i + 1) % n];
    }
    return math.max(p, 1);
  }

  /// En qué segundo de su ronda va, con el reloj de la escena en [t].
  double _uAt(double t) {
    final spot = _spot;
    if (spot != null) return (t + spot) % _spotPeriod;
    // Quien ya vivía aquí arranca en un punto cualquiera de su ronda —es lo
    // que hace que no salgan todos a la vez— y quien acaba de nacer arranca en
    // su puerta, que es por donde se sale de casa la primera vez. Ver [debut].
    final nace = debut;
    return nace == null
        ? (t + hash01(seed, 7) * period + _shift) % period
        : (t - nace + _shift) % period;
  }

  /// Por dónde de la ronda va en el segundo [u] de una ronda con [stays]:
  /// en qué tramo, si andando o parado, y cuánto lleva de eso.
  (int, bool, double) _where(double u, List<double> stays) {
    var acc = 0.0;
    final n = _stops.length;
    for (var i = 0; i < n; i++) {
      final a = _stops[i], b = _stops[(i + 1) % n];
      final walk =
          math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2)) / pace;
      if (u < acc + walk) return (i, true, walk <= 0 ? 1 : (u - acc) / walk);
      acc += walk;
      final stay = stays[(i + 1) % n];
      if (u < acc + stay) return (i, false, u - acc);
      acc += stay;
    }
    return (0, true, 0);
  }

  /// Lo contrario: en qué segundo de una ronda con [stays] se está en ese
  /// punto.
  double _uOf(int i, bool walking, double k, List<double> stays) {
    var acc = 0.0;
    final n = _stops.length;
    for (var j = 0; j < n; j++) {
      final a = _stops[j], b = _stops[(j + 1) % n];
      final walk =
          math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2)) / pace;
      if (j == i && walking) return acc + walk * k;
      acc += walk;
      if (j == i) {
        final stay = stays[(j + 1) % n];
        return acc + math.min(k, math.max(0.0, stay - 0.01));
      }
      acc += stays[(j + 1) % n];
    }
    return 0;
  }

  /// Que la cámara la siga, o que deje de seguirla, en el segundo [t].
  ///
  /// Una persona en su ronda de siempre se queda de medio minuto a un minuto
  /// en cada sitio haciendo una sola cosa. Visto de lejos, entre cuarenta, es
  /// un pueblo tranquilo; con la cámara encima de ella es mirar a alguien
  /// quieto. Así que cuando la siguen se queda menos en cada sitio, nunca pasa
  /// de largo por su puerta, y en cada parada hace varias cosas de las que
  /// tienen sentido ahí — se tumba en el prado, después lee, después siega.
  ///
  /// **Sin saltar de sitio.** Cambia el horario y no el camino: se busca en
  /// qué punto del camino va ahora y la ronda nueva sigue desde ese mismo
  /// punto. Lo mismo al dejar de seguirla.
  void spotlight(double t, {required bool on}) {
    if (on == spotlit) return;
    final antes = on ? _stay : _spotStay;
    final despues = on ? _spotStay : _stay;
    final (i, walking, k) = _where(_uAt(t), antes);
    final target = _uOf(i, walking, k, despues);
    if (on) {
      _spot = target - t;
    } else {
      _spot = null;
      final nace = debut;
      final base = nace == null ? t + hash01(seed, 7) * period : t - nace;
      _shift = target - base;
    }
  }

  /// Qué hace la persona seguida en la parada [i], a los [held] segundos de
  /// haberse puesto: va cambiando cada [_spotEach] segundos entre las cosas
  /// que tienen sentido en ese sitio, empezando por la de siempre.
  Doing _spotAct(int i, double held) {
    final puede = _spotChoices(i);
    final k = (held / _spotEach).floor();
    // Entre una cosa y la siguiente, un respiro: guardar la escoba y sacar
    // el libro no pasa entre dos fotogramas.
    if (k > 0 && held - k * _spotEach < 1.2) return Doing.idle;
    return puede[k % puede.length];
  }

  // ------------------------------------------------------------ a casa

  /// Las calles del pueblo, para volver a casa rodeando lo construido. Nulo
  /// en el expositor, que no tiene pueblo.
  Streets? _calles;

  /// Si ya se le vio alguna vez. Quien se ve por primera vez de noche ya
  /// estaba en casa: no se le hace volver de ningún sitio.
  bool _seen = false;

  /// Si está dentro de su casa.
  bool _inside = false;

  /// La vuelta a casa de esta tarde, si va de camino: desde cuándo y por
  /// dónde.
  ({double t0, List<(double, double)> path})? _homing;

  /// Cuándo salió de casa por la mañana, para verle salir por la puerta.
  double? _outAt;

  /// Lo que tarda en meterse por la puerta, o en salir de ella.
  static const double _doorway = 0.8;

  /// A qué altura de la tarde se va a casa: cada uno a la suya, para que se
  /// vea a todo el pueblo yéndose poco a poco y no a la vez.
  double get _bedtime => 0.06 + hash01(seed, 71) * 0.62;

  /// Dónde está en el segundo [t] con la tarde en [homeward]. Ver
  /// [folkWhere].
  ({FolkAt at, double sink})? _evening(double t, double homeward) {
    final first = !_seen;
    _seen = true;
    if (homeward >= _bedtime) {
      if (_inside) return null;
      // Si al abrir la app ya era su hora, o es noche cerrada, ya está en
      // casa: no tiene sentido verlo volver de donde estuviera.
      if (first || homeward >= 0.999) {
        _inside = true;
        _homing = null;
        return null;
      }
      var h = _homing;
      if (h == null) {
        final now = at(t);
        _trial = null;
        final from = (now.x, now.z);
        h = _homing = (
          t0: t,
          path: [from, ...?_calles?.route(from, door), door],
        );
      }
      final s = t - h.t0;
      final walk = _lengthOf(h.path) / pace;
      if (s < walk) return (at: _walkAlong(h.path, s, seed), sink: 0.0);
      final into = (s - walk) / _doorway;
      if (into >= 1) {
        _inside = true;
        _homing = null;
        return null;
      }
      return (
        at: FolkAt(door.$1, door.$2, _facing.first, 0, false),
        sink: into,
      );
    }
    if (_inside || _homing != null) {
      // Se hizo de día: sale de casa, y su ronda empieza en la puerta.
      final estaba = _inside;
      _inside = false;
      _homing = null;
      _resumeAtDoor(t);
      if (estaba) _outAt = t;
    }
    final out = _outAt;
    var sink = 0.0;
    if (out != null) {
      final k = (t - out) / _doorway;
      if (k >= 1 || k < 0) {
        _outAt = null;
      } else {
        sink = 1 - k;
      }
    }
    return (at: at(t), sink: sink);
  }

  // ---------------------------------------------------------------- prueba

  /// Una actividad que se le pidió desde fuera, para revisarla en el pueblo
  /// de verdad y no en el expositor. Ver [tryOut].
  _Trial? _trial;

  /// Lo que está probando, si está en una prueba.
  Doing? get trying => _trial?.doing;

  /// Que haga [doing] ahora, empezando en el segundo [t] del reloj.
  ///
  /// Va andando desde donde esté hasta [site] —por las calles, rodeando las
  /// casas como en su ronda—, se queda ahí haciéndolo [hold] segundos mirando
  /// hacia [facing], y vuelve a su puerta, desde donde sigue con su vida como
  /// si acabara de salir de casa. Sin saltos: cada tramo empieza donde acabó
  /// el anterior.
  ///
  /// Si [site] es nulo lo hace donde está, que es lo que pasa cuando en el
  /// pueblo no hay un sitio de esa clase — un pueblo sin agua no tiene dónde
  /// echar un barco de papel, y la prueba lo trae a sus pies y se lo lleva al
  /// terminar.
  void tryOut(
    Doing doing,
    double t, {
    required List<(double, double)> ida,
    required double facing,
    required List<(double, double)> vuelta,
    double hold = _trialHold,
  }) {
    _trial = _Trial(doing, t, ida, facing, hold, vuelta);
  }

  /// Le corre el reloj para que en el segundo [t] esté saliendo de su puerta,
  /// que es donde lo deja una prueba al terminar.
  void _resumeAtDoor(double t) {
    if (_spot != null) {
      _spot = _spotPeriod - (t % _spotPeriod);
    } else {
      final nace = debut;
      final base = nace == null ? t + hash01(seed, 7) * period : t - nace;
      _shift = -base;
    }
  }

  /// Lo que anda una persona en un segundo.
  ///
  /// Medido contra la puerta de una casa, que mide dos tercios de unidad: a
  /// este paso cruza un pueblo de veinte de radio en menos de un minuto, que
  /// es lo que dura una mirada a la app. Más despacio y parecen estatuas; más
  /// rápido y parecen hormigas con prisa.
  static const double pace = 0.78;

  /// Cuánto mide una zancada, para que el paso no vaya por su cuenta.
  ///
  /// El balanceo se cuenta por metros andados y no por segundos: contándolo
  /// por segundos, una persona que va más despacio patina.
  static const double stride = 0.42;

  /// Dónde está y hacia dónde mira en el segundo [t].
  ///
  /// [t] es el reloj de la escena, que corre mientras se mira el pueblo. La
  /// ronda da la vuelta sola, así que esto vale para cualquier [t] por grande
  /// que sea.
  /// Dónde está y hacia dónde mira en el segundo [t].
  ///
  /// [t] es el reloj de la escena, que corre mientras se mira el pueblo. La
  /// ronda da la vuelta sola, así que esto vale para cualquier [t] por grande
  /// que sea.
  FolkAt at(double t) {
    final prueba = _trial;
    if (prueba != null) {
      final en = prueba.at(t, seed);
      if (en != null) return en;
      // Ya volvió a su puerta: sigue con su ronda desde ahí.
      _trial = null;
      _resumeAtDoor(prueba.end);
    }
    final spot = _spot != null;
    final stays = spot ? _spotStay : _stay;
    final u = _uAt(t);
    var acc = 0.0;
    var walked = hash01(seed, 8) * 40; // para que no pisen todos a la vez
    final n = _stops.length;
    for (var i = 0; i < n; i++) {
      final from = _stops[i], to = _stops[(i + 1) % n];
      final dx = to.$1 - from.$1, dz = to.$2 - from.$2;
      final d = math.sqrt(dx * dx + dz * dz);
      final walk = d / pace;
      if (u < acc + walk) {
        final k = walk <= 0 ? 1.0 : (u - acc) / walk;
        return FolkAt(
          from.$1 + dx * k,
          from.$2 + dz * k,
          math.atan2(dx, dz),
          (walked + d * k) / stride * 2 * math.pi,
          true,
          null,
          u - acc,
        );
      }
      acc += walk;
      walked += d;
      final stay = stays[(i + 1) % n];
      if (u < acc + stay) {
        // Parado: mirando a donde vino a mirar, con un balanceo lento que es
        // lo que separa a alguien esperando de un poste.
        final held = u - acc;
        // Al llegar no se empieza en el acto, y antes de irse ya se terminó.
        //
        // Sin esto, una persona pasaba de andar a estar barriendo entre dos
        // fotogramas, y de barrer a andar igual: la escoba aparecía y
        // desaparecía en la mano sin que nadie se hubiera parado a sacarla.
        // Con un respiro a cada lado, lo que se ve es llegar, quedarse, y
        // entonces ponerse — que además es lo que separa un gesto del
        // siguiente y hace que no se disparen uno detrás de otro.
        //
        // El de muestra no lo lleva: el expositor existe para mirar un gesto
        // concreto y empezarlo con dos segundos de nada sería empezarlo mal.
        // Y para quien sigue la cámara, la mitad: está ahí para verla hacer
        // cosas, no para verla llegar.
        final settle = home < 0 ? 0.0 : math.min(spot ? 1.2 : 2.4, stay * 0.15);
        final metido = held >= settle && held <= stay - settle;
        // Y en el respiro no se queda congelado: respira y mira alrededor, que
        // es [Doing.idle] y es exactamente lo que hace quien acaba de llegar.
        final what = !metido
            ? Doing.idle
            : spot
            ? _spotAct((i + 1) % n, held - settle)
            : _act[(i + 1) % n];
        final look = _facing[(i + 1) % n];
        // La cabeza se va yendo a mirar alrededor, y cuánto depende de en qué
        // ande: quien pica piedra no levanta la vista y quien no hace nada la
        // levanta todo el rato.
        final sway =
            math.sin(held * 0.7 + hash01(seed, 9) * 6) *
            0.18 *
            (what?.turn ?? 1.0);
        // La fase del gesto cuenta desde que se puso a ello y no desde que
        // llegó: si contara desde la llegada, el gesto empezaría por la mitad.
        return FolkAt(
          to.$1,
          to.$2,
          look + sway,
          0,
          false,
          what,
          metido ? held - settle : held,
        );
      }
      acc += stay;
    }
    final last = _stops.first;
    return FolkAt(last.$1, last.$2, _facing.first, 0, false, _act.first, 0);
  }
}

/// Lo que dura cada cosa que hace la persona a la que sigue la cámara, y lo
/// que se queda en cada parada.
const double _spotEach = 8.0, _spotStop = 16.0;

/// Lo que dura una prueba haciendo la cosa, sin contar ir y volver.
const double _trialHold = 24.0;

/// Una prueba: ir, hacer una cosa un rato, y volver a casa.
class _Trial {
  _Trial(this.doing, this.t0, this.ida, this.facing, this.hold, this.vuelta);

  final Doing doing;
  final double t0;
  final List<(double, double)> ida;
  final double facing;
  final double hold;
  final List<(double, double)> vuelta;

  /// El respiro de antes y de después, como en cualquier parada.
  static const double settle = 1.0;

  late final double _ida = _lengthOf(ida) / Townsfolk.pace;
  late final double _vuelta = _lengthOf(vuelta) / Townsfolk.pace;
  late final double _stay = hold + 2 * settle;

  /// Cuándo está otra vez en su puerta.
  double get end => t0 + _ida + _stay + _vuelta;

  /// Dónde está en el segundo [t], o nulo si la prueba ya terminó.
  FolkAt? at(double t, int seed) {
    var s = t - t0;
    if (s < 0) s = 0;
    if (s < _ida) return _walkAlong(ida, s, seed);
    s -= _ida;
    if (s < _stay) {
      final p = ida.last;
      final metido = s >= settle && s <= _stay - settle;
      final what = metido ? doing : Doing.idle;
      final sway = math.sin(s * 0.7 + hash01(seed, 9) * 6) * 0.18 * what.turn;
      return FolkAt(
        p.$1,
        p.$2,
        facing + sway,
        0,
        false,
        what,
        metido ? s - settle : s,
      );
    }
    s -= _stay;
    if (s < _vuelta) return _walkAlong(vuelta, s, seed);
    return null;
  }
}

/// Lo que mide un camino de punto a punto.
double _lengthOf(List<(double, double)> p) {
  var d = 0.0;
  for (var i = 0; i + 1 < p.length; i++) {
    d += math.sqrt(
      math.pow(p[i + 1].$1 - p[i].$1, 2) + math.pow(p[i + 1].$2 - p[i].$2, 2),
    );
  }
  return d;
}

/// Dónde va quien lleva [s] segundos andando por [p], al paso de siempre.
FolkAt _walkAlong(List<(double, double)> p, double s, int seed) {
  var left = s * Townsfolk.pace;
  var walked = hash01(seed, 8) * 40;
  for (var i = 0; i + 1 < p.length; i++) {
    final a = p[i], b = p[i + 1];
    final dx = b.$1 - a.$1, dz = b.$2 - a.$2;
    final d = math.sqrt(dx * dx + dz * dz);
    if (left <= d && d > 0) {
      final k = left / d;
      return FolkAt(
        a.$1 + dx * k,
        a.$2 + dz * k,
        math.atan2(dx, dz),
        (walked + left) / Townsfolk.stride * 2 * math.pi,
        true,
      );
    }
    left -= d;
    walked += d;
  }
  final last = p.last;
  return FolkAt(last.$1, last.$2, 0, 0, true);
}

/// Manda a [who], vecino de [layout], a hacer [doing] desde el segundo [t].
///
/// Busca el sitio de esa clase más cercano a donde está: su propia puerta si
/// es una cosa de casa, la plaza, el agua de un hito que la tenga, una obra o
/// el prado. Llega por las calles y se pone en el corro, mirando al medio,
/// como en su ronda. Si en el pueblo no hay ninguno, lo hace donde está.
///
/// Devuelve si encontró sitio, para poder decirlo.
bool folkTryOut(
  TownLayout layout,
  int placed,
  Townsfolk who,
  Doing doing,
  double t,
) {
  folkOf(layout, placed);
  final key =
      '${layout.cx},${layout.cz},${layout.character.order},'
      '${layout.seed},${layout.folk.length}';
  final cache = _folk[key];
  if (cache == null) return false;
  final calles = cache.calles;
  // Desde donde está ahora, sin la prueba de antes si la había.
  who._trial = null;
  final ahora = who.at(t);
  final desde = (ahora.x, ahora.z);
  (double, double)? sitio;
  var mira = ahora.heading;
  if (doing.where == Where.door) {
    sitio = who.door;
    mira = who._facing.first;
  } else {
    var mejor = double.infinity;
    for (final s in _sitesOf(layout, placed, cache.huella)) {
      if (s.$4 != doing.where) continue;
      // Del lado por el que llega, que es el que queda más a mano.
      final dx = desde.$1 - s.$1, dz = desde.$2 - s.$2;
      final d = math.sqrt(dx * dx + dz * dz);
      if (d >= mejor) continue;
      mejor = d;
      final a = d < 1e-6 ? 0.0 : math.atan2(dx, dz);
      sitio = calles.onStreets((
        s.$1 + math.sin(a) * s.$3,
        s.$2 + math.cos(a) * s.$3,
      ));
      mira = math.atan2(-math.sin(a), -math.cos(a));
    }
  }
  // Y que quepa: lo que lleva no puede meterse en nada. Si de cara al sitio
  // no cabe se gira, y si girándose tampoco, se aparta del sitio de a palmos
  // hasta que quepa. Ver [_fitsAt].
  var aqui = sitio ?? desde;
  final centro = doing.where == Where.door && who.home >= 0
      ? (layout.buildings[who.home].cx, layout.buildings[who.home].cz)
      : aqui;
  var (_, que, cara) = _fitting(calles, who._h, who.kid, aqui, mira, [
    doing,
  ], step: false);
  var dx = aqui.$1 - centro.$1, dz = aqui.$2 - centro.$2;
  final largo = math.sqrt(dx * dx + dz * dz);
  if (largo > 1e-6) {
    dx /= largo;
    dz /= largo;
    for (var k = 1; que != doing && k <= 10; k++) {
      final otro = calles.onStreets((
        aqui.$1 + dx * k * 0.25,
        aqui.$2 + dz * k * 0.25,
      ));
      final (_, q, c) = _fitting(calles, who._h, who.kid, otro, mira, [
        doing,
      ], step: false);
      if (q == doing) {
        aqui = otro;
        que = q;
        cara = c;
      }
    }
  }
  // Una prueba se hace siempre, aunque no quepa en ningún sitio: es para
  // mirarla. Pero eso sólo pasa en un pueblo sin un hueco libre.
  if (que == doing) mira = cara;
  final ida = [desde, ...calles.route(desde, aqui), aqui];
  final vuelta = [aqui, ...calles.route(aqui, who.door), who.door];
  who.tryOut(doing, t, ida: ida, facing: mira, vuelta: vuelta);
  return sitio != null;
}

/// Una persona en un instante: dónde está, hacia dónde mira, y por dónde va su
/// paso.
class FolkAt {
  const FolkAt(
    this.x,
    this.z,
    this.heading,
    this.gait,
    this.moving, [
    this.act,
    this.phase = 0,
  ]);
  final double x, z;

  /// Hacia dónde mira, en radianes, como el `yaw` de la cámara.
  final double heading;

  /// La fase del paso, en radianes. Cero cuando está quieto.
  final double gait;
  final bool moving;

  /// Qué está haciendo ahora mismo. Nulo quiere decir que va de camino.
  final Doing? act;

  /// Cuántos segundos lleva haciéndolo. Es lo que mueve el gesto: sin esto,
  /// alguien charlando es alguien con el brazo levantado y quieto, que es peor
  /// que no levantarlo.
  final double phase;
}

/// La gente de un pueblo, guardada de un fotograma para el siguiente.
///
/// Quién vive dónde y por dónde anda no cambia mientras no caiga una pieza,
/// pero calcularlo no es gratis: cada vecino rodea las casas que le quedan en
/// medio, y eso son unas cuantas miles de cuentas para un pueblo mediano.
/// Hacerlas sesenta veces por segundo para llegar al mismo resultado sería
/// tirar un cuarto del fotograma a la basura.
///
/// Se guarda con la misma llave que la mampostería: dónde está el pueblo y
/// cuántas piezas lleva.
final Map<
  String,
  ({
    int placed,
    int mundo,
    List<Townsfolk> gente,
    Streets calles,
    Map<int, (double, double, double, double)> huella,
  })
>
_folk = {};

/// Dónde está [who] a la hora [time] de la escena, con la tarde cayendo
/// [homeward] (ver `folkHome`): de cero, de día, a uno, todos en casa.
///
/// Es lo único que dice dónde está alguien, y lo preguntan dos: el pintor, y
/// la cámara que lo sigue cuando se le toca. Con la cuenta escrita dos veces,
/// la cámara acabaría mirando un metro al lado de la persona.
///
/// Devuelve también cuánto se ha metido ya por su puerta ([sink], de cero a
/// uno), o nulo si ya está dentro del todo.
///
/// **Y a casa se vuelve por la calle.** Antes cada uno iba en línea recta
/// desde donde estaba hasta su puerta, y en línea recta hay casas en medio:
/// al caer la tarde se veía a la gente atravesando paredes. Ahora cada uno se
/// va a su hora —no todos a la vez— por el mismo camino que haría de día,
/// rodeando lo construido, y se mete por su puerta al llegar. Ver
/// [Townsfolk._evening].
({FolkAt at, double sink})? folkWhere(
  Townsfolk who,
  double time,
  double homeward,
) => who._evening(time, homeward);

/// La gente que hay ahora mismo en [layout], y por dónde andan.
///
/// Sale del plano y de nada más, así que dos llamadas con el mismo pueblo dan
/// la misma gente en el mismo orden — que es lo que hace que su semilla les
/// valga y que no cambien de ropa entre fotogramas.
List<Townsfolk> folkOf(TownLayout layout, int placed) {
  // Y el padrón entra en la llave. Sólo su tamaño: un padrón no se corrige
  // nunca, sólo crece, así que si tiene los mismos renglones que antes dice lo
  // mismo que antes. Sin esto, el primer arranque después de escribirlo se
  // quedaba con la gente sin nombre que había calculado un momento antes.
  final key =
      '${layout.cx},${layout.cz},${layout.character.order},'
      '${layout.seed},${layout.folk.length}';
  final had = _folk[key];
  // El camino de todos los fotogramas: no ha caído nada, es la misma gente.
  if (had != null && had.placed == placed) return had.gente;

  // Y el de cuando sí ha caído una pieza. **Que haya caído una pieza no quiere
  // decir que nadie tenga que cambiar de camino.**
  //
  // Rehacer la ronda de un pueblo es carísimo: son un A* por recado y por
  // vecino, y medido sobre pueblos de verdad son setenta y tres milisegundos
  // con seiscientas piezas y **doscientos ochenta con mil quinientas**. Eso es
  // un cuarto de segundo de app congelada justo al poner una pieza, que es la
  // única cosa que esta app hace, y creciendo cuanto más la usás — que es
  // exactamente al revés de como tiene que crecer nada.
  //
  // Lo que decide un camino no es cuántas piezas hay: es qué casillas del
  // suelo están tapadas. Y la mayoría de las piezas suben un piso a una casa
  // que ya estaba ocupando ese trozo de suelo, así que no tapan ninguna
  // casilla nueva. Medido sobre las últimas cien piezas de cuatro pueblos:
  // **entre veinte y veintiocho de cada cien** cambian la rejilla. Las otras
  // ochenta se estaban pagando enteras.
  //
  // Así que antes de rehacer nada se levanta la rejilla —cuatro milisegundos
  // con seiscientas piezas, siete con mil quinientas— y se compara con la de
  // antes. Si es la misma, y viven los mismos, la gente de antes vale tal cual.
  final estorbos = _blockers(layout, placed);
  final calles = Streets.of(layout.cx, layout.cz, layout.radius, estorbos);
  final huella = _footprints(layout, placed);
  var mundo = calles.fingerprint;
  for (final e in huella.entries) {
    mundo = ((mundo ^ e.key) * 0x01000193) & 0x3fffffff;
  }
  // Y **quién ha terminado su casa**, que es de donde salen los vecinos.
  //
  // Esto no estaba y era un fallo de los silenciosos: un vecino nace el día
  // que se remata su casa, y lo que remata una casa es normalmente el tejado
  // —que va encima de lo que ya estaba ocupando ese suelo y no tapa ninguna
  // casilla nueva—. Sin esta línea, la rejilla salía idéntica, la caché daba
  // por buena la gente de antes, y el vecino que acababa de nacer no aparecía
  // hasta la siguiente pieza que moviera un obstáculo. Lo caza un test.
  for (var i = 0; i < layout.buildings.length; i++) {
    final b = layout.buildings[i];
    if (b.firstPiece + b.cost > placed) continue;
    mundo = ((mundo ^ (i * 2654435761)) * 0x01000193) & 0x3fffffff;
  }
  if (!const bool.fromEnvironment('NOCACHE') &&
      had != null &&
      had.mundo == mundo) {
    _folk[key] = (
      placed: placed,
      mundo: mundo,
      gente: had.gente,
      calles: calles,
      huella: huella,
    );
    return had.gente;
  }

  final made = _folkOf(layout, placed, calles, huella);
  if (_folk.length > 24) _folk.clear();
  _folk[key] = (
    placed: placed,
    mundo: mundo,
    gente: made,
    calles: calles,
    huella: huella,
  );
  return made;
}

List<Townsfolk> _folkOf(
  TownLayout layout,
  int placed,
  Streets calles,
  Map<int, (double x0, double z0, double x1, double z1)> huella,
) {
  final casas = <TownBuilding>[];
  for (final b in layout.buildings) {
    if (b.isLandmark) continue;
    if (b.firstPiece + b.cost > placed) continue;
    casas.add(b);
  }
  if (casas.isEmpty) return const [];

  // A dónde va la gente. Pocos sitios y compartidos, que es lo que hace que se
  // encuentren: con un destino para cada uno, un pueblo de cuarenta vecinos
  // son cuarenta personas solas andando en paralelo. La plaza y los hitos son
  // de todos, así que a media tarde hay tres en el pozo, y eso no hubo que
  // programarlo.
  //
  // Y se ponen **fuera** de lo construido, no a una distancia inventada: el
  // sitio que se guarda una parcela no es lo que ocupa el edificio, y un
  // castillo ocupa mucho más que un pozo. Con una distancia fija, los vecinos
  // que iban al castillo se plantaban dentro de la muralla.
  //
  // Cada sitio dice además qué clase de sitio es, porque de eso depende lo que
  // se hace al llegar: en la plaza se charla, en una obra se arrima el hombro,
  // y en el prado se suelta la cometa. Un crío soltando una cometa en medio de
  // la plaza es lo que pasa cuando esto no se distingue.
  final sitios = _sitesOf(layout, placed, huella);

  // Lo que diga el padrón manda. Un vecino apuntado conserva su semilla —y con
  // ella su cara, su ropa y su talla— y su nombre, pase lo que pase con el
  // plano o con la lista de nombres.
  final padron = _censusOf(layout.folk);

  final out = <Townsfolk>[];
  for (final b in casas) {
    final apuntado = padron[b.index];
    final seed = apuntado?.$1 ?? folkSeedOf(layout.seed, b.seed, b.index);
    // La puerta, del lado por el que se sale al pueblo, y justo fuera de su
    // propia pared: si cae dentro, el vecino empieza el día dentro de su casa
    // y sale de ella atravesándola.
    final dx = layout.cx - b.cx, dz = layout.cz - b.cz;
    final d = math.sqrt(dx * dx + dz * dz);
    final c = huella[b.index];
    final fuera = (c == null ? b.reach * 0.7 : _spanOf(c)) + 0.30;
    final paso = d < 0.001 ? 1.0 : fuera / d;
    final door = calles.onStreets((b.cx + dx * paso, b.cz + dz * paso));

    // Tres recados y a casa. Tres y no más porque una ronda más larga es una
    // ronda que no se ve entera de una sentada.
    final crio = hash01(seed, 12) < 0.24;
    // Su propia puerta es el único sitio de la ronda que es suyo, y por eso es
    // donde pasan las cosas de casa: tomar el sol, hilar, partir leña. Casi la
    // mitad se queda un rato; los demás pasan de largo, que también es verdad.
    final stops = <(double, double)>[door];
    final encasa = hash01(seed, 61) < 0.45;
    final dwell = <double>[encasa ? hashRange(34.0, 74.0, seed, 62) : 0.0];
    final doing = <Doing>[_actAt(Where.door, seed, 9, crio)];
    // En su puerta mira **hacia fuera**, a la calle, de espaldas a su casa.
    // Miraba a la puerta, y todo lo que se hace en casa se hace con algo
    // delante —el tocón, las gallinas, el taburete—, así que se le metía en
    // la pared.
    final look = <double>[math.atan2(dx, dz)];
    for (var k = 0; k < 3; k++) {
      final s = sitios[hashInt(sitios.length, seed, 20 + k)];
      // Alrededor del sitio y no encima: se ponen en corro mirando al medio,
      // que es lo que hace la gente delante de un tablón o de una fuente.
      // En ocho sitios alrededor y no en cualquiera: con el ángulo libre, dos
      // que van al mismo pozo casi nunca quedan de cara, y con ocho puestos
      // coinciden a menudo. El corro se forma solo.
      final a = hashInt(8, seed, 30 + k) * math.pi / 4;
      stops.add(
        calles.onStreets((
          s.$1 + math.sin(a) * s.$3,
          s.$2 + math.cos(a) * s.$3,
        )),
      );
      look.add(math.atan2(-math.sin(a), -math.cos(a)));
      // Las paradas son más largas ahora que en ellas pasa algo: charlar seis
      // segundos y marcharse no es charlar, es saludar de lejos.
      //
      // Y más largas todavía desde que se vio el pueblo lleno: con paradas de
      // nueve a veintiséis segundos, un vecino empieza un gesto nuevo cada
      // medio minuto, y cuarenta vecinos haciendo eso a la vez es un pueblo
      // que parpadea. Lo que se quiere mirar es gente **estando** en un sitio,
      // no gente cambiando de sitio — así que la parada dura ahora más que el
      // paseo que la trajo.
      dwell.add(hashRange(28.0, 64.0, seed, 40 + k));
      doing.add(_actAt(s.$4, seed, k, crio));
    }

    // Y que quepa lo que va a hacer en cada parada. Ver [_fitsAt].
    final h = folkTalla(layout.character) * Townsfolk.buildOf(seed);
    for (var k = 0; k < stops.length; k++) {
      final (donde, que, mira) = _fitting(
        calles,
        h,
        crio,
        stops[k],
        look[k],
        [doing[k], ..._byWhere[doing[k].where]!],
        // La puerta no se mueve: es por donde entra y sale de casa. Lo que
        // no quepa en el umbral se cambia por otra cosa de casa que sí.
        step: k > 0,
      );
      stops[k] = donde;
      doing[k] = que;
      look[k] = mira;
    }

    // El camino de verdad: los recados, y los quiebros para no meterse por
    // dentro de las casas que queden en medio.
    //
    // En casa no se para: entrar por la puerta y volver a salir sería una
    // persona parpadeando en el umbral, así que la ronda sigue.
    final path = <(double, double)>[];
    final stay = <double>[];
    final facing = <double>[];
    final acts = <Doing?>[];
    for (var i = 0; i < stops.length; i++) {
      final from = stops[i], to = stops[(i + 1) % stops.length];
      path.add(from);
      stay.add(dwell[i]);
      facing.add(look[i]);
      acts.add(doing[i]);
      for (final q in calles.route(from, to)) {
        path.add(q);
        // Un paso del camino no es un sitio al que se va: ni se para en él ni
        // se queda mirando nada.
        stay.add(0);
        facing.add(look[i]);
        acts.add(null);
      }
    }
    var period = 0.0;
    for (var i = 0; i < path.length; i++) {
      final from = path[i], to = path[(i + 1) % path.length];
      period +=
          math.sqrt(
            math.pow(to.$1 - from.$1, 2) + math.pow(to.$2 - from.$2, 2),
          ) /
          Townsfolk.pace;
      period += stay[(i + 1) % path.length];
    }
    out.add(
      Townsfolk._(
          b.index,
          seed,
          apuntado?.$2 ?? folkName(seed),
          apuntado?.$3,
          path,
          stay,
          facing,
          acts,
          math.max(period, 1),
        )
        .._calles = calles
        .._h = h,
    );
  }
  return out;
}

/// Lo que mide una persona hecha, en un pueblo de esta región.
///
/// Medido contra el propio pueblo y no a ojo: una planta mide
/// `1.155 * storey` de suelo a techo y una persona son dos tercios largos de
/// eso, y una ventana mide el cuarenta por ciento de la planta y una persona
/// es una ventana y media. Las dos cuentas dan lo mismo. Y un cuarto menos,
/// porque las cabezas ocupan media figura y a la talla exacta salían gigantes
/// cabezones. Ver `TownPainter.folkHeight`, que es esto mismo.
double folkTalla(TownCharacter place) => 0.80 * 0.75 * place.storey;

/// Lo que ocupa en el suelo cada actividad, en partes de lo que mide quien la
/// hace y en su propio sistema (adelante en +z): el cuerpo, y todo lo que
/// lleva a lo largo del gesto entero.
final Map<String, (double, double, double, double)> _gestures = {};

(double x0, double z0, double x1, double z1) _footprintOf(Doing d, bool kid) =>
    _gestures['${d.id}:$kid'] ??= () {
      final who = Townsfolk.showcase(d, kid: kid);
      var x0 = 0.0, z0 = 0.0, x1 = 0.0, z1 = 0.0;
      // Un gesto entero, a saltos de un octavo: lo que se mueve —la maza que
      // baja, la pelota que sube— tiene que caber en todas sus posturas.
      final vuelta = 2 * math.pi / math.max(d.rate, 0.05);
      for (var k = 0; k < 16; k++) {
        for (final s in folkSolids(who, who.at(vuelta * k / 16), 1.0)) {
          for (final f in s.faces) {
            for (final v in f.v) {
              x0 = math.min(x0, v.x);
              x1 = math.max(x1, v.x);
              z0 = math.min(z0, v.z);
              z1 = math.max(z1, v.z);
            }
          }
        }
      }
      final b = who.build;
      return (x0 / b, z0 / b, x1 / b, z1 / b);
    }();

/// Si alguien de talla [h] puede hacer [d] de pie en [p] mirando a
/// [heading] sin que nada de lo suyo —el cuerpo, el taburete, el tocón, las
/// ovejas, la cometa— se meta en algo construido.
///
/// **Es la regla, no un parche por actividad.** Antes sólo se comprobaba que
/// los pies estuvieran en la calle, y lo que se lleva no se miraba nunca: un
/// puesto de mercado de medio metro de fondo delante de alguien que está a
/// un palmo de una pared es un puesto dentro de la pared. Ahora se mira todo
/// lo que ocupa el gesto entero contra el mismo plano de calles que decide
/// por dónde se anda, que ya deja un palmo de margen alrededor de lo
/// construido.
bool _fitsAt(
  Streets? calles,
  double h,
  Doing d,
  bool kid,
  (double, double) p,
  double heading,
) {
  if (calles == null || h <= 0) return true;
  final (x0, z0, x1, z1) = _footprintOf(d, kid);
  final cos = math.cos(heading), sin = math.sin(heading);
  // Una rejilla por encima de lo que ocupa, a pasos de menos de una casilla
  // del plano, con los bordes incluidos.
  const paso = 0.1;
  final nx = math.max(1, ((x1 - x0) * h / paso).ceil());
  final nz = math.max(1, ((z1 - z0) * h / paso).ceil());
  for (var i = 0; i <= nx; i++) {
    final x = x0 + (x1 - x0) * i / nx;
    for (var j = 0; j <= nz; j++) {
      final z = z0 + (z1 - z0) * j / nz;
      final q = (
        p.$1 + (x * cos + z * sin) * h,
        p.$2 + (-x * sin + z * cos) * h,
      );
      if (!calles.clearAt(q)) return false;
    }
  }
  return true;
}

/// Lo que va a hacer alguien que viene a [p], dónde se pone y mirando a
/// dónde: la primera de [prefer] que quepa, girándose lo que haga falta
/// —primero de cara a lo que vino a mirar, después un poco de lado, y de
/// espaldas lo último— y, si girándose no cabe y se puede [step], apartándose
/// de a palmos de lo que vino a mirar (hacia atrás de [look]). Si no cabe
/// ninguna, se queda mirando en [p], que no lleva nada.
((double, double), Doing, double) _fitting(
  Streets? calles,
  double h,
  bool kid,
  (double, double) p,
  double look,
  List<Doing> prefer, {
  bool step = true,
}) {
  const giros = [0.0, 0.785, -0.785, 1.571, -1.571, 2.356, -2.356, 3.142];
  for (final d in prefer) {
    if (!d.fits(kid)) continue;
    for (var k = 0; k <= (step && calles != null ? 6 : 0); k++) {
      final q = k == 0
          ? p
          : calles!.onStreets((
              p.$1 - math.sin(look) * k * 0.2,
              p.$2 - math.cos(look) * k * 0.2,
            ));
      for (final g in giros) {
        if (_fitsAt(calles, h, d, kid, q, look + g)) return (q, d, look + g);
      }
    }
  }
  return (p, Doing.idle, look);
}

/// A dónde va la gente de [layout]: la plaza, los hitos terminados y tres
/// rincones del prado, cada uno con la clase de sitio que es.
List<(double x, double z, double reach, Where kind)> _sitesOf(
  TownLayout layout,
  int placed,
  Map<int, (double x0, double z0, double x1, double z1)> huella,
) {
  final sitios = <(double x, double z, double reach, Where kind)>[
    (layout.cx, layout.cz, 0.9, Where.square),
  ];
  for (final b in layout.buildings) {
    if (!b.isLandmark) continue;
    if (b.firstPiece + b.cost > placed) continue;
    final c = huella[b.index];
    sitios.add((
      b.cx,
      b.cz,
      (c == null ? b.reach : _spanOf(c)) + 0.55,
      _wet.contains(b.landmark?.id) ? Where.water : Where.work,
    ));
  }
  // Y un paseo al borde del pueblo, para que no sea todo ir de un edificio a
  // otro. Un pueblo también es la gente que sale a mirar el campo.
  final borde = math.max(layout.radius * 0.82, 3.0);
  for (var k = 0; k < 3; k++) {
    final a = k * 2 * math.pi / 3 + 0.4;
    sitios.add((
      layout.cx + math.sin(a) * borde,
      layout.cz + math.cos(a) * borde,
      0.6,
      Where.meadow,
    ));
  }
  return sitios;
}

/// Qué clase de sitio es un recado.
/// Las obras que tienen agua.
///
/// Es lo que hace que se pueda pescar y echar barcos de papel sin inventarse
/// un río: en un pueblo con pozo hay quien saca agua, y en uno sin pozo no.
/// Un pueblo que todavía no ha levantado ninguna de éstas sencillamente no
/// tiene a nadie haciendo cosas de agua, que es lo correcto.
const Set<String> _wet = {
  'pozo',
  'salinas',
  'alfar',
  'cerveceria',
  'claustro',
  'huertoMonjes',
  'vinedo',
  'jardin',
  'baptisterio',
  'sinagoga',
  'mezquita',
  'hospitalMayor',
  'universidad',
  'faro',
  'herreriaMayor',
  'castillo',
  'muralla',
  'alcazar',
  'palacio',
  'monasterio',
  'homenaje',
  'hospederia',
};

/// Lo que se puede hacer en cada clase de sitio, repartido una sola vez.
final Map<Where, List<Doing>> _byWhere = {
  for (final w in Where.values)
    w: [
      for (final d in Doing.all)
        if (d.where == w) d,
    ],
};

/// A qué se dedica alguien al llegar a un sitio de esta clase.
///
/// Sale de la semilla, así que el mismo vecino hace lo mismo en el mismo
/// recado siempre — no hay nadie cambiando de oficio cada vez que se repinta.
///
/// Con peso: charlar en la plaza pasa mucho más que hacer malabares, y sin
/// pesos un pueblo de cuarenta vecinos tiene cuatro malabaristas. La rareza de
/// lo raro es lo que hace que valga la pena verlo.
Doing _actAt(Where where, int seed, int k, bool kid) {
  final puede = [
    for (final d in _byWhere[where]!)
      if (d.fits(kid)) d,
  ];
  if (puede.isEmpty) return Doing.idle;
  var total = 0.0;
  for (final d in puede) {
    total += d.weight;
  }
  var r = hash01(seed, 60 + k) * total;
  for (final d in puede) {
    r -= d.weight;
    if (r <= 0) return d;
  }
  return puede.last;
}

/// La semilla de quien viva en un edificio del pueblo [townSeed].
///
/// Aparte y pública porque el padrón la tiene que calcular igual el día que
/// apunta a alguien, y a partir de ahí es lo guardado lo que manda.
///
/// **El pueblo entra en la cuenta.** Salía sólo de la casa, y la semilla de
/// una casa sale de su número: la primera casa de cualquier pueblo tenía la
/// misma semilla, así que su vecino era la misma persona —misma cara, misma
/// ropa, mismo nombre— en todos los pueblos de todo el mundo.
int folkSeedOf(int townSeed, int buildingSeed, int index) =>
    hash32(hash32(buildingSeed, 0xF01C, index), 0x70A7, townSeed);

/// El padrón de [layout], leído.
///
/// Formato: `casa|semilla|nacimiento|nombre`. Se lee aquí y se escribe en el
/// modelo, que es quien tiene el hábito y las fechas de las piezas; el motor
/// sólo necesita saber leerlo.
Map<int, (int, String, DateTime)> _censusOf(List<String> book) {
  final out = <int, (int, String, DateTime)>{};
  for (final line in book) {
    final bits = line.split('|');
    if (bits.length < 4) continue;
    final home = int.tryParse(bits[0]);
    final seed = int.tryParse(bits[1]);
    final born = int.tryParse(bits[2]);
    if (home == null || seed == null || born == null) continue;
    out[home] = (
      seed,
      bits.sublist(3).join('|'),
      DateTime.fromMillisecondsSinceEpoch(born),
    );
  }
  return out;
}

/// Lo que ocupa en el suelo cada edificio, medido de lo que tiene en pie.
///
/// **Cajas y no círculos**, y eso importa más de lo que parece. Con un círculo
/// por edificio —el que le cabe por las esquinas— en un pueblo de solares a
/// dos metros y ochenta los círculos se solapan unos con otros y **no queda
/// calle**: el interior del pueblo entero queda marcado como pared, no hay
/// ningún punto libre a donde empujar a nadie, y la gente acaba andando por
/// dentro de las casas porque no hay otro sitio. Lo comprobé midiendo: hasta
/// tres metros dentro de un círculo, con todos los puntos «sacados».
///
/// Una caja se ajusta a lo que hay, y entre dos cajas hay calle.
///
/// Sólo lo que está a la altura de una persona. Un alero que vuela metro y
/// medio por encima de la cabeza no es un obstáculo, es un sitio donde
/// guarecerse.
Map<int, (double x0, double z0, double x1, double z1)> _footprints(
  TownLayout layout,
  int placed,
) {
  final out = <int, (double, double, double, double)>{};
  final n = math.min(placed, layout.pieces.length);
  for (var i = 0; i < n; i++) {
    final p = layout.pieces[i];
    if (p.y0 > 0.95) continue;
    final b = p.building;
    if (b < 0 || b >= layout.buildings.length) continue;
    final had = out[b];
    out[b] = had == null
        ? (p.x0, p.z0, p.x1, p.z1)
        : (
            math.min(had.$1, p.x0),
            math.min(had.$2, p.z0),
            math.max(had.$3, p.x1),
            math.max(had.$4, p.z1),
          );
  }
  return out;
}

/// Lo que estorba de verdad, **pieza a pieza y no edificio a edificio**.
///
/// Con una caja por edificio —la que envuelve todas sus piezas— un castillo
/// con patio, o cualquier obra en L, marca como pared un patio entero por el
/// que sí se puede andar. Y es peor que quedarse corto: al sacar un punto de
/// una caja de seis metros de alto, un paso sale por el sur y el siguiente por
/// el norte, y entre los dos queda un tramo recto de seis metros que cruza el
/// edificio de lado a lado. Eso era exactamente el tramo de nueve metros que
/// me estaba saliendo, y no se arregla partiéndolo más: el punto de en medio
/// vuelve a caer dentro y vuelve a salir por donde no es.
///
/// Una caja por pieza se ajusta a lo que hay de verdad. Son más cajas —dos
/// centenares en vez de cuarenta— pero el camino se calcula una vez, al
/// fundarse la ronda, y no sesenta veces por segundo.
const double _margin = 0.26;

List<(double x0, double z0, double x1, double z1)> _blockers(
  TownLayout layout,
  int placed,
) {
  final out = <(double, double, double, double)>[];
  final n = math.min(placed, layout.pieces.length);
  for (var i = 0; i < n; i++) {
    final p = layout.pieces[i];
    // Lo que vuela por encima de la cabeza no estorba: un alero es un sitio
    // donde guarecerse, no una pared.
    if (p.y0 > 0.95) continue;
    // Un palmo de más por cada lado, que es lo que ocupa una persona de
    // ancho: rozando la pared con el hombro no se atraviesa, pero se ve mal.
    //
    // Y un poco más que un palmo, por lo que mide una casilla del plano: una
    // casilla cuenta como libre si su centro lo está, y un punto cualquiera
    // de ella está a lo sumo a media diagonal —veinticuatro centímetros— del
    // centro. Con este margen, todo lo que pase por casillas libres queda
    // fuera de lo construido por geometría y no por suerte.
    out.add((p.x0 - _margin, p.z0 - _margin, p.x1 + _margin, p.z1 + _margin));
  }
  // Y lo que hay plantado en la plaza, que no es pieza de nadie y estaba
  // quedándose fuera: el sitio de la plaza es su centro exacto, o sea justo
  // donde está la fuente, así que había vecinos metidos en el agua y otros
  // cruzando el tablón de lado a lado.
  //
  // Los parterres no. Son de un palmo y con su bordillo, y por encima de un
  // parterre se pasa: bloquearlos partía el enlosado en cuatro trozos por los
  // que no se podía andar de uno a otro.
  if (!layout.solo && placed > 0) {
    final cx = layout.cx, cz = layout.cz;
    void estorbo(double x, double z, double w, double d) => out.add((
      x - w - _margin,
      z - d - _margin,
      x + w + _margin,
      z + d + _margin,
    ));

    final pilon = Plaza.basinOf(TownLayout.plazaReach);
    estorbo(cx, cz, pilon, pilon);
    // El tablón va girado mirando a la fuente, así que su estorbo es la caja
    // que lo contiene esté como esté puesto y no la plancha alineada a los
    // ejes: con la plancha, girado se colaba gente por las esquinas.
    estorbo(
      NoticeBoard.xAt(cx),
      NoticeBoard.zAt(cz),
      NoticeBoard.reach * 0.78,
      NoticeBoard.reach * 0.78,
    );
  }
  return out;
}

/// Lo que abulta una caja, para poner a alguien a su lado sin meterlo dentro.
double _spanOf((double, double, double, double) c) =>
    math.max(c.$3 - c.$1, c.$4 - c.$2) / 2;
