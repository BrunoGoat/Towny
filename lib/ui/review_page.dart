import 'package:flutter/material.dart';

import '../model/review.dart';
import 'papyrus.dart';

/// Un renglón de la cuenta: de qué es, y qué dice.
class ReviewLine {
  const ReviewLine(this.label, this.said);
  final String label;
  final String said;
}

/// La cuenta de un mes o de un año, escrita.
///
/// Se saca aparte de la página para poder leerla sin dibujar nada: lo que esta
/// app tiene que garantizar de una revisión no es que quepa bonita, es que lo
/// que dice sea verdad, y eso se comprueba sobre estas frases.
///
/// **Las cifras van en números normales, y es la única página del libro donde
/// pasa.** El resto del libro cuenta en romanos porque una crónica no cuenta en
/// árabes, y ahí la cifra es media decoración: nadie necesita saber que una
/// leyenda fue la pieza CXXIII. Una cuenta es lo contrario — existe para leer
/// los números y compararlos con los del mes pasado— y «CCIX piezas, en CLXXX
/// de los CCLXXI días» no lo lee nadie. Lo que se queda en romanos es el año del
/// encabezado, que es donde el libro habla.
List<ReviewLine> reviewLines(Review r) {
  final out = <ReviewLine>[];
  String dias(int n) => n == 1 ? 'día' : 'días';

  out.add(
    ReviewLine(
      r.open ? 'LO QUE LLEVÁS' : 'LO QUE PUSISTE',
      '${r.pieces} ${r.pieces == 1 ? 'pieza' : 'piezas'}, en '
          '${r.days} de los ${r.of} ${dias(r.of)} que contaban.',
    ),
  );

  final antes = r.before;
  final cambio = r.shift;
  if (antes != null && cambio != null) {
    final como = cambio == 0
        ? 'lo mismo'
        : '${cambio.abs()} ${cambio.abs() == 1 ? 'punto' : 'puntos'} '
              '${cambio > 0 ? 'más' : 'menos'}';
    out.add(
      ReviewLine(
        r.monthly ? 'CONTRA EL MES ANTERIOR' : 'CONTRA EL AÑO ANTERIOR',
        'Fueron ${antes.days} de ${antes.of}: $como.',
      ),
    );
  }

  out.add(ReviewLine('LOS HUECOS', _gaps(r)));

  final obra = r.underway;
  final rematadas = [for (final w in r.works) w.name].join(', ');
  out.add(
    ReviewLine(
      'LO QUE SE LEVANTÓ',
      r.works.isEmpty
          ? obra == null
                ? 'Nada se remató. El pueblo creció en casas, que también es '
                      'crecer.'
                : 'Nada se remató: ${obra.name} sigue en obra.'
          : obra == null
          ? '$rematadas.'
          : '$rematadas. ${obra.name} quedó en obra.',
    ),
  );

  final plan = r.plan;
  if (plan != null) {
    final cumple = r.planKept;
    out.add(
      ReviewLine(
        'EL PLAN',
        cumple == null
            ? '«$plan»'
            : '«$plan» Se cumplió el ${(cumple * 100).round()}% de las veces.',
      ),
    );
  }

  final quien = r.identity;
  if (quien != null) {
    out.add(
      ReviewLine(
        'QUIÉN SOS',
        '$quien Lo fuiste ${r.days} ${dias(r.days)} de éstos.',
      ),
    );
  }

  return out;
}

/// Los huecos, que es la línea que más fácil se escribe mal.
///
/// Un hueco es faltar **y volver**: los días en blanco con los que acaba el
/// tramo todavía no son un hueco, y por eso van aparte. Sin esa distinción, un
/// pueblo con cinco piezas en marzo y nada desde entonces salía con cero huecos
/// —el de siete meses no se cerró nunca— y la página anunciaba muy seria que no
/// había faltado un solo día.
String _gaps(Review r) {
  String dias(int n) => n == 1 ? 'día' : 'días';
  final cola = r.trailing;
  if (r.gaps == 0 && cola == 0) {
    return 'Ninguno: no faltaste un solo día de los que contaban.';
  }
  final b = StringBuffer();
  if (r.gaps == 0) {
    b.write('Ninguno en todo el tramo.');
  } else {
    b.write(
      'Faltaste ${r.gaps} ${r.gaps == 1 ? 'vez' : 'veces'}, y el hueco más '
      'largo fue de ${r.longest} ${dias(r.longest)}.',
    );
    if (cola == 0) b.write(' Volviste de todos.');
  }
  if (cola > 0) {
    b.write(
      r.open
          ? ' Y llevás $cola ${dias(cola)} sin poner nada.'
          : ' Y ${r.monthly ? 'el mes' : 'el año'} acabó con $cola '
                '${dias(cola)} sin nada.',
    );
  }
  return b.toString();
}

/// La página de la cuenta, en el libro del atril.
///
/// Está en el libro y no en una pantalla suya a propósito. Una pantalla de
/// «resumen» hay que ir a buscarla, y nadie va a buscar un resumen: se
/// encuentra hojeando, que es lo que uno hace con un libro, y aparece entre el
/// calendario de las obras y las leyendas de los días — que es exactamente
/// donde va una cuenta, entre los años y los días.
///
/// Acaba en una pregunta que la app no contesta. Es lo único que una revisión
/// tiene que hacer y lo único que ningún número puede hacer por vos: de todo
/// esto, decidir la única cosa que cambiarías. Y se dice dónde se escribe la
/// respuesta, porque hay un sitio para eso y es el tablón.
class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key, required this.review});

  final Review review;

  /// El subtítulo: en un mes, el mes y el año; en un año, el año.
  ///
  /// Corto a propósito, y en un solo renglón: «MES DE SEPTIEMBRE · AÑO MMXXVI»
  /// se parte en dos en media pantalla, y un encabezado partido por la mitad
  /// deja de leerse como un encabezado.
  String get when => review.monthly
      ? '${Papyrus.months[review.from.month - 1].toUpperCase()} · '
            '${Papyrus.roman(review.from.year)}'
      : 'AÑO ${Papyrus.roman(review.from.year)}';

  /// La pregunta del final, con la palabra que toca.
  String get question =>
      '¿Qué es lo único que haría que ${review.monthly ? 'el mes' : 'el año'} '
      'que viene fuera mejor?';

  @override
  Widget build(BuildContext context) {
    final lines = reviewLines(review);
    return LayoutBuilder(
      // Encogida entera antes que desbordada, igual que la portada: en una
      // pantalla chica la página mide poco, y una cuenta a la que le falta el
      // último renglón es una cuenta que no se puede creer.
      builder: (context, box) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: box.maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                review.heading,
                textAlign: TextAlign.center,
                style: Papyrus.body(
                  11,
                  w: FontWeight.w700,
                  c: Papyrus.rubric,
                ).copyWith(letterSpacing: 2.2),
              ),
              Text(
                when,
                textAlign: TextAlign.center,
                style: Papyrus.body(
                  8.5,
                  c: Papyrus.inkFaint,
                ).copyWith(letterSpacing: 1.4),
              ),
              const SizedBox(height: 8),
              const PapyrusRule(),
              const SizedBox(height: 10),
              for (final l in lines) ...[
                Text(
                  l.label,
                  style: Papyrus.body(
                    7.5,
                    c: Papyrus.inkFaint,
                  ).copyWith(letterSpacing: 1.6),
                ),
                const SizedBox(height: 1),
                Text(l.said, style: Papyrus.body(12)),
                const SizedBox(height: 11),
              ],
              const PapyrusRule(),
              const SizedBox(height: 10),
              Text(
                question,
                textAlign: TextAlign.center,
                style: Papyrus.body(
                  12,
                  c: Papyrus.rubric,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 4),
              Text(
                'Eso es todo lo que hay que sacar de esta hoja. Lo que salga, '
                'clavalo en el tablón.',
                textAlign: TextAlign.center,
                style: Papyrus.body(10, c: Papyrus.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
