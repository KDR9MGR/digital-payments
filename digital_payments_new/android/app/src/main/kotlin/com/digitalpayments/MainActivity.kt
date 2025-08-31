package com.digitalpayments

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable edge-to-edge display for Android 11+ (API 30+)
        // This ensures proper edge-to-edge display and compatibility with Android 15
        // without using deprecated setStatusBarColor and setNavigationBarColor
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
            
            // Set transparent status bar and navigation bar using modern API
            window.statusBarColor = Color.TRANSPARENT
            window.navigationBarColor = Color.TRANSPARENT
            
            // Configure status bar appearance using WindowInsetsController
            val windowInsetsController = WindowInsetsControllerCompat(window, window.decorView)
            windowInsetsController.isAppearanceLightStatusBars = true
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}
