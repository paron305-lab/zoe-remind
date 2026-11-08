package com.example.zoe_app

import android.annotation.SuppressLint
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
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
                    // Ringing screen sa ibabaw ng lock screen
                    "showOverLockScreen" -> { setLockScreenMode(true); result.success(null) }
                    "clearLockScreen" -> { setLockScreenMode(false); result.success(null) }

                    // Reminder Setup (permissions para sa lahat ng brand)
                    "manufacturer" -> result.success(Build.MANUFACTURER.lowercase())
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                    "openFullScreenIntentSettings" -> result.success(openFullScreenIntentSettings())
                    "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                    "requestIgnoreBatteryOptimizations" -> result.success(requestIgnoreBatteryOptimizations())
                    "openAutoStart" -> result.success(openAutoStart())
                    "openOemPermissions" -> result.success(openOemPermissions())
                    "openAppDetails" -> result.success(openAppDetails())
                    else -> result.notImplemented()
                }
            }
    }

    // ───────────────────────── Lock screen ─────────────────────────

    // ON lang habang nagri-ring. Pag Done/Snooze/Dismiss -> babalik ang lock screen.
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

    // ───────────────────────── Helpers ─────────────────────────

    private fun tryStart(intent: Intent): Boolean = try {
        startActivity(intent)
        true
    } catch (e: Exception) {
        false
    }

    private fun packageUri(): Uri = Uri.parse("package:$packageName")

    private fun openAppDetails(): Boolean =
        tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri()))

    // ───────────────────────── Full screen (Android 14+) ─────────────────────────

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.canUseFullScreenIntent()
    }

    private fun openFullScreenIntentSettings(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val i = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, packageUri())
            if (tryStart(i)) return true
        }
        return openAppDetails()
    }

    // ───────────────────────── Battery ─────────────────────────

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    @SuppressLint("BatteryLife")
    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (tryStart(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, packageUri()))) return true
        if (tryStart(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))) return true
        return openAppDetails()
    }

    // ───────────────────────── Autostart (per brand) ─────────────────────────

    /** Sinusubukan isa-isa ang Autostart page ng bawat brand. Fallback: App info. */
    private fun openAutoStart(): Boolean {
        val candidates = listOf(
            // Xiaomi / Redmi / POCO
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            // Oppo / Realme / OnePlus (ColorOS)
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
            ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            ComponentName("com.coloros.oppoguardelf", "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"),
            ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"),
            // Vivo / iQOO
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"),
            // Huawei / Honor
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
            ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            // Samsung (Battery → Background usage limits)
            ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"),
            ComponentName("com.samsung.android.sm", "com.samsung.android.sm.battery.ui.BatteryActivity"),
            // Infinix / Tecno / itel (Phone Master)
            ComponentName("com.transsion.phonemaster", "com.cyin.himgr.autostart.AutoStartActivity"),
            // Asus
            ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.entry.FunctionActivity"),
            ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity"),
        )
        for (c in candidates) {
            if (tryStart(Intent().setComponent(c))) return true
        }
        openAppDetails()
        return false
    }

    /** Xiaomi: "Other permissions" (Show on Lock screen, pop-up windows). Iba: App info. */
    private fun openOemPermissions(): Boolean {
        val m = Build.MANUFACTURER.lowercase()
        if (m == "xiaomi" || m == "redmi" || m == "poco") {
            val editors = listOf(
                "com.miui.permcenter.permissions.PermissionsEditorActivity",
                "com.miui.permcenter.permissions.AppPermissionsEditorActivity",
            )
            for (cls in editors) {
                val i = Intent("miui.intent.action.APP_PERM_EDITOR")
                    .setClassName("com.miui.securitycenter", cls)
                    .putExtra("extra_pkgname", packageName)
                if (tryStart(i)) return true
            }
        }
        return openAppDetails()
    }
}