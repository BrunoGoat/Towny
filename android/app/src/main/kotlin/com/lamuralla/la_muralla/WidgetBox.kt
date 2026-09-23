package com.lamuralla.la_muralla

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Lo único que el widget guarda, y lo único que la app le deja escrito.
 *
 * Son unas preferencias aparte, de las de toda la vida, y no las de la app.
 * No es descuido: el guardado del pueblo lo lleva Flutter en un almacén de
 * Jetpack que sólo admite un dueño vivo por proceso, y el widget corre en ese
 * mismo proceso. Abrirlo desde aquí sería pelearse con el que ya lo tiene
 * abierto por un fichero que además no hace falta: lo que el widget necesita
 * saber son seis nombres y seis marcas.
 *
 * Así que van dos cajas y una aduana. Aquí dentro hay dos cosas:
 *
 *  - **el resumen**, que escribe la app y lee el widget, y
 *  - **el buzón**, que escribe el widget y vacía la app.
 *
 * Ninguna de las dos la escriben los dos, que es lo que hace que esto no
 * necesite candados.
 */
object WidgetBox {
    private const val FILE = "towny_widget"

    private const val K_HABITS = "habits"
    private const val K_INBOX = "inbox"
    private const val K_NEXT = "next"
    private const val K_ARMED = "armed"
    private const val K_ARMED_AT = "armedAt"

    /**
     * Cuánto dura el «¿seguro?» de una fila.
     *
     * Existe porque dentro de la app una pieza no se pone con un toque: se
     * pone manteniendo el dedo hasta que se cierra un anillo, y eso es a
     * propósito —hace que poner una piedra sea una decisión y no un temblor—.
     * En la pantalla de inicio no hay manera de mantener el dedo, así que el
     * equivalente son dos toques: el primero pregunta y el segundo pone. Un
     * roce en el bolsillo no construye nada.
     */
    const val ARM_MS = 5000L

    fun prefs(c: Context): SharedPreferences =
        c.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    // ------------------------------------------------------------ el resumen

    fun putHabits(c: Context, rows: JSONArray) {
        prefs(c).edit().putString(K_HABITS, rows.toString()).apply()
    }

    fun habits(c: Context): JSONArray =
        try {
            JSONArray(prefs(c).getString(K_HABITS, "[]") ?: "[]")
        } catch (e: Exception) {
            JSONArray()
        }

    /** El hueco de ese hábito en el resumen, o -1 si ya no está. */
    fun rowOf(rows: JSONArray, habitId: String): Int {
        for (i in 0 until rows.length()) {
            if (rows.optJSONObject(i)?.optString("id") == habitId) return i
        }
        return -1
    }

    /**
     * Deja apuntado que ese pueblo ya tiene una pieza hoy.
     *
     * Es un adelanto: la pieza de verdad la pone la app cuando alguien la
     * abre. Pero el punto de la fila tiene que encenderse **ahora**, porque lo
     * que contesta es «¿ya lo hice hoy?» y la respuesta ya cambió.
     */
    fun markToday(c: Context, habitId: String) {
        val rows = habits(c)
        val at = rowOf(rows, habitId)
        if (at < 0) return
        rows.optJSONObject(at)?.put("today", true)?.put("resting", false)
        putHabits(c, rows)
    }

    // -------------------------------------------------------------- la marca

    fun markFile(c: Context, habitId: String): File =
        File(File(c.filesDir, "widget_marks"), "${safe(habitId)}.png")

    fun putMark(c: Context, habitId: String, png: ByteArray?) {
        val f = markFile(c, habitId)
        try {
            if (png == null || png.isEmpty()) {
                f.delete()
                return
            }
            f.parentFile?.mkdirs()
            f.writeBytes(png)
        } catch (e: Exception) {
            // Una fila sin marca es una fila con su nombre. Se puede tocar
            // igual, que es para lo que está.
        }
    }

    /** Las marcas de los pueblos que ya no están, fuera del disco. */
    fun sweepMarks(c: Context, keep: Set<String>) {
        try {
            val dir = File(c.filesDir, "widget_marks")
            val safe = keep.map { safe(it) + ".png" }.toSet()
            dir.listFiles()?.forEach { if (it.name !in safe) it.delete() }
        } catch (e: Exception) {
        }
    }

    private fun safe(id: String): String =
        id.map { if (it.isLetterOrDigit() || it == '_' || it == '-') it else '_' }
            .joinToString("")

    // --------------------------------------------------------------- el buzón

    /**
     * Apunta un toque y devuelve su número.
     *
     * El número sólo sube y no se reutiliza nunca: es lo que le permite a la
     * app no contar dos veces la misma pieza si se muere entre ponerla y decir
     * que ya está puesta.
     */
    fun add(c: Context, habitId: String, whenMs: Long): Long {
        val p = prefs(c)
        val n = p.getLong(K_NEXT, 1L)
        val box = inbox(c)
        box.put(
            JSONObject()
                .put("n", n)
                .put("h", habitId)
                .put("t", whenMs)
        )
        p.edit()
            .putString(K_INBOX, box.toString())
            .putLong(K_NEXT, n + 1)
            .apply()
        return n
    }

    fun inbox(c: Context): JSONArray =
        try {
            JSONArray(prefs(c).getString(K_INBOX, "[]") ?: "[]")
        } catch (e: Exception) {
            JSONArray()
        }

    /** Ya se pueden olvidar las de hasta [upTo] inclusive. */
    fun forget(c: Context, upTo: Long) {
        val box = inbox(c)
        val queda = JSONArray()
        for (i in 0 until box.length()) {
            val e = box.optJSONObject(i) ?: continue
            if (e.optLong("n", 0L) > upTo) queda.put(e)
        }
        prefs(c).edit().putString(K_INBOX, queda.toString()).apply()
    }

    // -------------------------------------------------------------- el armado

    /** Qué fila está preguntando «¿seguro?», si es que hay alguna. */
    fun armed(c: Context): String? {
        val p = prefs(c)
        val id = p.getString(K_ARMED, null) ?: return null
        if (id.isEmpty()) return null
        val since = System.currentTimeMillis() - p.getLong(K_ARMED_AT, 0L)
        // El reloj puede haber ido para atrás entre el toque y ahora; un
        // «hace menos de nada» negativo también es caducado.
        if (since < 0 || since > ARM_MS) return null
        return id
    }

    fun arm(c: Context, habitId: String) {
        prefs(c).edit()
            .putString(K_ARMED, habitId)
            .putLong(K_ARMED_AT, System.currentTimeMillis())
            .apply()
    }

    fun disarm(c: Context) {
        prefs(c).edit().remove(K_ARMED).remove(K_ARMED_AT).apply()
    }
}
