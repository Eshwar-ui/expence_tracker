package com.eshwar.expensetracker

import android.app.Notification
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class NotificationCaptureService : NotificationListenerService() {

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "Notification listener created")
    }

    override fun onDestroy() {
        Log.i(TAG, "Notification listener destroyed")
        super.onDestroy()
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "Notification listener connected")
    }

    override fun onListenerDisconnected() {
        Log.w(TAG, "Notification listener disconnected")
        super.onListenerDisconnected()
    }

    override fun onBind(intent: Intent?): android.os.IBinder? {
        Log.d(TAG, "Notification listener bound")
        return super.onBind(intent)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        Log.d(TAG, "Notification listener unbound")
        // Return true to receive onRebind when the system re-connects the listener.
        return true
    }

    override fun onRebind(intent: Intent?) {
        Log.d(TAG, "Notification listener rebound")
        super.onRebind(intent)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName ?: return
        if (!isAllowedPackage(packageName)) {
            return
        }

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val timestamp = sbn.postTime

        // Persist and forward the raw payload to Flutter on a background thread.
        NotificationChannelBridge.enqueueNotification(packageName, title, text, timestamp)

        // Broadcast a simple event so other app components can react in real time.
        val intent = Intent(ACTION_NOTIFICATION_CAPTURED).apply {
            putExtra(EXTRA_PACKAGE, packageName)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_TEXT, text)
            putExtra(EXTRA_TIMESTAMP, timestamp)
        }
        sendBroadcast(intent)
    }

    private fun isAllowedPackage(packageName: String): Boolean {
        val allowed = prefs().getStringSet(KEY_ALLOWED_PACKAGES, emptySet()) ?: emptySet()
        // If the allowlist is empty, skip everything to avoid capturing unintended apps.
        if (allowed.isEmpty()) {
            return false
        }
        return allowed.contains(packageName)
    }

    private fun prefs(): SharedPreferences =
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        private const val TAG = "NotificationCapture"

        const val ACTION_NOTIFICATION_CAPTURED =
            "com.eshwar.expensetracker.NOTIFICATION_CAPTURED"
        const val EXTRA_PACKAGE = "extra_package"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_TEXT = "extra_text"
        const val EXTRA_TIMESTAMP = "extra_timestamp"

        const val PREFS_NAME = "notification_listener_prefs"
        const val KEY_ALLOWED_PACKAGES = "allowed_notification_packages"
        const val KEY_LAST_PACKAGE = "last_notification_package"
        const val KEY_LAST_TITLE = "last_notification_title"
        const val KEY_LAST_TEXT = "last_notification_text"
        const val KEY_LAST_TIMESTAMP = "last_notification_timestamp"
    }
}
