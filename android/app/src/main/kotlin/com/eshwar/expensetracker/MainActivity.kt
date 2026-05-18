package com.eshwar.expensetracker

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "app_icon_theme"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationChannelBridge.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        
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

    private fun setLightIcon() {
        swapLauncherAlias(enable = ".MainActivityLight", disable = ".MainActivityDark")
    }

    private fun setDarkIcon() {
        swapLauncherAlias(enable = ".MainActivityDark", disable = ".MainActivityLight")
    }

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
