/// Una capa de la música de fondo, que suena en bucle.
///
/// En la web va por el audio de bajo nivel del navegador ([loop_track_web]):
/// el reproductor de siempre, el de una etiqueta de audio, deja un hueco al
/// volver a empezar —en el Safari del iPhone, un corte que se oye— y estas
/// capas duran de trece a dieciocho segundos, así que se oía cuatro veces por
/// minuto. Los archivos empalman bien; el que no empalmaba era el
/// reproductor. En el teléfono, el de siempre ([loop_track_io]).
library;

export 'loop_track_io.dart' if (dart.library.js_interop) 'loop_track_web.dart';
