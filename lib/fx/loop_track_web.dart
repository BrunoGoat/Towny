import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

/// Uno para todas las capas: así arrancan y se paran juntas.
web.AudioContext? _contexto;
web.AudioContext get _ac => _contexto ??= web.AudioContext();

/// Una capa en bucle por el audio de bajo nivel del navegador, que repite el
/// mismo trozo de sonido sin un solo hueco. Ver `loop_track.dart`.
class LoopTrack {
  web.AudioBuffer? _buffer;
  web.AudioBufferSourceNode? _fuente;
  web.GainNode? _volumen;
  double _nivel = 0;
  bool _quiere = false;

  /// Dónde iba al pararla, para seguir desde ahí y no desde el principio.
  double _desde = 0;
  double _empezo = 0;

  /// Carga [name], de `assets/sfx/`, y pide que suene en cuanto se pueda.
  Future<void> load(String name) async {
    _quiere = true;
    final data = await rootBundle.load('assets/sfx/$name');
    // Una copia propia: el navegador se queda con lo que decodifica.
    final bytes = Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    _buffer = await _ac.decodeAudioData(bytes.buffer.toJS).toDart;
    _volumen = _ac.createGain()..connect(_ac.destination);
    _volumen!.gain.value = _nivel;
    if (_quiere) play();
  }

  void play() {
    _quiere = true;
    // Hasta que la persona no toca la página, el navegador lo tiene en
    // espera; el primer toque vuelve a pedir que suene, y ahí sí.
    if (_ac.state == 'suspended') _ac.resume();
    final buffer = _buffer, volumen = _volumen;
    if (_fuente != null || buffer == null || volumen == null) return;
    final f = _ac.createBufferSource()
      ..buffer = buffer
      ..loop = true;
    f.connect(volumen);
    f.start(0, _desde);
    _empezo = _ac.currentTime - _desde;
    _fuente = f;
  }

  void pause() {
    _quiere = false;
    final f = _fuente, buffer = _buffer;
    if (f == null || buffer == null) return;
    _desde = (_ac.currentTime - _empezo) % buffer.duration;
    f.stop();
    f.disconnect();
    _fuente = null;
  }

  void setVolume(double v) {
    _nivel = v;
    _volumen?.gain.value = v;
  }

  void dispose() {
    pause();
    _volumen?.disconnect();
    _volumen = null;
  }
}
