package com.eshwar.expensetracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class BalanceHomeWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            val layoutId = resolveLayout(appWidgetManager.getAppWidgetOptions(appWidgetId))
            val views = RemoteViews(context.packageName, layoutId)

            val balance = widgetData.getString(KEY_BALANCE_TEXT, "\u20B90") ?: "\u20B90"
            val income = widgetData.getString(KEY_INCOME_TEXT, "\u20B90") ?: "\u20B90"
            val expense = widgetData.getString(KEY_EXPENSE_TEXT, "\u20B90") ?: "\u20B90"
            val updatedAt = widgetData.getString(KEY_UPDATED_AT_TEXT, "Updated now") ?: "Updated now"

            views.setTextViewText(R.id.tv_balance_value, balance)
            views.setTextViewText(R.id.tv_updated_at, updatedAt)

            if (layoutId == R.layout.balance_home_widget_expanded) {
                views.setTextViewText(R.id.tv_income_value, income)
                views.setTextViewText(R.id.tv_expense_value, expense)
            }

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            } ?: Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val launchPendingIntent = PendingIntent.getActivity(
                context,
                1010,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    companion object {
        private const val KEY_BALANCE_TEXT = "balance_text"
        private const val KEY_INCOME_TEXT = "income_text"
        private const val KEY_EXPENSE_TEXT = "expense_text"
        private const val KEY_UPDATED_AT_TEXT = "updated_at_text"

        private fun resolveLayout(options: Bundle): Int {
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val compact = minWidth in 1..179 || minHeight in 1..109
            return if (compact) R.layout.balance_home_widget_compact else R.layout.balance_home_widget_expanded
        }
    }
}
