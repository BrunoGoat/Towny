import 'dart:math' as math;

import 'habit.dart';
import 'piece.dart';

/// El reloj de la reproducción: cuándo cae cada pieza mientras se mira crecer
/// el valle entero de una sentada.
///
/// Todo lo que hay aquí es una cuenta y ninguna pantalla, que es a propósito:
/// el ritmo de esto es lo único que puede salir mal de una manera que no se ve
/// hasta que alguien lleva dos años poniendo piezas, y eso hay que poder
/// probarlo sin abrir la app.
///
/// **Por qué no es una línea de tiempo recta.** Las piezas no salen repartidas:
/// hay semanas de una al día y hay un mes de vacaciones en el que no hay
/// ninguna. Puestas en su sitio exacto del calendario, la reproducción son
/// ráfagas separadas por pantallas quietas — y en un pueblo de dos años la
/// mayor parte del rato no pasaría nada de nada.
///
/// Pero borrar los huecos tampoco vale, porque **el hueco es parte de lo que
/// pasó**. Un mes parado se tiene que ver; lo que no puede es durar un mes.
///
/// Así que el reloj se dobla. Cada pieza pesa lo mismo, y cada hueco pesa lo
/// que dure con un tope. Una ráfaga sale como ráfaga, una pausa sale como una
/// pausa, y un año sabático sale como una pausa larga y no como un intermedio.
/// Y como dentro del hueco la fecha sí corre entera, es ahí donde se ve girar
/// el cielo y cambiar la estación: lo que en el valle de verdad tardó tres
/// semanas aquí son dos segundos de luz moviéndose.
class Reel {
  Reel._(this.steps, this.seconds, this._mark, this.base, this.lead, this.tail);

  /// El respiro de antes: el valle vacío, sin nada puesto todavía.
  ///
  /// Sin él la primera pieza cae en el primer fotograma y nunca se llega a ver
  /// el prado del que salió todo — que es la mitad de lo que esto cuenta.
  static const double chronicleLead = 2.6;

  /// El de la otra reproducción, la corta. Ver [arrivals].
  static const double arrivalLead = 2.0;

  /// Y el de después: el pueblo terminado, quieto, mientras la música resuelve.
  ///
  /// Éste lo pidió un test. Sin cola, la última pieza caía exactamente en el
  /// último instante y **el pueblo de hoy se veía un fotograma**: sesenta
  /// segundos mirando cómo se hizo para no llegar a ver lo que es. Siete
  /// segundos es lo que tarda en dejar de caer gente y poder mirar lo que hay.
  static const double chronicleTail = 7.0;

  /// Y el suyo. Ver [arrivals].
  static const double arrivalTail = 5.0;

  /// Una por pieza, en el orden en que se pusieron de verdad.
  final List<ReelStep> steps;

  /// Cuántas piezas tenía ya puestas cada pueblo **antes** de que esto empiece.
  ///
  /// Ceros en la crónica, que arranca del prado vacío. En la reproducción
  /// corta —la de lo que llegó del widget— es el pueblo tal como lo dejaste:
  /// lo que cae encima son las tres o cuatro que no viste caer, y el resto ya
  /// estaba ahí y tiene que seguir estando desde el primer fotograma.
  final List<int> base;

  /// El respiro de antes y el de después, los de esta reproducción.
  final double lead, tail;

  /// Lo que dura la reproducción entera. Fija a propósito: ver esto no puede
  /// costar más cuanto más hayas hecho —sería exactamente el castigo al revés—
  /// y la música tiene un final escrito que cae donde cae. Con muchas piezas
  /// lo que pasa es que caen a puñados, que es mejor de ver que más rato.
  final double seconds;

  /// En qué segundo cae cada pieza. Una más que [steps]: la última marca es el
  /// final, y tenerla evita el caso especial en todas las cuentas de abajo.
  final List<double> _mark;

  /// Cuántas piezas hay en total.
  int get pieces => steps.length;

  DateTime get from => steps.first.when;
  DateTime get to => steps.last.when;

  /// Cuántos días de verdad hay entre la primera y la última.
  int get days => to.difference(from).inDays;

  /// Cuánto pesa un hueco por cada día que dura.
  ///
  /// Medio: dos días parados valen lo que una pieza. Por debajo de eso los
  /// huecos desaparecen y la reproducción se vuelve un chorro continuo que no
  /// dice nada de cómo fue; por encima, un pueblo de fin de semana pasa más
  /// tiempo quieto que poniendo.
  static const double gapPerDay = 0.5;

  /// Y lo máximo que puede pesar uno, dure lo que dure.
  ///
  /// Seis piezas. Es el número que hace que un mes de agosto entero se lea
  /// como «aquí no vino nadie en un buen rato» sin que se note que la app se
  /// quedó colgada. Sin tope, unas vacaciones de cuarenta días se comerían más
  /// de la mitad de la reproducción de un pueblo de un año.
  static const double gapCap = 6.0;

  /// A partir de cuántas piezas hay algo que mirar.
  ///
  /// Doce. Por debajo no hay «cómo se hizo»: hay un pueblo que se construyó
  /// entero el martes, y una cinemática de sesenta segundos sobre eso es una
  /// promesa que la propia pantalla desmiente.
  static const int enough = 12;

  /// Y desde cuántos días. Doce piezas en una tarde tampoco son una crónica.
  static const int enoughDays = 7;

  /// Si vale la pena ofrecerlo.
  static bool worthIt(List<Habit> habits) {
    final all = _chronological(habits);
    if (all.length < enough) return false;
    return all.last.when.difference(all.first.when).inDays >= enoughDays;
  }

  /// Arma la reproducción del valle entero.
  ///
  /// El valle entero y no un pueblo: las piezas de todos los hábitos van a la
  /// misma cola, ordenadas por su fecha. Es la única manera de que el segundo
  /// pueblo aparezca cuando apareció de verdad, que es de las pocas cosas que
  /// esta pantalla puede contar y ninguna otra de la app cuenta.
  static Reel? of(List<Habit> habits, {double seconds = 62.0}) {
    final all = _chronological(habits);
    if (all.length < 2) return null;

    final mark = _spread(all, seconds, chronicleLead, chronicleTail);
    return Reel._(
      all,
      seconds,
      mark,
      List<int>.filled(habits.length, 0),
      chronicleLead,
      chronicleTail,
    );
  }

  /// La reproducción corta: lo que se puso desde la pantalla de inicio y
  /// todavía no viste caer.
  ///
  /// Es la misma máquina que [of] mirando otra cosa. Allí el prado está vacío
  /// y se llena; aquí el pueblo ya está hecho y le caen las tres piezas que
  /// dejaste tocadas anoche. Lo único distinto de verdad es [base]: la cuenta
  /// de la que se parte no es cero.
  ///
  /// **Y dura lo mismo caigan una o doce**, por lo mismo que la crónica: ver
  /// lo que hiciste no puede costar más cuanto más hayas hecho. Con una, cae
  /// una y se mira el pueblo; con doce, caen a puñados, que es mejor de ver
  /// que más rato.
  static Reel? arrivals(
    List<Habit> habits,
    List<ReelStep> pieces, {
    double seconds = 11.0,
  }) {
    if (pieces.isEmpty) return null;
    final all = [...pieces]..sort((a, b) => a.when.compareTo(b.when));
    final base = List<int>.filled(habits.length, 0);
    for (var i = 0; i < habits.length; i++) {
      base[i] = habits[i].total;
    }
    for (final p in all) {
      if (p.habit >= 0 && p.habit < base.length) base[p.habit]--;
    }
    for (var i = 0; i < base.length; i++) {
      // Un pueblo no puede tener menos de cero piezas puestas, y si la cuenta
      // dice que sí es que lo que llegó no está en la lista del hábito —un
      // pueblo borrado entre medias, un guardado raro—. Se parte de cero antes
      // que de un número imposible.
      if (base[i] < 0) base[i] = 0;
    }

    final mark = _spread(all, seconds, arrivalLead, arrivalTail);
    return Reel._(all, seconds, mark, base, arrivalLead, arrivalTail);
  }

  /// En qué segundo cae cada una.
  ///
  /// El reparto entero de la clase en un sitio: las dos reproducciones lo
  /// hacen igual y lo único que cambia son los respiros. Primero lo que pesa
  /// cada cosa y después dónde cae, en dos vueltas, porque el total hace falta
  /// para repartir y el total no se sabe hasta haberlo recorrido entero. Y
  /// repartidas por el medio: ni encima de la entrada ni encima del final.
  static List<double> _spread(
    List<ReelStep> all,
    double seconds,
    double lead,
    double tail,
  ) {
    final weight = <double>[];
    var sum = 0.0;
    for (var i = 0; i < all.length; i++) {
      var w = 1.0;
      if (i > 0) {
        final gap = all[i].when.difference(all[i - 1].when).inMinutes / 1440.0;
        w += math.min(math.max(gap, 0.0) * gapPerDay, gapCap);
      }
      weight.add(w);
      sum += w;
    }
    final span = seconds - lead - tail;
    final mark = <double>[];
    var run = 0.0;
    for (final w in weight) {
      run += w;
      mark.add(lead + run / sum * span);
    }
    return mark;
  }

  /// Todas las piezas de un hábito como pasos, para la reproducción corta.
  static List<ReelStep> stepsFor(
    List<Habit> habits,
    bool Function(int habit, Piece piece) pick,
  ) {
    final out = <ReelStep>[];
    for (var h = 0; h < habits.length; h++) {
      for (final p in habits[h].pieces) {
        if (pick(h, p)) out.add(ReelStep(p.placedAt, h, p.label));
      }
    }
    out.sort((a, b) => a.when.compareTo(b.when));
    return out;
  }

  /// Todas las piezas del valle, en orden.
  ///
  /// Ordenadas por fecha y no por el orden en que están guardadas, porque no
  /// son lo mismo: una pieza se puede correr de hora después de ponerla —se
  /// corre a las once de la noche lo que se hizo a las siete— y entonces la
  /// lista del hábito ya no está en orden de reloj. Una reproducción que
  /// retrocede en el tiempo a mitad de camino sería un fallo muy raro de
  /// encontrar y muy fácil de evitar aquí.
  static List<ReelStep> _chronological(List<Habit> habits) {
    final all = <ReelStep>[];
    for (var h = 0; h < habits.length; h++) {
      for (final p in habits[h].pieces) {
        all.add(ReelStep(p.placedAt, h, p.label));
      }
    }
    all.sort((a, b) => a.when.compareTo(b.when));
    return all;
  }

  /// Cuántas piezas tenía cada hábito en el segundo [t], y en qué fecha va.
  ///
  /// Es lo único que la pantalla necesita saber: con esto se levanta el valle
  /// de ese instante y se pinta el cielo que tenía.
  ReelMoment at(double t, int habits) {
    final counts = List<int>.generate(
      habits,
      (i) => i < base.length ? base[i] : 0,
    );
    if (steps.isEmpty) {
      return ReelMoment(DateTime.now(), counts, 0, 0, -1, 0);
    }
    final clock = t.clamp(0.0, seconds);

    // Cuántas ya cayeron. Búsqueda binaria porque esto se pregunta sesenta
    // veces por segundo y la lista puede tener miles.
    var lo = 0, hi = _mark.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_mark[mid] <= clock) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final done = lo;
    for (var i = 0; i < done; i++) {
      final h = steps[i].habit;
      if (h >= 0 && h < habits) counts[h]++;
    }

    // La fecha corre también por dentro del hueco, que es lo que hace que el
    // cielo gire mientras no cae nada.
    final DateTime when;
    if (done >= steps.length) {
      when = steps.last.when;
    } else {
      final began = done == 0 ? 0.0 : _mark[done - 1];
      final ends = _mark[done];
      final k = ends <= began ? 1.0 : ((clock - began) / (ends - began));
      final a = done == 0 ? steps.first.when : steps[done - 1].when;
      final b = steps[done].when;
      when = a.add(
        Duration(
          milliseconds: (b.difference(a).inMilliseconds * k.clamp(0.0, 1.0))
              .round(),
        ),
      );
    }

    // Cuánto hace que cayó la última, para que la pantalla pueda encenderla.
    final since = done == 0 ? 1e9 : clock - _mark[done - 1];
    final last = done == 0 ? -1 : steps[done - 1].habit;
    return ReelMoment(when, counts, done, clock / seconds, last, since);
  }

  /// En qué segundo cae la pieza [i]. Para probar el reparto sin destriparlo.
  double markOf(int i) => _mark[i];
}

/// Una pieza en la cola: cuándo se puso y de qué pueblo es.
class ReelStep {
  const ReelStep(this.when, this.habit, this.label);
  final DateTime when;

  /// El hueco del hábito dentro del valle, que es también qué pueblo crece.
  final int habit;

  /// Su leyenda, si la tiene. La reproducción saca unas cuantas al pasar.
  final String? label;
  bool get hasLabel => label != null && label!.trim().isNotEmpty;
}

/// El valle en un instante de la reproducción.
class ReelMoment {
  const ReelMoment(
    this.when,
    this.counts,
    this.done,
    this.progress,
    this.lastHabit,
    this.sinceLast,
  );

  /// La fecha de verdad que se está mirando. De aquí salen el cielo, la hora y
  /// la estación, así que la luz de la reproducción es la que hubo.
  final DateTime when;

  /// Cuántas piezas tiene cada hábito puestas a esta altura.
  final List<int> counts;

  /// Cuántas van en total.
  final int done;

  /// Por dónde va, de cero a uno. Con esto se mueven la cámara y la música.
  final double progress;

  /// Qué pueblo puso la última, o -1 si todavía no cayó ninguna.
  final int lastHabit;

  /// Y cuántos segundos hace. Corto quiere decir que hay que encenderla.
  final double sinceLast;
}
