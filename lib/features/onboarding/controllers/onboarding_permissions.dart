import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Notification + exact-alarm permissions for reminders.
///
/// Android 13+ asks for notifications at runtime. Exact alarms
/// (Android 12+) are granted from a system Settings page; on Android 14+
/// they start denied for new installs, so the user must turn them on.
class OnboardingPermissions {
  const OnboardingPermissions();

  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> notificationsGranted() async {
    if (kIsWeb) return true;
    return (await Permission.notification.status).isGranted;
  }

  Future<bool> requestNotifications() async {
    if (kIsWeb) return true;
    return (await Permission.notification.request()).isGranted;
  }

  Future<bool> exactAlarmGranted() async {
    if (!isAndroid) return true;
    return (await Permission.scheduleExactAlarm.status).isGranted;
  }

  /// Opens the system "Alarms & reminders" page on Android 12+.
  Future<bool> requestExactAlarm() async {
    if (!isAndroid) return true;
    return (await Permission.scheduleExactAlarm.request()).isGranted;
  }
}