/// Qué hacer al conectarse, cuando el teléfono y la nube pueden no coincidir.
///
/// La regla de fondo es la que se pidió: lo que se hizo sin conexión vale, y
/// el cambio más reciente manda. Pero comparar «la nube» con «ahora» no
/// alcanza, por dos casos en que eso pierde un valle entero:
///
/// - **Un teléfono nuevo, o con los datos borrados.** Está vacío *ahora*, y
///   ahora es más reciente que cualquier cosa de la nube: subiría el vacío
///   encima de trescientas piezas.
/// - **Dos teléfonos sin conexión.** Cada uno pone sus piezas, y el que se
///   conecta segundo pisa al primero sin que nadie se entere.
///
/// Por eso se miran dos fechas del teléfono —cuándo cambió algo acá y cuándo
/// se sincronizó por última vez ([LocalChanges])— contra la de la nube. Y la
/// copia que pierde nunca se tira: se guarda en el teléfono.
library;

enum SyncAction {
  /// Las dos copias son la misma: no hay nada que hacer.
  none,

  /// Lo del teléfono es lo nuevo: se sube.
  upload,

  /// Lo de la nube es lo nuevo: se baja.
  download,
}

class SyncPlan {
  const SyncPlan(this.action, {this.backup = false, required this.why});

  final SyncAction action;

  /// Si la copia que se pisa tenía algo que la otra no: entonces se guarda
  /// antes en el teléfono, por si acaso.
  final bool backup;

  /// Por qué, para los tests y para quien lea esto.
  final String why;

  @override
  String toString() => '$action${backup ? ' (con copia)' : ''}: $why';
}

/// Qué hacer, sabiendo:
///
/// - [localChanged]: cuándo cambió algo en este teléfono (null: nunca).
/// - [lastSynced]: cuándo coincidieron por última vez (null: nunca).
/// - [remoteChanged]: cuándo cambió lo que hay en la nube, con el reloj del
///   teléfono que lo subió (null: la nube está vacía).
/// - [localPieces], [remotePieces]: cuántas piezas tiene cada copia.
SyncPlan decide({
  required DateTime? localChanged,
  required DateTime? lastSynced,
  required DateTime? remoteChanged,
  required int localPieces,
  required int remotePieces,
}) {
  if (remoteChanged == null && remotePieces == 0) {
    if (localChanged == null && localPieces == 0) {
      return const SyncPlan(SyncAction.none, why: 'no hay nada en ningún lado');
    }
    return const SyncPlan(SyncAction.upload, why: 'la nube está vacía');
  }

  // Un valle vacío no pisa nunca a uno con piezas, diga lo que diga el reloj:
  // es el teléfono recién instalado, o el que se borró.
  if (localPieces == 0 && remotePieces > 0) {
    return SyncPlan(
      SyncAction.download,
      backup: localChanged != null,
      why: 'el teléfono está vacío y la nube no',
    );
  }

  final aqui =
      localChanged != null &&
      (lastSynced == null || localChanged.isAfter(lastSynced));
  final alla =
      remoteChanged != null &&
      (lastSynced == null || remoteChanged.isAfter(lastSynced));

  if (!aqui && !alla) {
    return const SyncPlan(SyncAction.none, why: 'nada cambió desde la última');
  }
  if (aqui && !alla) {
    return const SyncPlan(SyncAction.upload, why: 'sólo cambió el teléfono');
  }
  if (!aqui && alla) {
    return const SyncPlan(SyncAction.download, why: 'sólo cambió la nube');
  }

  // Cambiaron los dos: otro teléfono subió algo mientras éste trabajaba sin
  // conexión. Gana el cambio más reciente, y el otro se guarda.
  if (!remoteChanged!.isAfter(localChanged!)) {
    return const SyncPlan(
      SyncAction.upload,
      backup: true,
      why: 'cambiaron los dos y el teléfono es lo más reciente',
    );
  }
  return const SyncPlan(
    SyncAction.download,
    backup: true,
    why: 'cambiaron los dos y la nube es lo más reciente',
  );
}
