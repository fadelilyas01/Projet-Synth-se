package com.shieldnet.shieldnet

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class ShieldNetAppWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val isShieldActive = prefs.getBoolean("flutter.widget_shield_active", true)
        val blockedCount = prefs.getInt("flutter.widget_blocked_count", 0)
        val lastSync = prefs.getString("flutter.widget_last_sync", "Synchronisation locale active")

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.shieldnet_appwidget)

            // Mise à jour de l'affichage
            views.setTextViewText(
                R.id.widget_status_badge,
                if (isShieldActive) "PROTÉGÉ" else "EN PAUSE"
            )
            views.setTextColor(
                R.id.widget_status_badge,
                if (isShieldActive) 0xFF10B981.toInt() else 0xFFEF4444.toInt()
            )

            views.setTextViewText(R.id.widget_blocked_count, "$blockedCount")
            views.setTextViewText(R.id.widget_sync_time, lastSync)

            // Clic sur le widget pour ouvrir l'application
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
