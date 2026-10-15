import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../engine/render_debug.dart';

/// El contador de rendimiento: cuántos fotogramas por segundo, cuánto tarda
/// cada uno y cuánto de eso es armar el pueblo. Arriba a la izquierda, encima
/// de todo, cuando se enciende en Ajustes → Desarrollo.
///
/// - **fps**: los fotogramas de verdad del último segundo.
/// - **cuadro**: lo que tardó en armarse cada fotograma, la mediana y el
///   peor del último segundo (el peor es el tirón que se siente).
/// - **gpu**: lo que tardó en dibujarse. En la web sale casi siempre bajo
///   aunque no lo sea: el navegador lo dibuja después, por su cuenta.
/// - **pueblo**: lo que tardó el pintor del pueblo, y cuántas caras pintó.
class PerfOverlay extends StatefulWidget {
  const PerfOverlay({super.key});

  @override
  State<PerfOverlay> createState() => _PerfOverlayState();
}

class _PerfOverlayState extends State<PerfOverlay> {
  final _cuadros = <ui.FrameTiming>[];
  Timer? _cada;
  String _texto = '…';

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_llegan);
    _cada = Timer.periodic(const Duration(seconds: 1), (_) => _resume());
  }

  void _llegan(List<ui.FrameTiming> ts) => _cuadros.addAll(ts);

  void _resume() {
    if (!mounted) return;
    double ms(Duration d) => d.inMicroseconds / 1000;
    final n = _cuadros.length;
    String linea;
    if (n == 0) {
      linea = '0 fps';
    } else {
      final arma = [for (final t in _cuadros) ms(t.buildDuration)]..sort();
      final gpu = [for (final t in _cuadros) ms(t.rasterDuration)]..sort();
      linea =
          '$n fps\n'
          'cuadro ${arma[n ~/ 2].toStringAsFixed(1)} ms '
          '(peor ${arma.last.toStringAsFixed(0)})\n'
          'gpu ${gpu[n ~/ 2].toStringAsFixed(1)} ms';
    }
    final pueblo = RenderDebug.instance.drain()..sort();
    if (pueblo.isNotEmpty) {
      final p = pueblo[pueblo.length ~/ 2] / 1000;
      linea +=
          '\npueblo ${p.toStringAsFixed(1)} ms · '
          '${RenderDebug.instance.faces} caras';
    }
    _cuadros.clear();
    setState(() => _texto = linea);
  }

  @override
  void dispose() {
    _cada?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_llegan);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          margin: const EdgeInsets.only(left: 8, top: 56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _texto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              height: 1.3,
              fontFamily: 'monospace',
              fontFamilyFallback: ['Roboto'],
              decoration: TextDecoration.none,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );
}
