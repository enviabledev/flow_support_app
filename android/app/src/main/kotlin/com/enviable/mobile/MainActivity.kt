package com.enviable.mobile

import android.os.Bundle
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.enviable.mobile/permissions"
    private val PERMISSION_REQUEST_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "requestPermissions") {
                val permissions = call.argument<List<String>>("permissions")
                if (permissions != null) {
                    ActivityCompat.requestPermissions(
                        this,
                        permissions.toTypedArray(),
                        PERMISSION_REQUEST_CODE
                    )
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "No permissions provided", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
