package com.lamuralla.la_muralla

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * La app, y la aduana con el cuadrito de la pantalla de inicio.
 *
 * Tres verbos y ni uno más. La app **publica** lo que hay que enseñar, **lee**
 * lo que se tocó mientras no estaba, y **confirma** cuando ya lo puso — que es
 * lo único que vacía el buzón. Ver [WidgetBox] para por qué van en ese orden.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "publish" -> {
                            publish(call.argument<List<Map<String, Any?>>>("habits"))
                            result.success(null)
                        }
                        "drain" -> result.success(drain())
                        "ack" -> {
                            val upTo = (call.argument<Number>("upTo"))?.toLong() ?: 0L
                            if (upTo > 0) WidgetBox.forget(applicationContext, upTo)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    // Nada de esto vale una app que no arranca. Un widget que
                    // se queda con el resumen de ayer sigue siendo un widget.
                    result.success(null)
                }
            }
    }

    private fun publish(habits: List<Map<String, Any?>>?) {
        val c = applicationContext
        val rows = JSONArray()
        val ids = mutableSetOf<String>()
        for (h in habits ?: emptyList()) {
            val id = h["id"] as? String ?: continue
            ids.add(id)
            rows.put(
                JSONObject()
                    .put("id", id)
                    .put("name", (h["name"] as? String).orEmpty())
                    .put("today", (h["today"] as? Number)?.toInt() ?: 0)
                    .put("day", (h["day"] as? Number)?.toInt() ?: 0)
                    .put("resting", h["resting"] as? Boolean ?: false)
            )
            // La marca sólo se reescribe cuando viene: si el dibujo no cambió,
            // el fichero de ayer es el mismo fichero.
            (h["mark"] as? ByteArray)?.let { WidgetBox.putMark(c, id, it) }
        }
        WidgetBox.putHabits(c, rows)
        WidgetBox.sweepMarks(c, ids)
        TownyWidget.refresh(c)
    }

    private fun drain(): List<Map<String, Any>> {
        val box = WidgetBox.inbox(applicationContext)
        val out = ArrayList<Map<String, Any>>(box.length())
        for (i in 0 until box.length()) {
            val e = box.optJSONObject(i) ?: continue
            val n = e.optLong("n", 0L)
            val h = e.optString("h")
            val t = e.optLong("t", 0L)
            if (n <= 0L || h.isEmpty() || t <= 0L) continue
            out.add(mapOf("n" to n, "h" to h, "t" to t))
        }
        return out
    }

    companion object {
        private const val CHANNEL = "towny/widget"
    }
}
