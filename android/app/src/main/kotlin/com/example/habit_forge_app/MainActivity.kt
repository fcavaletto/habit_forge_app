package com.example.habit_forge_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.habit_forge_app/lifecycle"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up method channel for lifecycle communication
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppLifecycleState" -> {
                    result.success("resumed")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Ensure proper Flutter engine initialization
        // This helps prevent black screen issues on app resume
    }

    override fun onResume() {
        super.onResume()
        
        // Notify Flutter about app resume to trigger data refresh
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod("onAppResumed", null)
        }
    }

    override fun onPause() {
        super.onPause()
        
        // Notify Flutter about app pause
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod("onAppPaused", null)
        }
    }
}
