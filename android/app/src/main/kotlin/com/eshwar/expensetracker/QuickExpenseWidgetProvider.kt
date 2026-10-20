package com.eshwar.expensetracker

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class QuickExpenseWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.quick_expense_widget)
            views.setOnClickPendingIntent(R.id.quick_expense_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("expense-widget://add")))
            manager.updateAppWidget(id, views)
        }
    }
}

class ExpenseShortcutsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.expense_shortcuts_widget)
            val actions = mapOf(R.id.widget_add to "add", R.id.widget_voice to "voice",
                R.id.widget_food to "food", R.id.widget_travel to "travel", R.id.widget_shopping to "shopping")
            for ((viewId, action) in actions) {
                views.setOnClickPendingIntent(viewId, HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, Uri.parse("expense-widget://$action")))
            }
            manager.updateAppWidget(id, views)
        }
    }
}
