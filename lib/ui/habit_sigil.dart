import 'package:flutter/material.dart';

import '../data/symbols.dart';
import '../engine/sigils.dart';

/// The mark of a habit, drawn.
///
/// Every glyph is authored by hand inside a hundred-by-hundred box, out of the
/// same vocabulary the town is: straight runs, squared masses, a few honest
/// curves. That is the whole point — the mark over a town has to look like it
/// came from the same place the town did, and no font on any phone was ever
/// going to do that.
class HabitSigil extends StatelessWidget {
  const HabitSigil({
    super.key,
    required this.symbol,
    required this.color,
    this.size = 22,
  });

  final String symbol;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: habitSymbolNames[resolveHabitSymbol(symbol)],
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _SigilPainter(resolveHabitSymbol(symbol), color),
        ),
      ),
    );
  }
}

class _SigilPainter extends CustomPainter {
  const _SigilPainter(this.symbol, this.color);
  final String symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    HabitSigils.draw(
      canvas,
      Rect.fromLTWH(0, 0, size.width, size.height),
      symbol,
      color,
    );
  }

  @override
  bool shouldRepaint(_SigilPainter old) =>
      old.symbol != symbol || old.color != color;
}
