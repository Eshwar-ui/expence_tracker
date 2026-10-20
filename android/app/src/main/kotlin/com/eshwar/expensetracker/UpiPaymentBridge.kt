package com.eshwar.expensetracker

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.Canvas
import java.io.ByteArrayOutputStream
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Forward the QR's payment details intact to the app the user selected. */
class UpiPaymentBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private var pendingResult: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, "com.eshwar.expensetracker/upi_payment")
            .setMethodCallHandler { call, result ->
                if (call.method == "getInstalledApps") {
                    try {
                        val pm = activity.packageManager
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay"))
                        val apps = pm.queryIntentActivities(intent, 0)
                            .distinctBy { it.activityInfo.packageName }
                            .map { info ->
                                val icon = info.loadIcon(pm)
                                val bitmap = Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888)
                                icon.setBounds(0, 0, 64, 64)
                                icon.draw(Canvas(bitmap))
                                val bytes = ByteArrayOutputStream()
                                bitmap.compress(Bitmap.CompressFormat.PNG, 100, bytes)
                                bitmap.recycle()
                                mapOf("packageName" to info.activityInfo.packageName,
                                    "appName" to info.loadLabel(pm).toString(),
                                    "icon" to bytes.toByteArray())
                            }
                        result.success(apps)
                    } catch (_: Exception) {
                        result.error("DISCOVERY_FAILED", "Could not load payment apps.", null)
                    }
                    return@setMethodCallHandler
                }
                // Open the app's own entry screen, without a payment intent.
                // The user completes a blocked handoff using its native payment flow.
                if (call.method == "openApp") {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.error("APP_UNAVAILABLE", "Select a payment app first.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val launchIntent = activity.packageManager
                            .getLaunchIntentForPackage(packageName)
                        if (launchIntent == null) {
                            result.error("APP_UNAVAILABLE", "The selected payment app is unavailable.", null)
                        } else {
                            activity.startActivity(launchIntent)
                            result.success(null)
                        }
                    } catch (_: Exception) {
                        result.error("LAUNCH_FAILED", "Could not open the selected payment app. The UPI ID is copied; open it manually.", null)
                    }
                    return@setMethodCallHandler
                }
                if (call.method != "pay") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingResult != null) {
                    result.error("PAYMENT_IN_PROGRESS", "A payment app is already open.", null)
                    return@setMethodCallHandler
                }
                val raw = call.argument<String>("uri")
                val packageName = call.argument<String>("packageName")
                val uri = raw?.let { Uri.parse(it) }
                if (uri?.scheme != "upi" || uri.host != "pay" ||
                    uri.getQueryParameter("pa").isNullOrBlank() || packageName.isNullOrBlank()) {
                    result.error("INVALID_PAYMENT", "Invalid UPI payment details.", null)
                    return@setMethodCallHandler
                }
                try {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_VIEW, uri).setPackage(packageName)
                    activity.startActivityForResult(intent, REQUEST_CODE)
                } catch (_: ActivityNotFoundException) {
                    pendingResult = null
                    result.error("APP_UNAVAILABLE", "The selected payment app is unavailable.", null)
                } catch (_: Exception) {
                    pendingResult = null
                    result.error("LAUNCH_FAILED", "Could not open the selected payment app.", null)
                }
            }
    }

    fun onActivityResult(requestCode: Int, data: Intent?) {
        if (requestCode != REQUEST_CODE) return
        val result = pendingResult ?: return
        pendingResult = null
        val response = data?.getStringExtra("response")
            ?: data?.getStringExtra("Response")
        if (response.isNullOrBlank()) {
            result.error("UNCONFIRMED", "No payment confirmation was returned. Check your payment app or bank before trying again.", null)
        } else {
            result.success(response)
        }
    }

    fun dispose() {
        pendingResult?.error("UNCONFIRMED", "Payment confirmation was interrupted. Check your payment app or bank.", null)
        pendingResult = null
    }

    companion object {
        private const val REQUEST_CODE = 48173
    }
}
