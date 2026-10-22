package com.farhan.murmur

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** Home-screen widget that opens Murmur's quick transcribe screen. */
class QuickWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).setAction(ACTION_QUICK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val views = RemoteViews(context.packageName, R.layout.quick_widget).apply {
            setOnClickPendingIntent(R.id.quick_widget, open)
        }
        manager.updateAppWidget(ids, views)
    }

    companion object {
        const val ACTION_QUICK = "com.farhan.murmur.QUICK_TRANSCRIBE"
    }
}
