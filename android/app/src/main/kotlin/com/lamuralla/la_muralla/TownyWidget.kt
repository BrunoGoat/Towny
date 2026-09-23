package com.lamuralla.la_muralla

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews

/**
 * El pueblo en la pantalla de inicio.
 *
 * Una fila por hábito: la marca, el nombre y cuántas piezas lleva hoy ese
 * pueblo. La cuenta y no un punto encendido, porque lo que alguien quiere
 * saber mirando la pantalla de inicio no es sólo si apareció hoy: es cuánto
 * lleva hecho, y obligarle a abrir la app para eso es cobrarle un peaje por
 * una información que cabe en un dígito.
 *
 * De hoy, y de nada más. Ni rachas ni totales: «llevás tres hoy» es lo que
 * hiciste, «llevás nueve días seguidos» es una cuenta que castiga el día que
 * se rompe, y ésa no la lleva la app por dentro ni la va a llevar por fuera.
 *
 * **Lo que pasa al tocar.** El primer toque abre un botón que dice «Poner
 * pieza» y tiñe la fila; el segundo, sobre cualquier parte de la fila, la
 * pone. No es un paso de más: dentro de la app poner una pieza pide mantener
 * el dedo hasta que se cierra un anillo, porque poner una piedra tiene que ser
 * una decisión y no un temblor. Un widget no puede pedir que mantengas el
 * dedo, así que pide dos toques. Un roce en el bolsillo no construye nada.
 *
 * El primer intento de decir eso era la palabra «Otra vez» al final de la
 * fila, y no se entendía: una palabra suelta describe algo, no pide nada, y la
 * pregunta que dejaba era «¿otra vez qué?». Un verbo dentro de algo con forma
 * de botón no deja esa duda.
 *
 * **Y lo que no pasa.** El widget no toca el pueblo. Deja el toque apuntado en
 * [WidgetBox] con su hora, y la pieza la pone la app la próxima vez que
 * alguien la abra — con la hora a la que se tocó, y enseñándola caer. Levantar
 * un pueblo entero desde un receptor de difusión para poner una piedra sería
 * arrancar el motor de la app cada vez que alguien pasa por su pantalla de
 * inicio.
 */
class TownyWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray
    ) {
        for (id in ids) draw(context, manager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_TAP -> {
                tap(context, intent.getStringExtra(EXTRA_HABIT) ?: return)
                refresh(context)
            }
            ACTION_FORGET -> {
                WidgetBox.disarm(context)
                refresh(context)
            }
            else -> super.onReceive(context, intent)
        }
    }

    /**
     * Un toque en una fila: pregunta, o pone.
     */
    private fun tap(context: Context, habitId: String) {
        if (WidgetBox.armed(context) == habitId) {
            WidgetBox.disarm(context)
            WidgetBox.add(context, habitId, System.currentTimeMillis())
            // La cuenta sube ahora, aunque la piedra no esté puesta hasta que
            // abras: lo que la fila contesta es «¿cuántas llevo hoy?», y esa
            // respuesta ya cambió.
            WidgetBox.bumpToday(context, habitId)
            cancelForget(context)
        } else {
            WidgetBox.arm(context, habitId)
            // Y que la pregunta se retire sola. Si alguien tocó sin querer y
            // se fue, lo que no puede pasar es encontrarse la fila preguntando
            // dos horas después: el segundo toque de entonces no sería una
            // confirmación de nada.
            scheduleForget(context)
        }
    }

    // ------------------------------------------------------------- el dibujo

    private fun draw(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.towny_widget)
        val rows = WidgetBox.habits(context)
        val armed = WidgetBox.armed(context)

        views.setViewVisibility(
            R.id.towny_empty,
            if (rows.length() == 0) View.VISIBLE else View.GONE
        )

        for (i in 0 until SLOTS) {
            val row = if (i < rows.length()) rows.optJSONObject(i) else null
            if (row == null) {
                views.setViewVisibility(ROW[i], View.GONE)
                continue
            }
            views.setViewVisibility(ROW[i], View.VISIBLE)

            val id = row.optString("id")
            val resting = row.optBoolean("resting", false)
            views.setTextViewText(NAME[i], row.optString("name"))
            // Un pueblo dormido no desaparece de la lista: se apaga. Sigue
            // estando y tocarlo lo despierta, igual que dentro de la app.
            views.setInt(
                NAME[i],
                "setTextColor",
                context.getColor(
                    if (resting) R.color.towny_widget_faint
                    else R.color.towny_widget_ink
                )
            )

            val mark = WidgetBox.markFile(context, id)
            if (mark.exists()) {
                val bmp = try {
                    BitmapFactory.decodeFile(mark.absolutePath)
                } catch (e: Exception) {
                    null
                }
                if (bmp != null) views.setImageViewBitmap(MARK[i], bmp)
            }
            // La marca viene dibujada en blanco desde la app, que no sabe
            // sobre qué fondo va a acabar. El color se le pone aquí.
            views.setInt(
                MARK[i],
                "setColorFilter",
                context.getColor(
                    if (resting) R.color.towny_widget_faint
                    else R.color.towny_widget_ink
                )
            )

            // Cuántas van hoy. La cuenta vale sólo si es de hoy: un resumen
            // que lleva desde anoche sin refrescarse tiene la de ayer, y
            // enseñarla sería mentir a la hora del desayuno.
            val lleva =
                if (row.optInt("day", 0) == WidgetBox.dayKey()) {
                    row.optInt("today", 0)
                } else {
                    0
                }

            val preguntando = armed != null && armed == id
            // La fila entera teñida mientras espera, no sólo el botón puesto:
            // lo que hay que dejar claro es que **ésta** está a medio camino.
            views.setInt(
                ROW[i],
                "setBackgroundResource",
                if (preguntando) R.drawable.towny_widget_row_armed
                else R.drawable.towny_widget_row
            )
            views.setViewVisibility(ASK[i], if (preguntando) View.VISIBLE else View.GONE)
            views.setViewVisibility(
                COUNT[i],
                if (!preguntando && lleva > 0) View.VISIBLE else View.GONE
            )
            // El anillo vacío sólo cuando no hay ninguna. No es un cero: dice
            // que el hueco está, no que hayas fallado.
            views.setViewVisibility(
                DOT[i],
                if (!preguntando && lleva <= 0) View.VISIBLE else View.GONE
            )
            if (lleva > 0) views.setTextViewText(COUNT[i], lleva.toString())

            views.setOnClickPendingIntent(ROW[i], tapIntent(context, i, id))
        }

        views.setOnClickPendingIntent(R.id.towny_open, openIntent(context))
        manager.updateAppWidget(widgetId, views)
    }

    companion object {
        /** Los solares del valle. Ver `Habit.maxSlots` del otro lado. */
        const val SLOTS = 6

        private const val ACTION_TAP = "com.lamuralla.la_muralla.WIDGET_TAP"
        private const val ACTION_FORGET = "com.lamuralla.la_muralla.WIDGET_FORGET"
        private const val EXTRA_HABIT = "habit"

        private val ROW = intArrayOf(
            R.id.towny_row_0, R.id.towny_row_1, R.id.towny_row_2,
            R.id.towny_row_3, R.id.towny_row_4, R.id.towny_row_5
        )
        private val MARK = intArrayOf(
            R.id.towny_mark_0, R.id.towny_mark_1, R.id.towny_mark_2,
            R.id.towny_mark_3, R.id.towny_mark_4, R.id.towny_mark_5
        )
        private val NAME = intArrayOf(
            R.id.towny_name_0, R.id.towny_name_1, R.id.towny_name_2,
            R.id.towny_name_3, R.id.towny_name_4, R.id.towny_name_5
        )
        private val ASK = intArrayOf(
            R.id.towny_ask_0, R.id.towny_ask_1, R.id.towny_ask_2,
            R.id.towny_ask_3, R.id.towny_ask_4, R.id.towny_ask_5
        )
        private val COUNT = intArrayOf(
            R.id.towny_count_0, R.id.towny_count_1, R.id.towny_count_2,
            R.id.towny_count_3, R.id.towny_count_4, R.id.towny_count_5
        )
        private val DOT = intArrayOf(
            R.id.towny_dot_0, R.id.towny_dot_1, R.id.towny_dot_2,
            R.id.towny_dot_3, R.id.towny_dot_4, R.id.towny_dot_5
        )

        /** Volver a dibujar todos los que haya puestos. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = try {
                manager.getAppWidgetIds(
                    ComponentName(context, TownyWidget::class.java)
                )
            } catch (e: Exception) {
                return
            }
            if (ids == null || ids.isEmpty()) return
            val w = TownyWidget()
            for (id in ids) w.draw(context, manager, id)
        }

        private fun flags(): Int =
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        /**
         * El toque de una fila.
         *
         * Lleva su propia `data` y no sólo su extra: dos `PendingIntent` que
         * se distinguen nada más que por los extras son, para Android, el
         * mismo, y las seis filas acabarían poniendo piezas en el mismo
         * pueblo.
         */
        private fun tapIntent(context: Context, row: Int, habitId: String) =
            PendingIntent.getBroadcast(
                context,
                row,
                Intent(context, TownyWidget::class.java)
                    .setAction(ACTION_TAP)
                    .setData(Uri.parse("towny://row/$habitId"))
                    .putExtra(EXTRA_HABIT, habitId),
                flags()
            )

        private fun forgetIntent(context: Context) =
            PendingIntent.getBroadcast(
                context,
                SLOTS + 1,
                Intent(context, TownyWidget::class.java).setAction(ACTION_FORGET),
                flags()
            )

        private fun openIntent(context: Context): PendingIntent? {
            val go = context.packageManager
                .getLaunchIntentForPackage(context.packageName) ?: return null
            return PendingIntent.getActivity(context, SLOTS + 2, go, flags())
        }

        /**
         * Que la pregunta se retire sola a los pocos segundos.
         *
         * Con una alarma de las flojas, no de las que despiertan el teléfono a
         * una hora clavada: esta app no pide `SCHEDULE_EXACT_ALARM` para los
         * avisos y menos todavía lo va a pedir para esto. Que llegue tarde no
         * rompe nada — la fila se mira por la hora a la que se armó, así que
         * una pregunta caducada ya no confirma aunque se siga viendo.
         */
        private fun scheduleForget(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: return
            val at = System.currentTimeMillis() + WidgetBox.ARM_MS + 250L
            try {
                am.set(AlarmManager.RTC, at, forgetIntent(context))
            } catch (e: Exception) {
            }
        }

        private fun cancelForget(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: return
            try {
                am.cancel(forgetIntent(context))
            } catch (e: Exception) {
            }
        }
    }
}
