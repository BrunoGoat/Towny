import 'package:flutter/foundation.dart';

/// Lo que se puede apagar del dibujo para ver qué pesa, y lo que cuesta cada
/// fotograma. Se toca desde Ajustes → Desarrollo → Rendimiento.
///
/// No se guarda: es para probar en el momento, en el aparato donde va lento,
/// y al volver a abrir la app todo está como siempre.
class RenderDebug extends ChangeNotifier {
  RenderDebug._();
  static final RenderDebug instance = RenderDebug._();

  /// El contador de fotogramas, arriba a la izquierda.
  bool showFps = false;

  /// Las partes del modo de calidad máxima, cada una por separado.
  bool shadows = true, grade = true, bloom = true, rays = true;

  /// Y lo que anda por el pueblo.
  bool folk = true, water = true;

  void set(void Function(RenderDebug d) cambio) {
    cambio(this);
    notifyListeners();
  }

  /// Lo que tardó en armarse cada fotograma del pueblo, en microsegundos,
  /// desde la última vez que se miró ([drain]), y cuántas caras pintó el
  /// último.
  final List<int> _pinta = [];
  int faces = 0;

  void painted(int micros, int caras) {
    if (!showFps) return;
    if (_pinta.length < 600) _pinta.add(micros);
    faces = caras;
  }

  List<int> drain() {
    final out = [..._pinta];
    _pinta.clear();
    return out;
  }
}
