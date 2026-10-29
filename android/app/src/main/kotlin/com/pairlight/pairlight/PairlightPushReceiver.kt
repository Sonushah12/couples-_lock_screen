package com.pairlight.pairlight

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/** A generic widget update independent of Flutter's foreground engine. */
class PairlightPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.google.android.c2dm.intent.RECEIVE") return
        val incomingSpace = intent.getStringExtra("spaceId") ?: return
        val prefs = context.getSharedPreferences("pairlight_widget", Context.MODE_PRIVATE)
        if (incomingSpace.isEmpty() || incomingSpace != prefs.getString("spaceId", "")) return
        prefs.edit().putString("message", "A new moment is waiting. Open Pairlight.").apply()
        val manager = AppWidgetManager.getInstance(context)
        PairlightWidget.refresh(context, manager, manager.getAppWidgetIds(ComponentName(context, PairlightWidget::class.java)))
    }
}
