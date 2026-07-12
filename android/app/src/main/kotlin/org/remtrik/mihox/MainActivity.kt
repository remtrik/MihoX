package org.remtrik.mihox

import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.appcompat.app.AppCompatDelegate
import org.remtrik.mihox.plugins.AppPlugin
import org.remtrik.mihox.plugins.ServicePlugin
import org.remtrik.mihox.plugins.TilePlugin
import org.remtrik.mihox.plugins.VpnPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Apply app theme before creating the activity to fix splash screen theme
        applyAppTheme()
        
        super.onCreate(savedInstanceState)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.attributes.preferredDisplayModeId = getHighestRefreshRateDisplayMode()
        }
    }

    private fun getHighestRefreshRateDisplayMode(): Int {
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }
        val modes = display?.supportedModes ?: return 0
        if (modes.isEmpty()) return 0

        return modes.maxByOrNull { it.refreshRate }?.modeId ?: 0
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Platform Channel for getting Android ID
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.remtrik.mihox/device_id")
            .setMethodCallHandler { call, result ->
                if (call.method == "getAndroidId") {
                    try {
                        val androidId = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                        result.success(androidId)
                    } catch (e: Exception) {
                        result.error("ANDROID_ID_ERROR", "Failed to get Android ID: ${e.message}", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(ServicePlugin)
        flutterEngine.plugins.add(TilePlugin())
        flutterEngine.plugins.add(VpnPlugin)
        GlobalState.flutterEngine = flutterEngine
        
        // Sync VPN status when app opens - this ensures UI reflects actual VPN state
        // especially important when VPN was started via Tile while app was not in memory
        GlobalState.syncStatus()
    }

    override fun onDestroy() {
        GlobalState.flutterEngine = null
        // Don't reset runState here - VPN might still be running via serviceEngine
        // The runState is managed by VpnPlugin.handleStart/handleStop
        super.onDestroy()
    }

    private fun applyAppTheme() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val configJson = prefs.getString("flutter.config", null)
            
            if (configJson != null) {
                val config = JSONObject(configJson)
                val themeProps = config.optJSONObject("themeProps")
                val themeMode = themeProps?.optString("themeMode", "ThemeMode.system") ?: "ThemeMode.system"
                
                when {
                    themeMode.contains("light", ignoreCase = true) -> {
                        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
                    }
                    themeMode.contains("dark", ignoreCase = true) -> {
                        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
                    }
                    else -> {
                        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
                    }
                }
            } else {
                // Default to system theme if config not found
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
            }
        } catch (_: Exception) {
            // Fallback to system theme on error
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
        }
    }
}