package com.eshwar.expensetracker

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.BinaryMessenger
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.util.concurrent.Executors

object NotificationChannelBridge {
    private const val TAG = "NotificationChannel"

    private const val METHOD_CHANNEL = "com.eshwar.expensetracker/notification_listener/methods"
    private const val EVENT_CHANNEL = "com.eshwar.expensetracker/notification_listener/events"

    private const val KEY_PENDING = "pending_notifications"

    private const val MAX_PENDING = 50

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var eventSink: EventChannel.EventSink? = null
    @Volatile
    private var appContext: Context? = null

    fun attach(context: Context, messenger: BinaryMessenger) {
        appContext = context.applicationContext
        Log.i(TAG, "Attaching notification bridge for package=${context.packageName}")

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.i(TAG, "Flutter event listener attached")
                dispatchPending()
            }

            override fun onCancel(arguments: Any?) {
                Log.i(TAG, "Flutter event listener detached")
                eventSink = null
            }
        })

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(object : MethodCallHandler {
            override fun onMethodCall(call: MethodCall, result: Result) {
                when (call.method) {
                    "setAllowedPackages" -> handleSetAllowedPackages(call, result)
                    "getAllowedPackages" -> handleGetAllowedPackages(result)
                    "getLastNotification" -> handleGetLastNotification(result)
                    "getPendingNotifications" -> handleGetPendingNotifications(result)
                    "clearPendingNotifications" -> handleClearPendingNotifications(result)
                    "isListenerEnabled" -> handleIsListenerEnabled(result)
                    "openNotificationSettings" -> handleOpenNotificationSettings(result)
                    "getAppPackageName" -> handleGetAppPackageName(result)
                    else -> result.notImplemented()
                }
            }
        })
    }

    fun enqueueNotification(
        packageName: String,
        title: String,
        text: String,
        timestamp: Long
    ) {
        executor.execute {
            val payload = buildPayload(packageName, title, text, timestamp)
            Log.i(
                TAG,
                "Queueing notification package=$packageName title=\"$title\" text=\"$text\" timestamp=$timestamp"
            )
            try {
                saveLast(payload)
                appendPending(payload)
                emit(payload)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to enqueue notification", e)
            }
        }
    }

    private fun handleSetAllowedPackages(call: MethodCall, result: Result) {
        val context = appContext
        if (context == null) {
            result.error("NO_CONTEXT", "Context not ready", null)
            return
        }
        val raw = call.arguments
        val list = when (raw) {
            is List<*> -> raw.filterIsInstance<String>()
            else -> emptyList()
        }
        executor.execute {
            prefs(context).edit()
                .putStringSet(NotificationCaptureService.KEY_ALLOWED_PACKAGES, list.toSet())
                .apply()
            Log.i(TAG, "Stored ${list.size} allowed notification packages")
            mainHandler.post { result.success(true) }
        }
    }

    private fun handleGetAllowedPackages(result: Result) {
        val context = appContext
        if (context == null) {
            result.error("NO_CONTEXT", "Context not ready", null)
            return
        }
        executor.execute {
            val set = prefs(context).getStringSet(
                NotificationCaptureService.KEY_ALLOWED_PACKAGES,
                emptySet()
            ) ?: emptySet()
            mainHandler.post { result.success(set.toList()) }
        }
    }

    private fun handleGetLastNotification(result: Result) {
        val context = appContext
        if (context == null) {
            result.error("NO_CONTEXT", "Context not ready", null)
            return
        }
        executor.execute {
            val prefs = prefs(context)
            val packageName = prefs.getString(NotificationCaptureService.KEY_LAST_PACKAGE, null)
            val title = prefs.getString(NotificationCaptureService.KEY_LAST_TITLE, null)
            val text = prefs.getString(NotificationCaptureService.KEY_LAST_TEXT, null)
            val timestamp = prefs.getLong(NotificationCaptureService.KEY_LAST_TIMESTAMP, -1L)

            if (packageName == null || title == null || text == null || timestamp <= 0L) {
                mainHandler.post { result.success(null) }
                return@execute
            }

            val payload = buildPayload(packageName, title, text, timestamp)
            mainHandler.post { result.success(payload) }
        }
    }

    private fun handleGetPendingNotifications(result: Result) {
        val context = appContext
        if (context == null) {
            result.error("NO_CONTEXT", "Context not ready", null)
            return
        }
        executor.execute {
            val pending = readPending(context)
            Log.i(TAG, "Returning ${pending.size} pending notifications to Flutter")
            clearPending(context)
            mainHandler.post { result.success(pending) }
        }
    }

    private fun handleClearPendingNotifications(result: Result) {
        val context = appContext
        if (context == null) {
            result.error("NO_CONTEXT", "Context not ready", null)
            return
        }
        executor.execute {
            clearPending(context)
            mainHandler.post { result.success(true) }
        }
    }

    private fun handleIsListenerEnabled(result: Result) {
        val context = appContext
        if (context == null) {
            result.error("NO_CONTEXT", "Context not ready", null)
            return
        }
        executor.execute {
            val enabled = isNotificationListenerEnabled(context)
            mainHandler.post { result.success(enabled) }
        }
    }

    private fun handleOpenNotificationSettings(result: Result) {
        val context = appContext
        if (context == null) {
            result.error("NO_CONTEXT", "Context not ready", null)
            return
        }
        try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_SETTINGS_FAILED", e.message, null)
        }
    }

    private fun handleGetAppPackageName(result: Result) {
        val context = appContext
        if (context == null) {
            result.error("NO_CONTEXT", "Context not ready", null)
            return
        }
        result.success(context.packageName)
    }

    private fun dispatchPending() {
        val context = appContext ?: return
        executor.execute {
            val pending = readPending(context)
            if (pending.isEmpty()) {
                Log.d(TAG, "No queued notifications to dispatch")
                return@execute
            }
            Log.i(TAG, "Dispatching ${pending.size} queued notifications to Flutter")
            for (item in pending) {
                emit(item)
            }
            clearPending(context)
        }
    }

    private fun emit(payload: Map<String, Any>) {
        val sink = eventSink ?: return
        mainHandler.post {
            try {
                sink.success(payload)
                Log.d(TAG, "Emitted notification to Flutter package=${payload["packageName"]}")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to emit payload", e)
            }
        }
    }

    private fun saveLast(payload: Map<String, Any>) {
        val context = appContext ?: return
        prefs(context).edit()
            .putString(NotificationCaptureService.KEY_LAST_PACKAGE, payload["packageName"] as String)
            .putString(NotificationCaptureService.KEY_LAST_TITLE, payload["title"] as String)
            .putString(NotificationCaptureService.KEY_LAST_TEXT, payload["text"] as String)
            .putLong(NotificationCaptureService.KEY_LAST_TIMESTAMP, payload["timestamp"] as Long)
            .apply()
        Log.d(TAG, "Saved last notification package=${payload["packageName"]}")
    }

    private fun appendPending(payload: Map<String, Any>) {
        val context = appContext ?: return
        val list = readPendingArray(context)
        val newKey = payloadKey(payload)
        for (i in 0 until list.length()) {
            val existing = list.optJSONObject(i) ?: continue
            if (payloadKey(existing) == newKey) {
                Log.d(TAG, "Skipping duplicate pending notification key=$newKey")
                return
            }
        }
        list.put(JSONObject(payload))
        while (list.length() > MAX_PENDING) {
            list.remove(0)
        }
        prefs(context).edit().putString(KEY_PENDING, list.toString()).apply()
        Log.d(TAG, "Pending notification queue size=${list.length()}")
    }

    private fun readPending(context: Context): List<Map<String, Any>> {
        val list = readPendingArray(context)
        val results = ArrayList<Map<String, Any>>(list.length())
        for (i in 0 until list.length()) {
            val obj = list.optJSONObject(i) ?: continue
            val payload = jsonToMap(obj) ?: continue
            results.add(payload)
        }
        return results
    }

    private fun readPendingArray(context: Context): JSONArray {
        val raw = prefs(context).getString(KEY_PENDING, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (_: JSONException) {
            JSONArray()
        }
    }

    private fun clearPending(context: Context) {
        prefs(context).edit().remove(KEY_PENDING).apply()
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(NotificationCaptureService.PREFS_NAME, Context.MODE_PRIVATE)

    private fun buildPayload(
        packageName: String,
        title: String,
        text: String,
        timestamp: Long
    ): Map<String, Any> {
        return mapOf(
            "packageName" to packageName,
            "title" to title,
            "text" to text,
            "timestamp" to timestamp
        )
    }

    private fun jsonToMap(obj: JSONObject): Map<String, Any>? {
        val packageName = obj.optString("packageName", "")
        val title = obj.optString("title", "")
        val text = obj.optString("text", "")
        val timestamp = obj.optLong("timestamp", 0L)
        if (packageName.isEmpty() || timestamp <= 0L) {
            return null
        }
        return buildPayload(packageName, title, text, timestamp)
    }

    private fun payloadKey(payload: Map<String, Any>): String {
        val packageName = payload["packageName"] as? String ?: ""
        val title = payload["title"] as? String ?: ""
        val text = payload["text"] as? String ?: ""
        val timestamp = payload["timestamp"] as? Long ?: 0L
        return "$packageName|$title|$text|$timestamp"
    }

    private fun payloadKey(payload: JSONObject): String {
        val packageName = payload.optString("packageName", "")
        val title = payload.optString("title", "")
        val text = payload.optString("text", "")
        val timestamp = payload.optLong("timestamp", 0L)
        return "$packageName|$title|$text|$timestamp"
    }

    private fun isNotificationListenerEnabled(context: Context): Boolean {
        val enabled =
            Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
                ?: return false
        val packageName = context.packageName
        val components = enabled.split(":")
        for (component in components) {
            val cn = ComponentName.unflattenFromString(component) ?: continue
            if (cn.packageName == packageName) {
                return true
            }
        }
        return false
    }
}
