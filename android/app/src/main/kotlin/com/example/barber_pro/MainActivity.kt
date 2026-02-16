package com.example.barber_pro

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val lifecycleChannel = "barber_pro/lifecycle"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, lifecycleChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "moveToBack") {
                    moveTaskToBack(true)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
