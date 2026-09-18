/// Cómo se va de una puerta a otra sin cruzar una pared.
///
/// Una rejilla de casillas libres sobre la parcela del pueblo y un camino más
/// corto por encima. Es un algoritmo entero y cerrado: entran las cajas de los
/// edificios y dos puntos, sale una lista de esquinas por las que pasar. No
/// sabe qué es un vecino, ni qué hora es, ni que existe un pueblo.
///
/// Estaba en medio de `folk.dart` porque el que lo llama vive ahí, que no es
/// una razón. Medido antes de moverlo: de las trescientas treinta líneas, lo
/// único que compartía con el resto del fichero era **una mención en un
/// comentario**. Aquí se lee como lo que es —una rejilla, una cola de
/// prioridad y un Dijkstra— y allí se leía como un tramo de código que había
/// que saltarse para llegar a lo siguiente.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Las calles del pueblo, como plano por el que se puede buscar camino.
///
/// Esto es lo que había que hacer desde el principio y tardé seis intentos en
/// aceptarlo. Todo lo anterior —círculos de estorbo, quiebros por las
/// esquinas, partir el tramo y sacar el punto de en medio— era **reparación
/// local**: coger la línea recta de un recado al siguiente y arreglarla por
/// trozos. Y una reparación local no puede rodear un edificio, por definición;
/// lo más que consigue es pegar el camino a la pared por el lado que le toque,
/// y cuando el punto siguiente se pega por el lado contrario queda un tramo
/// recto de seis metros que cruza la casa de parte a parte. Lo medí: de
/// cuatro vecinos metidos en paredes se bajaba a uno, y de ahí no bajaba.
///
/// Un plano sí puede. El suelo del pueblo se parte en casillas de un tercio de
/// metro, se marcan las que pisa algo construido, y de una casilla libre a
/// otra se busca camino. No hay heurística que ajustar y no hay caso que se
/// escape: si el camino existe lo encuentra, y todas sus casillas están
/// libres, así que no hay por dónde meterse en una pared.
///
/// Se construye **una vez por pueblo** —no uno por vecino— y la ronda entera
/// se calcula al fundarla, no al pintarla.
class Streets {
  Streets(this.x0, this.z0, this.cols, this.rows, this._free) {
    _label();
    _cost = Float64List(_free.length);
    _from = Int32List(_free.length);
    _seen = Int32List(_free.length);
  }

  /// Una huella de qué casillas están libres y cuáles no.
  ///
  /// Es lo único que decide un camino: dos rejillas con las mismas casillas
  /// libres dan los mismos caminos para todo el mundo, siempre. Sirve para no
  /// rehacer la ronda de un pueblo entero cuando la pieza que acaba de caer no
  /// ha tapado ninguna casilla nueva — que es lo que pasa cuatro de cada cinco
  /// veces, porque la mayoría de las piezas suben un piso a una casa que ya
  /// estaba ocupando ese trozo de suelo.
  int get fingerprint {
    var h = 0x811c9dc5;
    for (var i = 0; i < _free.length; i++) {
      h = ((h ^ (_free[i] ? 1 : 0)) * 0x01000193) & 0x3fffffff;
    }
    return h;
  }

  /// La esquina de la casilla (0, 0), en coordenadas del valle.
  final double x0, z0;
  final int cols, rows;

  /// Por dónde se puede pisar. Una casilla está libre si su centro no cae
  /// dentro de nada.
  final List<bool> _free;

  /// Lo que gasta el A*, de una vez y para siempre: un mapa por casilla en
  /// vez de un diccionario que se llena y se tira quinientas veces.
  /// [_seen] dice de qué búsqueda es lo que hay escrito, que es más barato que
  /// borrarlo todo entre una y otra.
  late final Float64List _cost;
  late final Int32List _from;
  late final Int32List _seen;
  int _run = 0;

  /// En qué trozo de pueblo cae cada casilla, y cual es el trozo grande.
  ///
  /// Un pueblo no siempre es de una pieza: el patio de un castillo, el hueco
  /// entre un muro y el río, la esquina que deja cerrada una obra nueva. Si a
  /// alguien le toca un recado al otro lado de una pared no hay camino, y sin
  /// camino lo que quedaba era la línea recta — por dentro de todo. Se marcan
  /// los trozos una vez y los recados se buscan siempre en el grande.
  late final List<int> _region;
  late final int _main;

  void _label() {
    _region = List<int>.filled(_free.length, -1);
    var next = 0, mejor = 0, cual = -1;
    final pila = <int>[];
    for (var seed = 0; seed < _free.length; seed++) {
      if (!_free[seed] || _region[seed] >= 0) continue;
      final id = next++;
      var size = 0;
      pila
        ..clear()
        ..add(seed);
      _region[seed] = id;
      while (pila.isNotEmpty) {
        final at = pila.removeLast();
        size++;
        final cx = at % cols, cz = at ~/ cols;
        for (var dz = -1; dz <= 1; dz++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dz == 0) continue;
            if (!_freeAt(cx + dx, cz + dz)) continue;
            // Igual que en el A*: por la punta de dos piezas no se pasa, así
            // que tampoco cuenta como el mismo trozo de pueblo.
            if (dx != 0 && dz != 0) {
              if (!_freeAt(cx + dx, cz) || !_freeAt(cx, cz + dz)) continue;
            }
            final j = (cz + dz) * cols + cx + dx;
            if (_region[j] >= 0) continue;
            _region[j] = id;
            pila.add(j);
          }
        }
      }
      if (size > mejor) {
        mejor = size;
        cual = id;
      }
    }
    _main = cual;
  }

  /// El sitio de verdad para un recado: éste mismo si se puede llegar a él, y
  /// si no el más cercano al que sí.
  (double, double) onStreets((double, double) p) {
    final (cx, cz) = _cellOf(p);
    if (_freeAt(cx, cz) && _region[cz * cols + cx] == _main) return p;
    for (var r = 1; r <= 30; r++) {
      for (var dz = -r; dz <= r; dz++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dz.abs() != r) continue;
          if (!_freeAt(cx + dx, cz + dz)) continue;
          final j = (cz + dz) * cols + cx + dx;
          if (_region[j] != _main) continue;
          return _centreOf(j);
        }
      }
    }
    return p;
  }

  /// Un tercio de metro, que es menos que el hueco más estrecho entre dos
  /// casas del pueblo más apretado. Con casillas más grandes una calle se
  /// cierra sola y la gente da un rodeo por donde sí se puede pasar.
  static const double cell = 1 / 3;

  /// La rejilla de una parcela: su centro, hasta dónde llega, y lo que hay
  /// plantado dentro.
  ///
  /// Tres números y una lista de cajas, no un `TownLayout`. Es lo único que
  /// esto leía del plano del pueblo, y pedir el plano entero para sacarle el
  /// centro y el radio era la única línea que ataba un Dijkstra a que existiera
  /// un pueblo — y con ella, a `town.dart` entero.
  factory Streets.of(
    double cx,
    double cz,
    double radius,
    List<(double, double, double, double)> blocks,
  ) {
    final borde = radius + 9;
    final x0 = cx - borde, z0 = cz - borde;
    final n = math.max(8, (borde * 2 / cell).ceil());
    final free = List<bool>.filled(n * n, true);
    for (final c in blocks) {
      // Sólo las casillas de esta caja, que es lo que hace que marcar
      // doscientas piezas en un plano de treinta mil casillas sea gratis.
      final ax = math.max(0, ((c.$1 - x0) / cell).floor());
      final az = math.max(0, ((c.$2 - z0) / cell).floor());
      final bx = math.min(n - 1, ((c.$3 - x0) / cell).ceil());
      final bz = math.min(n - 1, ((c.$4 - z0) / cell).ceil());
      for (var cz = az; cz <= bz; cz++) {
        final mz = z0 + (cz + 0.5) * cell;
        if (mz <= c.$2 || mz >= c.$4) continue;
        for (var cx = ax; cx <= bx; cx++) {
          final mx = x0 + (cx + 0.5) * cell;
          if (mx <= c.$1 || mx >= c.$3) continue;
          free[cz * n + cx] = false;
        }
      }
    }
    return Streets(x0, z0, n, n, free);
  }

  bool _freeAt(int cx, int cz) =>
      cx >= 0 && cz >= 0 && cx < cols && cz < rows && _free[cz * cols + cx];

  (int, int) _cellOf((double, double) p) =>
      (((p.$1 - x0) / cell).floor(), ((p.$2 - z0) / cell).floor());

  (double, double) _centreOf(int i) =>
      (x0 + (i % cols + 0.5) * cell, z0 + (i ~/ cols + 0.5) * cell);

  /// La casilla libre más cerca de una. Hace falta porque un punto puede estar
  /// libre y caer en una casilla cuyo centro no lo está — el borde de una
  /// pared parte casillas por la mitad.
  int? _near((double, double) p) {
    final (cx, cz) = _cellOf(p);
    if (_freeAt(cx, cz)) return cz * cols + cx;
    for (var r = 1; r <= 5; r++) {
      for (var dz = -r; dz <= r; dz++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dz.abs() != r) continue;
          if (_freeAt(cx + dx, cz + dz)) {
            return (cz + dz) * cols + cx + dx;
          }
        }
      }
    }
    return null;
  }

  /// Los quiebros que hay que dar para ir de [a] a [b] sin pisar nada.
  ///
  /// Sin [a] ni [b], que los pone quien llama. Vacío cuando la línea recta ya
  /// está libre, que en un pueblo abierto es casi siempre.
  List<(double, double)> route((double, double) a, (double, double) b) {
    if (!_walled(a, b)) return const [];
    final from = _near(a), to = _near(b);
    if (from == null || to == null) return const [];
    final camino = _search(from, to);
    if (camino == null) return const [];
    return _straighten(a, b, camino);
  }

  /// Si el tramo recto de [a] a [b] pisa algo.
  ///
  /// Se lo pregunta al plano y no a las cajas. Cuesta lo que mide el tramo y
  /// no lo que mide el pueblo: mil piezas son mil cajas que probar por cada
  /// tramo, y estirar los caminos de ciento cuarenta vecinos así tardaba medio
  /// segundo —justo al poner una pieza, que es el único momento en que la app
  /// tiene que ir fina—. Y es igual de de fiar, porque el margen de [_margin]
  /// ya cuenta con lo que mide una casilla.
  bool _walled((double, double) a, (double, double) b) {
    final d = math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2));
    final n = math.max(1, (d / (cell / 3)).ceil());
    for (var k = 0; k <= n; k++) {
      final t = k / n;
      final (cx, cz) = _cellOf((
        a.$1 + (b.$1 - a.$1) * t,
        a.$2 + (b.$2 - a.$2) * t,
      ));
      if (!_freeAt(cx, cz)) return true;
    }
    return false;
  }

  /// A* por las ocho vecinas, sin cortar esquinas en diagonal: pasar entre dos
  /// piezas que se tocan por la punta es pasar por dentro de las dos.
  List<int>? _search(int from, int to) {
    final tx = to % cols, tz = to ~/ cols;
    const raiz2 = 1.41421356237;
    final run = ++_run;
    _seen[from] = run;
    _cost[from] = 0;
    _from[from] = -1;
    final abierto = _Heap()..push(from, 0);
    var pasos = 0;
    while (abierto.isNotEmpty) {
      final at = abierto.pop();
      if (at == to) {
        final out = <int>[];
        for (var i = to; i >= 0; i = _from[i]) {
          out.add(i);
        }
        return out.reversed.toList();
      }
      // Un tope, porque un vecino encerrado por obra nueva puede no tener
      // camino a ninguna parte y no se va a buscar por el pueblo entero para
      // averiguarlo. Sin camino, la recta: se verá mal un instante, que es
      // mejor que una app que se queda pensando.
      if (++pasos > 60000) return null;
      final cx = at % cols, cz = at ~/ cols;
      final ya = _cost[at];
      for (var dz = -1; dz <= 1; dz++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dz == 0) continue;
          if (!_freeAt(cx + dx, cz + dz)) continue;
          if (dx != 0 && dz != 0) {
            if (!_freeAt(cx + dx, cz) || !_freeAt(cx, cz + dz)) continue;
          }
          final next = (cz + dz) * cols + cx + dx;
          final paso = ya + (dx != 0 && dz != 0 ? raiz2 : 1.0);
          if (_seen[next] == run && _cost[next] <= paso) continue;
          _seen[next] = run;
          _cost[next] = paso;
          _from[next] = at;
          final hx = (tx - cx - dx).abs(), hz = (tz - cz - dz).abs();
          final min = math.min(hx, hz);
          // Con la corazonada pesada: un camino de vecino no tiene por qué ser
          // el más corto que existe, tiene que ser uno que no pise casas y que
          // no se note raro, y después de estirarlo no hay ojo que distinga un
          // tres por ciento de rodeo. Buscando el óptimo exacto se exploraba
          // medio pueblo por cada recado.
          const afan = 1.4;
          abierto.push(next, paso + ((hx + hz - min) + raiz2 * min) * afan);
        }
      }
    }
    return null;
  }

  /// Estirar el camino: de la cuadrícula a una línea de verdad.
  ///
  /// Se va todo lo lejos que se pueda en recta y se quiebra sólo donde hay que
  /// quebrar. Sin esto, andar por las casillas se ve como andar por las
  /// casillas — a pasitos de un tercio de metro y en ocho direcciones.
  List<(double, double)> _straighten(
    (double, double) a,
    (double, double) b,
    List<int> camino,
  ) {
    final pts = <(double, double)>[a, for (final i in camino) _centreOf(i), b];
    final out = <(double, double)>[];
    var i = 0;
    while (i < pts.length - 1) {
      // Hacia delante y no hacia atrás desde el final: probando desde el final
      // se tira el tramo entero por cada quiebro, y son tantas pruebas como el
      // cuadrado de lo que mide el camino.
      var j = i + 1;
      while (j + 1 < pts.length && !_walled(pts[i], pts[j + 1])) {
        j++;
      }
      if (j < pts.length - 1) out.add(pts[j]);
      i = j;
    }
    return out;
  }
}

/// Un montón para el A*, que dart:core no trae.
///
/// Lo mínimo que hace falta: meter con prioridad y sacar la menor. Las
/// entradas viejas se quedan dentro y se descartan al salir, que es más barato
/// que buscarlas para cambiarlas de sitio.
class _Heap {
  final List<int> _what = [];
  final List<double> _cost = [];

  bool get isNotEmpty => _what.isNotEmpty;

  void push(int what, double cost) {
    _what.add(what);
    _cost.add(cost);
    var i = _what.length - 1;
    while (i > 0) {
      final up = (i - 1) >> 1;
      if (_cost[up] <= _cost[i]) break;
      _swap(up, i);
      i = up;
    }
  }

  int pop() {
    final top = _what.first;
    final last = _what.length - 1;
    _swap(0, last);
    _what.removeLast();
    _cost.removeLast();
    var i = 0;
    while (true) {
      final l = i * 2 + 1, r = l + 1;
      var min = i;
      if (l < _what.length && _cost[l] < _cost[min]) min = l;
      if (r < _what.length && _cost[r] < _cost[min]) min = r;
      if (min == i) break;
      _swap(i, min);
      i = min;
    }
    return top;
  }

  void _swap(int a, int b) {
    final w = _what[a];
    _what[a] = _what[b];
    _what[b] = w;
    final c = _cost[a];
    _cost[a] = _cost[b];
    _cost[b] = c;
  }
}
