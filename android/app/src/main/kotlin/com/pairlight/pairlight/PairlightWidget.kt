package com.pairlight.pairlight

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.time.LocalDate
import java.time.temporal.ChronoUnit

class PairlightWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = refresh(context, manager, ids)
    companion object {
        fun refresh(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences("pairlight_widget", Context.MODE_PRIVATE)
            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.pairlight_widget)
                views.setTextViewText(R.id.widget_title, prefs.getString("title", "Your little space"))
                val days = try {
                    ChronoUnit.DAYS.between(LocalDate.parse(prefs.getString("anniversary", "")), LocalDate.now()).coerceAtLeast(0)
                } catch (_: Exception) { null }
                views.setTextViewText(R.id.widget_days, days?.let { "$it days together" } ?: "A little closer, every day.")
                views.setTextViewText(R.id.widget_message, prefs.getString("message", "A little closer, every day."))
                val intent = Intent(context, MainActivity::class.java)
                val pending = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.widget_root, pending)
                manager.updateAppWidget(id, views)
            }
        }
    }
}
