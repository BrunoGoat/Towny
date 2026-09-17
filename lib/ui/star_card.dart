import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/constellations.dart';
import '../model/appearance.dart';
import 'style.dart';

/// Lo que dice el cielo cuando tocás una constelación.
///
/// **Diez maneras de decirlo, para elegir una.** Es como se eligieron los cinco
/// temas de música y los quince velos de la hoja del hábito: escritas todas,
/// probadas de verdad en el teléfono a distintas horas, y de ahí sale cuál se
/// queda. Las otras nueve se borran, y con ellas su fila en los ajustes — un
/// ajuste que ya nadie va a tocar es una fila más que leer cada vez.
///
/// Lo que no cambia entre las diez, porque es el encargo:
///
///  * **Llevan el nombre.** Sin él, unas estrellas unidas por rayas no son
///    Casiopea. El rótulo dejó de estar clavado sobre el cielo justamente para
///    que el nombre llegue acá, cuando alguien preguntó tocando.
///  * **Son ligeras.** Esto aparece encima de un pueblo al anochecer y se va
///    solo a los cinco segundos. Nada de esto puede pesar como una hoja de
///    ajustes: lo que hay debajo es lo que se estaba mirando.
///  * **No felicitan.** Tocar una constelación no es un logro y no desbloquea
///    nada. Es mirar para arriba.
class StarCard extends StatelessWidget {
  const StarCard({
    super.key,
    required this.constellation,
    required this.theme,
    this.design,
  });

  final Constellation constellation;
  final UiTheme theme;

  /// Cuál de las diez. Nula quiere decir la que esté elegida en los ajustes.
  final int? design;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final c = constellation;
    final n = design ?? Appearance.instance.starCard;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
      child: switch (n) {
        1 => _uno(t, c),
        2 => _dos(t, c),
        3 => _tres(t, c),
        4 => _cuatro(t, c),
        5 => _cinco(t, c),
        6 => _seis(t, c),
        7 => _siete(t, c),
        8 => _ocho(t, c),
        9 => _nueve(t, c),
        _ => _diez(t, c),
      },
    );
  }

  // 1 · La de la casa. El mismo esqueleto que las hojas nuevas —un rótulo
  // chico en versalitas, el nombre, y el texto flojo debajo—, encogido a lo
  // que cabe encima de un pueblo.
  Widget _uno(UiTheme t, Constellation c) => Frosted(
    theme: t,
    radius: 22,
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EN EL CIELO DE ESTA NOCHE',
          style: t.label.copyWith(fontSize: 8.5),
        ),
        const SizedBox(height: 8),
        Text(c.name, style: t.title.copyWith(fontSize: 19)),
        const SizedBox(height: 6),
        Text(c.blurb, style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.45)),
      ],
    ),
  );

  // 2 · El nombre, un filete de pelo, y el texto. Sin rótulo: el nombre ya dice
  // de qué va, y una línea menos es una línea menos.
  Widget _dos(UiTheme t, Constellation c) => Frosted(
    theme: t,
    radius: 20,
    padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c.name.toUpperCase(),
          style: t.label.copyWith(
            fontSize: 11.5,
            letterSpacing: 3.0,
            color: t.fg,
          ),
        ),
        const SizedBox(height: 9),
        Container(width: 26, height: 1, color: t.fg.withValues(alpha: 0.22)),
        const SizedBox(height: 9),
        Text(c.blurb, style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.45)),
      ],
    ),
  );

  // 3 · Sin panel ninguno: el texto sobre el cielo, con el aliento detrás que
  // usa la hoja del hábito. Es la más ambiental de las diez — no hay tarjeta,
  // hay algo escrito en el aire.
  Widget _tres(UiTheme t, Constellation c) {
    // El aliento sale del material de los paneles y no del color del
    // horizonte, que es lo que se acaba de corregir en toda la interfaz: el
    // horizonte es lo que tienen detrás las casas, no lo que hay detrás de un
    // texto puesto sobre la escena. Y así este papel cruza de claro a oscuro
    // en el mismo minuto que cruzan los rótulos de arriba, en vez de llevar
    // su propio reloj.
    final atras = t.dark ? const Color(0xFF14131A) : const Color(0xFFFBF7ED);
    final aliento = [
      Shadow(color: atras.withValues(alpha: 0.95), blurRadius: 12),
      Shadow(color: atras.withValues(alpha: 0.75), blurRadius: 26),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            c.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: t.label.copyWith(
              fontSize: 11,
              letterSpacing: 3.4,
              color: t.fg,
              shadows: aliento,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            c.blurb,
            textAlign: TextAlign.center,
            style: t.bodySoft.copyWith(
              fontSize: 12.5,
              height: 1.5,
              shadows: aliento,
            ),
          ),
        ],
      ),
    );
  }

  // 4 · Con la figura dibujada al lado, de verdad: las mismas estrellas y los
  // mismos trazos que hay arriba, a tamaño de sello. Es la única que contesta
  // «¿cuál de todas?» sin que haya que buscarla en el cielo.
  Widget _cuatro(UiTheme t, Constellation c) => Frosted(
    theme: t,
    radius: 20,
    padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: CustomPaint(painter: _Figura(c, t.fg)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name, style: t.title.copyWith(fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                c.blurb,
                style: t.bodySoft.copyWith(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // 5 · Al revés: la frase manda y el nombre va debajo y chiquito, como el pie
  // de una foto. Lo que se lee primero es lo que se cuenta, no cómo se llama.
  Widget _cinco(UiTheme t, Constellation c) => Frosted(
    theme: t,
    radius: 20,
    padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(c.blurb, style: t.body.copyWith(fontSize: 13.5, height: 1.45)),
        const SizedBox(height: 10),
        Text(
          '${c.name.toUpperCase()}  ·  ${c.latin.toUpperCase()}',
          style: t.label.copyWith(fontSize: 8.5, letterSpacing: 1.8),
        ),
      ],
    ),
  );

  // 6 · Un filete del color de la hora a la izquierda y nada más. Es el gesto
  // más sobrio que hay para decir «esto es una cosa»: una raya y aire.
  Widget _seis(UiTheme t, Constellation c) => Frosted(
    theme: t,
    radius: 18,
    padding: EdgeInsets.zero,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 2, color: t.accent.withValues(alpha: 0.75)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 18, 15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: t.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    c.blurb,
                    style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // 7 · Cartela de museo: todo centrado, el nombre muy espaciado y el latín
  // debajo en cursiva. La más formal, y la que más se parece a mirar algo que
  // lleva ahí dos mil años.
  Widget _siete(UiTheme t, Constellation c) => Frosted(
    theme: t,
    radius: 22,
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          c.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: t.label.copyWith(
            fontSize: 12,
            letterSpacing: 4.0,
            color: t.fg,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          c.latin,
          style: t.bodySoft.copyWith(
            fontSize: 10.5,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 11),
        Text(
          c.blurb,
          textAlign: TextAlign.center,
          style: t.bodySoft.copyWith(fontSize: 12.5, height: 1.5),
        ),
      ],
    ),
  );

  // 8 · Sobre papel, y no sobre vidrio. El libro de las leyendas de este pueblo
  // está en papiro: si el cielo hablara por escrito, hablaría en el mismo papel
  // en que está escrito todo lo demás que este pueblo cuenta.
  Widget _ocho(UiTheme t, Constellation c) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 17),
    decoration: BoxDecoration(
      color: t.dark ? const Color(0xFFE8DCC0) : const Color(0xFFF4EBD6),
      borderRadius: BorderRadius.circular(6),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c.name,
          style: const TextStyle(
            color: Color(0xFF3B2F1C),
            fontFamily: 'RobotoSlab',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          c.blurb,
          style: const TextStyle(
            color: Color(0xFF5A4A31),
            fontFamily: 'RobotoSlab',
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    ),
  );

  // 9 · Como una cita: la frase primero, y el nombre al pie precedido de una
  // raya. Lo que dice el cielo, y quién lo dijo.
  Widget _nueve(UiTheme t, Constellation c) => Frosted(
    theme: t,
    radius: 20,
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          c.blurb,
          style: t.bodySoft.copyWith(
            fontSize: 13,
            height: 1.5,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          '— ${c.name}',
          style: t.body.copyWith(fontSize: 12, color: t.accent),
        ),
      ],
    ),
  );

  // 10 · La más chica que puede seguir llevando el nombre: una sola línea con
  // el nombre en versalitas, un punto medio, y la frase seguida. Si lo que se
  // busca es que pase desapercibido, esto es el suelo.
  Widget _diez(UiTheme t, Constellation c) => Frosted(
    theme: t,
    radius: 26,
    padding: const EdgeInsets.fromLTRB(18, 11, 18, 12),
    child: RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: '${c.name.toUpperCase()}  ',
            style: t.label.copyWith(
              fontSize: 10,
              letterSpacing: 2.2,
              color: t.fg,
            ),
          ),
          TextSpan(
            text: c.blurb,
            style: t.bodySoft.copyWith(fontSize: 12, height: 1.45),
          ),
        ],
      ),
    ),
  );
}

/// La figura, a tamaño de sello: las mismas estrellas y los mismos trazos que
/// hay en el cielo, encajados en el cuadrado que se le dé.
///
/// Se dibuja de la forma real —[Constellation.shape], que son los ángulos
/// entre estrellas— y no de un icono a mano: si el cielo cambia, esto cambia
/// con él, y nadie tiene que acordarse de venir a repintarlo.
class _Figura extends CustomPainter {
  const _Figura(this.c, this.ink);
  final Constellation c;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final forma = c.shape;
    if (forma.isEmpty) return;
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    for (final (x, y) in forma) {
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
    final ancho = math.max(x1 - x0, 1e-6), alto = math.max(y1 - y0, 1e-6);
    // El mismo factor en los dos ejes: estirar para llenar el cuadrado sería
    // dibujar otra constelación.
    final k = math.min((size.width - 8) / ancho, (size.height - 8) / alto);
    final cx = size.width / 2, cy = size.height / 2;
    Offset at(int i) {
      final (x, y) = forma[i];
      return Offset(
        cx + (x - (x0 + x1) / 2) * k,
        // Al norte es hacia arriba, y en pantalla la ye crece hacia abajo.
        cy - (y - (y0 + y1) / 2) * k,
      );
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..color = ink.withValues(alpha: 0.30);
    for (var i = 0; i + 1 < c.lines.length; i += 2) {
      canvas.drawLine(at(c.lines[i]), at(c.lines[i + 1]), line);
    }
    final dot = Paint();
    for (var i = 0; i < forma.length; i++) {
      final brillo = ((3.2 - c.stars[i].mag) / 4.6).clamp(0.22, 1.0);
      dot.color = ink.withValues(alpha: 0.45 + 0.45 * brillo);
      canvas.drawCircle(at(i), 0.9 + 1.2 * brillo, dot);
    }
  }

  @override
  bool shouldRepaint(_Figura old) => old.c.id != c.id || old.ink != ink;
}
