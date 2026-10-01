import AppIntents
import SwiftUI
import WidgetKit

/// El pueblo en la pantalla de inicio.
///
/// Una fila por hábito: la marca, el nombre y cuántas piezas lleva hoy ese
/// pueblo. La cuenta y no un punto encendido, porque lo que alguien quiere
/// saber mirando la pantalla de inicio no es sólo si apareció hoy: es cuánto
/// lleva hecho, y obligarle a abrir la app para eso es cobrarle un peaje por
/// una información que cabe en un dígito.
///
/// De hoy, y de nada más. Ni rachas ni totales: «llevás tres hoy» es lo que
/// hiciste, «llevás nueve días seguidos» es una cuenta que castiga el día que
/// se rompe, y ésa no la lleva la app por dentro ni la va a llevar por fuera.
///
/// **Lo que pasa al tocar.** El primer toque abre un botón que dice «Poner
/// pieza» y tiñe la fila; el segundo la pone. No es un paso de más: dentro de
/// la app poner una pieza pide mantener el dedo hasta que se cierra un anillo,
/// porque poner una piedra tiene que ser una decisión y no un temblor. Un
/// widget no puede pedir que mantengas el dedo, así que pide dos toques. Un
/// roce en el bolsillo no construye nada.
///
/// **Y lo que no pasa.** El widget no toca el pueblo. Deja el toque apuntado
/// en `WidgetBox` con su hora, y la pieza la pone la app la próxima vez que
/// alguien la abra — con la hora a la que se tocó, y enseñándola caer.
/// Levantar un pueblo entero dentro de una extensión para poner una piedra
/// sería arrancar el motor de la app cada vez que alguien pasa por su pantalla
/// de inicio.

// ------------------------------------------------------------------- colores

/// Los del valle, los mismos que usa el widget de Android.
private enum Tinta {
    static let prado = Color(red: 0x70 / 255, green: 0x92 / 255, blue: 0x46 / 255)
    static let papel = Color(red: 0xF4 / 255, green: 0xEE / 255, blue: 0xE0 / 255)
    static let tinta = Color(red: 0x2C / 255, green: 0x26 / 255, blue: 0x20 / 255)
    static let suave = Color(red: 0x79 / 255, green: 0x6E / 255, blue: 0x5E / 255)
    static let brasa = Color(red: 0xA8 / 255, green: 0x54 / 255, blue: 0x1B / 255)
}

// -------------------------------------------------------------------- el toque

/// Tocar una fila. La primera vez pregunta, la segunda pone.
///
/// Esto corre **dentro del widget**, sin abrir la app, que es lo que iOS
/// permite desde la 17. Lo único que hace es escribir en la caja compartida;
/// quien levanta el pueblo sigue siendo la app.
struct TocarPueblo: AppIntent {
    static var title: LocalizedStringResource = "Tocar un pueblo"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Pueblo")
    var habit: String

    init() {}
    init(habit: String) { self.habit = habit }

    func perform() async throws -> some IntentResult {
        WidgetBox.tap(habit)
        return .result()
    }
}

/// Dejar de preguntar, sin poner nada.
struct Olvidar: AppIntent {
    static var title: LocalizedStringResource = "Dejarlo"
    static var isDiscoverable: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        WidgetBox.disarm()
        return .result()
    }
}

// ------------------------------------------------------------------ el reloj

struct Momento: TimelineEntry {
    let date: Date
    let rows: [WidgetBox.Row]
    let armed: String?
}

struct Cronista: TimelineProvider {
    func placeholder(in context: Context) -> Momento {
        Momento(
            date: Date(),
            rows: [
                WidgetBox.Row(
                    id: "x", name: "Leer", today: 1,
                    day: WidgetBox.dayKey(), resting: false)
            ],
            armed: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (Momento) -> Void) {
        completion(ahora())
    }

    /// Una entrada ahora y otra a medianoche.
    ///
    /// La de medianoche no es un capricho: la cuenta del resumen lleva escrito
    /// de qué día es, y a las doce y un minuto deja de valer. Sin esa segunda
    /// entrada, un cuadrito que nadie refresca enseña a las nueve de la mañana
    /// las tres piezas de ayer.
    func getTimeline(in context: Context, completion: @escaping (Timeline<Momento>) -> Void) {
        let hoy = ahora()
        var entradas = [hoy]
        if let manana = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) {
            entradas.append(Momento(date: manana, rows: hoy.rows, armed: nil))
        }
        completion(Timeline(entries: entradas, policy: .atEnd))
    }

    private func ahora() -> Momento {
        Momento(date: Date(), rows: WidgetBox.habits(), armed: WidgetBox.armed())
    }
}

// -------------------------------------------------------------------- el cuadro

struct Fila: View {
    let row: WidgetBox.Row
    let armada: Bool

    private var cuenta: Int { row.day == WidgetBox.dayKey() ? row.today : 0 }

    var body: some View {
        HStack(spacing: 8) {
            marca
            Text(row.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Tinta.tinta)
                .lineLimit(1)
            Spacer(minLength: 4)
            if armada {
                Text("Poner pieza")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tinta.papel)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Tinta.brasa))
            } else if row.resting {
                // Un pueblo en pausa no tiene cuenta que enseñar, y decir cero
                // sería decir que fallaste.
                Text("en pausa")
                    .font(.system(size: 12))
                    .foregroundStyle(Tinta.suave)
            } else {
                Text("\(cuenta)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(cuenta > 0 ? Tinta.prado : Tinta.suave)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(armada ? Tinta.brasa.opacity(0.14) : .clear)
        )
    }

    @ViewBuilder private var marca: some View {
        if let url = WidgetBox.markURL(row.id),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .frame(width: 20, height: 20)
        } else {
            // Una fila sin marca es una fila con su nombre: se puede tocar
            // igual, que es para lo que está.
            Circle().fill(Tinta.suave.opacity(0.35)).frame(width: 20, height: 20)
        }
    }
}

struct Cuadro: View {
    var entry: Momento

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.rows.isEmpty {
                Spacer()
                Text("Abrí Towny para fundar tu primer pueblo.")
                    .font(.system(size: 13))
                    .foregroundStyle(Tinta.suave)
                    .padding(.horizontal, 10)
                Spacer()
            } else {
                ForEach(entry.rows) { row in
                    Button(intent: TocarPueblo(habit: row.id)) {
                        Fila(row: row, armada: entry.armed == row.id)
                    }
                    .buttonStyle(.plain)
                }
                if entry.armed != nil {
                    Button(intent: Olvidar()) {
                        Text("Dejarlo")
                            .font(.system(size: 11))
                            .foregroundStyle(Tinta.suave)
                            .padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 6)
    }
}

@main
struct TownyWidget: Widget {
    let kind = "TownyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Cronista()) { entry in
            if #available(iOS 17.0, *) {
                Cuadro(entry: entry)
                    .containerBackground(Tinta.papel, for: .widget)
            } else {
                Cuadro(entry: entry)
                    .background(Tinta.papel)
            }
        }
        .configurationDisplayName("Towny")
        .description("Tus pueblos, y lo que llevás hoy en cada uno.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
