import Flutter
import UIKit
import WidgetKit

/// La app, y la aduana con el cuadrito de la pantalla de inicio.
///
/// Tres verbos y ni uno más, los mismos que del lado de Android: la app
/// **publica** lo que hay que enseñar, **lee** lo que se tocó mientras no
/// estaba, y **confirma** cuando ya lo puso — que es lo único que vacía el
/// buzón. Ver `WidgetBox.swift` para por qué van en ese orden.
@main
@objc class AppDelegate: FlutterAppDelegate {
    private static let channelName = "towny/widget"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        if let root = window?.rootViewController as? FlutterViewController {
            FlutterMethodChannel(
                name: AppDelegate.channelName,
                binaryMessenger: root.binaryMessenger
            ).setMethodCallHandler { call, result in
                switch call.method {
                case "publish":
                    let args = call.arguments as? [String: Any]
                    self.publish(args?["habits"] as? [[String: Any]] ?? [])
                    result(nil)
                case "drain":
                    result(WidgetBox.inbox().map { ["n": $0.n, "h": $0.h, "t": $0.t] })
                case "ack":
                    let args = call.arguments as? [String: Any]
                    let upTo = (args?["upTo"] as? NSNumber)?.int64Value ?? 0
                    if upTo > 0 { WidgetBox.forget(upTo: upTo) }
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func publish(_ habits: [[String: Any]]) {
        var rows: [WidgetBox.Row] = []
        var ids = Set<String>()
        for h in habits {
            guard let id = h["id"] as? String else { continue }
            ids.insert(id)
            rows.append(
                WidgetBox.Row(
                    id: id,
                    name: h["name"] as? String ?? "",
                    today: (h["today"] as? NSNumber)?.intValue ?? 0,
                    day: (h["day"] as? NSNumber)?.intValue ?? 0,
                    resting: h["resting"] as? Bool ?? false
                )
            )
            // La marca sólo se reescribe cuando viene: si el dibujo no cambió,
            // el fichero de ayer es el mismo fichero.
            if let mark = h["mark"] as? FlutterStandardTypedData {
                WidgetBox.putMark(id, png: mark.data)
            }
        }
        WidgetBox.putHabits(rows)
        WidgetBox.sweepMarks(keep: ids)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
