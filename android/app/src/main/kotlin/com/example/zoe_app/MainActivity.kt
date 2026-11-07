package com.example.zoe_app // ⚠️ panatilihin mo yung sarili mong package line

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zoe/alarm_screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOverLockScreen" -> { setLockScreenMode(true); result.success(null) }
                    "clearLockScreen" -> { setLockScreenMode(false); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    // ON lang habang nagri-ring. Pag Done/Snooze/Dismiss → babalik ang lock screen.
    private fun setLockScreenMode(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
        if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}