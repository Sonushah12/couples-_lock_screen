package com.pairlight.pairlight

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pairlight/widget").setMethodCallHandler { call, result ->
            val manager = AppWidgetManager.getInstance(this)
            val component = ComponentName(this, PairlightWidget::class.java)
            when (call.method) {
                "update" -> {
                    getSharedPreferences("pairlight_widget", Context.MODE_PRIVATE).edit()
                        .putString("title", call.argument<String>("title"))
                        .putString("message", call.argument<String>("message"))
                        .putString("spaceId", call.argument<String>("spaceId") ?: "")
                        .putString("anniversary", call.argument<String>("anniversary") ?: "").apply()
                    PairlightWidget.refresh(this, manager, manager.getAppWidgetIds(component))
                    result.success(true)
                }
                "pin" -> result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.isRequestPinAppWidgetSupported) manager.requestPinAppWidget(component, null, null) else false)
                else -> result.notImplemented()
            }
        }
    }
}
