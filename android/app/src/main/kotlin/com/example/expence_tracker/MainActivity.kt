package com.eshwar.expensetracker

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationChannelBridge.attach(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
