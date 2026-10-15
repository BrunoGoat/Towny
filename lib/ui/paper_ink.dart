import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/board_plan.dart';
import '../model/appearance.dart';
import '../model/notice.dart';
import 'note_font.dart';

/// Lo que lleva escrito una hoja.
///
/// Se maqueta en un rectángulo plano de [box] píxeles y de ahí lo recoge la
/// homografía, que lo planta sobre las cuatro esquinas de la hoja en la
/// pantalla. Por eso aquí no hay ni cámara ni perspectiva: esto es la hoja
/// vista de frente, y torcerla es asunto de quien la clava.
///
/// **Una sola maquetación.** Antes había dos —la de la hoja clavada y la de
/// la descolgada— y se cruzaban al abrirla. Eso hacía que durante el cruce se
/// vieran las dos frases, una encima de la otra y las dos a medias, que es
/// exactamente lo que parece papel transparente. Ahora el texto es el mismo
/// clavada que descolgada, y lo único que cambia al descolgarla es lo que se
/// añade debajo: las barras y el párrafo de más, que aparecen porque hay sitio
/// y porque ahora se puede leer.
///
/// El aire es de cartel de bando y no de nota adhesiva: un filete alrededor,
/// el titular espaciado con su raya debajo, y tinta parda.
class PaperInk {
  PaperInk(this.notice, {NoteFont? font, double? scale})
    : font =
          font ??
          NoteFont.porNombre(switch (notice.kind) {
            // Todo lo que clavás lo escribe la misma persona, que sos vos.
            NoticeKind.mine => NoteFont.rotulador.name,
            _ => Appearance.noteFont,
          }) ??
          NoteFont.sistema,
      scale = scale ?? Appearance.noteScale {
    _lay();
  }

  final Notice notice;

  /// Con qué letra, y de qué cuerpo. Se leen de los ajustes al maquetar, así
  /// que cambiar de letra pide rehacer las hojas — no hay nada que actualizar
  /// en caliente aquí dentro.
  final NoteFont font;
  final double scale;

  /// Una nota tuya se lee de corrido y no como un titular con su remate.
  ///
  /// Las notas del tablón son lo que el pueblo dice de vos, y debajo las
  /// cuentas de las que lo sacó: ahí la raya separa dos cosas que de verdad
  /// son distintas. «Comprar cal» no es una afirmación con su prueba debajo. Lo que va en el sitio de las cuentas es desde cuándo está
  /// clavada, que se lee al descolgarla y no desde el tablón.
  ///
  /// Salvo que le hayas escrito un renglón debajo: entonces tiene titular y
  /// algo más, y se escribe como las otras. Ésas llevan el día en
  /// [Notice.more] — ver `myNotices`.
  bool get corrido => notice.kind == NoticeKind.mine && notice.more == null;

  /// El rectángulo en el que se maqueta. Su proporción es la de la hoja
  /// ([BoardPlan.paperW] contra [BoardPlan.paperH]), o el texto saldría
  /// estirado.
  static const Size box = Size(300, 230);
  static const double pad = 18;

  /// Cómo se maqueta, en un solo sitio.
  ///
  /// Público porque hay un test que mide si a las notas escritas a mano les
  /// cabe lo que dicen, y para que esa medida signifique algo tiene que
  /// hacerse con estos números y no con unos parecidos. Una nota que no cabe
  /// sale recortada con puntos suspensivos.
  static const double saidSize = 15.5, becauseSize = 10.5;
  static const int saidLines = 4;

  /// Los renglones de debajo del titular. Eran cuatro, y una nota que pedía
  /// cinco no se partía en cinco: se encogía entera hasta que la frase
  /// entrara en cuatro, y salía a un cuarto de su tamaño con el papel medio
  /// vacío. Lo que de verdad limita es el alto del papel.
  static const int becauseLines = 10;

  /// Y el de corrido, que es todo el papel para una sola frase.
  static const double plainSize = 13, plainLines = 8;
  static const double lineHeight = 1.26;
  static double get textWidth => box.width - pad * 2;

  /// No son `final`: si el texto no entra se vuelve a maquetar más chico, y
  /// eso es reasignarlas.
  late TextPainter _said, _because;

  /// El alto del que dispone el texto dentro del papel.
  static double get textHeight => box.height - pad * 2 - 4;

  void _lay() {
    // Se maqueta, y si no entra se busca el tamaño más grande que sí entre.
    //
    // Una nota larga en una letra manuscrita puede pedir mucho más sitio
    // que el que hay, y sin esto saldría cortada con puntos suspensivos. Un
    // papel de un tablón se
    // escribe más chico cuando hay mucho que decir, que es exactamente esto.
    //
    // Se busca por mitades y no bajando a ojo. Bajar a ojo se pasa de largo
    // —al encoger cambian los cortes de línea y se gana una línea entera de
    // golpe—, y pasarse de largo tiene una consecuencia fea: que pedir más
    // tamaño dé menos. Con «Otra mano» en el tope, el deslizador escribía más
    // chico que a media altura. Buscando por mitades, el tamaño que sale es
    // siempre el mayor que cabe, así que subir el deslizador nunca puede
    // escribir más chico.
    //
    // Y no cabe de dos maneras, no de una: puede pasarse de alto, o puede
    // pasarse de renglones y salir cortado con puntos suspensivos aunque sobre
    // papel por abajo. Las dos son «no cabe». Mirando sólo el alto, un titular
    // largo se recortaba y ahí se quedaba —el alto ya estaba bien, porque lo
    // que no entraba estaba tirado— y eso es lo que le pasaba a la frase que
    // escribe el usuario: «este pueblo es de alguien que entrena antes de que
    // empiece el día» acababa en «…» con media hoja en blanco debajo.
    _layAt(1);
    shrunk = 1;
    if (_cabe) {
      _grow();
      return;
    }

    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 8; i++) {
      final k = (lo + hi) / 2;
      _layAt(k);
      if (_cabe) {
        lo = k;
      } else {
        hi = k;
      }
    }
    // La última prueba pudo ser una que no entraba: se deja puesta la mayor
    // que sí.
    _layAt(lo);
    shrunk = lo;
  }

  /// **Y si sobra papel, se escribe más grande.** Una nota que es sólo texto
  /// —sin gráfico debajo— y corta dejaba media hoja en blanco con la letra
  /// enana arriba: la de bienvenida del tablón, la del plan. Un cartel de
  /// plaza se escribe del tamaño del papel. Se busca igual que al encoger,
  /// por mitades, hasta casi el doble.
  ///
  /// Sólo esas: una nota tuya ya se escribe de corrido con todo el papel, y una nota con gráfico necesita el sitio
  /// para el gráfico.
  void _grow() {
    if (corrido || notice.bars.isNotEmpty) return;
    var lo = 1.0, hi = maxGrow;
    _layAt(hi);
    if (_cabe) {
      grown = hi;
      return;
    }
    for (var i = 0; i < 8; i++) {
      final k = (lo + hi) / 2;
      _layAt(k);
      if (_cabe) {
        lo = k;
      } else {
        hi = k;
      }
    }
    _layAt(lo);
    grown = lo;
  }

  /// Hasta cuánto se agranda una nota de sólo texto que tiene sitio.
  static const double maxGrow = 1.9;

  /// Cuánto se agrandó: 1 es que se quedó como estaba.
  double grown = 1;

  /// Cuánto hubo que encoger el texto para que entrara: 1 es que entró tal
  /// cual. Sirve para saber si el deslizador del tamaño todavía hace algo o si
  /// el papel ya está pidiendo lo contrario.
  double shrunk = 1;

  /// Lo que ocupa todo lo que lleva el papel: el titular, la raya, el renglón
  /// de abajo y el gráfico.
  ///
  /// El gráfico cuenta, y antes no contaba. La búsqueda del tamaño miraba sólo
  /// el texto, así que el texto siempre «entraba» y el gráfico se quedaba con
  /// lo que sobrara: en la nota del ritmo sobraban cuarenta y un píxeles de
  /// los cincuenta y cuatro que pide, y las barras salían aplastadas contra el
  /// filete. Reservando su sitio, lo que se ajusta es el texto, que es lo que
  /// se puede escribir más chico sin perder nada.
  ///
  /// Lo que pide es fijo y no proporcional: un gráfico de veinte píxeles no
  /// es un gráfico más chico, es una raya. Trece de esos píxeles son los pies
  /// de las barras cuando los hay, y ésos son texto de verdad.
  static const double chartHeight = 46, chartWithTicks = 58, chartGap = 8;

  double get _chart => corrido || notice.bars.isEmpty
      ? 0
      : chartGap + (notice.ticks.isEmpty ? chartHeight : chartWithTicks);

  /// El alto que le queda de verdad al gráfico al pintar.
  ///
  /// Cero es que no hay gráfico o que no cabe ninguno. Normalmente es lo que
  /// pide entero, porque el texto se encogió para dejarle sitio; el mínimo
  /// sigue ahí para el caso en que ni encogiendo entrara, porque aplastado se
  /// lee peor que entero pero mejor que fuera del papel.
  double get chartRoom {
    if (corrido || notice.bars.isEmpty) return 0;
    final y = pad + 4 + _said.height + 13 + _because.height;
    final hueco = box.height - pad - y;
    if (hueco <= 34) return 0;
    return math.min(
      hueco - chartGap,
      notice.ticks.isEmpty ? chartHeight : chartWithTicks,
    );
  }

  double get _alto =>
      _said.height + (corrido ? 0 : 13 + _because.height) + _chart;

  /// Si lo maquetado ahora mismo entra en el papel: ni se pasa de alto ni se
  /// queda ningún renglón fuera.
  bool get _cabe =>
      _alto <= textHeight &&
      !_said.didExceedMaxLines &&
      !_because.didExceedMaxLines;

  void _layAt(double k) {
    final ancho = textWidth;
    if (corrido) {
      _said = _paint(
        '${notice.said} ${notice.because}',
        plainSize * k,
        FontWeight.w500,
        0.92,
        plainLines.round(),
        ancho,
        0,
      );
      _because = _paint('', becauseSize, FontWeight.w400, 0, 1, ancho, 0);
      return;
    }
    _said = _paint(
      notice.said,
      saidSize * k,
      FontWeight.w700,
      1.0,
      saidLines,
      ancho,
      0.15,
    );
    _because = _paint(
      notice.because,
      becauseSize * k,
      FontWeight.w400,
      0.74,
      becauseLines,
      ancho,
      0,
    );
  }

  TextPainter _paint(
    String text,
    double size,
    FontWeight weight,
    double alpha,
    int lines,
    double width,
    double spacing,
  ) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: font.family,
        color: BoardPlan.ink.withValues(alpha: alpha),
        fontSize: size * font.scale * scale,
        height: lineHeight,
        letterSpacing: spacing,
        fontWeight: weight,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: lines,
    ellipsis: '…',
  )..layout(maxWidth: width);

  /// Si al papel no le cabe lo que lleva escrito, ni encogiéndolo.
  bool get overflows => !_cabe;

  /// Pinta la hoja. [detail] dice cuánto texto se gana a la distancia a la que
  /// está: de lejos una hoja es una mancha clara sobre madera, que es lo que es
  /// de verdad.
  ///
  /// Ya no hay dos estados. La nota enseña todo lo que tiene esté clavada o
  /// descolgada, y descolgarla sirve para poder leerla, no para que aparezca
  /// nada. El párrafo que había debajo del gráfico se fue entero: contaba cómo
  /// leer el gráfico, y un gráfico que necesita que le expliquen cómo leerlo
  /// está mal hecho.
  void paint(Canvas canvas, double detail) {
    if (detail <= 0.02) return;
    final capa = detail < 0.99;
    if (capa) {
      canvas.saveLayer(
        Offset.zero & box,
        Paint()..color = Colors.white.withValues(alpha: detail.clamp(0.0, 1.0)),
      );
    }

    // El filete del bando, por dentro del filo.
    canvas.drawRect(
      Rect.fromLTWH(9, 9, box.width - 18, box.height - 18),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = BoardPlan.ink.withValues(alpha: 0.2),
    );

    var y = pad + 4;
    _said.paint(canvas, Offset(pad, y));
    y += _said.height;

    if (!corrido) {
      y += 6;
      // La raya bajo el titular, que es lo que separa un bando de una notita.
      canvas.drawLine(
        Offset(pad, y),
        Offset(box.width - pad, y),
        Paint()..color = BoardPlan.ink.withValues(alpha: 0.28),
      );
      y += 7;
      _because.paint(canvas, Offset(pad, y));
      y += _because.height;
    }

    if (!corrido) {
      // El gráfico se ve desde el principio, clavada y todo. Antes salía sólo
      // al descolgar la nota, y era lo único que de verdad hacía falta ver: la
      // frase de arriba dice qué pasa y el gráfico dice de dónde sale, y las
      // dos juntas caben en el papel sin tener que tocarlo.
      final alto = chartRoom;
      if (alto > 0) {
        y += chartGap;
        canvas.save();
        canvas.translate(pad, y);
        _bars(canvas, Size(box.width - pad * 2, alto));
        canvas.restore();
      }
    }
    if (capa) canvas.restore();
  }

  /// Las barras: cada una es un número del que salió la frase de arriba, y las
  /// oscuras son las que la frase señala.
  void _bars(Canvas canvas, Size size) {
    final bars = notice.bars;
    if (bars.isEmpty) return;
    final rotula = notice.ticks.length == bars.length;
    final pie = rotula ? 13.0 : 0.0;
    final h = size.height - pie - 2;
    final hueco = bars.length > 14 ? 1.2 : 3.0;
    final w = (size.width - hueco * (bars.length - 1)) / bars.length;
    final flojo = Paint()..color = BoardPlan.ink.withValues(alpha: 0.22);
    final fuerte = Paint()..color = BoardPlan.ink.withValues(alpha: 0.82);
    for (var i = 0; i < bars.length; i++) {
      final on =
          notice.mark >= 0 && i >= notice.mark && i < notice.mark + notice.span;
      final alto = math.max(1.6, h * bars[i].clamp(0.0, 1.0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (w + hueco), 2 + h - alto, w, alto),
          Radius.circular(math.min(2.0, w / 2)),
        ),
        on ? fuerte : flojo,
      );
    }
    canvas.drawLine(
      Offset(0, h + 2.5),
      Offset(size.width, h + 2.5),
      Paint()..color = BoardPlan.ink.withValues(alpha: 0.2),
    );
    if (!rotula) return;
    for (var i = 0; i < bars.length; i++) {
      final text = notice.ticks[i];
      if (text.isEmpty) continue;
      final on =
          notice.mark >= 0 && i >= notice.mark && i < notice.mark + notice.span;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: BoardPlan.ink.withValues(alpha: on ? 0.8 : 0.45),
            fontSize: bars.length > 8 ? 6.4 : 7.6,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: w * (bars.length > 8 ? 1.0 : 1.6));
      tp.paint(canvas, Offset(i * (w + hueco) + (w - tp.width) / 2, h + 5));
    }
  }
}
