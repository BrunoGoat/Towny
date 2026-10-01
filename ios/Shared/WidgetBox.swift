import Foundation

/// Lo único que el cuadrito de la pantalla de inicio guarda, y lo único que la
/// app le deja escrito.
///
/// Es el hermano de `WidgetBox.kt`, y guarda lo mismo con los mismos nombres a
/// propósito: el protocolo entre la app y el widget es el mismo en los dos
/// teléfonos, así que leer uno es leer el otro.
///
/// **Por qué un grupo de aplicaciones y no el guardado de la app.** En iOS el
/// widget no es un trozo de la app: es otro proceso, con su propia caja de
/// arena, y no ve nada de lo que la app escriba en la suya. Lo único que
/// comparten es el contenedor del grupo, y por eso todo lo de aquí cuelga de
/// él. (En Android el motivo era el contrario —viven en el mismo proceso y no
/// pueden abrir dos veces el mismo almacén— y la solución acabó siendo la
/// misma: una caja aparte que no es la del pueblo.)
///
/// Dentro hay dos cosas, y ninguna de las dos la escriben los dos:
///
///  - **el resumen**, que escribe la app y lee el widget, y
///  - **el buzón**, que escribe el widget y vacía la app.
///
/// Eso es lo que hace que esto no necesite candados.
enum WidgetBox {
    /// El grupo. Tiene que estar escrito igual en las dos capacidades —la de
    /// la app y la del widget— o cada uno escribirá en su propia caja y el
    /// cuadrito saldrá siempre vacío.
    static let group = "group.com.lamuralla.towny"

    private static let kHabits = "habits"
    private static let kInbox = "inbox"
    private static let kNext = "next"
    private static let kArmed = "armed"
    private static let kArmedAt = "armedAt"

    /// Cuánto dura el «¿seguro?» de una fila, en milisegundos.
    ///
    /// Existe porque dentro de la app una pieza no se pone con un toque: se
    /// pone manteniendo el dedo hasta que se cierra un anillo, y eso es a
    /// propósito —hace que poner una piedra sea una decisión y no un temblor—.
    /// En la pantalla de inicio no hay manera de mantener el dedo, así que el
    /// equivalente son dos toques: el primero pregunta y el segundo pone. Un
    /// roce en el bolsillo no construye nada.
    static let armMs: Int64 = 5000

    static var defaults: UserDefaults? { UserDefaults(suiteName: group) }

    // ------------------------------------------------------------ el resumen

    /// Una fila del resumen: un pueblo, lo que lleva hoy y de qué día es esa
    /// cuenta.
    struct Row: Codable, Identifiable, Equatable {
        var id: String
        var name: String
        var today: Int
        var day: Int
        var resting: Bool
    }

    static func habits() -> [Row] {
        guard let raw = defaults?.string(forKey: kHabits),
              let data = raw.data(using: .utf8),
              let rows = try? JSONDecoder().decode([Row].self, from: data)
        else { return [] }
        return rows
    }

    static func putHabits(_ rows: [Row]) {
        guard let data = try? JSONEncoder().encode(rows),
              let raw = String(data: data, encoding: .utf8) else { return }
        defaults?.set(raw, forKey: kHabits)
    }

    /// Qué día es hoy, como un número.
    ///
    /// El mismo que calcula `dayKey` del lado del Dart, y tiene que seguir
    /// siéndolo: el resumen trae escrito de qué día es su cuenta, y el widget
    /// la da por buena sólo si coincide con éste. Sin eso, un cuadrito que
    /// nadie refresca desde anoche enseña a las nueve de la mañana las tres
    /// piezas de ayer, que es la manera más tonta de mentir.
    static func dayKey(_ when: Date = Date()) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: when)
        return (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    /// Le suma una a la cuenta de hoy de ese pueblo.
    ///
    /// Es un adelanto: la pieza de verdad la pone la app cuando alguien la
    /// abre. Pero la cuenta de la fila tiene que subir **ahora**, porque lo
    /// que contesta es «¿cuántas llevo hoy?» y la respuesta ya cambió. Cuando
    /// la app publique el resumen de verdad, este número queda pisado por el
    /// suyo, que es el bueno.
    ///
    /// Y si la fila venía de ayer, la cuenta empieza en uno en vez de seguir
    /// sumando: el resumen puede llevar horas ahí sin que nadie lo refresque.
    static func bumpToday(_ habitId: String) {
        var rows = habits()
        guard let at = rows.firstIndex(where: { $0.id == habitId }) else { return }
        let hoy = dayKey()
        let lleva = rows[at].day == hoy ? rows[at].today : 0
        rows[at].today = lleva + 1
        rows[at].day = hoy
        rows[at].resting = false
        putHabits(rows)
    }

    // -------------------------------------------------------------- la marca

    /// La carpeta del grupo donde van las marcas dibujadas.
    static var marksDir: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("widget_marks", isDirectory: true)
    }

    static func markURL(_ habitId: String) -> URL? {
        marksDir?.appendingPathComponent("\(safe(habitId)).png")
    }

    static func putMark(_ habitId: String, png: Data?) {
        guard let dir = marksDir, let url = markURL(habitId) else { return }
        do {
            guard let png, !png.isEmpty else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            try FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)
            try png.write(to: url)
        } catch {
            // Una fila sin marca es una fila con su nombre, que se puede tocar
            // igual. Nada de esto vale una pantalla en blanco.
        }
    }

    /// Las marcas de los pueblos que ya no están, fuera del disco.
    static func sweepMarks(keep: Set<String>) {
        guard let dir = marksDir else { return }
        let viven = Set(keep.map { "\(safe($0)).png" })
        let fm = FileManager.default
        guard let hay = try? fm.contentsOfDirectory(atPath: dir.path) else { return }
        for f in hay where !viven.contains(f) {
            try? fm.removeItem(at: dir.appendingPathComponent(f))
        }
    }

    private static func safe(_ id: String) -> String {
        String(id.map { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" ? $0 : "_" })
    }

    // --------------------------------------------------------------- el buzón

    struct Note: Codable {
        var n: Int64
        var h: String
        var t: Int64
    }

    /// Apunta un toque y devuelve su número.
    ///
    /// El número sólo sube y no se reutiliza nunca: es lo que le permite a la
    /// app no contar dos veces la misma pieza si se muere entre ponerla y
    /// decir que ya está puesta.
    @discardableResult
    static func add(_ habitId: String, whenMs: Int64) -> Int64 {
        let guardado = defaults?.integer(forKey: kNext) ?? 0
        let n = Int64(guardado > 0 ? guardado : 1)
        var box = inbox()
        box.append(Note(n: n, h: habitId, t: whenMs))
        putInbox(box)
        defaults?.set(Int(n + 1), forKey: kNext)
        return n
    }

    static func inbox() -> [Note] {
        guard let raw = defaults?.string(forKey: kInbox),
              let data = raw.data(using: .utf8),
              let box = try? JSONDecoder().decode([Note].self, from: data)
        else { return [] }
        return box
    }

    private static func putInbox(_ box: [Note]) {
        guard let data = try? JSONEncoder().encode(box),
              let raw = String(data: data, encoding: .utf8) else { return }
        defaults?.set(raw, forKey: kInbox)
    }

    /// Ya se pueden olvidar las de hasta [upTo] inclusive.
    static func forget(upTo: Int64) {
        putInbox(inbox().filter { $0.n > upTo })
    }

    // ------------------------------------------------------------ el «seguro»

    /// Qué fila está preguntando «¿seguro?», si es que alguna y si no ha
    /// pasado el tiempo.
    static func armed() -> String? {
        guard let d = defaults, let id = d.string(forKey: kArmed), !id.isEmpty
        else { return nil }
        let at = Int64(d.double(forKey: kArmedAt))
        if nowMs() - at > armMs {
            disarm()
            return nil
        }
        return id
    }

    static func arm(_ habitId: String) {
        defaults?.set(habitId, forKey: kArmed)
        defaults?.set(Double(nowMs()), forKey: kArmedAt)
    }

    static func disarm() {
        defaults?.removeObject(forKey: kArmed)
        defaults?.removeObject(forKey: kArmedAt)
    }

    static func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    /// Un toque en una fila: la primera vez pregunta, la segunda pone.
    ///
    /// Devuelve si lo que hizo fue poner, para que quien llame sepa si tiene
    /// algo que celebrar.
    @discardableResult
    static func tap(_ habitId: String) -> Bool {
        if armed() == habitId {
            disarm()
            add(habitId, whenMs: nowMs())
            bumpToday(habitId)
            return true
        }
        arm(habitId)
        return false
    }
}
