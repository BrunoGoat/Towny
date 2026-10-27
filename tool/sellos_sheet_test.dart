import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:towny/ui/habit_sigil.dart';

/// Muestras de cómo marcar, al fundar un pueblo, las clases de pueblo que ya
/// usa el valle: cada variante con uno, dos y cuatro pueblos de esa clase.
///
///   flutter test tool/sellos_sheet_test.dart --dart-define=OUT=/tmp/sellos
const _glass = Color(0xFF14110D);
const _cream = Color(0xFFF6EFE1);
const _gold = Color(0xFFEBC07A);
const _disc = Color(0x40000000);

const _marcas = ['book', 'run', 'lotus', 'broom'];

/// Una forma de marcar: recibe el lado del sello, el sello de la clase y las
/// marcas de los pueblos que la usan.
typedef _Estilo = Widget Function(double lado, Widget sello, List<String> m);

Widget _sello(double lado, {double apagado = 1, Color? borde}) => Container(
  width: lado,
  height: lado,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: _disc,
    border: Border.all(color: borde ?? _cream.withValues(alpha: 0.22)),
  ),
  child: Opacity(
    opacity: apagado,
    child: HabitSigil(
      symbol: 'wheat',
      color: _cream.withValues(alpha: 0.8),
      size: lado * 0.44,
    ),
  ),
);

Widget _disco(
  double d,
  Widget dentro, {
  required Color fondo,
  Color? borde,
  bool sombra = true,
}) => Container(
  width: d,
  height: d,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: fondo,
    border: borde == null ? null : Border.all(color: borde),
    boxShadow: sombra
        ? const [BoxShadow(color: Color(0x59000000), blurRadius: 5)]
        : null,
  ),
  child: dentro,
);

/// En el arco de arriba, de derecha a izquierda; de tres en adelante el
/// último dice cuántos más.
Widget _enArco(
  double lado,
  Widget sello,
  List<String> m,
  Widget Function(Widget dentro) chapa,
  Color tinta,
  double chico,
) {
  const angulos = [-40.0, -90.0, -140.0];
  final caben = m.length <= 3 ? m.length : 2;
  final resto = m.length - caben;
  Widget en(int i, Widget w) {
    final a = angulos[i] * math.pi / 180;
    final r = lado / 2;
    return Positioned(
      left: r + math.cos(a) * r - chico / 2,
      top: r + math.sin(a) * r - chico / 2,
      child: w,
    );
  }

  return SizedBox(
    width: lado,
    height: lado,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        sello,
        for (var i = 0; i < caben; i++)
          en(
            i,
            chapa(HabitSigil(symbol: m[i], color: tinta, size: chico * 0.58)),
          ),
        if (resto > 0)
          en(
            caben,
            chapa(
              Text(
                '+$resto',
                style: TextStyle(
                  fontSize: chico * 0.42,
                  fontWeight: FontWeight.w700,
                  color: tinta,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Una pastilla debajo del sello, con las marcas en fila.
Widget _pastilla(
  double lado,
  Widget sello,
  List<String> m, {
  required Color fondo,
  required Color tinta,
  Color? borde,
  bool numero = false,
}) {
  final h = lado * 0.36;
  final hijos = numero
      ? [
          HabitSigil(symbol: m.first, color: tinta, size: h * 0.6),
          if (m.length > 1) ...[
            const SizedBox(width: 3),
            Text(
              '×${m.length}',
              style: TextStyle(
                fontSize: h * 0.5,
                fontWeight: FontWeight.w700,
                color: tinta,
                height: 1,
              ),
            ),
          ],
        ]
      : [
          for (final (i, s) in m.take(3).indexed) ...[
            if (i > 0) const SizedBox(width: 2),
            HabitSigil(symbol: s, color: tinta, size: h * 0.6),
          ],
          if (m.length > 3) ...[
            const SizedBox(width: 2),
            Text(
              '+${m.length - 3}',
              style: TextStyle(
                fontSize: h * 0.48,
                fontWeight: FontWeight.w700,
                color: tinta,
                height: 1,
              ),
            ),
          ],
        ];
  return SizedBox(
    width: lado,
    height: lado,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        sello,
        Positioned(
          bottom: -h * 0.45,
          child: Container(
            height: h,
            padding: EdgeInsets.symmetric(horizontal: h * 0.3),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(h / 2),
              border: borde == null ? null : Border.all(color: borde),
              boxShadow: const [
                BoxShadow(color: Color(0x59000000), blurRadius: 5),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: hijos),
          ),
        ),
      ],
    ),
  );
}

/// Un anillo dorado partido en tantos tramos como pueblos, por fuera del
/// sello.
class _Anillo extends CustomPainter {
  const _Anillo(this.n, this.color);
  final int n;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 + 4;
    final c = size.center(Offset.zero);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const hueco = 0.35;
    final paso = 2 * math.pi / math.max(n, 1);
    for (var i = 0; i < n; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2 + i * paso + (n > 1 ? hueco / 2 : 0),
        n > 1 ? paso - hueco : 2 * math.pi,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_Anillo o) => o.n != n;
}

final List<(String, _Estilo)> _estilos = [
  (
    'A · Vidrio y dorado (el actual)',
    (l, s, m) => _enArco(
      l,
      s,
      m,
      (w) => _disco(
        l * 0.4,
        w,
        fondo: _glass.withValues(alpha: 0.92),
        borde: _gold.withValues(alpha: 0.85),
      ),
      _gold,
      l * 0.4,
    ),
  ),
  (
    'B · Dorado lleno, marca oscura',
    (l, s, m) => _enArco(
      l,
      s,
      m,
      (w) => _disco(l * 0.4, w, fondo: _gold, borde: _glass),
      _glass,
      l * 0.4,
    ),
  ),
  (
    'C · Vidrio y crema',
    (l, s, m) => _enArco(
      l,
      s,
      m,
      (w) => _disco(
        l * 0.4,
        w,
        fondo: _glass.withValues(alpha: 0.92),
        borde: _cream.withValues(alpha: 0.6),
      ),
      _cream,
      l * 0.4,
    ),
  ),
  (
    'D · Vidrio sin borde, dorado',
    (l, s, m) => _enArco(
      l,
      s,
      m,
      (w) => _disco(l * 0.4, w, fondo: _glass.withValues(alpha: 0.85)),
      _gold,
      l * 0.4,
    ),
  ),
  (
    'E · Sólo la marca dorada, sin disco',
    (l, s, m) => _enArco(
      l,
      s,
      m,
      (w) => SizedBox(
        width: l * 0.4,
        height: l * 0.4,
        child: Center(child: w),
      ),
      _gold,
      l * 0.4,
    ),
  ),
  (
    'F · Puntos dorados, uno por pueblo',
    (l, s, m) => SizedBox(
      width: l,
      height: l,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          s,
          Positioned(
            bottom: -l * 0.2,
            child: Row(
              children: [
                for (var i = 0; i < m.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  ),
  (
    'G · Pastilla de vidrio debajo, marcas en fila',
    (l, s, m) => _pastilla(
      l,
      s,
      m,
      fondo: _glass.withValues(alpha: 0.92),
      tinta: _gold,
      borde: _gold.withValues(alpha: 0.7),
    ),
  ),
  (
    'H · Pastilla dorada debajo, marcas oscuras',
    (l, s, m) => _pastilla(l, s, m, fondo: _gold, tinta: _glass),
  ),
  (
    'I · Pastilla con una marca y cuántos',
    (l, s, m) => _pastilla(
      l,
      s,
      m,
      fondo: _glass.withValues(alpha: 0.92),
      tinta: _gold,
      borde: _gold.withValues(alpha: 0.7),
      numero: true,
    ),
  ),
  (
    'J · Anillo dorado partido, un tramo por pueblo',
    (l, s, m) => SizedBox(
      width: l,
      height: l,
      child: CustomPaint(foregroundPainter: _Anillo(m.length, _gold), child: s),
    ),
  ),
  (
    'K · Anillo partido y la primera marca encima',
    (l, s, m) => SizedBox(
      width: l,
      height: l,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            foregroundPainter: _Anillo(m.length, _gold.withValues(alpha: 0.8)),
            child: s,
          ),
          Positioned(
            right: -l * 0.12,
            top: -l * 0.12,
            child: _disco(
              l * 0.4,
              HabitSigil(symbol: m.first, color: _gold, size: l * 0.23),
              fondo: _glass.withValues(alpha: 0.92),
              borde: _gold.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    ),
  ),
  (
    'L · Sello apagado y marcas dentro, abajo',
    (l, s, m) => Container(
      width: l,
      height: l,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _disc,
        border: Border.all(color: _gold.withValues(alpha: 0.45)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(0, -l * 0.1),
            child: HabitSigil(
              symbol: 'wheat',
              color: _cream.withValues(alpha: 0.35),
              size: l * 0.4,
            ),
          ),
          Positioned(
            bottom: l * 0.1,
            child: Row(
              children: [
                for (final x in m.take(3))
                  HabitSigil(symbol: x, color: _gold, size: l * 0.18),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
  (
    'M · Cinta arriba con las marcas',
    (l, s, m) => SizedBox(
      width: l,
      height: l,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          s,
          Positioned(
            top: -l * 0.18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(3),
                boxShadow: const [
                  BoxShadow(color: Color(0x59000000), blurRadius: 4),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final x in m.take(3))
                    HabitSigil(symbol: x, color: _glass, size: l * 0.2),
                  if (m.length > 3)
                    Text(
                      '+${m.length - 3}',
                      style: TextStyle(
                        fontSize: l * 0.17,
                        fontWeight: FontWeight.w700,
                        color: _glass,
                        height: 1,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
  (
    'N · Crema translúcido, marca dorada',
    (l, s, m) => _enArco(
      l,
      s,
      m,
      (w) => _disco(
        l * 0.4,
        w,
        fondo: _cream.withValues(alpha: 0.18),
        borde: _gold.withValues(alpha: 0.6),
      ),
      _gold,
      l * 0.4,
    ),
  ),
  (
    'O · Borde del sello dorado y número',
    (l, s, m) => SizedBox(
      width: l,
      height: l,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _sello(l, borde: _gold.withValues(alpha: 0.7)),
          Positioned(
            right: -l * 0.08,
            top: -l * 0.08,
            child: _disco(
              l * 0.36,
              Text(
                '${m.length}',
                style: TextStyle(
                  fontSize: l * 0.2,
                  fontWeight: FontWeight.w700,
                  color: _glass,
                  height: 1,
                ),
              ),
              fondo: _gold,
            ),
          ),
        ],
      ),
    ),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('las muestras de sellos', (tester) async {
    const out = String.fromEnvironment('OUT', defaultValue: '/tmp/sellos');
    Directory(out).createSync(recursive: true);
    await tester.runAsync(() async {
      final sdk =
          Platform.environment['FLUTTER_ROOT'] ??
          File(
            Platform.resolvedExecutable,
          ).parent.parent.parent.parent.parent.path;
      final l = FontLoader('Roboto');
      for (final f in [
        '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        '$sdk/bin/cache/artifacts/material_fonts/Roboto-Bold.ttf',
      ]) {
        if (File(f).existsSync()) {
          l.addFont(
            Future.value(File(f).readAsBytesSync().buffer.asByteData()),
          );
        }
      }
      await l.load();
    });
    const ancho = 420.0, fila = 108.0;
    final alto = 20 + _estilos.length * fila;
    tester.view.physicalSize = Size(ancho * 2, alto * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    const lado = 52.0;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto'),
        home: RepaintBoundary(
          key: key,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF5E8540), Color(0xFF3F5E2A)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (nombre, estilo) in _estilos)
                    SizedBox(
                      height: fila,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              for (final n in [1, 2, 4]) ...[
                                const SizedBox(width: 24),
                                estilo(
                                  lado,
                                  _sello(lado),
                                  _marcas.take(n).toList(),
                                ),
                                const SizedBox(width: 24),
                              ],
                              const SizedBox(width: 24),
                              // Y una sin usar, para comparar.
                              _sello(lado),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final img = await b.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/sellos.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
