package com.eshwar.expensetracker

import android.content.ComponentName
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "app_icon_theme"
    private var upiPaymentBridge: UpiPaymentBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (isDebuggable()) setLightIcon()
        NotificationChannelBridge.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        upiPaymentBridge = UpiPaymentBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setLightIcon" -> {
                    setLightIcon()
                    result.success(null)
                }
                "setDarkIcon" -> {
                    setDarkIcon()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        upiPaymentBridge?.onActivityResult(requestCode, data)
    }

    override fun onDestroy() {
        upiPaymentBridge?.dispose()
        super.onDestroy()
    }

    private fun setLightIcon() {
        swapLauncherAlias(enable = ".MainActivityLight", disable = ".MainActivityDark")
    }

    private fun setDarkIcon() {
        // `flutter run` always launches .MainActivityLight (the first enabled
        // LAUNCHER entry in the manifest), so debug builds must never disable it.
        if (isDebuggable()) {
            setLightIcon()
            return
        }
        swapLauncherAlias(enable = ".MainActivityDark", disable = ".MainActivityLight")
    }

    private fun isDebuggable(): Boolean =
        (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    // Swap which alias is the visible launcher icon. MainActivity itself is
    // never touched — disabling it breaks `flutter run`'s `am start` and
    // `pm` lookups of the package's launch activity.
    private fun swapLauncherAlias(enable: String, disable: String) {
        try {
            val pm = packageManager
            val mainName = ComponentName(packageName, "$packageName.MainActivity")
            val enableName = ComponentName(packageName, "$packageName$enable")
            val disableName = ComponentName(packageName, "$packageName$disable")

            // Self-heal: older builds disabled MainActivity. Restore it so
            // `am start -n .../.MainActivity` resolves again.
            if (pm.getComponentEnabledSetting(mainName) ==
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED) {
                pm.setComponentEnabledSetting(
                    mainName,
                    PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                    PackageManager.DONT_KILL_APP,
                )
            }

            if (pm.getComponentEnabledSetting(enableName) !=
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                pm.setComponentEnabledSetting(
                    enableName,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP,
                )
                pm.setComponentEnabledSetting(
                    disableName,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
