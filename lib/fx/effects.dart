import 'dart:math' as math;

import '../core/math3.dart';
import '../core/rng.dart';

enum ParticleKind { dust, chip, spark, gold, ember, moteRepair, smoke, glint }

class Particle {
  double x = 0, y = 0, z = 0;
  double vx = 0, vy = 0, vz = 0;
  double life = 0, maxLife = 1;
  double size = 1;
  double spin = 0, angle = 0;
  double drag = 2.2;
  double gravity = -6.0;
  ParticleKind kind = ParticleKind.dust;
  bool alive = false;

  /// De qué edificio salió, cuando salió de uno.
  ///
  /// Lo lleva el humo y sólo el humo: es lo que deja taparlo con las casas que
  /// tiene delante sin taparlo con la suya propia, que es la que tiene debajo.
  /// Menos uno quiere decir que no es de nadie.
  int owner = -1;
}

/// World-space particle system.
///
/// Particles live in world coordinates rather than on the screen, so the dust
/// thrown up by a landing stone stays where it was thrown even while the camera
/// keeps orbiting.
class EffectSystem {
  EffectSystem({this.capacity = 900}) {
    _pool = List.generate(capacity, (_) => Particle());
  }

  final int capacity;
  late final List<Particle> _pool;
  int _cursor = 0;
  final SeqRandom _rnd = SeqRandom(0x5eed);

  Iterable<Particle> get live => _pool.where((p) => p.alive);

  Particle _take() {
    for (var i = 0; i < capacity; i++) {
      final p = _pool[_cursor];
      _cursor = (_cursor + 1) % capacity;
      if (!p.alive) return p;
    }
    final p = _pool[_cursor];
    _cursor = (_cursor + 1) % capacity;
    return p;
  }

  void update(double dt) {
    for (final p in _pool) {
      if (!p.alive) continue;
      p.life -= dt;
      if (p.life <= 0) {
        p.alive = false;
        continue;
      }
      final d = math.exp(-p.drag * dt);
      p.vx *= d;
      p.vz *= d;
      p.vy = p.vy * d + p.gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.z += p.vz * dt;
      p.angle += p.spin * dt;
      if (p.y < 0.005 && p.vy < 0) {
        p.y = 0.005;
        p.vy = -p.vy * 0.24;
        p.vx *= 0.6;
        p.vz *= 0.6;
      }
    }
  }

  void clear() {
    for (final p in _pool) {
      p.alive = false;
    }
  }

  /// The puff a stone throws out when it lands. This is most of what sells the
  /// weight of the impact.
  void impact(V3 at, double radius, {double strength = 1.0}) {
    final n = (16 * strength).round().clamp(6, 34);
    for (var i = 0; i < n; i++) {
      final p = _take();
      final a = _rnd.range(0, math.pi * 2);
      final speed = _rnd.range(0.8, 2.9) * strength;
      p
        ..alive = true
        ..kind = ParticleKind.dust
        ..x = at.x + _rnd.jitter(radius * 0.7)
        ..y = at.y + _rnd.jitter(radius * 0.3)
        ..z = at.z + _rnd.jitter(radius * 0.5)
        ..vx = math.cos(a) * speed
        ..vz = math.sin(a) * speed * 0.8
        ..vy = _rnd.range(0.4, 2.2) * strength
        ..drag = 3.4
        ..gravity = -3.0
        ..maxLife = _rnd.range(0.5, 1.15)
        ..life = p.maxLife
        ..size = _rnd.range(0.06, 0.19) * (0.7 + strength * 0.5)
        ..spin = _rnd.jitter(2.0)
        ..angle = _rnd.range(0, 6.28);
    }
    final chips = (5 * strength).round().clamp(2, 12);
    for (var i = 0; i < chips; i++) {
      final p = _take();
      final a = _rnd.range(0, math.pi * 2);
      p
        ..alive = true
        ..kind = ParticleKind.chip
        ..x = at.x + _rnd.jitter(radius * 0.5)
        ..y = at.y
        ..z = at.z + _rnd.jitter(radius * 0.4)
        ..vx = math.cos(a) * _rnd.range(1.2, 3.6)
        ..vz = math.sin(a) * _rnd.range(0.8, 2.4)
        ..vy = _rnd.range(1.6, 4.2)
        ..drag = 0.5
        ..gravity = -9.5
        ..maxLife = _rnd.range(0.6, 1.3)
        ..life = p.maxLife
        ..size = _rnd.range(0.025, 0.06)
        ..spin = _rnd.jitter(9.0)
        ..angle = _rnd.range(0, 6.28);
    }
  }

  /// Gold motes for a finished building.
  ///
  /// They rise from around its feet rather than out of its middle, so the thing
  /// being celebrated stays visible instead of disappearing behind the
  /// celebration. Small and few: this fires several times a week for years.
  void celebrate(V3 at, double radius, {int count = 34}) {
    for (var i = 0; i < count; i++) {
      final p = _take();
      final a = _rnd.range(0, math.pi * 2);
      final r = radius * _rnd.range(0.75, 1.25);
      p
        ..alive = true
        ..kind = ParticleKind.gold
        ..x = at.x + math.cos(a) * r
        ..y = _rnd.range(0.05, radius * 0.35)
        ..z = at.z + math.sin(a) * r * 0.7
        ..vx = math.cos(a) * _rnd.range(0.15, 0.7)
        ..vz = math.sin(a) * _rnd.range(0.1, 0.5)
        ..vy = _rnd.range(1.3, 3.0)
        ..drag = 1.1
        ..gravity = 0.35
        ..maxLife = _rnd.range(1.0, 2.0)
        ..life = p.maxLife
        ..size = _rnd.range(0.016, 0.042)
        ..spin = _rnd.jitter(5.0)
        ..angle = _rnd.range(0, 6.28);
    }
  }

  /// A puff from a chimney.
  ///
  /// Nothing else says "somebody lives here" as cheaply as smoke. It rises
  /// slowly, spreads as it goes, and drifts with whatever the wind is doing, so
  /// the whole town leans the same way.
  void smoke(
    double x,
    double y,
    double z,
    double windX,
    double windZ, {
    int owner = -1,
  }) {
    final p = _take();
    p
      ..alive = true
      ..owner = owner
      ..kind = ParticleKind.smoke
      ..x = x + _rnd.jitter(0.07)
      ..y = y
      ..z = z + _rnd.jitter(0.07)
      ..vx = windX * _rnd.range(0.6, 1.3) + _rnd.jitter(0.12)
      ..vz = windZ * _rnd.range(0.6, 1.3) + _rnd.jitter(0.12)
      ..vy = _rnd.range(0.42, 0.78)
      ..drag = 0.28
      ..gravity = 0.30
      ..maxLife = _rnd.range(2.6, 4.6)
      ..life = p.maxLife
      ..size = _rnd.range(0.10, 0.20)
      ..spin = _rnd.jitter(0.5)
      ..angle = _rnd.range(0, 6.28);
  }

  /// A glint of sun on moving water.
  void glint(double x, double y, double z) {
    final p = _take();
    p
      ..alive = true
      ..kind = ParticleKind.glint
      ..x = x
      ..y = y
      ..z = z
      ..vx = 0
      ..vz = 0
      ..vy = 0
      ..drag = 8
      ..gravity = 0
      ..maxLife = _rnd.range(0.5, 1.1)
      ..life = p.maxLife
      ..size = _rnd.range(0.025, 0.06)
      ..spin = 0
      ..angle = 0;
  }

  /// A lick of flame on top of a beacon.
  void ember(double x, double y, double z) {
    final p = _take();
    p
      ..alive = true
      ..kind = ParticleKind.ember
      ..x = x + _rnd.jitter(0.16)
      ..y = y
      ..z = z + _rnd.jitter(0.12)
      ..vx = _rnd.jitter(0.3)
      ..vz = _rnd.jitter(0.2)
      ..vy = _rnd.range(0.9, 2.0)
      ..drag = 0.8
      ..gravity = 1.4
      ..maxLife = _rnd.range(0.5, 1.2)
      ..life = p.maxLife
      ..size = _rnd.range(0.03, 0.08)
      ..spin = 0
      ..angle = 0;
  }
}

/// El reloj de la fundación: cuándo sale cada cosa de la plaza.
///
/// Lo miran dos sitios que no se hablan —el pintor, que la dibuja, y la
/// pantalla del pueblo, que tira el polvo y el golpe cuando algo toca el
/// suelo— y tienen que estar de acuerdo al milisegundo o el polvo sale antes
/// o después que el aterrizaje. Por eso los números viven acá y no en ninguno
/// de los dos.
///
/// **Las dos caen del cielo**, una detrás de otra, con la caída y el rebote
/// de cualquiera de las seiscientas piezas que vendrán después. Salían de
/// debajo de la tierra, y era la única cosa de toda la app que no caía: en un
/// pueblo donde cada logro es una piedra que cae, una plaza que emerge del
/// suelo se lee como un error del dibujo y no como una plaza que se pone.
/// El taller del maestro de obras cayendo en la plaza, con él dentro: el
/// día de la primera obra. La misma caída que una pieza, desde más alto,
/// para que se vea venir desde que la cámara llega.
class WorkshopShow {
  const WorkshopShow._();

  /// Cuándo se suelta, en segundos desde que se pidió: lo que tarda la
  /// cámara en llegar a la plaza.
  static const double releaseAt = 1.1;

  /// Desde qué altura cae.
  static const double drop = 3.2;

  /// Cuándo toca el suelo.
  static double get lands => releaseAt + PlacementFx.fallDuration;

  /// Cuándo ya está todo quieto y puede salir el maestro a preguntar.
  static double get done => lands + PlacementFx.settleDuration + 0.9;

  /// A qué altura sobre su sitio está a los [t] segundos; nulo mientras no
  /// se soltó, que entonces no está.
  static double? liftAt(double t) {
    if (t < releaseAt) return null;
    return PlacementFx.fallAt(t - releaseAt, height: drop);
  }
}

class FoundingShow {
  const FoundingShow._();

  /// Lo que dura entera, en segundos.
  ///
  /// Una caída con su rebote dura casi un segundo, y el tablón se suelta
  /// pasado el primer cuarto: lo que sobra al final es aire para que el golpe
  /// se asiente antes de que el pueblo arranque.
  static const double seconds = 2.6;

  /// Cuándo se suelta cada una, en el reloj de 0 a 1.
  ///
  /// Primero el enlosado, que es lo que dice dónde está el centro; después el
  /// tablón, que es lo que el pueblo va a decir de vos. Se solapan a propósito:
  /// el tablón se suelta mientras el enlosado está acabando de asentarse, y así
  /// son dos golpes seguidos y no dos cosas esperando turno. Y el último, por
  /// separado, el banco con el consejero sentado: llega él, ya con la plaza
  /// puesta.
  static const double plazaAt = 0.0, boardAt = 0.23, benchAt = 0.46;

  /// Desde qué altura caen. La misma que una pieza cualquiera.
  static const double drop = 2.3;

  /// Cuándo toca el suelo lo que se soltó en [at].
  static double landing(double at) => at + PlacementFx.fallDuration / seconds;

  /// Si ya está todo en el suelo y quieto —la plaza, el tablón y el banco,
  /// con su rebote terminado—: desde ahí la plaza se pinta como la de
  /// siempre, con lo que ya tiene guardado.
  ///
  /// Se seguía armando entera en cada cuadro hasta que terminaba la cuenta,
  /// agua incluida, y ese último medio segundo, ya quieta, era el más caro de
  /// toda la fundación: de doce milisegundos por cuadro a setenta.
  ///
  /// Y quieto es también apoyado del todo: cualquier instante del rebote en
  /// que los tres tocan el suelo, que se pinta igual por un camino que por
  /// el otro.
  static bool settled(double t) {
    if (t >=
        benchAt +
            (PlacementFx.fallDuration + PlacementFx.settleDuration) / seconds) {
      return true;
    }
    if (t < benchLands) return false;
    for (final at in const [plazaAt, boardAt, benchAt]) {
      final y = liftAt(t, at);
      if (y == null || y.abs() >= 1e-4) return false;
    }
    return true;
  }

  static double get plazaLands => landing(plazaAt);
  static double get boardLands => landing(boardAt);
  static double get benchLands => landing(benchAt);

  /// A qué altura sobre su sitio está, en el momento [t] del reloj, lo que se
  /// soltó en [at]. Nulo mientras todavía no se soltó: entonces no se dibuja,
  /// igual que una pieza no existe hasta que la ponés.
  static double? liftAt(double t, double at) {
    if (t < at) return null;
    return PlacementFx.fallAt((t - at) * seconds, height: drop);
  }
}

/// The state of the stone currently in flight.
class PlacementFx {
  PlacementFx(this.brickIndex, {this.dropHeight = 5.2});

  final int brickIndex;
  final double dropHeight;

  /// 0..1 through the fall.
  double t = 0;

  /// Seconds since the stone landed, -1 while still falling.
  double sinceImpact = -1;

  static const double fallDuration = 0.36;
  static const double settleDuration = 0.55;

  bool get landed => sinceImpact >= 0;
  bool get done => landed && sinceImpact > settleDuration + 0.4;

  /// Height above the final resting place.
  double get yOffset => fallAt(
    landed ? fallDuration + sinceImpact : t * fallDuration,
    height: dropHeight,
  );

  /// A qué altura sobre su sitio está algo que se soltó hace [seconds]
  /// segundos: la caída que tiene todo lo que se pone en este pueblo.
  ///
  /// Está suelta y no dentro de [yOffset] porque **la plaza que se funda cae
  /// con esta misma curva sin ser pieza de nadie**: el enlosado y el tablón
  /// no tienen índice ni edificio, y antes salían de debajo de la tierra, que es
  /// lo único de toda la app que no caía del cielo. Dos cuentas separadas para
  /// la misma caída terminan con una de las dos vieja.
  static double fallAt(double seconds, {double height = 5.2}) {
    if (seconds < fallDuration) {
      final t = (seconds / fallDuration).clamp(0.0, 1.0);
      return height * (1 - t * t); // cae acelerando
    }
    // Y al tocar, un rebote corto en vez de una parada en seco.
    final s = ((seconds - fallDuration) / settleDuration).clamp(0.0, 1.0);
    return -0.035 * math.exp(-s * 7) * math.cos(s * 26);
  }

  /// Squash on landing, in x and y.
  (double, double) get squash {
    if (!landed) return (1.0, 1.0);
    final s = (sinceImpact / settleDuration).clamp(0.0, 1.0);
    final amp = 0.20 * math.exp(-s * 6.5) * math.cos(s * 22);
    return (1 + amp, 1 - amp);
  }

  /// The white-hot flash on the freshly laid stone.
  double get flash {
    if (!landed) return 0.0;
    final s = sinceImpact / 0.5;
    return s >= 1 ? 0.0 : (1 - s) * (1 - s);
  }

  void update(double dt) {
    if (!landed) {
      t += dt / fallDuration;
      if (t >= 1) {
        t = 1;
        sinceImpact = 0;
      }
    } else {
      sinceImpact += dt;
    }
  }
}
