import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';

/// Lahat ng kailangan para tumunog si Zoe sa kahit anong brand.
enum SetupItem {
  /// Android 13+: payagang magpakita ng notification.
  notifications,

  /// Android 12+: "Alarms & reminders" — eksaktong oras.
  exactAlarm,

  /// Android 14+: full screen ni Zoe sa lock screen.
  fullScreen,

  /// Hindi papatayin ng battery saver ang alarm.
  battery,

  /// "Display over other apps": lalabas ang buong screen ni Zoe kahit
  /// unlocked ang phone at nasa ibang app / home screen ang user.
  overlay,

  /// Xiaomi / Oppo / Vivo / Huawei / Samsung / Infinix …: Autostart at
  /// background permissions. Walang API para i-check, kaya kinukumpirma ng user.
  autostart,
}

class SetupStatus {
  const SetupStatus(this.ok, this.manufacturer, this.sdkInt);

  final Map<SetupItem, bool> ok;
  final String manufacturer;
  final int sdkInt;

  /// Mga item na kailangan sa phone na ito (hal. walang autostart step sa Pixel).
  List<SetupItem> get items => ok.keys.toList();

  bool isOk(SetupItem i) => ok[i] ?? true;

  /// Kung kulang ang isa sa mga ito, HINDI tutunog ang reminder.
  bool get criticalOk =>
      isOk(SetupItem.notifications) && isOk(SetupItem.exactAlarm);

  bool get allOk => ok.values.every((v) => v);

  int get readyCount => ok.values.where((v) => v).length;
}

class ReminderPermissions {
  ReminderPermissions._();
  static final ReminderPermissions instance = ReminderPermissions._();

  static const _ch = MethodChannel('zoe/alarm_screen');
  static const _kAutostart = 'reminder_autostart_confirmed';
  static const _kPrompted = 'reminder_setup_prompted';

  final _settings = SettingsRepository();

  /// Mga brand na may sariling Autostart / battery manager na pumapatay ng alarm.
  static const _oemBrands = {
    'xiaomi', 'redmi', 'poco', // MIUI / HyperOS
    'oppo', 'realme', 'oneplus', // ColorOS
    'vivo', 'iqoo', // FuntouchOS / OriginOS
    'huawei', 'honor', // EMUI / MagicOS
    'samsung', // One UI (Sleeping apps)
    'infinix', 'tecno', 'itel', // XOS / HiOS
    'asus', 'meizu', 'lenovo', 'nokia', 'cherry', 'cherry mobile',
  };

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool isOemBrand(String manufacturer) => _oemBrands.contains(manufacturer);

  // ───────────────────────── Check ─────────────────────────

  Future<SetupStatus> check() async {
    if (!_isAndroid) {
      return const SetupStatus({SetupItem.notifications: true}, 'other', 0);
    }

    final manufacturer = await _call<String>('manufacturer') ?? 'unknown';
    final sdkInt = await _call<int>('sdkInt') ?? 0;

    final ok = <SetupItem, bool>{
      SetupItem.notifications: (await Permission.notification.status).isGranted,
      SetupItem.exactAlarm: (await Permission.scheduleExactAlarm.status).isGranted,
    };
    if (sdkInt >= 34) {
      ok[SetupItem.fullScreen] = await _call<bool>('canUseFullScreenIntent') ?? true;
    }
    ok[SetupItem.battery] = await _call<bool>('isIgnoringBatteryOptimizations') ?? true;
    ok[SetupItem.overlay] = (await Permission.systemAlertWindow.status).isGranted;
    if (isOemBrand(manufacturer)) {
      ok[SetupItem.autostart] = await _settings.getValue(_kAutostart) == 'true';
    }
    return SetupStatus(ok, manufacturer, sdkInt);
  }

  /// Ipakita ba ang Reminder Setup pagkatapos mag-save ng reminder?
  /// - Laging oo kung kulang ang critical (hindi tutunog).
  /// - Isang beses lang kung ang kulang ay battery / full screen / autostart.
  Future<bool> shouldPrompt() async {
    final s = await check();
    if (!s.criticalOk) return true;
    if (s.allOk) return false;
    if (await _settings.getValue(_kPrompted) == 'true') return false;
    await _settings.setValue(_kPrompted, 'true');
    return true;
  }

  // ───────────────────────── Fix ─────────────────────────

  /// Bubuksan ang tamang system page / dialog para sa [item].
  Future<void> fix(SetupItem item) async {
    switch (item) {
      case SetupItem.notifications:
        final st = await Permission.notification.request();
        // "Don't ask again" na → buksan ang App info
        if (st.isPermanentlyDenied) await openAppSettings();
      case SetupItem.exactAlarm:
        await Permission.scheduleExactAlarm.request();
      case SetupItem.fullScreen:
        await _call<bool>('openFullScreenIntentSettings');
      case SetupItem.battery:
        await _call<bool>('requestIgnoreBatteryOptimizations');
      case SetupItem.overlay:
        await Permission.systemAlertWindow.request(); // bubuksan ang Settings
      case SetupItem.autostart:
        await _call<bool>('openAutoStart');
    }
  }

  /// Xiaomi: "Other permissions" (Show on Lock screen / pop-up windows).
  Future<void> openOemPermissions() => _call<bool>('openOemPermissions');

  Future<void> openAppDetails() => _call<bool>('openAppDetails');

  /// Pinindot ng user ang "Na-ON ko na" sa Autostart step.
  Future<void> confirmAutostart(bool done) =>
      _settings.setValue(_kAutostart, done ? 'true' : 'false');

  // ───────────────────────── Helpers ─────────────────────────

  Future<T?> _call<T>(String method) async {
    try {
      return await _ch.invokeMethod<T>(method);
    } catch (e) {
      debugPrint('ReminderPermissions.$method failed: $e');
      return null;
    }
  }
}