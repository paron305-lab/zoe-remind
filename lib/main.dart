import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:zoe_remind/app/app.dart';
import 'package:zoe_remind/app/router.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init(); // bago mag-runApp

  // Read the database before the first screen, so new users
  // land on onboarding and returning users land on Home.
  onboardingDone.value = await SettingsRepository().isOnboardingDone();

  runApp(const ZoeApp());

  final alarms = ReminderAlarmService.instance;
  alarms.startListening(); // nagri-ring -> bubuksan ang ringing screen
  alarms.syncAll(); // lagyan ng alarm ang lahat ng pending reminders
}