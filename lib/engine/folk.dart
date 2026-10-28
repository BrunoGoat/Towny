import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/math3.dart';
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
    this.period, {
    this.sage = false,
    List<(PropKind?, PropKind?)?>? swapIn,
    List<(PropKind?, PropKind?)?>? swapOut,
    List<PropKind?>? carry,
  }) : _swapIn = swapIn ?? const [],
       _swapOut = swapOut ?? const [],
       _carry = carry ?? const [];

  /// Lo que entra a cambiar por su puerta al llegar a cada parada —qué lleva
  /// al entrar y con qué sale—, y lo mismo al irse. Nulo, nada: casi siempre.
  /// Sólo en su puerta, y sólo para sacar o guardar lo que se usa fuera
  /// ([Doing.fetched]).
  final List<(PropKind?, PropKind?)?> _swapIn, _swapOut;

  /// Lo que lleva en las manos en el tramo que sale de cada punto del camino.
  final List<PropKind?> _carry;

  /// El consejero: el viejo de la barba y el bastón que anda por la plaza.
  ///
  /// No tiene casa, y eso es lo que es: no lo trajo ninguna obra, no vive en
  /// ningún sitio y no se va a ninguna parte de noche. Está en la plaza desde
  /// el día que se funda, dando vueltas despacio alrededor de la fuente, y se
  /// para a mirarla. Lo que sabe está en `data/advice.dart`.
  ///
  /// Su paseo es un arco que va y vuelve, y no un círculo: así no pasa nunca
  /// por delante del tablón, que está en la plaza y es lo que la gente viene
  /// a mirar. Entre una parada y la siguiente hay a lo sumo una sexta parte de
  /// vuelta, para que el tramo recto no se meta en el pilón de la fuente.
  ///
  /// Anda casi todo el rato —las paradas son de un par de segundos, a mirar—
  /// y una vez por vuelta se sienta un rato largo en el banco de la plaza
  /// ([PlazaBench]), mirando el agua.
  factory Townsfolk.sage(TownLayout layout) {
    // Un hombre hecho: la barba es suya.
    var s = hash32(layout.seed, 0x5A6E, 3);
    for (var k = 0; k < 4096; k++) {
      if (!folkIsKid(s) && !folkIsWoman(s)) break;
      s = hash32(s, 0x5A6E, k);
    }
    final cx = layout.cx, cz = layout.cz;
    (double, double) arco(double grados, double r) {
      final a = grados * math.pi / 180;
      return (cx + math.cos(a) * r, cz + math.sin(a) * r);
    }

    double haciaFuente((double, double) p) => math.atan2(cx - p.$1, cz - p.$2);
    double radio(int i) => hashRange(1.2, 1.45, s, i, 52);
    double giro(int i) => hashRange(-12, 12, s, i, 51);
    // El arco, de punta a punta, y el banco en medio con su paso de delante:
    // se llega al banco de frente, no atravesándolo por la punta.
    final p195 = arco(195 + giro(0), radio(0));
    final p255 = arco(255 + giro(1), radio(1));
    final p375 = arco(375 + giro(3), radio(3));
    final p435 = arco(435 + giro(4), radio(4));
    final frente = arco(315, 1.25);
    // El asiento, y el paso de delante del banco, que es donde se para al
    // llegar y al irse: de pie en el sitio del asiento quedaba con medio
    // cuerpo atravesando el banco.
    final mirarBanco = PlazaBench.turn;
    final asiento = (PlazaBench.xAt(cx), PlazaBench.zAt(cz));
    const delante = PlazaBench.depth + 0.16;
    final banco = (
      asiento.$1 + math.sin(mirarBanco) * delante,
      asiento.$2 + math.cos(mirarBanco) * delante,
    );
    // (sitio, cuánto se queda, hacia dónde mira, qué hace)
    final ronda = <((double, double), double, double, Doing)>[
      (p195, hashRange(4, 8, s, 61), haciaFuente(p195), Doing.idle),
      (p255, hashRange(2, 4, s, 62), haciaFuente(p255), Doing.idle),
      (frente, 0.3, mirarBanco, Doing.idle),
      (banco, hashRange(36, 50, s, 63), mirarBanco, Doing.bench),
      (frente, 0.3, mirarBanco, Doing.idle),
      (p375, hashRange(2, 4, s, 64), haciaFuente(p375) + math.pi, Doing.idle),
      (p435, hashRange(4, 8, s, 65), haciaFuente(p435), Doing.idle),
      (p375, hashRange(1, 3, s, 66), haciaFuente(p375), Doing.idle),
      (frente, 0.5, haciaFuente(frente), Doing.idle),
      (p255, hashRange(2, 4, s, 67), haciaFuente(p255) + math.pi, Doing.idle),
    ];
    final stops = [for (final r in ronda) r.$1];
    final stay = [for (final r in ronda) r.$2];
    final facing = [for (final r in ronda) r.$3];
    final acts = [for (final r in ronda) r.$4];
    var period = 0.0;
    for (var i = 0; i < stops.length; i++) {
      final a = stops[i], b = stops[(i + 1) % stops.length];
      period +=
          math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2)) /
              pace +
          stay[(i + 1) % stops.length];
    }
    return Townsfolk._(
        sageHome,
        s,
        'Consejero',
        null,
        stops,
        stay,
        facing,
        acts,
        period,
        sage: true,
      )
      ..debut = _sageAnchor[_sageKey(layout)]?.$1
      .._greetAt = _sageAnchor[_sageKey(layout)]?.$2
      .._asiento = asiento;
  }

  /// Desde cuándo cuenta su ronda el consejero de cada valle, y cuándo llegó
  /// con la fundación, si se le puso en hora (ver [arriveNow]). Aparte del
  /// consejero, porque el consejero se rehace cada vez que el pueblo cambia
  /// de forma, y la hora tiene que sobrevivirle.
  static final Map<String, (double, double)> _sageAnchor = {};
  static String _sageKey(TownLayout l) => '${l.cx},${l.cz},${l.seed}';

  /// Dónde se sienta: el asiento del banco. La parada de la ronda está un
  /// paso por delante; sólo sentado se corre hasta aquí.
  (double, double)? _asiento;

  /// Cuándo aterrizó con el banco, si fue en esta sesión: a partir de ahí,
  /// durante [greetLength] segundos, se levanta y saluda.
  double? _greetAt;

  /// Lo que dura la llegada: un segundo más sentado, levantarse dando un
  /// paso al frente, y el saludo.
  static const double greetLength = 5.6;
  static const double _sigueSentado = 1.6, _levanta = 0.7;

  /// El consejero acaba de caer del cielo sentado en el banco, en el segundo
  /// [t]: se queda un momento, se levanta, saluda a quien lo está mirando y
  /// sigue su ronda desde el paso de delante del banco, sin saltar de sitio.
  void arriveNow(TownLayout layout, double t) {
    if (!sage) return;
    final banco = _act.indexOf(Doing.bench);
    if (banco < 0) return;
    final frente = (banco + 1) % _stops.length;
    // Cuándo sale de su ronda del paso de delante del banco.
    var acc = 0.0;
    for (var i = 0; i < _stops.length; i++) {
      final from = _stops[i], to = _stops[(i + 1) % _stops.length];
      acc +=
          math.sqrt(
            math.pow(to.$1 - from.$1, 2) + math.pow(to.$2 - from.$2, 2),
          ) /
          pace;
      acc += _stay[(i + 1) % _stops.length];
      if ((i + 1) % _stops.length == frente) break;
    }
    _greetAt = t;
    debut = t + greetLength - acc;
    _sageAnchor[_sageKey(layout)] = (debut!, t);
  }

  /// Dónde está y qué hace mientras llega, [s] segundos después de
  /// aterrizar.
  FolkAt _llegando(double s) {
    final banco = _act.indexOf(Doing.bench);
    final frente = (banco + 1) % _stops.length;
    final b = _stops[banco], f = _stops[frente];
    final mira = _facing[banco];
    if (s < _sigueSentado) {
      // Sentado en el asiento, y al final se corre hacia delante para
      // levantarse delante del banco.
      final a = _asiento ?? b;
      final k = smoothstep(_sigueSentado - _corre, _sigueSentado, s);
      return FolkAt(
        lerpD(a.$1, b.$1, k),
        lerpD(a.$2, b.$2, k),
        mira,
        0,
        false,
        Doing.bench,
        5 + s,
      );
    }
    if (s < _sigueSentado + _levanta) {
      // Se levanta delante del banco, no dentro, y da un paso al frente.
      final k = smoothstep(0, 1, (s - _sigueSentado) / _levanta);
      return FolkAt(
        lerpD(b.$1, f.$1, k),
        lerpD(b.$2, f.$2, k),
        mira,
        0,
        false,
        Doing.idle,
        s,
      );
    }
    return FolkAt(
      f.$1,
      f.$2,
      mira,
      0,
      false,
      Doing.greet,
      s - _sigueSentado - _levanta,
    );
  }

  /// Para el consejero: cuánto hace que se sentó en el banco en esta vuelta
  /// de su ronda —desde que se puso, sin el respiro de llegar—, cuánto se
  /// queda sentado y en qué vuelta va. Negativo si todavía no llegó; nulo si
  /// no es el consejero. Es el reloj de las palomas (ver `pigeons.dart`).
  ({double since, double sits, int lap})? benchClock(double t) {
    if (!sage) return null;
    final u = _uAt(t);
    var acc = 0.0;
    final n = _stops.length;
    for (var i = 0; i < n; i++) {
      final from = _stops[i], to = _stops[(i + 1) % n];
      final d = math.sqrt(
        math.pow(to.$1 - from.$1, 2) + math.pow(to.$2 - from.$2, 2),
      );
      acc += d / pace;
      final stay = _stay[(i + 1) % n];
      if (_act[(i + 1) % n] == Doing.bench) {
        final settle = math.min(2.4, stay * 0.15);
        return (
          since: u - acc - settle,
          sits: stay - 2 * settle,
          lap: _lapAt(t),
        );
      }
      acc += stay;
    }
    return null;
  }

  /// La casa del consejero, que no tiene: un número que no es de ningún
  /// edificio y que no es tampoco el `-1` del de muestra.
  static const int sageHome = -2;

  /// Si es el consejero. Ver [Townsfolk.sage].
  final bool sage;

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
      if (folkIsKid(s) == kid) break;
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

  /// El centro de la plaza de su pueblo, donde está la fuente. Nulo en el
  /// expositor, que no tiene pueblo. Lo mira quien echa un barco de papel,
  /// para que caiga en el agua del pilón y no en el brocal.
  (double, double)? plazaCentre;

  /// Si es un crío. Más chico, y es el que salta a la comba o corre detrás de
  /// una mariposa — que es lo que hace un crío en un pueblo donde no hay nada
  /// más que hacer.
  bool get kid => folkIsKid(seed);

  /// Lo que mide, contra lo que mide una persona hecha.
  double get build => buildOf(seed);

  /// Lo que mide quien sale de la semilla [seed]. Ver [build].
  static double buildOf(int seed) => folkIsKid(seed)
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
    for (final q in [...?p?.puntos, ...?h?.path]) {
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
  /// no se ponga a martillear un puente y que nadie se ponga a segar dentro
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
          : _act[i] == Doing.idle
          ? _spotGlance
          : (_spotChoices(i).length > 1 ? _spotStop : _spotFirst + 2.4),
  ];

  /// Lo que puede hacer en la parada [i] cuando la sigue la cámara: lo de
  /// siempre primero, y después todo lo demás que tiene sentido ahí.
  ///
  /// Sólo las que **caben** ahí: mirando a donde mira en esa parada, nada de
  /// lo que lleva puede meterse en una pared. Ver [_fitsAt].
  List<Doing> _spotChoices(int i) => _spotMemo[i] ??= _spotChoicesOf(i);

  final Map<int, List<Doing>> _spotMemo = {};

  List<Doing> _spotChoicesOf(int i) {
    final suya = (_spotActs ?? _act)[i] ?? Doing.idle;
    final donde = (_spotStops ?? _stops)[i];
    final mira = (_spotFacing ?? _facing)[i];
    // Donde no hay nada que hacer —al pie de una obra, desde que se sacaron
    // la maza, la sierra y la carretilla— se mira un momento y se sigue: no
    // se toca el laúd en mitad de la obra. Y donde se trae algo de casa, o se
    // va a dejarlo, se hace eso y nada más.
    if (suya == Doing.idle ||
        suya.fetched ||
        _swapAt(_swapIn, i) != null ||
        _swapAt(_swapOut, i) != null) {
      return [suya];
    }
    // Y lo que se trae de casa, sólo donde es suyo: en otro sitio no está.
    return [
      suya,
      for (final d in Doing.all)
        if (d.where == suya.where &&
            d.fits(kid) &&
            d.id != suya.id &&
            !d.fetched &&
            _fitsAt(_calles, _h, d, kid, donde, mira))
          d,
    ];
  }

  double get _spotPeriod =>
      _spotPeriodMemo ??= _periodWith(_spotStay, _spotStops ?? _stops);
  double? _spotPeriodMemo;

  double _periodWith(List<double> stays, List<(double, double)> stops) {
    var p = 0.0;
    final n = stops.length;
    for (var i = 0; i < n; i++) {
      final a = stops[i], b = stops[(i + 1) % n];
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
    return _baseAt(t) % period;
  }

  /// El reloj de su ronda sin dar la vuelta: cuántos segundos lleva de
  /// rondas desde que empezó. De aquí sale en qué vuelta va.
  double _baseAt(double t) {
    final nace = debut;
    return (nace == null ? t + hash01(seed, 7) * period : t - nace) + _shift;
  }

  /// En qué vuelta de su ronda va.
  int _lapAt(double t) => (_baseAt(t) / period).floor();

  // ------------------------------------------------------------- la vuelta

  /// **Cada vuelta, en otro sitio.** La ronda es la misma —los mismos
  /// recados, por las mismas calles—, pero lo que pasa al llegar no: quien
  /// se tumba a mirar las nubes en el prado se tumba cada vez en otro trozo
  /// del prado, mirando para otro lado, y a veces en vez de tumbarse lee. Con
  /// la ronda fija, cada vecino iba a parar exactamente al mismo palmo de
  /// suelo cada vez, y en cuanto uno se fijaba se veía el reloj.
  ///
  /// Sólo se corre si cabe: lo que va a hacer tiene que caber ahí sin meterse
  /// en nada ([_fitsAt]) y los dos tramos que llegan y salen de ahí tienen
  /// que ir por suelo libre. Y lo que se anda de más o de menos se le quita o
  /// se le pone a lo que se queda, así que la vuelta dura lo mismo y el
  /// reloj de la ronda no se entera.
  int? _lapKey;
  List<(double, double)> _lapStops = const [];
  List<double> _lapStay = const [];
  List<Doing?> _lapActs = const [];
  List<double> _lapFacing = const [];

  void _lapFor(int lap) {
    if (_lapKey == lap) return;
    _lapKey = lap;
    final stops = [..._stops];
    final stay = [..._stay];
    final acts = [..._act];
    final facing = [..._facing];
    final calles = _calles;
    final n = stops.length;
    if (calles != null && home >= 0 && _h > 0) {
      double largo((double, double) a, (double, double) b) =>
          math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2));
      bool libre((double, double) a, (double, double) b) {
        final pasos = math.max(1, (largo(a, b) / 0.1).ceil());
        for (var k = 1; k < pasos; k++) {
          final q = (
            a.$1 + (b.$1 - a.$1) * k / pasos,
            a.$2 + (b.$2 - a.$2) * k / pasos,
          );
          if (!calles.clearAt(q)) return false;
        }
        return true;
      }

      for (var i = 1; i < n; i++) {
        final suya = acts[i];
        if (suya == null || stay[i] <= 0) continue;
        // En la orilla no: pescar o lavar es en el borde del agua, y corrido
        // un metro ya no hay agua delante.
        if (suya.where == Where.water) continue;
        // Ni donde lo que se hace vive en su sitio —el tocón no se mueve—,
        // ni donde se trae algo de casa, ni asomado a la fuente.
        if (suya.fetched ||
            _swapAt(_swapIn, i) != null ||
            _swapAt(_swapOut, i) != null) {
          continue;
        }
        final antes = stops[i - 1], despues = stops[(i + 1) % n];
        final anda = largo(antes, stops[i]) + largo(stops[i], despues);
        // A veces, otra cosa de las que se hacen en ese sitio.
        final otras = _spotChoices(i);
        var que = suya;
        if (otras.length > 1 && hash01(seed, lap, i, 41) < 0.45) {
          que = otras[1 + hashInt(otras.length - 1, seed, lap, i * 7 + 42)];
        }
        for (var intento = 0; intento < 10; intento++) {
          final h = i * 16 + intento;
          final r = hashRange(0.35, 1.4, seed, lap, h, 43);
          final a = hash01(seed, lap, h, 44) * 2 * math.pi;
          final p = (
            stops[i].$1 + math.cos(a) * r,
            stops[i].$2 + math.sin(a) * r,
          );
          final mira = facing[i] + (hash01(seed, lap, h, 45) - 0.5) * 1.2;
          var hace = que;
          if (!_fitsAt(calles, _h, hace, kid, p, mira)) {
            if (hace == suya || !_fitsAt(calles, _h, suya, kid, p, mira)) {
              continue;
            }
            hace = suya;
          }
          if (!libre(antes, p) || !libre(p, despues)) continue;
          // Y con aire alrededor: corrido a un sitio nuevo, que no quede
          // pegado a nada construido. Los sitios de siempre se eligieron
          // lejos de las paredes; éste tiene que estarlo también.
          var holgado = true;
          for (var k = 0; k < 8 && holgado; k++) {
            final b = k * math.pi / 4;
            holgado = calles.clearAt((
              p.$1 + math.cos(b) * 0.6,
              p.$2 + math.sin(b) * 0.6,
            ));
          }
          if (!holgado) continue;
          final queda =
              stay[i] - (largo(antes, p) + largo(p, despues) - anda) / pace;
          if (queda < 10) continue;
          stops[i] = p;
          stay[i] = queda;
          acts[i] = hace;
          facing[i] = mira;
          break;
        }
      }
    }
    _lapStops = stops;
    _lapStay = stay;
    _lapActs = acts;
    _lapFacing = facing;
  }

  /// Por dónde de la ronda va en el segundo [u] de una ronda con [stays]:
  /// en qué tramo, si andando o parado, y cuánto lleva de eso.
  (int, bool, double) _where(
    double u,
    List<double> stays,
    List<(double, double)> stops,
  ) {
    var acc = 0.0;
    final n = stops.length;
    for (var i = 0; i < n; i++) {
      final a = stops[i], b = stops[(i + 1) % n];
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
  double _uOf(
    int i,
    bool walking,
    double k,
    List<double> stays,
    List<(double, double)> stops,
  ) {
    var acc = 0.0;
    final n = stops.length;
    for (var j = 0; j < n; j++) {
      final a = stops[j], b = stops[(j + 1) % n];
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
    // Al consejero no se le sigue —tocarlo abre su menú—: su ronda es
    // siempre la de quedarse en la plaza, sentándose y levantándose del banco.
    if (sage || on == spotlit) return;
    if (on) {
      // Sigue por donde va en esta vuelta: los mismos sitios en los que
      // estaba, con el horario de cuando la siguen.
      final lap = _lapAt(t);
      _lapFor(lap);
      final (i, walking, k) = _where(_uAt(t), _lapStay, _lapStops);
      _spotLap = lap;
      _spotStops = _lapStops;
      _spotActs = _lapActs;
      _spotFacing = _lapFacing;
      _spotMemo.clear();
      _spotPeriodMemo = null;
      // Parada en un sitio, sigue con lo que estaba haciendo desde el
      // principio de lo suyo ahí: lo de siempre va primero y dura diez
      // segundos (ver [_spotFirst]). Si se cayera en el mismo segundo de la
      // parada, que con el horario nuevo es otra cosa, el libro que estaba
      // leyendo desaparecía al tocarla.
      final target = _uOf(
        i,
        walking,
        walking ? k : math.min(k, 1.25),
        _spotStay,
        _spotStops!,
      );
      _spot = target - t;
    } else {
      final (i, walking, k) = _where(_uAt(t), _spotStay, _spotStops ?? _stops);
      final lap = _spotLap ?? 0;
      _spot = null;
      _spotStops = null;
      _spotActs = null;
      _spotFacing = null;
      _spotLap = null;
      _spotMemo.clear();
      _spotPeriodMemo = null;
      _lapFor(lap);
      final target = _uOf(i, walking, k, _lapStay, _lapStops);
      // Y la ronda de siempre sigue en esa misma vuelta, que es la que tiene
      // los sitios en los que estaba.
      final nace = debut;
      final base = nace == null ? t + hash01(seed, 7) * period : t - nace;
      _shift = target + lap * period - base;
    }
  }

  /// Los sitios de la vuelta en la que se la empezó a seguir: siguiéndola,
  /// la ronda es ésa, con más cosas en cada parada.
  int? _spotLap;
  List<(double, double)>? _spotStops;
  List<Doing?>? _spotActs;
  List<double>? _spotFacing;

  /// Qué hace la persona seguida en la parada [i], a los [held] segundos de
  /// haberse puesto: va cambiando cada [_spotEach] segundos entre las cosas
  /// que tienen sentido en ese sitio, empezando por la de siempre.
  Doing _spotAct(int i, double held) {
    final puede = _spotChoices(i);
    if (held < _spotFirst) return puede.first;
    final despues = held - _spotFirst;
    final k = (despues / _spotEach).floor();
    // Entre una cosa y la siguiente, un respiro: guardar la escoba y sacar
    // el libro no pasa entre dos fotogramas.
    if (despues - k * _spotEach < 1.2) return Doing.idle;
    return puede[(k + 1) % puede.length];
  }

  // ------------------------------------------------------------ a casa

  /// Las calles del pueblo, para volver a casa rodeando lo construido. Nulo
  /// en el expositor, que no tiene pueblo.
  Streets? _calles;

  /// Las mismas calles sin lo que vive en su sitio —el tocón, el puesto, las
  /// gallinas—: por donde se va si eso deja a alguien encerrado.
  Streets? _callesSin;

  /// Los quiebros para ir de [a] a [b] rodeando lo construido y lo que vive
  /// en su sitio; o, si eso lo deja encerrado, rodeando sólo lo construido.
  List<(double, double)> _ruta((double, double) a, (double, double) b) {
    final con = _calles;
    if (con == null) return const [];
    final r = con.route(a, b);
    if (r.isNotEmpty || con.clearLine(a, b)) return r;
    return _callesSin?.route(a, b) ?? r;
  }

  /// Si ya se le vio alguna vez. Quien se ve por primera vez de noche ya
  /// estaba en casa: no se le hace volver de ningún sitio.
  bool _seen = false;

  /// Si está dentro de su casa.
  bool _inside = false;

  /// La vuelta a casa de esta tarde, si va de camino: desde cuándo y por
  /// dónde.
  ({double t0, List<(double, double)> path, PropKind? carry})? _homing;

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
    // El consejero no tiene adónde ir: se queda en la plaza, de día y de
    // noche.
    if (sage) return (at: at(t), sink: 0.0);
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
          path: [from, ..._ruta(from, door), door],
          // Si lleva algo que sacó de casa, se lo lleva a casa.
          carry: now.carry,
        );
      }
      final s = t - h.t0;
      final walk = _lengthOf(h.path) / pace;
      if (s < walk) {
        return (at: _walkAlong(h.path, s, seed).carrying(h.carry), sink: 0.0);
      }
      final into = (s - walk) / _doorway;
      if (into >= 1) {
        _inside = true;
        _homing = null;
        return null;
      }
      return (
        at: FolkAt(
          door.$1,
          door.$2,
          _facing.first + math.pi,
          0,
          false,
        ).carrying(h.carry),
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
    final ahora = at(t);
    return (at: ahora, sink: math.max(sink, ahora.sink));
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
  /// pescar, y la prueba lo hace a sus pies.
  ///
  /// Lo que se saca de casa ([Doing.fetched]) se saca de casa también en la
  /// prueba: [porCasa] es el camino hasta su puerta, entra, sale con ello, y
  /// al terminar lo vuelve a dejar.
  void tryOut(
    Doing doing,
    double t, {
    required List<(double, double)> ida,
    required double facing,
    required List<(double, double)> vuelta,
    double hold = _trialHold,
    List<(double, double)>? porCasa,
  }) {
    final item = doing.fetched ? doing.prop : null;
    final tramos = <_Tramo>[];
    if (item != null && porCasa != null) {
      tramos
        ..add(_Tramo.walk(porCasa, null))
        ..add(_Tramo.door(porCasa.last, _facing.first, (null, item)));
    }
    tramos
      ..add(_Tramo.walk(ida, item))
      ..add(_Tramo.stay(ida.last, facing, doing, hold, carry: item))
      ..add(_Tramo.walk(vuelta, item));
    if (item != null) {
      tramos.add(_Tramo.door(vuelta.last, _facing.first, (item, null)));
    }
    _trial = _Trial(doing, t, tramos);
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
    final r = _at(t);
    // Sentado en el banco, en el asiento; de pie, la parada está delante. Se
    // corre de una a otra al sentarse y al levantarse, a paso de andar: de
    // golpe era un salto de un palmo.
    final a = _asiento;
    final llega = _greetAt;
    final llegando = llega != null && t >= llega && t < llega + greetLength;
    if (a != null && r.act == Doing.bench && !llegando) {
      final i = _act.indexOf(Doing.bench);
      final stay = _stay[i];
      final sits = stay - 2 * math.min(2.4, stay * 0.15);
      final k =
          smoothstep(0, _corre, r.phase) *
          (1 - smoothstep(sits - _corre, sits, r.phase));
      final b = _stops[i];
      return FolkAt(
        lerpD(b.$1, a.$1, k),
        lerpD(b.$2, a.$2, k),
        r.heading,
        r.gait,
        r.moving,
        r.act,
        r.phase,
      );
    }
    return r;
  }

  /// Lo que tarda en correrse del paso de delante del banco al asiento, y
  /// al revés. Ya va sentado mientras se corre, así que tiene que ser casi
  /// dejarse caer: a siete décimas se veía deslizarse sentado por el aire.
  static const double _corre = 0.25;

  /// Lo que lleva en el tramo que sale del punto [i] del camino.
  PropKind? _carryAt(int i) => i < _carry.length ? _carry[i] : null;

  (PropKind?, PropKind?)? _swapAt(List<(PropKind?, PropKind?)?> l, int i) =>
      i < l.length ? l[i] : null;

  FolkAt _at(double t) {
    final llega = _greetAt;
    if (llega != null && t >= llega && t < llega + greetLength) {
      return _llegando(t - llega);
    }
    final prueba = _trial;
    if (prueba != null) {
      final en = prueba.at(t, seed);
      if (en != null) return en;
      // Ya volvió a su puerta: sigue con su ronda desde ahí.
      _trial = null;
      _resumeAtDoor(prueba.end);
    }
    final spot = _spot != null;
    if (!spot) _lapFor(_lapAt(t));
    final stays = spot ? _spotStay : _lapStay;
    final stops = spot ? (_spotStops ?? _stops) : _lapStops;
    final acts = spot ? (_spotActs ?? _act) : _lapActs;
    final facings = spot ? (_spotFacing ?? _facing) : _lapFacing;
    final u = _uAt(t);
    var acc = 0.0;
    var walked = hash01(seed, 8) * 40; // para que no pisen todos a la vez
    final n = stops.length;
    for (var i = 0; i < n; i++) {
      final from = stops[i], to = stops[(i + 1) % n];
      final dx = to.$1 - from.$1, dz = to.$2 - from.$2;
      final d = math.sqrt(dx * dx + dz * dz);
      final walk = d / pace;
      if (u < acc + walk) {
        final k = walk <= 0 ? 1.0 : (u - acc) / walk;
        return FolkAt.full(
          from.$1 + dx * k,
          from.$2 + dz * k,
          math.atan2(dx, dz),
          (walked + d * k) / stride * 2 * math.pi,
          true,
          phase: u - acc,
          carry: _carryAt(i),
        );
      }
      acc += walk;
      walked += d;
      final j = (i + 1) % n;
      final stay = stays[j];
      if (u < acc + stay) {
        var held = u - acc;
        final to = stops[j];
        final look = facings[j];
        // A la puerta a por algo, o a dejarlo: entra, y sale con lo otro.
        final entra = _swapAt(_swapIn, j), sale = _swapAt(_swapOut, j);
        if (entra != null && held < _swapLength) {
          return _enLaPuerta(to, look, held, entra);
        }
        if (sale != null && held > stay - _swapLength) {
          return _enLaPuerta(to, look, held - (stay - _swapLength), sale);
        }
        // Lo que queda de la parada, sin las idas a la puerta.
        final antes = entra != null ? _swapLength : 0.0;
        final queda = stay - antes - (sale != null ? _swapLength : 0.0);
        held -= antes;
        // Parado: mirando a donde vino a mirar, con un balanceo lento que es
        // lo que separa a alguien esperando de un poste.
        //
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
        final settle = home == -1
            ? 0.0
            : math.min(spot ? 1.2 : 2.4, queda * 0.15);
        // Y en una parada de un suspiro —la de entrar a dejar algo— no se
        // pone a nada: un gesto de medio segundo es un parpadeo.
        final metido = queda >= 6 && held >= settle && held <= queda - settle;
        // Y en el respiro no se queda congelado: respira y mira alrededor, que
        // es [Doing.idle] y es exactamente lo que hace quien acaba de llegar.
        final what = !metido
            ? Doing.idle
            : spot
            ? _spotAct(j, held - settle)
            : acts[j];
        // La cabeza se va yendo a mirar alrededor, y cuánto depende de en qué
        // ande: quien pica piedra no levanta la vista y quien no hace nada la
        // levanta todo el rato.
        final sway =
            math.sin(held * 0.7 + hash01(seed, 9) * 6) *
            0.18 *
            (what?.turn ?? 1.0);
        // Lo que trae en las manos, mientras no lo esté usando: la banqueta
        // que acaba de sacar, el barreño con el que llega al agua. Usándolo,
        // está en el suelo y lo pinta lo que hace.
        final enMano = entra != null ? entra.$2 : _carryAt(i);
        final usando = metido && (what?.fetched ?? false);
        // La fase del gesto cuenta desde que se puso a ello y no desde que
        // llegó: si contara desde la llegada, el gesto empezaría por la mitad.
        return FolkAt.full(
          to.$1,
          to.$2,
          look + sway,
          0,
          false,
          act: what,
          phase: metido ? held - settle : held,
          carry: usando ? null : enMano,
        );
      }
      acc += stay;
    }
    final last = _stops.first;
    return FolkAt(last.$1, last.$2, _facing.first, 0, false, _act.first, 0);
  }
}

/// Lo que tarda en entrar en casa a por algo —o a dejarlo— y volver a salir:
/// meterse por la puerta, un momento dentro, y salir.
const double _swapLength = 2.0;
const double _puertaEntra = 0.8, _puertaDentro = 0.4;

/// Lo que dura cada cosa que hace la persona a la que sigue la cámara, y lo
/// que se queda en cada parada.
///
/// La primera de cada parada —la de siempre, la que estaba haciendo si se
/// la tocó ahí— dura [_spotFirst]: quien la toca mientras lee es porque
/// quiere verla leer, y a los ocho segundos ya estaba guardando el libro.
const double _spotEach = 8.0, _spotFirst = 10.0, _spotStop = 22.0;

/// Lo que se queda, seguida, donde no hay nada que hacer: mira un momento y
/// sigue.
const double _spotGlance = 5.0;

/// Lo que dura una prueba haciendo la cosa, sin contar ir y volver.
const double _trialHold = 24.0;

/// Una prueba: ir, hacer una cosa un rato, y volver a casa.
class _Trial {
  _Trial(this.doing, this.t0, this.tramos);

  final Doing doing;
  final double t0;
  final List<_Tramo> tramos;

  /// El respiro de antes y de después, como en cualquier parada.
  static const double settle = 1.0;

  /// Cuándo está otra vez en su puerta.
  late final double end = t0 + tramos.fold(0.0, (a, s) => a + s.length);

  /// Por dónde pasa, para saber hasta dónde puede llegar ([Townsfolk.reach]).
  Iterable<(double, double)> get puntos sync* {
    for (final s in tramos) {
      yield* s.path ?? [s.at!];
    }
  }

  /// Dónde está en el segundo [t], o nulo si la prueba ya terminó.
  FolkAt? at(double t, int seed) {
    var s = t - t0;
    if (s < 0) s = 0;
    for (final tramo in tramos) {
      if (s < tramo.length) return tramo.at_(s, seed);
      s -= tramo.length;
    }
    return null;
  }
}

/// Un trozo de una prueba: andar, quedarse haciéndolo, o entrar en casa a
/// cambiar lo que se lleva.
class _Tramo {
  _Tramo.walk(List<(double, double)> this.path, this.carry)
    : at = null,
      facing = 0,
      doing = null,
      hold = 0,
      swap = null;

  _Tramo.stay(
    (double, double) this.at,
    this.facing,
    Doing this.doing,
    this.hold, {
    this.carry,
  }) : path = null,
       swap = null;

  _Tramo.door(
    (double, double) this.at,
    this.facing,
    (PropKind?, PropKind?) this.swap,
  ) : path = null,
      doing = null,
      hold = 0,
      carry = null;

  final List<(double, double)>? path;
  final (double, double)? at;
  final double facing;
  final Doing? doing;
  final double hold;
  final PropKind? carry;
  final (PropKind?, PropKind?)? swap;

  late final double length = path != null
      ? _lengthOf(path!) / Townsfolk.pace
      : swap != null
      ? _swapLength
      : hold + 2 * _Trial.settle;

  FolkAt at_(double s, int seed) {
    final p = path;
    if (p != null) return _walkAlong(p, s, seed).carrying(carry);
    final cambio = swap;
    if (cambio != null) return _enLaPuerta(at!, facing, s, cambio);
    final metido = s >= _Trial.settle && s <= length - _Trial.settle;
    final what = metido ? doing! : Doing.idle;
    final sway = math.sin(s * 0.7 + hash01(seed, 9) * 6) * 0.18 * what.turn;
    return FolkAt.full(
      at!.$1,
      at!.$2,
      facing + sway,
      0,
      false,
      act: what,
      phase: metido ? s - _Trial.settle : s,
      carry: metido && what.fetched ? null : carry,
    );
  }
}

/// Entrando en casa con [swap].$1 y saliendo con [swap].$2, [t] segundos
/// después de llegar a la puerta [at]. De cara a la casa al entrar y a la
/// calle al salir, como cualquiera.
FolkAt _enLaPuerta(
  (double, double) at,
  double look,
  double t,
  (PropKind?, PropKind?) swap,
) {
  const fuera = _swapLength - _puertaEntra - _puertaDentro;
  final saliendo = t >= _puertaEntra + _puertaDentro;
  final dentro = t < _puertaEntra
      ? t / _puertaEntra
      : !saliendo
      ? 1.0
      : 1 - (t - _puertaEntra - _puertaDentro) / fuera;
  return FolkAt.full(
    at.$1,
    at.$2,
    saliendo ? look : look + math.pi,
    0,
    false,
    act: Doing.idle,
    sink: dentro.clamp(0.0, 1.0),
    carry: saliendo ? swap.$2 : swap.$1,
  );
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
  // Lo que se saca de casa, de casa: primero a su puerta a por ello.
  final porCasa = doing.fetched
      ? [desde, ...who._ruta(desde, who.door), who.door]
      : null;
  final sale = porCasa == null ? desde : who.door;
  final ida = [sale, ...who._ruta(sale, aqui), aqui];
  final vuelta = [aqui, ...who._ruta(aqui, who.door), who.door];
  who.tryOut(
    doing,
    t,
    ida: ida,
    facing: mira,
    vuelta: vuelta,
    porCasa: porCasa,
  );
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
  ]) : carry = null,
       sink = 0;

  /// Lo mismo, con lo que lleva en las manos y cuánto se ha metido por su
  /// puerta.
  const FolkAt.full(
    this.x,
    this.z,
    this.heading,
    this.gait,
    this.moving, {
    this.act,
    this.phase = 0,
    this.carry,
    this.sink = 0,
  });

  /// Lo mismo, llevando [what] en las manos (nulo, nada).
  FolkAt carrying(PropKind? what) => FolkAt.full(
    x,
    z,
    heading,
    gait,
    moving,
    act: act,
    phase: phase,
    carry: what,
    sink: sink,
  );

  final double x, z;

  /// Lo que lleva en las manos de un sitio a otro: la banqueta que sacó de
  /// casa ([Doing.fetched]). Nulo, nada.
  final PropKind? carry;

  /// Cuánto se ha metido por su puerta, de cero a uno: entrando a por algo o
  /// a guardarlo, de día. De noche lo dice [folkWhere].
  final double sink;

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
      calles: had.calles,
      huella: huella,
    );
    return had.gente;
  }

  final made = _folkOf(layout, placed, calles, estorbos, huella);
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
  List<(double, double, double, double)> estorbos,
  Map<int, (double x0, double z0, double x1, double z1)> huella,
) {
  final casas = <TownBuilding>[];
  for (final b in layout.buildings) {
    if (b.isLandmark) continue;
    if (b.firstPiece + b.cost > placed) continue;
    casas.add(b);
  }
  // El consejero está en la plaza desde que se funda, haya casas o no.
  if (casas.isEmpty) {
    return [if (hasSage(layout)) Townsfolk.sage(layout)];
  }

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
  // y en el prado se siega. Alguien segando en medio de la plaza es lo que
  // pasa cuando esto no se distingue.
  final sitios = _sitesOf(layout, placed, huella);

  // Lo que diga el padrón manda. Un vecino apuntado conserva su semilla —y con
  // ella su cara, su ropa y su talla— y su nombre, pase lo que pase con el
  // plano o con la lista de nombres.
  final padron = _censusOf(layout.folk);

  // Lo que se decide de cada vecino antes de trazarle el camino: los caminos
  // se trazan después, cuando ya se sabe dónde queda todo lo que no se mueve.
  final planes =
      <
        ({
          TownBuilding b,
          int seed,
          String name,
          DateTime? born,
          bool crio,
          double h,
          List<(double, double)> stops,
          List<double> dwell,
          List<Doing> doing,
          List<double> look,
          int traido,
        })
      >[];
  // La primera casa del pueblo, la de su primer vecino: ver [adultSeed].
  final primera = layout.buildings
      .where((b) => !b.isLandmark)
      .fold<int?>(null, (m, b) => m == null || b.index < m ? b.index : m);
  for (final b in casas) {
    final apuntado = padron[b.index];
    final nacida = apuntado?.$1 ?? folkSeedOf(layout.seed, b.seed, b.index);
    final seed = b.index == primera ? adultSeed(nacida) : nacida;
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
    final crio = folkIsKid(seed);
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

    // Y que tenga sentido, no sólo que quepa. Ver [Doing.fetched]: lo que
    // se saca de casa se saca para una cosa por vuelta, y la primera: sale
    // con la banqueta, la usa, vuelve a dejarla, y sigue. Un segundo recado
    // de ésos en la misma vuelta se cambia por otra cosa de ese sitio.
    var traido = -1;
    for (var k = 1; k < stops.length; k++) {
      final d = doing[k];
      if (d.fetched && traido >= 0) {
        final (donde, que, mira) = _fitting(
          calles,
          h,
          crio,
          stops[k],
          look[k],
          [
            for (final o in _byWhere[d.where]!)
              if (!o.fetched) o,
          ],
        );
        stops[k] = donde;
        doing[k] = que;
        look[k] = mira;
        continue;
      }
      if (d.fetched) traido = k;
    }
    // El recado con algo de casa, el primero de la vuelta.
    if (traido > 1) {
      void cambia<T>(List<T> l) {
        final t = l[1];
        l[1] = l[traido];
        l[traido] = t;
      }

      cambia(stops);
      cambia(dwell);
      cambia(doing);
      cambia(look);
      traido = 1;
    }
    planes.add((
      b: b,
      seed: seed,
      // Un crío no lleva el nombre que se le apuntó si era de oficio: los
      // críos no tienen oficio.
      name: crio ? folkName(seed) : apuntado?.$2 ?? folkName(seed),
      born: apuntado?.$3,
      crio: crio,
      h: h,
      stops: stops,
      dwell: dwell,
      doing: doing,
      look: look,
      traido: traido,
    ));
  }

  final out = <Townsfolk>[];
  for (final pl in planes) {
    final stops = pl.stops;
    // Lo que se trae de casa para el primer recado, si se trae algo.
    final lleva = pl.traido > 0 ? pl.doing[pl.traido].prop : null;
    // La banqueta de la puerta: se saca al empezar y se guarda al terminar.
    final banqueta = pl.doing[0].fetched && pl.dwell[0] > 0
        ? pl.doing[0].prop
        : null;
    // Las paradas en orden, con la vuelta a casa a dejar lo traído justo
    // después del recado en el que se usó.
    final orden =
        <
          ({
            (double, double) at,
            double stay,
            double look,
            Doing act,
            (PropKind?, PropKind?)? entra,
            (PropKind?, PropKind?)? sale,
            PropKind? lleva,
          })
        >[];
    for (var k = 0; k < stops.length; k++) {
      if (k == 0) {
        final cambia = banqueta != null || lleva != null;
        orden.add((
          at: stops[0],
          // Sin quedarse en casa, lo justo para entrar a por ello.
          stay: cambia ? math.max(pl.dwell[0], _swapLength + 0.4) : pl.dwell[0],
          look: pl.look[0],
          // Si no se queda en casa, lo de casa no se hace: entra y sale.
          act: pl.dwell[0] > 0 ? pl.doing[0] : Doing.idle,
          entra: banqueta == null ? null : (null, banqueta),
          sale: cambia ? (banqueta, lleva) : null,
          lleva: lleva,
        ));
        continue;
      }
      orden.add((
        at: stops[k],
        stay: pl.dwell[k],
        look: pl.look[k],
        act: pl.doing[k],
        entra: null,
        sale: null,
        lleva: k == pl.traido ? lleva : null,
      ));
      if (k == pl.traido) {
        orden.add((
          at: stops[0],
          stay: _swapLength + 0.4,
          look: pl.look[0],
          act: Doing.idle,
          entra: (lleva, null),
          sale: null,
          lleva: null,
        ));
      }
    }

    // El camino de verdad: los recados, y los quiebros para no meterse por
    // dentro de las casas que queden en medio.
    //
    // En casa no se para: entrar por la puerta y volver a salir sería una
    // persona parpadeando en el umbral, así que la ronda sigue — salvo para
    // sacar o guardar algo, que es justo entrar y volver a salir.
    final path = <(double, double)>[];
    final stay = <double>[];
    final facing = <double>[];
    final acts = <Doing?>[];
    final entra = <(PropKind?, PropKind?)?>[];
    final sale = <(PropKind?, PropKind?)?>[];
    final carga = <PropKind?>[];
    for (var i = 0; i < orden.length; i++) {
      final o = orden[i];
      final to = orden[(i + 1) % orden.length].at;
      path.add(o.at);
      stay.add(o.stay);
      facing.add(o.look);
      acts.add(o.act);
      entra.add(o.entra);
      sale.add(o.sale);
      // De aquí al siguiente: lo que sacó al salir, o lo que trae de vuelta.
      final enMano = o.sale != null ? o.sale!.$2 : o.lleva;
      carga.add(enMano);
      // Por donde no haya nada —tampoco lo que vive en su sitio—; y si eso
      // lo deja encerrado, por donde iba antes de que estuviera.
      final vuelta = calles.route(o.at, to);
      for (final q in vuelta) {
        path.add(q);
        // Un paso del camino no es un sitio al que se va: ni se para en él ni
        // se queda mirando nada.
        stay.add(0);
        facing.add(o.look);
        acts.add(null);
        entra.add(null);
        sale.add(null);
        carga.add(enMano);
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
          pl.b.index,
          pl.seed,
          pl.name,
          pl.born,
          path,
          stay,
          facing,
          acts,
          math.max(period, 1),
          swapIn: entra,
          swapOut: sale,
          carry: carga,
        )
        .._calles = calles
        .._callesSin = calles
        .._h = pl.h
        ..plazaCentre = layout.solo ? null : (layout.cx, layout.cz),
    );
  }
  if (hasSage(layout)) out.add(Townsfolk.sage(layout));
  return out;
}

/// Si en la plaza de [layout] vive el consejero.
///
/// Uno solo por valle, en el primer pueblo, que es el del medio del valle (el
/// hueco cero, ver `Habit.centreOf`). Es el mismo viejo para todos tus
/// pueblos —los consejos son tuyos, no de cada pueblo—, y vive donde
/// empezaste.
bool hasSage(TownLayout layout) =>
    !layout.solo && layout.cx == 0 && layout.cz == 0;

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
        for (final s in folkSolids(
          who,
          who.at(vuelta * k / 16),
          1.0,
          measuring: true,
        )) {
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
/// gallinas, la guadaña— se meta en algo construido.
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
    const vueltas = giros;
    for (var k = 0; k <= (step && calles != null ? 6 : 0); k++) {
      final q = k == 0
          ? p
          : calles!.onStreets((
              p.$1 - math.sin(look) * k * 0.2,
              p.$2 - math.cos(look) * k * 0.2,
            ));
      for (final g in vueltas) {
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

/// [seed], o la primera semilla de adulto que sale de ella.
///
/// **El primer vecino de un pueblo nunca es un crío.** Uno de cada cuatro lo
/// es, y en un pueblo recién fundado el primero es el único que hay: un crío
/// solo, a dos tercios de la talla de un adulto al lado de su casa, se leía
/// como un pueblo de enanos. Se aplica al pintar y no al escribir el padrón,
/// así que vale también para los pueblos que ya lo tenían apuntado.
int adultSeed(int seed) {
  var s = seed;
  for (var i = 1; folkIsKid(s) && i < 32; i++) {
    s = hash32(seed, 0xAD17, i);
  }
  return s;
}

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
    // Y el banco, por lo mismo que el tablón: girado, su caja entera.
    estorbo(
      PlazaBench.xAt(cx),
      PlazaBench.zAt(cz),
      PlazaBench.half * 0.8,
      PlazaBench.half * 0.8,
    );
  }
  return out;
}

/// Lo que abulta una caja, para poner a alguien a su lado sin meterlo dentro.
double _spanOf((double, double, double, double) c) =>
    math.max(c.$3 - c.$1, c.$4 - c.$2) / 2;
