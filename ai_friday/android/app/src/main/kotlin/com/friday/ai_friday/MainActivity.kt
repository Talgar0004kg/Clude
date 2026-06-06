package com.friday.ai_friday

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "friday/accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                val svc = FridayAccessibilityService.instance
                when (call.method) {
                    "isEnabled" -> result.success(isServiceEnabled())
                    "openSettings" -> {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }
                    "setText" ->
                        result.success(svc?.setText(call.argument<String>("text") ?: "") ?: false)
                    "tap" -> {
                        val labels = call.argument<List<String>>("labels") ?: emptyList()
                        result.success(svc?.clickByLabel(labels) ?: false)
                    }
                    "pressSend" -> result.success(svc?.pressSend() ?: false)
                    "back" -> result.success(svc?.back() ?: false)
                    "home" -> result.success(svc?.home() ?: false)
                    "launchApp" -> result.success(launchApp(call.argument<String>("package") ?: ""))
                    "readScreen" -> result.success(svc?.readScreen() ?: "")
                    "tapXY" -> result.success(
                        svc?.tapCoordinate(call.argument<Int>("x") ?: 0, call.argument<Int>("y") ?: 0) ?: false
                    )
                    "scroll" -> result.success(
                        svc?.scrollScreen(call.argument<String>("direction") ?: "down") ?: false
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /// Запуск приложения точно по пакету (минуя любые дефолт-ассоциации).
    private fun launchApp(pkg: String): Boolean {
        if (pkg.isEmpty()) return false
        return try {
            val intent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun isServiceEnabled(): Boolean {
        if (FridayAccessibilityService.instance != null) return true
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.contains("FridayAccessibilityService")
    }
}
