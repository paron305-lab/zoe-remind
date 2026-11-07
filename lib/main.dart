import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:zoe_remind/app/app.dart';
import 'package:zoe_remind/app/router.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init(); // bago mag-runApp

  onboardingDone.value = await SettingsRepository().isOnboardingDone();

  runApp(const ZoeApp());

  // Makikinig kapag nagri-ring na → bubuksan ang ringing screen
  ReminderAlarmService.instance.startListening();
}