import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:zoe_remind/app/app.dart';
import 'package:zoe_remind/app/router.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
import 'package:zoe_remind/supabase/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init(); // bago mag-runApp

  // Supabase (login / sync / model config).
  // Offline-first: kapag walang keys o internet, tuloy pa rin ang app.
  await SupabaseService.init();

  // Read the database before the first screen, so new users
  // land on onboarding and returning users land on Home.
  onboardingDone.value = await SettingsRepository().isOnboardingDone();
  await ZoeTheme.load(); // dark mode (Settings › Appearance)

  runApp(const ZoeApp());

  final alarms = ReminderAlarmService.instance;
  alarms.startListening(); // nagri-ring -> bubuksan ang ringing screen
  alarms.syncAll(); // lagyan ng alarm ang lahat ng pending reminders
}