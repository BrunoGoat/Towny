import 'package:audioplayers/audioplayers.dart';

/// Una capa en bucle con el reproductor de siempre. Ver `loop_track.dart`.
class LoopTrack {
  final AudioPlayer _p = AudioPlayer();

  /// Carga [name], de `assets/sfx/`, y pide que suene en cuanto se pueda.
  Future<void> load(String name) async {
    await _p.setReleaseMode(ReleaseMode.loop);
    await _p.setVolume(0);
    await _p.setSource(AssetSource('sfx/$name'));
    play();
  }

  void play() {
    _p.resume().catchError((Object _) {});
  }

  void pause() {
    _p.pause().catchError((Object _) {});
  }

  void setVolume(double v) {
    _p.setVolume(v).catchError((Object _) {});
  }

  void dispose() {
    _p.stop().catchError((Object _) {});
    _p.dispose().catchError((Object _) {});
  }
}
