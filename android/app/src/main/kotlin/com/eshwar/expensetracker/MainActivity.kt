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
        try {
            val packageManager = packageManager
            val mainName = ComponentName(packageName, "$packageName.MainActivity")
            val lightName = ComponentName(packageName, "$packageName.MainActivityLight")
            val darkName = ComponentName(packageName, "$packageName.MainActivityDark")

            if (packageManager.getComponentEnabledSetting(lightName) != PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                // Enable Light alias as the single launcher entry; disable main and dark so only one icon shows.
                packageManager.setComponentEnabledSetting(lightName, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                packageManager.setComponentEnabledSetting(mainName, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                packageManager.setComponentEnabledSetting(darkName, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setDarkIcon() {
        try {
            val packageManager = packageManager
            val mainName = ComponentName(packageName, "$packageName.MainActivity")
            val lightName = ComponentName(packageName, "$packageName.MainActivityLight")
            val darkName = ComponentName(packageName, "$packageName.MainActivityDark")

            if (packageManager.getComponentEnabledSetting(darkName) != PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                // Enable Dark alias as the single launcher entry; disable main and light so only one icon shows.
                packageManager.setComponentEnabledSetting(darkName, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                packageManager.setComponentEnabledSetting(mainName, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                packageManager.setComponentEnabledSetting(lightName, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
