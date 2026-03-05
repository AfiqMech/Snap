package com.example.snap

import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.snap/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStorageInfo" -> {
                    try {
                        val stat = StatFs(Environment.getExternalStorageDirectory().path)
                        val bytesAvailable = stat.blockSizeLong * stat.availableBlocksLong
                        val totalSpace = stat.blockSizeLong * stat.blockCountLong
                        
                        result.success(mapOf(
                            "free" to bytesAvailable,
                            "total" to totalSpace
                        ))
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                }
                "getLaunchMode" -> {
                    val intent = activity.intent
                    val action = intent.action
                    val launchMode = intent.getStringExtra("launch_mode")
                    
                    // Check for explicit quick download intent
                    if (launchMode == "quick" || 
                        (intent != null && intent.hasCategory("com.example.snap.QUICK_DOWNLOAD"))) {
                        result.success("quick")
                    } else {
                        result.success("normal")
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        // Ensure the activity uses the latest intent when a new share comes in
        setIntent(intent)
    }

    override fun getBackgroundMode(): BackgroundMode {
        return BackgroundMode.transparent
    }
}
